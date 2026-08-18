#!/usr/bin/env bash
#
# casting-check.sh — 「観点の配役」フレームワークの語彙 lint ＋ 起案シグナル検出
#
# 対象 repo の .claude/casting/{project.md,local.md,precedents.md} に対して4項目を検査する:
#   1. catalog.md に無い観点語彙（「カタログ外」を除く）
#   2. 判例台帳の「カタログ外」判例（観点追加の起案シグナル）
#   3. 同一観点で帰結「論点じゃなかった」が2件以上（移譲仕組み化の起案シグナル）
#   4. 各ファイルの catalog_version が catalog.md の version と不一致
#
# 検出なしなら exit 0、検出ありなら対象一覧を出力して exit 1。
#
# 日本語語彙の照合は LC_ALL=C の grep -F / sed で行う（awk のマルチバイト文字列比較は
# macOS 実装で壊れる実績があるため使わない）。
#
# サブコマンド:
#   （省略時）      対象 repo の配役表・判例台帳を検査する（上記4項目）
#   resolve          catalog.md・project.md・local.md を観点（行）単位で合成した
#                     有効な配役表を、由来（カタログ既定／project／local）付きで出力する
#
# usage: casting-check.sh [resolve] [--catalog <path>] [<target-repo-root>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="${SCRIPT_DIR}/../catalog/catalog.md"
TARGET="."
SUBCOMMAND="check"

if [ $# -gt 0 ] && [ "$1" = "resolve" ]; then
  SUBCOMMAND="resolve"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --catalog)
      CATALOG="$2"
      shift 2
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

if [ ! -f "$CATALOG" ]; then
  echo "casting-check: catalog not found: $CATALOG" >&2
  exit 2
fi

CASTING_DIR="${TARGET%/}/.claude/casting"
PROJECT_MD="${CASTING_DIR}/project.md"
LOCAL_MD="${CASTING_DIR}/local.md"
PRECEDENTS_MD="${CASTING_DIR}/precedents.md"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

FINDINGS="${WORK_DIR}/findings"
: > "$FINDINGS"

report() {
  # report <category> <message>
  printf '[%s] %s\n' "$1" "$2" >> "$FINDINGS"
}

# stripped_copy <file> — HTML コメント（<!-- ... -->）の行を除いた作業コピーのパスを返す。
# テンプレの記入例（コメント内の表行）を実在の行として解釈しないための前処理。
# パースはこのコピーに対して行い、報告のパスは元ファイルを使う
stripped_copy() {
  local file="$1" out
  out="${WORK_DIR}/stripped-$(printf '%s' "$file" | cksum | cut -d' ' -f1)"
  sed '/<!--/,/-->/d' "$file" > "$out"
  printf '%s\n' "$out"
}

# pipe_count <line> — 行に含まれる | の個数（5列表の行なら6以上）
pipe_count() {
  printf '%s' "$1" | tr -cd '|' | wc -c | tr -d ' '
}

# front_matter <file> — front matter 本体（--- と --- の間）を出力する。
# 1行目が --- でない・閉じの --- が無いファイルは front matter 無しとして何も出力しない
front_matter() {
  head -1 "$1" | LC_ALL=C grep -qx -- '---' || return 0
  tail -n +2 "$1" | LC_ALL=C grep -qx -- '---' || return 0
  sed -n '2,/^---$/p' "$1" | sed '$d'
}

# field_value <label> <front-matter-text> — "label: value" 行から value を取り出す。
# 該当行が無ければ空を返す（set -euo pipefail 下で grep の exit 1 が代入ごと
# スクリプトを殺さないよう、grep は必ずガードする）
field_value() {
  local label="$1" text="$2"
  printf '%s\n' "$text" \
    | { LC_ALL=C grep -F -- "${label}:" || true; } \
    | head -1 | sed -E "s/^${label}: *//; s/ *$//"
}

# ---- 1. catalog.md から観点語彙を抽出する（グループA/B/C の5列表の1列目） ----

CATALOG_VOCAB="${WORK_DIR}/catalog-vocab"
: > "$CATALOG_VOCAB"

# 表の行から1列目の値を取り出す共通フィルタ。
# ・パイプ直後の空白は必須にしない（`|観点名|` 形式も有効な Markdown 表）
# ・区切り行（---）とヘッダ行は値のレベルで除外する
# ・対象行ゼロでも pipefail でスクリプトが死なないよう grep はガードする
table_first_column() {
  { grep -E '^\|' || true; } \
    | cut -d'|' -f2 \
    | sed -E 's/^ *//; s/ *$//' \
    | { LC_ALL=C grep -vE '^:?-+:?$' || true; } \
    | { LC_ALL=C grep -vxF -- '観点' || true; } \
    | { LC_ALL=C grep -vxF -- '' || true; }
}

extract_group_vocab() {
  local start_marker="$1" end_marker="$2"
  local start_line end_line
  start_line="$(LC_ALL=C grep -nF -- "$start_marker" "$CATALOG" | head -1 | cut -d: -f1)"
  [ -z "$start_line" ] && return 0
  end_line="$(LC_ALL=C grep -nF -- "$end_marker" "$CATALOG" | head -1 | cut -d: -f1)"
  [ -z "$end_line" ] && end_line="$(wc -l < "$CATALOG" | tr -d ' ')"
  sed -n "${start_line},${end_line}p" "$CATALOG" \
    | table_first_column \
    >> "$CATALOG_VOCAB"
}

extract_group_vocab '## グループA' '## グループB'
extract_group_vocab '## グループB' '## グループC'
extract_group_vocab '## グループC' '## 横断軸'

is_known_vocab() {
  local val="$1"
  [ "$val" = "カタログ外" ] && return 0
  LC_ALL=C grep -F -x -q -- "$val" "$CATALOG_VOCAB"
}

# ---- resolve: catalog.md・project.md・local.md を観点（行）単位で合成する ----
#
# table_first_column と同じ1列目フィルタ規則（パイプ直後スペース非依存・値レベル除外）を
# 適用しつつ、残り4列も一緒に「c1<TAB>c2<TAB>c3<TAB>c4<TAB>c5」で取り出す。

table_rows() {
  local file="$1"
  [ -f "$file" ] || return 0
  local src line c1 c2 c3 c4 c5
  src="$(stripped_copy "$file")"
  while IFS= read -r line; do
    printf '%s\n' "$line" | LC_ALL=C grep -qE '^\|' || continue
    c1="$(printf '%s\n' "$line" | cut -d'|' -f2 | sed -E 's/^ *//; s/ *$//')"
    [ -z "$c1" ] && continue
    LC_ALL=C grep -qxF -- '観点' <<<"$c1" && continue
    printf '%s\n' "$c1" | LC_ALL=C grep -qE '^:?-+:?$' && continue
    # 5列未満（| が6個未満）の壊れた行は有効値として扱わない（検出は check 側が担う）
    [ "$(pipe_count "$line")" -lt 6 ] && continue
    c2="$(printf '%s\n' "$line" | cut -d'|' -f3 | sed -E 's/^ *//; s/ *$//')"
    c3="$(printf '%s\n' "$line" | cut -d'|' -f4 | sed -E 's/^ *//; s/ *$//')"
    c4="$(printf '%s\n' "$line" | cut -d'|' -f5 | sed -E 's/^ *//; s/ *$//')"
    c5="$(printf '%s\n' "$line" | cut -d'|' -f6 | sed -E 's/^ *//; s/ *$//')"
    printf '%s\t%s\t%s\t%s\t%s\n' "$c1" "$c2" "$c3" "$c4" "$c5"
  done < "$src"
}

# extract_group_rows <start-marker> <end-marker> <out-file> — catalog.md の指定グループ範囲の
# 行を table_rows と同じ書式で out-file に追記する（extract_group_vocab と対の実装）
extract_group_rows() {
  local start_marker="$1" end_marker="$2" out_file="$3"
  local start_line end_line slice
  start_line="$(LC_ALL=C grep -nF -- "$start_marker" "$CATALOG" | head -1 | cut -d: -f1)"
  [ -z "$start_line" ] && return 0
  end_line="$(LC_ALL=C grep -nF -- "$end_marker" "$CATALOG" | head -1 | cut -d: -f1)"
  [ -z "$end_line" ] && end_line="$(wc -l < "$CATALOG" | tr -d ' ')"
  slice="${WORK_DIR}/group-slice"
  sed -n "${start_line},${end_line}p" "$CATALOG" > "$slice"
  table_rows "$slice" >> "$out_file"
}

# find_row <rows-file> <perspective> — table_rows 形式のファイルから観点名（1列目）が
# 完全一致する最初の行を返す。無ければ何も出力せず戻り値1（grep は必ずガードする）
find_row() {
  local file="$1" name="$2" lineno
  [ -f "$file" ] || return 1
  lineno="$(cut -f1 "$file" | { LC_ALL=C grep -nxF -- "$name" || true; } | head -1 | cut -d: -f1)"
  [ -z "$lineno" ] && return 1
  sed -n "${lineno}p" "$file"
}

cmd_resolve() {
  local catalog_rows="${WORK_DIR}/catalog-rows"
  : > "$catalog_rows"
  extract_group_rows '## グループA' '## グループB' "$catalog_rows"
  extract_group_rows '## グループB' '## グループC' "$catalog_rows"
  extract_group_rows '## グループC' '## 横断軸' "$catalog_rows"

  local project_rows="${WORK_DIR}/project-rows"
  local local_rows="${WORK_DIR}/local-rows"
  : > "$project_rows"
  : > "$local_rows"
  table_rows "$PROJECT_MD" >> "$project_rows"
  table_rows "$LOCAL_MD" >> "$local_rows"

  printf '| 観点 | この観点が要る論点の条件 | 判断基準の出どころ | 移譲に必要な文書 | 既定の担い手 | 由来 |\n'
  printf '|---|---|---|---|---|---|\n'

  local name c2 c3 c4 c5 row origin n1 n2 n3 n4 n5
  while IFS=$'\t' read -r name c2 c3 c4 c5; do
    [ -z "$name" ] && continue
    if row="$(find_row "$local_rows" "$name")"; then
      origin="local"
    elif row="$(find_row "$project_rows" "$name")"; then
      origin="project"
    else
      row="$(printf '%s\t%s\t%s\t%s\t%s' "$name" "$c2" "$c3" "$c4" "$c5")"
      origin="カタログ既定"
    fi
    IFS=$'\t' read -r n1 n2 n3 n4 n5 <<<"$row"
    printf '| %s | %s | %s | %s | %s | %s |\n' "$n1" "$n2" "$n3" "$n4" "$n5" "$origin"
  done < "$catalog_rows"
}

if [ "$SUBCOMMAND" = "resolve" ]; then
  cmd_resolve
  exit 0
fi

# ---- 対象ファイルから「観点」語彙を集める ----
# project.md / local.md: 5列表の1列目
# precedents.md: "- 観点: <値>" 行

extract_table_vocab() {
  local file="$1"
  [ -f "$file" ] || return 0
  table_first_column < "$(stripped_copy "$file")"
}

extract_precedent_field() {
  # extract_precedent_field <file> <label> — 値の前後空白は除去して返す
  local file="$1" label="$2"
  [ -f "$file" ] || return 0
  { LC_ALL=C grep -F -- "- ${label}:" "$(stripped_copy "$file")" || true; } \
    | sed -E "s/^- ${label}: *//; s/ *$//"
}

# ---- 検出0: 5列未満の壊れた表行（配役表のみ。「行を書くなら5列」の強制） ----

check_malformed_rows() {
  local file="$1"
  [ -f "$file" ] || return 0
  local src line c1
  src="$(stripped_copy "$file")"
  while IFS= read -r line; do
    printf '%s\n' "$line" | LC_ALL=C grep -qE '^\|' || continue
    c1="$(printf '%s\n' "$line" | cut -d'|' -f2 | sed -E 's/^ *//; s/ *$//')"
    [ -z "$c1" ] && continue
    LC_ALL=C grep -qxF -- '観点' <<<"$c1" && continue
    printf '%s\n' "$c1" | LC_ALL=C grep -qE '^:?-+:?$' && continue
    if [ "$(pipe_count "$line")" -lt 6 ]; then
      report "malformed-row" "${file}: 5列未満の行（行を書く場合は5列すべて必要）: ${line}"
    fi
  done < "$src"
}

# 観点フィールドの値を「、」で分割して1行1観点にする（複数観点の判例に対応）
split_perspectives() {
  sed 's/、/\
/g' | sed -E 's/^ *//; s/ *$//'
}

# ---- 検出1: 未知の観点語彙 ----

check_unknown_vocab() {
  local file="$1" label="$2"
  [ -f "$file" ] || return 0
  local val
  while IFS= read -r val; do
    [ -z "$val" ] && continue
    if ! is_known_vocab "$val"; then
      report "unknown-vocab" "${label}: ${val}"
    fi
  done < <(extract_table_vocab "$file")
}

check_malformed_rows "$PROJECT_MD"
check_malformed_rows "$LOCAL_MD"

check_unknown_vocab "$PROJECT_MD" "$PROJECT_MD"
check_unknown_vocab "$LOCAL_MD" "$LOCAL_MD"

if [ -f "$PRECEDENTS_MD" ]; then
  while IFS= read -r val; do
    [ -z "$val" ] && continue
    if ! is_known_vocab "$val"; then
      report "unknown-vocab" "${PRECEDENTS_MD}: ${val}"
    fi
  done < <(extract_precedent_field "$PRECEDENTS_MD" "観点" | split_perspectives)
fi

# ---- 検出2: 「カタログ外」判例 ----

if [ -f "$PRECEDENTS_MD" ]; then
  count="$(extract_precedent_field "$PRECEDENTS_MD" "観点" | split_perspectives | LC_ALL=C grep -Fx -c -- "カタログ外" || true)"
  if [ "${count:-0}" -gt 0 ]; then
    report "catalog-external-precedent" "${PRECEDENTS_MD}: カタログ外判例が ${count} 件（観点追加の起案シグナル）"
  fi
fi

# ---- 検出3: 同一観点で帰結「論点じゃなかった」が2件以上 ----

if [ -f "$PRECEDENTS_MD" ]; then
  PERSPECTIVES="${WORK_DIR}/precedent-perspectives"
  OUTCOMES="${WORK_DIR}/precedent-outcomes"
  extract_precedent_field "$PRECEDENTS_MD" "観点" > "$PERSPECTIVES"
  extract_precedent_field "$PRECEDENTS_MD" "帰結" > "$OUTCOMES"

  NOT_ISSUE_PERSPECTIVES="${WORK_DIR}/not-issue-perspectives"
  : > "$NOT_ISSUE_PERSPECTIVES"

  total="$(wc -l < "$PERSPECTIVES" | tr -d ' ')"
  i=1
  while [ "$i" -le "$total" ]; do
    perspective="$(sed -n "${i}p" "$PERSPECTIVES")"
    outcome="$(sed -n "${i}p" "$OUTCOMES")"
    if [ -n "$perspective" ] && printf '%s' "$outcome" | LC_ALL=C grep -qF -- "論点じゃなかった"; then
      printf '%s\n' "$perspective" >> "$NOT_ISSUE_PERSPECTIVES"
    fi
    i=$((i + 1))
  done

  sort "$NOT_ISSUE_PERSPECTIVES" | uniq -c | while read -r cnt perspective; do
    [ -z "$perspective" ] && continue
    if [ "$cnt" -ge 2 ]; then
      report "repeated-not-issue" "${PRECEDENTS_MD}: ${perspective}（論点じゃなかった ${cnt}件・移譲仕組み化の起案シグナル）"
    fi
  done
fi

# ---- 検出4: catalog_version 不一致 ----

CATALOG_VERSION="$(field_value "version" "$(front_matter "$CATALOG")")"
if [ -z "$CATALOG_VERSION" ]; then
  echo "casting-check: catalog.md の front matter に version が無い: $CATALOG" >&2
  exit 2
fi

check_version() {
  local file="$1"
  [ -f "$file" ] || return 0
  local v
  v="$(field_value "catalog_version" "$(front_matter "$file")")"
  if [ -z "$v" ]; then
    report "version-mismatch" "${file}: catalog_version が front matter に無い"
  elif [ "$v" != "$CATALOG_VERSION" ]; then
    report "version-mismatch" "${file}: catalog_version=${v}（catalog.md は version=${CATALOG_VERSION}）"
  fi
}

check_version "$PROJECT_MD"
check_version "$LOCAL_MD"
check_version "$PRECEDENTS_MD"

# ---- 結果 ----

if [ -s "$FINDINGS" ]; then
  cat "$FINDINGS"
  exit 1
fi

exit 0
