#!/usr/bin/env bash
# 親が、拒否されて返ってきた子のコマンドを 1 回だけ通す許可を書く（spec destructive-git-hook の要件
# 「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）。
#
# 使い方: git-guard-permit.sh <拒否の記録のパス> <理由>
#   拒否の記録は git-destructive-guard.sh が子を拒否したときに <base>/denied/<key>.json に書き、そのパスを子への
#   拒否理由に載せたもの（子は親への報告にこのパスを書く）。<base> は記録のパスの 2 つ上で、TMPDIR は見ない
#   （hook と親の Bash で TMPDIR が違いうるため）。
#
# 許可を書くのは、記録のコマンドが触る repo がすべてそのセッションの scratchpad の中にあると、共通ファイル
# git-guard-scratchpad.py の判定（git を実行しない）で確かめられたときだけ。許可は 15 分で切れ、1 回で消える。
# hook は許可を使う時点でも同じ判定をかけ直す。許可を書いたら、その子の拒否の回数を 0 に戻す。
#
# 終了コード: 0 = 許可を書いた／1 = 確かめられなかったので書かない（理由は stderr）／2 = 使い方の誤り／
#   3 = 一時領域の判定に落ち、記録のコマンドが単独のコマンドの形（判定が許す文字だけで、; & 改行を含まない）
#   でないので書かない（実パスの単独のコマンドに打ち直せば、新しい拒否の記録で判定し直せる。許可を書くかどうかは
#   1 と変わらない）
# 子がこのスクリプトを呼ぶと git-destructive-guard.sh が拒否する（許可を書くのは親の役目）。
set -uo pipefail

if [ "$#" -ne 2 ] || [ -z "${2//[[:space:]]/}" ]; then
  echo "使い方: git-guard-permit.sh <拒否の記録のパス> <理由（空でない）>" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "git-guard-permit: python3 が無いため許可を書かない" >&2
  exit 1
fi

# 本体の渡し方は git-destructive-guard.sh と同じ（ヒアドキュメントで変数に読み、-c で渡す。/dev/fd/3 は使わない: #869）
PY_SRC=""
IFS= read -r -d '' PY_SRC <<'PY' || true
import json, os, sys, time

common_path, rec_arg, reason = sys.argv[1], sys.argv[2], sys.argv[3]


def fail(msg):
    sys.stderr.write("git-guard-permit: 許可を書かない: " + msg + "\n")
    sys.exit(1)


def single_shaped(command):
    """単独のコマンドの形か（使う判定が許す文字だけで、; & 改行を含まない）。True / False、取り出せなければ None。
    文字の集合と git 用か rm 用かの決め方は共通ファイルのものを使い、書き写さない。None は 1 に倒す側。"""
    try:
        chars = C["_RM_ALLOWED_CHARS"] if C["is_rm_command"](command) else C["_ALLOWED_CHARS"]
        if not chars.match(command):
            return False
    except Exception:
        return None
    return not any(c in command for c in ";&\n")


try:
    with open(common_path, encoding="utf-8") as fh:
        src = fh.read()
    C = {"__name__": "git_guard_scratchpad"}
    exec(compile(src, common_path, "exec"), C)
except Exception as e:
    fail("共通の判定ファイル %s を読めない（%s）" % (common_path, e))

rec_path = os.path.abspath(rec_arg)
denied = os.path.dirname(rec_path)
base = os.path.dirname(denied)
name = os.path.basename(rec_path)
if os.path.basename(denied) != "denied" or os.path.basename(base) != C["BASE_NAME"]:
    fail("記録が <%s>/denied/<key>.json の形の場所にない: %s" % (C["BASE_NAME"], rec_path))
if not name.endswith(".json") or not C["is_key"](name[:-len(".json")]):
    fail("記録のファイル名が <key>.json の形でない: %s" % name)
key = name[:-len(".json")]
# 記録の場所から求めた <base> を hook と同じ確かめにかける。満たさなければ許可も permit-log.jsonl の行も書かず、
# 回数のファイルも消さない（spec「許可を書くスクリプトは確かめを満たさない <base> に書かない」）
try:
    base_err = C["check_base"](base)
except Exception as e:
    base_err = "確かめが失敗した（%s）" % e
if base_err:
    fail("拒否の記録の置き場所 %s を確かめられない: %s" % (base, base_err))
try:
    rec = C["read_json_nofollow"](rec_path)  # symlink の記録は読まない
except Exception as e:
    fail("記録を読めない（symlink か、普通のファイルでないか、壊れている: %s）" % e)
if not isinstance(rec, dict):
    fail("記録の中身がオブジェクトでない")
vals = {k: rec.get(k) for k in ("session_id", "agent_id", "cwd", "command")}
for k, v in vals.items():
    if not isinstance(v, str):
        fail("記録の %s が文字列でない" % k)
if vals["agent_id"] == "":
    fail("記録の agent_id が空（子の拒否の記録でない）")
if C["key_of"](vals["session_id"], vals["agent_id"], vals["cwd"], vals["command"]) != key:
    fail("記録の中身から計算した key がファイル名と一致しない（書き換えられたか、別の場所の記録）")

# hook は <base> を自分の TMPDIR（未設定か空なら /tmp）の下に置き、同じ TMPDIR で一時フォルダの候補を数える。
# 自分の TMPDIR で数えると hook が使えない許可を書くので、記録の場所から hook の TMPDIR を求めて渡す
err, sp, repos = C["check_command"](vals["session_id"], vals["cwd"], vals["command"], temp_dir=os.path.dirname(base))
if err:
    if single_shaped(vals["command"]) is False:
        sys.stderr.write("git-guard-permit: 許可を書かない: 一時領域の判定を満たさない: " + err + "\n")
        sys.stderr.write("git-guard-permit: 形の理由で断った: 変数・置換・引用符を使わず実パスで書き、&&・;・改行で"
                         "つながない単独のコマンドに打ち直せば、新しい拒否の記録で判定し直せる\n")
        sys.exit(3)
    fail("一時領域の判定を満たさない: " + err)

now = int(time.time())
permit = dict(vals, scratchpad=sp, repos=repos, reason=reason, created_at=now, expires_at=now + C["PERMIT_TTL"])
try:
    C["append_log"](base, dict(permit, event="permit", time=now))
except Exception as e:
    fail("記録 %s に追記できない（%s）" % (os.path.join(base, "permit-log.jsonl"), e))
try:
    C["write_json_atomic"](os.path.join(base, "permits", key + ".json"), permit)
except Exception as e:
    fail("許可を置けない（%s）" % e)

count = os.path.join(base, C["count_name"](vals["session_id"], vals["agent_id"]))
try:
    os.unlink(count)
except FileNotFoundError:
    pass
except OSError as e:
    sys.stderr.write("git-guard-permit: 拒否の回数のファイル %s を消せなかった（%s）。許可は有効\n" % (count, e))

print("許可を書いた（この 1 回だけ。期限 %s）" % time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(permit["expires_at"])))
print("コマンド: " + vals["command"].replace("\n", "\\n"))
print("cwd: " + vals["cwd"])
print("scratchpad: " + sp)
print("確かめた repo: " + "、".join(repos))
PY
if [ -z "$PY_SRC" ]; then
  echo "git-guard-permit: 本体を読めなかったため許可を書かない" >&2
  exit 1
fi
python3 -I -c "$PY_SRC" "$(dirname "$0")/git-guard-scratchpad.py" "$1" "$2"
