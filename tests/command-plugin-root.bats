#!/usr/bin/env bats
#
# コマンド本文の探索ループが、本文の読み込み時に置換される形の先頭候補を使うこと（issue #793）。
#
# Claude Code がコマンド本文で絶対パスに置き換えるのは ${CLAUDE_PLUGIN_ROOT} の字面だけで、
# Bash 実行には環境変数 CLAUDE_PLUGIN_ROOT が渡らない。"${CLAUDE_PLUGIN_ROOT:+...}" の形だと
# 内側だけ置換され、外側の :+ が残って実行時に空になり、marketplace の自動更新コピーが選ばれる。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "no command body uses the \${CLAUDE_PLUGIN_ROOT:+ form" {
  run git -C "$REPO_ROOT" grep -n 'CLAUDE_PLUGIN_ROOT:+' -- 'plugins/*/commands/*.md'
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

# --- 未置換時に先頭候補がルート直下を指さないこと（issue #808） ---
#
# 置換されない経路では ${CLAUDE_PLUGIN_ROOT} が空になり、直接参照の先頭候補は /skills/develop のように
# ルート直下を指す。各ループは plugin_root="${CLAUDE_PLUGIN_ROOT}" を前に置き、空なら先頭候補を検査しない。
# ルート直下には書けないので、抽出したループ本文のファイル検査 -f "$dir/ を、一時ディレクトリを
# 接頭辞にした擬似ルートへの検査に差し替えて実行する（"/skills/develop" が擬似ルート内の同名ファイルを指す）。

# 「ファイル|何番目のループか|先頭候補の接尾辞|検査対象ファイル」
LOOPS=(
  "plugins/casting/commands/init.md|1|/templates|project.md"
  "plugins/cost-ledger/commands/cost.md|1|/scripts|cost_ledger.py"
  "plugins/dev-workflow/commands/ci-watch.md|1||references/ci-watch.md"
  "plugins/dev-workflow/commands/develop.md|1|/skills/develop|SKILL.md"
  "plugins/dev-workflow/commands/develop.md|2|/skills/issueify|SKILL.md"
  "plugins/dev-workflow/commands/memory-refresh.md|1|/skills/memory-refresh|SKILL.md"
  "plugins/worktree/commands/wt-clean.md|1|/skills/wt-clean|SKILL.md"
  "plugins/worktree/commands/wt-setup.md|1|/skills/wt-setup|SKILL.md"
)

# n 番目の「for dir in」ループ（その前にルートを変数へ読む plugin_root= / PLUGIN_ROOT= があれば、
# そこからループまでの行も含む）を標準出力へ
extract_loop() {
  awk -v n="$2" '
    /^[[:space:]]*for dir in/ { c++ }
    c == n && !on { on = 1; if (buf != "") print buf }
    on { print }
    on && /^[[:space:]]*done/ { exit }
    !on && /^[[:space:]]*(plugin_root|PLUGIN_ROOT)=/ { buf = $0; next }
    !on && /^[[:space:]]*IFS= read -r PLUGIN_ROOT/ { buf = $0; next }
    !on && buf != "" { buf = buf "\n" $0 }
    /^[[:space:]]*done/ { buf = "" }
  ' "$REPO_ROOT/$1"
}

@test "unsubstituted CLAUDE_PLUGIN_ROOT does not select a root-level first candidate" {
  local entry file n suffix target fake out
  for entry in "${LOOPS[@]}"; do
    IFS='|' read -r file n suffix target <<<"$entry"
    fake="$BATS_TEST_TMPDIR/fake-$n-$(basename "$file")"
    mkdir -p "$fake$suffix/$(dirname "$target")"
    : >"$fake$suffix/$target"
    local body
    body="$(extract_loop "$file" "$n" | sed "s#-f \"\$dir/#-f \"$fake\$dir/#")"
    [ -n "$body" ] || { echo "no loop: $file #$n"; return 1; }
    out="$(env -u CLAUDE_PLUGIN_ROOT HOME="$BATS_TEST_TMPDIR/nohome" bash -c "$body; echo \"\${CL:-}\"")"
    [ -z "$out" ] || { echo "$file #$n selected: $out"; return 1; }
  done
}

@test "substituted CLAUDE_PLUGIN_ROOT still selects the first candidate" {
  local entry file n suffix target root out
  for entry in "${LOOPS[@]}"; do
    IFS='|' read -r file n suffix target <<<"$entry"
    root="$BATS_TEST_TMPDIR/root-$n-$(basename "$file")"
    mkdir -p "$root$suffix/$(dirname "$target")"
    : >"$root$suffix/$target"
    local body
    body="$(extract_loop "$file" "$n" | sed "s#\${CLAUDE_PLUGIN_ROOT}#$root#g")"
    out="$(env -u CLAUDE_PLUGIN_ROOT HOME="$BATS_TEST_TMPDIR/nohome" bash -c "$body; echo \"\${CL:-}\"")"
    [ -n "$out" ] || { echo "$file #$n found nothing"; return 1; }
    case "$out" in "$root"*) ;; *) echo "$file #$n: $out"; return 1 ;; esac
  done
}
