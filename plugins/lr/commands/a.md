---
name: a
description: "完了したロングラン実行をアーカイブする（/longrun:archive の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob
---

ユーザーの承認を受けて、完了したロングラン実行をアーカイブしてください。

## 手順

1. ランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longrun/` 内の最新サブディレクトリ（`ls -1d _longrun/20*/ | sort | tail -1`）を使用

2. `{run-dir}/instruction.md` のChanges分解セクションからchange一覧を取得

3. **OpenSpec changeのアーカイブ**（各changeに対して）:
   - delta specがある場合: `openspec/changes/<change-name>/specs/` → `openspec/specs/<capability>/spec.md` にコピー
   - `mv openspec/changes/<change-name> openspec/changes/archive/YYYY-MM-DD-<change-name>`

4. **ランディレクトリのアーカイブ**:
   - `mv {run-dir} _longrun/_archive/`

5. **Worktreeのクリーンアップ**

6. **アーカイブコミット**:
   `chore: archive longrun and openspec - [change名の列挙]`
