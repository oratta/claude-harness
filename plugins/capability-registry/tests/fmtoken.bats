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

  # 登録済みアイテムを FMTOKEN_TEST_REGISTERED（ref 完全一致。item list の title にも反映）で
  # 表現する op スタブ。FMTOKEN_TEST_EXPECT_SA が設定されていれば、OP_SERVICE_ACCOUNT_TOKEN の
  # 一致も要求する（どの経路の SA トークンが使われたかを検証するため）。
  # item create だけは FMTOKEN_TEST_EXPECT_SA_CREATE を優先して照合する
  # （--register が「二重登録判定は ro / 作成は rw」と SA を使い分けるため、経路別に検証する）
  cat >"${STUB}/op" <<'EOF'
#!/usr/bin/env bash
expect_sa="${FMTOKEN_TEST_EXPECT_SA:-}"
if [[ "$1" == "item" && "$2" == "create" && -n "${FMTOKEN_TEST_EXPECT_SA_CREATE:-}" ]]; then
  expect_sa="$FMTOKEN_TEST_EXPECT_SA_CREATE"
fi
if [[ -n "$expect_sa" && "${OP_SERVICE_ACCOUNT_TOKEN:-}" != "$expect_sa" ]]; then
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
  # exit 0 のまま解析できない出力を返す（op の出力形式が変わった / 途中で切れた状況）
  if [[ -n "${FMTOKEN_TEST_LIST_BROKEN:-}" ]]; then
    echo 'not json at all'
    exit 0
  fi
  extra=""
  if [[ -n "${FMTOKEN_TEST_REGISTERED:-}" ]]; then
    t="${FMTOKEN_TEST_REGISTERED#op://agents/}"
    t="${t%/credential}"
    extra="{\"title\":\"${t}\"},"
  fi
  echo "[${extra}{\"title\":\"proj--github\"},{\"title\":\"proj--supabase\"},{\"title\":\"other--vercel\"}]"
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
# grep の終了コードは 0=一致 / 1=不一致 / 2=エラー（ファイルが無い・読めない等）。
# 2 を 1 と一緒に「不一致」へ丸めると、露出検査の対象ログが作られていない状態を
# 「値が漏れていない」と誤判定して素通りする。読めることを先に要求し、2 は失敗にする。
refute_in_file() {
  if [[ ! -r "$2" ]]; then
    echo "refute_in_file: ${2} が読めない（露出検査が成立していない）" >&2
    return 1
  fi
  local rc=0
  grep -q -- "$1" "$2" || rc=$?
  case "$rc" in
    0) echo "unexpected match: ${1} found in ${2}" >&2; return 1 ;;
    1) return 0 ;;
    *) echo "refute_in_file: grep が異常終了した（rc=${rc} / ${2}）" >&2; return 1 ;;
  esac
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
  export FMTOKEN_TEST_EXPECT_SA="dummy-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  run bash -c "printf '%s' sekrit-value | '$FMTOKEN' --register newproj--newsvc"
  [ "$status" -eq 0 ]
  [ "$(created_field title)" = "newproj--newsvc" ]
  [[ "$output" != *"sekrit-value"* ]]
}

# 露出検査（refute_in_file）自身が素通りしないことを固定する。issue #130 の受け入れ条件
# 「値が argv に載らない」を検査する唯一の手段がこのヘルパなので、ログが欠けたときに
# 緑になる形だと検査が黙って消える。
@test "refute_in_file: unreadable log fails instead of silently passing" {
  printf 'haystack only\n' >"${WORK}/refute-probe.log"
  run refute_in_file "needle" "${WORK}/no-such-file.log"
  [ "$status" -ne 0 ]
  run refute_in_file "needle" "${WORK}/refute-probe.log"
  [ "$status" -eq 0 ]
  run refute_in_file "haystack" "${WORK}/refute-probe.log"
  [ "$status" -ne 0 ]
}

@test "--register: value goes through stdin only, never through op's argv" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  # 二重登録判定（op item list）は ro SA、作成は rw SA で走る（issue #131）
  export FMTOKEN_TEST_EXPECT_SA="dummy-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
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
  export FMTOKEN_TEST_EXPECT_SA="dummy-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
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
  export FMTOKEN_TEST_EXPECT_SA="dummy-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="file-rw-token"
  HOME="$WORK" run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 0 ]
  [ "$(created_field title)" = "moko--NEWTOKEN" ]
}

# ─── 二重登録ガード（issue #131）: 判定は ro SA・title 一致・fail-closed ───

@test "--register: duplicate title exits 47 even when rw SA cannot read (guard uses ro SA)" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  # 許可 SA を ro トークンに固定 = rw トークンでの op は全て失敗（rw に read 権が無い構成の再現）
  export FMTOKEN_TEST_EXPECT_SA="dummy-sa-token"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run bash -c "printf '%s' v | '$FMTOKEN' --register moko--TRELLO_TOKEN"
  [ "$status" -eq 47 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
  [[ "$output" == *"登録済み"* ]]
}

@test "--register: no duplicate title: create is called and exits 0" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA="dummy-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  run bash -c "printf '%s' v | '$FMTOKEN' --register moko--BRANDNEW"
  [ "$status" -eq 0 ]
  [ "$(created_field title)" = "moko--BRANDNEW" ]
}

@test "--register: ro token unresolvable anywhere exits 48 without create (fail-closed)" {
  unset OP_SERVICE_ACCOUNT_TOKEN
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  HOME="$WORK" run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 48 ]
  [[ "$output" == *"fail-closed"* ]]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
}

@test "--register: op item list failure exits 48 without create (fail-closed)" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  # ro でも rw でもない SA だけを許可 = 判定の op item list が失敗する状況
  export FMTOKEN_TEST_EXPECT_SA="some-other-token"
  run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 48 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
  # 判定不能で止めたときは、どちらを直せばいいかの選択肢まで出す
  [[ "$output" == *"claude-agents-ro.token"* ]]
  [[ "$output" == *"read 権"* ]]
}

@test "--register: unparsable item list exits 48 without create (parse failure is not 'not found')" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  export FMTOKEN_TEST_LIST_BROKEN=1
  run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 48 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
  [[ "$output" == *"解析できませんでした"* ]]
  [[ "$output" == *"claude-agents-ro.token"* ]]
}

@test "--register: ro token unresolvable message offers both remedies" {
  unset OP_SERVICE_ACCOUNT_TOKEN
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  HOME="$WORK" run bash -c "printf '%s' v | '$FMTOKEN' --register moko--NEWTOKEN"
  [ "$status" -eq 48 ]
  [[ "$output" == *"claude-agents-ro.token"* ]]
  [[ "$output" == *"read 権"* ]]
}

# ── issue #159-1: --register が末尾改行を落とさないこと ────────────────────────
#
# 既存の `--register: value containing quotes, backslashes, newlines and $ survives intact`
# はこの欠陥を検出できない。(a) 検証値に末尾改行が無く (b) 比較が
# `[ "$(created_credential)" = "$(cat file)" ]` とコマンド置換同士で、両辺が同じように
# 削れて素通りするため。だから既存ケースを拡張せず、バイト単位で見る別ケースを足す。

# op item create の stdin ログの credential 値が、ファイル $1 の中身と**バイト単位**で
# 一致することを検証する。比較を python の中で完結させるのが要点で、シェル側の
# コマンド置換を1回でも挟むと末尾改行がそこで削れて検査が無意味になる。
assert_credential_matches_file() {
  /usr/bin/python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
got=[f for f in d["fields"] if f["id"]=="credential"][0]["value"].encode()
want=open(sys.argv[2],"rb").read()
if got != want:
    sys.stderr.write("credential mismatch: got %r (%d bytes) / want %r (%d bytes)\n"
                     % (got, len(got), want, len(want)))
    sys.exit(1)' "$FMTOKEN_TEST_CREATE_STDIN_LOG" "$1"
}

# 検出器そのものが素通りしないことを固定する（refute_in_file と同じ趣旨）。
# 末尾改行の保存を検査する唯一の手段がこのヘルパなので、緩いと検査が黙って消える。
@test "assert_credential_matches_file: fails when the stored value lost its trailing newlines" {
  printf 'x\n\n' >"${WORK}/want-trailing"
  write_credential_log() {
    /usr/bin/python3 -c 'import json,sys
open(sys.argv[1],"w").write(json.dumps({"fields":[{"id":"credential","value":sys.argv[2]}]}))' \
      "$FMTOKEN_TEST_CREATE_STDIN_LOG" "$1"
  }
  write_credential_log 'x'
  run assert_credential_matches_file "${WORK}/want-trailing"
  [ "$status" -ne 0 ]
  write_credential_log 'x

'
  run assert_credential_matches_file "${WORK}/want-trailing"
  [ "$status" -eq 0 ]
}

@test "--register: trailing newlines survive (PEM-style value is stored byte for byte)" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  # 13 バイト・末尾 \n\n。`value="$(cat)"` のままだと 11 バイトで登録される
  printf 'line1\nline2\n\n' >"${WORK}/trailing-nl"
  [ "$(wc -c <"${WORK}/trailing-nl" | tr -d ' ')" -eq 13 ]
  run bash -c "'$FMTOKEN' --register newproj--pem < '${WORK}/trailing-nl'"
  [ "$status" -eq 0 ]
  assert_credential_matches_file "${WORK}/trailing-nl"
}

@test "--register: a value that is only a newline is not mistaken for empty stdin" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  printf '\n' >"${WORK}/nl-only"
  run bash -c "'$FMTOKEN' --register newproj--nlonly < '${WORK}/nl-only'"
  [ "$status" -eq 0 ]
  assert_credential_matches_file "${WORK}/nl-only"
}

# ── issue #159-2: xtrace 下で値が stderr に出ないこと ─────────────────────────
#
# `bash -x fmtoken.sh --register ...` は `+ value=<値>` として呼び出し側自身の stderr に
# 値を吐いていた。stderr は bats の $output に混ざると検査しづらいので、ファイルに落として
# refute_in_file で見る。

XTRACE_SECRET="SUPERSECRET-VALUE"

# bash -x 配下で --register を実行し、stderr を $WORK/xtrace.err に落とす。
# $1 = アイテム名。値は固定の XTRACE_SECRET を stdin から渡す。
# $2（省略可）= 呼び出し側が設定している PS4。env で渡すのは、テスト側の二重クォートで
# `${value-}` のような展開がテスト自身のシェルで潰れるのを避けるため（PS4 は環境変数として
# 渡せば bash がそのままシェル変数として取り込み、トレース行のプレフィックスに使う）。
run_register_under_xtrace() {
  local cmd="printf '%s' '${XTRACE_SECRET}' | bash -x '$FMTOKEN' --register '$1' 2>'${WORK}/xtrace.err'"
  if [[ $# -ge 2 ]]; then
    run env PS4="$2" bash -c "$cmd"
  else
    run bash -c "$cmd"
  fi
}

# 「トレース自体は出ている」ことを先に要求する。xtrace が最初から効いていない状態で
# 「値が出ていない」を確認しても、露出検査が成立していない。
assert_xtrace_active() {
  if ! grep -q -- '^+ ' "${WORK}/xtrace.err"; then
    echo "xtrace が有効になっていない（トレース行が 1 行も無い）: ${WORK}/xtrace.err" >&2
    return 1
  fi
}

@test "--register: value never reaches stderr under bash -x (success path, exit 0)" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  run_register_under_xtrace "newproj--xtok"
  [ "$status" -eq 0 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
  # 値は握りつぶされたのではなく、確かに op へ渡っている
  [ "$(created_credential)" = "$XTRACE_SECRET" ]
}

@test "--register: xtrace is restored after the secret region (not left off)" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  run_register_under_xtrace "newproj--xtrestore"
  [ "$status" -eq 0 ]
  # 値の取り込み（前半の抑止区間）より後にある二重登録ガードがトレースされている。
  # `+` の数はコマンド置換の入れ子で増える（op item list は `$(...)` の中なので `++`）ため、
  # 個数に依存しない形で見る
  grep -qE '^\++ op item list' "${WORK}/xtrace.err"
  # create（後半の抑止区間）より後もトレースされている＝最後まで off のままにしていない
  grep -q -- '^+ exit 0' "${WORK}/xtrace.err"
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
}

@test "--register: value never reaches stderr under bash -x (name violation, exit 46)" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  run_register_under_xtrace "BadName"
  [ "$status" -eq 46 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
}

@test "--register: value never reaches stderr under bash -x (already registered, exit 47)" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run_register_under_xtrace "moko--TRELLO_TOKEN"
  [ "$status" -eq 47 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
}

@test "--register: value never reaches stderr under bash -x (ro token unresolvable, exit 48)" {
  unset OP_SERVICE_ACCOUNT_TOKEN
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  HOME="$WORK" run bash -c "printf '%s' '${XTRACE_SECRET}' | bash -x '$FMTOKEN' --register moko--NEWTOKEN 2>'${WORK}/xtrace.err'"
  [ "$status" -eq 48 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
}

@test "--register: value never reaches stderr under bash -x (unparsable item list, exit 48)" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_LIST_BROKEN=1
  run_register_under_xtrace "moko--NEWTOKEN"
  [ "$status" -eq 48 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
}

# rw SA トークン自体も xtrace に出さない。値と同じ代入経路の欠陥で、
# 「--register の値は隠れたが SA トークンは出る」では塞いだことにならない。
@test "--register: rw SA token itself never reaches stderr under bash -x" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token-SECRETLY"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token-SECRETLY"
  run_register_under_xtrace "newproj--rwtrace"
  [ "$status" -eq 0 ]
  assert_xtrace_active
  refute_in_file "rw-sa-token-SECRETLY" "${WORK}/xtrace.err"
}

@test "--register: value never reaches stderr with inherited SHELLOPTS=xtrace" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  run bash -c "printf '%s' '${XTRACE_SECRET}' | env SHELLOPTS=xtrace '$FMTOKEN' --register newproj--shellopts 2>'${WORK}/xtrace.err'"
  [ "$status" -eq 0 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
  [ "$(created_credential)" = "$XTRACE_SECRET" ]
}

# ── issue #170: 値がシェル変数を経由しないこと ────────────────────────────────
#
# #159 までは stdin の値を一度 bash 変数（`value`）に載せてから python に渡していた。
# 「変数を通す」こと自体が 2 つの欠陥の根で、どちらも xtrace の on/off では塞げない。

@test "--register: a value containing NUL bytes is stored byte for byte" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  # 4 バイト。bash 変数は NUL を保持できないので、`value="$(cat; printf x)"` を経由する
  # 実装だと NUL が黙って落ちて 3 バイトで登録される。
  printf 'A\0B\n' >"${WORK}/nul-value"
  [ "$(wc -c <"${WORK}/nul-value" | tr -d ' ')" -eq 4 ]
  run bash -c "'$FMTOKEN' --register newproj--nul < '${WORK}/nul-value'"
  [ "$status" -eq 0 ]
  # 固定できるのは op item create に渡す JSON まで。1Password 側が NUL を保持するかは
  # スタブでは検証できないので、この受け入れ条件には含めない。
  assert_credential_matches_file "${WORK}/nul-value"
}

# これは #170 の欠陥の検出器ではなく（変更前の実装でも通る）、将来の回帰ガード。
# CPython は std ストリームを newline="\n" で開くので、テキストモードで読んでいた頃も
# \r\n は潰れていなかった。ただし読み手を `io.TextIOWrapper(newline=None)` や
# `open(0, "r")` に変えると universal newlines が効いて \r\n が \n に化ける。
# 「バイト単位で保存する」（#159 / #170）を名乗る以上、そこを踏んだら落ちるようにしておく。
@test "--register: CRLF line endings are not rewritten to LF" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  printf 'line1\r\nline2\r\n' >"${WORK}/crlf-value"
  [ "$(wc -c <"${WORK}/crlf-value" | tr -d ' ')" -eq 14 ]
  run bash -c "'$FMTOKEN' --register newproj--crlf < '${WORK}/crlf-value'"
  [ "$status" -eq 0 ]
  assert_credential_matches_file "${WORK}/crlf-value"
}

# 呼び出し側が fmtoken.sh の内部変数名を狙った PS4 を設定していると、`secret_end` で
# xtrace を戻したあとのトレース行のプレフィックスとして値が stderr に出ていた
# （値が変数に残っているため）。値を変数に載せなければ PS4 が何を展開しても出ない。
@test "--register: value never reaches stderr under a PS4 that expands the internal variable name" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_EXPECT_SA_CREATE="rw-sa-token"
  run_register_under_xtrace "newproj--ps4trace" '+ ${value-} '
  [ "$status" -eq 0 ]
  # PS4 を差し替えてもトレース自体は出ている（出ていなければ露出検査が成立していない）
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
  [ "$(created_credential)" = "$XTRACE_SECRET" ]
}

# 早期 exit する経路でも同じ（値の参照が終わっていても変数は残るため、旧実装は
# 47 / 48 で抜ける経路でも PS4 経由で漏れた）。
@test "--register: PS4 leak is closed on the early-exit paths too (already registered, exit 47)" {
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  export FMTOKEN_TEST_REGISTERED="op://agents/moko--TRELLO_TOKEN/credential"
  run_register_under_xtrace "moko--TRELLO_TOKEN" '+ ${value-} '
  [ "$status" -eq 47 ]
  assert_xtrace_active
  refute_in_file "$XTRACE_SECRET" "${WORK}/xtrace.err"
}

# 実装の性質そのものを固定する。上の 3 ケースは「観測されない」ことしか見ていないので、
# 将来また変数経由に戻したときに（別の抑止でたまたま緑になって）素通りしないよう、
# --register の区間に stdin 由来の代入が無いことを直接見る。
@test "--register: the register block assigns no stdin-derived shell variable" {
  local block="${WORK}/register-block.sh"
  sed -n '/^if \[\[ "$mode" == "register" \]\]/,/^fi$/p' "$FMTOKEN" >"$block"
  [ -s "$block" ]
  refute_in_file 'value=' "$block"
  refute_in_file '\$(cat' "$block"
}

# 値の取り込みを python の sys.stdin.buffer に寄せた結果、UTF-8 として解釈できない
# バイト列は「python の traceback + exit 1」ではなく、案内つきの exit 46 で止まる。
# 1Password の credential フィールドはテキストなので、ここは通してはいけない経路。
@test "--register: a non-UTF-8 value exits 46 before any op call" {
  make_repo "myproj"
  export OP_SERVICE_ACCOUNT_TOKEN_RW="rw-sa-token"
  printf '\xff\xfe\xfd' >"${WORK}/binary-value"
  run bash -c "'$FMTOKEN' --register newproj--binary < '${WORK}/binary-value'"
  [ "$status" -eq 46 ]
  [ ! -s "$FMTOKEN_TEST_CREATE_LOG" ]
  [[ "$output" == *"UTF-8"* ]]
}
