#!/usr/bin/env bash
# accounts.sh: アカウント登録簿（accounts.json）の一覧・追加・オン・オフ。
#
# 登録簿の正本は openspec/specs/usage-account-registry。ここは操作の手段であって、仕様の定義ではない。
#
# 使い方:
#   accounts.sh list                         一覧（id, label, on|off, securestorage をタブ区切りで 1 行ずつ）
#   accounts.sh add <id> [--label <label>]   認証情報の置き場所を作って登録し、ログインするコマンドを 1 行出す
#   accounts.sh off <id>                     enabled を false にする（登録と認証情報は消さない）
#   accounts.sh on <id>                      enabled を true にする
#
# accounts-init.sh との使い分け:
#   accounts-init.sh は「いま居るシェルの CLAUDE_SECURESTORAGE_CONFIG_DIR の実値を登録する」手段で、
#   同じ id は上書きする。既定アカウント（securestorage が null）のスロットもこちらで作る。
#   accounts.sh add は置き場所（<CLAUDE_ACCOUNTS_HOME>/<id>）を新しく作って登録し、同じ id は拒否する。
#   accounts.sh は登録簿が読めない・accounts が配列でないときは何も書かず exit 1（accounts-init.sh は
#   accounts が配列でないと空の登録簿として上書きする）。
#
# 書き換える前に既存の登録簿を <登録簿>.bak へ控える（1 世代。続けて実行すると上書きされる）。
# 書き込みは一時ファイル + os.replace。
#
# 環境変数:
#   CLAUDE_ACCOUNTS_FILE  登録簿の場所（無ければ ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json）
#   CLAUDE_ACCOUNTS_HOME  認証情報の置き場所の基点（絶対パス。既定 $HOME/.claude-accounts）
set -uo pipefail

ACCOUNTS_FILE="${CLAUDE_ACCOUNTS_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json}"
ACCOUNTS_HOME="${CLAUDE_ACCOUNTS_HOME:-$HOME/.claude-accounts}"

# usage [fd]: 既定は stderr（引数の誤り）。-h/--help のときだけ usage 1 で stdout に出す。
usage() {
  if [ "${1:-}" = "stdout" ]; then exec 3>&1; else exec 3>&2; fi
  cat >&3 <<'USAGE'
usage: accounts.sh list
       accounts.sh add <id> [--label <label>]
       accounts.sh off <id>
       accounts.sh on <id>

  id     英数字とハイフン、1〜32 文字
  label  制御文字を含まない 16 文字以下（省略時は id）
USAGE
}

die_usage() { printf '%s\n' "$1" >&2; usage; exit 2; }

check_id() {
  # bash 3.2 + UTF-8 ロケールでは [!A-Za-z0-9-] が照合順で評価され、全角の英数字が通る。
  local LC_ALL=C
  case "$1" in
    ""|*[!A-Za-z0-9-]*) die_usage "invalid id: $1" ;;
  esac
  [ "${#1}" -le 32 ] || die_usage "id is too long (max 32)"
}

[ $# -ge 1 ] || { usage; exit 2; }
CMD="$1"; shift
ID=""
LABEL=""

case "$CMD" in
  -h|--help) usage stdout; exit 0 ;;
  list)
    [ $# -eq 0 ] || die_usage "list takes no arguments"
    ;;
  on|off)
    [ $# -ge 1 ] || die_usage "$CMD requires <id>"
    [ $# -eq 1 ] || die_usage "unexpected argument: $2"
    ID="$1"; check_id "$ID"
    ;;
  add)
    [ $# -ge 1 ] || die_usage "add requires <id>"
    case "$1" in
      -h|--help) usage stdout; exit 0 ;;
      --label) die_usage "add requires <id> before --label" ;;
    esac
    ID="$1"; shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --label)
          [ $# -ge 2 ] || die_usage "--label requires a value"
          LABEL="$2"; shift 2 ;;
        *) die_usage "unknown option: $1" ;;
      esac
    done
    check_id "$ID"
    [ -n "$LABEL" ] || LABEL="$ID"
    case "$LABEL" in
      *[[:cntrl:]]*) die_usage "--label must not contain control characters" ;;
    esac
    [ "${#LABEL}" -le 16 ] || die_usage "--label is too long (max 16)"
    case "$ACCOUNTS_HOME" in
      /*) ;;
      *) die_usage "CLAUDE_ACCOUNTS_HOME must be an absolute path: $ACCOUNTS_HOME" ;;
    esac
    ;;
  *) die_usage "unknown subcommand: $CMD" ;;
esac

ACCOUNTS_FILE="$ACCOUNTS_FILE" ACCOUNTS_HOME="$ACCOUNTS_HOME" CMD="$CMD" SLOT_ID="$ID" SLOT_LABEL="$LABEL" \
python3 <<'PY'
import json, os, shutil, sys, tempfile

path = os.environ["ACCOUNTS_FILE"]
cmd = os.environ["CMD"]
sid = os.environ["SLOT_ID"]

def err(msg, code):
    sys.stderr.write(msg + "\n")
    raise SystemExit(code)

doc = {"schema": 1, "accounts": []}
exists = os.path.exists(path)
if exists:
    try:
        with open(path, encoding="utf-8") as fh:
            loaded = json.load(fh)
    except Exception:
        err("registry is not valid JSON (nothing written): %s" % path, 1)
    if not isinstance(loaded, dict) or not isinstance(loaded.get("accounts"), list):
        err('registry is not an object with an "accounts" array (nothing written): %s' % path, 1)
    doc = loaded
elif cmd in ("on", "off"):
    err("no such id in registry: %s (%s does not exist)" % (sid, path), 2)

accounts = doc["accounts"]

def find(i):
    for idx, s in enumerate(accounts):
        if isinstance(s, dict) and s.get("id") == i:
            return idx
    return -1

def write(d):
    d_dir = os.path.dirname(path) or "."
    os.makedirs(d_dir, exist_ok=True)
    if exists:
        shutil.copyfile(path, path + ".bak")
    fd, tmp = tempfile.mkstemp(dir=d_dir, prefix=".accounts-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(d, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

if cmd == "list":
    for s in accounts:
        if not isinstance(s, dict):
            continue
        sec = s.get("securestorage")
        row = [str(s.get("id", "-")), str(s.get("label", "-")),
               "off" if s.get("enabled") is False else "on",
               "-" if sec is None else str(sec)]
        print("\t".join(row))
elif cmd in ("on", "off"):
    idx = find(sid)
    if idx < 0:
        err("no such id in registry: %s" % sid, 2)
    accounts[idx]["enabled"] = (cmd == "on")
    write(doc)
    sys.stderr.write("%s: %s\n" % (sid, cmd))
elif cmd == "add":
    if find(sid) >= 0:
        err("id already registered: %s" % sid, 2)
    place = os.path.join(os.environ["ACCOUNTS_HOME"], sid)
    try:
        os.makedirs(place, exist_ok=True)
    except OSError as e:
        err("cannot create %s: %s" % (place, e), 1)
    accounts.append({"id": sid, "label": os.environ["SLOT_LABEL"], "securestorage": place})
    write(doc)
    sys.stderr.write("registered slot %r (securestorage=%s) in %s\n" % (sid, place, path))
    quoted = "'" + place.replace("'", "'\\''") + "'"
    print("CLAUDE_SECURESTORAGE_CONFIG_DIR=%s claude" % quoted)
PY
