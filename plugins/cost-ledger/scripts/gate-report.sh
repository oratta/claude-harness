#!/usr/bin/env bash
# PostToolUse（matcher Bash）hook: ゲート通過（agent-review:passed の付与）の直後に、
# その PR へ `/cost <PR番号>` の 1 行目と同じ行をコメントで貼る。LLM のトークンは使わない。
# 規範の正本は openspec の spec `cost-ledger-gate-report`。
#
#   緊急停止 COST_LEDGER_GATE_REPORT=off
#
# この hook は全 Bash 呼び出しで起動するので、stdin に文字列 agent-review:passed が
# 無ければ JSON のパースも jq・python3 の起動もせずに抜ける（fast path）。判定対象が
# payload 全体なのは tool_response（コマンドの出力）も入るためで、ラベル名を表示しただけの
# 呼び出しも通るが、その先の厳密な判定で落ちて無音で終わるだけになる。
#
# どの経路でも stdout・stderr に何も出さず終了コード 0。hook の失敗でゲートを止めず、
# 文脈にも何も入れないため。
set -u

[ "${COST_LEDGER_GATE_REPORT:-on}" = "off" ] && exit 0
payload="$(cat)" || exit 0
case "$payload" in
  *agent-review:passed*) ;;
  *) exit 0 ;;
esac
exit 0
