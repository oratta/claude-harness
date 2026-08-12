#!/usr/bin/env bash
# fmtoken — プロジェクトスコープのトークン取得ラッパー
#
# エージェントが「このプロジェクトのセッションです」と名乗る代わりに、
# origin remote のリポ名からプロジェクトを機械的に導出し、1Password の
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

OP_VAULT="agents"
KEYCHAIN_SERVICE="op-sa-claude-agents-ro"

mode="read"
if [[ "${1:-}" == "--check" ]]; then mode="check"; shift; fi
if [[ "${1:-}" == "--list" ]]; then mode="list"; fi

# プロジェクト名: origin remote のリポ名（末尾 .git 除去 → 最終パス要素 → 小文字化）。
# 例: https://github.com/genetta-inc/suimei.git / git@github.com:genetta-inc/suimei.git → suimei
# dir 名導出は flatmate 住人の workspace/<住人>/repo 構造（basename が一律 repo）で破綻し、
# 登録済みトークンに登録依頼を飛ばす誤誘導を生んだため廃止（oratta/claude-harness#56）。
# メイン repo・worktree・住人 dir のどこで実行しても同じ名前に解決される。
if ! remote_url="$(git remote get-url origin 2>/dev/null)"; then
  echo "fmtoken: origin remote が無いためプロジェクトを特定できません（git リポジトリ外か remote 未設定）。" >&2
  echo "→ プロジェクトの正式リポジトリ（origin 設定済み）の中で実行すること。主への依頼は不要（トークンが無いのではなく実行場所の問題）" >&2
  exit 45
fi
remote_url="${remote_url%/}"
remote_url="${remote_url%.git}"
project="${remote_url##*/}"
project="${project##*:}"  # scp 形式で org が無い場合（git@host:name）の保険
project="$(printf '%s' "$project" | tr '[:upper:]' '[:lower:]')"
if [[ -z "$project" ]]; then
  echo "fmtoken: origin remote の URL からプロジェクト名を導出できません: $(git remote get-url origin)" >&2
  exit 45
fi

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
  op item list --vault "$OP_VAULT" --format json |
    /usr/bin/python3 -c "import json,sys; [print(t.split('--',1)[1]) for i in json.load(sys.stdin) if (t:=i['title']).startswith('${project}--')]"
  exit 0
fi

service="${1:?usage: fmtoken.sh [--check] <service> | fmtoken.sh --list}"
ref="op://${OP_VAULT}/${project}--${service}/credential"

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
echo "→ ブラウザに行かず、主に『1Password の ${OP_VAULT} 保管庫に ${project}--${service}（フィールド: credential）を登録して』と依頼すること" >&2
exit 44
