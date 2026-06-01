## MODIFIED Requirements

### Requirement: wt-clean は実行時に origin remote を同期する

`wt-clean` コマンドおよびスキルは、対象選択および各対象の遅延診断（`wt-clean-target-selection`）に先立つ Step 0 として、ローカル `<main>` ブランチを `origin/<main>` に同期するものとする（SHALL）。同期は `git fetch origin` と、必要に応じた `git pull --ff-only origin <main>` で行う。デフォルトでこの同期が有効であり、`--no-sync` オプション指定時のみスキップする。パス／ブランチ名引数で対象を指定した場合も、単一対象のマージ済み判定を正確に行うため Step 0 は実行される（`--no-sync` で停止可能）。

#### Scenario: デフォルトで fetch が実行される

- **WHEN** ユーザーが `wt-clean` をオプションなしで実行する
- **THEN** 対象選択・遅延診断より前に `git fetch origin` が実行される

#### Scenario: ローカル main が遅れていれば fast-forward pull される

- **WHEN** `git rev-list --left-right --count <main>...origin/<main>` の右側が 1 以上で左側が 0
- **THEN** `git pull --ff-only origin <main>` が実行され、ローカル `<main>` が origin と一致する

#### Scenario: 既に最新ならスキップ

- **WHEN** ローカル `<main>` が `origin/<main>` と一致している
- **THEN** `git pull` は実行されず、レポートに「already up-to-date」と表示される

#### Scenario: パス指定時も Step 0 が実行される

- **WHEN** ユーザーが `wt-clean ~/wt/foo` をパス指定で実行する（`--no-sync` なし）
- **THEN** その 1 件の診断に先立ち Step 0 の `git fetch origin` が実行される

### Requirement: 同期後の診断が origin/main 反映状態で行われる

Step 0 で同期が成功した場合、逐次処理ループでの各対象のマージ済み判定（`git branch --merged <main>`）は同期後の `<main>` を基準に行うものとする（SHALL）。これにより、GitHub 側でマージ済みの feature ブランチは 🟢 Safe に分類される。

#### Scenario: PR マージ済みブランチが Safe 判定される

- **GIVEN** feature ブランチが GitHub PR でマージ済み、ローカル `<main>` は同期前の状態
- **WHEN** `wt-clean` を実行し、その worktree を対象として逐次処理ループで診断する
- **THEN** Step 0 でローカル `<main>` が origin に追従し、その feature ブランチが 🟢 Safe（マージ済み & dirty なし & LLM なし）に分類される
