#!/usr/bin/env bash
#
# casting-check.sh — 「観点の配役」フレームワークの語彙 lint ＋ 起案シグナル検出
#
# 対象 repo の .claude/casting/{project.md,local.md,precedents.md} に対して6項目を検査する
# （検出カテゴリ名は report の第1引数と一対一。項目数の表記は tests/casting-structure.bats が
#  この report 呼び出しの異なり数と突き合わせる）:
#   0. 配役表の表行が5列に割れない（5列未満／セル内の | で6列以上に割れる）（malformed-row）
#   0'. HTML コメント（<!-- -->）の開閉が不一致（閉じ忘れは以降を EOF まで飲み込む）（unclosed-comment）
#   1. catalog.md に無い観点語彙（「カタログ外」を除く）（unknown-vocab）
#   2. 判例台帳の「カタログ外」判例（観点追加の起案シグナル）（catalog-external-precedent）
#   3. 同一観点で帰結「論点じゃなかった」が2件以上（移譲仕組み化の起案シグナル）（repeated-not-issue）
#   4. 各ファイルの catalog_version が catalog.md の version と不一致（version-mismatch）
#
# 日本語語彙の照合は LC_ALL=C の grep -F / sed で行う（awk のマルチバイト文字列比較は
# macOS 実装で壊れる実績があるため使わない）。
#
# サブコマンド:
#   （省略時）      対象 repo の配役表・判例台帳を検査する（上記6項目）
#   resolve          catalog.md・project.md・local.md を観点（行）単位で合成した
#                     有効な配役表を、由来（カタログ既定／project／local）付きで出力する。
#                     出力前に合成の入力（project.md / local.md）へ配役表の検証
#                     （行形式・コメント開閉・語彙・catalog_version）を通し、失敗時は
#                     合成表を出さずに理由を stderr へ出力して exit 1 する（fail-closed / #117）
#
# exit code:
#   0  検出なし（resolve は合成表を出力した）
#   1  検出あり（resolve は合成表を出力していない）
#   2  使い方エラー（catalog 不在・対象 repo ルート不在・引数過多・不明オプション）
#   3  resolve のみ: 配役表（project.md / local.md）が1枚も無いため解決していない（#139）
#
# usage: casting-check.sh [resolve] [--catalog <path>] [--] [<target-repo-root>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="${SCRIPT_DIR}/../catalog/catalog.md"
TARGET=""
SUBCOMMAND="check"

usage() {
  cat <<'USAGE'
usage: casting-check.sh [resolve] [--catalog <path>] [--] [<target-repo-root>]

  （省略時）  対象 repo の配役表・判例台帳を検査する
  resolve     有効な配役表を合成して出力する（検証を通らなければ出力しない）

exit code: 0=検出なし / 1=検出あり / 2=使い方エラー / 3=配役表が1枚も無い（resolve）
USAGE
}

# 引数はサブコマンド・オプション・positional 1個をどの順でも受け取る。
# positional が2個以上来たら「どちらが対象か」を黙って決めずに使い方エラーにする
# （旧実装は後勝ちで上書きし、`--catalog <path> resolve <repo>` が黙って check に落ちていた / #139）。
set_target() {
  if [ -n "$TARGET" ]; then
    echo "casting-check: 引数が多すぎます（対象 repo ルートは1つだけ）: $1" >&2
    usage >&2
    exit 2
  fi
  TARGET="$1"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
      while [ $# -gt 0 ]; do
        set_target "$1"
        shift
      done
      break
      ;;
    resolve)
      SUBCOMMAND="resolve"
      shift
      ;;
    --catalog)
      if [ $# -lt 2 ]; then
        echo "casting-check: --catalog に値がありません" >&2
        usage >&2
        exit 2
      fi
      CATALOG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "casting-check: 不明なオプション: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      set_target "$1"
      shift
      ;;
  esac
done

TARGET="${TARGET:-.}"

if [ ! -f "$CATALOG" ]; then
  echo "casting-check: catalog not found: $CATALOG" >&2
  exit 2
fi

# 対象 repo ルートの打ち間違えを「配役表が無い repo」と同じ扱いにしない（#139）
if [ ! -d "$TARGET" ]; then
  echo "casting-check: 対象 repo ルートが存在しません: $TARGET" >&2
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

# pipe_count <line> — 行に含まれる | の個数（5列表の有効行・区切り行はちょうど6）
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
    # 5列に割れない行（| が6個ちょうどでない）は有効値として扱わない（検出は check 側が担う）。
    # 6個超はセル内に | が紛れた行で、cut の列位置が右へずれて別のセルが担い手として
    # 解決される（#139）。片側だけの判定にしないこと
    [ "$(pipe_count "$line")" -ne 6 ] && continue
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

# ---- 検出0: 5列に割れない壊れた表行（配役表のみ。「行を書くなら5列ちょうど」の強制） ----

check_malformed_rows() {
  local file="$1"
  [ -f "$file" ] || return 0
  local src line c1 pipes
  src="$(stripped_copy "$file")"
  while IFS= read -r line; do
    printf '%s\n' "$line" | LC_ALL=C grep -qE '^\|' || continue
    c1="$(printf '%s\n' "$line" | cut -d'|' -f2 | sed -E 's/^ *//; s/ *$//')"
    [ -z "$c1" ] && continue
    LC_ALL=C grep -qxF -- '観点' <<<"$c1" && continue
    printf '%s\n' "$c1" | LC_ALL=C grep -qE '^:?-+:?$' && continue
    pipes="$(pipe_count "$line")"
    if [ "$pipes" -lt 6 ]; then
      report "malformed-row" "${file}: 5列未満の行（行を書く場合は5列すべて必要）: ${line}"
    elif [ "$pipes" -gt 6 ]; then
      report "malformed-row" "${file}: 6列以上に割れる行（セル内の | が列をずらし、既定の担い手が別のセルに解決される）: ${line}"
    fi
  done < "$src"
}

# ---- 検出0': HTML コメントの開閉不一致（閉じ忘れは以降を EOF まで飲み込む） ----
#
# stripped_copy の `sed '/<!--/,/-->/d'` は閉じタグが無ければファイル末尾まで削るため、
# 閉じ忘れが1つあるだけでその配役表の上書き行が全滅し、しかも何も検出されないまま
# 「全部カタログ既定」に化ける（#139）。開閉の個数不一致を findings に積んで塞ぐ。

check_comment_balance() {
  local file="$1"
  [ -f "$file" ] || return 0
  local opens closes
  opens="$({ LC_ALL=C grep -o -F -- '<!--' "$file" || true; } | wc -l | tr -d ' ')"
  closes="$({ LC_ALL=C grep -o -F -- '-->' "$file" || true; } | wc -l | tr -d ' ')"
  if [ "$opens" != "$closes" ]; then
    report "unclosed-comment" "${file}: HTML コメントの開閉が不一致（<!-- が ${opens}個 / --> が ${closes}個）。閉じ忘れは以降の行を丸ごと無視させる"
  fi
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

# ---- catalog.md の version（検出4で使う。catalog 側の欠落は使い方エラー） ----

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

# ---- 配役表2層（project.md / local.md）の検証。check と resolve の両モードで通す ----

check_layer_files() {
  check_malformed_rows "$PROJECT_MD"
  check_malformed_rows "$LOCAL_MD"
  check_comment_balance "$PROJECT_MD"
  check_comment_balance "$LOCAL_MD"
  check_unknown_vocab "$PROJECT_MD" "$PROJECT_MD"
  check_unknown_vocab "$LOCAL_MD" "$LOCAL_MD"
  check_version "$PROJECT_MD"
  check_version "$LOCAL_MD"
}

# ---- resolve: 合成の入力を検証してから合成表を出力する（fail-closed / #117） ----
#
# 検証対象は合成の入力になる層だけ（precedents.md は合成に使わないので check モード専任）。
# 起案シグナル（「カタログ外」判例・「論点じゃなかった」2件以上）では止めない — 観点追加の
# 提案がそのリポの自走を全面停止させないため。検証に失敗したら stdout には部分表も含めて
# 何も出さず、理由（検出カテゴリ・ファイル・該当行/観点）を stderr に出して exit 1 する。
# バイパスフラグは設けない（壊れているときの調査は check モードが行と理由を出す）。

if [ "$SUBCOMMAND" = "resolve" ]; then
  # 配役表が1枚も無い対象は「検証を通った解決結果」と区別できない完全な表を返していた（#139）。
  # カタログ既定だけを返すのは正しい答えでもあるが、repo ルートの打ち間違え・casting 未導入と
  # 見分けが付かないため、合成表を出さず専用の exit code で呼び出し側に知らせる
  if [ ! -f "$PROJECT_MD" ] && [ ! -f "$LOCAL_MD" ]; then
    echo "casting-check: resolve を中止（配役表が1枚も無い）: ${CASTING_DIR}/{project.md,local.md} が存在しない" >&2
    echo "  カタログ既定だけで解決したい repo なら、行を持たない project.md を置く（/casting:init が生成する）" >&2
    exit 3
  fi
  check_layer_files
  if [ -s "$FINDINGS" ]; then
    echo "casting-check: resolve を中止（配役表が検証を通らない）:" >&2
    cat "$FINDINGS" >&2
    exit 1
  fi
  cmd_resolve
  exit 0
fi

check_layer_files

check_comment_balance "$PRECEDENTS_MD"

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

# ---- 検出4: catalog_version 不一致（precedents.md のみ。配役表2層は check_layer_files で済み） ----

check_version "$PRECEDENTS_MD"

# ---- 結果 ----

if [ -s "$FINDINGS" ]; then
  cat "$FINDINGS"
  exit 1
fi

exit 0
