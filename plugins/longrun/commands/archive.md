---
name: archive
description: 完了した自律実行をアーカイブする（OpenSpec change + ランディレクトリ）。縮退モード（.degraded-mode マーカー）と MVP モード（<!-- mvp-mode --> マーカー）は OpenSpec change 生成をスキップしてディレクトリのみアーカイブ
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

ユーザーの承認を受けて、完了した自律実行をアーカイブしてください。

## 手順

1. ランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longruns/` 内の最新サブディレクトリ（`ls -1d _longruns/20*/ | sort | tail -1`）を使用

2. **アーカイブモード判定**（必ず実行 — 判定順は下記のとおり）:

   **判定ソースは 2 つあり別物である**。両者の判定順を厳守する:
   1. **縮退モード判定（最優先）** — ソース: ランディレクトリの `.degraded-mode` **ファイル**
      ```bash
      test -f "{longrun-dir}/.degraded-mode" && echo DEGRADED || echo NOT_DEGRADED
      ```
      - 存在 → 「縮退モードアーカイブ」分岐へ進む（下記「縮退モードアーカイブ」セクション）
   2. **MVP モード判定** — ソース: `plan.md` 先頭の `<!-- mvp-mode -->` **マーカーコメント**
      - 判定方法: `head -5 {longrun-dir}/plan.md` 等で先頭数行を取得し、リテラル
        `<!-- mvp-mode -->` が含まれるかを Grep / 文字列一致で確認する
      - 含まれる → 「MVP モードアーカイブ」分岐へ進む（下記「MVP モードアーカイブ」セクション）
   3. どちらでもない → 既存のフルモードアーカイブを実行する（下記「フルモードアーカイブ」セクション）

   **重要（判定ソースの不一致）**: 縮退判定のソースは run ディレクトリの `.degraded-mode`
   ファイル、MVP 判定のソースは plan.md 内のコメントであり、別物である。両マーカーが併存する
   場合は `.degraded-mode` を優先する（先に判定する）。動作はいずれも「OpenSpec change の
   アーカイブをスキップし、ランディレクトリのみアーカイブ」で同一だが、ユーザーへの**判定根拠の
   表示を分ける**（縮退検知 / MVP 検知）。

---

## 縮退モードアーカイブ（`.degraded-mode` マーカーあり — 最優先分岐）

縮退モードの run は OpenSpec CLI を使わず spec 類を `{longrun-dir}/specs/` に自己完結生成して
いるため、`openspec/changes/<name>` の archive 処理は **行わない**。delta spec のコピーも
行わない。ランディレクトリのアーカイブのみ実施する（spec 類はランディレクトリに内包されて
いるため一緒に保全される）。

3''. **OpenSpec change のアーカイブをスキップ**:
   - `openspec/changes/` 配下を一切触らない（`openspec/changes/archive/` への移動は発生しない）
   - delta spec のコピーも行わない
   - ユーザーには「縮退モード（.degraded-mode マーカー）を検知したため OpenSpec change
     archive はスキップしました」と**判定根拠を明示**して出力する

4''. **ランディレクトリのアーカイブ**（フルモードと同じ）:
   - `{longrun-dir}` → `_longruns/_archive/` に移動（`specs/` も一緒に移動される）

5''. **Worktreeのクリーンアップ**（フルモードと同じ）:
   - 残存worktreeがあれば削除

6''. **アーカイブコミット**:
   ```
   chore: archive degraded-mode longrun - {longrun-dir basename}
   ```
   フル / MVP のコミットメッセージと区別するため、`degraded-mode` を含む文言にする。

7''. 完了報告:
   - 「縮退モードアーカイブ完了」を明示
   - 判定根拠（`.degraded-mode` マーカー）と OpenSpec change archive がスキップされたことを再掲
   - 移動先パス（`_longruns/_archive/{basename}/`）を案内

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
