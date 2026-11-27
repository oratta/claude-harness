#!/usr/bin/env bash
# SessionStart hook（source が compact のときだけ働く）: その会話で develop を呼んでいたら、
# skills/develop/SKILL.md の読み直しと、エピックの親か子かの確かめ直しを差し込む（#1217）。
#
# コンパクト後に Claude Code が貼り直すのは呼んだスキル（入口の commands/develop.md）と小さい最近読んだ
# ファイルだけで、SKILL.md 本体は要約に置き換わる。要約の上では読んだことになっているので、
# モデルは読み直さずに進む。それを防ぐ。
#
# develop を呼んだかの判定は会話記録（stdin の transcript_path の jsonl）で行う。SessionStart(compact) の
# 時点では、今回のコンパクトの compact_boundary も invoked_skills もまだ書かれていない（#1217 の実機確認）。
# 書かれているのはコンパクト前の記録なので、次のどれかが 1 つあれば「呼んでいた」とみなす:
#   - assistant の Skill 呼び出しで input.skill が dev-workflow:develop
#   - user の発言（文字列、または一覧の text のブロック）にある <command-name>/dev-workflow:develop</command-name>
#   - 前のコンパクトのあとの invoked_skills の記録に dev-workflow:develop がある
# 名前空間の無い develop は数えない。プラグインのコマンドは /develop と打っても /dev-workflow:develop と
# 記録されるので、名前空間の無い名前で拾えるのは利用者の別のスキルやコマンドだけになる。
# 文中で名前に触れただけのもの（assistant の text・tool_result の中身）は数えない。
# 形の違う行（値の型が想定と違うなど）は 1 行ずつ飛ばし、走査は続ける。
#
# 判定できないとき（stdin が JSON でない・会話記録が無い・CLAUDE_PLUGIN_ROOT が空・python3 が無い）は
# 何も出さない（fail-open）。常に exit 0（セッション開始を止めない）。
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$ROOT" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null)" || exit 0
[ -n "$INPUT" ] || exit 0

HOOK_INPUT="$INPUT" SKILL_PATH="${ROOT}/skills/develop/SKILL.md" python3 -I -c '
import json, os, re, sys

try:
    hook = json.loads(os.environ["HOOK_INPUT"])
except Exception:
    sys.exit(0)
if not isinstance(hook, dict) or hook.get("source") != "compact":
    sys.exit(0)
tp = hook.get("transcript_path")
if not isinstance(tp, str) or not tp or not os.path.isfile(tp):
    sys.exit(0)

NAME = "dev-workflow:develop"
CMD = re.compile(r"<command-name>/dev-workflow:develop</command-name>")

def called(d):
    t = d.get("type")
    msg = d.get("message")
    content = msg.get("content") if isinstance(msg, dict) else None
    if t == "assistant" and isinstance(content, list):
        for c in content:
            if (isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Skill"
                    and isinstance(c.get("input"), dict) and c["input"].get("skill") == NAME):
                return True
    if t == "user":
        if isinstance(content, str) and CMD.search(content):
            return True
        if isinstance(content, list):
            for c in content:
                if (isinstance(c, dict) and c.get("type") == "text" and isinstance(c.get("text"), str)
                        and CMD.search(c["text"])):
                    return True
    if t == "attachment":
        a = d.get("attachment")
        if isinstance(a, dict) and a.get("type") == "invoked_skills":
            for s in a.get("skills") or []:
                if isinstance(s, dict) and s.get("name") == NAME:
                    return True
    return False

found = False
try:
    with open(tp, encoding="utf-8", errors="replace") as f:
        for line in f:
            # 速さのため、名前を含まない行は JSON として読まない
            if "develop" not in line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            try:
                hit = isinstance(d, dict) and called(d)
            except Exception:
                continue
            if hit:
                found = True
                break
except Exception:
    sys.exit(0)
if not found:
    sys.exit(0)

text = ("このセッションはコンパクトされ、コンパクトの前に develop を呼んでいた。要約の上では develop の手順を読んだことになっているが、"
        "手順の本体（" + os.environ["SKILL_PATH"] + "）は要約に置き換わっていて手元に無い。続ける前に、"
        "この SKILL.md を Read ツールで読み直し（1 回では上限に当たるので offset と limit で 2 回に分けて読む）、自分がエピックの親か子かを記録先の issue から確かめ直してから続ける。")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}, ensure_ascii=False))
' 2>/dev/null
exit 0
