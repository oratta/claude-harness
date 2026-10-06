## ADDED Requirements

### Requirement: 行を積むきっかけ
システムは、PostToolUse の hook（`plugins/cost-ledger/scripts/gate-report.sh`）が受け取った `tool_input.command` に次のいずれかが含まれるとき、その対象の PR / issue に行を 1 行積 MUST む。行の「きっかけ」の欄には表の呼び名を SHALL 書く。

| コマンド | きっかけ |
|---|---|
| `gh pr comment` | `PR コメント` |
| `gh issue comment` | `issue コメント` |
| `gh pr ready`（`--undo` を除く） | `Ready` |
| `gh pr close` | `PR クローズ` |
| `gh pr merge` | `マージ` |
| `gh issue close` | `issue クローズ` |
| `gh issue reopen` | `issue 再オープン` |
| 合格ラベル `agent-review:passed` の付与（判定は `cost-ledger-gate-report`） | `ゲート通過` |

これ以外のコマンド（`gh pr view`・`gh issue view`・`gh pr create`・`gh pr reopen`・`gh api` の直叩きでの投稿など）で行を積んではなら MUST NOT ない。コマンドの読み取りは `cost-ledger-gate-report` の付与の判定と同じ規則（同じコマンドの中の単純な代入と `for` の展開、サブシェルの扱い）に従い、コマンドを評価・再実行してはなら MUST NOT ない。文字列として含むだけ（`echo "gh pr comment 300"` など）のコマンドで積んではなら MUST NOT ない。

1 つのコマンドに同じ対象へのきっかけが複数あるとき、システムは行を 1 行だけ積み、きっかけを実行順に `+` でつな SHALL ぐ。

#### Scenario: 7 種のコマンドで同じコメントに 1 行ずつ増える
- **WHEN** 同じ PR に `gh pr comment`・`gh pr ready`・`gh pr close`・`gh pr merge` を、同じ issue に `gh issue comment`・`gh issue close`・`gh issue reopen` を、それぞれ別の hook 呼び出しとして順に流す（GitHub の応答は各コマンドが成功した状態を返す）
- **THEN** PR と issue のそれぞれで、コメントの新規作成は最初の 1 回だけで、以後は同じコメントが書き換えられ、流すたびに表の行が 1 行ずつ増える

#### Scenario: 対象外の gh コマンドでは積まない
- **WHEN** `gh pr view 300` や `gh pr create --title x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 文字列として含むだけでは積まない
- **WHEN** `echo "gh pr comment 300 --body x"` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 1 つのコマンドに複数のきっかけ
- **WHEN** `gh pr comment 300 --body x && gh pr ready 300` の hook JSON を流す
- **THEN** #300 に積まれる行は 1 行で、きっかけの欄は `PR コメント+Ready`

### Requirement: 対象の解決
システムは対象の番号を、最初の位置引数が数字ならその番号、`https://github.com/<owner>/<repo>/pull/<番号>` または `.../issues/<番号>` の URL ならそのリポジトリと番号として SHALL 求める。`gh pr comment`・`gh pr ready`・`gh pr merge` で位置引数が無いときは、hook の `cwd` の現在のブランチをヘッドに持つ PR を対象と SHALL する。それ以外の形（ブランチ名の位置引数、解決できない変数）は積まずに飛ば MUST す。

リポジトリは gh と同じ順で、`-R` / `--repo`、無ければその呼び出しの前置きの `GH_REPO=値`、どちらも無ければ hook の `cwd` のリポジトリと SHALL する。

`gh issue comment` などの issue 向けのコマンドに渡された番号が PR だったとき、システムはそれを PR として扱 SHALL う。

#### Scenario: 番号を渡す
- **WHEN** `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `cwd` のリポジトリの #300 が対象になる

#### Scenario: URL を渡す
- **WHEN** `gh issue comment https://github.com/acme/other/issues/12 --body x` の hook JSON を流す
- **THEN** acme/other の #12 が対象になる

#### Scenario: 番号を省く
- **WHEN** `cwd` のブランチをヘッドに持つ PR #300 がある状態で `gh pr ready` の hook JSON を流す
- **THEN** #300 が対象になる

#### Scenario: -R で別のリポジトリを指す
- **WHEN** `gh pr comment 300 -R acme/other --body x` の hook JSON を流す
- **THEN** acme/other の #300 が対象になる

#### Scenario: 解決できない番号は飛ばす
- **WHEN** `gh pr comment "$(gh pr view --json number -q .number)" --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

### Requirement: 状態の変更は実測してから積む
システムは状態を変えるきっかけについて、積む前に GitHub に問い合わせ、その状態になっていることを確かめ MUST る。`Ready` は `draft` が false、`PR クローズ` と `issue クローズ` は `state` が closed、`マージ` はマージ済み、`issue 再オープン` は `state` が open、`ゲート通過` はラベルが付いていること。なっていなければ、そのきっかけでは積んではなら MUST NOT ない。コメントのきっかけは、対象が存在することだけを確かめ SHALL る。

#### Scenario: マージされていない
- **WHEN** `gh pr merge 300 --auto` の hook JSON を流し、問い合わせた PR がマージ済みでない
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: クローズに失敗していた
- **WHEN** `gh issue close 12` の hook JSON を流すが、問い合わせた issue の `state` が open
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 存在しない番号
- **WHEN** `gh pr comment 999 --body x` の hook JSON を流すが、#999 の問い合わせが失敗する
- **THEN** コメントの作成も書き換えも行われない

### Requirement: 1 本のコメントに行を積む
システムは PR / issue 1 件につき、`<!-- cost-ledger:timeline` で始まる行を持つコメントを 1 本だけ SHALL 保つ。そのコメントが既にあれば `gh api -X PATCH` で本文を書き換え、無ければ新規作成 MUST する。書き換えでは既存の表の行をそのまま残し、末尾に 1 行だけ足 MUST す。既存の行を書き換えても削除してもなら MUST NOT ない。書き換えに失敗したときに新規作成へ切り替えてはなら MUST NOT ない。既存のコメントの有無が分からなかった（検索が失敗した）ときは、書いてはなら MUST NOT ない。

本文は次の構成と SHALL する。

1. 1 行目: 最新の累計の行。`/cost <その番号>` の出力の 1 行目と同じ行で、`headline()` が作る
2. 空行をはさんで Markdown の表。見出しは `| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |`
3. 空行をはさんで最終行: `<!-- cost-ledger:timeline v1 usd=<金額> io=<入出力トークン> cache=<キャッシュトークン> -->`（最新の累計の丸める前の値）

古い目印 `<!-- cost-ledger:gate-report -->` を持つコメントは、探しても書き換えても削除してもなら MUST NOT ない。

#### Scenario: 初回
- **WHEN** 目印付きのコメントが無い PR に `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** コメントが 1 本新規作成され、1 行目が `コスト: ` で始まり、表の行が 1 行で、最終行が `<!-- cost-ledger:timeline v1 ` で始まる

#### Scenario: 2 回目以降
- **WHEN** 目印付きのコメント（表の行が 2 行）がある PR に `gh pr ready 300` の hook JSON を流す
- **THEN** そのコメントが PATCH で書き換えられ、新しいコメントは作成されず、表の行は 3 行で、先頭の 2 行は書き換え前と同じ

#### Scenario: 書き換えに失敗する
- **WHEN** PATCH が失敗する環境で、目印付きのコメントがある PR にきっかけの hook JSON を流す
- **THEN** 新しいコメントは作成されない

#### Scenario: 古い形のコメントには触らない
- **WHEN** `<!-- cost-ledger:gate-report -->` を持つコメントだけがある PR にきっかけの hook JSON を流す
- **THEN** 新しいコメントが 1 本作成され、古いコメントへの PATCH は行われない

### Requirement: 行の書式
システムは表の 1 行を `| <時刻> | <きっかけ> | <金額> | <入出力> | <キャッシュ> |` と SHALL する。この行を作る実装は `cost_ledger.py` の 1 か所（`timeline_row()`）だけと MUST する。

- 時刻: きっかけのコマンドを実行した時刻（hook が起動した時刻）を、実行したマシンのローカル時刻で `MM/DD HH:MM`
- 金額・入出力・キャッシュ: どれも `<累計> (<符号つきの増分>)`。増分は前の行の累計との差で、0 以上は `+`、負は `-` を付ける。初回の増分は累計と同じ値
- 金額: `$` と小数 2 桁、3 桁区切り。増分には `$` を付けない（例: `$39.62 (+23.02)`）
- トークン: 1,000 未満はそのままの整数、1,000,000 未満は整数の `K`、10,000,000 未満は小数 1 桁の `M`、1,000,000,000 未満は整数の `M`、それ以上は小数 1 桁の `B`（例: `900K`・`2.1M`・`81M`・`1.2B`）
- 入出力トークンは入力トークンと出力トークンの和、キャッシュトークンはキャッシュ書き込み（5 分・1 時間）とキャッシュ読み出しの和。単価が引けないモデルの行のトークンも数える

#### Scenario: 2 行目の増分
- **WHEN** 前の累計が $16.60・入出力 900,000・キャッシュ 33,000,000 のコメントに、累計が $39.62・入出力 2,100,000・キャッシュ 81,000,000 の時点で 1 行積む
- **THEN** 足された行の金額は `$39.62 (+23.02)`、入出力は `2.1M (+1.2M)`、キャッシュは `81M (+48M)`

#### Scenario: 初回の行
- **WHEN** コメントが無い状態で、累計が $16.60 の時点で 1 行積む
- **THEN** 足された行の金額は `$16.60 (+16.60)`

#### Scenario: 累計が減った
- **WHEN** 前の累計が $5.00 のコメントに、累計が $3.80 の時点で 1 行積む
- **THEN** 足された行の金額は `$3.80 (-1.20)`

#### Scenario: 未知モデルのトークンも数える
- **WHEN** 料金表に無いモデルの応答（入力 1,000 トークン）だけがあるブランチで 1 行積む
- **THEN** 金額は `$0.00`、入出力は `1K` で始まる

### Requirement: 前の節目の値はコメントの最終行から読む
システムは増分の計算に使う前の累計を、既存のコメントの最終行（`<!-- cost-ledger:timeline v1 usd=... io=... cache=... -->`）から SHALL 読む。表に表示した丸めた数字から読み戻してはなら MUST NOT ない。前の値を手元のファイルに保存してはなら MUST NOT ない（別のマシンから同じ PR に積んでも増分がつながるようにするため）。

最終行が読めないとき、システムは 3 項目の増分を `(?)` と書き、0 として計算してはなら MUST NOT ない。

#### Scenario: 丸めの誤差を持ち越さない
- **WHEN** 最終行が `usd=16.604000 io=949999 cache=33000000` のコメントに、累計の入出力が 1,050,001 の時点で 1 行積む
- **THEN** 入出力の増分は `+100K`（表示の `950K` と `1.1M` の差ではなく、正確な値の差）

#### Scenario: 最終行が壊れている
- **WHEN** 目印の行はあるが `usd=` の値が数値でないコメントに 1 行積む
- **THEN** 足された行の増分は 3 項目とも `(?)` で、新しい最終行には今回の累計が書かれる

### Requirement: 数字と書式は `timeline` サブコマンドから取る
システムは `cost_ledger.py timeline` を持ち、標準入力で既存のコメント本文（無ければ空）を受け取って、行を 1 行足した新しい本文を標準出力に返 MUST す。hook は集計・単価・書式を自分で持ってはなら MUST NOT ない。`timeline` は PR か issue かの判別のために `gh` を呼んではなら MUST NOT ない（hook が判別して `--pr <番号> --branch <ヘッドブランチ>` か `--issue <番号>` で渡す）。

累計は、PR では `cost_ledger.py cost <PR番号>` と、issue では `cost_ledger.py cost <issue番号>` と同じ値で MUST ある。`COST_LEDGER_PATH` があるときは、他の集計系サブコマンドと同じく、読む前に会話ログの差分を台帳へ追記してから台帳を読 SHALL む。

次のときは何も出力せず終了コード 3 を返し、hook は何も書いてはなら MUST NOT ない。

- 累計の金額が 0 で、既存のコメント本文が空
- issue が対象で、対象のリポジトリ（`--target-repo`）が `--repo` の場所のリポジトリと一致しない

#### Scenario: 1 行目が `/cost` と一致する
- **WHEN** 同じ会話ログで `cost_ledger.py timeline --pr 300 --branch <ブランチ> ...` と `cost_ledger.py cost 300` を実行する
- **THEN** `timeline` の出力の 1 行目と `cost` の出力の 1 行目が一致する

#### Scenario: issue の累計が `/cost` と一致する
- **WHEN** issue #12 に帰属する区間がある会話ログで `cost_ledger.py timeline --issue 12 ...` と `cost_ledger.py cost 12` を実行する
- **THEN** `timeline` の出力の 1 行目と `cost` の出力の 1 行目が一致する

#### Scenario: 最後の追記以降の応答も含む
- **WHEN** `ledger-sync` のあとで会話ログに応答が増え、Stop hook を待たずに `timeline` を実行する
- **THEN** 増えた応答も累計に含まれる

#### Scenario: コストが無くコメントも無い
- **WHEN** そのブランチの行が 1 つも無い状態で、標準入力を空にして `timeline --pr 300 --branch <ブランチ>` を実行する
- **THEN** 出力は空で、終了コードは 3

#### Scenario: 別リポジトリの issue
- **WHEN** `cwd` が acme/repo-a のリポジトリで、`gh issue comment 12 -R acme/repo-b --body x` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

### Requirement: issue の集計は関係するセッションだけを読む
`COST_LEDGER_PATH` があるとき、システムは issue の累計を、台帳のうちその issue 番号を触った行を持つセッションの行だけを読んで SHALL 求める。結果は台帳の全行を読んで区間に切った場合と同じで MUST ある。`cost_ledger.py cost <issue番号>` と `cost_ledger.py issue <番号>` も同じ読み方を SHALL 使う。

#### Scenario: 絞っても値が変わらない
- **WHEN** 複数のセッションが複数の issue を触っている会話ログを台帳へ取り込み、`cost_ledger.py issue <番号> --json` を実行する
- **THEN** `total_usd`・`messages`・`intervals` は、`COST_LEDGER_PATH` を未設定にして同じ会話ログを直接読んだ場合と同じ

### Requirement: hook は判定だけをして、残りを裏で行う
システムは hook の同期部分でコマンド文字列の判定だけを行い、対象が見つかったら、GitHub への問い合わせ・集計・書き込みを hook のプロセスから切り離した別プロセスで行 MUST う。同期部分で `gh` を呼んだり台帳や会話ログを読んだりしてはなら MUST NOT ない。hook は裏のプロセスの終了を待たずに終了コード 0 で終わ MUST る。

同期部分も裏のプロセスも、stdout と stderr に何も出してはなら MUST NOT ない（会話の文脈に何も入れない）。どの失敗でも、hook は終了コード 0 で終わる。

環境変数 `COST_LEDGER_HOOK_FOREGROUND=1` のとき、システムは切り離さずにその場で最後まで実行 SHALL する（テストと実測のため）。

#### Scenario: gh が遅くても hook はすぐ終わる
- **WHEN** `gh` が 1 回の呼び出しに 3 秒かかる環境で `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** hook は 1 秒未満で終了コード 0 で終わり、そのあとでコメントが作成される

#### Scenario: 何も出力しない
- **WHEN** きっかけの hook JSON を流す
- **THEN** hook の stdout と stderr は空

#### Scenario: その場で実行する
- **WHEN** `COST_LEDGER_HOOK_FOREGROUND=1` を付けてきっかけの hook JSON を流す
- **THEN** hook が終わった時点でコメントの作成または書き換えが済んでいる

### Requirement: 同じコメントへの同時の書き込みで行を失わない
システムは対象（リポジトリと番号）ごとの排他ロックを取ってから、コメントの読み取り・行の追加・書き込みを MUST 行う。同じマシンで同じ対象への処理が同時に走っても、積まれる行の数は処理の数と一致しなければなら MUST ない。

#### Scenario: 同時に 2 つ流す
- **WHEN** 目印付きのコメントが無い PR に、きっかけの hook JSON を 2 つ同時に流す
- **THEN** コメントは 1 本で、表の行は 2 行

### Requirement: `gh` の呼び出し回数
システムが 1 行積むために呼ぶ `gh` は、対象 1 件あたり 3 回（対象の確認・既存コメントの取得・書き込み）以下で MUST ある。既存コメントの取得がコメント 100 件ごとに 1 ページ増える分と、issue 向けのコマンドに渡された番号が PR だったときの 1 回は、この数に含めない。回数は、その PR / issue に既に積まれている行の数に比例してはなら MUST NOT ない。

#### Scenario: PR へのコメント
- **WHEN** `gh pr comment 300 --body x` の hook JSON を流す（コメントは 100 件未満）
- **THEN** `gh` が呼ばれた回数は 3 回

#### Scenario: 対象が 2 件
- **WHEN** `gh issue comment 12 --body x; gh pr comment 300 --body y` の hook JSON を流す
- **THEN** `gh` が呼ばれた回数は 6 回
