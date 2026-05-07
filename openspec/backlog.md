# Backlog

未着手 / 優先度低のタスク置き場。openspec change にするほど確定していないものや、まとめて作業したいものを溜める。

`/longrun:feedback` の Tier 3（new change）もここに記録される。

---

## Skill 命名規則リファクタリング

`CONTRIBUTING.md` の「命名規則（Skill / Agent / Command）」セクションに従い、`-er` / `-or` 終わりの Skill を名詞形にリネームする。

### 背景

Claude Code では Skill / Agent / Command が同じディスカバリカタログに混在表示されるが、現状は両者とも `-er` / `-or` 終わりが多く、名前から種別を判断できない。実際 `longrun-orchestrator` を Skill tool で呼ぼうとして `disable-model-invocation` エラーになるバグが発生した（2026-05-07 修正済み、コミット `89f2181`）。

### 対象（Skill 名 = `-er` / `-or` 終わり）

| 現在名 | 提案リネーム | プラグイン | 備考 |
|---|---|---|---|
| `longrun-orchestrator` | `longrun-orchestration` | longrun | 命名規則の発端 |
| `pre-task-orchestrator` | `pre-task-orchestration` | skill-aware-workflow | |
| `context-reader` | `context-loading` または `context-bootstrap` | obsidian-llm-session-rules | |
| `execution-tracker` | `execution-tracking` | skill-aware-workflow | |
| `session-logger` | `session-logging` または `session-recording` | obsidian-llm-session-rules | |
| `skill-finder` | `skill-discovery` | skill-aware-workflow | |
| `skill-proposer` | `skill-proposal` | skill-aware-workflow | |
| `task-analyzer` | `task-analysis` | skill-aware-workflow | |

### 各リネームで必要な作業

1. skill ディレクトリ名変更（`mv plugins/<plugin>/skills/<old>/ plugins/<plugin>/skills/<new>/`）
2. `SKILL.md` frontmatter `name:` を新名に
3. `plugins/<plugin>/.claude-plugin/plugin.json` の `skills` 配列パスを更新 + `version` bump
4. `.claude-plugin/marketplace.json` 該当プラグインの `version` を同期
5. 他 Skill / Command / Agent からの旧名参照を `grep -rn "<old>"` で全置換
6. アーカイブ済み openspec changes（`openspec/changes/archive/`）は触らない（履歴）
7. 別セッションで動作確認（特に Skill tool / Agent tool での起動テスト）

### 推奨進め方

- **プラグイン単位で 1 PR**: 影響範囲を限定。`skill-aware-workflow` は5個まとめて1PRでもOK
- **巨大 PR にしない**: レビュー負荷の観点
- **rename と同時に他のリファクタを混ぜない**: 純粋な rename で diff を読みやすく
- **優先度**: `longrun-orchestrator` → 既にユーザー文脈で問題発覚しているため最優先。他は順次。

### 関連

- 命名規則の定義: `CONTRIBUTING.md` の「命名規則（Skill / Agent / Command）」
- 発端バグ修正: コミット `89f2181` (`fix(longrun,lr): replace Skill-tool delegation with inline SKILL.md exec`)
