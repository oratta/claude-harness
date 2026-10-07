## ADDED Requirements

### Requirement: セッション開始の hook で後追いを起こす
システムは `plugins/cost-ledger/hooks/hooks.json` に `SessionStart`・matcher `startup|resume`・`timeout: 10` の hook を 1 つ持ち、`plugins/cost-ledger/scripts/backfill.sh` を呼 MUST ぶ。hook の同期部分は、標準入力の JSON から `cwd` を読み、後追いの処理を hook のプロセスから切り離した別プロセスで起こして、その終了を待たずに終了コード 0 で終わ MUST る。同期部分で `gh`・`git` を呼んだり、台帳・会話ログ・控えファイルを読んだりしてはなら MUST NOT ない。

同期部分も裏のプロセスも、stdout と stderr に何も出してはなら MUST NOT ない（SessionStart の hook の stdout は会話の文脈に入るため）。どの失敗でも、hook は終了コード 0 で終わ MUST る。

環境変数 `COST_LEDGER_HOOK_FOREGROUND=1` のとき、システムは切り離さずにその場で最後まで実行 SHALL する（テストと実測のため）。

#### Scenario: hook の登録
- **WHEN** `plugins/cost-ledger/hooks/hooks.json` を読む
- **THEN** `SessionStart` に matcher `startup|resume`・`timeout: 10` で `backfill.sh` を呼ぶ hook があり、`PostToolUse` と `Stop` の登録は変更前と同じ

#### Scenario: gh が遅くても hook はすぐ終わる
- **WHEN** `gh` が 1 回の呼び出しに 3 秒かかる環境で、候補が 1 件ある状態の SessionStart の hook JSON を流す
- **THEN** hook は 1 秒未満で終了コード 0 で終わり、そのあとでコメントが書き込まれる

#### Scenario: 何も出力しない
- **WHEN** 候補が 1 件ある状態と、`gh` がすべて失敗する状態のそれぞれで、`COST_LEDGER_HOOK_FOREGROUND=1` を付けて SessionStart の hook JSON を流す
- **THEN** どちらも stdout と stderr は空で、終了コードは 0

#### Scenario: その場で実行する
- **WHEN** `COST_LEDGER_HOOK_FOREGROUND=1` を付けて、候補が 1 件ある状態の SessionStart の hook JSON を流す
- **THEN** hook が終わった時点でコメントの作成または書き換えが済んでいる

### Requirement: 後追いが動かない条件
システムは次のどれかに当たるとき、`gh` を 1 回も呼ばず、控えファイルも書かずに終わ MUST る。

- 環境変数 `COST_LEDGER_GATE_REPORT=off` または `COST_LEDGER_BACKFILL=off`（このときは `python3` も起動しない）
- `COST_LEDGER_PATH` が未設定（このときは `python3` も起動しない）、または台帳の場所が `cost-ledger-persistence` の定めで書けない場所（プラグインのリポジトリの配下）
- `python3` か `gh` が無い
- hook の `cwd` が git リポジトリでない、origin が無い・読めない、または origin のホストが github.com でない
- hook が引き継いだ環境変数 `GH_HOST` が github.com 以外

有効・無効を切り替える設定項目を持ってはなら MUST NOT ない（上の 2 つの環境変数は緊急停止）。

#### Scenario: 後追いだけを止める
- **WHEN** `COST_LEDGER_BACKFILL=off` を付けて SessionStart の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 既存の緊急停止も効く
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて SessionStart の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれない

#### Scenario: 台帳が未設定
- **WHEN** `COST_LEDGER_PATH` を未設定にして SessionStart の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれない

#### Scenario: github.com でないリポジトリ
- **WHEN** `cwd` のリポジトリの origin が `https://unrelated.example/acme/repo-a.git` の状態で SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、控えファイルは作られない

#### Scenario: git リポジトリでない場所
- **WHEN** `cwd` が git リポジトリでないディレクトリの SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

### Requirement: 候補は前回見た時刻以降の分だけを一覧 1 回で探す
システムは候補を、`cwd` のリポジトリ（origin の `owner/repo`）に対する `gh api` の一覧 1 回（`repos/<owner>/<repo>/issues`、`state=closed`、`since=<前回見た時刻>`、更新時刻の昇順、`per_page=100`、`--paginate`）で SHALL 探す。問い合わせ先は他の呼び出しと同じく github.com に固定 MUST する。

一覧に現れたもののうち、候補にするのは次のどちらかで、出来事の時刻が前回見た時刻より後のものだけと MUST する。

| 種類 | 条件 | 出来事の時刻 | 積む行のきっかけ |
|---|---|---|---|
| PR | `pull_request.merged_at` がある | `pull_request.merged_at` | `マージ` |
| issue | `pull_request` を持たず、`state` が closed | `closed_at` | `issue クローズ` |

マージされずに閉じられた PR は候補にしてはなら MUST NOT ない。出来事の時刻が前回見た時刻以前のもの（更新時刻だけが進んだもの）について、システムは `gh` を追加で呼んではなら MUST NOT ない。一覧が失敗した・応答が読めないとき、システムは何も積まず、控えファイルを変えてはなら MUST NOT ない。

候補は出来事の時刻の昇順（同じ時刻なら番号の昇順）に処理 SHALL する。1 回の実行で処理する候補は 20 件までと SHALL し、残りは次の実行に回す。ただし、20 件目と出来事の時刻が同じ候補は、同じ実行で処理 MUST する。

守備範囲: この判定が受け取る入力は、`gh api` が返す GitHub の一覧の応答と、控えファイルの前回見た時刻に限る。拾いたい誤りは、前回までに見終えたものを毎回問い合わせ直すこと（`gh` の回数が過去の PR / issue の数に比例すること）と、前回見た時刻より後のマージ・クローズを候補から落とすことの 2 つ。次の入力は誤ったまま通ることを許す: 一覧を取った直後の同じ秒のうちに起きたマージ・クローズは、出来事の時刻が前回見た時刻と同じ秒になり、候補から落ちる（時刻は秒単位）／マージされずに閉じられた PR、GitHub の画面で付けたコメント、`Ready`、再オープン、ゲート通過は候補にならない／クローズされたあと、次のセッション開始までに再オープンされた issue は一覧に現れず、候補にならない／別のリポジトリへ移された・削除された issue は候補にならない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 新しいマージ・クローズが無い
- **WHEN** 一覧が 0 件を返す状態で SessionStart の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 1 回で、コメントの作成も書き換えも行われない

#### Scenario: 一覧は前回見た時刻で絞る
- **WHEN** 控えファイルの `acme/cwd-repo` の `seen_until` が `2026-10-07T01:00:00Z` の状態で SessionStart の hook JSON を流す
- **THEN** 一覧の呼び出しは `repos/acme/cwd-repo/issues` に対するもので、`state=closed` と `since=2026-10-07T01:00:00Z` を含む

#### Scenario: 更新されただけのものは問い合わせない
- **WHEN** 前回見た時刻が `2026-10-07T01:00:00Z` で、一覧が、`2026-10-07T00:30:00Z` にマージされ `2026-10-07T01:30:00Z` に更新された PR #300 だけを返す
- **THEN** `gh` が呼ばれた回数は 1 回で、コメントの作成も書き換えも行われない

#### Scenario: マージされずに閉じられた PR は候補にしない
- **WHEN** 一覧が、`pull_request.merged_at` が null で `closed_at` が前回見た時刻より後の PR #301 だけを返す
- **THEN** `gh` が呼ばれた回数は 1 回

#### Scenario: 一覧が失敗する
- **WHEN** 一覧の呼び出しが失敗する環境で SessionStart の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、控えファイルの内容は実行前と同じ

#### Scenario: 1 回の実行は 20 件まで
- **WHEN** 出来事の時刻がすべて違う候補の issue が 25 件ある状態で SessionStart の hook JSON を流す
- **THEN** 既存コメントの取得は 20 件分だけ行われ、控えファイルの `seen_until` は 20 件目の出来事の時刻で、もう一度流すと残りの 5 件が処理される

#### Scenario: 同じ時刻の候補は分けない
- **WHEN** 候補が 21 件あり、20 件目と 21 件目の出来事の時刻が同じ状態で SessionStart の hook JSON を流す
- **THEN** 21 件すべてが処理される

### Requirement: どこまで見たかを台帳の隣に記録する
システムは前回見た時刻を、台帳の隣の控えファイル `<COST_LEDGER_PATH>.backfill.json` に、GitHub の `owner/repo`（小文字）ごとに 1 つ SHALL 記録する。形は `{"version": 1, "repos": {"<owner/repo>": {"seen_until": "<UTC の ISO 8601、秒まで>"}}}`。控えファイルをこのリポジトリの配下に置いてはなら MUST NOT ず、既定のパスを持ってはなら MUST NOT ない。書き込みは、同じディレクトリの一時ファイルに書いてから置き換える形で SHALL 行い、他のリポジトリの値を消してはなら MUST NOT ない。

前回見た時刻は次のとおりに SHALL 進める。今の値より前に戻してはなら MUST NOT ない。

- 一覧が成功し、候補をすべて処理した（候補が 0 件の場合を含む）: 一覧に現れたものの更新時刻（`updated_at`）の最大値。一覧が 0 件なら変えない
- 候補が 1 回の上限を超えて残った: 最後に処理した候補の出来事の時刻
- 一覧が失敗した: 変えない

候補ごとの処理の失敗（`gh` の失敗・タイムアウト・ロックが取れない・`timeline` の失敗）で、前回見た時刻を止めてはなら MUST NOT ない（その 1 件には行が付かないまま先へ進む）。

控えファイルが無い・読めない・形が崩れている・そのリポジトリの値が無いとき、システムは前回見た時刻を「実行した時刻の 24 時間前」として SHALL 扱う。

守備範囲: この記録が受け取る入力は、この処理自身が書いた控えファイルと、GitHub の一覧が返す時刻に限る。拾いたい誤りは、控えが無い状態でリポジトリの全履歴を候補にすること・手元の時計のずれで出来事を見落とすこと・通信が切れていた回のあとで、その間の出来事を見ないまま先へ進むことの 3 つ。次の入力は誤ったまま通ることを許す: 候補ごとの失敗は取り戻さない（一覧は成功したが、その候補の問い合わせや書き込みだけが失敗した場合、その 1 件には最後の行が付かない）／控えファイルを手で未来の時刻に書き換えると、その時刻まで何も候補にならない／控えが無い状態で 24 時間より前に起きたマージ・クローズには付かない／控えは PC ごとで、別の PC の進み具合は見ない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 控えが無い初回
- **WHEN** 控えファイルが無い状態で、一覧が、実行した時刻の 1 時間前にマージされた PR #300 と 48 時間前にクローズされ 1 時間前に更新された issue #12 を返す
- **THEN** 一覧の `since` は実行した時刻の 24 時間前（前後 60 秒以内）で、#300 だけが処理され、控えファイルに `acme/cwd-repo` の `seen_until` が書かれる

#### Scenario: 一覧の更新時刻まで進める
- **WHEN** 前回見た時刻が `2026-10-07T01:00:00Z` で、一覧が、`2026-10-07T02:00:00Z` にマージされ `2026-10-07T02:00:05Z` に更新された PR #300 を返す
- **THEN** 実行後の `seen_until` は `2026-10-07T02:00:05Z`

#### Scenario: 一覧が空なら変えない
- **WHEN** 前回見た時刻が `2026-10-07T01:00:00Z` で、一覧が 0 件を返す
- **THEN** 実行後の `seen_until` は `2026-10-07T01:00:00Z`

#### Scenario: 候補の失敗で止めない
- **WHEN** 候補の PR #300 の書き込みだけが失敗する環境で SessionStart の hook JSON を流す
- **THEN** 実行後の `seen_until` は一覧の更新時刻の最大値まで進んでいる

#### Scenario: 他のリポジトリの値を残す
- **WHEN** 控えファイルに `acme/other` の値がある状態で、`cwd` が `acme/cwd-repo` の SessionStart の hook JSON を流す
- **THEN** 実行後の控えファイルに `acme/other` の値が実行前と同じまま残っている

#### Scenario: 壊れた控え
- **WHEN** 控えファイルの中身が JSON でない状態で SessionStart の hook JSON を流す
- **THEN** 初回と同じく 24 時間前からの一覧が行われ、実行後の控えファイルは読める形になっている

### Requirement: 後追いの行を積む
システムは候補 1 件につき、`cost-ledger-timeline` の定める 1 本のコメントに行を SHALL 積む。きっかけの呼び名は、PR は `マージ`、issue は `issue クローズ` と MUST する（後追い専用の呼び名を作らない）。`cost_ledger.py timeline` には、`--at` に出来事の時刻（epoch 秒）、`--target-repo` に一覧のリポジトリ、`--repo` に hook の `cwd`、そして `--backfill` を渡 MUST す。対象ごとの排他ロック、既存コメントの取得、新規作成と書き換えの使い分け、書き換えに失敗しても新規作成に切り替えないこと、既存コメントの有無が分からなければ書かないことは、`cost-ledger-timeline` の PostToolUse の hook と同じ処理を SHALL 使う。hook は集計・単価・書式・行の有無の判定を自分で持ってはなら MUST NOT ない。

PR の候補は、積む前に `repos/<owner>/<repo>/pulls/<番号>` を問い合わせ、次のすべてを満たすときだけ積 MUST む: マージ済みである／ベースのリポジトリが一覧のリポジトリと一致する（大文字と小文字は区別しない）／ヘッドブランチが同じリポジトリにある（ヘッドのリポジトリがベースのリポジトリと一致する）／ヘッドブランチの名前が空でない。

issue の候補は、一覧が返した状態（closed）をそのまま使い、対象の確認の問い合わせを足してはなら MUST NOT ない。issue を閉じた PR の問い合わせと合計の行は、`cost-ledger-timeline` の「`issue クローズ` では、閉じた PR を合わせた合計の行を積む」に SHALL 従う。

守備範囲: この処理が受け取る入力は、GitHub の一覧と `pulls/<番号>` の応答、既存のコメント本文、手元の台帳に限る。拾いたい誤りは、手元のコストを別のリポジトリの PR / issue に書き出すこと・fork の PR のブランチ名（`main`・`patch-1` など）で手元の同じ名前のブランチのコストを引き込むこと・セッションを始めた時刻で累計を切って、マージのあとの作業まで最後の行に入れることの 3 つ。次の入力は誤ったまま通ることを許す: 同じリポジトリの他人の PR でも、手元に同じ名前のブランチのコストがあれば、その PR に行が付く（`/cost <PR番号>` と共通の、ブランチ名だけで引く既存の性質）／fork から出された PR には、手元で作業していても付かない／別の PC と手元の両方で作業した PR / issue では、行の累計が手元の分だけになる／一覧を取ってから書き込むまでのあいだに再オープンされた issue にも `issue クローズ` の行が付く。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: マージ済みで最後の行が無い PR に 1 行付く
- **WHEN** 前回見た時刻より後にマージされた PR #300（ヘッドブランチ `feat/a` に手元のコストがあり、積み先のコメントには `PR コメント` の行が 1 行ある）が一覧に 1 件ある状態で、`COST_LEDGER_HOOK_FOREGROUND=1` を付けて SessionStart の hook JSON を流す
- **THEN** コメントの書き換えがちょうど 1 回行われ、表の行は 2 行で、2 行目のきっかけは `マージ`、時刻は PR の `merged_at`（ローカル時刻）

#### Scenario: もう一度流しても増えない
- **WHEN** 前の Scenario のあと、GitHub の応答が書き換え後のコメントを返す状態で、同じ hook JSON をもう一度流す
- **THEN** コメントの作成も書き換えも行われず、`gh` が呼ばれた回数は 1 回

#### Scenario: 控えを消して流しても増えない
- **WHEN** 最初の Scenario のあと、控えファイルを消し、GitHub の応答が書き換え後のコメントを返す状態で、同じ hook JSON をもう一度流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 累計はマージの時刻で切る
- **WHEN** ブランチ `feat/a` に、PR #300 の `merged_at` より前の応答（$1.00）と後の応答（$2.00）がある会話ログで、#300 が候補の SessionStart の hook JSON を流す
- **THEN** 積まれた `マージ` の行の金額の累計は `$1.00`

#### Scenario: 自動でクローズされた issue に合計の行まで付く
- **WHEN** 前回見た時刻より後にクローズされた issue #12（区間のコストがあり、`closedByPullRequestsReferences` が同じリポジトリの PR #300・ヘッドブランチ `feat/a` を返す）が一覧に 1 件ある状態で SessionStart の hook JSON を流す
- **THEN** `timeline` は `--issue 12`・`--trigger "issue クローズ"`・`--closing-pr 300:feat/a`・`--backfill` を受け取り、コメントが 1 本書き込まれる

#### Scenario: fork の PR には積まない
- **WHEN** 候補の PR #300 の `pulls/300` の応答で、ヘッドのリポジトリが `someone/cwd-repo`、ベースのリポジトリが `acme/cwd-repo`
- **THEN** 既存コメントの取得もコメントの作成も書き換えも行われない

#### Scenario: 手で積んだ行があれば増やさない
- **WHEN** 候補の PR #300 の積み先のコメントに、`merged_at` の 5 秒後の時刻の `マージ` の行が既にある
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 手元にコストが無い PR には積まない
- **WHEN** 候補の PR #300 のヘッドブランチの行が手元に 1 つも無く、積み先のコメント（別の PC が積んだ行が 1 行）がある
- **THEN** コメントの作成も書き換えも行われない

### Requirement: 後追いの `gh` の呼び出し回数
システムが 1 回のセッション開始で呼ぶ `gh` は、一覧の 1 回に、候補 1 件あたり 3 回（PR は対象の確認・既存コメントの取得・書き込み、issue は既存コメントの取得・閉じた PR の問い合わせ・書き込み）以下を足した数で MUST ある。一覧と既存コメントの取得がコメント 100 件ごとに 1 ページ増える分は、この数に含めない。回数は、そのリポジトリの過去の PR / issue の数にも、前回見た時刻以前にマージ・クローズされたものの数にも比例してはなら MUST NOT ない。

#### Scenario: PR が 1 件
- **WHEN** 候補がマージ済みの PR 1 件だけの状態で SessionStart の hook JSON を流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は 4 回

#### Scenario: issue が 1 件
- **WHEN** 候補がクローズ済みの issue 1 件だけの状態で SessionStart の hook JSON を流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は 4 回

### Requirement: 後追いは同時に 1 つだけ走らせる
システムは裏のプロセスの最初に、`<COST_LEDGER_PATH>.backfill.lock` に待たない排他ロックを SHALL 取り、取れなければ `gh` を呼ばずに終わ MUST る。控えファイルの読み取りから書き込みまでは、このロックを持ったまま行 MUST う。

#### Scenario: 別の後追いが実行中
- **WHEN** `<COST_LEDGER_PATH>.backfill.lock` の排他ロックを別のプロセスが持っている状態で SessionStart の hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、控えファイルの内容は実行前と同じ

#### Scenario: 同時に 2 つ流す
- **WHEN** 候補の PR が 1 件ある状態で、SessionStart の hook JSON を 2 つ同時に流す
- **THEN** 両方が終わったあと、その PR のコメントは 1 本で、`マージ` の行は 1 行
