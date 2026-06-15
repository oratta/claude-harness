#!/usr/bin/env bats
#
# Tests for plugins/longrun/scripts/openspec-preflight.sh
#
# Covers exec Step 0 preflight detection (change-1: openspec-degradation):
#   - npx openspec 解決不可 -> NO_CLI
#   - openspec/ 不在        -> NO_INIT
#   - 両方 OK               -> OK
#   - 既存 openspec あり repo で副作用なし（縮退マーカー・openspec/ への書き込みなし）
#
# Detection contract (see plugins/longrun/docs/openspec-cli-verification.md §5):
#   CLI 解決 = `command -v openspec` OR `npx --no-install openspec --version`
#   init     = git root 直下の openspec/ ディレクトリ存在
#
# Stubbing strategy:
#   - command -v openspec: PATH を制御し、ダミー openspec を置くか除く
#   - npx:                 OPENSPEC_PREFLIGHT_NPX_CMD で stub コマンドを注入
#   - repo:                位置引数 $1 で対象 repo dir を渡す（テスト容易性）

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  lr_make_tmpdir
  PREFLIGHT_SH="${PLUGIN_DIR}/scripts/openspec-preflight.sh"
  lr_require_file "$PREFLIGHT_SH"

  # Sandbox bin dir to control whether `openspec` is on PATH.
  STUB_BIN="${LR_TEST_TMPDIR}/bin"
  mkdir -p "$STUB_BIN"

  # An npx stub that FAILS (no openspec resolvable) by default.
  NPX_FAIL="${LR_TEST_TMPDIR}/npx-fail.sh"
  cat > "$NPX_FAIL" <<'EOS'
#!/usr/bin/env bash
# Simulate `npx --no-install openspec --version` failing to resolve.
exit 1
EOS
  chmod +x "$NPX_FAIL"

  # An npx stub that SUCCEEDS (openspec resolvable via npx, prints a version).
  NPX_OK="${LR_TEST_TMPDIR}/npx-ok.sh"
  cat > "$NPX_OK" <<'EOS'
#!/usr/bin/env bash
echo "0.23.0"
exit 0
EOS
  chmod +x "$NPX_OK"

  # A dummy `openspec` placed on STUB_BIN to simulate global resolution.
  cat > "${STUB_BIN}/openspec" <<'EOS'
#!/usr/bin/env bash
echo "1.2.0"
EOS
  chmod +x "${STUB_BIN}/openspec"
}

teardown() {
  lr_teardown_tmpdir
}

# Run preflight with a minimal PATH (no global openspec unless we add STUB_BIN).
run_preflight() {
  local repo="$1"; shift
  run env \
    PATH="/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_FAIL" \
    "$@" \
    bash "$PREFLIGHT_SH" "$repo"
}

# ---------------------------------------------------------------------------
# NO_CLI: neither global openspec nor npx resolves
# ---------------------------------------------------------------------------

@test "preflight: no global openspec + npx fails -> NO_CLI" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  mkdir -p "${LR_TEST_TMPDIR}/repo/openspec"   # even with openspec/, CLI gate wins
  run_preflight "${LR_TEST_TMPDIR}/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "NO_CLI" ]
}

@test "preflight: NO_CLI takes priority over NO_INIT" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  # no openspec/ dir AND no CLI -> still NO_CLI (CLI checked first)
  run_preflight "${LR_TEST_TMPDIR}/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "NO_CLI" ]
}

# ---------------------------------------------------------------------------
# NO_INIT: CLI resolves but openspec/ missing
# ---------------------------------------------------------------------------

@test "preflight: global openspec present + no openspec/ -> NO_INIT" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  run env \
    PATH="${STUB_BIN}:/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_FAIL" \
    bash "$PREFLIGHT_SH" "${LR_TEST_TMPDIR}/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "NO_INIT" ]
}

@test "preflight: npx resolves + no openspec/ -> NO_INIT" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  run env \
    PATH="/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_OK" \
    bash "$PREFLIGHT_SH" "${LR_TEST_TMPDIR}/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "NO_INIT" ]
}

# ---------------------------------------------------------------------------
# OK: CLI resolves AND openspec/ exists
# ---------------------------------------------------------------------------

@test "preflight: global openspec + openspec/ exists -> OK" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  mkdir -p "${LR_TEST_TMPDIR}/repo/openspec"
  run env \
    PATH="${STUB_BIN}:/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_FAIL" \
    bash "$PREFLIGHT_SH" "${LR_TEST_TMPDIR}/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "preflight: npx resolves + openspec/ exists -> OK (npx-only env)" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  mkdir -p "${LR_TEST_TMPDIR}/repo/openspec"
  run env \
    PATH="/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_OK" \
    bash "$PREFLIGHT_SH" "${LR_TEST_TMPDIR}/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

# ---------------------------------------------------------------------------
# 副作用なし: 既存 openspec あり repo で書き込みが発生しない（回帰防止）
# ---------------------------------------------------------------------------

@test "preflight: OK path does not create .degraded-mode marker" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  mkdir -p "${LR_TEST_TMPDIR}/repo/openspec"
  run env \
    PATH="${STUB_BIN}:/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_FAIL" \
    bash "$PREFLIGHT_SH" "${LR_TEST_TMPDIR}/repo"
  [ "$output" = "OK" ]
  [ ! -e "${LR_TEST_TMPDIR}/repo/.degraded-mode" ]
}

@test "preflight: does not write into openspec/ on any path" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  mkdir -p "${LR_TEST_TMPDIR}/repo/openspec"
  before="$(find "${LR_TEST_TMPDIR}/repo/openspec" -type f | sort)"
  run env \
    PATH="${STUB_BIN}:/usr/bin:/bin" \
    OPENSPEC_PREFLIGHT_NPX_CMD="$NPX_FAIL" \
    bash "$PREFLIGHT_SH" "${LR_TEST_TMPDIR}/repo"
  after="$(find "${LR_TEST_TMPDIR}/repo/openspec" -type f | sort)"
  [ "$before" = "$after" ]
}

@test "preflight: NO_CLI path creates no marker and no openspec/ writes" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  run_preflight "${LR_TEST_TMPDIR}/repo"
  [ "$output" = "NO_CLI" ]
  [ ! -e "${LR_TEST_TMPDIR}/repo/.degraded-mode" ]
  [ ! -d "${LR_TEST_TMPDIR}/repo/openspec" ]
}

# ---------------------------------------------------------------------------
# repo 引数省略時は git root にフォールバックする
# ---------------------------------------------------------------------------

@test "preflight: defaults to git toplevel when no repo arg given" {
  lr_make_git_repo "${LR_TEST_TMPDIR}/repo"
  mkdir -p "${LR_TEST_TMPDIR}/repo/openspec"
  run bash -c "cd '${LR_TEST_TMPDIR}/repo' && PATH='${STUB_BIN}:/usr/bin:/bin' OPENSPEC_PREFLIGHT_NPX_CMD='$NPX_FAIL' bash '$PREFLIGHT_SH'"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}
