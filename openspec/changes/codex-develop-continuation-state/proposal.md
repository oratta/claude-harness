## Why

Codex executor の初回依頼で確定した executor・account・model・run-dir が会話継続時に失われ、追加依頼が Claude 経路へ誤って落ちる。継続時にも同じ担当へ委譲し、設定を復元できない場合は安全に停止するため、develop の記録先を用いた継続状態の復元を追加する。

## What Changes

- 初回に確定した Codex 委譲設定を issue または Draft PR の機械可読な継続記録として保存する。
- 引数なしの追加依頼では記録先から executor・account・model・run-dir（および worker-state）を復元し、同じ run に委譲する。
- 記録が欠落・不一致・曖昧な場合は Claude 実行へフォールバックせず、指定の再入力を求めて停止する。
- 追加依頼、レビュー、修正でも既存 develop の工程順・仕様要否・レビュー条件を維持し、Codex 専用ゲートを追加しない。
- 設定復元、復元不能時の停止、追加依頼の委譲先固定を回帰テストし、追加依頼を含む公開 PR finish/G 完走の実測記録を残す。

## Capabilities

### New Capabilities
- `codex-develop-continuation`: 記録先から Codex develop の継続委譲設定を復元し、安全に追加依頼を委譲する能力。

### Modified Capabilities
<!-- 既存 capability の要件本文は変更せず、新しい継続 capability として契約化する。 -->

## Impact

`plugins/dev-workflow/commands/develop.md`、`plugins/dev-workflow/references/codex-develop.md`、`plugins/dev-workflow/scripts/codex-develop.py` と関連テスト・ドキュメントに影響する。GitHub issue/Draft PR コメントを記録・復元の境界として使うが、GitHub 操作は本体の代理操作範囲に残す。既存の `manual-codex-develop` の transport 契約、89764a8 で撤去された独自品質ゲート、通常 develop の工程管理は変更しない。
