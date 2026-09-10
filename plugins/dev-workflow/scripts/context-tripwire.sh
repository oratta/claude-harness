#!/usr/bin/env bash
# PostToolUse（全ツール）/ PreToolUse（Edit|Write|NotebookEdit|Bash）hook:
# サブエージェントが 1 回の起動の中で膨らませたコンテキストを途中で測り、2 段で止める。
#
#   通知     DEV_WORKFLOW_CONTEXT_CAP（既定 150000）超  → PostToolUse で additionalContext を出す
#   強制停止 DEV_WORKFLOW_CONTEXT_HARD_CAP（既定 220000）超 → PreToolUse で編集系を deny する
#   全解除   DEV_WORKFLOW_CONTEXT_TRIPWIRE=off
#
# 理由: 本体が SendMessage で再開する直前にしか測られないので、1 起動の中で膨らむぶんは
# 誰も止めない（実測で W が 497,552 トークンに達した）。規範の正本は
# skills/develop/references/decision-criteria.md「コンテキスト上限」。
#
# 計測対象は payload の transcript_path そのものではない。transcript_path は hook が発火した
# セッション（サブエージェントの中でも親）のトランスクリプトを指すので、その親ディレクトリと
# session_id・agent_id から <親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl を
# 導出する。直接パスが無ければ subagents/ 以下を深さ 3 段まで（上限つきで）探す。
#
# 計測の式（正本は spec「コンテキスト量の計測の式は 1 つに定める」。subagent-context.sh と同じ）:
#   対象トランスクリプトの最後の assistant レコードの
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
#
# fail-open: 判定できないときは何も出力せず exit 0。この hook は install 先の全セッションで
# 発火するので、判定を失敗させて全ユーザーのツール実行を止めてはならない。
set -uo pipefail

[ "${DEV_WORKFLOW_CONTEXT_TRIPWIRE:-on}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0   # fail-open（判定できなければ止めない）

# メインスレッド（agent_id 無し）は全ユーザーの全ツール呼び出しの大多数なので、
# python3 の起動コストを課さない。この判定は JSON をパースせず、必要条件だけで切る。
#
# 必要条件が成り立つ根拠: JSON のキーは文字列リテラルなので、agent_id の 8 文字を生の文字
# 以外で書く手段は文字列エスケープしかない。\uXXXX 以外の 8 種（\" \\ \/ \b \f \n \r \t）が
# 生む文字は " \ / とバックスペース・改頁・改行・復帰・タブで、英小文字もアンダースコアも
# 作れない。つまり生表記でないキーは必ず \uXXXX を含む。さらに agent_id の 8 文字は
# U+005F〜U+0074 に収まるので、その \uXXXX 表記は上位 2 桁が必ず 00 になる（16 進の大文字
# 小文字の揺れは下位 2 桁にしか出ない）。よって前置 4 文字 \u00 まで見て切ってよい。
#
# 誤検知は「余計に python3 を起動して無音で終わる」向きにしか起きない（コマンド文字列に
# agent_id と書いたメインスレッド呼び出し、tool_response に \u00 を含む出力が入った呼び出し）。
# その先で agent_id フィールドが無いと判定されて fail-open するだけなので無害。逆向き
# （agent_id を持つ payload を早期 exit させること）は spec が MUST NOT で禁じている。
payload="$(cat)" || exit 0
case "$payload" in
  *'"agent_id"'*) ;;   # 生表記（実運用のほぼ全て）
  *'\u00'*) ;;         # Unicode エスケープ表記かもしれない → 判定は python3 のパースに任せる
  *) exit 0 ;;
esac

# Python 本体は fd 3 のヒアドキュメントで渡し、payload は stdin から読ませる。
# payload を環境変数や引数に載せると長い prompt で ARG_MAX を超えて hook が落ちる。
printf '%s' "$payload" | python3 /dev/fd/3 3<<'PY'
import json, os, sys, time

TAIL = 256 * 1024        # 末尾だけ読む。環境変数化しない（design Decision 5）
ENTRY_BUDGET = 200       # 探索で走査するディレクトリエントリの上限
SCAN_SEC = 0.020         # 探索に費やす時間の上限

NOTIFY = (
    "[dev-workflow 途中計測] このサブエージェントのコンテキストは {ctx} tokens で、"
    "上限 DEV_WORKFLOW_CONTEXT_CAP={cap} を超えた。\n"
    "次のツールを呼ばずに今の工程を締め、成果（編集済みファイル・通ったテスト・判明した事実・"
    "埋めた決定・残作業）を列挙して return せよ。\n"
    "return の 1 行目は、そのとき進めていた tasks グループの項目がすべて済んでいれば「工程完了:」、"
    "1 つでも残っていれば「工程中断:」にする"
    "（tasks.md が無い場合は本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす）。"
)

STOP = (
    "[dev-workflow 強制停止] このサブエージェントのコンテキストは {ctx} tokens で、"
    "強制停止の閾値 DEV_WORKFLOW_CONTEXT_HARD_CAP={hard} を超えた。"
    "ここから Bash はコマンド内容によらず一切通らない（git も含む）。"
    "作業ツリー {cwd} の変更は commit できないまま残る。commit は本体が行う。"
    "編集済みファイルの一覧と、この作業ツリーのパス（{cwd}）を return に書いて締めよ。"
    "return の 1 行目は必ず「工程中断:」にする（拒否された時点で予定していた作業が残っているため）。"
)


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))


def env_int(name, default):
    """正の整数でなければ None（＝ fail-open）。未設定は既定値。"""
    v = os.environ.get(name)
    if v is None or v.strip() == "":
        return default
    v = v.strip()
    if not v.isdigit() or int(v) <= 0:
        return None
    return int(v)


def find_transcript(root, fname):
    """subagents/ 以下を深さ 3 段まで幅優先で探す（直下を 1 段目と数える）。
    上限（エントリ数・時間）に達したら打ち切って None を返す。"""
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


def measure(path):
    """末尾 TAIL バイトに現れる最後の assistant usage を合算する。読めなければ None。"""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            if size > TAIL:
                f.seek(size - TAIL)
                f.readline()          # 途中で切れた 1 行目は捨てる
            data = f.read()
    except OSError:
        return None
    for line in reversed(data.splitlines()):
        if b'"assistant"' not in line:      # 全行を JSON パースしないための前段フィルタ
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue                        # 壊れた行は読み飛ばす
        if not isinstance(d, dict) or d.get("type") != "assistant":
            continue
        msg = d.get("message")
        u = msg.get("usage") if isinstance(msg, dict) else None
        if not isinstance(u, dict):
            continue

        def n(k):
            v = u.get(k)
            return int(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else 0

        return n("input_tokens") + n("cache_creation_input_tokens") + n("cache_read_input_tokens")
    return None


try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(payload, dict):
    sys.exit(0)

agent_id = payload.get("agent_id")
session_id = payload.get("session_id")
transcript_path = payload.get("transcript_path")
event = payload.get("hook_event_name")
if not all(isinstance(v, str) and v for v in (agent_id, session_id, transcript_path)):
    sys.exit(0)
# 導出先がディレクトリの外に出る値は測らない
if os.sep in agent_id or os.sep in session_id or agent_id in (".", "..") or session_id in (".", ".."):
    sys.exit(0)
if event not in ("PostToolUse", "PreToolUse"):
    sys.exit(0)

cap = env_int("DEV_WORKFLOW_CONTEXT_CAP", 150000)
hard = env_int("DEV_WORKFLOW_CONTEXT_HARD_CAP", 220000)
if cap is None or hard is None:
    sys.exit(0)

root = os.path.join(os.path.dirname(transcript_path), session_id, "subagents")
fname = "agent-%s.jsonl" % agent_id
target = os.path.join(root, fname)
if not os.path.isfile(target):
    target = find_transcript(root, fname)
if not target:
    sys.exit(0)

ctx = measure(target)
if ctx is None:
    sys.exit(0)

if event == "PostToolUse":
    if ctx <= cap:
        sys.exit(0)
    emit({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                                 "additionalContext": NOTIFY.format(ctx=ctx, cap=cap)}})
    sys.exit(0)

# --- PreToolUse（強制停止）---
if hard <= cap:                 # 閾値の大小が逆なら何もしない
    sys.exit(0)
if ctx <= hard:
    sys.exit(0)

tool = payload.get("tool_name")
if tool not in ("Edit", "Write", "NotebookEdit", "Bash"):
    sys.exit(0)                 # 読み取り系はここに来ない（matcher でも絞っている）が念のため

# Bash はコマンド内容によらず全件拒否する（窓を開けない。#269 決定・2 回目）。
# 検査側のトークン化（このプロセス）と実行するシェル（zsh/bash）のトークン化は
# 一致を保証できず、受理する経路が1つでもあれば迂回が再発するため、内容は一切見ない。
cwd = payload.get("cwd")
cwd = cwd if isinstance(cwd, str) and cwd else "(cwd 不明)"
reason = STOP.format(ctx=ctx, hard=hard, cwd=cwd)

emit({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                             "permissionDecision": "deny",
                             "permissionDecisionReason": reason}})
sys.exit(0)
PY
