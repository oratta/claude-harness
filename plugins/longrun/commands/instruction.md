---
name: instruction
description: ロングラン実行用のinstruction.mdを対話的に作成する
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

instruction-builder スキルを使用して、ロングラン実行用の instruction.md を対話的に作成してください。

## 実行手順

1. ユーザーの入力（$ARGUMENTS）をbrain dumpとして受け取る
2. プロジェクトのコンテキストを把握する（CLAUDE.md、package.json等）
3. brain dumpを分析し、Gap Analysisの結果を提示する
4. 発散リスクの高い論点から1問ずつ質問する（AskUserQuestion使用）
5. 十分な情報が集まったら instruction.md を生成する
6. 日付付きサブディレクトリ `_longrun/YYYY-MM-DD_slug/instruction.md` に保存する
   - slug はbrain dumpから英語の短い要約を生成（例: `habit-skip`, `daily-impact`）
   - 同日に複数作成する場合はスラグで区別される
7. ユーザーにレビューを依頼する

引数の解釈:
- ファイルパス: そのファイルをbrain dumpとして読み込む
- テキスト: それ自体をbrain dumpとして扱う
- 引数なし: ユーザーに「何を作りたいか教えてください」と聞く

完了後、`/longrun:exec` コマンドでロングラン実行を開始できることを案内してください。
