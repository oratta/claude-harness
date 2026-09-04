#!/usr/bin/env bash
# accounts-init.sh: 現在のシェルのアカウントを ${CLAUDE_ACCOUNTS_FILE} に 1 スロットとして登録する。
#
# レジストリの正本は openspec/specs/usage-account-registry。ここは雛形の生成手段であって、
# 仕様の定義ではない。
#
# 使い方（登録したいアカウントの環境で実行すること）:
#   CLAUDE_SECURESTORAGE_CONFIG_DIR を設定していないシェル: ./accounts-init.sh --id a --label A
#   B アカウントのシェル:                                   ./accounts-init.sh --id b --label B
#
# securestorage には環境変数 CLAUDE_SECURESTORAGE_CONFIG_DIR の**実値をそのまま**書き出す。
# 人手でパスを転記すると、末尾スラッシュや ~ 展開の差で Keychain のサービス名が変わり、
# 別アカウント扱いになって残量が取れなくなるため。
#
# 同じ id が既にあれば上書きし、無ければ末尾に追加する。
set -uo pipefail

ACCOUNTS_FILE="${CLAUDE_ACCOUNTS_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json}"
SLOT_ID=""
SLOT_LABEL=""

usage() {
  cat <<'USAGE'
usage: accounts-init.sh --id <slot-id> [--label <label>]

  --id     スロット id（英数字とハイフン、1〜32 文字）。snapshot のキーになる
  --label  statusline に出す短いラベル（省略時は id）

登録先は ${CLAUDE_ACCOUNTS_FILE}、無ければ ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json。
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --id)    SLOT_ID="${2:-}"; shift 2 ;;
    --label) SLOT_LABEL="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$SLOT_ID" ]; then
  printf '--id is required\n' >&2
  usage >&2
  exit 2
fi
case "$SLOT_ID" in
  *[!A-Za-z0-9-]*|"") printf 'invalid --id: %s\n' "$SLOT_ID" >&2; exit 2 ;;
esac
[ "${#SLOT_ID}" -le 32 ] || { printf '--id is too long (max 32)\n' >&2; exit 2; }
[ -n "$SLOT_LABEL" ] || SLOT_LABEL="$SLOT_ID"

dir="$(dirname "$ACCOUNTS_FILE")"
mkdir -p "$dir" || exit 1

ACCOUNTS_FILE="$ACCOUNTS_FILE" SLOT_ID="$SLOT_ID" SLOT_LABEL="$SLOT_LABEL" \
SLOT_SECURE="${CLAUDE_SECURESTORAGE_CONFIG_DIR-}" python3 <<'PY' || exit 1
import json, os, sys

path = os.environ["ACCOUNTS_FILE"]
sid = os.environ["SLOT_ID"]
label = os.environ["SLOT_LABEL"]
# 環境変数の実値をそのまま記録する（未設定・空文字は既定アカウント = null）
secure = os.environ.get("SLOT_SECURE") or None

doc = {"schema": 1, "accounts": []}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as fh:
            loaded = json.load(fh)
        if isinstance(loaded, dict) and isinstance(loaded.get("accounts"), list):
            doc = loaded
    except Exception:
        # 壊れているレジストリは上書きしない（消失事故を避ける）
        sys.stderr.write("existing registry is not valid JSON: %s\n" % path)
        raise SystemExit(1)

entry = {"id": sid, "label": label, "securestorage": secure}
for i, existing in enumerate(doc["accounts"]):
    if isinstance(existing, dict) and existing.get("id") == sid:
        doc["accounts"][i] = entry
        break
else:
    doc["accounts"].append(entry)

tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
os.replace(tmp, path)
sys.stderr.write("registered slot %r (securestorage=%s) in %s\n" % (sid, secure, path))
PY
