## Context

The current first-pass reviewer contract says to enumerate all applicable findings, but it does not force the reviewer to identify what the PR newly decides before looking for defects. The fixed finding format also constrains `場所` to a diff-overlapping range, so it cannot naturally express a conflict between new text and unchanged text elsewhere in the repository.

The triage work merged before this change established a revision-safe inventory convention for G: a full SHA, a `git grep ... <rev> -- <path>` command, and a table of every hit. Issue #355 requires the new first-pass reconciliation table and triage's first-stage set comparison to share the stricter repository-wide form defined by this change, while using G only for mechanical comparison rather than another semantic review.

## Goals / Non-Goals

**Goals:**

- Make a first-pass reviewer identify every explicit rule, judgment, and term introduced by the PR before writing findings.
- Make repository-wide consistency checking and diff-hunk coverage visible and mechanically auditable by G.
- Detect omitted search hits without making G reread and reinterpret the PR.
- Preserve a bounded review loop across fresh reviewer threads by requesting only missing inventory material once, then stopping without another reviewer if a residual remains.
- Record why later-round findings escaped the first pass under the four categories named in issue #355.

**Non-Goals:**

- Guarantee that the reviewer discovers a change the reviewer omitted from the change inventory itself.
- Replace the existing fixed finding format, blocking-finding judgment, triage table, or two-round convergence rules.
- Run several independent reviewers and aggregate their results.
- Change specification review (R1), which is tracked separately.

## Decisions

**The three pre-finding artifacts live in the existing reviewer instruction block and are emitted in a fixed order.** The reviewer first emits `変更点の一覧`, then one or more `照合表`, then `ハンク被覆`, self-checks those artifacts, and only then emits findings. This keeps a single reviewer contract for Codex and delegated reviewer paths and makes “inventory before findings” observable.

`変更点の一覧` assigns a stable ID to each new rule, judgment, or term, identifies the acceptance criterion it covers, and gives the search term used for reconciliation. G checks only that every acceptance criterion is mapped by at least one row; G does not decide whether the inventory is semantically complete.

**The first-pass reconciliation and triage step 3 share one base inventory contract.** The shared block has `修正前 SHA: <40桁>` (the fixed review HEAD for a first-pass review, or the HEAD immediately before W starts a step 3 correction), `検索コマンド: git grep -n <語の指定> <rev> -- .`, and the columns `| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |`. The first three columns are the hit-set identity consumed by the checker. The fourth column is deliberately use-specific: first-pass review uses `一致` or `食い違い: <finding ID>`; triage step 3 keeps `直した` or `該当しない: <理由>`.

The search root is the repository root and `-- .` covers every tracked path in the fixed revision, including unchanged files in other directories. A reviewer may not narrow the path or exclude a tracked path. Git metadata and untracked or ignored generated output are outside the revision tree and therefore outside the contract; there is no additional tracked-path exclusion list. G substitutes the fixed SHA for `<rev>`, reruns the command, and compares the complete hit set.

The new checker implements the common first-stage operation for both consumers: validate the common metadata/columns and compare the fixed-revision search hits with all table rows regardless of the fourth-column value. Triage step 3 alone retains its second stage against post-fix HEAD, including matched text, multiplicity, and deleted-line checks. First-pass reconciliation compares one fixed SHA only and does not perform that post-fix stage.

`ハンク被覆` has one row per diff hunk and records either a finding ID or `問題なし`. Its hunk identity includes the file path and hunk header, which G can compare with the fixed PR diff without interpreting the code.

**Inconsistency findings may identify both sides of the inconsistency.** The fixed finding format keeps the ordinary `場所` contract, but when a finding reports that changed text conflicts with unchanged repository text it may include two locations, one of which may be outside the diff. Both locations remain bounded line ranges. This is the narrow exception needed to make a reconciliation finding actionable.

**G verifies sets mechanically and asks for only the missing material once.** The shared repository script compares the table's hit set with G's replayed grep hit set and reports missing or extra `file:line` entries. A matching set exits 0; any difference exits 1 and prints the difference. G also compares acceptance-criterion IDs with the change inventory and diff-hunk IDs with hunk coverage. If an initial comparison is incomplete, G returns `needs-reviewer` for an inventory supplement, not a new review. Its payload carries the fixed HEAD, the original three tables, the exact residual, and `補足済み回数: 0`.

The develop coordinator may satisfy that `needs-reviewer` through the fresh review thread required by the Codex adapter, but the thread receives the supplement payload and must fill only the named gaps for the same review; it must not restart the review or replace the original tables. G receives the supplemented tables with `補足済み回数: 1`. The count is payload state, so replacing G or the reviewer does not reset it.

If a Codex response uses its priority-shaped output and omits the three tables, the existing interpretation table treats the omitted artifacts as incomplete reviewer output and applies the same supplement path. If a difference remains with `補足済み回数: 1`, G records the residual and returns terminal Status `review-incomplete`. The coordinator does not launch another reviewer for that status, leaves `agent-review:pending`, reports the residual, and does not enter the pass path. `needs-reviewer` is therefore only a request below the limit; `review-incomplete` is the exhausted fail-closed outcome.

**Later-round findings carry one outcome category in G's result.** For round two and later, each new or unresolved finding is classified as exactly one of: `同じ文が複数か所`, `場合分けの漏れ`, `直したつもりで直っていない`, or `直しで新しく入った`. G records the category in its PR comment/return contract so the effectiveness of the first-pass inventory can be measured without changing the blocking decision.

## Risks / Trade-offs

- [The first-pass output and runtime increase] → Keep the artifacts tabular and reuse one reviewer invocation plus at most one targeted supplement; do not add independent review runs.
- [A poor search term can make an apparently complete reconciliation set too narrow] → Expose the exact replayable command and search term in the output, require repository-root `-- .`, and prohibit tracked-path exclusions. The guarantee remains limited to items listed in the change inventory, as stated in issue #355.
- [Markdown parsing can be brittle] → Give the tables fixed headings and columns, and cover matching, missing-hit, and malformed/incomplete cases with bats tests.
- [Forward references from reconciliation rows to findings can be awkward] → Use stable finding IDs; ordering requires the analysis artifacts to appear first, not that finding text be written before its identifier is known.
- [A single supplemental request may still leave gaps] → Fail closed with terminal `review-incomplete`; do not reuse `needs-reviewer`, because the coordinator would otherwise start another reviewer and reset the one-supplement limit.
