## ADDED Requirements

### Requirement: パスごとに open の issue を 1 回検索して番号と題名を返す

`plugins/dev-workflow/scripts/review-issue-candidates.sh` は、`--repo <owner>/<name>` と 1 つ以上のファイルのパスを受け取り、パスごとに `gh issue list --repo <owner>/<name> --state open --search '"<ファイル名>" in:title,body'` を 1 回だけ実行しなければならない（MUST）。`<ファイル名>` は渡されたパスの最後の要素とする（MUST）。同じ文字列のパスが複数回渡されたときは、最初の 1 つだけを検索する（MUST）。

出力は、パスごとに `== <渡されたパス>` の見出し行を渡された順に出し、その下に候補を 1 行 1 件で `<番号><TAB><題名>` と出さなければならない（MUST）。題名に含まれるタブは空白 1 個に置き換える（MUST）。issue の本文を出力してはならない（MUST NOT）。候補が 0 件のパスは、見出し行の下に `(該当なし)` の 1 行を出す（MUST）。

#### Scenario: 2 つのパスを渡すと、パスごとに 1 回ずつ検索する

- **WHEN** `review-issue-candidates.sh --repo o/r plugins/x/scripts/pr-state.sh plugins/x/stages/triage.md` を実行する
- **THEN** `gh issue list` が 2 回だけ呼ばれ、検索語はそれぞれ `"pr-state.sh" in:title,body` と `"triage.md" in:title,body` で、どちらも `--state open` と `--repo o/r` が付いている

#### Scenario: 候補は見出し行の下に番号と題名で出る

- **WHEN** `plugins/x/stages/triage.md` の検索が #886「triage.md の --repo を明記する」と #578「bats を triage.md に向ける」を返す
- **THEN** 標準出力は `== plugins/x/stages/triage.md` の行に続けて `886<TAB>triage.md の --repo を明記する` と `578<TAB>bats を triage.md に向ける` の 2 行で、終了コードは 0 である

#### Scenario: 候補が無いパスは該当なしと出る

- **WHEN** あるパスの検索が 0 件を返す
- **THEN** そのパスの見出し行の下に `(該当なし)` の 1 行が出て、終了コードは 0 である

#### Scenario: 同じパスを 2 回渡しても検索は 1 回

- **WHEN** 同じ文字列のパスを 2 回渡して実行する
- **THEN** `gh issue list` はそのパスについて 1 回だけ呼ばれ、見出し行も 1 つだけ出る

#### Scenario: 本文は出力に含まれない

- **WHEN** 検索が返した issue の本文に、題名に無い文字列が入っている
- **THEN** その文字列は標準出力に現れず、`gh issue list` の `--json` に `body` を指定していない

### Requirement: 外す番号を除き、パスごとに最大 15 件で打ち切る

`review-issue-candidates.sh` は `--exclude <番号>` を 0 回以上受け取り、その番号の issue を候補から除かなければならない（MUST）。除いたあとの候補が 15 件を超えるパスでは、検索が返した順の先頭 15 件だけを出し、そのパスの最後に `(15 件で打ち切り。ほかにも一致あり)` の 1 行を出さなければならない（MUST）。15 件以下のパスにはこの行を出してはならない（MUST NOT）。

除いたあとに 15 件を超えるかを判定できるよう、`gh issue list` の `--limit` には「15 ＋ `--exclude` の個数 ＋ 1」を渡す（MUST）。

#### Scenario: 外す番号は候補に出ない

- **WHEN** `--exclude 973 --exclude 980` を付けて実行し、検索が #973 と #886 を返す
- **THEN** 出力に #886 の行はあり、#973 の行は無い

#### Scenario: 外す番号の分だけ多く取り寄せる

- **WHEN** `--exclude` を 2 つ付けて実行する
- **THEN** `gh issue list` は `--limit 18` で呼ばれる

#### Scenario: 16 件以上あれば 15 件で打ち切ったと出る

- **WHEN** 外す番号を除いたあとの候補が 16 件ある
- **THEN** 候補の行は検索が返した順の先頭 15 件だけで、その後に `(15 件で打ち切り。ほかにも一致あり)` の 1 行が出る

#### Scenario: ちょうど 15 件なら打ち切りの行は出ない

- **WHEN** 外す番号を除いたあとの候補がちょうど 15 件ある
- **THEN** 候補の行は 15 件で、`(15 件で打ち切り。ほかにも一致あり)` の行は出ない

### Requirement: エピックを指定すると子かどうかを添え、子だけに絞ることもできる

`review-issue-candidates.sh` は `--epic <番号>` を受け取ったとき、実行の最初に `gh api` で `repos/<owner>/<name>/issues/<番号>/sub_issues` を全ページ取り、各候補の行の 3 列目に、番号がその一覧にあれば `child`、無ければ `other` を足さなければならない（MUST）。この呼び出しは、パスの数によらず 1 回の実行につき 1 回とする（MUST）。`--epic` が無いとき、候補の行は 2 列でなければならない（MUST）。

`--epic <番号>` と `--children-only` の両方を受け取ったときは、`sub_issues` を取らず、各パスの検索語に `parent-issue:<owner>/<name>#<番号>` を足して検索の側で子だけに絞り、候補の行の 3 列目をすべて `child` にしなければならない（MUST）。このときも検索はパスごとに 1 回とする（MUST）。

#### Scenario: エピックの子とそれ以外を見分ける

- **WHEN** `--epic 725` を付けて実行し、`sub_issues` が #721 を含み #886 を含まず、検索が #721 と #886 を返す
- **THEN** #721 の行の 3 列目は `child`、#886 の行の 3 列目は `other` である

#### Scenario: 子の一覧は 1 回だけ取る

- **WHEN** `--epic 725` を付けて 3 つのパスを渡して実行する
- **THEN** `repos/o/r/issues/725/sub_issues` への `gh api` の呼び出しは 1 回だけで、`gh issue list` は 3 回である

#### Scenario: 子だけに絞ると検索語に親の指定が足される

- **WHEN** `--repo o/r --epic 725 --children-only plugins/x/stages/triage.md` を実行する
- **THEN** `gh issue list` の検索語は `"triage.md" in:title,body parent-issue:o/r#725` で、`sub_issues` への `gh api` の呼び出しは無く、候補の行の 3 列目はすべて `child` である

#### Scenario: エピックを指定しなければ 2 列

- **WHEN** `--epic` を付けずに実行する
- **THEN** 候補の行は `<番号><TAB><題名>` の 2 列で、`gh api` は呼ばれない

### Requirement: 検索に失敗したら候補なしと区別できる形で終わる

`review-issue-candidates.sh` は、`gh issue list` または `gh api` の呼び出しが 1 つでも失敗したとき、標準出力に何も出さず、標準エラーに失敗した呼び出しが分かる 1 行以上を出し、終了コード 1 で終わらなければならない（MUST）。先に済んだパスの結果も出してはならない（MUST NOT）。

引数の不備と、`gh` または `jq` が無いときは、検索を 1 回も実行せず、標準エラーに理由を出し、終了コード 2 で終わらなければならない（MUST）。引数の不備は次のとおり: パスが 1 つも無い、`--repo` が無いか `<owner>/<name>` の形でない、`--exclude` または `--epic` の値が 1 以上の整数でない、`--children-only` があるのに `--epic` が無い、知らないオプション、最後の要素が空のパス（空文字や `/` で終わるパス）、ファイル名に `"` を含むパス。

全パスの検索が済んだときは、候補が 0 件でも終了コード 0 で終わらなければならない（MUST）。

#### Scenario: 2 つ目のパスの検索が失敗したら何も出さない

- **WHEN** 2 つのパスを渡し、1 つ目の検索は候補を返し、2 つ目の `gh issue list` が非 0 で終わる
- **THEN** 標準出力は空で、標準エラーに失敗が書かれ、終了コードは 1 である

#### Scenario: 子の一覧が取れなければ検索に進まない

- **WHEN** `--epic 725` を付けて実行し、`sub_issues` への `gh api` が非 0 で終わる
- **THEN** 標準出力は空で、終了コードは 1 である

#### Scenario: パスが無ければ終了コード 2

- **WHEN** `review-issue-candidates.sh --repo o/r` をパスなしで実行する
- **THEN** `gh` は 1 回も呼ばれず、終了コードは 2 である

#### Scenario: リポジトリの指定が無ければ終了コード 2

- **WHEN** `--repo` を付けずにパスだけを渡して実行する
- **THEN** `gh` は 1 回も呼ばれず、終了コードは 2 である

#### Scenario: 数字でない番号は終了コード 2

- **WHEN** `--exclude abc` または `--epic '#725'` を付けて実行する
- **THEN** `gh` は 1 回も呼ばれず、終了コードは 2 である

#### Scenario: エピックなしの子だけ指定は終了コード 2

- **WHEN** `--children-only` を `--epic` なしで付けて実行する
- **THEN** `gh` は 1 回も呼ばれず、終了コードは 2 である

#### Scenario: ファイル名を取り出せないパスは終了コード 2

- **WHEN** `plugins/x/` のように `/` で終わるパス、またはファイル名に `"` を含むパスを渡して実行する
- **THEN** `gh` は 1 回も呼ばれず、終了コードは 2 である

#### Scenario: 全パスが 0 件でも終了コード 0

- **WHEN** 渡したパスの検索がすべて 0 件を返す
- **THEN** 各パスの見出し行と `(該当なし)` が出て、終了コードは 0 である
