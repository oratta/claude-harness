## MODIFIED Requirements

### Requirement: 後追いが動かない条件
システムは次のどれかに当たるとき、`gh` を 1 回も呼ばず、控えファイルも書かずに終わ MUST る。

- 環境変数 `COST_LEDGER_GATE_REPORT=off` または `COST_LEDGER_BACKFILL=off`（このときは `python3` も起動しない）
- 台帳の場所が未設定（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` の両方が空。解決は `cost-ledger-persistence` の定めに従い、前者が優先。このときは `python3` も起動しない）。SessionStart の hook のプロセスには、userConfig が未設定なら `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` 自体が渡らない（`${user_config.` で始まる置換されなかった文字列が渡るのは `/cost` のコマンド本文だけ）ので、`cost-ledger-persistence` の「`${user_config.` で始まる値も未設定」の扱いはここでは要らない、または台帳の場所が `cost-ledger-persistence` の定めで書けない場所（プラグインのリポジトリの配下）
- 許可の一覧（`cost-ledger-write-allowlist`）のファイルが無い、または大きさが 0（このときは `python3` も起動しない。場所は `COST_LEDGER_WRITE_REPOS_FILE`、無ければ `$HOME/.config/cost-ledger/write-repos`）
- `python3` か `gh` が無い
- hook の `cwd` が git リポジトリでない、origin が無い・読めない、または origin のホストが github.com でない
- `cwd` のリポジトリ（origin の `owner/repo`）が許可の一覧に載っていない（判定は `cost-ledger-write-allowlist` の定める `write_allow.py` の関数が行う。一覧のファイルが作業中のリポジトリの中にある・持ち主や権限が合わない・有効な行が無いときも、載っていないのと同じ）
- hook が引き継いだ環境変数 `GH_HOST` が github.com 以外

有効・無効を切り替える設定項目を持ってはなら MUST NOT ない（上の 2 つの環境変数は緊急停止）。

後追いが `gh` を呼ぶ相手（候補の一覧の取得、対象の確認、既存コメントの取得、閉じた PR の問い合わせ、書き込み）は `cwd` のリポジトリだけなので、許可の一覧の判定は最初の `gh` の前に 1 回 SHALL 行う。一覧に載っていないリポジトリでは、書き込みだけでなく候補の一覧の取得も行ってはなら MUST NOT ない。`backfill.sh` がファイルの有無と大きさだけを見て抜ける近道は、`gate-report.sh` の近道と同じ扱いで、判定の代わりにしてはなら MUST NOT ない（`backfill.py` を直接起動しても、同じ判定を通る）。

SessionStart の JSON の `source` が `clear` または `compact` のとき（matcher を通らずに直接流された場合）と、JSON が読めない・`cwd` が文字列でないときも、システムは `gh` を呼ばず、控えファイルを書かずに終わ MUST る。

守備範囲: この判定が受け取る入力は、Claude Code が SessionStart の hook に渡す JSON（`source`・`cwd`）、hook のプロセスが引き継いだ環境変数（`COST_LEDGER_GATE_REPORT`・`COST_LEDGER_BACKFILL`・`CLAUDE_PLUGIN_OPTION_LEDGER_PATH`・`COST_LEDGER_PATH`・`COST_LEDGER_WRITE_REPOS_FILE`・`HOME`・`GH_HOST`・`PATH`）、`cwd` の git リポジトリの origin の URL、許可の一覧のファイルに限る（一覧のファイルの読み方と、その入力の守備範囲は `cost-ledger-write-allowlist` が定める）。どれも手元の利用者とそのセッションが決める値で、外部の第三者が書き込む入力は無い。拾いたい誤りは、止めたはずの後追いが `gh` を呼ぶこと・github.com 以外に向けたセッションやリポジトリから github.com へ書き込むこと・控えの置き場所が決まらないまま既定の場所やリポジトリの配下に書くこと・利用者が許可していないリポジトリ（clone しただけの他人の公開リポジトリなど）の PR / issue にコストのコメントを書くことの 4 つ。次の入力は誤ったまま通ることを許す: 緊急停止の値は `off` との完全一致だけを見るので、`OFF`・`0`・`false` では止まらない（`cost-ledger-gate-report` の緊急停止と同じ）／`GH_HOST` は hook のプロセスが引き継いだ値だけを見るので、`gh` の設定ファイルで既定のホストを変えている環境は検知しない（問い合わせ先は `--hostname github.com` で固定するので、書き込み先が変わることはない）／origin 以外の remote（`upstream` など）は見ないので、origin が github.com でなく別の remote が github.com のリポジトリでは動かない／origin の URL が github.com を指していても、`insteadOf` などの git の設定で実際の接続先を書き換えている環境は検知しない／`cwd` が worktree やサブディレクトリでも、その場所から見える origin をそのまま使う／`source` の値が `startup`・`resume`・`clear`・`compact` のどれでもない（将来の Claude Code が足した値・値が無い）ときは、matcher を通った以上は起動として扱い、動く／許可の一覧は origin の `owner/repo` の名前で照合するので、リポジトリが改名・移管されて GitHub が別の名前へ転送する場合、候補の一覧が返したリポジトリ名（`repository_url`）が origin と違う要素が 1 件でもあれば一覧の失敗と同じ扱いにして、何も積まない（PR の候補は、対象の確認で返ったベースのリポジトリ名が origin と違えば積まない）／許可の一覧に載っているリポジトリの中では、別のリポジトリの同名ブランチのコストが混ざること・セッションが見ただけの issue にコメントが付くことを、この判定では防がない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 一覧に無いリポジトリには書かない
- **WHEN** 許可の一覧に `cwd` のリポジトリが載っておらず（別のリポジトリだけが載っている）、候補が 1 件ある状態で SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず（候補の一覧の取得も行われない）、控えファイルは変わらない

#### Scenario: 一覧が無ければどこにも書かない
- **WHEN** 許可の一覧のファイルが無い状態と、大きさが 0 の状態のそれぞれで、候補が 1 件ある SessionStart の hook JSON を流す
- **THEN** どちらも `gh` と `python3` は一度も呼ばれない

#### Scenario: 作業中のリポジトリの中の一覧は効かない
- **WHEN** `COST_LEDGER_WRITE_REPOS_FILE` が `cwd` のリポジトリの中のファイル（`cwd` のリポジトリを載せてある）を指す状態で、候補が 1 件ある SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

#### Scenario: `backfill.py` を直接起動しても一覧に従う
- **WHEN** 許可の一覧のファイルが無い状態と、`cwd` のリポジトリが載っていない状態のそれぞれで、`backfill.sh` を通さずに `backfill.py` へ SessionStart の hook JSON を流す
- **THEN** どちらも `gh` は一度も呼ばれない

#### Scenario: 後追いだけを止める
- **WHEN** `COST_LEDGER_BACKFILL=off` を付けて SessionStart の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 既存の緊急停止も効く
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて SessionStart の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれない

#### Scenario: 台帳が未設定
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` の両方を未設定（または空文字）にして SessionStart の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれない

#### Scenario: userConfig だけで台帳を設定した環境でも動く
- **WHEN** `COST_LEDGER_PATH` を未設定にし、`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` だけを台帳の場所に設定して、手元にコストがあり、同じきっかけの行がまだ無いマージ済みの PR が候補に 1 件ある状態で SessionStart の hook JSON を流す
- **THEN** 候補に行が積まれ、控えファイルとロックは `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が指す台帳の隣にできる

#### Scenario: 両方を別の場所に設定したときは userConfig を使う
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` を別の場所に設定して、手元にコストがあり、同じきっかけの行がまだ無いマージ済みの PR が候補に 1 件ある状態で SessionStart の hook JSON を流す
- **THEN** 控えファイルは `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が指す台帳の隣にだけでき、`COST_LEDGER_PATH` の隣には作られない

#### Scenario: github.com でないリポジトリ
- **WHEN** `cwd` のリポジトリの origin が `https://unrelated.example/acme/repo-a.git` の状態で SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、控えファイルは作られない

#### Scenario: 引き継いだ `GH_HOST` が github.com でない
- **WHEN** `GH_HOST=ghe.example.com` を付けて、origin が github.com のリポジトリを `cwd` にした SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、控えファイルは作られない

#### Scenario: `clear` と `compact` では動かない
- **WHEN** `source` が `clear` または `compact` の SessionStart の hook JSON を `backfill.sh` に直接流す
- **THEN** `gh` は一度も呼ばれず、控えファイルは作られない

#### Scenario: git リポジトリでない場所
- **WHEN** `cwd` が git リポジトリでないディレクトリの SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

