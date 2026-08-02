#!/usr/bin/env bats
#
# Tests for AGENTS.md <-> CLAUDE.md sync (issue #73)
#
# AGENTS.md declares itself to be identical in content to CLAUDE.md
# (except for its title line and the sync-declaration line). This guard
# fails whenever only one of the two files is edited, so the drift that
# happened in c2d20af (CLAUDE.md was lazy-loaded into docs/ pointers
# while AGENTS.md kept the old inline sections) cannot silently recur.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
  AGENTS_MD="$REPO_ROOT/AGENTS.md"
  # AGENTS.md 固有として許される行を特定するためのマーカー（同期宣言行）
  SYNC_MARKER='両ファイルを同期して保つこと'
}

# 正規化 diff:
#   - CLAUDE.md からはタイトル行（1 行目）のみを除外
#   - AGENTS.md からはタイトル行（1 行目）・同期宣言行・その直後の空行のみを除外
# それ以外の差分は一切許さない。同期宣言行が見つからなければ失敗。
check_sync() {
  local claude="$1" agents="$2" n del
  n=$(grep -nF "$SYNC_MARKER" "$agents" | head -1 | cut -d: -f1)
  [ -n "$n" ] || return 1
  del="1d;${n}d"
  if sed -n "$((n + 1))p" "$agents" | grep -q '^[[:space:]]*$'; then
    del="${del};$((n + 1))d"
  fi
  /usr/bin/diff <(tail -n +2 "$claude") <(sed "$del" "$agents")
}

@test "AGENTS.md is in sync with CLAUDE.md (normalized diff is empty)" {
  run check_sync "$CLAUDE_MD" "$AGENTS_MD"
  [ "$status" -eq 0 ]
}

@test "AGENTS.md keeps its sync-declaration line" {
  run grep -cF "$SYNC_MARKER" "$AGENTS_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "sync check fails when a body line of AGENTS.md is tampered" {
  local tampered="$BATS_TEST_TMPDIR/AGENTS.md"
  # 本文の 1 行（"## PR 運用ルール" 見出し）の末尾に 1 文字加えた改変コピーを作る
  local n
  n=$(grep -nF '## PR ' "$AGENTS_MD" | head -1 | cut -d: -f1)
  [ -n "$n" ]
  sed "${n}s/\$/x/" "$AGENTS_MD" > "$tampered"
  run check_sync "$CLAUDE_MD" "$tampered"
  [ "$status" -ne 0 ]
}

@test "sync check fails when the sync-declaration line is removed" {
  local stripped="$BATS_TEST_TMPDIR/AGENTS-no-decl.md"
  grep -vF "$SYNC_MARKER" "$AGENTS_MD" > "$stripped"
  run check_sync "$CLAUDE_MD" "$stripped"
  [ "$status" -ne 0 ]
}

@test "AGENTS.md follows the docs/ pointer refactor (c2d20af)" {
  run grep -cF 'docs/worktree-recovery.md' "$AGENTS_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -cF 'docs/ci-design.md' "$AGENTS_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
