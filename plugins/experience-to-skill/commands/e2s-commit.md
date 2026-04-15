---
name: e2s-commit
description: 自セッションの作業を明示的にコミットする。experience-to-skill スキルを手動起動するフォールバック。
allowed-tools: Read, Bash, Glob, Grep
---

# /e2s:commit — 明示コミット起動

`experience-to-skill` スキル（auto-trigger）が見逃した場合や、ユーザーが明示的に今すぐコミットしたいタイミングで呼び出す。スキル本体と**完全に同じワークフロー**が走る。

## 実行

`experience-to-skill` スキルを起動し、全ステップを順に実行する：

1. **Precondition**: `git diff --cached --quiet && git diff --quiet` で clean かチェック → clean なら「コミット対象なし」と報告して終了
2. **Step 1-2**: 自セッション編集ファイル特定 + git status 交集合
3. **Step 3-5**: Layer 1（ファイルパス除外 + 正規表現）+ Layer 2（LLM review）の secret filter
4. **Step 6-7**: コミットメッセージ生成 + session-id 取得
5. **Step 8**: `git add <files>` + `git commit`
6. 結果報告

## $ARGUMENTS の扱い

- 引数なし（通常）: 全自動でメッセージ生成
- 引数として `type:subject` 形式（例: `feat:add user auth`）が渡された場合: その type と subject を使い、Intent/Result は自動生成
- 引数として subject のみが渡された場合: type は LLM が推定、subject は引数そのまま使用

いずれの場合も Intent / Result / Prompted-by / 🤖 via experience-to-skill trailer は必ず付与する。

## 参照

完全な仕様は `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` を参照。
