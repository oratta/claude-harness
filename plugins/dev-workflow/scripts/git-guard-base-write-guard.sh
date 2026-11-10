#!/usr/bin/env bash
# PreToolUse hook（matcher: Write|Edit|NotebookEdit）: 子（サブエージェント）が git ガードの置き場所
# （${TMPDIR:-/tmp}/dev-workflow-git-guard。拒否の記録・回数・許可を置くフォルダ。以下 <base>）にツールで書くのを止める
# （issue #1155。spec destructive-git-hook「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」）。
#
# 拒否された子が親に返らずに、許可（<base>/permits/<key>.json）を自分で置く分かりやすい書き方を止める。
# セキュリティ境界ではない。子・hook・親は同じ uid で動き、Bash からの書き込み・変数で組み立てたパス・MCP の
# 書き込みなどは通る（通すことを許す入力の正本は spec の「守備範囲」）。Bash で置き場所を名指しするコマンドは
# git ガード（scripts/git-destructive-guard.sh）の permit-store が止める。
#
# 判定: payload の agent_id が空でない文字列（子）で、書き先（Write / Edit は tool_input.file_path、NotebookEdit は
# tool_input.notebook_path。相対なら cwd を前に付ける）を、.. を畳んだパスと symlink を辿ったパスの両方で / で区切り、
# どれかの部品が大文字小文字を区別せずに dev-workflow-git-guard と一致すれば deny。<base> の中はすべて止める
# （回数や拒否の記録を書き換える用事も子には無い）。<base> を作らず、回数・拒否の記録・許可に触れない（数えない）。
# 置き場所の名前は共通ファイル（git-guard-scratchpad.py の BASE_NAME）を読まずにここにも書く（共通ファイルを読めないと
# 止められなくなるため。食い違わないことは tests/git-guard-base-write-guard.bats で確かめる）。
#
# DEV_WORKFLOW_GIT_GUARD=off で全許可（git ガードと同じ逃げ道）。
# fail-open: python3 が無い・payload が読めない・3 つのツール以外・書き先が文字列でないときは何も出さず exit 0。
set -uo pipefail

[ "${DEV_WORKFLOW_GIT_GUARD:-on}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# 主の呼び出しと置き場所に無関係な書き込みの大多数で python3 を起動しない。payload 全体の文字列で必要条件だけを見る:
# 置き場所の名前（大文字小文字を問わない）・\u00（名前を \uXXXX で書いたもの）・agent_id（子の判定に要る。symlink を
# 経た書き先はパスに名前が出ないので、子の呼び出しは名前が無くても起動する）。誤りは余計に起動する向きにしか起きない。
payload="$(cat)" || exit 0
shopt -s nocasematch
case "$payload" in
  *dev-workflow-git-guard*) ;;
  *'\u00'*) ;;
  *agent_id*) ;;
  *) exit 0 ;;
esac
shopt -u nocasematch

# 本体は変数に読んで python3 -I -c で渡す（git-destructive-guard.sh と同じ形。/dev/fd/3 は #869 の理由で使わない）
PY_SRC=""
IFS= read -r -d '' PY_SRC <<'PY' || true
import json, os, sys

BASE_NAME = "dev-workflow-git-guard"
FIELDS = {"Write": "file_path", "Edit": "file_path", "NotebookEdit": "notebook_path"}

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(payload, dict) or payload.get("tool_name") not in FIELDS:
    sys.exit(0)
agent_id = payload.get("agent_id")
if not isinstance(agent_id, str) or agent_id == "":
    sys.exit(0)  # 主の呼び出しは止めない
inp = payload.get("tool_input")
if not isinstance(inp, dict):
    sys.exit(0)
path = inp.get(FIELDS[payload["tool_name"]])
if not isinstance(path, str) or path == "":
    sys.exit(0)
cwd = payload.get("cwd")
if not os.path.isabs(path) and isinstance(cwd, str) and cwd != "":
    path = os.path.join(cwd, path)


def hits(p):
    # macOS の既定のファイルシステムは大文字小文字を区別しないので、部品は大文字小文字を区別せずに比べる
    return any(part.casefold() == BASE_NAME for part in p.split(os.sep))


candidates = []
for f in (os.path.normpath, os.path.realpath):
    try:
        candidates.append(f(path))
    except Exception:
        pass  # NUL を含むパスなど。辿れなければ残りの形で見る
if not any(hits(c) for c in candidates):
    sys.exit(0)

# 理由文に置き場所の 2 つの名前を並べない（子が理由文を報告用のコマンドに写したとき、そのコマンドが git ガードに
# 止まらないようにする）。書き先のパスも載せない
reason = ("[dev-workflow git-guard-base-write-guard] 子（サブエージェント）は、許可の置き場所（git ガードが拒否の記録・"
          "回数・許可を置くフォルダ）に Write / Edit / NotebookEdit で書けない。許可を書くのは親の役目。"
          "この書き込みは実行されない。打ち直さず、別の書き方（Bash など）も試さないこと。作業を止め、報告に、"
          "書きたかったファイルのパス・なぜ要るか・拒否されたコマンドがあればその全文と拒否の記録のパス、を書いて親に返す。")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                         "permissionDecisionReason": reason}}, ensure_ascii=False))
PY
if [ -z "$PY_SRC" ]; then
  # 本体を読めなかった（ヒアドキュメントの一時ファイルを作れない等）。空の本体を python3 に渡すと
  # rc=0・無出力で終わって黙って通すので、渡さずに stderr で知らせる。
  echo "git-guard-base-write-guard: 判定の本体を読めなかったため、判定していない" >&2
  exit 1
fi
printf '%s' "$payload" | python3 -I -c "$PY_SRC"
exit 0
