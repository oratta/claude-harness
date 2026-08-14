# Tasks: pr-body-positioning-risk-weighting

## 1. 正本の改訂
- [x] 1.1 `plugins/loops/references/pr-body-format.md` の PR 型を改訂（位置づけ / 実装方針 / リスク（重い順） / 動作確認ポイント / 実装メモ）
- [x] 1.2 設計原則に「上から降りる」「リスクは重み付き」を追加し、翻訳例にリスクの重み付け例を追加
- [x] 1.3 軽量モードの必須 2 節を「位置づけ」＋「動作確認ポイント」に変更

## 2. 追従
- [x] 2.1 `plugins/dev-workflow/templates/auto-merge/.github/workflows/revert-pr.yml` の生成本文見出しを「位置づけ」に変更
- [x] 2.2 `.github/PULL_REQUEST_TEMPLATE.md` を新設
- [x] 2.3 loops 0.22.0 / dev-workflow 1.9.1 に bump（plugin.json + marketplace.json）

## 3. 検証
- [x] 3.1 `openspec validate pr-body-positioning-risk-weighting` が通る
- [x] 3.2 リポ内に旧セクション名（「壊れうるポイント」等）を PR 型として参照する箇所が残っていない（issue 型の「これで何が変わるか」は対象外）
