#!/usr/bin/env bash
#
# casting-set.sh — カタログ（catalog/catalog.md）書き込みの唯一の入口
#
# サブコマンド:
#   owner <観点名> <新しい既定の担い手> --why <理由>
#     カタログの当該観点の「既定の担い手」列だけを書き換え、変更記録節に追記する（軽量ルート）
#   replace-catalog <file> --why <理由>
#     カタログを丸ごと差し替える。差し替えファイルの front matter version が現行より
#     大きくなければ拒否する（重量ルート）
#
# どちらの書き込みも成功後、導入 repo 台帳（既定 ~/.claude/casting/registry.txt。
# 環境変数 CASTING_REGISTRY で差し替え可能）を走査し、影響一覧を出力する。
#
# 日本語語彙の照合は LC_ALL=C の grep -F で行う（awk のマルチバイト文字列比較は
# macOS 実装で壊れる実績があるため使わない）。
#
# usage:
#   casting-set.sh [--catalog <path>] owner <観点名> <新しい既定の担い手> --why <理由>
#   casting-set.sh [--catalog <path>] replace-catalog <file> --why <理由>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="${SCRIPT_DIR}/../catalog/catalog.md"
REGISTRY="${CASTING_REGISTRY:-${HOME}/.claude/casting/registry.txt}"

usage() {
  cat >&2 <<'EOF'
usage:
  casting-set.sh [--catalog <path>] owner <観点名> <新しい既定の担い手> --why <理由>
  casting-set.sh [--catalog <path>] replace-catalog <file> --why <理由>
EOF
}

ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --catalog)
      CATALOG="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

SUBCOMMAND="$1"
shift

if [ ! -f "$CATALOG" ]; then
  echo "casting-set: catalog not found: $CATALOG" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# front_matter <file> — front matter 本体（--- と --- の間）を出力する。
# 1行目が --- でない・閉じの --- が無いファイルは front matter 無しとして何も出力しない
# （casting-check.sh と同一実装。共有ライブラリを持たないため個別に保つ）
front_matter() {
  head -1 "$1" | LC_ALL=C grep -qx -- '---' || return 0
  tail -n +2 "$1" | LC_ALL=C grep -qx -- '---' || return 0
  sed -n '2,/^---$/p' "$1" | sed '$d'
}

# field_value <label> <front-matter-text> — "label: value" 行から value を取り出す
field_value() {
  local label="$1" text="$2"
  printf '%s\n' "$text" \
    | { LC_ALL=C grep -F -- "${label}:" || true; } \
    | head -1 | sed -E "s/^${label}: *//; s/ *$//"
}

# perspective_in_file <file> <観点名> — 5列表の1列目にその観点名の行があるか
# （table_first_column と同じフィルタ規則。casting-check.sh の実装と揃える）
perspective_in_file() {
  local file="$1" name="$2"
  [ -f "$file" ] || return 1
  { grep -E '^\|' "$file" || true; } \
    | cut -d'|' -f2 \
    | sed -E 's/^ *//; s/ *$//' \
    | { LC_ALL=C grep -vE '^:?-+:?$' || true; } \
    | { LC_ALL=C grep -vxF -- '観点' || true; } \
    | { LC_ALL=C grep -vxF -- '' || true; } \
    | LC_ALL=C grep -qxF -- "$name"
}

# append_changelog <file> <line> — "## 変更記録" 節の末尾（次の "## " 見出しの直前、
# 無ければファイル末尾）に1行追記する
append_changelog() {
  local file="$1" line="$2"
  local heading_line next_offset insert_at tmp
  heading_line="$(LC_ALL=C grep -nF -- '## 変更記録' "$file" | head -1 | cut -d: -f1)"
  if [ -z "$heading_line" ]; then
    printf '\n## 変更記録\n\n%s\n' "$line" >> "$file"
    return 0
  fi
  next_offset="$(tail -n +"$((heading_line + 1))" "$file" | { LC_ALL=C grep -nE '^## ' || true; } | head -1 | cut -d: -f1)"
  if [ -z "$next_offset" ]; then
    printf '%s\n' "$line" >> "$file"
    return 0
  fi
  insert_at=$((heading_line + next_offset))
  tmp="${WORK_DIR}/changelog-insert"
  {
    sed -n "1,$((insert_at - 1))p" "$file"
    printf '%s\n' "$line"
    sed -n "${insert_at},\$p" "$file"
  } > "$tmp"
  mv "$tmp" "$file"
}

# rewrite_owner_row <file> <観点名> <新しい既定の担い手> — 観点名が一致する行の5列目だけを
# 書き換える。見つからなければ何も変更せず戻り値1。旧値は WORK_DIR/old-owner に書き出す
rewrite_owner_row() {
  local file="$1" name="$2" new_owner="$3"
  local tmp="${WORK_DIR}/catalog-rewrite"
  local found=0
  local line c1 c2 c3 c4 c5
  : > "$tmp"
  while IFS= read -r line; do
    if printf '%s\n' "$line" | LC_ALL=C grep -qE '^\|'; then
      c1="$(printf '%s\n' "$line" | cut -d'|' -f2 | sed -E 's/^ *//; s/ *$//')"
      if [ -n "$c1" ] \
        && { ! LC_ALL=C grep -qxF -- '観点' <<<"$c1"; } \
        && { ! printf '%s\n' "$c1" | LC_ALL=C grep -qE '^:?-+:?$'; } \
        && LC_ALL=C grep -qxF -- "$name" <<<"$c1"; then
        c2="$(printf '%s\n' "$line" | cut -d'|' -f3 | sed -E 's/^ *//; s/ *$//')"
        c3="$(printf '%s\n' "$line" | cut -d'|' -f4 | sed -E 's/^ *//; s/ *$//')"
        c4="$(printf '%s\n' "$line" | cut -d'|' -f5 | sed -E 's/^ *//; s/ *$//')"
        c5="$(printf '%s\n' "$line" | cut -d'|' -f6 | sed -E 's/^ *//; s/ *$//')"
        printf '%s\n' "$c5" > "${WORK_DIR}/old-owner"
        printf '| %s | %s | %s | %s | %s |\n' "$c1" "$c2" "$c3" "$c4" "$new_owner" >> "$tmp"
        found=1
        continue
      fi
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  [ "$found" -eq 1 ] || return 1
  mv "$tmp" "$file"
  return 0
}

# report_registry_impact <観点名> — 台帳の各 repo について、この観点を project.md / local.md で
# 上書きしているか（上書き中・影響なし）／していないか（継承中・影響あり）を出力する。
# 存在しないパスは警告つきでスキップする
report_registry_impact() {
  local name="$1" repo
  if [ ! -f "$REGISTRY" ]; then
    echo "（registry が見つかりません: $REGISTRY）"
    return 0
  fi
  while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    if [ ! -d "$repo" ]; then
      echo "警告: registry のパスが存在しません（スキップ）: $repo"
      continue
    fi
    if perspective_in_file "${repo%/}/.claude/casting/project.md" "$name" \
      || perspective_in_file "${repo%/}/.claude/casting/local.md" "$name"; then
      echo "${repo}: 上書き中（影響なし）"
    else
      echo "${repo}: 継承中（影響あり）"
    fi
  done < "$REGISTRY"
}

cmd_owner() {
  if [ $# -lt 1 ]; then
    echo "casting-set: owner requires <観点名>" >&2
    exit 1
  fi
  local name="$1"
  shift
  if [ $# -lt 1 ]; then
    echo "casting-set: owner requires <新しい既定の担い手>" >&2
    exit 1
  fi
  local new_owner="$1"
  shift

  local why=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --why)
        why="${2:-}"
        shift 2
        ;;
      *)
        echo "casting-set: unknown argument: $1" >&2
        exit 1
        ;;
    esac
  done
  if [ -z "$why" ]; then
    echo "casting-set: --why は必須です" >&2
    exit 1
  fi

  if ! rewrite_owner_row "$CATALOG" "$name" "$new_owner"; then
    echo "casting-set: 観点が見つかりません: $name" >&2
    exit 1
  fi
  local old_owner
  old_owner="$(cat "${WORK_DIR}/old-owner")"

  local today
  today="$(date +%F)"
  append_changelog "$CATALOG" "| ${today} | 観点「${name}」の既定の担い手を「${old_owner}」→「${new_owner}」に変更 | ${why} | — |"

  echo "casting-set: 観点「${name}」の既定の担い手を更新しました（${old_owner} → ${new_owner}）"
  echo ""
  echo "影響一覧:"
  report_registry_impact "$name"
}

cmd_replace_catalog() {
  if [ $# -lt 1 ]; then
    echo "casting-set: replace-catalog requires <file>" >&2
    exit 1
  fi
  local new_file="$1"
  shift

  local why=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --why)
        why="${2:-}"
        shift 2
        ;;
      *)
        echo "casting-set: unknown argument: $1" >&2
        exit 1
        ;;
    esac
  done
  if [ -z "$why" ]; then
    echo "casting-set: --why は必須です" >&2
    exit 1
  fi
  if [ ! -f "$new_file" ]; then
    echo "casting-set: file not found: $new_file" >&2
    exit 1
  fi

  local new_version cur_version
  new_version="$(field_value "version" "$(front_matter "$new_file")")"
  cur_version="$(field_value "version" "$(front_matter "$CATALOG")")"

  if [ -z "$new_version" ]; then
    echo "casting-set: 差し替えファイルの front matter に version が無い: $new_file" >&2
    exit 1
  fi
  if [ -z "$cur_version" ] || [ "$new_version" -le "$cur_version" ]; then
    echo "casting-set: version を増やす必要があります（現行 version=${cur_version:-不明}、差し替え version=${new_version}）" >&2
    exit 1
  fi

  cp "$new_file" "$CATALOG"

  local today
  today="$(date +%F)"
  append_changelog "$CATALOG" "| ${today} | replace-catalog によりカタログを version ${new_version} に差し替え | ${why} | — |"

  echo "casting-set: カタログを version ${new_version} に差し替えました"
}

case "$SUBCOMMAND" in
  owner)
    cmd_owner "$@"
    ;;
  replace-catalog)
    cmd_replace_catalog "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
