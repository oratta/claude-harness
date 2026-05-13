#!/usr/bin/env bash
#
# jsonl-finder.sh — locate Claude Code session jsonl files for a given cwd
#
# Provides three helper functions for the experience-to-skill jsonl-distillation
# pipeline:
#
#   e2s_encode_cwd <abs-path>
#       Map an absolute filesystem path to the directory naming convention used
#       under ~/.claude/projects/. Both `/` and `.` are replaced with `-`, so
#       `/Users/oratta/.claude-mem` -> `-Users-oratta--claude-mem`.
#
#   e2s_resolve_jsonl_dir <abs-cwd>
#       Return the absolute path of the projects directory that hosts session
#       jsonl for the supplied cwd. Falls back to a longest-prefix-match search
#       across ~/.claude/projects/ when the primary encoded entry is missing
#       (e.g. when Claude Code's encoding rules diverge in edge cases).
#       Echoes nothing and exits non-zero when no candidate exists.
#
#   e2s_list_jsonl <abs-cwd>
#       List jsonl files for cwd applying four short-circuiting filter stages:
#         (1) projects dir existence check
#         (2) mtime range filter (optional; honours $E2S_JSONL_SINCE_DAYS)
#         (3) file size upper bound (default 50MB; override via $E2S_JSONL_MAX_SIZE bytes)
#         (4) keyword grep when $E2S_JSONL_KEYWORDS is non-empty (space-separated)
#       Stage (1) returns non-zero immediately when the directory is missing.
#
# Environment:
#   E2S_PROJECTS_DIR        Base dir to scan (default ~/.claude/projects).
#                           Tests override this to a tmp dir.
#   E2S_JSONL_MAX_SIZE      Max file size in bytes for filter (3). Default 52428800 (50MB).
#   E2S_JSONL_SINCE_DAYS    If set, only files modified within the last N days pass.
#   E2S_JSONL_KEYWORDS      Optional grep keywords (space-separated).

set -o pipefail

e2s_projects_dir() {
  printf '%s' "${E2S_PROJECTS_DIR:-$HOME/.claude/projects}"
}

e2s_encode_cwd() {
  local path="${1:-}"
  if [ -z "$path" ]; then
    return 1
  fi
  # Strip any trailing slash so /foo/ and /foo encode identically.
  while [ "${path: -1}" = "/" ] && [ ${#path} -gt 1 ]; do
    path="${path%/}"
  done
  # Replace `/` and `.` with `-`. Order is irrelevant; do them in one pass.
  local result="${path//\//-}"
  result="${result//./-}"
  printf '%s' "$result"
}

e2s_resolve_jsonl_dir() {
  local cwd="${1:-}"
  if [ -z "$cwd" ]; then
    return 1
  fi
  local base
  base="$(e2s_projects_dir)"
  if [ ! -d "$base" ]; then
    return 1
  fi
  local encoded
  encoded="$(e2s_encode_cwd "$cwd")"
  if [ -d "$base/$encoded" ]; then
    printf '%s' "$base/$encoded"
    return 0
  fi
  # Fallback: longest-prefix match against entries whose name begins with the
  # encoded prefix. This handles edge cases where Claude Code's actual encoding
  # diverges from our naive transform (e.g. additional suffix characters).
  local best=""
  local best_len=0
  local entry name len
  for entry in "$base"/*; do
    [ -d "$entry" ] || continue
    name="$(basename "$entry")"
    case "$name" in
      "$encoded"*)
        len=${#name}
        if [ "$len" -gt "$best_len" ]; then
          best="$entry"
          best_len="$len"
        fi
        ;;
    esac
  done
  if [ -n "$best" ]; then
    printf '%s' "$best"
    return 0
  fi
  return 1
}

e2s_list_jsonl() {
  local cwd="${1:-}"
  # Stage 1: directory existence (short-circuit when missing).
  local dir
  if ! dir="$(e2s_resolve_jsonl_dir "$cwd")"; then
    return 1
  fi
  local max_size="${E2S_JSONL_MAX_SIZE:-52428800}"
  local since_days="${E2S_JSONL_SINCE_DAYS:-}"
  local keywords="${E2S_JSONL_KEYWORDS:-}"

  # Stage 2: mtime range filter (optional).
  local find_args=("$dir" -maxdepth 1 -type f -name '*.jsonl')
  if [ -n "$since_days" ]; then
    find_args+=(-mtime "-${since_days}")
  fi

  # Collect candidates.
  local file
  local results=()
  while IFS= read -r -d '' file; do
    # Stage 3: size upper bound (portable wc -c; macOS/BSD compatible).
    local size
    size=$(wc -c < "$file" | tr -d ' ')
    if [ "$size" -gt "$max_size" ]; then
      continue
    fi
    # Stage 4: keyword grep (only when keywords requested).
    if [ -n "$keywords" ]; then
      local matched=0
      local kw
      for kw in $keywords; do
        if grep -q -F -- "$kw" "$file"; then
          matched=1
          break
        fi
      done
      [ "$matched" -eq 1 ] || continue
    fi
    results+=("$file")
  done < <(find "${find_args[@]}" -print0 2>/dev/null)

  local r
  for r in "${results[@]}"; do
    printf '%s\n' "$r"
  done
}

# CLI entry: when invoked directly, list jsonl for the current working directory.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  e2s_list_jsonl "$(pwd)"
fi
