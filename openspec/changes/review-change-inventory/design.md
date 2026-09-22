## Context

The current first-pass reviewer contract says to enumerate all applicable findings, but it does not force the reviewer to identify what the PR newly decides before looking for defects. The fixed finding format also constrains `場所` to a diff-overlapping range, so it cannot naturally express a conflict between new text and unchanged text elsewhere in the repository.

The triage work merged before this change established a revision-safe inventory convention for G: a full SHA, a `git grep ... <rev> -- <path>` command, and a table of every hit. Issue #355 requires the new first-pass reconciliation table to align with that convention, while using G only for mechanical set comparison rather than another semantic review.

## Goals / Non-Goals

**Goals:**

- Make a first-pass reviewer identify every explicit rule, judgment, and term introduced by the PR before writing findings.
- Make repository-wide consistency checking and diff-hunk coverage visible and mechanically auditable by G.
- Detect omitted search hits without making G reread and reinterpret the PR.
- Preserve a bounded review loop by requesting only missing inventory material, at most once.
- Record why later-round findings escaped the first pass under the four categories named in issue #355.

**Non-Goals:**

- Guarantee that the reviewer discovers a change the reviewer omitted from the change inventory itself.
- Replace the existing fixed finding format, blocking-finding judgment, triage table, or two-round convergence rules.
- Run several independent reviewers and aggregate their results.
- Change specification review (R1), which is tracked separately.

## Decisions

**The three pre-finding artifacts live in the existing reviewer instruction block and are emitted in a fixed order.** The reviewer first emits `変更点の一覧`, then one or more `照合表`, then `ハンク被覆`, self-checks those artifacts, and only then emits findings. This keeps a single reviewer contract for Codex and delegated reviewer paths and makes “inventory before findings” observable.

`変更点の一覧` assigns a stable ID to each new rule, judgment, or term, identifies the acceptance criterion it covers, and gives the search term used for reconciliation. G checks only that every acceptance criterion is mapped by at least one row; G does not decide whether the inventory is semantically complete.

Each `照合表` is keyed by a change ID and follows the revision-safe shape established by the triage inventory: target HEAD, a replayable `git grep -n ... <rev> -- <path>` command, and rows containing file, line at target HEAD, matched text, and `一致` or `食い違い: <finding ID>`. G substitutes the fixed target HEAD for `<rev>`, reruns the command, and compares the complete hit set. This alignment deliberately reuses the existing table vocabulary instead of introducing a second inventory dialect.

`ハンク被覆` has one row per diff hunk and records either a finding ID or `問題なし`. Its hunk identity includes the file path and hunk header, which G can compare with the fixed PR diff without interpreting the code.

**Inconsistency findings may identify both sides of the inconsistency.** The fixed finding format keeps the ordinary `場所` contract, but when a finding reports that changed text conflicts with unchanged repository text it may include two locations, one of which may be outside the diff. Both locations remain bounded line ranges. This is the narrow exception needed to make a reconciliation finding actionable.

**G verifies sets mechanically and asks for only the missing material once.** A repository script compares the reviewer table's hit set with G's replayed grep hit set and reports missing or extra `file:line` entries. A matching set exits 0; any difference exits 1 and prints the difference. G also compares acceptance-criterion IDs with the change inventory and diff-hunk IDs with hunk coverage. If any comparison is incomplete, G requests only those missing rows or artifacts rather than rerunning the full review, and does so at most once.

If a Codex response uses its priority-shaped output and omits the three tables, the existing interpretation table treats the omitted artifacts as incomplete reviewer output and applies the same single supplemental request. If material differences remain after that request, G records the remaining difference and returns `needs-reviewer` without entering the pass path. This fail-closed outcome is the only behavior supplied by this design that the issue did not state explicitly; treating an unverified inventory as complete would contradict the promised repository-wide coverage.

**Later-round findings carry one outcome category in G's result.** For round two and later, each new or unresolved finding is classified as exactly one of: `同じ文が複数か所`, `場合分けの漏れ`, `直したつもりで直っていない`, or `直しで新しく入った`. G records the category in its PR comment/return contract so the effectiveness of the first-pass inventory can be measured without changing the blocking decision.

## Risks / Trade-offs

- [The first-pass output and runtime increase] → Keep the artifacts tabular and reuse one reviewer invocation plus at most one targeted supplement; do not add independent review runs.
- [A poor search term can make an apparently complete reconciliation set too narrow] → Expose the exact replayable command and search term in the output. The guarantee remains limited to items listed in the change inventory, as stated in issue #355.
- [Markdown parsing can be brittle] → Give the tables fixed headings and columns, and cover matching, missing-hit, and malformed/incomplete cases with bats tests.
- [Forward references from reconciliation rows to findings can be awkward] → Use stable finding IDs; ordering requires the analysis artifacts to appear first, not that finding text be written before its identifier is known.
- [A single supplemental request may still leave gaps] → Fail closed and return `needs-reviewer` with the residual difference rather than silently treating coverage as complete.
