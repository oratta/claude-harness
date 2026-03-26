---
name: plan
description: 自律実行用のplan.mdを対話的に作成する
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

run-planner スキルを使用して、自律実行用の plan.md を対話的に作成してください。

## ⚠️ 必須: ディレクトリ構造ルール

**plan.md は必ずサブディレクトリに保存すること。`_runs/` 直下に置いてはならない。**

```
✅ 正しい: _runs/2026-03-26_feature-name/plan.md
❌ 間違い: _runs/plan.md
```

サブディレクトリ名: `YYYY-MM-DD_slug`（slug はbrain dumpから英語の短い要約）

## 実行手順

1. ユーザーの入力（$ARGUMENTS）をbrain dumpとして受け取る
2. プロジェクトのコンテキストを把握する（CLAUDE.md、package.json等）
3. brain dumpを分析し、Gap Analysisの結果を提示する
4. **マルチchange分解**: 要件を複数のOpenSpec changeに分解する案を提示
5. **スキル選定**: 各changeに必要なClaude Codeスキルを特定する
6. 発散リスクの高い論点から1問ずつ質問する（AskUserQuestion使用）
7. 十分な情報が集まったら plan.md を生成する
8. 日付付きサブディレクトリ `_runs/YYYY-MM-DD_slug/plan.md` に保存する
9. ユーザーにレビューを依頼する

完了後、`/run:exec` コマンドで自律実行を開始できることを案内してください。
