#!/bin/bash
# ─────────────────────────────────────────────────────────────
# forbidden-words-check.sh — 公開側のリポジトリに固有名が混ざっていないかを辞書で調べる共有スクリプト（issue #1207）
#
#   printf '%s\n' <ファイル一覧> | forbidden-words-check.sh --root <dir> --dict <file> [--dict <file>...]
#                                    [--allow <file>...] [--name <名前>] [--count-file <file>]
#
# 標準入力: 検査するファイルの一覧（1 行 1 パス、--root からの相対。空行は無視）。
#   一覧の集合の選定とルートの外を指す symlink の排除は呼び出し側の責務。
# 引数:
#   --root <dir>        必須。検査の cwd（--dict / --allow / --count-file の相対パスもここから解く）
#   --dict <file>       1 回以上。複数回指定できる（引数の順・各ファイルの行の順に連結。重複する語も保持）
#   --allow <file>      0 回以上。複数回指定できる
#   --name <名前>       任意。既定 forbidden-words-check。gh が引けないときの通知の先頭に使う
#   --count-file <file> 任意。違反の件数を 10 進数 1 行で書く（違反 0 件でも 0 を書く）
# 環境変数:
#   FORBIDDEN_WORDS_NO_GH  非空なら gh を呼ばない（書式と未使用の検査だけ）。gh は呼び出し元の PATH から探し、--root を cwd にして呼ぶ
# 終了コード: 0 = 違反なし / 1 = 違反あり / 2 = 引数の誤り・--count-file に書けない。違反は 1 件 1 行で stderr に出す。stdout には何も出さない。
#
# 辞書: 1 行 1 語の固定文字列。空行と # 始まりは無視。大文字小文字を区別しない部分一致で、本文（バイナリは見ない）とパス名に当てる。
# allow: 1 行 1 件 <path>:<語>:<第 3 欄>。空行と # 始まりは無視。第 3 欄は 2 つ目の : から行末まで。
#   #<issue番号>              期限付き。そのファイルの中のその語の当たりをすべて許す。issue が OPEN の間だけ有効
#   =<行に含まれる固定の文字列> 恒久。その語に当たった本文の行のうち、固定の文字列を含む行だけを許す（パス名の当たりは許さない）。期限なし
# 違反の順序: 辞書の読み込み → allow の書式 → ファイルごとの当たり → 未使用の allow → issue の状態
# 規則の詳細: plugins/dev-workflow/docs/forbidden-words-check.md
# 仕様の正本: openspec の capability dev-workflow-forbidden-words-check
# ─────────────────────────────────────────────────────────────
set -u

usage() {
  echo "usage: forbidden-words-check.sh --root <dir> --dict <file> [--dict <file>...] [--allow <file>...] [--name <名前>] [--count-file <file>] < ファイル一覧" >&2
  exit 2
}

ROOT=""
NAME="forbidden-words-check"
COUNT_FILE=""
DICTS=()
ALLOWS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
    --dict) [ $# -ge 2 ] || usage; DICTS+=("$2"); shift 2 ;;
    --allow) [ $# -ge 2 ] || usage; ALLOWS+=("$2"); shift 2 ;;
    --name) [ $# -ge 2 ] || usage; NAME="$2"; shift 2 ;;
    --count-file) [ $# -ge 2 ] || usage; COUNT_FILE="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$ROOT" ] || usage
[ "${#DICTS[@]}" -gt 0 ] || usage

# ファイル一覧は cd の前に読む
FILES="$(sed '/^$/d')"

cd "$ROOT" 2>/dev/null || { echo "$NAME: ルートに移れない: $ROOT" >&2; exit 2; }

VIOLATIONS=0
violation() { echo "$*" >&2; VIOLATIONS=$((VIOLATIONS+1)); }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ── 禁止語 ───────────────────────────────────────────────────
NW=0
WORDS=()
WORDS_LC=()
WORD_ARGS=()
for dict in "${DICTS[@]}"; do
  if [ -f "$dict" ] && [ ! -r "$dict" ]; then
    violation "$dict: 読めない"
  elif [ -f "$dict" ]; then
    while IFS= read -r w || [ -n "$w" ]; do
      case "$w" in ''|'#'*) continue ;; esac
      WORDS[$NW]="$w"; WORDS_LC[$NW]="$(lower "$w")"; NW=$((NW+1))
      WORD_ARGS+=(-e "$w")
    done < "$dict"
  else
    violation "$dict: 無い"
  fi
done

# ── allow の読み込みと書式の検査 ────────────────────────────────
NA=0
A_FILE=(); A_LINE=(); A_NO=(); A_PATH=(); A_WORD=(); A_KIND=(); A_ARG=(); A_USED=()
for af in ${ALLOWS[@]+"${ALLOWS[@]}"}; do
  [ -f "$af" ] || continue
  no=0
  while IFS= read -r line || [ -n "$line" ]; do
    no=$((no+1))
    case "$line" in ''|'#'*) continue ;; esac
    kind=""
    if printf '%s\n' "$line" | grep -qE '^[^:]+:[^:]+:#[0-9]+$'; then
      kind="t"
    elif printf '%s\n' "$line" | grep -qE '^[^:]+:[^:]+:=.+$'; then
      kind="p"
    fi
    if [ -z "$kind" ]; then
      violation "$af:$no: 書式が <path>:<語>:#<issue番号> でない: $line"
      continue
    fi
    r="${line#*:}"
    t="${r#*:}"
    A_FILE[$NA]="$af"; A_LINE[$NA]="$line"; A_NO[$NA]="$no"; A_KIND[$NA]="$kind"
    A_PATH[$NA]="${line%%:*}"; A_WORD[$NA]="$(lower "${r%%:*}")"
    if [ "$kind" = "t" ]; then A_ARG[$NA]="${t#\#}"; else A_ARG[$NA]="${t#=}"; fi
    A_USED[$NA]=0
    NA=$((NA+1))
  done < "$af"
done

# allowed_timed <path> <語の小文字>: 期限付きの行があれば使用済みにして 0
allowed_timed() {
  local i=0 hit=1
  while [ "$i" -lt "$NA" ]; do
    if [ "${A_KIND[$i]}" = "t" ] && [ "${A_PATH[$i]}" = "$1" ] && [ "${A_WORD[$i]}" = "$2" ]; then
      A_USED[$i]=1; hit=0
    fi
    i=$((i+1))
  done
  return $hit
}

# allowed_line <path> <語の小文字> <行の本文>: 本文が恒久の行の固定の文字列を含めば使用済みにして 0
allowed_line() {
  local i=0 hit=1
  while [ "$i" -lt "$NA" ]; do
    if [ "${A_KIND[$i]}" = "p" ] && [ "${A_PATH[$i]}" = "$1" ] && [ "${A_WORD[$i]}" = "$2" ]; then
      case "$3" in *"${A_ARG[$i]}"*) A_USED[$i]=1; hit=0 ;; esac
    fi
    i=$((i+1))
  done
  return $hit
}

# ── ファイルの中身とパスの照合 ─────────────────────────────────
if [ "$NW" -gt 0 ] && [ -n "$FILES" ]; then
  while IFS= read -r f; do
    pl="$(lower "$f")"
    # 中身にどれかの語があるときだけ語ごとに引く（-I でバイナリの中身は見ない）
    content_hit=0
    if [ ! -r "$f" ]; then
      violation "$f: 読めない"
      rc=2
    else
      grep -qiIF "${WORD_ARGS[@]}" -- "$f" 2>/dev/null; rc=$?
    fi
    case "$rc" in
      0) content_hit=1 ;;
      1) ;;
      *) [ -r "$f" ] && violation "$f: 読めない（grep の終了コード ${rc}）" ;;
    esac
    i=0
    while [ "$i" -lt "$NW" ]; do
      w="${WORDS[$i]}"; wl="${WORDS_LC[$i]}"
      case "$pl" in
        *"$wl"*) allowed_timed "$f" "$wl" || violation "$f:path:$w" ;;
      esac
      if [ "$content_hit" = 1 ]; then
        hits="$(grep -niIF -e "$w" -- "$f" 2>/dev/null)"
        if [ -n "$hits" ] && ! allowed_timed "$f" "$wl"; then
          while IFS= read -r h; do
            n="${h%%:*}"; body="${h#*:}"
            allowed_line "$f" "$wl" "$body" || violation "$f:$n:$w"
          done <<HITS
$hits
HITS
        fi
      fi
      i=$((i+1))
    done
  done <<FILELIST
$FILES
FILELIST
fi

# ── allow の放置と issue の状態 ─────────────────────────────────
i=0
while [ "$i" -lt "$NA" ]; do
  if [ "${A_USED[$i]}" = 0 ]; then
    violation "${A_FILE[$i]}:${A_NO[$i]}: 何も打ち消していない（出荷集合に無い・語がもう無い）: ${A_LINE[$i]}"
  fi
  i=$((i+1))
done

HAS_TIMED=0
i=0
while [ "$i" -lt "$NA" ]; do
  [ "${A_KIND[$i]}" = "t" ] && HAS_TIMED=1
  i=$((i+1))
done

if [ "$HAS_TIMED" = 1 ] && [ -z "${FORBIDDEN_WORDS_NO_GH:-}" ] && command -v gh >/dev/null 2>&1; then
  seen=" "
  i=0
  while [ "$i" -lt "$NA" ]; do
    if [ "${A_KIND[$i]}" != "t" ]; then i=$((i+1)); continue; fi
    n="${A_ARG[$i]}"
    case "$seen" in *" $n "*) i=$((i+1)); continue ;; esac
    seen="$seen$n "
    if ! state="$(gh issue view "$n" --json state -q .state 2>/dev/null)"; then
      echo "$NAME: gh で issue #$n の状態を引けないため、allow は書式だけ検査する" >&2
      break
    fi
    if [ "$state" != "OPEN" ]; then
      j=0
      while [ "$j" -lt "$NA" ]; do
        if [ "${A_KIND[$j]}" = "t" ] && [ "${A_ARG[$j]}" = "$n" ]; then
          violation "${A_FILE[$j]}:${A_NO[$j]}: issue #$n が OPEN でない（${state}）: ${A_LINE[$j]}"
        fi
        j=$((j+1))
      done
    fi
    i=$((i+1))
  done
fi

# ── 結果 ─────────────────────────────────────────────────────
if [ -n "$COUNT_FILE" ]; then
  printf '%s\n' "$VIOLATIONS" > "$COUNT_FILE" 2>/dev/null || { echo "$NAME: 件数を書けない: $COUNT_FILE" >&2; exit 2; }
fi
[ "$VIOLATIONS" -gt 0 ] && exit 1
exit 0
