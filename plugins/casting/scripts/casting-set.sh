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
# HTML コメント内の記入例を実在の行と誤認しないよう、先にコメント行を除いて読む
perspective_in_file() {
  local file="$1" name="$2"
  [ -f "$file" ] || return 1
  sed '/<!--/,/-->/d' "$file" \
    | { grep -E '^\|' || true; } \
    | cut -d'|' -f2 \
    | sed -E 's/^ *//; s/ *$//' \
    | { LC_ALL=C grep -vE '^:?-+:?$' || true; } \
    | { LC_ALL=C grep -vxF -- '観点' || true; } \
    | { LC_ALL=C grep -vxF -- '' || true; } \
    | LC_ALL=C grep -qxF -- "$name"
}

# assert_cell_safe <ラベル> <値> — Markdown 表のセルに埋め込む値の検証。
# | と改行は列構造を壊すため拒否する
assert_cell_safe() {
  local label="$1" value="$2"
  case "$value" in
    *'|'*)
      echo "casting-set: ${label}に | は使えません（表の列構造が壊れるため）: ${value}" >&2
      exit 1
      ;;
  esac
  if [ "$(printf '%s' "$value" | wc -l | tr -d ' ')" -gt 0 ]; then
    echo "casting-set: ${label}に改行は使えません" >&2
    exit 1
  fi
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
  # 呼び出し側が変更記録を書き足してから mv する（カタログ確定と記録追記を1回の mv に
  # まとめて原子的にするため、ここでは確定しない）
  [ "$found" -eq 1 ] || return 1
  printf '%s\n' "$tmp" > "${WORK_DIR}/rewrite-path"
  return 0
}

# report_registry_impact <観点名> — 台帳の各 repo について、この観点を project.md / local.md で
# 上書きしているか（上書き中・影響なし）／していないか（継承中・影響あり）を出力する。
# 存在しないパスは警告つきでスキップする
report_registry_impact() {
  local name="$1" repo
  if [ ! -f "$REGISTRY" ]; then
    echo "（registry が見つかりません: ${REGISTRY}）"
    return 0
  fi
  # `|| [ -n "$repo" ]` は末尾改行の無い最終行を読み飛ばさないため
  while IFS= read -r repo || [ -n "$repo" ]; do
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

# report_registry_impact_all — replace-catalog 用。各 repo の上書き行数を数え、
# 「どの repo にどれだけ独自配役が残っているか」を出力する
report_registry_impact_all() {
  local repo n f
  if [ ! -f "$REGISTRY" ]; then
    echo "（registry が見つかりません: ${REGISTRY}）"
    return 0
  fi
  while IFS= read -r repo || [ -n "$repo" ]; do
    [ -z "$repo" ] && continue
    if [ ! -d "$repo" ]; then
      echo "警告: registry のパスが存在しません（スキップ）: $repo"
      continue
    fi
    n=0
    for f in "${repo%/}/.claude/casting/project.md" "${repo%/}/.claude/casting/local.md"; do
      [ -f "$f" ] || continue
      n=$((n + $(sed '/<!--/,/-->/d' "$f" \
        | { grep -E '^\|' || true; } \
        | cut -d'|' -f2 \
        | sed -E 's/^ *//; s/ *$//' \
        | { LC_ALL=C grep -vE '^:?-+:?$' || true; } \
        | { LC_ALL=C grep -vxF -- '観点' || true; } \
        | { LC_ALL=C grep -vxF -- '' || true; } \
        | wc -l | tr -d ' ')))
    done
    if [ "$n" -gt 0 ]; then
      echo "${repo}: ${n}観点を上書き中（それ以外は新カタログを継承・影響あり）"
    else
      echo "${repo}: 全観点継承中（影響あり）"
    fi
  done < "$REGISTRY"
}

# validate_catalog_structure <file> — replace-catalog の差し替えファイルがカタログとして
# 最低限の構造（3グループ見出し・変更記録節・グループA に1行以上の観点行）を持つか
validate_catalog_structure() {
  local file="$1" section
  for section in '## グループA' '## グループB' '## グループC' '## 変更記録'; do
    if ! LC_ALL=C grep -qF -- "$section" "$file"; then
      echo "casting-set: 差し替えファイルに必須節がありません: ${section}" >&2
      return 1
    fi
  done
  section="$(sed '/<!--/,/-->/d' "$file" | sed -n '/## グループA/,/## グループB/p' \
    | { grep -E '^\|' || true; } \
    | cut -d'|' -f2 \
    | sed -E 's/^ *//; s/ *$//' \
    | { LC_ALL=C grep -vE '^:?-+:?$' || true; } \
    | { LC_ALL=C grep -vxF -- '観点' || true; } \
    | { LC_ALL=C grep -vxF -- '' || true; } \
    | wc -l | tr -d ' ')"
  if [ "$section" -eq 0 ]; then
    echo "casting-set: 差し替えファイルのグループA に観点の行がありません" >&2
    return 1
  fi
  return 0
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

  assert_cell_safe "新しい既定の担い手" "$new_owner"
  assert_cell_safe "--why の理由" "$why"

  if ! rewrite_owner_row "$CATALOG" "$name" "$new_owner"; then
    echo "casting-set: 観点が見つかりません: $name" >&2
    exit 1
  fi
  local old_owner tmp_new
  old_owner="$(cat "${WORK_DIR}/old-owner")"
  tmp_new="$(cat "${WORK_DIR}/rewrite-path")"

  # 行の書き換えと変更記録の追記を作業コピー上で済ませてから1回の mv で確定する
  # （途中失敗で「値だけ変わって記録が無い」状態を残さない）
  local today
  today="$(date +%F)"
  append_changelog "$tmp_new" "| ${today} | 観点「${name}」の既定の担い手を「${old_owner}」→「${new_owner}」に変更 | ${why} | — |"
  mv "$tmp_new" "$CATALOG"

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
  assert_cell_safe "--why の理由" "$why"
  if ! validate_catalog_structure "$new_file"; then
    exit 1
  fi

  # 差し替えと変更記録の追記を作業コピー上で済ませてから1回の mv で確定する
  local tmp_new="${WORK_DIR}/catalog-replace"
  cp "$new_file" "$tmp_new"
  local today
  today="$(date +%F)"
  append_changelog "$tmp_new" "| ${today} | replace-catalog によりカタログを version ${new_version} に差し替え | ${why} | — |"
  mv "$tmp_new" "$CATALOG"

  echo "casting-set: カタログを version ${new_version} に差し替えました"
  echo ""
  echo "影響一覧:"
  report_registry_impact_all
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
