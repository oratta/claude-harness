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
  PUB="$FAKE_CLAUDE/rules/claude-harness"
  MP="$FAKE_CLAUDE/plugins/marketplaces"
}

# mk_overlay <dir名> <印の中身> [rules に置くファイル名...] — 偽の overlay を作る
mk_overlay() {
  d="$MP/$1"; mark="$2"; shift 2
  mkdir -p "$d/rules" "$d/output-styles"
  printf '%s\n' "$mark" > "$d/.harness-overlay"
  for f in "$@"; do echo "overlay $f" > "$d/rules/$f"; done
}

teardown() {
  rm -rf "$FAKE_CLAUDE"
}

@test "first run symlinks rules/*.md into claude-dir/rules" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/communication-style.md" ]
  target="$(readlink "$PUB/communication-style.md")"
  [ "$target" = "$REPO_ROOT/rules/communication-style.md" ]
}

@test "README.md is not symlinked" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -e "$PUB/README.md" ]
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
  [ -L "$PUB/communication-style.md" ]
}

@test "identical real file is replaced by a symlink (migration from copy install)" {
  mkdir -p "$PUB"
  cp "$REPO_ROOT/rules/communication-style.md" "$PUB/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/communication-style.md" ]
}

@test "diverged real file is left untouched and reported with non-zero exit" {
  mkdir -p "$PUB"
  echo "local-only content" > "$PUB/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ ! -L "$PUB/communication-style.md" ]
  grep -q "local-only content" "$PUB/communication-style.md"
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

@test "same-name symlink pointing outside harness is left untouched and reported" {
  mkdir -p "$PUB"
  ln -s /etc/hosts "$PUB/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ "$(readlink "$PUB/communication-style.md")" = "/etc/hosts" ]
}

@test "unwritable claude dir yields non-zero exit (fail-loud)" {
  touch "$FAKE_CLAUDE/blocker"
  CLAUDE_CONFIG_DIR="$FAKE_CLAUDE/blocker" run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
}

@test "dangling symlinks pointing into this harness are pruned" {
  mkdir -p "$FAKE_CLAUDE/rules"
  ln -s "$REPO_ROOT/rules/deleted-rule.md" "$FAKE_CLAUDE/rules/deleted-rule.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_CLAUDE/rules/deleted-rule.md" ]
}

# ---- 出どころごとのサブディレクトリ（#1130） ----

@test "public rules are not linked at the top level of rules" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_CLAUDE/rules/communication-style.md" ]
}

@test "old top-level symlink into public rules moves to the subdirectory" {
  mkdir -p "$FAKE_CLAUDE/rules"
  ln -s "$REPO_ROOT/rules/communication-style.md" "$FAKE_CLAUDE/rules/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/communication-style.md" ]
  [ ! -L "$FAKE_CLAUDE/rules/communication-style.md" ]
}

@test "old-position cleanup keeps real files and unrelated live or dead links outside marketplaces" {
  mkdir -p "$FAKE_CLAUDE/rules"
  echo "mine" > "$FAKE_CLAUDE/rules/mine.md"
  ln -s /etc/hosts "$FAKE_CLAUDE/rules/live.md"
  ln -s /nonexistent/dead.md "$FAKE_CLAUDE/rules/dead.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -f "$FAKE_CLAUDE/rules/mine.md" ]
  [ -L "$FAKE_CLAUDE/rules/live.md" ]
  [ -L "$FAKE_CLAUDE/rules/dead.md" ]
}

@test "no overlay and no marketplaces dir: silent and exit 0" {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- overlay ----

@test "overlay rules are linked under claude-harness/<name>" {
  mk_overlay ov-repo ov x.md
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ "$(readlink "$PUB/ov/x.md")" = "$MP/ov-repo/rules/x.md" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "overlay README.md is not linked" {
  mk_overlay ov-repo ov x.md README.md
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -e "$PUB/ov/README.md" ]
}

@test "same-name rule in public and overlay are both linked" {
  mk_overlay ov-repo ov communication-style.md
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ "$(readlink "$PUB/communication-style.md")" = "$REPO_ROOT/rules/communication-style.md" ]
  [ "$(readlink "$PUB/ov/communication-style.md")" = "$MP/ov-repo/rules/communication-style.md" ]
}

@test "overlay with invalid name is skipped with a warning and non-zero exit" {
  mk_overlay bad-repo '../x' x.md
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad-repo"* ]]
  [ ! -e "$FAKE_CLAUDE/rules/x" ]
  [ ! -e "$PUB/x.md" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "overlay with empty name is skipped with a warning and non-zero exit" {
  mk_overlay empty-repo '' x.md
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty-repo"* ]]
  [ -L "$PUB/communication-style.md" ]
}

@test "overlay name taken by a real file is skipped with a warning" {
  mkdir -p "$PUB"
  echo "file" > "$PUB/ov"
  mk_overlay ov-repo ov x.md
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -f "$PUB/ov" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "duplicate overlay names: first in directory order wins, second warned" {
  mk_overlay a-repo ov a.md
  mk_overlay b-repo ov b.md
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -L "$PUB/ov/a.md" ]
  [ ! -e "$PUB/ov/b.md" ]
  [[ "$output" == *"b-repo"* ]]
}

@test "overlay content semantics are not checked (contradicting rule is linked, exit 0)" {
  mk_overlay ov-repo ov communication-style.md
  echo "contradicts public" > "$MP/ov-repo/rules/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/ov/communication-style.md" ]
}

# ---- output styles ----

@test "overlay output style with the same name as a public one is not linked" {
  mk_overlay ov-repo ov
  echo "ov style" > "$MP/ov-repo/output-styles/readable.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ "$(readlink "$FAKE_CLAUDE/output-styles/readable.md")" = "$REPO_ROOT/output-styles/readable.md" ]
}

@test "overlay output style with a new name is linked flat" {
  mk_overlay ov-repo ov
  echo "ov style" > "$MP/ov-repo/output-styles/mine.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ "$(readlink "$FAKE_CLAUDE/output-styles/mine.md")" = "$MP/ov-repo/output-styles/mine.md" ]
}

@test "style first linked to another harness is switched to public silently" {
  mkdir -p "$FAKE_CLAUDE/output-styles" "$MP/other/output-styles"
  echo x > "$MP/other/output-styles/readable.md"
  ln -s "$MP/other/output-styles/readable.md" "$FAKE_CLAUDE/output-styles/readable.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(readlink "$FAKE_CLAUDE/output-styles/readable.md")" = "$REPO_ROOT/output-styles/readable.md" ]
}

@test "style order flip: overlay linked first, then public gains the name: public wins and overlay warned" {
  mk_overlay ov-repo ov
  echo "ov style" > "$MP/ov-repo/output-styles/readable.md"
  mkdir -p "$FAKE_CLAUDE/output-styles"
  ln -s "$MP/ov-repo/output-styles/readable.md" "$FAKE_CLAUDE/output-styles/readable.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ "$(readlink "$FAKE_CLAUDE/output-styles/readable.md")" = "$REPO_ROOT/output-styles/readable.md" ]
}

@test "style symlink outside harness and marketplaces is kept with a warning" {
  mkdir -p "$FAKE_CLAUDE/output-styles"
  ln -s /etc/hosts "$FAKE_CLAUDE/output-styles/readable.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ "$(readlink "$FAKE_CLAUDE/output-styles/readable.md")" = "/etc/hosts" ]
}

@test "identical real output style is replaced by a symlink" {
  mkdir -p "$FAKE_CLAUDE/output-styles"
  cp "$REPO_ROOT/output-styles/readable.md" "$FAKE_CLAUDE/output-styles/readable.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$FAKE_CLAUDE/output-styles/readable.md" ]
}

# ---- 掃除 ----

@test "removing an overlay prunes its dangling links and the empty directory" {
  mk_overlay ov-repo ov x.md
  sh "$SYNC" --no-pull
  rm -f "$MP/ov-repo/.harness-overlay" "$MP/ov-repo/rules/x.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -e "$PUB/ov" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "unrelated dangling link and real file under an overlay dir survive" {
  mkdir -p "$PUB/ov"
  ln -s /nonexistent/other.md "$PUB/ov/other.md"
  echo mine > "$PUB/ov/mine.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/ov/other.md" ]
  [ -f "$PUB/ov/mine.md" ]
}

@test "dangling output style link into marketplaces is pruned" {
  mkdir -p "$FAKE_CLAUDE/output-styles"
  ln -s "$MP/gone/output-styles/old.md" "$FAKE_CLAUDE/output-styles/old.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_CLAUDE/output-styles/old.md" ]
}

@test "dangling top-level rules link into marketplaces is pruned" {
  mkdir -p "$FAKE_CLAUDE/rules"
  ln -s "$MP/gone/rules/old.md" "$FAKE_CLAUDE/rules/old.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -L "$FAKE_CLAUDE/rules/old.md" ]
}
