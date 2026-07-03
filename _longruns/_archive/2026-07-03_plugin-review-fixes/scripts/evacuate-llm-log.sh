#!/usr/bin/env bash
#
# evacuate-llm-log.sh — snapshot-based safe relocation of untracked LLM/
# session logs into $LLM_LOG_DIR, per openspec/changes/plugin-retirement
# capability llm-log-relocation (S1-S8).
#
# Usage:
#   evacuate-llm-log.sh snapshot <src_dir> <snapshot_file>
#     Records the current file count + filename list of <src_dir> (maxdepth 1,
#     regular files only) into <snapshot_file> BEFORE any mv happens. Format:
#       line 1: file count
#       lines 2..N+1: filenames, one per line
#
#   evacuate-llm-log.sh execute <src_dir> <dest_dir> <snapshot_file> <report_file>
#     For every filename recorded in <snapshot_file>:
#       - if a same-named file already exists under <dest_dir>, skip the mv
#         (destination is never overwritten), leave the source file in place,
#         and record it as a collision.
#       - otherwise mv the file from <src_dir> to <dest_dir> and count it as moved.
#     Reconciliation: moved + collision-skipped MUST equal the snapshot count.
#     Any snapshotted filename that is present in neither <src_dir> nor
#     <dest_dir> and was not recorded as a collision is a genuine loss —
#     reconciliation fails loudly (nonzero exit) and this is reported.
#     Any file present in <src_dir> that was NOT part of the snapshot (e.g.
#     the auto-save.py Stop hook writing a new file during evacuation) is
#     excluded from the reconciliation arithmetic and reported separately as
#     hook-attributed.
#     Writes a human-readable report to <report_file> covering: moved count,
#     collision list (or "zero collisions"), and hook-attributed new files
#     (or "none").

set -uo pipefail

usage() {
  echo "Usage:" >&2
  echo "  $0 snapshot <src_dir> <snapshot_file>" >&2
  echo "  $0 execute <src_dir> <dest_dir> <snapshot_file> <report_file>" >&2
  exit 2
}

cmd_snapshot() {
  local src_dir="$1" snapshot_file="$2"

  if [ ! -d "$src_dir" ]; then
    # A missing source dir evacuates trivially: zero files.
    {
      echo "0"
    } > "$snapshot_file"
    return 0
  fi

  local -a files=()
  while IFS= read -r -d '' f; do
    files+=("$(basename "$f")")
  done < <(find "$src_dir" -maxdepth 1 -type f -print0 | sort -z)

  {
    echo "${#files[@]}"
    for f in "${files[@]}"; do
      echo "$f"
    done
  } > "$snapshot_file"
}

cmd_execute() {
  local src_dir="$1" dest_dir="$2" snapshot_file="$3" report_file="$4"

  if [ ! -f "$snapshot_file" ]; then
    echo "evacuate-llm-log.sh: snapshot file not found: $snapshot_file" >&2
    return 2
  fi

  mkdir -p "$dest_dir"

  local -a snapshot_names=()
  {
    read -r _count
    while IFS= read -r name; do
      [ -n "$name" ] && snapshot_names+=("$name")
    done
  } < "$snapshot_file"
  local snapshot_count="${#snapshot_names[@]}"

  local -a moved=()
  local -a collisions=()
  local -a lost=()

  for name in "${snapshot_names[@]}"; do
    local src_path="${src_dir}/${name}"
    local dest_path="${dest_dir}/${name}"

    if [ -f "$dest_path" ]; then
      # Already at destination (either a genuine collision, or this file
      # was already moved in a prior partial run). Either way: do not
      # overwrite, and treat as a collision-skip if the source still exists.
      collisions+=("$name")
      continue
    fi

    if [ -f "$src_path" ]; then
      mv "$src_path" "$dest_path"
      moved+=("$name")
      continue
    fi

    # Snapshotted filename is present in neither src nor dest, and was
    # never marked as a collision-skip: genuine loss.
    lost+=("$name")
  done

  # Detect hook-attributed new files: anything now in src_dir that was not
  # part of the original snapshot.
  local -a hook_new=()
  if [ -d "$src_dir" ]; then
    while IFS= read -r -d '' f; do
      local base
      base="$(basename "$f")"
      local known=0
      for name in "${snapshot_names[@]}"; do
        if [ "$name" = "$base" ]; then
          known=1
          break
        fi
      done
      if [ "$known" -eq 0 ]; then
        hook_new+=("$base")
      fi
    done < <(find "$src_dir" -maxdepth 1 -type f -print0 | sort -z)
  fi

  {
    echo "# LLM/ evacuation report"
    echo
    echo "Snapshot count: ${snapshot_count}"
    echo "Moved: ${#moved[@]}"
    echo
    echo "## Collisions"
    if [ "${#collisions[@]}" -eq 0 ]; then
      echo "zero collisions"
    else
      for name in "${collisions[@]}"; do
        echo "- ${name}"
      done
    fi
    echo
    echo "## Hook-attributed new files (excluded from reconciliation)"
    if [ "${#hook_new[@]}" -eq 0 ]; then
      echo "none"
    else
      for name in "${hook_new[@]}"; do
        echo "- ${name}"
      done
    fi
    if [ "${#lost[@]}" -gt 0 ]; then
      echo
      echo "## RECONCILIATION FAILED — genuine loss detected"
      for name in "${lost[@]}"; do
        echo "- ${name}"
      done
    fi
  } > "$report_file"

  if [ "${#lost[@]}" -gt 0 ]; then
    echo "evacuate-llm-log.sh: reconciliation failed, missing: ${lost[*]}" >&2
    return 1
  fi

  local reconciled=$(( ${#moved[@]} + ${#collisions[@]} ))
  if [ "$reconciled" -ne "$snapshot_count" ]; then
    echo "evacuate-llm-log.sh: reconciliation arithmetic mismatch (moved=${#moved[@]} collisions=${#collisions[@]} snapshot=${snapshot_count})" >&2
    return 1
  fi

  return 0
}

main() {
  local sub="${1:-}"
  case "$sub" in
    snapshot)
      [ "$#" -eq 3 ] || usage
      cmd_snapshot "$2" "$3"
      ;;
    execute)
      [ "$#" -eq 5 ] || usage
      cmd_execute "$2" "$3" "$4" "$5"
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
