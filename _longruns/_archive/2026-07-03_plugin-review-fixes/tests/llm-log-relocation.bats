#!/usr/bin/env bats
#
# Tests for change-6 (plugin-retirement), capability: llm-log-relocation
# spec: openspec/changes/plugin-retirement/specs/llm-log-relocation/spec.md (S1-S8)
#
# These tests exercise the reusable evacuation script against throwaway
# temp directories (never the real repository-root LLM/ or real
# $LLM_LOG_DIR), so they are safe to run repeatedly and do not depend on
# hook timing in the real session.

setup() {
  RUN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${RUN_DIR}/scripts/evacuate-llm-log.sh"
  WORK="$(mktemp -d)"
  SRC="${WORK}/LLM"
  DEST="${WORK}/vault-llm"
  SNAPSHOT="${WORK}/snapshot.txt"
  REPORT="${WORK}/report.txt"
  mkdir -p "$SRC" "$DEST"
}

teardown() {
  rm -rf "$WORK"
}

# --- S1: Snapshot recorded before the first move ---

@test "S1: snapshot subcommand persists file count and filenames before any mv" {
  echo "a" > "${SRC}/one.md"
  echo "b" > "${SRC}/two.md"

  run "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"
  [ "$status" -eq 0 ]
  [ -f "$SNAPSHOT" ]

  # snapshot file must record the count and both filenames
  head -1 "$SNAPSHOT" | grep -q '^2$'
  grep -qx "one.md" "$SNAPSHOT"
  grep -qx "two.md" "$SNAPSHOT"

  # no mv must have happened yet (files still in SRC, none in DEST)
  [ -f "${SRC}/one.md" ]
  [ -f "${SRC}/two.md" ]
  [ -z "$(ls -A "$DEST")" ]
}

# --- S2: Every snapshotted filename is accounted for ---

@test "S2: after execute, every snapshotted filename is either moved or collision-skipped" {
  echo "a" > "${SRC}/one.md"
  echo "b" > "${SRC}/two.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -eq 0 ]

  [ -f "${DEST}/one.md" ]
  [ -f "${DEST}/two.md" ]
  [ ! -f "${SRC}/one.md" ]
  [ ! -f "${SRC}/two.md" ]
}

# --- S3: Collision detected and skipped ---

@test "S3: pre-existing destination file is not overwritten and source file is retained" {
  echo "source-version" > "${SRC}/dup.md"
  echo "dest-version-should-not-change" > "${DEST}/dup.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -eq 0 ]

  # destination untouched
  [ "$(cat "${DEST}/dup.md")" = "dest-version-should-not-change" ]
  # source retained
  [ -f "${SRC}/dup.md" ]
  [ "$(cat "${SRC}/dup.md")" = "source-version" ]
  # collision recorded in report
  grep -q "dup.md" "$REPORT"
}

# --- S4: Snapshot-based arithmetic passes despite hook activity ---

@test "S4: post-snapshot new file in source dir is excluded from reconciliation arithmetic and logged separately" {
  echo "a" > "${SRC}/one.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  # simulate the auto-save.py hook writing a brand new file AFTER the
  # snapshot was taken but before execute runs
  echo "hook-generated" > "${SRC}/hook-new.md"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -eq 0 ]

  # the snapshotted file moved fine
  [ -f "${DEST}/one.md" ]
  # the hook-generated file was NOT moved (never part of the snapshot)
  [ -f "${SRC}/hook-new.md" ]
  [ ! -f "${DEST}/hook-new.md" ]
  # it must be reported separately as hook-attributed, not as a failure
  grep -q "hook-new.md" "$REPORT"
  grep -qi "hook" "$REPORT"
}

# --- S5: Reconciliation fails loudly on genuine loss ---

@test "S5: a snapshotted file missing from both source and dest (and not a collision) fails reconciliation" {
  echo "a" > "${SRC}/one.md"
  echo "b" > "${SRC}/vanishing.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  # simulate genuine loss: file disappears between snapshot and execute
  # (e.g. externally deleted) without being a collision-skip
  rm "${SRC}/vanishing.md"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -ne 0 ]
  grep -qi "vanishing.md" "$REPORT"
}

# --- S6: post-merge-steps.md documents the evacuation outcome (report content shape) ---

@test "S6: report records zero-collision and zero-hook-file cases explicitly" {
  echo "a" > "${SRC}/one.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -eq 0 ]

  grep -qi "collision" "$REPORT"
  grep -qi "hook" "$REPORT"
}

# --- S7: Zero-collision case leaves LLM/ empty or absent ---

@test "S7: zero-collision evacuation leaves source dir empty" {
  echo "a" > "${SRC}/one.md"
  echo "b" > "${SRC}/two.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -eq 0 ]

  [ -z "$(ls -A "$SRC")" ]
}

# --- S8: Collision case leaves only the collided files ---

@test "S8: collision evacuation leaves only the collided filename in source dir" {
  echo "a" > "${SRC}/one.md"
  echo "source-version" > "${SRC}/dup.md"
  echo "dest-version" > "${DEST}/dup.md"
  "$SCRIPT" snapshot "$SRC" "$SNAPSHOT"

  run "$SCRIPT" execute "$SRC" "$DEST" "$SNAPSHOT" "$REPORT"
  [ "$status" -eq 0 ]

  remaining="$(ls -A "$SRC")"
  [ "$remaining" = "dup.md" ]
}
