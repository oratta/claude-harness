## ADDED Requirements

### Requirement: 起動アカウントを週次余裕から自動選択する
`plugins/dev-workflow/scripts/select-account.sh` は、引数が無いときにレジストリの宣言順でスロットと schema 2 usage snapshot の `accounts` を突き合わせ、利用可能な候補のうち週次余裕が最大のスロットを選ばなければならない（SHALL）。週次余裕は、現在時刻と `weekly_resets_epoch` から既存の共有枠モードと同じ式で求めて 0〜100 に clamp した週経過率から `weekly_all_pct` を引いた値とする。同点ではレジストリの宣言順で先のスロットを選ばなければならない（SHALL）。選択は起動時の 1 回だけであり、起動済みセッションのアカウントを変更してはならない（MUST NOT）。

#### Scenario: 週次余裕が大きいスロットを選ぶ
- **WHEN** 新鮮な 2 スロットの snapshot で週次余裕が `a < b` である
- **THEN** selector は `b` の `securestorage` を出力し、理由行に `a` と `b` の週次余裕を小数点以下 2 桁で含める

#### Scenario: 同点は宣言順で決める
- **WHEN** 利用可能な 2 スロットの週次余裕が等しい
- **THEN** selector は `accounts.json` で先に宣言されたスロットを選ぶ

### Requirement: 古い・欠測・短期枠逼迫のスロットを候補から外す
自動選択では `0 <= now - fetched_at < 300` 秒のスロットだけを新鮮とみなさなければならない（SHALL）。`fetched_at`、`weekly_all_pct`、`weekly_resets_epoch`、`five_hour_pct` のいずれかが欠測・非数値であるスロット、未来の `fetched_at` を持つスロット、および `five_hour_pct >= 90` のスロットを候補から外さなければならない（SHALL）。候補が 1 つも無い場合は既定アカウントを表す空の `securestorage` を選び、古い値を余裕があるものとして選んではならない（MUST NOT）。

#### Scenario: 閾値以上に古いスロットを選ばない
- **WHEN** 片方の `fetched_at` の age が 300 秒以上で、もう片方が 300 秒未満の snapshot を与える
- **THEN** selector は古いスロットを候補から外し、新鮮なスロットを選ぶ

#### Scenario: 全スロットが古いときは既定へ縮退する
- **WHEN** 全スロットの `fetched_at` の age が 300 秒以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `reason=no-eligible-usage` と各スロットの `stale` を含める

#### Scenario: 5 時間枠が 90 パーセントなら候補から外す
- **WHEN** 週次余裕が最大のスロットの `five_hour_pct` が 90 で、別の新鮮なスロットが 90 未満である
- **THEN** selector は週次余裕が最大のスロットを候補から外し、別のスロットを選ぶ

#### Scenario: 選択に必要な値が欠測している
- **WHEN** スロットの選択に必要な 4 フィールドのいずれかが null または非数値である
- **THEN** selector はそのスロットを候補から外し、理由行に `missing` を含める

### Requirement: 登録済みスロットを明示選択できる
`select-account.sh <slot-id>` は usage snapshot を読まず、レジストリに登録された id の `securestorage` を返さなければならない（SHALL）。id が未登録、または引数が 2 個以上なら stdout に値を出さず exit 2 で終了しなければならない（SHALL）。

#### Scenario: 登録済み id を snapshot 無しで選ぶ
- **WHEN** 登録済み id を 1 個渡し、usage snapshot が存在しない
- **THEN** selector はそのスロットの `securestorage` を返し、exit 0 になる

#### Scenario: 未登録 id を拒否する
- **WHEN** レジストリに無い id を渡す
- **THEN** selector は stdout に値を出さず、stderr に診断を出して exit 2 になる

### Requirement: 値と選択理由を別の出力ストリームで返す
成功時の selector は stdout に選んだ `securestorage` の実値だけを改行付きで出さなければならない（SHALL）。既定アカウントの stdout は空行とする。stderr には `selected=<id> reason=<reason> margins=<entries>` の 1 行だけを出さなければならない（SHALL）。自動選択の `margins` は全登録スロットを宣言順に含み、候補は週次余裕を小数点以下 2 桁、候補外は `stale`、`missing`、`five-hour>=90` のいずれかで示さなければならない（SHALL）。

#### Scenario: shell は stdout だけを値として取り込める
- **WHEN** 自動選択の stdout を command substitution で取得し、stderr を端末へ残す
- **THEN** 変数には `securestorage` の実値だけが入り、選択 id・理由・全スロットの比較は stderr の 1 行で確認できる

#### Scenario: 明示選択の理由を示す
- **WHEN** 登録済み id を明示して選ぶ
- **THEN** stderr は `reason=explicit` と `margins=-` を含む

### Requirement: shell function から選択したアカウントで Claude を起動する
`plugins/dev-workflow/README.md` は zsh の `cld [claude-args...]` と `cld-account <slot-id> [claude-args...]` の設定例を示さなければならない（SHALL）。`cld` は起動前に `usage-probe.sh` を best-effort で実行してから自動選択し、`cld-account` は id を selector へ渡して明示選択する。選択値が空なら `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset し、空でなければその値を設定して、残りの引数を引用したまま `claude` へ渡さなければならない（SHALL）。

#### Scenario: 自動選択と statusline の active 表示が一致する
- **WHEN** `cld` が selector の選んだ非空の `securestorage` で Claude を起動する
- **THEN** 起動したセッションの statusline は同じレジストリスロットを active として表示する

#### Scenario: 既定アカウントでは環境変数を解除する
- **WHEN** selector が既定アカウントを表す空行を返す
- **THEN** `cld` は `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset した環境で Claude を起動する
