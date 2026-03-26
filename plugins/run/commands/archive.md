---
name: archive
description: 完了した自律実行をアーカイブする（OpenSpec change + ランディレクトリ）
allowed-tools: Read, Write, Edit, Bash, Glob
---

ユーザーの承認を受けて、完了した自律実行をアーカイブしてください。

## 手順

1. ランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_runs/` 内の最新サブディレクトリ（`ls -1d _runs/20*/ | sort | tail -1`）を使用

2. `{run-dir}/plan.md` のChanges分解セクションからchange一覧を取得

3. **OpenSpec changeのアーカイブ**（各changeに対して）:
   - delta specがある場合: specs/ をメインspecsにコピー
   - `openspec/changes/<name>` → `openspec/changes/archive/YYYY-MM-DD-<name>` に移動

4. **ランディレクトリのアーカイブ**:
   - `{run-dir}` → `_runs/_archive/` に移動

5. **Worktreeのクリーンアップ**:
   - 残存worktreeがあれば削除

6. **アーカイブコミット**:
   ```
   chore: archive run and openspec - [change名の列挙]
   ```

7. 完了報告
