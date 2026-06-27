# longrun-feedback-backlog-fallback

縮退 run における feedback Tier 3（new change）の記録先を `openspec/backlog.md` から `_longruns/<run>/backlog.md` にフォールバックする capability。

## ADDED Requirements

### Requirement: 縮退 run では Tier 3 を run ディレクトリの backlog に記録する

longrun-feedback（`/longrun:feedback` および orchestrator の Feedback フェーズ）は、対象 run に縮退マーカー（`_longruns/<run>/.degraded-mode`）が存在する場合、Tier 3 に分類されたアイテムを `openspec/backlog.md` ではなく `_longruns/<run>/backlog.md` に追記しなければならない（SHALL）。このとき `openspec/` ディレクトリを作成してはならない（MUST NOT）。記録フォーマットは通常モードの backlog エントリと同等とする（SHALL）。

#### Scenario: 縮退 run のフィードバックで Tier 3 が run 内 backlog に記録される

- **WHEN** 縮退 run の動作確認後、ユーザーが `/lr:f` でスコープ外の新規要件（例: 「通知機能も欲しい」）を含むフィードバックを伝える
- **THEN** そのアイテムは Tier 3 に分類され `_longruns/<run>/backlog.md` に追記され、分類結果の提示で記録先が `_longruns/<run>/backlog.md` であることが明示される。`openspec/backlog.md` は作成・変更されない

### Requirement: 通常 run の Tier 3 記録先は従来どおり openspec backlog である

縮退マーカーが存在しない通常 run では、Tier 3 アイテムは従来どおり `openspec/backlog.md` に記録されなければならない（SHALL）。フォールバック分岐の追加が通常 run の feedback 挙動を変えてはならない（MUST NOT）。

#### Scenario: 通常 run のフィードバックで Tier 3 が openspec backlog に記録される

- **WHEN** 通常モード（openspec あり）の run でユーザーが `/lr:f` でスコープ外の新規要件を含むフィードバックを伝える
- **THEN** そのアイテムは Tier 3 に分類され、従来どおり `openspec/backlog.md` に追記される
