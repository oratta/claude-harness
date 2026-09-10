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
# python3 の起動コストを課さない。agent_id は JSON のキーとして必ず入るため、
# 文字列 "agent_id" を含まない payload はサブエージェント発火ではない。
# 逆の誤検知（コマンド文字列に agent_id を含むメインスレッド呼び出し）は、
# その先で agent_id フィールドが無いと判定されて fail-open するだけで無害。
payload="$(cat)" || exit 0
case "$payload" in
  *'"agent_id"'*) ;;
  *) exit 0 ;;
esac

# Python 本体は fd 3 のヒアドキュメントで渡し、payload は stdin から読ませる。
# payload を環境変数や引数に載せると長い prompt で ARG_MAX を超えて hook が落ちる。
printf '%s' "$payload" | python3 /dev/fd/3 3<<'PY'
import json, os, shlex, sys, time

TAIL = 256 * 1024        # 末尾だけ読む。環境変数化しない（design Decision 5）
ENTRY_BUDGET = 200       # 探索で走査するディレクトリエントリの上限
SCAN_SEC = 0.020         # 探索に費やす時間の上限
GIT_OK = {"status", "diff", "add", "commit", "push"}

# サブコマンドごとの許可オプション表（正本は #269 の決定と openspec spec 側の同名の表）。
# 表に無いオプションは、危険と分かっていなくても拒否する（正の列挙。負の列挙にしない）。
GIT_COMMON_OPTS = {"--"}
GIT_ALLOWED_OPTS = {
    "status": {
        "-s", "--short", "-b", "--branch", "--long", "--porcelain",
        "--porcelain=v1", "--porcelain=v2", "-u", "-uall", "-uno", "-unormal",
        "--untracked-files", "--untracked-files=all", "--untracked-files=no",
        "--untracked-files=normal",
    },
    "diff": {
        "--stat", "--shortstat", "--numstat", "--name-only", "--name-status",
        "--cached", "--staged", "--no-color",
    },
    "add": {"-A", "--all", "-u", "--update", "-n", "--dry-run"},
    "commit": {"-a", "--all", "--allow-empty", "-q", "--quiet"},
    "push": {"-u", "--set-upstream", "-q", "--quiet", "-n", "--dry-run"},
}
# 値を取るオプション。直後の 1 トークンは内容自由（commit メッセージは実行経路を持たない）
GIT_VALUE_OPTS = {"commit": {"-m", "--message"}}
GIT_VALUE_PREFIXES = {"commit": ("--message=",)}

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
    "ここから残せるのは commit と return だけ。作業ツリーを commit し、"
    "成果（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）を列挙して return せよ。"
    "return の 1 行目は必ず「工程中断:」にする（拒否された時点で予定していた作業が残っているため）。"
)

BASH_HINT = (
    " Bash で通るのは git の status / diff / add / commit / push で、それぞれ決まった形のオプションだけ"
    "（作業ディレクトリの指定は -C <path> だけが通り、-c <k=v> は値によらず拒否される）。"
    "commit メッセージは -m を複数回に分けて 1 行ずつ渡せ（$(…) やパイプ・&& を含むコマンドは拒否される）。"
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


def scan_command(cmd):
    """引用の外に複合コマンドの記号があるかを見る。
    返り値: None=素直な単一コマンド / "subst"=コマンド置換 / "compound" / "unparsable"。
    引用の中まで拒否すると `git commit -m "fix(x): y"` のような正当な commit を落とすので、
    引用状態を追いながら判定する。"""
    if not isinstance(cmd, str) or not cmd.strip():
        return "unparsable"
    i, n, state = 0, len(cmd), None
    while i < n:
        c = cmd[i]
        if state == "'":
            if c == "'":
                state = None
        elif state == '"':
            # コマンド置換は二重引用の中でも展開されるので、ここでも拒否する
            if c == "\\":
                i += 1
            elif c == '"':
                state = None
            elif c == "`":
                return "subst"
            elif c == "$" and i + 1 < n and cmd[i + 1] == "(":
                return "subst"
        else:
            if c == "'":
                state = "'"
            elif c == '"':
                state = '"'
            elif c == "\\":
                i += 1
            elif c == "`":
                return "subst"
            elif c == "$" and i + 1 < n and cmd[i + 1] == "(":
                return "subst"
            elif c in "|&;()<>\n":
                return "compound"
        i += 1
    return "unparsable" if state is not None else None


def _is_operand(tok):
    """`-` で始まらず `::`（git のリモートヘルパー記法）を含まない 1 トークンだけを許す。"""
    return not tok.startswith("-") and "::" not in tok


def bash_allowed(cmd):
    """受理する文法だけを読める形として通す（負の列挙ではなく正の列挙）:
    git ( -C <path> )* <subcommand> <arg>*
    - `-c <k=v>` は値によらず一律拒否。`-C` 以外のグローバルオプションも拒否
    - サブコマンドは status/diff/add/commit/push のみ
    - それ以降は (a) 許可オプション表にある形 (b) 値オプション直後の自由な値
      (c) `-` で始まらず `::` を含まないオペランド、の 3 通りだけを許す
    """
    if scan_command(cmd) is not None:
        return False
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return False
    if not tokens or tokens[0] != "git":
        return False
    n = len(tokens)
    i = 1
    while i < n and tokens[i] == "-C":
        i += 1
        if i >= n or not tokens[i] or tokens[i].startswith("-"):
            return False                    # 値なし・空・`-` 始まりは拒否
        i += 1
    if i >= n:
        return False
    if tokens[i] == "-c":
        return False                        # `-c` はキーの値によらず一律拒否
    sub = tokens[i]
    if sub not in GIT_OK:
        return False
    i += 1
    allowed = GIT_ALLOWED_OPTS.get(sub, set())
    value_opts = GIT_VALUE_OPTS.get(sub, set())
    value_prefixes = GIT_VALUE_PREFIXES.get(sub, ())
    while i < n:
        tok = tokens[i]
        if tok in GIT_COMMON_OPTS or tok in allowed or tok.startswith(value_prefixes):
            i += 1
            continue
        if tok in value_opts:
            i += 1
            if i >= n:
                return False                 # 値が無い
            i += 1                           # 値の中身は自由
            continue
        if _is_operand(tok):
            i += 1
            continue
        return False                         # 表に無いオプションは危険と分かっていなくても拒否
    return True


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
reason = STOP.format(ctx=ctx, hard=hard)
if tool in ("Edit", "Write", "NotebookEdit"):
    pass
elif tool == "Bash":
    inp = payload.get("tool_input")
    cmd = inp.get("command") if isinstance(inp, dict) else None
    if bash_allowed(cmd):
        sys.exit(0)
    reason += BASH_HINT
else:
    sys.exit(0)                 # 読み取り系はここに来ない（matcher でも絞っている）が念のため

emit({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                             "permissionDecision": "deny",
                             "permissionDecisionReason": reason}})
sys.exit(0)
PY
