#!/bin/sh
# Decide the start-comment mode without reading state or invoking operation tools.
set -u

usage() {
  printf '%s\n' 'Usage: develop-mode.sh [--unmanned] [--channel-request]' \
    '  --unmanned: develop の引数に --unmanned があるときだけ渡す。' \
    '  --channel-request: 今回の依頼本文が <channel source= で始まるときだけ渡す。引用や単なる Discord への言及では渡さない。' \
    '  フラグは順不同、重複可。issue 番号や他の develop 引数は渡さない。' \
    '  DEV_WORKFLOW_UNATTENDED は Python 3 の .strip() で前後の空白を除く。未設定・空・0 は印なし、それ以外は印あり。' \
    '  優先順: --unmanned > 印 > --channel-request > 既定。' \
    '  正常時は次のいずれかの改行付き 1 行だけを stdout に出し、stderr 空、exit 0:' \
    '実行モード: unmanned（引数）' \
    '実行モード: channel（印）' \
    '実行モード: channel（チャンネルの依頼）' \
    '実行モード: interactive（既定）' \
    '  --help / -h 単独はこの説明を stdout に出し exit 0。' \
    '  引数誤り・Python 3 の実行失敗は stdout 空、理由または使い方を stderr に出し exit 1。'
}

if [ "$#" -eq 1 ]; then
  case "$1" in --help|-h) usage; exit 0 ;; esac
fi
unmanned=0
channel_request=0
for arg in "$@"; do
  case "$arg" in
    --unmanned) unmanned=1 ;;
    --channel-request) channel_request=1 ;;
    *) usage >&2; exit 1 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' 'develop-mode.sh: Python 3 (python3) が実行できません。' >&2
  exit 1
fi
if result=$(python3 - "$unmanned" "$channel_request" <<'PY'
import os
import sys

if sys.argv[1] == "1":
    mode = "unmanned（引数）"
elif os.environ.get("DEV_WORKFLOW_UNATTENDED", "").strip() not in ("", "0"):
    mode = "channel（印）"
elif sys.argv[2] == "1":
    mode = "channel（チャンネルの依頼）"
else:
    mode = "interactive（既定）"
print("実行モード: " + mode)
PY
); then
  case "$result" in
    *'
'*) ;;
    '実行モード: '*) printf '%s\n' "$result"; exit 0 ;;
  esac
fi
printf '%s\n' 'develop-mode.sh: Python 3 (python3) による判定に失敗しました（実行失敗または不正な出力）。' >&2
exit 1
