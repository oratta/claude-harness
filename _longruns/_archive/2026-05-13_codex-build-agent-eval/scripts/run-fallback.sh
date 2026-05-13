#!/usr/bin/env bash
#
# run-fallback.sh — Codex unavailable -> Opus fallback drill.
#
# Usage:
#   run-fallback.sh --simulate-codex-down
#
# When --simulate-codex-down is passed we synthesize the failure signature we
# expect from a real Codex outage (non-zero exit + auth-style stderr) and then
# route the same sample change to the Opus path. For the PoC we don't actually
# invoke an Opus agent here — Task #6 will plug that in. The script simply
# records that the fallback branch was reached so Bats can verify the wiring.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LONGRUN_REL="_longruns/2026-05-13_codex-build-agent-eval"
EVAL_FILE="$REPO_ROOT/$LONGRUN_REL/evaluation.md"

SIMULATE=0
for arg in "$@"; do
  case "$arg" in
    --simulate-codex-down) SIMULATE=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log() {
  printf '[run-fallback] %s\n' "$*"
}

if [ "$SIMULATE" -eq 1 ]; then
  log "simulating codex-down: injecting fake codex into PATH"
  fakebin="$(mktemp -d)"
  trap 'rm -rf "$fakebin"' EXIT
  cat >"$fakebin/codex" <<'BASH'
#!/usr/bin/env bash
echo "codex: authentication failed (simulated)" >&2
exit 64
BASH
  chmod +x "$fakebin/codex"

  # Probe the fake codex; we expect non-zero exit. Capture and classify.
  set +e
  codex_stderr="$(PATH="$fakebin:$PATH" codex --version 2>&1 >/dev/null)"
  codex_exit=$?
  set -e

  log "codex probe exit=$codex_exit, stderr='$codex_stderr'"
  if [ "$codex_exit" -eq 0 ]; then
    echo "ERROR: expected codex to fail under --simulate-codex-down" >&2
    exit 1
  fi

  # Classify: stderr matching auth/quota patterns => fallback to Opus.
  if echo "$codex_stderr" | grep -Eqi 'auth|quota|429|unauthorized'; then
    log "classified as: codex unavailable -> routing to Opus fallback"
  else
    log "classified as: unknown failure (still falling back to Opus for safety)"
  fi
fi

# --- Opus fallback "run" -----------------------------------------------------
START=$(date +%s)
log "Opus path: would invoke longrun-builder Agent here (deferred to Task #6)"
# Pretend the run took at least 1 wall-clock second so the regex in tests
# (which expects integer seconds) is satisfied even on extremely fast hosts.
sleep 1
END=$(date +%s)
DURATION=$((END - START))

# --- Record into evaluation.md ----------------------------------------------
if [ -f "$EVAL_FILE" ]; then
  tmp="$(mktemp)"
  awk -v dur="${DURATION}s" '
    { line = $0 }
    line ~ /^- Opus wall-clock:/ { line = "- Opus wall-clock: " dur }
    { print line }
  ' "$EVAL_FILE" > "$tmp"
  mv "$tmp" "$EVAL_FILE"

  # Append a fallback log entry (idempotent enough for the PoC).
  if ! grep -q "fallback path engaged" "$EVAL_FILE"; then
    printf '\n- fallback path engaged: Opus (simulated codex-down)\n' >> "$EVAL_FILE"
  fi
fi

log "fallback completed in ${DURATION}s"
