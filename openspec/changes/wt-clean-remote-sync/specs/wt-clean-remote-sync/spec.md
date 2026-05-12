## ADDED Requirements

### Requirement: wt-clean は実行時に origin remote を同期する

`wt-clean` コマンドおよびスキルは、worktree 診断（Step 1）に先立ち、ローカル `<main>` ブランチを `origin/<main>` に同期するものとする（SHALL）。同期は `git fetch origin` と、必要に応じた `git pull --ff-only origin <main>` で行う。デフォルトでこの同期が有効であり、`--no-sync` オプション指定時のみスキップする。

#### Scenario: デフォルトで fetch が実行される

- **WHEN** ユーザーが `wt-clean` をオプションなしで実行する
- **THEN** Step 1 の診断より前に `git fetch origin` が実行される

#### Scenario: ローカル main が遅れていれば fast-forward pull される

- **WHEN** `git rev-list --left-right --count <main>...origin/<main>` の右側が 1 以上で左側が 0
- **THEN** `git pull --ff-only origin <main>` が実行され、ローカル `<main>` が origin と一致する

#### Scenario: 既に最新ならスキップ

- **WHEN** ローカル `<main>` が `origin/<main>` と一致している
- **THEN** `git pull` は実行されず、レポートに「already up-to-date」と表示される

### Requirement: --no-sync オプションで Remote 同期をスキップする

`wt-clean` は `--no-sync` オプションを受け付け、指定時には Step 0 の同期処理を完全にスキップするものとする（SHALL）。

#### Scenario: --no-sync で fetch も pull も走らない

- **WHEN** ユーザーが `wt-clean --no-sync` を実行する
- **THEN** `git fetch` および `git pull` は実行されない
- **AND** Step 1 の診断はローカルの現状の `<main>` ベースで行われる

#### Scenario: --keep との併用が許可される

- **WHEN** ユーザーが `wt-clean --keep --no-sync` を実行する
- **THEN** Step 0 はスキップされ、その後 `--keep` モード（再利用化）の処理が実行される

### Requirement: origin remote が存在しない場合は同期をスキップする

`wt-clean` は実行リポジトリに `origin` remote が存在しない場合、Step 0 をスキップしエラー終了しないものとする（SHALL）。

#### Scenario: origin がないリポジトリで実行

- **WHEN** `git remote get-url origin` が失敗する
- **THEN** Step 0 はスキップされ、wt-clean は通常通り Step 1 から続行する
- **AND** 完了レポートに「Remote 同期: -- skipped (no origin remote)」と表示される

### Requirement: 同期失敗時は wt-clean を中断する

`git pull --ff-only` または `git fetch` が失敗した場合、`wt-clean` は後続の診断・削除・再利用化を実行せず、エラーメッセージとともに中断するものとする（SHALL）。失敗の典型例はローカル `<main>` が origin と diverge している、remote が force-push された、ネットワーク到達不能、等である。

#### Scenario: fast-forward 不可で中断

- **WHEN** `git pull --ff-only origin <main>` が non-fast-forward により失敗する
- **THEN** wt-clean は Step 1 以降に進まず、エラー出力（`git status` や `git log` で確認する旨）を表示して終了する

#### Scenario: fetch がネットワーク失敗

- **WHEN** `git fetch origin` がネットワークエラーで失敗する
- **THEN** wt-clean は中断し、再実行または `--no-sync` でのスキップを案内する

### Requirement: 完了レポートに同期結果を表示する

`wt-clean` 完了レポート（Step 8）は、Step 0 の同期結果を 1 行で含むものとする（SHALL）。同期結果は以下のいずれかである:

- `Remote 同期: ✅ pulled N commits (origin/<main> → <main>)` — fast-forward pull 実行時
- `Remote 同期: ✅ already up-to-date` — pull 不要時
- `Remote 同期: -- skipped (--no-sync)` — `--no-sync` 指定時
- `Remote 同期: -- skipped (no origin remote)` — origin remote 不在時

#### Scenario: pull 実行時の表示

- **WHEN** Step 0 で 3 コミット pull された
- **THEN** 完了レポートに「Remote 同期: ✅ pulled 3 commits (origin/main → main)」と表示される

#### Scenario: --no-sync 時の表示

- **WHEN** `--no-sync` 指定で実行された
- **THEN** 完了レポートに「Remote 同期: -- skipped (--no-sync)」と表示される

### Requirement: 同期後の診断が origin/main 反映状態で行われる

Step 0 で同期が成功した場合、Step 1 以降のマージ済み判定（`git branch --merged <main>`）は同期後の `<main>` を基準に行うものとする（SHALL）。これにより、GitHub 側でマージ済みの feature ブランチは 🟢 Safe に分類される。

#### Scenario: PR マージ済みブランチが Safe 判定される

- **GIVEN** feature ブランチが GitHub PR でマージ済み、ローカル `<main>` は同期前の状態
- **WHEN** `wt-clean` をデフォルト実行する
- **THEN** Step 0 でローカル `<main>` が origin に追従し、Step 1 でその feature ブランチが 🟢 Safe（マージ済み & dirty なし & LLM なし）に分類される
