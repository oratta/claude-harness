# wt-clean-reuse Specification

## Purpose

`wt-clean` コマンドに、マージ済み worktree を削除せず再利用可能な状態へ戻す `--keep` オプションを提供する。worktree 内の untracked ファイル（`node_modules`, `.env` 等）を保持したまま、tracked 状態を `main` に揃え元ブランチを削除することで、次の作業を高速に開始できる状態を作る。
## Requirements
### Requirement: wt-clean は --keep オプションを受け付ける

`wt-clean` コマンドおよびスキルは `--keep` オプションを受け付けるものとする（SHALL）。オプション未指定時は従来通りの全削除動作を実行し、指定時は再利用モードで動作する。後方互換性のため、デフォルト動作は削除のまま変更しない。

#### Scenario: オプション未指定時は従来動作
- **WHEN** ユーザーが `wt-clean` をオプションなしで実行する
- **THEN** 全ての 🟢 Safe worktree は `git worktree remove` + `git branch -d` で削除される

#### Scenario: --keep 指定時は再利用モードに切り替わる
- **WHEN** ユーザーが `wt-clean --keep` を実行する
- **THEN** 🟢 Safe worktree は削除されず、worktree 内のブランチが `main`（または `master`）に切り替えられ、元ブランチが削除される

### Requirement: 再利用化の対象は 🟢 Safe worktree のみ

`--keep` モードにおいて、再利用可能化の対象は「マージ済み かつ 未コミット変更なし かつ `LLM/` ディレクトリなし」である🟢 Safe worktree に限定するものとする（SHALL）。🟡 Recoverable および 🔴 Active worktree は `--keep` 指定時も従来の扱いを維持する。

#### Scenario: 🟢 Safe worktree は再利用可能化される
- **WHEN** `--keep` モードで🟢 Safe と分類された worktree を処理する
- **THEN** worktree ディレクトリは削除されず、ブランチが main に切り替えられる

#### Scenario: 🟡 Recoverable worktree は従来の削除フロー
- **WHEN** `--keep` モードで🟡 Recoverable と分類された worktree を処理する
- **THEN** LLM保全→未コミット変更確認→削除 の従来フローが実行される

#### Scenario: 🔴 Active worktree はスキップされる
- **WHEN** `--keep` モードで🔴 Active と分類された worktree を処理する
- **THEN** 従来通り明示指示がない限りスキップされる

### Requirement: 再利用化は最小操作で安全に行う

`--keep` モードの再利用化処理は、worktree 内で `main`（または `master`）ブランチへ `git checkout` し、元のブランチを `git branch -d` で削除するものとする（SHALL）。**worktree 内**での `git reset --hard` / `git clean` / `git pull` / `git fetch` などの破壊的操作は実行しないものとする（SHALL NOT）。untracked ファイル（`node_modules`, `.env`, 作業中ファイル等）は一切変更しない。

なお、本禁則は Step 7b（再利用化処理）**内**の worktree に対する制約であり、Step 0（Remote 同期）でメインリポにて実行する `git fetch origin` / `git pull --ff-only origin <main>` は本禁則の対象外である。Step 0 と Step 7b は実行コンテキスト（メインリポ vs 各 worktree）と目的（最新化 vs 再利用化）が異なる。

#### Scenario: 再利用化で tracked ファイルが main と一致する

- **WHEN** 再利用化処理が完了する
- **THEN** 対象 worktree の HEAD は `main`（または `master`）を指し、tracked ファイルは main と一致する

#### Scenario: untracked ファイルは保持される

- **WHEN** 再利用化処理を実行する
- **THEN** `node_modules`, `.env`, その他 untracked ファイルは全て保持される

#### Scenario: 元ブランチが削除される

- **WHEN** 再利用化処理が完了する
- **THEN** `git branch` の出力に元のマージ済みブランチが含まれない

#### Scenario: Step 7b 内では worktree に対して pull/fetch しない

- **WHEN** `--keep` モードで Step 7b の再利用化処理を実行する
- **THEN** `git -C <worktree> pull` や `git -C <worktree> fetch` は実行されない（Step 0 のメインリポでの fetch/pull とは区別される）

### Requirement: サニティチェック FAIL 時は再利用化も保留する

Step 6 のマージ後サニティチェックで FAIL した worktree は、`--keep` 指定時も再利用化せず保留するものとする（SHALL）。FAIL した worktree のマージ以降にマージされた worktree についても同様に保留する。

#### Scenario: サニティチェック FAIL 時は再利用化しない
- **WHEN** `--keep` モードでサニティチェックが FAIL する
- **THEN** 該当 worktree は削除も再利用化もされず、元ブランチのまま保持される

#### Scenario: FAIL 以降の worktree も保留
- **WHEN** サニティチェックが FAIL し、それ以降にマージされた worktree が存在する
- **THEN** 後続の worktree も削除・再利用化とも保留される

### Requirement: 完了レポートで再利用可能化された worktree を明示する

`--keep` モード実行後の完了レポートは、再利用可能化された worktree ごとにディレクトリパスと次作業開始コマンドを表示するものとする（SHALL）。また、`package.json` 等の依存が変わっていた場合の再インストール注意喚起を含めるものとする（SHALL）。

#### Scenario: 再利用化 worktree のパスが表示される
- **WHEN** `--keep` モードが完了する
- **THEN** 完了レポートに再利用可能化された worktree ごとのディレクトリパスが含まれる

#### Scenario: 次作業コマンドが表示される
- **WHEN** 完了レポートを表示する
- **THEN** `cd <path> && git checkout -b <new-branch>` 形式の次作業コマンドが含まれる

#### Scenario: 依存再インストール注意が含まれる
- **WHEN** 完了レポートを表示する
- **THEN** 「package.json / Gemfile 等が更新されていれば依存を再インストールする」旨の案内が含まれる

### Requirement: main ブランチ重複チェックアウト競合を検知する

`--keep` モードで main（または master）への切り替えを試みる前に、同じブランチが他の worktree で既にチェックアウトされていないか検査するものとする（SHALL）。競合が検知された場合、該当 worktree を再利用化対象から除外し、警告を表示する。

#### Scenario: main が別 worktree で使用中の場合は除外される
- **WHEN** 他の worktree が既に main をチェックアウトしている状態で `--keep` を実行する
- **THEN** 該当 worktree は再利用化対象から除外され、警告メッセージが表示される

#### Scenario: 競合がない場合は通常処理
- **WHEN** 他の worktree が main をチェックアウトしていない
- **THEN** 通常の再利用化処理（checkout main + branch -d）が実行される

### Requirement: 再利用化対象が0件でも実行は成功する

`--keep` 指定時に再利用化対象（🟢 Safe）が 1つも存在しない場合でも、コマンド実行はエラーにせず、従来の削除フローを実行して正常終了するものとする（SHALL）。

#### Scenario: 🟢 Safe が 0 件
- **WHEN** `--keep` 指定で実行したが🟢 Safe worktree が存在しない
- **THEN** 「再利用化対象なし」とレポートに明示し、🟡 Recoverable / 🔴 Active に対する従来処理を継続する

