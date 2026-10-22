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

# allow <dir名> — 許可ファイルに 1 行足す
allow() {
  mkdir -p "$FAKE_CLAUDE"
  printf '%s\n' "$1" >> "$FAKE_CLAUDE/harness-overlays"
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

@test "old top-level link stays when the subdirectory cannot be created" {
  mkdir -p "$FAKE_CLAUDE/rules"
  echo "blocker" > "$PUB"
  ln -s "$REPO_ROOT/rules/communication-style.md" "$FAKE_CLAUDE/rules/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -L "$FAKE_CLAUDE/rules/communication-style.md" ]
  [ "$(readlink "$FAKE_CLAUDE/rules/communication-style.md")" = "$REPO_ROOT/rules/communication-style.md" ]
}

@test "old top-level link stays when the new position holds a diverged real file" {
  mkdir -p "$PUB"
  echo "local-only content" > "$PUB/communication-style.md"
  ln -s "$REPO_ROOT/rules/communication-style.md" "$FAKE_CLAUDE/rules/communication-style.md"
  ln -s "$REPO_ROOT/rules/git-commit-policy.md" "$FAKE_CLAUDE/rules/git-commit-policy.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -L "$FAKE_CLAUDE/rules/communication-style.md" ]
  grep -q "local-only content" "$PUB/communication-style.md"
  [ -L "$PUB/git-commit-policy.md" ]
  [ ! -L "$FAKE_CLAUDE/rules/git-commit-policy.md" ]
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
  allow ov-repo
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ "$(readlink "$PUB/ov/x.md")" = "$MP/ov-repo/rules/x.md" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "overlay README.md is not linked" {
  mk_overlay ov-repo ov x.md README.md
  allow ov-repo
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ ! -e "$PUB/ov/README.md" ]
}

@test "same-name rule in public and overlay are both linked" {
  mk_overlay ov-repo ov communication-style.md
  allow ov-repo
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ "$(readlink "$PUB/communication-style.md")" = "$REPO_ROOT/rules/communication-style.md" ]
  [ "$(readlink "$PUB/ov/communication-style.md")" = "$MP/ov-repo/rules/communication-style.md" ]
}

@test "overlay with invalid name is skipped with a warning and non-zero exit" {
  mk_overlay bad-repo '../x' x.md
  allow bad-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"bad-repo"* ]]
  [ ! -e "$FAKE_CLAUDE/rules/x" ]
  [ ! -e "$PUB/x.md" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "overlay with empty name is skipped with a warning and non-zero exit" {
  mk_overlay empty-repo '' x.md
  allow empty-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty-repo"* ]]
  [ -L "$PUB/communication-style.md" ]
}

@test "overlay name taken by a real file is skipped with a warning" {
  mkdir -p "$PUB"
  echo "file" > "$PUB/ov"
  mk_overlay ov-repo ov x.md
  allow ov-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -f "$PUB/ov" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "duplicate overlay names: first in directory order wins, second warned" {
  mk_overlay a-repo ov a.md
  allow a-repo
  mk_overlay b-repo ov b.md
  allow b-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -L "$PUB/ov/a.md" ]
  [ ! -e "$PUB/ov/b.md" ]
  [[ "$output" == *"b-repo"* ]]
}

@test "duplicate overlay names: lexical order wins even when allowed in reverse" {
  mk_overlay a-repo ov a.md
  mk_overlay b-repo ov b.md
  allow b-repo
  allow a-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -L "$PUB/ov/a.md" ]
  [ ! -e "$PUB/ov/b.md" ]
  [[ "$output" == *"b-repo"* ]]
}

@test "overlay content semantics are not checked (contradicting rule is linked, exit 0)" {
  mk_overlay ov-repo ov communication-style.md
  allow ov-repo
  echo "contradicts public" > "$MP/ov-repo/rules/communication-style.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/ov/communication-style.md" ]
}

# ---- output styles ----

@test "overlay output style with the same name as a public one is not linked" {
  mk_overlay ov-repo ov
  allow ov-repo
  echo "ov style" > "$MP/ov-repo/output-styles/readable.md"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ "$(readlink "$FAKE_CLAUDE/output-styles/readable.md")" = "$REPO_ROOT/output-styles/readable.md" ]
}

@test "overlay output style with a new name is linked flat" {
  mk_overlay ov-repo ov
  allow ov-repo
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
  allow ov-repo
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
  allow ov-repo
  sh "$SYNC" --no-pull
  rm -rf "$MP/ov-repo"
  rm -f "$FAKE_CLAUDE/harness-overlays"
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

# ---- 許可ファイル（#1130 セキュリティ指摘） ----

@test "marketplace with a marker but not allowed is not linked" {
  mk_overlay ov-repo ov x.md
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$PUB/ov" ]
}

@test "marketplace not listed in a non-empty allow file is not linked" {
  mk_overlay ov-repo ov x.md
  mk_overlay other-repo other y.md
  allow other-repo
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/other/y.md" ]
  [ ! -e "$PUB/ov" ]
}

@test "allow file with only comments and blank lines: silent and exit 0" {
  mk_overlay ov-repo ov x.md
  printf '# comment\n\n   \n# another\n' > "$FAKE_CLAUDE/harness-overlays"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$PUB/ov" ]
}

@test "allow file comments and blank lines are ignored next to a real entry" {
  mk_overlay ov-repo ov x.md
  printf '# c\n\nov-repo\n' > "$FAKE_CLAUDE/harness-overlays"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -L "$PUB/ov/x.md" ]
}

@test "allowed directory that does not exist: warning and non-zero, alone" {
  allow nowhere
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"nowhere"* ]]
  [ -L "$PUB/communication-style.md" ]
}

@test "allowed directory without a marker: warning and non-zero, alone" {
  mkdir -p "$MP/nomark/rules"
  echo r > "$MP/nomark/rules/x.md"
  allow nomark
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"nomark"* ]]
  [ ! -e "$PUB/x.md" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "allowed overlay with an empty marker name: warning and non-zero, alone" {
  mk_overlay e-repo '' x.md
  allow e-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"e-repo"* ]]
  [ -L "$PUB/communication-style.md" ]
}

@test "allowed overlay with an invalid marker name: warning and non-zero, alone" {
  mk_overlay b-repo 'Bad Name' x.md
  allow b-repo
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [ -L "$PUB/communication-style.md" ]
}

@test "invalid allow lines are skipped with a warning and non-zero exit" {
  mk_overlay ok-repo ok x.md
  printf '../x\n.hidden\na/b\nok-repo\n' > "$FAKE_CLAUDE/harness-overlays"
  run sh "$SYNC" --no-pull
  [ "$status" -ne 0 ]
  [[ "$output" == *"../x"* ]]
  [ -L "$PUB/ok/x.md" ]
  [ ! -e "$FAKE_CLAUDE/rules/x" ]
}

# 使い捨ての偽の harness（git リポジトリ・origin 無し）に sync.sh を写し、--no-pull なしで走らせる。
# 本物の作業ツリーには pull を走らせない
mk_fake_harness() {
  FH="$FAKE_CLAUDE/fake-harness"
  mkdir -p "$FH/scripts" "$FH/rules"
  cp "$SYNC" "$FH/scripts/sync.sh"
  echo r > "$FH/rules/r.md"
  git -C "$FH" init -q
  git -C "$FH" add -A
  git -C "$FH" -c user.email=t@example.com -c user.name=t commit -q -m init
}

@test "pull does not touch a marketplace that is not allowed" {
  mk_fake_harness
  mk_overlay ov-repo ov x.md
  git -C "$MP/ov-repo" init -q
  git -C "$MP/ov-repo" remote add origin /nonexistent/remote.git
  run sh -c "sh '$FH/scripts/sync.sh' 2>&1"
  [[ "$output" != *"ov-repo"* ]]
  [ ! -e "$PUB/ov" ]
}

@test "pull is attempted for an allowed marketplace" {
  mk_fake_harness
  mk_overlay ov-repo ov x.md
  allow ov-repo
  git -C "$MP/ov-repo" init -q
  git -C "$MP/ov-repo" remote add origin /nonexistent/remote.git
  run sh -c "sh '$FH/scripts/sync.sh' 2>&1"
  [[ "$output" == *"ov-repo"* ]]
  [ -L "$PUB/ov/x.md" ]
}

# ── 許可の取り消し（許可から外した overlay の symlink は、リンク先が残っていても消える）──

mk_styled_overlay() {
  # <dir名> <名前> [style名] — rules x.md と output-styles ovstyle.md を持つ overlay
  mk_overlay "$1" "$2" x.md
  echo "overlay style" > "$MP/$1/output-styles/${3:-ovstyle}.md"
}

@test "revoked overlay: links removed even though link targets still exist" {
  mk_styled_overlay ov-repo ov
  allow ov-repo
  sh "$SYNC" --no-pull
  [ -L "$PUB/ov/x.md" ]
  [ -L "$FAKE_CLAUDE/output-styles/ovstyle.md" ]
  : > "$FAKE_CLAUDE/harness-overlays"
  run sh -c "sh '$SYNC' --no-pull 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -d "$MP/ov-repo/rules" ]
  [ ! -e "$PUB/ov/x.md" ] && [ ! -L "$PUB/ov/x.md" ]
  [ ! -L "$FAKE_CLAUDE/output-styles/ovstyle.md" ]
  [ ! -d "$PUB/ov" ]
}

@test "revoked overlay: public links stay" {
  mk_styled_overlay ov-repo ov
  allow ov-repo
  sh "$SYNC" --no-pull
  : > "$FAKE_CLAUDE/harness-overlays"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/communication-style.md" ]
  [ -L "$FAKE_CLAUDE/output-styles/readable.md" ]
}

@test "revoking one of two overlays keeps the other" {
  mk_styled_overlay ov-a oa sa
  mk_styled_overlay ov-b ob sb
  allow ov-a
  allow ov-b
  sh "$SYNC" --no-pull
  [ -L "$PUB/oa/x.md" ] && [ -L "$PUB/ob/x.md" ]
  printf '%s\n' ov-a > "$FAKE_CLAUDE/harness-overlays"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/oa/x.md" ]
  [ ! -L "$PUB/ob/x.md" ]
  [ ! -d "$PUB/ob" ]
  [ -L "$FAKE_CLAUDE/output-styles/sa.md" ]
  [ ! -L "$FAKE_CLAUDE/output-styles/sb.md" ]
}

@test "revocation leaves symlinks outside marketplaces and real files alone" {
  mkdir -p "$PUB/ov" "$FAKE_CLAUDE/output-styles"
  ln -s /etc/hosts "$PUB/ov/h.md"
  echo real > "$PUB/ov/real.md"
  ln -s /etc/hosts "$FAKE_CLAUDE/output-styles/h.md"
  echo real > "$FAKE_CLAUDE/output-styles/real.md"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -L "$PUB/ov/h.md" ] && [ -f "$PUB/ov/real.md" ]
  [ -L "$FAKE_CLAUDE/output-styles/h.md" ] && [ -f "$FAKE_CLAUDE/output-styles/real.md" ]
}

@test "deleting the allow file removes the traces of a former overlay" {
  mk_styled_overlay ov-repo ov
  allow ov-repo
  sh "$SYNC" --no-pull
  rm -f "$FAKE_CLAUDE/harness-overlays"
  run sh -c "sh '$SYNC' --no-pull 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -L "$PUB/ov/x.md" ] && [ ! -d "$PUB/ov" ]
  [ ! -L "$FAKE_CLAUDE/output-styles/ovstyle.md" ]
  [ -L "$PUB/communication-style.md" ]
}

@test "never-overlaid environment: empty stderr and exit 0 after revocation cleanup" {
  run sh -c "sh '$SYNC' --no-pull 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
