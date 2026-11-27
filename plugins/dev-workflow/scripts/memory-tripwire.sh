#!/usr/bin/env bash
# メモリ索引の肥大と放置の検知（session-tripwires.sh から SessionStart ごとに呼ばれる。#294）。
# あわせて、メモリの frontmatter の patches:（直し先の issue の URL。書き方の正本は
# skills/memory-refresh/SKILL.md）の issue が閉じていないかを gh で確かめる（#1654）。
# 通知だけで、止めない・削らない。閾値を超えたか、閉じた issue を持つメモリがあるときだけ 1 行を
# stdout に出し、それ以外・メモリディレクトリ不在・読めないときは無出力で exit 0（fail-open）。
# 書くのはメモリディレクトリの外の控え（DEV_WORKFLOW_MEMORY_PATCHES_CACHE。既定
# ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.memory-patches-cache.tsv。1 行が URL・確かめた日・状態・閉じ方の
# タブ区切り）と、裏の確認が走っている間だけ置く目印のディレクトリ（控えのパスに .lock）だけ。
# 開始の処理は控えだけを読んで知らせ、gh を待たない。当日に閉じたと控えた URL のほかは、裏のプロセスで
# gh に確かめ直して控えを書き換える（知らせはその次のセッション）。裏の確認は
# DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT 秒（既定 3。0 なら gh を呼ばない）で打ち切る。確かめられなかった
# URL はその日の UNKNOWN（不明）と控え、閉じたとして扱わない。gh が無いときは控えを書かない。
# macOS の bash 3.2 で動く書き方にする。直し方の正本は skills/memory-refresh/SKILL.md。
set -uo pipefail

# 閾値（env で上書き可）。初期値の根拠は #294 の初回整理の実測コメント
# （claude-harness プロジェクトの整理後: 索引 2,285 バイト / 13 行、本文最大 2,192 バイト）。
num_or() { case "${1:-}" in ''|*[!0-9]*) printf '%s' "$2" ;; *) printf '%s' "$1" ;; esac; }
INDEX_BYTES_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_INDEX_BYTES:-}" 4000)"
INDEX_LINES_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_INDEX_LINES:-}" 20)"
FILE_BYTES_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_FILE_BYTES:-}" 2500)"
STALE_DAYS_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_STALE_DAYS:-}" 30)"
PATCHES_TIMEOUT="$(num_or "${DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT:-}" 3)"
PATCHES_CACHE="${DEV_WORKFLOW_MEMORY_PATCHES_CACHE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.memory-patches-cache.tsv}"

# メモリディレクトリの解決。Claude Code は worktree でも元のリポジトリ（git の共通ディレクトリの親）で
# project を決め、そのパスの英数字以外を - にした名前を ~/.claude/projects/ の下に使う。
resolve_dir() {
  if [ -n "${DEV_WORKFLOW_MEMORY_DIR:-}" ]; then
    printf '%s' "$DEV_WORKFLOW_MEMORY_DIR"
    return
  fi
  local cwd="${CLAUDE_PROJECT_DIR:-$PWD}" common root
  common="$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)" || common=""
  if [ -n "$common" ]; then
    root="$(cd "$cwd" && cd "$common/.." && pwd -P)" || return 1
  else
    root="$(cd "$cwd" && pwd -P)" || return 1
  fi
  printf '%s/projects/%s/memory' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" "${root//[^A-Za-z0-9]/-}"
}

dir="$(resolve_dir)" || exit 0
index="${dir}/MEMORY.md"
[ -r "$index" ] || exit 0

index_bytes=$(( $(wc -c < "$index") ))
index_lines=$(( $(wc -l < "$index") ))

max_bytes=0
max_name=""
while read -r b path; do
  case "$path" in ''|total|*/MEMORY.md) continue ;; esac
  if [ "$b" -gt "$max_bytes" ]; then
    max_bytes="$b"
    max_name="${path##*/}"
  fi
done < <(wc -c "$dir"/*.md 2>/dev/null)

mtime="$(stat -c %Y "$index" 2>/dev/null || stat -f %m "$index" 2>/dev/null)" || mtime=""
now="${EPOCHSECONDS:-$(date +%s)}"
days=0
[ -n "$mtime" ] && days=$(( (now - mtime) / 86400 ))

# --- patches: の issue（#1654） ---
# frontmatter（1 行目の --- から次の --- まで）のトップレベルの patches: と、metadata: の下に字下げした
# patches: を読む。値が GitHub の issue の URL の形のものだけを「ファイル名<TAB>URL」で出す。
# ファイルが 1 件も無いときに awk が標準入力（hook の入力）を読まないよう /dev/null を必ず渡す。
mem_files=()
for f in "$dir"/*.md; do [ "${f##*/}" = MEMORY.md ] || [ ! -f "$f" ] || mem_files+=("$f"); done
patch_pairs="$(awk '
  FNR == 1 { infm = ($0 == "---"); inmeta = 0; next }
  !infm { next }
  $0 == "---" { infm = 0; next }
  /^[^ \t]/ { inmeta = ($0 ~ /^metadata:[ \t]*$/) }
  /^patches:/ || (inmeta && /^[ \t]+patches:/) {
    v = $0; sub(/^[ \t]*patches:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
    if (v ~ /^https:\/\/github\.com\/[^\/ \t]+\/[^\/ \t]+\/issues\/[0-9]+$/) {
      n = FILENAME; sub(/.*\//, "", n); print n "\t" v
    }
  }
' ${mem_files[@]+"${mem_files[@]}"} /dev/null 2>/dev/null)" || patch_pairs=""

# 裏の確認（#1654）: 引数の URL（1 行 1 本）を gh で確かめ、控えを書き換える。開始の処理からは
# 標準入力・標準出力・標準エラーを閉じた裏のプロセスとして呼ぶ。終わったら目印（${lock}）を外す。
check_patches() {
  local need="$1" work i pids e n pid u st why out s r start timer new_lines cur kept body tmpc
  trap 'rmdir "$lock" 2>/dev/null' EXIT
  work="$(mktemp -d "${TMPDIR:-/tmp}/memory-patches.XXXXXX" 2>/dev/null)" || return 0
  i=0; pids=""
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    i=$((i + 1))
    printf '%s' "$u" > "${work}/${i}.url"
    gh issue view "$u" --json state,stateReason > "${work}/${i}.out" 2>/dev/null < /dev/null &
    pids="${pids} ${i}:$!"
  done <<< "$need"
  # 打ち切り: TIMEOUT 秒の sleep を時計にして、それが終わるまで 0.05 秒刻みで待つ（bash 3.2 には
  # timeout と EPOCHREALTIME が無い）。上限は秒で決め、刻みの数に頼らない（負荷で刻みが遅れても
  # 待ちが延びない）。時計を起こせなかったときのために、整数の SECONDS でも上限をかける。
  start="$SECONDS"
  sleep "$PATCHES_TIMEOUT" 2>/dev/null & timer=$!
  while :; do
    running=0
    for e in $pids; do kill -0 "${e#*:}" 2>/dev/null && running=1; done
    [ "$running" -eq 0 ] && break
    kill -0 "$timer" 2>/dev/null || break
    [ $((SECONDS - start)) -gt "$PATCHES_TIMEOUT" ] && break
    sleep 0.05
  done
  kill "$timer" 2>/dev/null; wait "$timer" 2>/dev/null
  new_lines=""
  for e in $pids; do
    n="${e%%:*}"; pid="${e#*:}"
    u="$(cat "${work}/${n}.url")"
    st="UNKNOWN"; why=""
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null  # 自分が起こした gh だけを PID で止める
      wait "$pid" 2>/dev/null
    elif wait "$pid" 2>/dev/null; then
      out="$(cat "${work}/${n}.out" 2>/dev/null)"
      s="$(printf '%s' "$out" | sed -n 's/.*"state":"\([A-Z_]*\)".*/\1/p')"
      r="$(printf '%s' "$out" | sed -n 's/.*"stateReason":"\([A-Z_]*\)".*/\1/p')"
      case "$s" in OPEN|CLOSED) st="$s"; why="$r" ;; esac
    fi
    new_lines="${new_lines}${u}	${today}	${st}	${why}
"
  done
  rm -rf "$work"
  # 控えを書き換える（書く直前の控えを読み直し、確かめた URL の古い行を外して足す）。
  # 別のファイルに書いてから置き換える。
  cur=""
  [ -r "$PATCHES_CACHE" ] && cur="$(cat "$PATCHES_CACHE" 2>/dev/null)"
  kept="$(printf '%s\n' "$cur" | awk -F '\t' '
    NR == FNR { if ($1 != "") skip[$1] = 1; next }
    $1 != "" && !($1 in skip)
  ' <(printf '%s' "$new_lines") - 2>/dev/null)"
  body="${kept:+${kept}
}${new_lines}"
  tmpc="$(mktemp "${PATCHES_CACHE}.XXXXXX" 2>/dev/null)" || return 0
  if ! { printf '%s' "$body" > "$tmpc" && mv -f "$tmpc" "$PATCHES_CACHE"; } 2>/dev/null; then
    rm -f "$tmpc"
  fi
}

closed_list=""
if [ -n "$patch_pairs" ]; then
  today="$(date +%Y-%m-%d)"
  urls="$(printf '%s\n' "$patch_pairs" | cut -f2 | sort -u)"
  cache_body=""
  [ -r "$PATCHES_CACHE" ] && cache_body="$(cat "$PATCHES_CACHE" 2>/dev/null)"
  # 控えの状態が閉じている URL を持つメモリ（URL ごとに最後の行を使う）。開始の処理は控えだけを見る
  closed_list="$(printf '%s\n' "$patch_pairs" | awk -F '\t' '
    NR == FNR { if ($1 != "") st[$1] = $3; next }
    $2 != "" && st[$2] == "CLOSED" { print $1 " ← " $2 }
  ' <(printf '%s\n' "$cache_body") - 2>/dev/null)"
  # 確かめ直す URL: 当日に閉じたと控えたもの以外（控えの無いもの、当日に OPEN・UNKNOWN と控えたもの、
  # 前の日の控え）
  need="$(printf '%s\n' "$urls" | awk -F '\t' -v d="$today" '
    NR == FNR { if ($1 != "") { dt[$1] = $2; st[$1] = $3 }; next }
    $1 != "" && !(dt[$1] == d && st[$1] == "CLOSED") { print }
  ' <(printf '%s\n' "$cache_body") - 2>/dev/null)"
  case "$PATCHES_CACHE" in "$dir"/*) need="" ;; esac  # 控えをメモリディレクトリに置かない
  if [ -n "$need" ] && [ "$PATCHES_TIMEOUT" -gt 0 ] && command -v gh >/dev/null 2>&1; then
    # 目印が取れたときだけ裏の確認を起こす（同時に 2 つ走らせない）。打ち切りより 60 秒以上古い目印は、
    # 途中で止まった確認の残りとみなして取り直す。控えの置き場所が無ければ目印も取れず、確かめない
    lock="${PATCHES_CACHE}.lock"
    if ! mkdir "$lock" 2>/dev/null; then
      lm="$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null)" || lm=""
      if [ -n "$lm" ] && [ $((now - lm)) -gt $((PATCHES_TIMEOUT + 60)) ] && rmdir "$lock" 2>/dev/null; then
        mkdir "$lock" 2>/dev/null || lock=""
      else
        lock=""
      fi
    fi
    if [ -n "$lock" ]; then
      # 標準入力・標準出力・標準エラーと fd 3 を閉じて起こす（hook を走らせる側がパイプの終わりを待たない）
      ( check_patches "$need" ) < /dev/null > /dev/null 2>&1 3>&- &
    fi
  fi
fi

msg=""
add() { if [ -z "$msg" ]; then msg="$1"; else msg="${msg}、$1"; fi; }
if [ "$index_bytes" -gt "$INDEX_BYTES_MAX" ] || [ "$index_lines" -gt "$INDEX_LINES_MAX" ]; then
  add "索引 ${index_bytes} バイト / ${index_lines} 行（閾値 ${INDEX_BYTES_MAX} / ${INDEX_LINES_MAX}）"
fi
if [ "$max_bytes" -gt "$FILE_BYTES_MAX" ]; then
  add "本文 ${max_name} が ${max_bytes} バイト（閾値 ${FILE_BYTES_MAX}）"
fi
if [ "$days" -gt "$STALE_DAYS_MAX" ]; then
  add "索引の最終更新から ${days} 日（閾値 ${STALE_DAYS_MAX}）"
fi
if [ -n "$closed_list" ]; then
  add "閉じた issue を patches: に持つメモリ $(printf '%s\n' "$closed_list" | grep -c '') 件（$(printf '%s\n' "$closed_list" | paste -sd '|' - | sed 's/|/、/g')）"
fi
[ -n "$msg" ] || exit 0

printf '[memory] メモリの見直しが必要です: %s。/memory-refresh で見直してください（削除・短縮の適用前に主の承認が要る）\n' "$msg"
