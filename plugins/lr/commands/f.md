---
name: f
description: "ロングラン完了後のフィードバックを受け付ける（/longrun:feedback の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Task
---

feedback-handler スキルを使用して、フィードバック処理を実行してください。

## 起動条件

- ロングラン完了後にフィードバックしたいとき
- セッションが切れた後にフィードバックループを再開したいとき
- 動作確認して気づいたことを伝えたいとき

## 引数の解釈

- テキストが渡された場合: それ自体をフィードバックとして処理
- 引数なしの場合: ユーザーに「気づいたことを教えてください」と聞く

## フロー概要

1. 最新の未アーカイブlongrunを特定
2. OpenSpec changes + specs + decisions.md をロード
3. ユーザーのフィードバックを受け取る（brain dump OK）
4. 個別アイテムに分解 → Tier分類
5. 分類結果をユーザーに提示して確認
6. Tier 1/2 → 即実行
7. Tier 3 → `openspec/backlog.md` に記録
8. 完了後、再度フィードバックがあるか確認
