---
name: archive
description: 完了したロングラン実行をアーカイブする（OpenSpec change + ランディレクトリ）
allowed-tools: Read, Write, Edit, Bash, Glob
---

ユーザーの承認を受けて、完了したロングラン実行をアーカイブしてください。

## 手順

1. ランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longrun/` 内の最新サブディレクトリ（`ls -1d _longrun/20*/ | sort | tail -1`）を使用

2. `{run-dir}/instruction.md` のChanges分解セクションからchange一覧を取得

3. **OpenSpec changeのアーカイブ**（各changeに対して）:
   - `openspec/changes/<change-name>/` が存在することを確認
   - delta specがある場合: `openspec/changes/<change-name>/specs/` 内の各ファイルを `openspec/specs/<capability>/spec.md` にコピー（既存があれば上書き）
   - `mkdir -p openspec/changes/archive`
   - `mv openspec/changes/<change-name> openspec/changes/archive/YYYY-MM-DD-<change-name>`（日付は実行日）

4. **ランディレクトリのアーカイブ**:
   - `mkdir -p _longrun/_archive`
   - `mv {run-dir} _longrun/_archive/`

5. **Worktreeのクリーンアップ**:
   - `_worktrees/` 配下に残っているworktreeがあれば削除:
     ```bash
     git worktree list  # 確認
     git worktree remove _worktrees/<change-name>  # 各worktree
     ```

6. **アーカイブコミット**:
   ```
   chore: archive longrun and openspec - [change名の列挙]
   ```

7. 完了報告:
   ```
   アーカイブ完了:
   - OpenSpec changes: [N]件アーカイブ
   - ランディレクトリ: {run-dir} → _longrun/_archive/
   - Worktree: [クリーンアップ状況]
   ```
