#!/usr/bin/env bash
# PostToolUse（matcher Bash）hook: PR / issue へのコメント・状態の変更・ゲート通過の直後に、
# その PR / issue の 1 本のコメントへ「ここまでのコスト」を 1 行積む。LLM のトークンは使わない。
# 規範の正本は openspec の spec `cost-ledger-gate-report` と `cost-ledger-timeline`。
#
#   きっかけ: gh pr comment / gh pr ready / gh pr close / gh pr merge /
#             gh issue comment / gh issue close / gh issue reopen / agent-review:passed の付与
#   緊急停止 COST_LEDGER_GATE_REPORT=off（上のきっかけすべてを止める）
#
# 既定では GitHub に何も書かない。書くのは、利用者がリポジトリの外に置いた許可の一覧
# （COST_LEDGER_WRITE_REPOS_FILE、無ければ $HOME/.config/cost-ledger/write-repos）に載っている
# リポジトリだけ（spec `cost-ledger-write-allowlist`）。評価の順は、緊急停止 → 一覧のファイルが
# 無いか大きさ 0 か → きっかけの文字列の有無。一覧のファイルが無い・大きさ 0 なら、stdin も読まず
# python3 も起動せずに抜ける。ここで見るのは「空でないファイルがあるか」だけの近道で、中身の判定
# （書式・持ち主と権限・作業中のリポジトリの中に置かれていないか・対象が載っているか）は必ず
# write_allow.py の allowed() が行う。
#
# この hook は全 Bash 呼び出しで起動するので、stdin にきっかけの文字列がどれも無ければ
# JSON のパースも jq・python3 の起動もせずに抜ける（fast path）。判定対象が payload 全体なのは
# tool_response（コマンドの出力）も入るためで、文字列を表示しただけの呼び出しも通るが、
# その先の厳密な判定（gate_report.py）で落ちて無音で終わるだけになる。
#
# ここと gate_report.py の同期部分が行うのはコマンド文字列の判定だけ。GitHub への問い合わせ・
# 集計・書き込みは、gate_report.py が自分を切り離して起こした裏のプロセスで行う（セッションを
# 待たせない）。COST_LEDGER_HOOK_FOREGROUND=1 のときは切り離さず、その場で最後まで実行する
# （テストと実測のため）。
#
# どの経路でも stdout・stderr に何も出さず終了コード 0。hook の失敗でゲートを止めず、
# 文脈にも何も入れないため。
set -u

[ "${COST_LEDGER_GATE_REPORT:-on}" = "off" ] && exit 0
write_repos="${COST_LEDGER_WRITE_REPOS_FILE:-${HOME:+$HOME/.config/cost-ledger/write-repos}}"
[ -n "$write_repos" ] || exit 0
[ -s "$write_repos" ] || exit 0
payload="$(cat)" || exit 0
case "$payload" in
  *agent-review:passed*) ;;
  *"gh pr comment"*|*"gh pr ready"*|*"gh pr close"*|*"gh pr merge"*) ;;
  *"gh issue comment"*|*"gh issue close"*|*"gh issue reopen"*) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0
command -v gh >/dev/null 2>&1 || exit 0
# gate_report.py と cost_ledger.py は CLAUDE_PLUGIN_ROOT ではなくこのスクリプトの隣から引く。
scripts_dir="$(cd "$(dirname "$0")" && pwd)" || exit 0
[ -f "$scripts_dir/gate_report.py" ] || exit 0
[ -f "$scripts_dir/write_allow.py" ] || exit 0

# payload は stdin から読ませる。環境変数や引数に載せると長い出力で ARG_MAX を超えて hook が落ちる。
printf '%s' "$payload" 2>/dev/null | python3 "$scripts_dir/gate_report.py" >/dev/null 2>&1
exit 0
