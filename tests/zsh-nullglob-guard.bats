#!/usr/bin/env bats
#
# zsh 向け nullglob 退避が、ZSH_VERSION を export した bash で `setopt: command not found` を
# 出さないこと（issue #955）。
#
# 各コマンド・エージェント本文の探索ブロック（`<X>_NG=; if [ -n "${ZSH_VERSION:-}" ] ...` の行から
# `unsetopt nullglob` の行まで）を抜き出して実行する。bash には setopt が無いので、
# 条件に `command -v setopt` が無いと `[[ ! -o nullglob ]]` と setopt が bash で評価され、
# 標準エラーに警告が出る。unsetopt 側は `$X_NG` が空のままなら評価されないので条件の変更は要らない。

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# 抜き出したブロックを 1 つずつ $BATS_TEST_TMPDIR/block.<n>.sh に書く。本数を標準出力へ
extract_blocks() {
  git -C "$ROOT" grep -l 'ZSH_VERSION' -- plugins ':!*/changes/*' | while IFS= read -r f; do
    awk -v out="$BATS_TEST_TMPDIR" -v base="$(echo "$f" | tr '/' '_')" '
      /_NG=; if \[ -n "\$\{ZSH_VERSION:-\}" \]/ { n++; on=1 }
      on { sub(/^ +/, ""); print > (out "/block." base "." n ".sh") }
      on && /unsetopt nullglob/ { on=0 }
    ' "$ROOT/$f"
  done
}

@test "every ZSH_VERSION line guards setopt with command -v" {
  run git -C "$ROOT" grep -n 'ZSH_VERSION' -- plugins ':!*/changes/*'
  [ "$status" -eq 0 ] || return 1
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 11 ] || { echo "$output"; return 1; }
  run bash -c 'printf "%s\n" "$1" | grep -vc "command -v setopt >/dev/null 2>&1 && \[\[ ! -o nullglob \]\]"' _ "$output"
  [ "$output" = "0" ] || return 1
}

@test "each extracted block runs under bash with ZSH_VERSION exported: no stderr, exit 0" {
  extract_blocks
  count=0
  for b in "$BATS_TEST_TMPDIR"/block.*.sh; do
    count=$((count + 1))
    run bash -c 'ZSH_VERSION=5.9 HOME="$2" bash "$1" 2>"$2/err"; echo "exit=$?"; cat "$2/err"' _ "$b" "$BATS_TEST_TMPDIR"
    [ "$output" = "exit=0" ] || { echo "$b: $output"; return 1; }
  done
  [ "$count" -eq 11 ] || { echo "blocks: $count"; return 1; }
}

@test "under zsh the extracted blocks still set nullglob and restore it afterwards" {
  command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
  extract_blocks
  for b in "$BATS_TEST_TMPDIR"/block.*.sh; do
    # 1 行目（退避の行）の直後に状態を表示する行を挟み、ブロック全体を実行して最後の状態も見る
    { head -n1 "$b"; echo 'if [[ -o nullglob ]]; then echo "during: on"; else echo "during: off"; fi'; tail -n +2 "$b"; } > "$BATS_TEST_TMPDIR/probe.sh"
    run zsh -c '
      HOME="$2"
      if [[ -o nullglob ]]; then echo "before: on"; else echo "before: off"; fi
      source "$1"
      if [[ -o nullglob ]]; then echo "after: on"; else echo "after: off"; fi
    ' _ "$BATS_TEST_TMPDIR/probe.sh" "$BATS_TEST_TMPDIR"
    [[ "$output" == *"before: off"*"during: on"*"after: off"* ]] || { echo "$b: $output"; return 1; }
  done
}
