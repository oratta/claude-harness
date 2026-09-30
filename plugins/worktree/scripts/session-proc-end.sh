#!/usr/bin/env bash
# session-proc-end.sh — SessionEnd hook（issue #470）
#
# SessionEnd フックの持ち時間は既定 1.5 秒で、プラグインの timeout では延びない。TERM → 数秒 → KILL は
# 収まらないので、ここでは目印を計算して後始末（reaper --session-end）を切り離して起動し、すぐ戻る。
#
# 目印はフックのプロセス環境に乗っているかが公式に書かれていないので頼らず、SessionStart と同じく
# フックの PID から親をたどって持ち主の Claude Code を特定して計算する。持ち主が見つからなければ
# 後始末を起動しない（落ちたセッションと同じく次の掃除に任せる）。
#
# 後始末は持ち主の Claude Code の終了を待ってから止める。/clear や /resume で同じプロセスが続く
# 場合は止めない（reason で分岐しない）。
#
# fail-soft 厳守: 会話に何も出力せず、何が起きても exit 0。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAPER="$SCRIPT_DIR/session-proc-reaper.sh"

cat >/dev/null 2>&1 || true

{
  # shellcheck source=session-proc-reaper.sh
  . "$REAPER" || exit 0

  owner=$(srp_find_owner "${SESSION_REAPER_HOOK_PID:-$$}") || owner=""
  if [ -n "$owner" ] && mark=$(srp_mark_for "$owner"); then
    # 後始末自身は目印を持たない（フック環境に乗っていた場合の保険。自分を止め対象にしない）
    srp_detach env -u "$SRP_MARK_VAR" "$REAPER" --session-end "$mark"
  else
    srp_log "no-owner hook_pid=${SESSION_REAPER_HOOK_PID:-$$} trigger=session-end"
  fi
} >/dev/null 2>&1

exit 0
