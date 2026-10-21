## Why

待ち方の spec が、pr-review-gate のフォールバック条件を「未導入・サブスク切れ・タイムアウト」という旧表現で再掲している。pr-review-gate 手順 2-1 の不可判定は「実測したバイナリ無し・認証切れ・タイムアウト」に変わっており（PR #317）、条件名の再掲は現行と食い違う。参照文書側は同 PR で参照に置き換え済みで、spec 側が残っている。

## What Changes

- spec の該当要件から条件名の再掲をなくし、`skills/pr-review-gate/stages/review-run.md` 手順 2-1 のタイムアウト条件の定義を、この上限が担うと参照する形にする。

## Capabilities

### Modified Capabilities

- `dev-workflow-subagent-waiting`: 総待ち上限の要件の文言から旧フォールバック条件の再掲を除く（要件の意味は変えない）。

## Impact

- `openspec/specs/dev-workflow-subagent-waiting/spec.md` のみ。
