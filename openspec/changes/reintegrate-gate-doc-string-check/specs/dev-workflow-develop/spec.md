## MODIFIED Requirements

### Requirement: 周回は前の段から引き継ぐ

G は `周回:` を前の段の Gate Result の値から引き継がなければならない（MUST）。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（MUST）。ただし前の Gate Result に行 `取り直し: 説明の整合（周に数えない）` がある failed のあとは増やさない（MUST。pr-review-gate の手順 4-2 の不合格はレビューの指摘の周ではない）。戻した指摘が順 3 だけの修正のあとは周を消費しない（`stages/triage.md` の既存規則のまま）。

#### Scenario: 再レビューの周

- **WHEN** 周回 1 で failed が返り、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ

#### Scenario: 説明の整合の取り直し

- **WHEN** 周回 2 の合格処理の G が取り直しの行を持つ failed を返し、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ
