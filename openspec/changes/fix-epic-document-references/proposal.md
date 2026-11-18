# Proposal

## Why

エピック手順書を場面別に分割した後、旧い相対参照や説明の欠落が残り、利用者と保守者が正本へたどれない。#1693 の指摘を、親エピック #1682 が定めた「動きを変えない」範囲で修正する。

## What Changes

- 時間分類は `reply-after-idle.md`「親への適用」、報告形式は `epic-loop.md`「主への報告」、マージ待ちは `epic-merge-wait.md`「マージ待ちの子」をファイル名つきで指す。
- `epic-subagent.md` に旧表の利用条件・本体 worktree の片付けに関する説明を戻し、`epic.md` の「両経路」を具体名にする。
- 指定されたテストのコメントと `docs/public-private-split.md` の現行の説明を移動先に合わせる。参照整合の回帰テストを書く。
- `reply-after-idle.md` から移った指摘文は、本体の判断に従い `epic-keepalive-watch.md:9` で直し、`reply-after-idle.md`「そのまま送るか、起動し直すか（子）」を指す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 既存の「エピックの入口は読み手と場面ごとに読むものを案内する」に、分割後の手順書・指定された参照元が正本へ案内する条件を明記する。実行時の条件・権限・経路は変えない。

## Impact

実装見積りは既存8ファイル。`plugins/dev-workflow/skills/develop/references/` の `epic-loop.md`・`epic-stop.md`・`epic-subagent.md`・`epic.md`・`epic-keepalive-watch.md`、`plugins/dev-workflow/tests/epic-dispatch.bats`・`parent-merge.bats`、`docs/public-private-split.md` に限定する。

単一の参照整合の変更として1 PRで扱う。8ファイル > 5 の規模超過は本体が確認し、同じ受け入れ条件の参照修正として分割しないと判断済み（#1693 の issuecomment-6993166891）。既存の場面別バイト予算・読込集合は維持し、予算超過を予算値の引き上げで解決しない。

`SKILL.md` 本体・`pr-review-gate/` 本文・`roles/gate-runner.md` 本文・`epic-dispatch.sh` 冒頭・`pass.md`・他の並行 issue の箇所は対象外。依存追加・API変更・公開版分類の変更は無い。
