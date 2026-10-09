#!/usr/bin/env bats
# /cost の探索ループが、探索先が無い・glob が当たらないときも zsh / bash で次の候補へ進むことの検査（#913）。
# COST_MD で対象の cost.md を差し替えられる（直す前の版で落ちることの確認用）。

setup() {
  PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  COST_MD="${COST_MD:-$PLUGIN_DIR/commands/cost.md}"
  HOME_DIR="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME_DIR"
}

# cost.md の bash ブロックを取り出し、置換を模擬して（ルートは未置換のまま）、台帳は未設定にして書き出す。
# 末尾の python3 起動は偽のスクリプトの出力に差し替えるため、CL を表示する行にする。
make_block() {
  python3 -I - "$COST_MD" > "$BATS_TEST_TMPDIR/block.sh" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
block = re.search(r"```bash\n(.*?)```", text, re.S).group(1)
block = block.replace("${CLAUDE_PLUGIN_ROOT}", "${CLAUDE_PLUGIN_ROOT}").replace("${user_config.LEDGER_PATH}", "")
lines = [l for l in block.splitlines() if not l.startswith("CLAUDE_PLUGIN_OPTION_LEDGER_PATH=")]
sys.stdout.write("\n".join(lines) + '\nprintf "CL=%s\\n" "${CL-}"\n')
PY
}

run_in() {  # $1 = zsh | bash
  make_block
  case "$1" in
    zsh) HOME="$HOME_DIR" run zsh -f "$BATS_TEST_TMPDIR/block.sh" ;;
    bash) HOME="$HOME_DIR" run /bin/bash "$BATS_TEST_TMPDIR/block.sh" ;;
  esac
}

need_zsh() { command -v zsh >/dev/null || skip "zsh が無い"; }

fake() { mkdir -p "$1"; : > "$1/cost_ledger.py"; }

check_shell() {
  local sh="$1" want
  # ① plugins/installed も marketplaces も無い
  run_in "$sh"
  [ "$status" -eq 0 ] || { echo "$sh none: status $status: $output"; return 1; }
  [ "$output" = "CL=" ] || { echo "$sh none: $output"; return 1; }
  # ② 在るが空
  mkdir -p "$HOME_DIR/.claude/plugins/installed" "$HOME_DIR/.claude/plugins/marketplaces"
  run_in "$sh"
  [ "$status" -eq 0 ] || { echo "$sh empty: status $status: $output"; return 1; }
  [ "$output" = "CL=" ] || { echo "$sh empty: $output"; return 1; }
  # ③ installed だけに当たりがある（marketplaces の glob は当たらない）
  want="$HOME_DIR/.claude/plugins/installed/x/cost-ledger/scripts/cost_ledger.py"
  fake "$HOME_DIR/.claude/plugins/installed/x/cost-ledger/scripts"
  run_in "$sh"
  [ "$status" -eq 0 ] || { echo "$sh installed: status $status: $output"; return 1; }
  [ "$output" = "CL=$want" ] || { echo "$sh installed: $output"; return 1; }
  # ④ marketplaces にも当たりがあれば marketplaces が先
  want="$HOME_DIR/.claude/plugins/marketplaces/m/plugins/cost-ledger/scripts/cost_ledger.py"
  fake "$HOME_DIR/.claude/plugins/marketplaces/m/plugins/cost-ledger/scripts"
  run_in "$sh"
  [ "$status" -eq 0 ] || return 1
  [ "$output" = "CL=$want" ] || { echo "$sh both: $output"; return 1; }
}

@test "cost zsh: the search loop moves on when globs match nothing (zsh -f)" {  # zsh: 当たらなくても次へ進む
  need_zsh
  check_shell zsh
}

@test "cost zsh: the same cases behave the same in bash" {  # bash でも同じ
  check_shell bash
}

@test "cost zsh: zsh options are not changed after the block runs" {  # zsh のオプションを恒久的に変えない
  need_zsh
  make_block
  printf 'setopt | grep -c nullglob\n' >> "$BATS_TEST_TMPDIR/block.sh"
  HOME="$HOME_DIR" run zsh -f "$BATS_TEST_TMPDIR/block.sh"
  [[ "$output" == *$'\n0' ]] || { echo "$output"; return 1; }
}
