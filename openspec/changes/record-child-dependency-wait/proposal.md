# Proposal

## Why

依存待ちで正常に終了した子は `状態: 作業報告` を残すため、状態記録だけを読む親が通常の作業報告と区別できない。#1775 と #1744 の裁定に従い、まず子の生成側に構造化した依存待ち情報を追加し、後続の親側変更へ渡す契約を残す。

## What Changes

- `turn_state` に任意の boolean 項目 `dependency_wait` を追加する。検査済みの今回の終了発言が、既存の依存待ちの末尾形式と `状態: 作業報告` を満たすときだけ `true` を保存する。
- 通常の作業報告、引用・フェンス内の印、欠落・型不正の項目を依存待ちの根拠にしない。通常入力と Stop 差し戻しで旧状態と一緒に無効化し、既存の排他・世代照合を保つ。
- 子の依存待ち手順を新しい記録による受け渡しに合わせる。成功時の状態行は `作業報告` のままにする。
- 親の検知・依存照合・再起動は #1744 の範囲とし、変更前の親が新項目を無視して従来どおり動くことを確認する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: 終了状態の任意項目の型、生成条件、旧記録互換、通常入力と Stop 差し戻しによる無効化を定める。

## Impact

- 実装対象は `plugins/dev-workflow/scripts/epic-child-state.sh`、実フックの回帰テスト `plugins/dev-workflow/tests/epic-child-state.bats`、手順 `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`。
- schema は 1 のまま。`epic-dispatch.sh` と既存の親用の記録検査は変更しない。既存 `epic-dispatch.bats` を互換確認に使う。
- 単一 change とする。生成側の一つの capability に閉じた、同じ任意項目の型・保存・無効化の変更であり、独立して分割する設計判断はない。親の消費側は既に #1744 に分離されている。
- この工程は artifact 作成まで。実装は新規 R1 の APPROVE 後に行い、archive 済み change は書き換えない。
