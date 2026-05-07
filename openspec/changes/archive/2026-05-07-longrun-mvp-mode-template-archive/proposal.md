## Why

change-A で MVP モード用 subagent 3 種を、change-B で `longrun-plan` SKILL.md の `--mode=mvp` 分岐ロジックを追加した。SKILL.md は既に `templates/plan-template-mvp.md` への参照を持つが、テンプレ実体はまだ存在せず、また MVP モードで生成された plan.md を archive するパス（OpenSpec change 生成スキップ）も実装されていない。

本 change はこの「実体不在」の最終ピースを埋め、`/longrun:plan --mode=mvp` から `/longrun:archive` までの MVP フローを end-to-end で動作可能にする。具体的には軽量テンプレ本体の作成、archive コマンドへの MVP モード分岐追加、plugin.json と SKILL.md frontmatter の同期バージョン bump、README 更新を行う。

最重要制約はフルモードへの regression を入れないこと。archive 側の分岐は `<!-- mvp-mode -->` マーカー検知時のみ動作し、マーカーなしの既存 plan.md に対しては従来通り OpenSpec change の自動 archive を実行する。

## What Changes

- `plugins/longrun/templates/plan-template-mvp.md` を新規作成。フル版 `plan-template.md` から派生し、Build Contract / TDD / Verifier 関連セクション（Changes 分解の自律実行向け要素 / 受け入れ条件のうち TDD・ビルド関連の自律実行用文言）を除外した軽量版とする。先頭にマーカーコメント `<!-- mvp-mode -->` と「フルテンプレからの派生／共通セクション同時更新義務」を示す HTML コメントを必ず埋め込む（divergence 防止）。
- `plugins/longrun/commands/archive.md` を更新。手順 1 と 2 の間に「MVP モード判定」ステップを挿入し、対象ランディレクトリの `plan.md` 先頭に `<!-- mvp-mode -->` マーカーがある場合は手順 3（OpenSpec change の archive）をスキップして手順 4（ランディレクトリの archive）と手順 5〜7（クリーンアップ・コミット・報告）のみ実行するパスを定義する。マーカーなしの場合は既存挙動を維持する。
- `plugins/longrun/.claude-plugin/plugin.json` の version を minor bump し（プラグインキャッシュ無効化のため）、`plugins/longrun/skills/longrun-plan/SKILL.md` の frontmatter `version` も同じ値に揃える（plan.md 受け入れ条件 #10「両方を同時に bump」を満たす）。
- `plugins/longrun/README.md` に MVP モードの使い方セクション（起動方法・フルモードとの違い・適用シナリオ）を追記する。

## Capabilities

### New Capabilities
（なし。既存 capability への追加で十分）

### Modified Capabilities
- `longrun-plan-skill`: 既存の Skill 命名規則 / 起動プロトコル / orchestrator バイアスガード / バージョンバンプ要件 / change-B で追加された MVP モード分岐要件には触れず、新たに「MVP 軽量テンプレートの存在と派生防止コメント」「archive コマンドの MVP モード判定分岐」「plugin.json と SKILL.md frontmatter の同期バンプ」を要件として追加する。

## Impact

- **新規ファイル**:
  - `plugins/longrun/templates/plan-template-mvp.md`
  - `openspec/changes/longrun-mvp-mode-template-archive/proposal.md`
  - `openspec/changes/longrun-mvp-mode-template-archive/specs/longrun-plan-skill/spec.md`
  - `openspec/changes/longrun-mvp-mode-template-archive/tasks.md`
- **変更ファイル**:
  - `plugins/longrun/commands/archive.md`（MVP モード分岐セクションを追記）
  - `plugins/longrun/.claude-plugin/plugin.json`（version bump）
  - `plugins/longrun/skills/longrun-plan/SKILL.md`（frontmatter version bump のみ）
  - `plugins/longrun/README.md`（MVP モードセクション追記）
- **依存**: change-A（subagent 3 種）、change-B（SKILL.md MVP 分岐）が完了済みであること
- **regression リスク**: archive コマンドのマーカー判定分岐により、フルモードの既存 plan.md（マーカーなし）に対しては従来通り OpenSpec change の archive が走ることを spec で保証する。テンプレ追加は新規ファイル作成のみで既存テンプレに変更を加えない。
- **version bump の取り扱い**: 当初 plan.md は 4.2.0 → 4.3.0 を想定していたが、`plugin.json` は v5.0 / v5.1 のリネーム作業で既に 5.1.0 まで進んでいた。downgrade を避けるため、本 change では両者を一致させる minor bump を行う（決定の詳細は `_longruns/2026-05-07_longrun-plan-mvp-mode/decisions.md` D5 を参照）。
