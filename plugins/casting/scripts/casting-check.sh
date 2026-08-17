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
# usage: casting-check.sh [--catalog <path>] [<target-repo-root>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="${SCRIPT_DIR}/../catalog/catalog.md"
TARGET="."

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

# front_matter <file> — front matter 本体（--- と --- の間）を出力する
front_matter() {
  sed -n '2,/^---$/p' "$1" | sed '$d'
}

# field_value <label> <front-matter-text> — "label: value" 行から value を取り出す
field_value() {
  local label="$1" text="$2"
  printf '%s\n' "$text" | LC_ALL=C grep -F -- "${label}:" | head -1 | sed -E "s/^${label}: *//"
}

# ---- 1. catalog.md から観点語彙を抽出する（グループA/B/C の5列表の1列目） ----

CATALOG_VOCAB="${WORK_DIR}/catalog-vocab"
: > "$CATALOG_VOCAB"

extract_group_vocab() {
  local start_marker="$1" end_marker="$2"
  local start_line end_line
  start_line="$(LC_ALL=C grep -nF -- "$start_marker" "$CATALOG" | head -1 | cut -d: -f1)"
  [ -z "$start_line" ] && return 0
  end_line="$(LC_ALL=C grep -nF -- "$end_marker" "$CATALOG" | head -1 | cut -d: -f1)"
  [ -z "$end_line" ] && end_line="$(wc -l < "$CATALOG" | tr -d ' ')"
  sed -n "${start_line},${end_line}p" "$CATALOG" \
    | grep -E '^\| ' \
    | LC_ALL=C grep -vF -- '|---' \
    | LC_ALL=C grep -vF -- '| 観点 | この観点が要る論点の条件 |' \
    | cut -d'|' -f2 \
    | sed -E 's/^ *//; s/ *$//' \
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

# ---- 対象ファイルから「観点」語彙を集める ----
# project.md / local.md: 5列表の1列目
# precedents.md: "- 観点: <値>" 行

extract_table_vocab() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -E '^\| ' "$file" \
    | LC_ALL=C grep -vF -- '|---' \
    | LC_ALL=C grep -vF -- '| 観点 | この観点が要る論点の条件 |' \
    | cut -d'|' -f2 \
    | sed -E 's/^ *//; s/ *$//'
}

extract_precedent_field() {
  # extract_precedent_field <file> <label>
  local file="$1" label="$2"
  [ -f "$file" ] || return 0
  LC_ALL=C grep -F -- "- ${label}:" "$file" | sed -E "s/^- ${label}: *//"
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

check_unknown_vocab "$PROJECT_MD" "$PROJECT_MD"
check_unknown_vocab "$LOCAL_MD" "$LOCAL_MD"

if [ -f "$PRECEDENTS_MD" ]; then
  while IFS= read -r val; do
    [ -z "$val" ] && continue
    if ! is_known_vocab "$val"; then
      report "unknown-vocab" "${PRECEDENTS_MD}: ${val}"
    fi
  done < <(extract_precedent_field "$PRECEDENTS_MD" "観点")
fi

# ---- 検出2: 「カタログ外」判例 ----

if [ -f "$PRECEDENTS_MD" ]; then
  count="$(extract_precedent_field "$PRECEDENTS_MD" "観点" | LC_ALL=C grep -Fx -c -- "カタログ外" || true)"
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
