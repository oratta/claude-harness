#!/bin/sh
# cost-ledger の Stop hook。会話ログの増えた分を台帳（COST_LEDGER_PATH）へ追記する。
#
# - COST_LEDGER_PATH が未設定なら python3 を起動せずに抜ける（hook からは利用者に聞けない。
#   聞くのは /cost のコマンド本文の役目）
# - どの失敗でも無出力で exit 0（応答を止めない。exit 2 は返さない）
# - hook の JSON（stdin）は使わない。会話ログのルート全体を歩くので、サブエージェントの
#   会話ログも同じ回で拾う
cat >/dev/null 2>&1
[ -n "${COST_LEDGER_PATH:-}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
python3 "$(dirname "$0")/cost_ledger.py" ledger-sync --quiet </dev/null >/dev/null 2>&1
exit 0
