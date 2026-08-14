# Proposal: pr-body-positioning-risk-weighting

## Why

現行の PR 本文 5 セクション型（2026-07-28 導入）はオーナーのマージ判断に使われていない。オーナーからの実フィードバック（2026-08-13）は 3 点: (1)「壊れうるポイント」は起こりうる事象の羅列で、起きやすさと影響範囲が加味されていないため読む価値の判断ができない、(2) どういう方針で実装したのか（アプローチと捨てた代案）が書かれておらず diff を読む道しるべがない、(3)「なぜ変えるか」だけ書かれてもプロジェクトの中でのこの PR の位置づけが分からない — 承認者はプロジェクト全体像を頭に入れていない。結果として「よくわからずマージ/クローズ」が起きている。

## What Changes

- `plugins/loops/references/pr-body-format.md` の PR 5 セクション型を改訂:
  - 「これで何が変わるか」→「**位置づけ**」（プロダクトの目的 → この PR の担当範囲 → 起きる変化、の 3 行で上から降りる。翻訳の規律は 3 行目に適用）
  - 「良くなること / 悪くなりうること」を廃止（良くなること → 位置づけ 3 行目へ、悪くなりうること → リスクへ統合）
  - 「壊れうるポイント」→「**リスク（重い順）**」（起きうること / 起きやすさ(高中低+根拠) / 影響 / 戻し方 の 4 列表。重み付けのない羅列を禁止）
  - 「**実装方針**」を新設（アプローチ 1〜2 行＋捨てた代案と理由 1 行。設計判断の理由は実装メモから移動）
  - 「動作確認ポイント」「実装メモ」は維持（対応関係の記述を新セクション名に追従）
- 軽量モードの必須 2 節を「位置づけ」＋「動作確認ポイント」に変更（発動条件・理由行の義務は不変)
- issue 本文の型は**変更しない**（これで何が変わるか / やらないとどうなるか の 2 節先頭追加はそのまま）
- `plugins/dev-workflow/templates/auto-merge/.github/workflows/revert-pr.yml` の自動生成 PR 本文の見出しを新型に追従
- 本リポジトリに `.github/PULL_REQUEST_TEMPLATE.md` を新設（新型のテンプレート）
- plugin.json バージョン更新: loops 0.21.1 → 0.22.0、dev-workflow 1.9.0 → 1.9.1（marketplace.json も同期）

## Impact

- Affected specs: loops-pr-body-format
- Affected code: plugins/loops/references/pr-body-format.md, plugins/dev-workflow/templates/auto-merge/.github/workflows/revert-pr.yml, .github/PULL_REQUEST_TEMPLATE.md, 両 plugin.json, marketplace.json
- 各リポに配布済みの PULL_REQUEST_TEMPLATE.md（flatmate 等）と revert-pr.yml は各リポ側 PR で追従する（このリポの変更には含まれない）
