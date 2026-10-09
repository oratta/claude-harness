## MODIFIED Requirements

### Requirement: 後追いが動かない条件
システムは次のどれかに当たるとき、`gh` を 1 回も呼ばず、控えファイルも書かずに終わ MUST る。

- 環境変数 `COST_LEDGER_GATE_REPORT=off` または `COST_LEDGER_BACKFILL=off`（このときは `python3` も起動しない）
- 台帳の場所が未設定（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` の両方が空。解決は `cost-ledger-persistence` の定めに従い、前者が優先。このときは `python3` も起動しない）、または台帳の場所が `cost-ledger-persistence` の定めで書けない場所（プラグインのリポジトリの配下）
- 許可の一覧（`cost-ledger-write-allowlist`）のファイルが無い、または大きさが 0（このときは `python3` も起動しない。場所は `COST_LEDGER_WRITE_REPOS_FILE`、無ければ `$HOME/.config/cost-ledger/write-repos`）
- `python3` か `gh` が無い
- hook の `cwd` が git リポジトリでない、origin が無い・読めない、または origin のホストが github.com でない
- `cwd` のリポジトリ（origin の `owner/repo`）が許可の一覧に載っていない（判定は `cost-ledger-write-allowlist` の定める `write_allow.py` の関数が行う。一覧のファイルが作業中のリポジトリの中にある・持ち主や権限が合わない・有効な行が無いときも、載っていないのと同じ）
- hook が引き継いだ環境変数 `GH_HOST` が github.com 以外

有効・無効を切り替える設定項目を持ってはなら MUST NOT ない（上の 2 つの環境変数は緊急停止）。

後追いが `gh` を呼ぶ相手（候補の一覧の取得、対象の確認、既存コメントの取得、閉じた PR の問い合わせ、書き込み）は `cwd` のリポジトリだけなので、許可の一覧の判定は最初の `gh` の前に 1 回 SHALL 行う。一覧に載っていないリポジトリでは、書き込みだけでなく候補の一覧の取得も行ってはなら MUST NOT ない。`backfill.sh` がファイルの有無と大きさだけを見て抜ける近道は、`gate-report.sh` の近道と同じ扱いで、判定の代わりにしてはなら MUST NOT ない（`backfill.py` を直接起動しても、同じ判定を通る）。

SessionStart の JSON の `source` が `clear` または `compact` のとき（matcher を通らずに直接流された場合）と、JSON が読めない・`cwd` が文字列でないときも、システムは `gh` を呼ばず、控えファイルを書かずに終わ MUST る。

守備範囲: この判定が受け取る入力は、Claude Code が SessionStart の hook に渡す JSON（`source`・`cwd`）、hook のプロセスが引き継いだ環境変数（`COST_LEDGER_GATE_REPORT`・`COST_LEDGER_BACKFILL`・`CLAUDE_PLUGIN_OPTION_LEDGER_PATH`・`COST_LEDGER_PATH`・`COST_LEDGER_WRITE_REPOS_FILE`・`HOME`・`GH_HOST`・`PATH`）、`cwd` の git リポジトリの origin の URL、許可の一覧のファイルに限る（一覧のファイルの読み方と、その入力の守備範囲は `cost-ledger-write-allowlist` が定める）。どれも手元の利用者とそのセッションが決める値で、外部の第三者が書き込む入力は無い。拾いたい誤りは、止めたはずの後追いが `gh` を呼ぶこと・github.com 以外に向けたセッションやリポジトリから github.com へ書き込むこと・控えの置き場所が決まらないまま既定の場所やリポジトリの配下に書くこと・利用者が許可していないリポジトリ（clone しただけの他人の公開リポジトリなど）の PR / issue にコストのコメントを書くことの 4 つ。次の入力は誤ったまま通ることを許す: 緊急停止の値は `off` との完全一致だけを見るので、`OFF`・`0`・`false` では止まらない（`cost-ledger-gate-report` の緊急停止と同じ）／`GH_HOST` は hook のプロセスが引き継いだ値だけを見るので、`gh` の設定ファイルで既定のホストを変えている環境は検知しない（問い合わせ先は `--hostname github.com` で固定するので、書き込み先が変わることはない）／origin 以外の remote（`upstream` など）は見ないので、origin が github.com でなく別の remote が github.com のリポジトリでは動かない／origin の URL が github.com を指していても、`insteadOf` などの git の設定で実際の接続先を書き換えている環境は検知しない／`cwd` が worktree やサブディレクトリでも、その場所から見える origin をそのまま使う／`source` の値が `startup`・`resume`・`clear`・`compact` のどれでもない（将来の Claude Code が足した値・値が無い）ときは、matcher を通った以上は起動として扱い、動く／許可の一覧は origin の `owner/repo` の名前で照合するので、リポジトリが改名・移管されて GitHub が別の名前へ転送する場合、issue の候補では転送先の名前を確かめずに積む（PR の候補は、対象の確認で返ったベースのリポジトリ名が origin と違えば積まない）／許可の一覧に載っているリポジトリの中では、別のリポジトリの同名ブランチのコストが混ざること・セッションが見ただけの issue にコメントが付くことを、この判定では防がない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

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
- **WHEN** `COST_LEDGER_PATH` を未設定にし、`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` だけを台帳の場所に設定して、候補が 1 件ある SessionStart の hook JSON を流す
- **THEN** 候補に行が積まれ、控えファイルとロックは `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` が指す台帳の隣にできる

#### Scenario: 両方を別の場所に設定したときは userConfig を使う
- **WHEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` と `COST_LEDGER_PATH` を別の場所に設定して、候補が 1 件ある SessionStart の hook JSON を流す
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

### Requirement: どこまで見たかを台帳の隣に記録する
システムは前回見た時刻を、台帳の隣の控えファイル `<解決した台帳のパス>.backfill.json`（台帳のパスは `cost-ledger-persistence` の定めで解決したもの） に、GitHub の `owner/repo`（小文字）ごとに 1 つ SHALL 記録する。形は `{"version": 1, "repos": {"<owner/repo>": {"seen_until": "<UTC の ISO 8601、秒まで>"}}}`。控えファイルをこのリポジトリの配下に置いてはなら MUST NOT ず、既定のパスを持ってはなら MUST NOT ない。書き込みは、同じディレクトリの一時ファイルに書いてから置き換える形で SHALL 行い、他のリポジトリの値を消してはなら MUST NOT ない。

前回見た時刻は次のとおりに SHALL 進める。今の値より前に戻してはなら MUST NOT ない。

- 一覧が成功し、候補をすべて処理した（候補が 0 件の場合を含む）: 一覧に現れたものの更新時刻（`updated_at`）の最大値。一覧が 0 件のときは、控えにそのリポジトリの値があれば変えず、無ければ（控えが無い・読めない・形が崩れている場合を含む）今回の一覧の `since`（実行した時刻の 24 時間前）を書く
- 候補が 1 回の上限を超えて残った: 最後に処理した候補の出来事の時刻
- 一覧が失敗した: 変えない

候補ごとの処理の失敗（`gh` の失敗・タイムアウト・ロックが取れない・`timeline` の失敗）で、前回見た時刻を止めてはなら MUST NOT ない（その 1 件には行が付かないまま先へ進む）。

控えファイルが無い・読めない・形が崩れている・そのリポジトリの値が無いとき、システムは前回見た時刻を「実行した時刻の 24 時間前」として SHALL 扱う。

守備範囲: この記録が受け取る入力は、この処理自身が書いた控えファイルと、GitHub の一覧が返す時刻に限る。拾いたい誤りは、控えが無い状態でリポジトリの全履歴を候補にすること・手元の時計のずれで出来事を見落とすこと・通信が切れていた回のあとで、その間の出来事を見ないまま先へ進むことの 3 つ。次の入力は誤ったまま通ることを許す: 候補ごとの失敗は取り戻さない（一覧は成功したが、その候補の問い合わせや書き込みだけが失敗した場合、その 1 件には最後の行が付かない）／控えファイルを手で未来の時刻に書き換えると、その時刻まで何も候補にならない／控えが無い状態で 24 時間より前に起きたマージ・クローズには付かない（一覧が空だった回も控えに今回の `since` を書くので、窓は最初の実行の 24 時間前に固定され、セッションのたびにずれない）／控えは PC ごとで、別の PC の進み具合は見ない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 控えが無い初回
- **WHEN** 控えファイルが無い状態で、一覧が、実行した時刻の 1 時間前にマージされた PR #300 と 48 時間前にクローズされ 1 時間前に更新された issue #12 を返す
- **THEN** 一覧の `since` は実行した時刻の 24 時間前（前後 60 秒以内）で、#300 だけが処理され、控えファイルに `acme/cwd-repo` の `seen_until` が書かれる

#### Scenario: 一覧の更新時刻まで進める
- **WHEN** 前回見た時刻が `2026-10-07T01:00:00Z` で、一覧が、`2026-10-07T02:00:00Z` にマージされ `2026-10-07T02:00:05Z` に更新された PR #300 を返す
- **THEN** 実行後の `seen_until` は `2026-10-07T02:00:05Z`

#### Scenario: 一覧が空で値があれば変えない
- **WHEN** 前回見た時刻が `2026-10-07T01:00:00Z` で、一覧が 0 件を返す
- **THEN** 実行後の `seen_until` は `2026-10-07T01:00:00Z`

#### Scenario: 一覧が空で値が無ければ今回の since を書く
- **WHEN** 控えファイルが無い（または、そのリポジトリの値が無い）状態で、一覧が 0 件を返す
- **THEN** 実行後の `seen_until` は、この実行の一覧の `since`（実行した時刻の 24 時間前）と同じ値で、`gh` の呼び出し回数は変わらない

#### Scenario: 一覧が空の回が続いても窓がずれ続けない
- **WHEN** 控えファイルが無い状態で、一覧が 0 件を返す実行をしたあと、一覧が、1 回目の実行の 24 時間前より後で 2 回目の実行の 24 時間前より前にマージされた PR #300 を返す実行をする
- **THEN** 2 回目の一覧の `since` は 1 回目の `since` と同じで、#300 は候補になる

#### Scenario: 一覧が失敗した回は値が無くても書かない
- **WHEN** 控えファイルが無い状態で、一覧の取得が失敗する
- **THEN** 控えファイルは作られない

#### Scenario: 候補の失敗で止めない
- **WHEN** 候補の PR #300 の書き込みだけが失敗する環境で SessionStart の hook JSON を流す
- **THEN** 実行後の `seen_until` は一覧の更新時刻の最大値まで進んでいる

#### Scenario: 他のリポジトリの値を残す
- **WHEN** 控えファイルに `acme/other` の値がある状態で、`cwd` が `acme/cwd-repo` の SessionStart の hook JSON を流す
- **THEN** 実行後の控えファイルに `acme/other` の値が実行前と同じまま残っている

#### Scenario: 壊れた控え
- **WHEN** 控えファイルの中身が JSON でない状態で SessionStart の hook JSON を流す
- **THEN** 初回と同じく 24 時間前からの一覧が行われ、実行後の控えファイルは読める形になっている

### Requirement: 後追いは同時に 1 つだけ走らせる
システムは裏のプロセスの最初に、`<解決した台帳のパス>.backfill.lock` に待たない排他ロックを SHALL 取り、取れなければ `gh` を呼ばずに終わ MUST る。控えファイルの読み取りから書き込みまでは、このロックを持ったまま行 MUST う。

#### Scenario: 別の後追いが実行中
- **WHEN** `<解決した台帳のパス>.backfill.lock` の排他ロックを別のプロセスが持っている状態で SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、控えファイルの内容は実行前と同じ

#### Scenario: 同時に 2 つ流す
- **WHEN** 候補の PR が 1 件ある状態で、SessionStart の hook JSON を 2 つ同時に流す
- **THEN** 両方が終わったあと、その PR のコメントは 1 本で、`マージ` の行は 1 行
