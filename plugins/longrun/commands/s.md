---
name: s
description: "[alias: status] ロングラン実行の現在の進捗状況を確認する"
allowed-tools: Read, Glob, Bash
---

**このコマンドは `/longrun:status` のエイリアスです。** 全く同じ動作をします。

ロングラン実行の現在の進捗状況を確認して表示してください。

## 確認手順

1. ランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longrun/` 内の最新サブディレクトリ（`ls -1d _longrun/20*/ | sort | tail -1`）を使用
   - 注: `_longrun/_archive/` 内のアーカイブ済みランは自動検索対象外

2. `{run-dir}/progress.md` を読み込む
   - 存在しない場合: 「ロングラン実行は開始されていません。`/longrun:exec` で開始してください」と表示

3. **OpenSpec進捗を集約表示**:
   - `openspec list` を実行し、各changeの進捗を取得
   - change名、タスク完了数/全数、ステータスを表示

4. 以下の情報を簡潔に表示:
   - ランディレクトリ名（日付とスラグ）
   - 現在のPhase（0/1/2/3/4）
   - 各changeの進捗（openspec listから）
   - 意思決定の件数
   - 最終更新時刻

5. Git の状態:
   - 最新のコミットメッセージ
   - アクティブなworktreeの一覧（`git worktree list`）

6. アーカイブ済みラン:
   - `_longrun/_archive/` 内のディレクトリを一覧表示（存在する場合）
