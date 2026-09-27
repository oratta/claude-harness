#!/usr/bin/env bash
# SubagentStop hook: 自分が run_in_background で起動した背景タスクを終わらせないまま
# ターンを終えようとするサブエージェントの停止を拒否する（issue #264）。
#
#   未完了 = {自分のトランスクリプトの tool_result 本文 `Command running in background with ID: <id>` の id}
#          ∩ {payload background_tasks のうち status:"running" の id}
#   未完了があれば {"decision":"block","reason":…} を出す。拒否は同じサブエージェントに MAX_BLOCKS 回まで
#   全解除   DEV_WORKFLOW_STOP_GUARD=off
#
# 理由: 名前付き background サブエージェントは自分の背景タスクの完了では再起動されない。
# 「完了を待つ」と書いてターンを終えると親が SendMessage を送るまで止まる（#509 で 12 PR 中 7 件）。
# 手順書の禁止は文言検査でしか守れず、言い換えも「書いてあるのに従わない」も素通りするので、
# ターンを終える瞬間そのものを止める。規範の正本は references/subagent-waiting.md。
#
# 所有と生死を別の場所で見る（Claude Code 2.1.283、2026-09-27 の実測）:
#   - 所有: payload の background_tasks は親セッション全体の台帳で、本体の ci-watch.sh wait や
#     停止する本人（type:"subagent"）も入る。自分が起動したものだけをトランスクリプトで絞る。
#     サブエージェント側の tool_result には toolUseResult が無く、ID は本文からしか取れない
#   - 生死: 完了・失敗・TaskStop 後のタスクは background_tasks から消える。killed の通知は
#     トランスクリプトに書かれないので、通知では判定しない
#
# fail-open: 判定できないときは stdout に何も出さず exit 0。この hook は install 先の全サブエージェントの
# 停止で走るので、判定の失敗でサブエージェントを止め続けてはならない。
set -uo pipefail

[ "${DEV_WORKFLOW_STOP_GUARD:-on}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# メインセッション（agent_id 無し）は python3 を起動せずに切る。必要条件の根拠は
# context-tripwire.sh と同じ（生表記でない agent_id キーは必ず \u00 を含む）。
payload="$(cat)" || exit 0
case "$payload" in
  *'"agent_id"'*) ;;
  *'\u00'*) ;;
  *) exit 0 ;;
esac

# 理由文に載せる正本の絶対パス（install 先でも開けるように）
CANON_PATH="${0%/*}/../references/subagent-waiting.md"
export CANON_PATH

# Python 本体は fd 3 のヒアドキュメントで渡し、payload は stdin から読ませる（ARG_MAX を避ける）
printf '%s' "$payload" | python3 /dev/fd/3 3<<'PY'
import json, os, re, sys, time

MAX_BLOCKS = 3           # 正本 subagent-waiting.md の総待ちの上限回数と一致させる（bats で突き合わせる）
ENTRY_BUDGET = 200       # 探索で走査するディレクトリエントリの上限（context-tripwire.sh と同じ）
SCAN_SEC = 0.020         # 探索に費やす時間の上限（context-tripwire.sh と同じ）
NEEDLE = b"Command running in background with ID"
LAUNCH = re.compile(r"Command running in background with ID: ([A-Za-z0-9_-]+)\."
                    r"(?: Output is being written to: (\S+?)\.(?=\s|$))?")

REASON = (
    "[dev-workflow 停止の拒否 {n}/{max}] 自分が run_in_background で起動した背景タスクが終わっていないのに、"
    "ターンを終えようとした: {tasks}\n"
    "完了を待つ目的でターンを終えてはならない（名前付き background サブエージェントは、"
    "自分の背景タスクが終わっても再起動されない）。このターンの中で、前景の待ちループ"
    "（Bash ツールの timeout を指定した until ループ）で完了を確認してから終えよ。\n"
    "上限まで待ち終えた、または結果を使わないと決めたなら、TaskStop ツールでそのタスクを停止してから終えよ"
    "（return には停止したタスクと、どこまで待ったかを書く）。\n"
    "待ち方の正本: {canon}"
)


def skip(msg):
    """判定を見送って停止を通す。stderr に 1 行だけ残す。"""
    sys.stderr.write("[dev-workflow subagent-stop-guard] %s\n" % msg)
    sys.exit(0)


def find_transcript(root, fname):
    """subagents/ 以下を深さ 3 段まで幅優先で探す（context-tripwire.sh と同じ上限）。"""
    deadline = time.monotonic() + SCAN_SEC
    scanned = 0
    level = [root]
    for _ in range(3):
        nxt = []
        for d in level:
            try:
                with os.scandir(d) as it:
                    for e in it:
                        scanned += 1
                        if scanned > ENTRY_BUDGET or time.monotonic() > deadline:
                            return None
                        try:
                            if e.name == fname and e.is_file():
                                return e.path
                            if e.is_dir():
                                nxt.append(e.path)
                        except OSError:
                            continue
            except OSError:
                continue
        if not nxt:
            return None
        level = nxt
    return None


def strings(v):
    if isinstance(v, str):
        yield v
    elif isinstance(v, list):
        for x in v:
            yield from strings(x)
    elif isinstance(v, dict):
        for x in v.values():
            yield from strings(x)


def launches(path):
    """type:"user" の記録の本文から、背景起動の (id, 出力ファイル) を起動順に返す。"""
    found = {}
    with open(path, "rb") as f:
        for line in f:
            if NEEDLE not in line:          # 全行を JSON パースしないための前段フィルタ
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            if not isinstance(d, dict) or d.get("type") != "user":
                continue
            for s in strings(d.get("message")):
                for m in LAUNCH.finditer(s):
                    found.setdefault(m.group(1), m.group(2))
    return found


try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(payload, dict):
    sys.exit(0)

agent_id = payload.get("agent_id")
if not isinstance(agent_id, str) or not agent_id:
    sys.exit(0)                     # メインセッションは対象外（stderr にも出さない）

session_id = payload.get("session_id")
transcript_path = payload.get("transcript_path")
bad = lambda v: not isinstance(v, str) or not v or os.sep in v or v in (".", "..")
if bad(agent_id) or bad(session_id):
    skip("agent_id / session_id が読めないので判定を見送る")

tasks = payload.get("background_tasks")
if not isinstance(tasks, list):
    skip("payload に background_tasks が無いので判定を見送る（Claude Code の版を確かめる）")

# 拒否回数（後詰め）の置き場。running / pending の判定より前に決めておき、
# 停止を通すどの分岐でも同じ変数で削除できるようにする（issue #561）。
counter_dir = os.path.join(os.environ.get("TMPDIR") or "/tmp", "dev-workflow-stop-guard")
counter = os.path.join(counter_dir, "%s-%s.count" % (session_id, agent_id))

running = {t.get("id") for t in tasks
           if isinstance(t, dict) and t.get("status") == "running" and isinstance(t.get("id"), str)}
running.discard(agent_id)           # 停止する本人（type:"subagent"）
if not running:
    try:
        os.remove(counter)          # 停止を通す時点でカウンタを消す。無ければ何もしない
    except OSError:
        pass
    sys.exit(0)

# 対象トランスクリプト: agent_transcript_path → 導出 → 上限つきの探索（後の 2 つは context-tripwire.sh と同じ）
target = payload.get("agent_transcript_path")
if not (isinstance(target, str) and os.path.isfile(target)):
    target = None
    if isinstance(transcript_path, str) and transcript_path:
        root = os.path.join(os.path.dirname(transcript_path), session_id, "subagents")
        fname = "agent-%s.jsonl" % agent_id
        target = os.path.join(root, fname)
        if not os.path.isfile(target):
            target = find_transcript(root, fname)
if not target:
    skip("サブエージェントのトランスクリプトが見つからないので判定を見送る")

try:
    mine = launches(target)
except OSError:
    skip("サブエージェントのトランスクリプトが読めないので判定を見送る")

pending = [(i, out) for i, out in mine.items() if i in running]
if not pending:
    try:
        os.remove(counter)          # 停止を通す時点でカウンタを消す。無ければ何もしない
    except OSError:
        pass
    sys.exit(0)

# 正当な出口は前景で待つか TaskStop で止めることで、ここから先は理由を無視し続ける場合の上限
try:
    os.makedirs(counter_dir, exist_ok=True)
except OSError:
    skip("拒否回数のディレクトリ %s が作れないので判定を見送る" % counter_dir)
try:
    with open(counter) as f:
        n = int(f.read().strip())
except FileNotFoundError:
    n = 0
except (OSError, ValueError):
    skip("拒否回数のファイル %s が読めないので判定を見送る" % counter)

if n >= MAX_BLOCKS:
    try:
        os.remove(counter)
    except OSError:
        pass
    skip("未完了の背景タスク %s が残っているが、拒否が上限 %d 回に達したので停止を通す"
         % (",".join(i for i, _ in pending), MAX_BLOCKS))

try:
    with open(counter, "w") as f:
        f.write(str(n + 1))
except OSError:
    skip("拒否回数のファイル %s に書けないので判定を見送る" % counter)

listed = "、".join("%s（出力: %s）" % (i, out) if out else i for i, out in pending)
canon = os.path.normpath(os.environ.get("CANON_PATH") or "plugins/dev-workflow/references/subagent-waiting.md")
print(json.dumps({"decision": "block",
                  "reason": REASON.format(n=n + 1, max=MAX_BLOCKS, tasks=listed, canon=canon)},
                 ensure_ascii=False))
sys.exit(0)
PY
