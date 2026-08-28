#!/usr/bin/env bats
#
# spec-touch-check.sh（issue #191）— 規範を持ちうるパスへの接触と openspec/ 差分の有無を報告する。
# spec: dev-workflow-pr-review-gate「spec-touch-check スクリプトが規範パス接触と openspec 差分を報告する」

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/spec-touch-check.sh"
  cd "$BATS_TEST_TMPDIR"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "normative path touched without openspec diff -> exit 2" {
  SPEC_TOUCH_FILES=$'docs/foo.md\nlib/a.ts' run "$SCRIPT" owner/repo 1
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qx 'SPEC_TOUCH=yes'
  printf '%s\n' "$output" | grep -qx 'OPENSPEC_DIFF=no'
  printf '%s\n' "$output" | grep -qx 'docs/foo.md'
  ! printf '%s\n' "$output" | grep -qx 'lib/a.ts'
}

@test "openspec diff present -> exit 0" {
  SPEC_TOUCH_FILES=$'docs/foo.md\nopenspec/specs/x/spec.md' run "$SCRIPT" owner/repo 1
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'SPEC_TOUCH=yes'
  printf '%s\n' "$output" | grep -qx 'OPENSPEC_DIFF=yes'
}

@test "no normative path touched -> exit 0" {
  SPEC_TOUCH_FILES='lib/a.ts' run "$SCRIPT" owner/repo 1
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'SPEC_TOUCH=no'
  printf '%s\n' "$output" | grep -qx 'OPENSPEC_DIFF=no'
}

@test "default normative prefixes include CLAUDE.md and .claude/" {
  SPEC_TOUCH_FILES=$'CLAUDE.md\n.claude/skills/x/SKILL.md' run "$SCRIPT" owner/repo 1
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qx 'CLAUDE.md'
  printf '%s\n' "$output" | grep -qx '.claude/skills/x/SKILL.md'
}

@test ".spec-touch-paths replaces the defaults" {
  printf '# comment\nhandbook/\n' > .spec-touch-paths
  SPEC_TOUCH_FILES=$'docs/foo.md\nhandbook/a.md' run "$SCRIPT" owner/repo 1
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qx 'SPEC_TOUCH=yes'
  printf '%s\n' "$output" | grep -qx 'handbook/a.md'
  ! printf '%s\n' "$output" | grep -qx 'docs/foo.md'
}

@test "missing arguments -> exit 1" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
}
