#!/usr/bin/env bash
# fmtoken — プロジェクトスコープのトークン取得ラッパー
#
# エージェントが「このプロジェクトのセッションです」と名乗る代わりに、
# cwd の git root 名からプロジェクトを機械的に導出し、1Password の
# agents 保管庫（read-only Service Account 経由）から正しいトークンだけを返す。
#
# 使い方（トークンを transcript に出さないため、必ずコマンド置換で使う）:
#   GITHUB_TOKEN="$(fmtoken.sh github)" gh api ...
#   SUPABASE_ACCESS_TOKEN="$(fmtoken.sh supabase)" supabase projects list
#
# 存在確認だけしたい時:
#   fmtoken.sh --check <service>   # 値を出力せず 0/44 で返す
#   fmtoken.sh --list              # このプロジェクトに登録済みのサービス一覧
#
# 登録は人間（主）が 1Password アプリで行う:
#   保管庫: agents / アイテム名: <project>--<service> / フィールド: credential
set -euo pipefail

VAULT="agents"
KEYCHAIN_SERVICE="op-sa-claude-agents-ro"

mode="read"
if [[ "${1:-}" == "--check" ]]; then mode="check"; shift; fi
if [[ "${1:-}" == "--list" ]]; then mode="list"; fi

# プロジェクト名: git root のディレクトリ名を正規化（小文字化・先頭 _ とバージョン接尾辞を除去）
# 例: Buffon_ver.0.4.0 → buffon / Shukan_ver.1.0 → shukan / flatmate → flatmate
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
normalize() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/^_+//; s/_?ver[._]?[0-9][0-9.]*$//'; }
project="$(normalize "$(basename "$root")")"
# ディレクトリ名全体がバージョン（例: ver0.0.1）だった場合は親ディレクトリ名を使う
[[ -z "$project" ]] && project="$(normalize "$(basename "$(dirname "$root")")")"

# SA トークンの取得順: env → 600権限ファイル → Keychain
# 無人経路（cron・常駐・SSH）を優先する順序。Keychain は ACL 次第で読み出しごとに
# 生体認証ダイアログを出し、無人文脈ではそこでブロックする（GUI が無ければ即失敗）ため、
# 対話マシン用の最終フォールバックに置く。ファイル未配布のマシンだけが Keychain に落ちる。
TOKEN_FILE="$HOME/.config/op-sa/claude-agents-ro.token"
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  if [[ -r "$TOKEN_FILE" ]]; then
    OP_SERVICE_ACCOUNT_TOKEN="$(tr -d '\n' < "$TOKEN_FILE")"
  elif OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)"; then
    :
  else
    echo "fmtoken: SA トークンが見つかりません（ファイル: ${TOKEN_FILE} / Keychain: ${KEYCHAIN_SERVICE}）。このマシンは未セットアップです。" >&2
    echo "→ 主に『SA トークンをこのマシンに配布して』と依頼すること（ブラウザでのログイン代行は不要）" >&2
    exit 43
  fi
  export OP_SERVICE_ACCOUNT_TOKEN
fi

if [[ "$mode" == "list" ]]; then
  op item list --vault "$VAULT" --format json |
    /usr/bin/python3 -c "import json,sys; [print(t.split('--',1)[1]) for i in json.load(sys.stdin) if (t:=i['title']).startswith('${project}--')]"
  exit 0
fi

service="${1:?usage: fmtoken.sh [--check] <service> | fmtoken.sh --list}"
ref="op://${VAULT}/${project}--${service}/credential"

if [[ "$mode" == "check" ]]; then
  if op read "$ref" >/dev/null 2>&1; then
    echo "OK: ${project}--${service} は登録済み"
    exit 0
  fi
else
  if op read "$ref" 2>/dev/null; then
    exit 0
  fi
fi

echo "fmtoken: 未登録 → ${ref}" >&2
echo "→ ブラウザに行かず、主に『1Password の ${VAULT} 保管庫に ${project}--${service}（フィールド: credential）を登録して』と依頼すること" >&2
exit 44
