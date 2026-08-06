# Proposal: pr-review-gate-review-weight-triage

## Why

現行の pr-review-gate は、変更の中身によらず**全 PR に Codex CLI レビューを既定**にしている（手順2の優先順表）。
Codex を既定にした理由（実装者と別モデル系列で独立性が上がる・Claude の 5h/7d 枠を消費しない）は
今も有効だが、**待ち時間のコストが変更の重さに比例していない**。

2026-08-06 に flatmate で観測した実測:

| 試行 | 結果 |
|---|---|
| 1 | 10 分でタイムアウト |
| 2 | 変更内容（セキュリティ形状のテストコード）を理由に実行拒否 |
| 3 | 成功。所要 **14 分** |

3 回中 1 回しか成果が出ず、成功しても 14 分かかる。ドキュメントの誤字修正や数行の直しに
毎回この待ち時間を払う価値はない一方、レビューを丸ごと省くと fail-closed のゲートが緩む。

同じ問題は github-issue スキルが Step B（仕様化要否）で既に解いている ——
「**判定材料を機械的に取り、条件を満たしたときだけ軽い側へ倒し、迷ったら重い側（既定）に倒す**」。
レビューの重さも同じ型で判定する。

## What Changes

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の手順2 冒頭に **レビュー重量判定（2-0）** を追加する
  - 判定材料は機械的に取る: `gh pr diff $N --name-only` と diff の変更行数
  - **light の条件**（(a)(b) のいずれか一方をすべて満たす）:
    - (a) 変更ファイルがすべて `*.md` で、かつ**エージェントの行動を定義するファイルを含まない**
      （`CLAUDE.md` / `AGENTS.md`・`.claude/` 配下・`.github/workflows/`・スキル/コマンド/エージェント定義・憲法 doc）
    - (b) 合計変更 30 行以下で、diff を読んだ結果**挙動を変えない**と判断できる（コメント・typo・文言・テストデータのみ）
  - **既定は full**。迷ったら full に倒す（fail-closed）。「判断がつかない」は light の理由にならない
  - **light で変わるのはレビュー実行者だけ**（最初から Task サブエージェント、Codex 呼び出しを省く）。
    リスク宣言・動作確認の証拠・HEAD SHA 照合・合格前の API 実測・収束ルールは一切免除しない
  - 判定結果と理由を **PR コメントに1行残す**（事後監査可能にする）
- 手順2 の優先順表の「使う条件」を light / full で書き分け、
  **事前判定（2-0）と障害時フォールバック（Codex が使えない）の役割の違い**を明記する
  （既存のフォールバック記述は削らない）
- スキル frontmatter の version を 1.0.0 → 1.1.0、`plugin.json` と `marketplace.json` の
  dev-workflow version を 1.7.0 → 1.8.0 に bump（プラグインキャッシュはバージョン単位のため、
  上げないと他プロジェクトに反映されない）
- bats テストを `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に追加

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: レビュー実行者の選び方に「変更内容からの事前判定（light / full）」を追加する。
  通過の必須3点・fail-closed の判定順序・収束ルールは変更しない

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（手順2 に追記、frontmatter version bump）
- `plugins/dev-workflow/.claude-plugin/plugin.json`（version 1.7.0 → 1.8.0）
- `.claude-plugin/marketplace.json`（dev-workflow entry の version 同期。整合ガード S131/S132 の対象）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（テスト追加）
- 運用への影響: light と判定された PR ではレビューの所要時間が Codex 待ち（実測 10〜14 分）ぶん短縮される。
  full の PR の手順は現行と完全に同一
