# Backlog

未着手 / 優先度低のタスク置き場。openspec change にするほど確定していないものや、まとめて作業したいものを溜める。

`/longrun:feedback` の Tier 3（new change）もここに記録される。

---

## Phase 2: Codex Builder Integration（次セッション着手予定）

Phase 1 PoC（`_longruns/2026-05-13_codex-build-agent-eval/`）の Conditional Go 判定を踏まえ、`longrun-builder-codex` Agent 新設 + orchestrator 分岐の本実装。

**起点**: 次セッションで以下を実行
```
/longrun:plan _longruns/_archive/2026-05-13_codex-build-agent-eval/phase2-draft.md
```
（Phase 1 archive 後のパス。archive 前なら `_longruns/2026-05-13_codex-build-agent-eval/phase2-draft.md`）

**主要内容** (詳細は phase2-draft.md):
- change-1: Codex commit を親 repo に乗せる方式（案 A/B/C から選択） — **★最重要**
- change-2: prompt 規律見直し（`--allow-empty` noop 撤廃）
- change-3: `longrun-builder-codex` Agent 新設
- change-4: orchestrator 分岐ロジック
- change-5: Codex vs Opus 実時間比較ハーネス

**Phase 1 carry-over リスク 9 件**:
- 必須 4 件: タイムアウト / 部分成功ロールバック / quota 判別 / NW vs 認証
- ★最重要 1 件: gitmeta 統合方式
- stretch 4 件: fidelity drift / empty-test anti-pattern / `~/.codex/` 排他 / fidelity スコープ

---

## Skill 命名規則リファクタリング

`CONTRIBUTING.md` の「命名規則（Skill / Agent / Command）」セクションに従い、`-er` / `-or` 終わりの Skill を名詞形にリネームする。

### 背景

Claude Code では Skill / Agent / Command が同じディスカバリカタログに混在表示されるが、現状は両者とも `-er` / `-or` 終わりが多く、名前から種別を判断できない。実際 `longrun-orchestrator` を Skill tool で呼ぼうとして `disable-model-invocation` エラーになるバグが発生した（2026-05-07 修正済み、コミット `89f2181`）。

### 消化済み

- `longrun-orchestrator`（命名規則の発端）→ **change-2 (workflow-exec, longrun v6.0.0) で消化済み**。リネームではなく**スキル解体**で解消した。Workflow ツール載せ替えにより orchestrator スキル層そのものが不要になり、`plugins/longrun/skills/longrun-orchestrator/` を削除、生成ロジックは exec コマンド + 同梱テンプレート（`templates/workflow/`）へ移管。

### 対象（Skill 名 = `-er` / `-or` 終わり）

| 現在名 | 提案リネーム | プラグイン | 備考 |
|---|---|---|---|
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
- **優先度**: `longrun-orchestrator` は change-2 で消化済み。残りは順次。

### 関連

- 命名規則の定義: `CONTRIBUTING.md` の「命名規則（Skill / Agent / Command）」
- 発端バグ修正: コミット `89f2181` (`fix(longrun,lr): replace Skill-tool delegation with inline SKILL.md exec`)

---

## `longrun-pr-merge-sync` skill 候補 — キャンセル

**日付**: 2026-05-13
**状態**: 作成しない

### 経緯

worktree で作業 → push → GitHub PR → merge on GitHub → 親リポ main から後片付け、という Issue-Driven workflow 終端の skill として `longrun-pr-merge-sync`（仮称）が想定されていた。役割は「ローカル `main` を `origin/main` に pull → feature branch 削除 → worktree 撤去」。

### キャンセル理由

`wt-clean` との差分が実質「事前に `git pull origin <main>` するか否か」の 1 点だけで、責務分割するほどの差ではないと判明。`wt-clean` に Step 0「Remote 同期」フェーズを追加すれば同一フローで処理できる。

### 統合先

OpenSpec change `wt-clean-remote-sync`（2026-05-13）で `wt-clean` に統合済み。
- デフォルトで `git fetch` + `git pull --ff-only origin <main>` を実行
- `--no-sync` でオプトアウト可能
- `--keep` との併用も可
- 参照: `openspec/changes/wt-clean-remote-sync/proposal.md`

PR マージ後の片付けは `wt-clean`（または `wt-clean --keep`）を親リポ main から実行することで完結する。
