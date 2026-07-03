# llm-log-relocation Specification

## Purpose
TBD - created by archiving change plugin-retirement. Update Purpose after archive.
## Requirements
### Requirement: Evacuation MUST capture a pre-move snapshot before any mv begins

Before any file is moved out of the repository-root `LLM/` directory, the evacuation process SHALL capture a snapshot consisting of the file count and the full filename list of `LLM/*` as they exist at that moment. This snapshot MUST be persisted (e.g. recorded in `decisions.md` or a snapshot file under the longrun run directory) before the first `mv` command executes, and MUST be the sole baseline used by all later reconciliation.

#### Scenario: Snapshot recorded before the first move

- **WHEN** evacuation of the repository-root `LLM/` directory begins
- **THEN** a snapshot (file count and filename list) of `LLM/*` MUST be captured and persisted before any `mv` command runs, and this snapshot count MUST be the number referenced by the later reconciliation step

### Requirement: Evacuation MUST move, not delete, every snapshotted file

Every filename present in the pre-move snapshot SHALL end the evacuation process in exactly one of two states: successfully moved to `$LLM_LOG_DIR`, or left in place under repository-root `LLM/` as a documented collision-skip (see the collision requirement below). No snapshotted filename may be deleted outright, nor may it end up absent from both locations.

#### Scenario: Every snapshotted filename is accounted for

- **WHEN** evacuation completes
- **THEN** each filename recorded in the pre-move snapshot MUST either exist under `$LLM_LOG_DIR` (moved) or remain in repository-root `LLM/` as a collision-skip; a snapshotted filename missing from both locations MUST be treated as a evacuation failure and MUST block completion

### Requirement: Same-name collisions at the destination MUST NOT be overwritten

When a snapshotted filename already exists under `$LLM_LOG_DIR`, the evacuation process SHALL skip moving that specific file (the destination file remains untouched, the source file remains in repository-root `LLM/`) rather than overwriting the destination. Every skipped filename MUST be recorded in a collision list.

#### Scenario: Collision detected and skipped

- **WHEN** a snapshotted filename already exists under `$LLM_LOG_DIR`
- **THEN** the `mv` for that file MUST be skipped, the destination file MUST remain byte-identical to its pre-evacuation state, the source file MUST remain in repository-root `LLM/`, and the filename MUST be added to a collision list

### Requirement: Post-move reconciliation MUST use the pre-move snapshot as its baseline, not a live re-count

Reconciliation after the `mv` operations complete SHALL verify that `moved-file count + collision-skip count == pre-move snapshot count`. If repository-root `LLM/` contains any file not present in the pre-move snapshot (which can occur if the `auto-save.py` Stop hook writes a new file during the same session as the evacuation), that file MUST be excluded from this arithmetic and instead attributed to hook activity during evacuation.

#### Scenario: Snapshot-based arithmetic passes despite hook activity

- **WHEN** reconciliation runs after all `mv` operations complete, and repository-root `LLM/` contains a file that was not part of the pre-move snapshot
- **THEN** the reconciliation arithmetic (moved + collision-skip == snapshot count) MUST still hold using only snapshotted filenames, and the extra post-snapshot file MUST be excluded from the count and instead logged separately as hook-generated during evacuation

#### Scenario: Reconciliation fails loudly on genuine loss

- **WHEN** a filename present in the pre-move snapshot is absent from both `$LLM_LOG_DIR` and repository-root `LLM/`, and it was not recorded as a collision-skip
- **THEN** reconciliation MUST report this as a failure and evacuation MUST NOT be considered complete until resolved

### Requirement: Evacuation results MUST be recorded in `post-merge-steps.md`

The evacuation process SHALL write its results into `{longrun-dir}/post-merge-steps.md`: the full collision list (or an explicit statement that zero collisions occurred), and any post-snapshot new files attributed to hook activity (or an explicit statement that none occurred).

#### Scenario: post-merge-steps.md documents the evacuation outcome

- **WHEN** evacuation and reconciliation finish
- **THEN** `{longrun-dir}/post-merge-steps.md` MUST list every collision-skipped filename (or state that zero collisions occurred) and every post-snapshot new file attributed to `auto-save.py` hook activity (or state that none occurred)

### Requirement: Final state of repository-root `LLM/` MUST contain only unresolved collisions

After evacuation completes, repository-root `LLM/` SHALL contain nothing except the files that were skipped due to a naming collision. If there were zero collisions, the directory MUST be empty or non-existent.

#### Scenario: Zero-collision case leaves LLM/ empty or absent

- **WHEN** evacuation completes with zero recorded collisions
- **THEN** repository-root `LLM/` MUST be empty or non-existent

#### Scenario: Collision case leaves only the collided files

- **WHEN** evacuation completes with one or more recorded collisions
- **THEN** repository-root `LLM/` MUST contain exactly the collision-skipped filenames (no successfully-moved file may remain, and no file absent from the collision list may remain)

