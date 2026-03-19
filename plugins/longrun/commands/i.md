---
name: i
description: "[alias: instruction] ロングラン実行用のinstruction.mdを対話的に作成する"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

instruction-builder スキルを使用して、ロングラン実行用の instruction.md を対話的に作成してください。

**このコマンドは `/longrun:instruction` のエイリアスです。** 全く同じ動作をします。

## ⚠️ 必須: ディレクトリ構造ルール

**instruction.md は必ずサブディレクトリに保存すること。`_longrun/` 直下に置いてはならない。**

```
✅ 正しい: _longrun/2026-03-13_feature-name/instruction.md
❌ 間違い: _longrun/instruction.md
```

サブディレクトリ名: `YYYY-MM-DD_slug`（slug はbrain dumpから英語の短い要約）

## 実行手順

1. ユーザーの入力（$ARGUMENTS）をbrain dumpとして受け取る
2. プロジェクトのコンテキストを把握する（CLAUDE.md、package.json等）
3. brain dumpを分析し、Gap Analysisの結果を提示する
4. **マルチchange分解**: 要件を複数のOpenSpec changeに分解する案を提示
5. **スキル選定**: 各changeに必要なClaude Codeスキルを特定する
6. 発散リスクの高い論点から1問ずつ質問する（AskUserQuestion使用）
7. 十分な情報が集まったら instruction.md を生成する
8. 日付付きサブディレクトリ `_longrun/YYYY-MM-DD_slug/instruction.md` に保存する
9. ユーザーにレビューを依頼する

引数の解釈:
- ファイルパス: そのファイルをbrain dumpとして読み込む
- テキスト: それ自体をbrain dumpとして扱う
- 引数なし: ユーザーに「何を作りたいか教えてください」と聞く

完了後、`/longrun:exec` コマンドでロングラン実行を開始できることを案内してください。
