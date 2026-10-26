# Proposal

## Why

エピックの子の会話が大きくても、止まってから 60 分未満に返事が来ると同じ会話を読み直し続ける。#1323 後の時間による起動し直しに、会話量だけでも起動し直す条件を加え、使用量と長い会話での判断品質を改善する（#1150、親エピック #1325）。

## What Changes

- 子の会話量が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら、経過時間・`compact_boundary` の有無によらず起動し直して返事を送る。
- #1323 の「最後の assistant から 60 分以上なら、会話量・compact の有無によらず起動し直す」を残し、会話量の条件と OR で組み合わせる。
- `wait --resolve` の自動判定と `reply-after-idle.md` の子の表を同じ条件にする。会話量は既存の `subagent-context.sh --file` の `context_tokens` で測る。
- 既定値は #1046 の完了した再集計で維持された 150000 に揃える。150000 をキャッシュ有効中の最適値とする根拠は無いため、その限りも design に残す。
- 閾値境界・compact・計測失敗・従来の時間条件のテストと `plugins/dev-workflow/changes/1150.md` を実装工程で追加する。版は上げない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: `wait --resolve` の子の再開判定と、子の表を規定する既存の 2 要件を更新する。

## Impact

実装対象は `plugins/dev-workflow/scripts/epic-dispatch.sh`、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md`、`plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/changes/1150.md`。既存の `reply --relaunch` と停止の記録からの再開を使う。

単一の子の再開判定に閉じ、1 PR で完結する単一 change とする。#1324 のキャッシュ維持の声かけ・親の短い待ち直し、#1085 の CI 見張り再開、親の表・コンパクト閾値は対象外。この工程では OpenSpec の成果物だけを作る。
