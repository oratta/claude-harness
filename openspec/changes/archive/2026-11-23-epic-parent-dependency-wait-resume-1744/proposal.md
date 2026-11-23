# Proposal

## Why

#1744 で親の `wait --watch-stopped` を子の状態記録だけで判断するようにした結果、停止対象が `parent` / `startup` の `主の返事待ち` に限られ、依存待ちで終わった子（成功時は `状態: 作業報告` で終わる）を親が受け取らず、依存が解けても起こし直さない退行が生じた（ゲート段 A の指摘 P3-F1）。決める役の裁定 https://github.com/oratta/claude-harness/issues/1744#issuecomment-7089341978 で、子の側の記録（Stop フックが `turn_state.dependency_wait: true` を保存する）を #1775 に切り出して main に入れた（PR #1780）。この change は、その記録を親の側で受け取り、既存の依存照合と再起動につなぐ。

## What Changes

- 親の停止対象を、有効な `parent` / `startup` の組で ①`主の返事待ち`、または ②`作業報告` かつ `turn_state.dependency_wait == true` に広げる。通常の作業報告・完了・owner・欠落・不正・世代やセッションの不一致は引き続き除外し、項目の欠落を依存待ちの証拠にしない
- ②の停止（以下、依存待ちの停止）は `stopped` と `pending-owner` の `pending` を通じて親の依存照合へ渡す。判断役・長い待ちの判断し直し・キャッシュ維持の声かけ・「問いではない」としての自動の `resumed` 戻しには渡さない。会話ログが読めなくても同じに扱う
- `pending-owner` は受領済みで有効な依存待ちの停止を、会話ログの読み取り結果によらず出す
- `reply --as parent` で受領済みの停止（`stop_turn` を持つ記録）を再開するときは、入口と起動部品を呼ぶ直前の 2 か所で、受領した組がまだ有効な停止であることを確かめ、違えば送信・端末終了・再起動をしない。明示的な reply が受領後の owner の入力や新世代を迂回する穴を塞ぐ
- 移行条件: `dependency_wait` の無い既存の作業報告を、親が会話ログやコメントから依存待ちに補ってはならない。更新済みの子フックがその終了状態を保存することを要件にし、その移行のために owner の子へ自動で入力しない
- 子の側の契約（`dependency_wait` の型・生成条件・無効化）は #1775 で main spec `dev-workflow-epic-state` に入っており、この change は前提として参照するだけで規定し直さない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 停止対象の例外（依存待ちの停止）、依存待ちの判断・判断し直し・声かけ・自動の戻しの抑止、`pending-owner` での復元、`reply --as parent` の再確認、移行条件、状態記録による判定の守備範囲を整合させる

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`: `WAIT_TURN_DEFS`（停止対象の述語）・`detect_stopped`・`wait_received`・`resolve_stopped`・`rejudge_changed`・`keepalive_child` の候補判定・`stop_to_resumed` の自動の戻し・`cmd_pending_owner`・`deliver_reply`
- `plugins/dev-workflow/tests/epic-dispatch.bats`（P3-F1 の再現テストを復旧テストに変える・依存待ちの回帰）、`plugins/dev-workflow/tests/epic-child-state.bats` と `plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats` の旧期待値の整合
- `plugins/dev-workflow/changes/1744.md`（変更の記録の追記）
- 子フック（`epic-child-state.sh`）と子の終了手順（`epic-child-stop.md`）は変えない（#1775 の範囲）。親向け手順書の一般の書き換えは #1760 の範囲で、戻さない
