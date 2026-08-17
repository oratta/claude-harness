#!/usr/bin/env bats
# rules-sync.bats — scripts/sync.sh（rules / output-styles の symlink 配線）のテスト
#
# CLAUDE_CONFIG_DIR を使い捨てディレクトリに向けて実行するので、実際の ~/.claude は
# 一切触らない。pull はネットワークに出るため --no-pull のみを検査対象とする
# （pull 部の dirty スキップ・ff-only は repo-sync.sh と同型の枯れたパターン）。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SYNC="$REPO_ROOT/scripts/sync.sh"
  FAKE_CLAUDE="$(mktemp -d)"
  export CLAUDE_CONFIG_DIR="$FAKE_CLAUDE"
}

teardown() {
  rm -rf "$FAKE_CLAUDE"
}

@test "first run symlinks rules/*.md into claude-dir/rules" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$FAKE_CLAUDE/rules/communication-style.md" ]
  target="$(readlink "$FAKE_CLAUDE/rules/communication-style.md")"
  [ "$target" = "$REPO_ROOT/rules/communication-style.md" ]
}

@test "README.md is not symlinked" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_CLAUDE/rules/README.md" ]
}

@test "output-styles/readable.md is symlinked too" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$FAKE_CLAUDE/output-styles/readable.md" ]
}

@test "idempotent: second run succeeds and keeps symlinks" {
  sh "$SYNC" --no-pull
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$FAKE_CLAUDE/rules/communication-style.md" ]
}

@test "identical real file is replaced by a symlink (migration from copy install)" {
  mkdir -p "$FAKE_CLAUDE/rules"
  cp "$REPO_ROOT/rules/communication-style.md" "$FAKE_CLAUDE/rules/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$FAKE_CLAUDE/rules/communication-style.md" ]
}

@test "diverged real file is left untouched and reported with non-zero exit" {
  mkdir -p "$FAKE_CLAUDE/rules"
  echo "local-only content" > "$FAKE_CLAUDE/rules/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ ! -L "$FAKE_CLAUDE/rules/communication-style.md" ]
  grep -q "local-only content" "$FAKE_CLAUDE/rules/communication-style.md"
}

@test "unrelated local files and symlinks survive" {
  mkdir -p "$FAKE_CLAUDE/rules"
  echo "local rule" > "$FAKE_CLAUDE/rules/my-local-rule.md"
  ln -s /etc/hosts "$FAKE_CLAUDE/rules/other-link.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -f "$FAKE_CLAUDE/rules/my-local-rule.md" ]
  [ -L "$FAKE_CLAUDE/rules/other-link.md" ]
}

@test "dangling symlinks pointing into this harness are pruned" {
  mkdir -p "$FAKE_CLAUDE/rules"
  ln -s "$REPO_ROOT/rules/deleted-rule.md" "$FAKE_CLAUDE/rules/deleted-rule.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_CLAUDE/rules/deleted-rule.md" ]
}
