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
