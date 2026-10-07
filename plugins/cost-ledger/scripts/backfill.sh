#!/usr/bin/env bash
# SessionStart（matcher startup|resume）hook: 手元の Bash を通らなかったマージと issue のクローズ
# （auto-merge のマージ、`Closes` による自動クローズ）へ、そのリポジトリで次にセッションを始めた
# ときに最後の行（`マージ` / `issue クローズ` と issue の合計の行）を積む。LLM のトークンは使わない。
# 規範の正本は openspec の spec `cost-ledger-backfill`。
#
#   緊急停止 COST_LEDGER_BACKFILL=off（後追いだけ）/ COST_LEDGER_GATE_REPORT=off（GitHub へ書く処理すべて）
#   COST_LEDGER_PATH が未設定なら動かない（どこまで見たかの控えを台帳の隣に置くため。既定の場所は持たない）
#
# 上の 3 つのどれかに当たれば python3 を起動せずに抜ける。ここと backfill.py の同期部分が行うのは
# hook の JSON の判定だけで、GitHub への問い合わせ・集計・書き込みは backfill.py が自分を切り離して
# 起こした裏のプロセスで行う（セッションの開始を待たせない）。COST_LEDGER_HOOK_FOREGROUND=1 の
# ときは切り離さず、その場で最後まで実行する（テストと実測のため）。
#
# どの経路でも stdout・stderr に何も出さず終了コード 0。SessionStart の hook の stdout は会話の
# 文脈に入るので、1 文字でも出すと毎セッションのトークンになる。
set -u

[ "${COST_LEDGER_GATE_REPORT:-on}" = "off" ] && exit 0
[ "${COST_LEDGER_BACKFILL:-on}" = "off" ] && exit 0
[ -n "${COST_LEDGER_PATH:-}" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0
command -v gh >/dev/null 2>&1 || exit 0
# backfill.py・gate_report.py・cost_ledger.py は CLAUDE_PLUGIN_ROOT ではなくこのスクリプトの隣から引く。
scripts_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
[ -f "$scripts_dir/backfill.py" ] || exit 0

# hook の JSON は stdin のまま渡す。
python3 "$scripts_dir/backfill.py" >/dev/null 2>&1
exit 0
