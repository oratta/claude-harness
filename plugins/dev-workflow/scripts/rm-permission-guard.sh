#!/usr/bin/env bash
# PermissionRequest hook（matcher: Bash）: サブエージェント（子）の rm の確認画面に、親の 1 回だけの許可に従って答える。
# 権限確認を省くモードの子の、rm の判定に当たらない確認画面は拒否する。
#
# spec: rm-permission-hook。Claude Code 本体の rm の確認画面（Dangerous rm operation on statically-unresolvable
# target など）は PreToolUse の allow では通せず、PermissionRequest hook だけが答えられる（#1132 の実機確認）。
# 入力にはなぜ確認が出たかが無いので、コマンド文字列から自分で判定する。
#
# 答える範囲: payload の agent_id が空でない文字列（子）で、tool_input.command が文字列のときだけ。
#   - 単純コマンドのどれかの先頭の語が rm なら、下の答え方で答える。
#   - rm の入口の形に当たらず、permission_mode がちょうど bypassPermissions なら、許可も拒否の記録も使わずに deny と
#     打ち直し方（本文をファイルに書いて --body-file で渡す等）・親に返る条件を返す（#1610。bypassPermissions で
#     確認画面が出るのは規則で許可できない安全確認だけで、誰も見ていない子がそこで止まり続けるため）。
#     それ以外のモード（default・acceptEdits・plan・無い）は普通の権限確認と見分けられないので何も出さない。
#   それ以外（主の呼び出し・読めない payload・python3 が無い）は何も出力せず exit 0
#   （本体の確認画面か今までの拒否に任せる）。
# 答え方: git-destructive-guard.sh と同じ key（session_id・agent_id・cwd・command の sha256）の
#   <base>/permits/<key>.json を rename で取り、4 値の一致・期限・使う時点の rm 用の一時領域の判定（共通ファイル
#   git-guard-scratchpad.py の check_rm）を満たせば allow。それ以外は deny と、何を・なぜを報告に書いて親に返す理由。
#   <base> は ${TMPDIR:-/tmp}/dev-workflow-git-guard。許可を書くのは親の git-guard-permit.sh。
#   deny のたびに拒否の記録 <base>/denied/<key>.json を書く（共通ファイルを読めないときと書けないときは書かず、
#   理由もパスを示さない）。回数を数えての打ち切りはしない。
#   許可を使う前に <base> を共通ファイルの check_base で確かめ、満たさなければ許可を探さず、記録も
#   permit-log.jsonl の行も書かずに deny を返す（<base> の中のファイルは共通ファイルの関数で symlink を辿らずに開く）。
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0
payload="$(cat)" || exit 0
[ -n "$payload" ] || exit 0

PY_SRC=""
IFS= read -r -d '' PY_SRC <<'PY' || true
import json, os, sys, time

try:
    p = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
if not isinstance(p, dict):
    sys.exit(0)
ti = p.get("tool_input")
command = ti.get("command") if isinstance(ti, dict) else None
agent_id = p.get("agent_id")
if not isinstance(command, str) or not isinstance(agent_id, str) or agent_id == "":
    sys.exit(0)


def load_common():
    path = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        ns = {"__name__": "git_guard_scratchpad"}
        exec(compile(src, path, "exec"), ns)
        for name in ("key_of", "check_rm", "is_rm_command", "append_log", "write_json_atomic", "check_base",
                     "read_json_nofollow"):
            if not callable(ns.get(name)):
                return None
        return ns
    except Exception:
        return None


def emit(behavior, message=None):
    d = {"behavior": behavior}
    if message is not None:
        d["message"] = message
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": d}}, ensure_ascii=False))
    sys.exit(0)


def not_rm():
    """rm の入口の形に当たらない子の確認。権限確認を省くモード（bypassPermissions）では確認画面が規則で許可できない
    安全確認のときだけ出て、誰も見ていない子がそこで止まり続けるので、許可も記録も使わずに deny して打ち直し方を返す。
    それ以外のモードは普通の権限確認と見分けられないので何も出さない（#1610）。"""
    if p.get("permission_mode") != "bypassPermissions":
        sys.exit(0)
    emit("deny", "[dev-workflow rm-permission-guard] rm の判定に当たらないコマンドで Claude Code 本体が確認を求めたので、"
         "実行していない。確認の原因が本文の引用や置換（$(...)・逆引用符）なら、本文をファイルに書いて --body-file で渡すなど、"
         "それらを本文に入れない形で打ち直せる。打ち直せなければ、何をしたかったか（コマンドの全文）を報告に書いて親に返ること。")


common = load_common()
# 入口の形（先頭の語が rm）は共通ファイルで判定する。読めないときは同じ判定を簡易に行う
if common is not None:
    if not common["is_rm_command"](command):
        not_rm()
else:
    import re
    if not any(s.split()[:1] == ["rm"] for s in re.split(r"&&|\|\||[;&|\n]", command)):
        not_rm()


def str_field(name):
    v = p.get(name)
    return v if isinstance(v, str) else ""


session_id, cwd = str_field("session_id"), str_field("cwd")
base = os.path.join(os.environ.get("TMPDIR") or "/tmp", "dev-workflow-git-guard")


def log_event(entry):
    try:
        common["append_log"](base, entry)
    except Exception:
        pass


def use_permit(key):
    """一致する許可があり、使う時点の判定も満たせば ("allow", None)。判定を満たさず捨てたら ("unverified", 理由)。
    許可が無い・一致しない・期限切れなら None。取った許可は必ず消す。"""
    path = os.path.join(base, "permits", key + ".json")
    taken = "%s.taken.%d" % (path, os.getpid())
    try:
        os.rename(path, taken)
    except OSError:
        return None
    try:
        perm = common["read_json_nofollow"](taken)  # symlink なら読めないものとして消す（先は読まない）
    except Exception:
        perm = None
    finally:
        try:
            os.unlink(taken)
        except OSError:
            pass
    if not isinstance(perm, dict):
        return None
    vals = {"session_id": session_id, "agent_id": agent_id, "cwd": cwd, "command": command}
    if any(perm.get(k) != v for k, v in vals.items()):
        return None
    exp = perm.get("expires_at")
    entry = dict(vals, key=key)
    if not isinstance(exp, (int, float)) or isinstance(exp, bool) or exp <= time.time():
        log_event(dict(entry, event="expired", expires_at=exp))
        return None
    try:
        err, sp, targets = common["check_rm"](session_id, cwd, command)
    except Exception as e:
        err, sp, targets = "一時領域の判定が失敗した: %s" % e, None, None
    if err:
        log_event(dict(entry, event="rejected", error=err))
        return ("unverified", err)
    log_event(dict(entry, event="use", scratchpad=sp, repos=targets, reason=perm.get("reason")))
    return ("allow", None)


key = common["key_of"](session_id, agent_id, cwd, command) if common else None
# <base> は許可を使う前に確かめる。満たさなければ許可を探さず、記録も permit-log.jsonl の行も書かない
# （spec rm-permission-hook「rm の hook も <base> を確かめてから使う」）
base_err = None
if key:
    try:
        base_err = common["check_base"](base)
    except Exception as e:
        base_err = "確かめが失敗した（%s）" % e
used = use_permit(key) if key and not base_err else None
if used and used[0] == "allow":
    emit("allow")

record_path = None
if key and not base_err:
    path = os.path.join(base, "denied", key + ".json")
    rec = {"session_id": session_id, "agent_id": agent_id, "cwd": cwd, "command": command,
           "kinds": ["rm"], "time": int(time.time())}
    try:
        common["write_json_atomic"](path, rec)
        record_path = path
    except Exception:
        record_path = None

msg = "[dev-workflow rm-permission-guard] この rm は親の許可が無いので実行していない。"
if used:
    msg += "許可はあるが行き先を確かめられない（%s）。" % used[1]
msg += ("何を（コマンドの全文）・なぜ消したかったかを報告に書いて、親に返すこと。同じコマンドや言い換えを打ち直さない。"
        "親の許可を受けられる打ち方の例は、変数を使わず実パスで単独のコマンドとして打つこと（変数や置換を含む形は親が許可を書けない）。"
        "親が一時領域の中と確かめて許可を書いたら、親が子を再開する。")
if record_path:
    msg += "拒否の記録: " + record_path + " 。親に返す報告にこのパスを書く。"
elif base_err:
    msg += ("拒否の記録を作れなかった（拒否の記録の置き場所 " + base + " を確かめられない: " + base_err
            + "）。親に返す報告にコマンドの全文と cwd を書き、この置き場所の問題も書く。")
else:
    msg += "拒否の記録を作れなかった。親に返す報告にコマンドの全文と cwd を書く。"
emit("deny", msg)
PY
if [ -z "$PY_SRC" ]; then
  echo "rm-permission-guard: 判定の本体を読めなかったため、答えていない" >&2
  exit 0
fi
printf '%s' "$payload" | python3 -I -c "$PY_SRC" "$(dirname "$0")/git-guard-scratchpad.py"
exit 0
