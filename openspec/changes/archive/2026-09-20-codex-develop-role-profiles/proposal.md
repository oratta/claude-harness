## Why

Issue #321 の Codex develop は全役割に同じモデルを割り当てるため、判断を担う役と実作業を担う役の消費を分けられない。既存の品質工程を維持したまま名前付き設定を選択し、旧 pending の冪等性と #315 の継続復元を保つ必要がある。

## What Changes

- `/develop --executor codex --profile codex-standard|codex-economy` を追加し、役割別 executor/account/model/effort を init で固定する。任意の `--profile-file PATH` で同形式の設定を指定できる。
- worker の effort 対応と二段階検証を先に実装し、続いて develop の設定解決・pending 固定・retry・継続記録を接続する。単一 change・単一 PR とし、別の品質ループを作らない。
- 要求設定と観測した実効設定を区別して worker 公開結果と run 履歴に残す。
- 単一 account/model の旧 run/request と継続記録 v1 を維持し、profile run 用の継続記録 v2 を追加する。

## Capabilities

### New Capabilities

- `codex-role-profiles`: 名前付き設定、init スナップショット、役割別 pending 固定、共通入口と受け入れ検証。
- `manual-codex-develop`: main specs には未収録。既存 `changes/manual-codex-develop/specs/manual-codex-develop/spec.md` を継承し、単一 account 契約と retry 契約を設定セット対応へ置換する。

### Modified Capabilities

- `codex-worker`: effort の二段階検証と送信、要求/実効設定の観測記録を追加する。
- `codex-develop-continuation`: v1 の読み取り互換を保つ v2 と profile snapshot 照合を追加する。

## Impact

対象は `plugins/dev-workflow/` の worker/develop スクリプトと Python tests、bats ラッパー、`commands/develop.md`、`references/codex-develop.md`、`docs/codex-develop.md`、`scripts/CODEX-WORKER.md`、`references/model-tiers.md`、設定例、plugin manifest。実装時に既存 manual-codex-develop change の契約も同期する。

#320 の既存砂場契約は維持し再実装しない。Claude/Codex 混在実行、残量による自動配分 (#703)、消費集計 (#709)、永続 worker の steer/バーン接続は対象外。初回は全 entry の executor を codex に制限する。#251 の Claude 強制層は変更しない。仕様作成の段階では製品コード・既存仕様を編集しない。
