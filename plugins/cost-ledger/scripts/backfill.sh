#!/usr/bin/env bash
# SessionStart（matcher startup|resume）hook: 手元の Bash を通らなかったマージと issue のクローズ
# （auto-merge のマージ、`Closes` による自動クローズ）へ、そのリポジトリで次にセッションを始めた
# ときに最後の行（`マージ` / `issue クローズ` と issue の合計の行）を積む。LLM のトークンは使わない。
# 規範の正本は openspec の spec `cost-ledger-backfill`。
#
#   緊急停止 COST_LEDGER_BACKFILL=off（後追いだけ）/ COST_LEDGER_GATE_REPORT=off（GitHub へ書く処理すべて）
#   台帳の場所が未設定なら動かない（どこまで見たかの控えを台帳の隣に置くため。既定の場所は持たない）。
#   場所は ledger-hook.sh と同じく CLAUDE_PLUGIN_OPTION_LEDGER_PATH（userConfig の LEDGER_PATH）を優先し、
#   空なら COST_LEDGER_PATH を使う（spec `cost-ledger-persistence`）
#
# 既定では GitHub に何も書かない。書くのは、利用者がリポジトリの外に置いた許可の一覧
# （COST_LEDGER_WRITE_REPOS_FILE、無ければ $HOME/.config/cost-ledger/write-repos）に載っている
# リポジトリだけ（spec `cost-ledger-write-allowlist`。gate-report.sh と同じ一覧）。ここで見るのは
# 「空でないファイルがあるか」だけの近道で、中身の判定（書式・持ち主と権限・作業中のリポジトリの
# 中に置かれていないか・cwd のリポジトリが載っているか）は、backfill.py が最初の gh の前に
# write_allow.py の allowed() で行う。
#
# 緊急停止・台帳の未設定・一覧のファイルが無いか大きさ 0、のどれかに当たれば python3 を起動せずに抜ける。ここと backfill.py の同期部分が行うのは
# hook の JSON の判定だけで、GitHub への問い合わせ・集計・書き込みは backfill.py が自分を切り離して
# 起こした裏のプロセスで行う（セッションの開始を待たせない）。COST_LEDGER_HOOK_FOREGROUND=1 の
# ときは切り離さず、その場で最後まで実行する（テストと実測のため）。
#
# どの経路でも stdout・stderr に何も出さず終了コード 0。SessionStart の hook の stdout は会話の
# 文脈に入るので、1 文字でも出すと毎セッションのトークンになる。
set -u
exec >/dev/null 2>&1

[ "${COST_LEDGER_GATE_REPORT:-on}" = "off" ] && exit 0
[ "${COST_LEDGER_BACKFILL:-on}" = "off" ] && exit 0
COST_LEDGER_PATH="${CLAUDE_PLUGIN_OPTION_LEDGER_PATH:-${COST_LEDGER_PATH:-}}"
[ -n "$COST_LEDGER_PATH" ] || exit 0
export COST_LEDGER_PATH
write_repos="${COST_LEDGER_WRITE_REPOS_FILE:-${HOME:+$HOME/.config/cost-ledger/write-repos}}"
[ -n "$write_repos" ] || exit 0
[ -s "$write_repos" ] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0
command -v gh >/dev/null 2>&1 || exit 0
# backfill.py・gate_report.py・cost_ledger.py・write_allow.py は CLAUDE_PLUGIN_ROOT ではなくこのスクリプトの隣から引く。
scripts_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || exit 0
[ -f "$scripts_dir/backfill.py" ] || exit 0
[ -f "$scripts_dir/write_allow.py" ] || exit 0

# hook の JSON は stdin のまま渡す。
# -E -s で起動し、PYTHON* の環境変数（PYTHONPATH など）とユーザー site を検索パスに使わない。-I は付けない:
# -I はスクリプトのディレクトリも検索パスから外すので、隣の cost_ledger.py・write_allow.py を import できなくなる（#847）。
python3 -E -s "$scripts_dir/backfill.py" >/dev/null 2>&1
exit 0
