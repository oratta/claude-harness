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

Skill 命名規則リファクタリング（`-er` / `-or` 終わり違反の解消）は全消化済み: `longrun-orchestrator`（命名規則の発端）は change-2 (workflow-exec, longrun v6.0.0) でスキル解体により消化済み。残る対象7スキルは 2026-07-03 の change-6 (plugin-retirement) で所属プラグインごと削除されたため、リネームではなく削除により命名規則違反が解消された。

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

---

## loops プラグイン: 廃案分の将来候補（change-1 タスク 5.5 記録）

前版 plan（Loop Engineering コミュニティ解釈版）で設計したが、公式路線（ネイティブプリミティブの合成）への
方針転換で廃案にした要素。将来価値がありうるため記録する。実装は「必要になってから」。

- **レシピの機械検証（loop-audit 相当）**: `recipes/*.md` が固定見出し 7 項目と停止基準を持つことを bats/CI で機械検証する。
  現状は Markdown 見出し規約のみ（schema 強制なし）。件数が増えて手動 grep が辛くなったら着手。
- **レシピの schema 化**: `loop-definition.schema.json` によるレシピの構造化。公式は「ランタイムはネイティブ」路線のため
  宣言的ランタイムは作らないが、**検証専用**の schema（実行はしない）なら価値がありうる。
- **loop-cost 相当**: レシピ単位のトークン予算見積り・実測の突き合わせ。`references/cost-guardrails.md`（change-5）の定量化。
- **skill-eval / e2s-tune のループ化**: 「スキルを改善するループ」を将来のレシピ追加（recipe-miner の生成対象）で対応。
