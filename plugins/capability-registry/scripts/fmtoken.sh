#!/usr/bin/env bash
# fmtoken — 1Password agents 保管庫のトークン取得・登録ラッパー
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
# 明示名での参照（エージェント名接頭辞 <agent>--<SERVICE> はプロジェクト導出で
# 引けないため、アイテム名をそのまま渡す。プロジェクト名接頭辞のアイテムにも使える）:
#   TRELLO_TOKEN="$(fmtoken.sh --name moko--TRELLO_TOKEN)"
#   fmtoken.sh --check --name moko--TRELLO_TOKEN
#
# 登録（正規手順は CLI 代行。read = claude-agents-ro / register = claude-agents-rw の
# 役割分担。値は argv でなく stdin で渡す — transcript / ps への露出を避けるため）:
#   printf '%s' "$VALUE" | fmtoken.sh --register <project|agent>--<service>
#
# exit code: 0 成功 / 43 SA トークン未配布 / 44 未登録 / 45 プロジェクト導出不能 /
#            46 命名規約違反・入力不正 / 47 登録済みアイテムへの二重登録 /
#            48 二重登録判定の不能（読み取り用 SA が解決できない・op item list 失敗 — fail-closed）
set -euo pipefail

OP_VAULT="agents"
KEYCHAIN_SERVICE_RO="op-sa-claude-agents-ro"
KEYCHAIN_SERVICE_RW="op-sa-claude-agents-rw"
USAGE="usage: fmtoken.sh [--check] <service> | fmtoken.sh --list | fmtoken.sh [--check] --name <item> | fmtoken.sh --register <item> (value via stdin)"

mode="read"
if [[ "${1:-}" == "--check" ]]; then mode="check"; shift; fi
if [[ "${1:-}" == "--list" ]]; then mode="list"; fi
if [[ "${1:-}" == "--register" ]]; then mode="register"; shift; fi

explicit_name=""
if [[ "${1:-}" == "--name" ]]; then
  explicit_name="${2:?${USAGE}}"
elif [[ "$mode" == "register" ]]; then
  explicit_name="${1:?${USAGE}}"
fi

# 命名規約の機械検証: <prefix>--<service>。prefix はプロジェクト名（プロダクトの秘密）
# またはエージェント名（身元）で小文字、区切りの -- はちょうど 1 回。
# 人間の手作業登録が規約逸脱の源になるため、CLI 登録側で機械的に弾く（issue #63）。
validate_item_name() {
  local name="$1" prefix suffix
  prefix="${name%%--*}"
  suffix="${name#*--}"
  if [[ "$name" != *--* || "$suffix" == *--* ]] ||
     ! [[ "$prefix" =~ ^[a-z0-9][a-z0-9._-]*$ ]] ||
     ! [[ "$suffix" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "fmtoken: アイテム名が命名規約に反しています: ${name}" >&2
    echo "→ 規約は <project>--<service>（プロダクトの秘密。例: shukan--SUPABASE_ACCESS_TOKEN）または <agent>--<SERVICE>（エージェントの身元。例: moko--TRELLO_TOKEN）。prefix は小文字英数、区切りは -- を 1 回だけ" >&2
    exit 46
  fi
}

# 読み取り用 SA トークンの取得順: env → 600権限ファイル → Keychain
# 無人経路（cron・常駐・SSH）を優先する順序。Keychain は ACL 次第で読み出しごとに
# 生体認証ダイアログを出し、無人文脈ではそこでブロックする（GUI が無ければ即失敗）ため、
# 対話マシン用の最終フォールバックに置く。ファイル未配布のマシンだけが Keychain に落ちる。
# `--optional` 付きの呼び出しは、解決できない時に exit せず非 0 を返す
# （呼び出し側が fail-closed の文脈に合ったエラーを出すため。--register の二重登録ガードが使う）。
resolve_ro_token() {
  local optional=""
  if [[ "${1:-}" == "--optional" ]]; then optional=1; fi
  local token_file="$HOME/.config/op-sa/claude-agents-ro.token"
  if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    if [[ -r "$token_file" ]]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(tr -d '\n' < "$token_file")"
    elif OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_RO" -w 2>/dev/null)"; then
      :
    else
      if [[ -n "$optional" ]]; then return 1; fi
      echo "fmtoken: SA トークンが見つかりません（ファイル: ${token_file} / Keychain: ${KEYCHAIN_SERVICE_RO}）。このマシンは未セットアップです。" >&2
      echo "→ 主に『SA トークンをこのマシンに配布して』と依頼すること（ブラウザでのログイン代行は不要）" >&2
      exit 43
    fi
    export OP_SERVICE_ACCOUNT_TOKEN
  fi
  return 0
}

# 書き込み用 SA トークン（claude-agents-rw）の取得順: env → 600権限ファイル → Keychain。
# 環境の OP_SERVICE_ACCOUNT_TOKEN は多くのマシンで ro トークンなので、登録では参照しない
# （ro のまま op item create すると権限エラーになるだけで、どのトークンで失敗したか
# 分からない。rw を明示的に解決してから OP_SERVICE_ACCOUNT_TOKEN を差し替える）。
resolve_rw_token() {
  local rw_file="$HOME/.config/op-sa/claude-agents-rw.token" rw=""
  if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN_RW:-}" ]]; then
    rw="$OP_SERVICE_ACCOUNT_TOKEN_RW"
  elif [[ -r "$rw_file" ]]; then
    rw="$(tr -d '\n' < "$rw_file")"
  elif rw="$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE_RW" -w 2>/dev/null)"; then
    :
  else
    echo "fmtoken: 書き込み用 SA トークン（claude-agents-rw）が見つかりません（env: OP_SERVICE_ACCOUNT_TOKEN_RW / ファイル: ${rw_file} / Keychain: ${KEYCHAIN_SERVICE_RW}）。" >&2
    echo "→ 主に『rw SA トークンをこのマシンに配布して』と依頼すること（読み取り用の ro トークンでは登録できない）" >&2
    exit 43
  fi
  export OP_SERVICE_ACCOUNT_TOKEN="$rw"
}

# --register: 明示名アイテムを agents 保管庫に作成する（rw SA 経由）
if [[ "$mode" == "register" ]]; then
  validate_item_name "$explicit_name"
  if [[ -t 0 ]]; then
    echo "fmtoken: 登録する値を stdin から渡してください（例: printf '%s' \"\$VALUE\" | fmtoken.sh --register ${explicit_name}）。値を引数で渡さないのは transcript / ps への露出を避けるため" >&2
    exit 46
  fi
  value="$(cat)"
  if [[ -z "$value" ]]; then
    echo "fmtoken: stdin が空です。登録する値を stdin から渡してください" >&2
    exit 46
  fi
  # 判定不能（exit 48）で共通して出す案内。1Password 側の権限変更は人間の GUI 作業なので、
  # スクリプトは選択肢の提示までで止まる。
  GUARD_HINT="→ ro SA トークンをこのマシンに配布する（env OP_SERVICE_ACCOUNT_TOKEN / ~/.config/op-sa/claude-agents-ro.token / Keychain ${KEYCHAIN_SERVICE_RO}）か、rw SA に agents 保管庫の read 権を付けて OP_SERVICE_ACCOUNT_TOKEN に設定すること（1Password 側の権限変更は人間の GUI 作業）"
  # 二重登録ガード（issue #131）: 判定は読み取り用 SA（claude-agents-ro）で行い、
  # rw SA の read 権には依存しない。rw で `op read` して判定すると、rw に read 権が無い構成で
  # 判定が常に「未登録」側に倒れ（fail-open）、1Password は同名アイテムの作成を許すため
  # 重複アイテムができる。ro SA はこのスクリプトの読み取り経路全体が依存している＝定義上
  # read 可能なので、存在判定はそちらに寄せる。判定は title 完全一致（op item list）で行い、
  # credential フィールドの有無に依存しない（フィールド欠落アイテムを「未登録」と誤判定して
  # 同名重複を作らないため）。判定できない時は create せず止まる（fail-closed / exit 48）。
  if ! resolve_ro_token --optional; then
    echo "fmtoken: 二重登録の判定に使える読み取り用 SA トークン（claude-agents-ro）が解決できません。判定できないまま登録すると同名アイテムの重複を作りうるため、登録を中止します（fail-closed）" >&2
    echo "${GUARD_HINT}" >&2
    exit 48
  fi
  if ! existing_items="$(op item list --vault "$OP_VAULT" --format json 2>/dev/null)"; then
    echo "fmtoken: 二重登録の判定（op item list --vault ${OP_VAULT}）に失敗しました。判定できないまま登録すると同名アイテムの重複を作りうるため、登録を中止します（fail-closed）" >&2
    echo "${GUARD_HINT}" >&2
    exit 48
  fi
  # 一致（0）/ 不一致（1）/ 解析不能（2）を区別する。JSON が壊れている・想定の形でない場合を
  # 「不一致」に混ぜると、判定できていないのに create に進んでしまう（fail-open）。
  guard_rc=0
  printf '%s' "$existing_items" |
    /usr/bin/python3 -c 'import json,sys
try:
    items = json.load(sys.stdin)
    titles = [i["title"] for i in items]
except Exception:
    sys.exit(2)
sys.exit(0 if sys.argv[1] in titles else 1)' "$explicit_name" || guard_rc=$?
  if [[ "$guard_rc" -eq 0 ]]; then
    echo "fmtoken: ${explicit_name} は既に登録済みです → 上書きしない（更新が必要なら主の判断を経て op item edit を使う。無断上書き防止）" >&2
    exit 47
  fi
  if [[ "$guard_rc" -ne 1 ]]; then
    echo "fmtoken: 二重登録の判定に使う ${OP_VAULT} 保管庫のアイテム一覧を解析できませんでした（op item list --format json の出力が想定の形ではありません）。判定できないまま登録すると同名アイテムの重複を作りうるため、登録を中止します（fail-closed）" >&2
    echo "${GUARD_HINT}" >&2
    exit 48
  fi
  resolve_rw_token
  op item create --vault "$OP_VAULT" --category "API Credential" --title "$explicit_name" "credential[password]=${value}" >/dev/null
  echo "OK: ${explicit_name} を ${OP_VAULT} 保管庫に登録した（フィールド: credential）"
  exit 0
fi

# --name: 明示名アイテムの参照（プロジェクト導出をスキップ。origin remote 不要）
if [[ -n "$explicit_name" ]]; then
  validate_item_name "$explicit_name"
  resolve_ro_token
  ref="op://${OP_VAULT}/${explicit_name}/credential"
  if [[ "$mode" == "check" ]]; then
    if op read "$ref" >/dev/null 2>&1; then
      echo "OK: ${explicit_name} は登録済み"
      exit 0
    fi
  else
    if op read "$ref" 2>/dev/null; then
      exit 0
    fi
  fi
  echo "fmtoken: 未登録 → ${ref}" >&2
  echo "→ 値が手元にあるなら printf '%s' \"\$VALUE\" | fmtoken.sh --register ${explicit_name} で登録できる（rw SA 経由）。値が無ければ主に発行と登録を依頼する" >&2
  exit 44
fi

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

resolve_ro_token

if [[ "$mode" == "list" ]]; then
  op item list --vault "$OP_VAULT" --format json |
    /usr/bin/python3 -c "import json,sys; [print(t.split('--',1)[1]) for i in json.load(sys.stdin) if (t:=i['title']).startswith('${project}--')]"
  exit 0
fi

service="${1:?${USAGE}}"
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
echo "→ ブラウザに行かず、値が手元にあるなら printf '%s' \"\$VALUE\" | fmtoken.sh --register ${project}--${service} で登録する（rw SA 経由）。値が無ければ主に『1Password の ${OP_VAULT} 保管庫に ${project}--${service}（フィールド: credential）を登録して』と依頼すること" >&2
exit 44
