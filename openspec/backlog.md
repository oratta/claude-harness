# Backlog

未着手 / 優先度低のタスク置き場。openspec change にするほど確定していないものや、まとめて作業したいものを溜める。

フィードバックのうち即実行しない改善案（かつての Tier 3）もここに記録される。

---

## Phase 2: Codex Builder Integration — 対象消失

2026-08 の自律実行プラグインの解散（#205）で `longrun-builder-codex` と orchestrator 分岐の実装対象が無くなった。Codex を builder に使う構想は dev-workflow の Workflow 実行の型（`plugins/dev-workflow/references/workflow-execution.md`）で必要になったときに再起票する。

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

## loops プラグイン: 廃案分の将来候補 — 対象消失

レシピ集は 2026-08 の解散（#205）で削除。レシピの機械検証・schema 化・コスト見積りの候補は対象ごと消えた。

---

## proactive-routines（change-4）実装中に見つけた拡張候補 — 対象消失

routine 系レシピと feature-list.json は 2026-08 の解散（#205）で削除。外部状態は Workflow の `args` / return 値と `resumeFromRunId` で持つ（`plugins/dev-workflow/references/workflow-execution.md`）。
