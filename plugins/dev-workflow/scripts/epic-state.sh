# shellcheck shell=bash
# エピックの子の状態の記録を読み書きする関数（epic-dispatch.sh が source する。単体では実行しない）。
#
# 記録は ${EPIC_STATE_ROOT:-$HOME/.claude/epic-state}/<エピックの owner>.<repo>-<エピック番号>/<子の owner>.<repo>-<子の番号>.json
# に子ごと 1 ファイル。項目は schema(1)・epic・child・repo・number・launcher・parent_worktree・worktree・branch・
# base・session・launch_failed・status(running|waiting|done)・stop(""|stopped|stopped-seen|resumed)・
# created_at・updated_at。知らない項目は残す。書き込みは同じディレクトリの一時ファイルから mv で置き換え、
# 読んで書き換えるときは <記録>.lock を mkdir して排他する。残ったロックは消さない。
# このファイルは起動部品の名前を書かない（起動部品のコマンドを呼ぶのは epic-dispatch.sh だけ）。
#
# 正本: openspec の dev-workflow-epic-state spec。

ES_ROOT=""

# 置き場の根を決めて ES_ROOT に入れる。未設定は ~/.claude/epic-state、空は 1 を返す。相対パスは今の作業ディレクトリから
es_root_init() {
  local r="${EPIC_STATE_ROOT-$HOME/.claude/epic-state}"
  [ -n "$r" ] || { echo "EPIC_STATE_ROOT must not be empty" >&2; return 1; }
  case "$r" in /*) ;; *) r="$PWD/$r" ;; esac
  while [ "${#r}" -gt 1 ] && [ "${r%/}" != "$r" ]; do r="${r%/}"; done
  ES_ROOT="$r"
}

# EPIC_STATE_LOCK_TIMEOUT（秒・既定 10）が非負の整数か
es_check_env() {
  [[ "${EPIC_STATE_LOCK_TIMEOUT-10}" =~ ^[0-9]+$ ]] || {
    echo "EPIC_STATE_LOCK_TIMEOUT must be a non-negative integer: ${EPIC_STATE_LOCK_TIMEOUT-}" >&2; return 1; }
}

# 子の引数の形（番号だけか <owner>/<repo>#<N>）
es_valid_arg() { [[ "$1" =~ ^[0-9]+$ ]] || [[ "$1" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+#[0-9]+$ ]]; }

es_lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# 子の引数を ES_ARG_REPO（小文字の <owner>/<repo>。番号だけなら空）と ES_ARG_NUM に分ける
ES_ARG_REPO=""; ES_ARG_NUM=""
es_parse_arg() {
  case "$1" in
    *"#"*) ES_ARG_REPO="$(es_lower "${1%%#*}")"; ES_ARG_NUM="${1##*#}" ;;
    *) ES_ARG_REPO=""; ES_ARG_NUM="$1" ;;
  esac
}

# origin の URL から小文字の <owner>/<repo> を出す。GitHub の 3 つの形でなければ 1
es_repo_from_url() {
  local u="$1" rest o r
  case "$u" in
    git@github.com:*) rest="${u#git@github.com:}" ;;
    ssh://git@github.com/*) rest="${u#ssh://git@github.com/}" ;;
    https://github.com/*) rest="${u#https://github.com/}" ;;
    *) return 1 ;;
  esac
  rest="${rest%/}"; rest="${rest%.git}"
  [[ "$rest" =~ ^([A-Za-z0-9-]+)/([A-Za-z0-9._-]+)$ ]] || return 1
  o="${BASH_REMATCH[1]}"; r="${BASH_REMATCH[2]}"
  es_lower "$o/$r"
}

# 今のワークツリーの origin からエピックの <owner>/<repo> を出す。読めなければ stderr に理由を出して 1
es_epic_repo() {
  local url
  if ! url="$(git remote get-url origin 2>/dev/null)" || [ -z "$url" ]; then
    echo "cannot read the epic repository from origin: no origin" >&2; return 1
  fi
  es_repo_from_url "$url" || { echo "cannot read the epic repository from origin: $url" >&2; return 1; }
}

# <owner>/<repo> と番号から、ディレクトリ名・ファイル名の部分（<owner>.<repo>-<N>）を出す
es_name() { printf '%s-%s' "$(printf '%s' "$1" | sed 's#/#.#')" "$2"; }

# 記録のパス（<エピックの repo> <エピック番号> <子の repo> <子の番号>）
es_path() { printf '%s/%s/%s.json' "$ES_ROOT" "$(es_name "$1" "$2")" "$(es_name "$3" "$4")"; }

# <owner>.<repo>-<N> の名前を "<owner>/<repo> <N>" に戻す（owner には . が入らない）
es_split_name() {
  local s="$1" n o
  n="${s##*-}"; s="${s%-*}"
  o="${s%%.*}"
  printf '%s/%s %s' "$o" "${s#*.}" "$n"
}

ES_VALID='type == "object" and .schema == 1
  and ((.status | type) == "string") and ([.status] | inside(["running","waiting","done"]))
  and ((.stop | type) == "string") and ([.stop] | inside(["","stopped","stopped-seen","resumed"]))
  and ((.epic | type) == "string") and ((.child | type) == "string") and ((.repo | type) == "string")
  and ((.number | type) == "number") and ((.parent_worktree | type) == "string") and ((.worktree | type) == "string")'

# 記録を読んで 1 行の JSON で出す。読めない記録（JSON でない・schema が 1 でない・表に無い値・必須の項目が無い）は 1
es_read() {
  local out
  [ -f "$1" ] || return 1
  out="$(jq -c "if ($ES_VALID) then . else error(\"unreadable\") end" "$1" 2>/dev/null)" || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

es_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# 一時ファイルに書いてから mv で置き換える（<パス> <JSON>）
es_write() {
  local f="$1" dir tmp
  dir="$(dirname "$f")"
  mkdir -p "$dir" || return 1
  tmp="$dir/.$(basename "$f").tmp.$$"
  if ! printf '%s\n' "$2" > "$tmp" || ! mv -f "$tmp" "$f"; then
    rm -f "$tmp"; return 1
  fi
}

# 排他を取る（<記録のパス>）。取れなければ stderr にロックの外し方を出して 1
es_lock() {
  local lock="$1.lock" limit tries i
  limit="${EPIC_STATE_LOCK_TIMEOUT-10}"
  tries=$(( limit * 5 + 1 ))
  for (( i = 0; i < tries; i++ )); do
    mkdir "$lock" 2>/dev/null && return 0
    [ $(( i + 1 )) -lt "$tries" ] && sleep 0.2
  done
  echo "the state record is locked: $lock" >&2
  echo "check that neither the child nor the parent session is writing it, then remove the lock: rmdir $(printf '%q' "$lock")" >&2
  return 1
}

es_unlock() { rmdir "$1.lock" 2>/dev/null || true; }

# 排他を取って記録を読み、jq の式で書き換える（<パス> <jq の式> [jq の引数...]）。式が empty を返したら書かない。
# 戻り値 0 = 書いた / 1 = 排他を取れない / 2 = 読めない記録 / 3 = 書けない / 4 = 書き換えなし。書けたら新しい記録を stdout
es_modify() {
  local f="$1" filter="$2" cur new
  shift 2
  es_lock "$f" || return 1
  if ! cur="$(es_read "$f")"; then
    es_unlock "$f"; echo "unreadable state record: $f" >&2; return 2
  fi
  new="$(printf '%s' "$cur" | jq -c "$@" --arg now "$(es_now)" "($filter) | .updated_at = \$now" 2>/dev/null)" \
    || { es_unlock "$f"; return 3; }
  if [ -z "$new" ]; then es_unlock "$f"; return 4; fi
  es_write "$f" "$new" || { es_unlock "$f"; echo "could not write the state record: $f" >&2; return 3; }
  es_unlock "$f"
  printf '%s\n' "$new"
}

# 新しい記録の JSON を組み立てる（<epic の repo> <epic 番号> <子の repo> <子の番号> <launcher> <親のパス>
# <子のパス> <branch> <base> <status> <stop>）
es_new_record() {
  local now; now="$(es_now)"
  jq -cn --arg er "$1" --arg e "$2" --arg cr "$3" --arg n "$4" --arg l "$5" --arg pw "$6" --arg w "$7" \
    --arg b "$8" --arg base "$9" --arg st "${10}" --arg sp "${11}" --arg now "$now" \
    '{schema: 1, epic: "\($er)#\($e)", child: "\($cr)#\($n)", repo: $cr, number: ($n | tonumber), launcher: $l,
      parent_worktree: $pw, worktree: $w, branch: $b, base: $base, session: "", launch_failed: "",
      status: $st, stop: $sp, created_at: $now, updated_at: $now}'
}

# 今のワークツリー（<パス>）を worktree に持つ読める記録のパスを、全エピックのディレクトリから 1 行ずつ出す。
# 読めない記録は候補から外し、stderr にパスを出す
es_find_by_worktree() {
  local f rec
  [ -n "$1" ] || return 0
  for f in "$ES_ROOT"/*/*.json; do
    [ -f "$f" ] || continue
    if ! rec="$(es_read "$f")"; then
      echo "unreadable state record (skipped): $f" >&2; continue
    fi
    printf '%s' "$rec" | jq -e --arg p "$1" '.worktree == $p' >/dev/null 2>&1 && printf '%s\n' "$f"
  done
  return 0
}

# 親の側の照合: 今のワークツリー（<パス>）を parent_worktree に持ち、子の引数（<arg>）に当たる記録を
# `ok <パス>` で 1 行ずつ出す。番号だけは number と epic のリポジトリ、<owner>/<repo>#<N> は child で当てる。
# 読めない記録は中を読めないので、ディレクトリ名とファイル名で子に当たれば `bad <パス>` で出す。origin は読まない
es_find_for_parent() {
  local parent="$1" f rec dname fname erepo crepo cnum
  es_parse_arg "$2"
  for f in "$ES_ROOT"/*/*.json; do
    [ -f "$f" ] || continue
    if rec="$(es_read "$f")"; then
      if [ -n "$ES_ARG_REPO" ]; then
        printf '%s' "$rec" | jq -e --arg p "$parent" --arg c "$ES_ARG_REPO#$ES_ARG_NUM" \
          '.parent_worktree == $p and .child == $c' >/dev/null 2>&1 && printf 'ok %s\n' "$f"
      else
        printf '%s' "$rec" | jq -e --arg p "$parent" --arg n "$ES_ARG_NUM" \
          '.parent_worktree == $p and (.number | tostring) == $n and .repo == (.epic | split("#")[0])' >/dev/null 2>&1 \
          && printf 'ok %s\n' "$f"
      fi
    else
      dname="$(basename "$(dirname "$f")")"; fname="$(basename "$f" .json)"
      erepo="$(es_split_name "$dname")"; erepo="${erepo% *}"
      crepo="$(es_split_name "$fname")"; cnum="${crepo##* }"; crepo="${crepo% *}"
      [ "$cnum" = "$ES_ARG_NUM" ] || continue
      if [ -n "$ES_ARG_REPO" ]; then
        [ "$crepo" = "$ES_ARG_REPO" ] || continue
      else
        [ "$crepo" = "$erepo" ] || continue
      fi
      echo "unreadable state record: $f" >&2
      printf 'bad %s\n' "$f"
    fi
  done
  return 0
}

# es_find_for_parent の出力を 1 つに絞る。ES_HIT にパスを入れ、戻り値 0 = 1 件 / 1 = 0 件 / 2 = 2 件以上 / 3 = 読めない記録がある
ES_HIT=""
es_pick() {
  local out="$1" cnt
  ES_HIT=""
  [ -n "$out" ] || return 1
  if printf '%s\n' "$out" | grep -q '^bad '; then
    ES_HIT="$(printf '%s\n' "$out" | awk '/^bad /{print substr($0, 5); exit}')"
    return 3
  fi
  cnt="$(printf '%s\n' "$out" | grep -c '^ok ')"
  [ "$cnt" -eq 1 ] || return 2
  # shellcheck disable=SC2034
  ES_HIT="$(printf '%s\n' "$out" | sed -n 's/^ok //p')"
  return 0
}

# 記録の項目を 1 つ出す（<パス> <項目>）。読めなければ空
es_get() { es_read "$1" 2>/dev/null | jq -r --arg k "$2" '.[$k] // empty | tostring' 2>/dev/null; }
