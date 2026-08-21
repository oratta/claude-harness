#!/usr/bin/env bats
#
# capability-registry-fmtoken: fmtoken.sh のプラグイン内動作
#
# spec: capability-registry-fmtoken
# op / security は PATH スタブで差し替え、1Password 実環境に依存しない。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FMTOKEN="${PLUGIN_DIR}/scripts/fmtoken.sh"
  WORK="$(mktemp -d)"
  STUB="${WORK}/stub-bin"
  mkdir -p "$STUB"

  # 登録済みアイテムを FMTOKEN_TEST_REGISTERED（ref 完全一致）で表現する op スタブ。
  # FMTOKEN_TEST_EXPECT_SA が設定されていれば、OP_SERVICE_ACCOUNT_TOKEN の一致も要求する
  # （どの経路の SA トークンが使われたかを検証するため）
  cat >"${STUB}/op" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${FMTOKEN_TEST_EXPECT_SA:-}" && "${OP_SERVICE_ACCOUNT_TOKEN:-}" != "$FMTOKEN_TEST_EXPECT_SA" ]]; then
  exit 1
fi
if [[ "$1" == "read" ]]; then
  if [[ "$2" == "${FMTOKEN_TEST_REGISTERED:-}" ]]; then
    echo "tok-secret-123"
    exit 0
  fi
  exit 1
fi
if [[ "$1" == "item" && "$2" == "list" ]]; then
  echo '[{"title":"proj--github"},{"title":"proj--supabase"},{"title":"other--vercel"}]'
  exit 0
fi
if [[ "$1" == "item" && "$2" == "create" ]]; then
  # argv と stdin を別ログに分けて記録する。値がどちらの経路を通ったかを
  # テストで区別するため（issue #130: 値は argv に載せず stdin の JSON で渡す）。
  printf '%s\n' "$@" >"${FMTOKEN_TEST_CREATE_LOG:-/dev/null}"
  cat >"${FMTOKEN_TEST_CREATE_STDIN_LOG:-/dev/null}"
  exit 0
fi
exit 1
EOF
  chmod +x "${STUB}/op"

  # Keychain 不在をシミュレートする security スタブ
  cat >"${STUB}/security" <<'EOF'
#!/usr/bin/env bash
exit 44
EOF
  chmod +x "${STUB}/security"

  PATH="${STUB}:${PATH}"
  export OP_SERVICE_ACCOUNT_TOKEN="dummy-sa-token"
  export FMTOKEN_TEST_CREATE_LOG="${WORK}/op-create.log"
  export FMTOKEN_TEST_CREATE_STDIN_LOG="${WORK}/op-create-stdin.log"
}

# op item create の stdin ログに記録された JSON から、credential フィールドの値を取り出す。
# 値の完全一致を見るため、文字列の部分一致ではなく JSON をパースして比較する。
created_credential() {
  /usr/bin/python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
print([f for f in d["fields"] if f["id"]=="credential"][0]["value"], end="")' "$FMTOKEN_TEST_CREATE_STDIN_LOG"
}

# ファイル $2 にパターン $1 が現れないことを検証する。
# `! grep ...` を直接書かないのは、bash の errexit が `!` で始まる形では無効化され、
# アサートが黙って素通りするため（露出検査が常に緑になる事故を防ぐ）。
refute_in_file() {
  if grep -q -- "$1" "$2"; then
    echo "unexpected match: ${1} found in ${2}" >&2
    return 1
  fi
}

# 同じく stdin ログの JSON から任意のトップレベルキーを取り出す（title / category）。
created_field() {
  /usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]], end="")' \
    "$FMTOKEN_TEST_CREATE_STDIN_LOG" "$1"
}

teardown() {
  rm -rf "$WORK"
}

# 作業ディレクトリ $1（WORK 相対）に git リポを作り、origin remote を設定して移動する。
# $2 で remote URL を指定できる（省略時は https://github.com/test-org/<basename>.git）。
# project 導出は remote のリポ名ベースなので、dir 名は導出結果に影響しない。
make_repo() {
  local repo="${WORK}/$1"
  mkdir -p "$repo"
  git -C "$repo" init --quiet
  git -C "$repo" remote add origin "${2:-https://github.com/test-org/$(basename "$1").git}"
  cd "$repo"
}

@test "fmtoken.sh: exists and is executable" {
  [ -x "$FMTOKEN" ]
}

@test "registered service: prints token and exits 0" {
  make_repo "myproj"
  export FMTOKEN_TEST_REGISTERED="op://agents/myproj--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "project derives from remote repo name, not directory name (workspace/x/repo)" {
  make_repo "workspace/uranai-market/repo" "https://github.com/genetta-inc/suimei.git"
  export FMTOKEN_TEST_REGISTERED="op://agents/suimei--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "SSH scp-style remote resolves to same name as HTTPS" {
  make_repo "traore-checkout" "git@github.com:oratta/traore.git"
  export FMTOKEN_TEST_REGISTERED="op://agents/traore--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "uppercase remote repo name is lowercased" {
  make_repo "buffon-dir" "https://github.com/oratta/Buffon.git"
  export FMTOKEN_TEST_REGISTERED="op://agents/buffon--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "worktree resolves to same project as main repo" {
  make_repo "mainrepo" "https://github.com/test-org/suimei.git"
  git -c user.email=t@example.com -c user.name=t commit --allow-empty --quiet -m init
  git worktree add --quiet "${WORK}/wt-feature" -b wt-feature
  cd "${WORK}/wt-feature"
  export FMTOKEN_TEST_REGISTERED="op://agents/suimei--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "no origin remote: exit 45, no registration request in message" {
  local repo="${WORK}/noremote"
  mkdir -p "$repo"
  git -C "$repo" init --quiet
  cd "$repo"
  export FMTOKEN_TEST_REGISTERED="op://agents/noremote--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 45 ]
  [[ "$output" == *"origin"* ]]
  [[ "$output" != *"登録"* ]]
}

@test "outside a git repo: exit 45 (no cwd fallback reference)" {
  mkdir -p "${WORK}/plaindir"
  cd "${WORK}/plaindir"
  run "$FMTOKEN" github
  [ "$status" -eq 45 ]
}

@test "unregistered service: exit 44 with registration request on stderr" {
  make_repo "myproj"
  run "$FMTOKEN" notregistered
  [ "$status" -eq 44 ]
  [[ "$output" == *"myproj--notregistered"* ]]
  [[ "$output" == *"登録"* ]]
}

@test "--check: no token value printed, exit 0 when registered" {
  make_repo "myproj"
  export FMTOKEN_TEST_REGISTERED="op://agents/myproj--github/credential"
  run "$FMTOKEN" --check github
  [ "$status" -eq 0 ]
  [[ "$output" != *"tok-secret-123"* ]]
}

@test "--check: exit 44 when unregistered" {
  make_repo "myproj"
  run "$FMTOKEN" --check github
  [ "$status" -eq 44 ]
}

@test "--list: returns only this project's service names" {
  make_repo "proj"
  run "$FMTOKEN" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"github"* ]]
  [[ "$output" == *"supabase"* ]]
  [[ "$output" != *"vercel"* ]]
}

@test "missing SA token everywhere: exit 43 with distribution request" {
  make_repo "myproj"
  unset OP_SERVICE_ACCOUNT_TOKEN
  HOME="$WORK" run "$FMTOKEN" github
  [ "$status" -eq 43 ]
  [[ "$output" == *"SA トークン"* ]]
}

@test "SA token falls back to 600-permission file" {
  make_repo "myproj"
  unset OP_SERVICE_ACCOUNT_TOKEN
  mkdir -p "${WORK}/.config/op-sa"
  printf 'file-sa-token' >"${WORK}/.config/op-sa/claude-agents-ro.token"
  chmod 600 "${WORK}/.config/op-sa/claude-agents-ro.token"
  export FMTOKEN_TEST_REGISTERED="op://agents/myproj--github/credential"
  HOME="$WORK" run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "600 file takes precedence over Keychain (unattended-first)" {
  make_repo "myproj"
  unset OP_SERVICE_ACCOUNT_TOKEN
  # Keychain が値を返す状況（＝生体認証プロンプトの原因になる経路）でも、
  # ファイルが先に解決され Keychain には触れない
  cat >"${STUB}/security" <<'EOF'
#!/usr/bin/env bash
echo "keychain-sa-token"
exit 0
EOF
  chmod +x "${STUB}/security"
  mkdir -p "${WORK}/.config/op-sa"
  printf 'file-sa-token' >"${WORK}/.config/op-sa/claude-agents-ro.token"
  chmod 600 "${WORK}/.config/op-sa/claude-agents-ro.token"
  export FMTOKEN_TEST_EXPECT_SA="file-sa-token"
  export FMTOKEN_TEST_REGISTERED="op://agents/myproj--github/credential"
  HOME="$WORK" run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "env var takes precedence over 600 file" {
  make_repo "myproj"
  mkdir -p "${WORK}/.config/op-sa"
  printf 'file-sa-token' >"${WORK}/.config/op-sa/claude-agents-ro.token"
  chmod 600 "${WORK}/.config/op-sa/claude-agents-ro.token"
  export OP_SERVICE_ACCOUNT_TOKEN="env-sa-token"
  export FMTOKEN_TEST_EXPECT_SA="env-sa-token"
  export FMTOKEN_TEST_REGISTERED="op://agents/myproj--github/credential"
  HOME="$WORK" run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

# ─── 明示名参照（--name）: <agent>--<SERVICE> / <project>--<service> 両規約 ───

@test "--name: agent-prefixed item resolves by explicit name" {
  make_repo "myproj"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run "$FMTOKEN" --name moko--TRELLO_TOKEN
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "--name: project-prefixed item also resolves by explicit name" {
  make_repo "myproj"
  export FMTOKEN_TEST_REGISTERED="op://agents/suimei--github/credential"
  run "$FMTOKEN" --name suimei--github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "--name: works outside a git repo (no origin derivation needed)" {
  mkdir -p "${WORK}/no-repo-here"
  cd "${WORK}/no-repo-here"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run "$FMTOKEN" --name moko--TRELLO_TOKEN
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
}

@test "--check --name: exit 0 without printing token value" {
  make_repo "myproj"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run "$FMTOKEN" --check --name moko--TRELLO_TOKEN
  [ "$status" -eq 0 ]
  [[ "$output" != *"tok-secret-123"* ]]
}

@test "--name unregistered: exit 44 with --register hint" {
  make_repo "myproj"
  run "$FMTOKEN" --name moko--NOT_THERE
  [ "$status" -eq 44 ]
  [[ "$output" == *"moko--NOT_THERE"* ]]
  [[ "$output" == *"--register"* ]]
}

@test "--name: naming convention violation exits 46" {
  make_repo "myproj"
  run "$FMTOKEN" --name not_a_valid_name
  [ "$status" -eq 46 ]
  [[ "$output" == *"命名規約"* ]]
}

# ─── 登録（--register）: rw SA 経由・命名規約の機械検証・上書き防止 ───

@test "--register: project-prefixed item is created via rw SA (not ambient ro token)" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA="rw-sa-token"
  run bash -c "printf '%s' sekrit-value | '$FMTOKEN' --register newproj--newsvc"
  [ "$status" -eq 0 ]
  [ "$(created_field title)" = "newproj--newsvc" ]
  [[ "$output" != *"sekrit-value"* ]]
}

@test "--register: value goes through stdin only, never through op's argv" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA="rw-sa-token"
  run bash -c "printf '%s' sekrit-value | '$FMTOKEN' --register newproj--newsvc"
  [ "$status" -eq 0 ]
  # 値は op の argv に載らない（ps から見えない）
  refute_in_file "sekrit-value" "$FMTOKEN_TEST_CREATE_LOG"
  # assignment statement 形式そのものが消えていること
  refute_in_file "credential\[password\]" "$FMTOKEN_TEST_CREATE_LOG"
  # 値は stdin 経由で確かに渡っている（両方見ないと「どこにも渡さない」実装が通る）
  [ "$(created_credential)" = "sekrit-value" ]
}

@test "--register: created item keeps the API Credential shape (category / credential field)" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  run bash -c "printf '%s' sekrit-value | '$FMTOKEN' --register newproj--newsvc"
  [ "$status" -eq 0 ]
  [ "$(created_field category)" = "API_CREDENTIAL" ]
  grep -q -- "--vault" "$FMTOKEN_TEST_CREATE_LOG"
  grep -q -- "agents" "$FMTOKEN_TEST_CREATE_LOG"
  # JSON テンプレートを stdin で読ませる形（op item create ... -）
  grep -qx -- "-" "$FMTOKEN_TEST_CREATE_LOG"
}

@test "--register: value containing quotes, backslashes, newlines and \$ survives intact" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  # " \ 改行 $ ' タブ を含む値。手組み JSON や shell 展開で壊れるとここで落ちる。
  # 値はファイル経由で渡す（テスト側のクォートで壊すと検証の意味が無くなるため）
  printf 'a"b\\c$d\n%s\tsingle'\''quote' "line2" >"${WORK}/tricky"
  run bash -c "'$FMTOKEN' --register newproj--tricky < '${WORK}/tricky'"
  [ "$status" -eq 0 ]
  [ "$(created_credential)" = "$(cat "${WORK}/tricky")" ]
  refute_in_file 'a"b' "$FMTOKEN_TEST_CREATE_LOG"
}

@test "--register: agent-prefixed item is created" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA="rw-sa-token"
  run bash -c "printf '%s' sekrit-value | '$FMTOKEN' --register moko--TRELLO_TOKEN"
  [ "$status" -eq 0 ]
  [ "$(created_field title)" = "moko--TRELLO_TOKEN" ]
}

@test "--register: naming convention violation exits 46, op item create not called" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  run bash -c "printf '%s' v | '$FMTOKEN' --register BadName"
  [ "$status" -eq 46 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
}

@test "--register: double separator in name exits 46" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  run bash -c "printf '%s' v | '$FMTOKEN' --register a--b--c"
  [ "$status" -eq 46 ]
}

@test "--register: already-registered item exits 47 without overwrite" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run bash -c "printf '%s' v | '$FMTOKEN' --register moko--TRELLO_TOKEN"
  [ "$status" -eq 47 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
  [[ "$output" == *"登録済み"* ]]
}

@test "--register: empty stdin exits 46" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  run bash -c "printf '' | '$FMTOKEN' --register moko--EMPTY"
  [ "$status" -eq 46 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
}

@test "--register: missing rw SA token everywhere exits 43 (ro token is not reused)" {
  # 環境には ro トークン（dummy-sa-token）があるが、rw の解決先はどこにも無い
  HOME="$WORK" run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 43 ]
  [[ "$output" == *"claude-agents-rw"* ]]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
}

@test "--register: rw SA token falls back to 600-permission rw file" {
  mkdir -p "${WORK}/.config/op-sa"
  printf 'file-rw-token' >"${WORK}/.config/op-sa/claude-agents-rw.token"
  chmod 600 "${WORK}/.config/op-sa/claude-agents-rw.token"
  export FMTOKEN_TEST_EXPECT_SA="file-rw-token"
  HOME="$WORK" run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 0 ]
  [ "$(created_field title)" = "moko--NEWTOKEN" ]
}
