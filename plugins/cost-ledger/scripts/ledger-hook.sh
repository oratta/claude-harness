#!/bin/sh
# cost-ledger の Stop hook。会話ログの増えた分を台帳へ追記する。
#
# - 台帳の場所は userConfig の LEDGER_PATH（環境変数 CLAUDE_PLUGIN_OPTION_LEDGER_PATH）を優先し、
#   空なら従来の COST_LEDGER_PATH を使う。見つけた値は COST_LEDGER_PATH に写して python に渡す
# - どちらも空なら python3 を起動せずに抜ける（hook からは利用者に聞けない。
#   聞くのは /cost のコマンド本文の役目）
# - どの失敗でも無出力で exit 0（応答を止めない。exit 2 は返さない）
# - hook の JSON（stdin）は使わない。会話ログのルート全体を歩くので、サブエージェントの
#   会話ログも同じ回で拾う
cat >/dev/null 2>&1
COST_LEDGER_PATH="${CLAUDE_PLUGIN_OPTION_LEDGER_PATH:-${COST_LEDGER_PATH:-}}"
[ -n "$COST_LEDGER_PATH" ] || exit 0
export COST_LEDGER_PATH
command -v python3 >/dev/null 2>&1 || exit 0
# -E -s で起動し、PYTHON* の環境変数（PYTHONPATH など）とユーザー site を検索パスに使わない（-I にしないのは、
# cost_ledger.py を置いたディレクトリを検索パスに残すため。backfill.sh・gate-report.sh と呼び方をそろえる。#847）。
python3 -E -s "$(dirname "$0")/cost_ledger.py" ledger-sync --quiet </dev/null >/dev/null 2>&1
exit 0
