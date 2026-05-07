---
name: archive
description: 完了した自律実行をアーカイブする（OpenSpec change + ランディレクトリ）。MVP モード plan.md は OpenSpec change 生成をスキップしてディレクトリのみアーカイブ
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

ユーザーの承認を受けて、完了した自律実行をアーカイブしてください。

## 手順

1. ランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longruns/` 内の最新サブディレクトリ（`ls -1d _longruns/20*/ | sort | tail -1`）を使用

2. **MVP モード判定**（必ず実行）:
   - 対象ランディレクトリの `plan.md` の先頭を読み込み、`<!-- mvp-mode -->` マーカーが含まれているかを判定する
   - 判定方法: `head -5 {longrun-dir}/plan.md` 等で先頭数行を取得し、リテラル `<!-- mvp-mode -->` が含まれるかを Grep / 文字列一致で確認する
   - マーカー**あり** → 「MVP モードアーカイブ」分岐へ進む（下記「MVP モードアーカイブ」セクション）
   - マーカー**なし** → 既存のフルモードアーカイブを実行する（下記「フルモードアーカイブ」セクション）

---

## フルモードアーカイブ（マーカーなし — 既存挙動）

3. `{longrun-dir}/plan.md` のChanges分解セクションからchange一覧を取得

4. **OpenSpec changeのアーカイブ**（各changeに対して）:
   - delta specがある場合: specs/ をメインspecsにコピー
   - `openspec/changes/<name>` → `openspec/changes/archive/YYYY-MM-DD-<name>` に移動

5. **ランディレクトリのアーカイブ**:
   - `{longrun-dir}` → `_longruns/_archive/` に移動

6. **Worktreeのクリーンアップ**:
   - 残存worktreeがあれば削除

7. **アーカイブコミット**:
   ```
   chore: archive longrun and openspec - [change名の列挙]
   ```

8. 完了報告

---

## MVP モードアーカイブ（マーカーあり — 新規分岐）

MVP モード plan.md は人間実装前提で OpenSpec change の自動生成パイプラインに乗っていないため、`openspec/changes/<name>` の archive 処理は **行わない**。delta spec のコピーも行わない。ランディレクトリのアーカイブのみ実施する。

3'. **OpenSpec change のアーカイブをスキップ**:
   - `openspec/changes/` 配下を一切触らない
   - delta spec のコピーも行わない
   - ユーザーには「MVP モードを検知したため OpenSpec change archive はスキップしました」と明示的に出力する

4'. **ランディレクトリのアーカイブ**（フルモードと同じ）:
   - `{longrun-dir}` → `_longruns/_archive/` に移動

5'. **Worktreeのクリーンアップ**（フルモードと同じ）:
   - 残存worktreeがあれば削除

6'. **アーカイブコミット**:
   ```
   chore: archive mvp-mode longrun - {longrun-dir basename}
   ```
   フルモードのコミットメッセージ（`archive longrun and openspec`）と区別するため、`mvp-mode` を含む文言にする。

7'. 完了報告:
   - 「MVP モードアーカイブ完了」を明示
   - OpenSpec change の archive がスキップされたことを再掲
   - 移動先パス（`_longruns/_archive/{basename}/`）を案内
