#!/usr/bin/env bats
# /statusline:setupの探索ループが、探索先が無い・glob が当たらないときも zsh / bash で止まらないことの検査（#938）。
# 文書から `for dir in` を含む bash ブロックを取り出して実行する（手本: plugins/cost-ledger/tests/cost-command-zsh.bats）。
# SEARCH_DOCS（改行区切りのパス）で対象の文書を差し替えられる（直す前の版で落ちることの確認用）。
# zsh が無い環境（CI の ubuntu-latest など）では zsh の検査は skip になる。

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  DOCS="${SEARCH_DOCS:-plugins/statusline/commands/setup.md}"
  HOME_DIR="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME_DIR"
  # 既定の対象（SEARCH_DOCS 未設定）のときは、取り出すブロック数を期待値で固定する。差し替えのときは固定しない。
  if [ -n "${SEARCH_DOCS:-}" ]; then EXPECT_N=; else EXPECT_N=1; fi
}

need_zsh() { command -v zsh >/dev/null || skip "zsh が無い"; }

# 文書から `for dir in` を含む bash ブロックを取り出し、block-N.sh（本体）と block-N.meta（installed 側の相対パスと目印のファイル）に書く。
# 取り出せたブロック数を出力する。
extract_blocks() {
  python3 -I - "$BATS_TEST_TMPDIR" "$REPO_DIR" "$DOCS" "$EXPECT_N" <<'PY'
import re, sys, textwrap
out, repo, docs, expect = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
n = 0
for rel in docs.replace("\\n", "\n").split("\n"):
    if not rel:
        continue
    path = rel if rel.startswith("/") else repo + "/" + rel
    text = open(path, encoding="utf-8").read()
    before = n
    for block in re.findall(r"```bash\n(.*?)```", text, re.S):
        if "for dir in" not in block:
            continue
        block = textwrap.dedent(block)
        inst = re.search(r"~/\.claude/plugins/installed/\*/([^\s;\\]+)", block).group(1)
        mark = re.search(r'-f "\$dir/([^"]+)"', block)
        rootm = re.search(r'"\$\{(?:plugin_root:\+\$plugin_root|CLAUDE_PLUGIN_ROOT:-)([^"}]*)\}"', block)
        n += 1
        open("%s/block-%d.sh" % (out, n), "w", encoding="utf-8").write(block)
        open("%s/block-%d.meta" % (out, n), "w", encoding="utf-8").write(inst + "\n" + (mark.group(1) if mark else "") + "\n" + ("1" if rootm else "0") + "\n" + (rootm.group(1) if rootm else "") + "\n")
    if n == before:
        print("no search block: " + rel)
        sys.exit(1)
if expect and n != int(expect):
    print("block count %d != expected %s" % (n, expect))
    sys.exit(1)
print(n)
PY
}

run_block() {  # $1 = zsh | bash, $2 = ブロックの番号
  case "$1" in
    zsh) HOME="$HOME_DIR" run env -u CLAUDE_PLUGIN_ROOT zsh -f "$BATS_TEST_TMPDIR/block-$2.sh" ;;
    bash) HOME="$HOME_DIR" run env -u CLAUDE_PLUGIN_ROOT /bin/bash "$BATS_TEST_TMPDIR/block-$2.sh" ;;
  esac
}

# $1 = zsh | bash（直した後は bash・zsh とも探索が空振りでも終了コード 0。origin/main の版は bash で rc=1 が残る）。全ブロックについて、候補なし・空の探索先・installed だけに当たりの 3 通りを見る。
check_shell() {
  local sh="$1" n i inst mark
  n="$(extract_blocks)" || { echo "$n"; return 1; }
  [ "$n" -ge 1 ] || { echo "ブロックを取り出せなかった: $n"; return 1; }
  for i in $(seq 1 "$n"); do
    [ -s "$BATS_TEST_TMPDIR/block-$i.sh" ] || { echo "block-$i が空"; return 1; }
    grep -q 'for dir in' "$BATS_TEST_TMPDIR/block-$i.sh" || { echo "block-$i に for が無い"; return 1; }
    inst="$(sed -n 1p "$BATS_TEST_TMPDIR/block-$i.meta")"
    mark="$(sed -n 2p "$BATS_TEST_TMPDIR/block-$i.meta")"
    rm -rf "$HOME_DIR/.claude"
    # ① ~/.claude/plugins が無い
    run_block "$sh" "$i"
    [ "$status" -eq 0 ] || { echo "$sh $i none: status $status: $output"; return 1; }
    [ -z "$output" ] || { echo "$sh $i none: $output"; return 1; }
    # ② 在るが空
    mkdir -p "$HOME_DIR/.claude/plugins/installed" "$HOME_DIR/.claude/plugins/marketplaces"
    run_block "$sh" "$i"
    [ "$status" -eq 0 ] || { echo "$sh $i empty: status $status: $output"; return 1; }
    [ -z "$output" ] || { echo "$sh $i empty: $output"; return 1; }
    # ③ installed だけに当たりがある（marketplaces の glob は当たらない）
    mkdir -p "$HOME_DIR/.claude/plugins/installed/x/$inst"
    if [ -n "$mark" ]; then mkdir -p "$(dirname "$HOME_DIR/.claude/plugins/installed/x/$inst/$mark")"; : > "$HOME_DIR/.claude/plugins/installed/x/$inst/$mark"; fi
    run_block "$sh" "$i"
    [ "$status" -eq 0 ] || { echo "$sh $i installed: status $status: $output"; return 1; }
    [[ "$output" == *"/installed/x/$inst"* ]] || { echo "$sh $i installed: $output"; return 1; }
  done
}

@test "statusline setup zsh: the search loop moves on when globs match nothing (zsh -f)" {  # zsh: 当たらなくても止まらない
  need_zsh
  check_shell zsh || return 1
}

@test "statusline setup zsh: the same cases behave the same in bash" {  # bash でも同じ
  check_shell bash || return 1
}

@test "statusline setup zsh: zsh and bash print the same result for the same input" {  # zsh と bash の出力が一致
  need_zsh
  local n i inst mark z b
  n="$(extract_blocks)" || { echo "$n"; return 1; }
  [ "$n" -ge 1 ] || { echo "ブロックを取り出せなかった: $n"; return 1; }
  for i in $(seq 1 "$n"); do
    inst="$(sed -n 1p "$BATS_TEST_TMPDIR/block-$i.meta")"
    mark="$(sed -n 2p "$BATS_TEST_TMPDIR/block-$i.meta")"
    mkdir -p "$HOME_DIR/.claude/plugins/installed/x/$inst"
    if [ -n "$mark" ]; then mkdir -p "$(dirname "$HOME_DIR/.claude/plugins/installed/x/$inst/$mark")"; : > "$HOME_DIR/.claude/plugins/installed/x/$inst/$mark"; fi
    run_block zsh "$i"; z="$output"
    run_block bash "$i"; b="$output"
    [ -n "$z" ] || { echo "block-$i: zsh の出力が空"; return 1; }
    [ "$z" = "$b" ] || { echo "block-$i: zsh=$z bash=$b"; return 1; }
  done
}

@test "statusline setup zsh: nullglob stays off when it was off before the block runs" {  # 元が無効なら無効のまま
  need_zsh
  local n i
  n="$(extract_blocks)" || { echo "$n"; return 1; }
  [ "$n" -ge 1 ] || { echo "ブロックを取り出せなかった: $n"; return 1; }
  for i in $(seq 1 "$n"); do
    { cat "$BATS_TEST_TMPDIR/block-$i.sh"; printf 'setopt | grep -c nullglob\n'; } >| "$BATS_TEST_TMPDIR/off.sh"
    HOME="$HOME_DIR" run env -u CLAUDE_PLUGIN_ROOT zsh -f "$BATS_TEST_TMPDIR/off.sh"
    [[ "$output" == "0" || "$output" == *$'\n0' ]] || { echo "block-$i: $output"; return 1; }
  done
}

@test "statusline setup zsh: a nullglob the user already had is still on after the block runs" {  # 元から有効なら有効のまま
  need_zsh
  local n i
  n="$(extract_blocks)" || { echo "$n"; return 1; }
  [ "$n" -ge 1 ] || { echo "ブロックを取り出せなかった: $n"; return 1; }
  for i in $(seq 1 "$n"); do
    { printf 'setopt nullglob\n'; cat "$BATS_TEST_TMPDIR/block-$i.sh"; printf 'setopt | grep -c nullglob\n'; } >| "$BATS_TEST_TMPDIR/on.sh"
    HOME="$HOME_DIR" run env -u CLAUDE_PLUGIN_ROOT zsh -f "$BATS_TEST_TMPDIR/on.sh"
    [ "$status" -eq 0 ] || { echo "block-$i: status $status: $output"; return 1; }
    [[ "$output" == "1" || "$output" == *$'\n1' ]] || { echo "block-$i: $output"; return 1; }
  done
}

@test "statusline setup zsh: a given plugin root is chosen when the later globs match nothing" {  # ルートが有効で glob が当たらない（#938 の再現）
  need_zsh
  local n i mark sub root z b hit=0
  n="$(extract_blocks)" || { echo "$n"; return 1; }
  for i in $(seq 1 "$n"); do
    [ "$(sed -n 3p "$BATS_TEST_TMPDIR/block-$i.meta")" = 1 ] || continue
    hit=$((hit + 1))
    mark="$(sed -n 2p "$BATS_TEST_TMPDIR/block-$i.meta")"
    sub="$(sed -n 4p "$BATS_TEST_TMPDIR/block-$i.meta")"
    root="$BATS_TEST_TMPDIR/root-$i"
    mkdir -p "$root$sub"
    if [ -n "$mark" ]; then mkdir -p "$(dirname "$root$sub/$mark")"; : > "$root$sub/$mark"; fi
    HOME="$HOME_DIR" run env CLAUDE_PLUGIN_ROOT="$root" zsh -f "$BATS_TEST_TMPDIR/block-$i.sh"
    [ "$status" -eq 0 ] || { echo "block-$i zsh: status $status: $output"; return 1; }
    z="$output"
    HOME="$HOME_DIR" run env CLAUDE_PLUGIN_ROOT="$root" /bin/bash "$BATS_TEST_TMPDIR/block-$i.sh"
    [ "$status" -eq 0 ] || { echo "block-$i bash: status $status: $output"; return 1; }
    b="$output"
    [[ "$z" == "$root$sub"* ]] || { echo "block-$i: ルート側が選ばれていない: $z"; return 1; }
    [ "$z" = "$b" ] || { echo "block-$i: zsh=$z bash=$b"; return 1; }
  done
  [ "$hit" -ge 1 ] || { echo "ルートを受けるブロックが無い"; return 1; }
}
