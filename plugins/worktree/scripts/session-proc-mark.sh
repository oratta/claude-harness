#!/usr/bin/env bash
# session-proc-mark.sh — SessionStart hook（issue #470）
#
# 1. セッションの持ち主の Claude Code プロセスを親をたどって見つけ、目印
#    `export CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>` を CLAUDE_ENV_FILE に 1 行追記する。
#    Bash ツールから起動したプロセスはツールの種類を問わずこの目印を引き継ぐ。
# 2. 前回から既定 10 分以上たっていれば、落ちたセッションの分の掃除（reaper --sweep）を
#    切り離して起動する。スタンプファイルはログと同じディレクトリに置く。
#
# fail-soft 厳守: 会話に何も出力せず、何が起きても exit 0（wt-setup-guard.sh と同じ方針）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAPER="$SCRIPT_DIR/session-proc-reaper.sh"

# stdin は読み捨てる（詰まり防止）
cat >/dev/null 2>&1 || true

{
  # shellcheck source=session-proc-reaper.sh
  . "$REAPER" || exit 0

  owner=$(srp_find_owner "${SESSION_REAPER_HOOK_PID:-$$}") || owner=""
  if [ -n "$owner" ] && mark=$(srp_mark_for "$owner"); then
    if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
      # 他のプラグインも同じファイルに書くので追記だけする。export を落とすと子プロセスに渡らない
      printf 'export %s=%s\n' "$SRP_MARK_VAR" "$mark" >>"$CLAUDE_ENV_FILE" 2>/dev/null || true
    fi
  else
    srp_log "no-owner hook_pid=${SESSION_REAPER_HOOK_PID:-$$} trigger=session-start"
  fi

  # --- 落ちたセッションの掃除 ---
  stamp="$(srp_log_dir)/$SRP_STAMP_NAME"
  interval=${SESSION_REAPER_SWEEP_INTERVAL_SECS:-600}
  due=1
  if [ -f "$stamp" ]; then
    age=$(perl -e 'my @s = stat($ARGV[0]) or exit 1; print time - $s[9]' "$stamp" 2>/dev/null) || age=""
    case "$age" in
      ''|*[!0-9-]*) ;;
      *) [ "$age" -lt "$interval" ] && due=0 ;;
    esac
  fi
  if [ "$due" -eq 1 ]; then
    mkdir -p "$(dirname "$stamp")" 2>/dev/null
    # 先にスタンプを更新してから起動する（同時に始まったセッションが重ねて起動しないため）
    touch "$stamp" 2>/dev/null
    srp_detach env -u "$SRP_MARK_VAR" "$REAPER" --sweep
  fi
} >/dev/null 2>&1

exit 0
