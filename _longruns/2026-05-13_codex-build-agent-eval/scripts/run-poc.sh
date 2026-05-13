#!/usr/bin/env bash
#
# run-poc.sh — Codex Build Agent PoC harness (Phase 1)
#
# Responsibilities:
#   1. Refuse to run when the worktree has uncommitted changes (so that any
#      drift after the Codex call is unambiguously attributable to Codex).
#   2. Invoke codex-companion against the sandbox to drive a TDD loop on
#      sandbox/src/greet.ts. (Skipped when CODEX_DRY_RUN=1.)
#   3. Post-guard: scan `git diff` for any path outside the sandbox and
#      `git checkout --` them away (i.e. restore tracked files, delete
#      untracked ones), then exit non-zero so the operator notices.
#   4. Record the adopted model ID and wall-clock duration to evaluation.md.
#
# Environment knobs (mainly for tests):
#   CODEX_DRY_RUN=1        skip the real codex-companion invocation
#   CODEX_MODEL=<id>       override the adopted model id (default: gpt-5.5-pro)
#   CODEX_FAKE_WRITES=...  semicolon-separated `kind:relpath` directives that
#                          simulate Codex output. `outside:<path>` writes a
#                          rogue file outside the sandbox; `inside:<tag>`
#                          touches a file inside the sandbox.

set -euo pipefail

# Resolve REPO_ROOT relative to this script's location so the harness works no
# matter what CWD the caller invokes it from. This is critical for Bats tests
# which copy the script into a disposable fake repo and call it from outside.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LONGRUN_REL="_longruns/2026-05-13_codex-build-agent-eval"
SANDBOX_REL="$LONGRUN_REL/sandbox"
EVAL_FILE="$REPO_ROOT/$LONGRUN_REL/evaluation.md"

log() {
  printf '[run-poc] %s\n' "$*"
}

# --- Pre-guard: worktree must be clean ---------------------------------------
if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
  echo "ERROR: working tree is dirty. Commit or stash changes first." >&2
  exit 1
fi

# --- Model ID resolution -----------------------------------------------------
CODEX_MODEL="${CODEX_MODEL:-gpt-5.5-pro}"
log "model = $CODEX_MODEL"

# --- Run (or simulate) Codex -------------------------------------------------
START_EPOCH=$(date +%s)

if [ "${CODEX_DRY_RUN:-0}" = "1" ]; then
  log "CODEX_DRY_RUN=1 -> skip real codex-companion call"

  # Optional: simulate Codex output via CODEX_FAKE_WRITES so that the
  # post-guard can be exercised by Bats without a real Codex.
  if [ -n "${CODEX_FAKE_WRITES:-}" ]; then
    IFS=';' read -r -a fake_writes <<<"$CODEX_FAKE_WRITES"
    for entry in "${fake_writes[@]}"; do
      [ -z "$entry" ] && continue
      kind="${entry%%:*}"
      rel="${entry#*:}"
      case "$kind" in
        outside)
          mkdir -p "$REPO_ROOT/$(dirname "$rel")"
          printf 'rogue Codex write\n' > "$REPO_ROOT/$rel"
          ;;
        inside)
          # Mutate a file we know exists inside the sandbox.
          printf '// touched: %s\n' "$rel" >> "$REPO_ROOT/$SANDBOX_REL/src/greet.ts"
          ;;
        *)
          log "unknown CODEX_FAKE_WRITES kind: $kind"
          ;;
      esac
    done
  fi
else
  # Real path. We do NOT execute Codex from this PoC scaffolding task; the
  # orchestrator task (#6) will plug in the actual invocation. Keep the
  # command line documented here so the diff during #6 is minimal.
  log "(real Codex call deferred to Task #6 / orchestrator)"
  # node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --write \
  #   -m "$CODEX_MODEL" \
  #   "$(cat "$REPO_ROOT/$LONGRUN_REL/prompts.md")"
fi

END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

# --- Post-guard: detect sandbox-outside writes -------------------------------
TRACKED_DIFF=$(git -C "$REPO_ROOT" diff --name-only HEAD || true)
UNTRACKED=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard || true)
ALL_CHANGED=$(printf '%s\n%s\n' "$TRACKED_DIFF" "$UNTRACKED" | sed '/^$/d' | sort -u)

# Allowed: anything under SANDBOX_REL, plus evaluation.md itself (this script
# writes to it after the guard).
OUTSIDE=$(printf '%s\n' "$ALL_CHANGED" \
  | grep -v "^$SANDBOX_REL/" \
  | grep -v "^$LONGRUN_REL/evaluation.md$" \
  || true)

if [ -n "$OUTSIDE" ]; then
  echo "ERROR: sandbox 外への書き込みを検出: $OUTSIDE" >&2
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if git -C "$REPO_ROOT" ls-files --error-unmatch "$path" >/dev/null 2>&1; then
      git -C "$REPO_ROOT" checkout -- "$path" || true
    else
      # Untracked: remove outright (the spec says "破棄").
      rm -f "$REPO_ROOT/$path" || true
    fi
  done <<<"$OUTSIDE"
  exit 1
fi

# --- Record results in evaluation.md ----------------------------------------
if [ -f "$EVAL_FILE" ]; then
  tmp="$(mktemp)"
  awk -v model="$CODEX_MODEL" -v dur="${DURATION}s" '
    { line = $0 }
    line ~ /^- Codex model:/  { line = "- Codex model: " model }
    line ~ /^- Codex wall-clock:/ { line = "- Codex wall-clock: " dur }
    { print line }
  ' "$EVAL_FILE" > "$tmp"
  mv "$tmp" "$EVAL_FILE"
fi

log "guards passed (model=$CODEX_MODEL, duration=${DURATION}s)"
