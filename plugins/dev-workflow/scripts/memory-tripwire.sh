#!/usr/bin/env bash
# メモリ索引の肥大と放置の検知（session-tripwires.sh から SessionStart ごとに呼ばれる。#294）。
# 通知だけで、止めない・削らない。閾値を超えたときだけ 1 行を stdout に出し、
# 閾値未満・メモリディレクトリ不在・読めないときは無出力で exit 0（fail-open）。
# 直し方の正本は skills/memory-refresh/SKILL.md。
set -uo pipefail

# 閾値（env で上書き可）。初期値の根拠は #294 の初回整理の実測コメント
# （claude-harness プロジェクトの整理後: 索引 2,285 バイト / 13 行、本文最大 2,192 バイト）。
num_or() { case "${1:-}" in ''|*[!0-9]*) printf '%s' "$2" ;; *) printf '%s' "$1" ;; esac; }
INDEX_BYTES_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_INDEX_BYTES:-}" 4000)"
INDEX_LINES_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_INDEX_LINES:-}" 20)"
FILE_BYTES_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_FILE_BYTES:-}" 2500)"
STALE_DAYS_MAX="$(num_or "${DEV_WORKFLOW_MEMORY_STALE_DAYS:-}" 30)"

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
[ -n "$msg" ] || exit 0

printf '[memory] メモリの見直しが必要です: %s。/memory-refresh で見直してください（削除・短縮の適用前に主の承認が要る）\n' "$msg"
