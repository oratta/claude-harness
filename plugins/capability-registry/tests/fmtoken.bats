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

  # 登録済みアイテムを FMTOKEN_TEST_REGISTERED（ref 完全一致）で表現する op スタブ
  cat >"${STUB}/op" <<'EOF'
#!/usr/bin/env bash
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

# git root 名 $1 の作業ディレクトリを作って移動する
make_repo() {
  local repo="${WORK}/$1"
  mkdir -p "$repo"
  git -C "$repo" init --quiet
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

@test "project name normalization: Buffon_ver.0.4.0 -> buffon" {
  make_repo "Buffon_ver.0.4.0"
  export FMTOKEN_TEST_REGISTERED="op://agents/buffon--github/credential"
  run "$FMTOKEN" github
  [ "$status" -eq 0 ]
  [ "$output" = "tok-secret-123" ]
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
