## MODIFIED Requirements

### Requirement: issue による帰属（第 2 の鍵）
issue 番号はリポジトリ内でしか一意でないため、システムは第 2 の帰属の鍵を **（リポジトリ識別子, issue 番号）の組** と SHALL する。issue 番号だけを鍵にしてはなら MUST NOT ない。

issue 番号は各行の `Bash` ツールの `command` から、`gh issue view`・`gh issue comment`・`gh issue edit`・`gh issue close`・`gh issue reopen`・`gh issue develop` に渡された番号と、コマンドの位置（行頭、または `;` `&&` `||` `|` `(` の直後。前に `VAR=値` の代入が付く形も可。ただし、直前の行がバックスラッシュで終わる行継続の行頭と、直前がバックスラッシュの区切り（`\;` `\|` など、エスケープされて文字として `echo` などに渡るもの）はコマンドの位置としない）にある `gh api` の endpoint（`-X`・`--method` とその値を除いた最初の語。`gh api` と endpoint の間、`-X`・`--method` とその値の前後は同じ行の空白だけでつながっているものに限り、改行をまたいだ次の行の語は endpoint として読まない）が `repos/<owner>/<repo>/issues/<番号>` で始まるときのその番号として拾 SHALL う。`gh api` の endpoint は、番号の直後が英数字・`_` でないとき（`issues/42/comments`・`issues/42?per_page=1`・行末は読み、`issues/42abc` は読まない）だけ拾い、完全な URL・`gh api graphql`・`issues/comments/<id>`・フィールドや `--input` の値の中の文字列は読まなくてよい（コマンドの位置以外の `gh api`（`xargs gh api ...`・`time gh api ...`・`if gh api ...; then` など）、バックスラッシュの行継続で endpoint を次の行に書いた `gh api`、エスケープしたバックスラッシュの直後の区切り（`echo x\\; gh api ...` の `;` は本当の区切りだが、直前がバックスラッシュなので位置としない）の後ろの `gh api` も読まなくてよい。読み落としは許し、その区間はその issue に寄らないだけにして、別の issue へ誤って寄せる方向を避ける）。読み落としの穴を塞ぎ切ることは、この要件の完了条件にしない。`gh issue` の 5 つのサブコマンド（`reopen` 以外）は設計の根拠になった計測（測り方と数字は archive 済みの change `cost-ledger-aggregation` の design に記録。計測スクリプトは change `cost-ledger-gate-report` で削除した）と一致させ、`reopen` と `gh api` は change `cost-ledger-issue-reopen-key` で足した。走査する場所は**実行されたコマンド**に限 SHALL る。その計測はツール呼び出しの入力全体を文字列にして当てていたため、サブエージェントへの指示文やファイル編集の中身に書かれた `gh issue view <番号>` という文字列にも反応した。実行していないコマンドの文字列を根拠に帰属させてはなら MUST NOT ない。ただし例外として、引用符の中の `;` `&` `|` `(` の直後に `gh api repos/<owner>/<repo>/issues/<番号>` が続く文字列（`-f body="x; gh api repos/a/b/issues/99"`）は、正規表現では引用符の内外を区別できないため拾ってよい（まれな形で、塞ぐには引用符を読む解析器が要り範囲外。子 issue #879 で扱う）。同じく例外として、シェルのコメント（行の途中の、語の先頭の `#` より後ろ）の中の `;` `&` `|` `(` の直後に `gh api repos/<owner>/<repo>/issues/<番号>` が続く文字列（`echo ok #; gh api repos/a/b/issues/99`）も拾ってよい。Python の正規表現の後読みは固定長で、同じ行のそれより前にコメントの `#` があるかを見られず、行頭から読ませる形にすると同じ行の 2 つ目以降のコマンド（`gh issue view 5; gh api repos/a/b/issues/6` の 6）を読み落とす。`#` が引用符の中か外かも正規表現では区別できないので、塞ぐには行を読む解析器が要り範囲外。

過去に台帳へ書いた行は書き換え MUST NOT ない。台帳には導いた帰属ではなく事実（触った issue 番号の列）が書かれており、`reopen` と `gh api` を拾う前に書かれた行にはその番号が入っていないが、そのままにして、新しく書く行から拾う。

#### Scenario: 実行していないコマンドの文字列は帰属しない
- **WHEN** `Agent` の指示文や `Edit`・`Write` の本文に `gh issue view 999` または `gh issue reopen 999` という文字列が含まれるが、そのコマンドは実行されていない
- **THEN** その行は issue 999 に帰属しない

#### Scenario: 別リポジトリの同じ番号が混ざらない
- **WHEN** リポジトリ A の issue 108 とリポジトリ B の issue 108 の両方に行が存在する
- **THEN** それぞれの組は別の帰属先として扱われ、合算されない

#### Scenario: main 上の作業が issue に帰属する
- **WHEN** main ブランチ上のセッションで `gh issue comment 148` が実行されている
- **THEN** そのセッションの該当区間のコストは、そのリポジトリの issue 148 へ帰属する

#### Scenario: close と develop も鍵になる
- **WHEN** セッション中に `gh issue close 273` または `gh issue develop 273` だけが実行されている
- **THEN** その区間は issue 273 へ帰属する

#### Scenario: reopen も鍵になる
- **WHEN** セッション中に `gh issue reopen 42` だけが実行されている
- **THEN** その区間は issue 42 へ帰属する

#### Scenario: gh api の issues endpoint も鍵になる
- **WHEN** セッション中に `gh api -X POST repos/acme/app/issues/42/comments -f body=x` または `gh api -X PATCH repos/acme/app/issues/42 -f state=open` だけが実行されている
- **THEN** その区間は issue 42 へ帰属する

#### Scenario: 引数の値の中の gh api は鍵にならない
- **WHEN** セッション中に `gh api -X POST repos/acme/app/issues/42/comments -f body="gh api repos/acme/app/issues/99"` だけが実行されている
- **THEN** その区間は issue 42 へ帰属し、issue 99 には帰属しない

#### Scenario: 引用符の中の区切りの直後の gh api は例外として拾う
- **WHEN** セッション中に `gh api -X POST repos/acme/app/issues/42/comments -f body="x; gh api repos/acme/app/issues/99"` だけが実行されている
- **THEN** 現状は issue 42 と 99 の両方が拾われ、最後の 99 に帰属する（既知の例外。子 issue #879 で扱う）

#### Scenario: シェルのコメントの中の区切りの直後の gh api は例外として拾う
- **WHEN** セッション中に `echo ok #; gh api repos/acme/app/issues/99` だけが実行されている
- **THEN** 現状は issue 99 が拾われ、99 に帰属する（既知の例外。同じ行のそれより前の `#` は正規表現から見えない）

#### Scenario: エスケープした区切りと行継続の後ろの gh api は鍵にならない
- **WHEN** セッション中に `echo x\; gh api repos/acme/app/issues/99`、`echo x\| gh api repos/acme/app/issues/99`、または行末のバックスラッシュで次の行に続けた `echo x \` と `gh api repos/acme/app/issues/99` の 2 行だけが実行されている
- **THEN** その区間はどの issue にも帰属しない

#### Scenario: gh api は次の行の語を endpoint として読まない
- **WHEN** セッション中に、`gh api` または `gh api -X POST` で終わる行と、その次の行の `repos/acme/app/issues/42` だけが実行されている
- **THEN** その区間はどの issue にも帰属しない

#### Scenario: コマンドの位置にある gh api は鍵になる
- **WHEN** セッション中に `cd x && gh api repos/acme/app/issues/42`、行頭の `GH_TOKEN=x gh api repos/acme/app/issues/42` のいずれかだけが実行されている
- **THEN** その区間は issue 42 へ帰属する

#### Scenario: コマンドの位置以外の gh api は読み落とす
- **WHEN** セッション中に `xargs gh api repos/acme/app/issues/42` だけが実行されている
- **THEN** その区間はどの issue にも帰属しない

#### Scenario: コメントの編集や別の endpoint は鍵にならない
- **WHEN** セッション中に `gh api -X PATCH repos/acme/app/issues/comments/777`、`gh api repos/acme/app/issues/42abc` または `gh api graphql -f query=...` だけが実行されている
- **THEN** その区間はどの issue にも帰属しない

#### Scenario: issue 番号を一度も触っていないセッション
- **WHEN** セッション中に上記のコマンドが一度も実行されていない
- **THEN** そのセッションのコストはどの issue にも帰属せず、未帰属として扱われる

#### Scenario: 過去の行は書き換えない
- **WHEN** `reopen` を拾う前に台帳へ書かれた、`gh issue reopen 42` を実行した行（触った issue 番号の列が空）がある状態で新しい版を動かす
- **THEN** その行は書き換えられず、issue 42 には寄らない
