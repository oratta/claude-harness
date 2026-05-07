## Why

`/longrun:plan` コマンド経由で `longrun-planner` を起動すると、Claude が `longrun-builder`/`longrun-reviewer`/`longrun-verifier` 等と同じ命名パターンに引っ張られて Agent として起動しようとし、`Agent type 'longrun:longrun-planner' not found` エラーで失敗するケースが繰り返し発生している。本体は Skill だが、名前と実態が一致していないことと、コマンドファイルの指示が曖昧なことが Agent 誤起動を誘発する根本原因である。

## What Changes

- **BREAKING**: `longrun-planner` Skill を `longrun-plan` にリネーム（命名規則: Skill は動詞・名詞、Agent は -er/-or で終わる役割名）
- `commands/plan.md` を `Skill tool` 経由で `longrun:longrun-plan` を呼び出すよう明示的に書き換え（Agent tool 禁止を明記）
- `longrun-orchestrator` Skill から `longrun-planner` を参照する箇所を新名称へ追従
- `README.md` の図とテキストを新命名規則に合わせて更新
- `lr/commands/p.md` の Skill 名参照を新名称に追従
- `plugin.json` のバージョンを 5.0.0 → 5.1.0 にバンプ（プラグインキャッシュ無効化のため必須）
- バイアス緩和: `longrun-orchestrator` Skill のレビュー受領段階に「reviewer の指摘は仮説として扱い、根拠なき指摘は採用しない」プロンプトを追加（self-preference bias と過剰受容バイアスの両方を緩和する目的）

## Capabilities

### New Capabilities

- `longrun-plan-skill`: 自律実行用 plan.md を対話的に作成する Skill の命名規則と起動プロトコル、ならびに orchestrator 側のレビュー受領時のバイアス緩和ルールを定義する。

### Modified Capabilities

なし（既存の longrun spec は本リポジトリに未登録のため、本変更は新規 capability として記録する）

## Impact

- 影響ファイル:
  - `plugins/longrun/skills/longrun-planner/` → `plugins/longrun/skills/longrun-plan/` に移動
  - `plugins/longrun/skills/longrun-plan/SKILL.md` (`name:` フィールド更新)
  - `plugins/longrun/skills/longrun-orchestrator/SKILL.md`（参照名追従＋バイアス緩和プロンプト追加）
  - `plugins/longrun/commands/plan.md`（Skill tool 明示）
  - `plugins/longrun/README.md`（命名・図の追従）
  - `plugins/longrun/.claude-plugin/plugin.json`（skills パス更新＋ version bump）
  - `plugins/lr/commands/p.md`（Skill 名追従）
- 影響利用者: `/longrun:plan` および `/lr:p` のすべてのユーザー
- マイグレーション: ユーザー側の操作変更は不要。プラグインキャッシュは version bump で自動再読み込みされる。途中状態の `_longruns/<date>_<slug>/` ディレクトリには影響しない。
- リスク: 旧 `longrun-planner` 名を参照する外部スクリプト・他プラグインがあれば壊れる（本リポジトリ内では grep 済み、外部は不明）。
