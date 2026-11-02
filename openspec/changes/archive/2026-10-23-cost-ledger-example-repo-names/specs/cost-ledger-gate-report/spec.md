## MODIFIED Requirements

### Requirement: ラベル付与コマンドの判定と対象 PR の取り出し
システムは `tool_input.command` が `agent-review:passed` の**付与**であるときだけ投稿に進 MUST む。付与とは、endpoint が `repos/<リポジトリ>/issues/<番号>/labels` の `gh api` 呼び出しで、同じ呼び出しのフィールド（`-f` / `--raw-field` / `-F` / `--field` の値）に `labels[]=agent-review:passed` があり、メソッドの指定が無い（フィールドがあるので gh の既定は POST）か POST・PUT のもの、または `gh pr edit` / `gh issue edit` の `--add-label` の値に `agent-review:passed` を含むものと SHALL する。`gh api` の endpoint・メソッド・フィールドは `cost-ledger-timeline` の「`gh api` の呼び出しの読み方」に従って読み、endpoint 以外の引数（`--input` の値など）からラベルのパスを拾ってはなら MUST NOT ない。endpoint の `<リポジトリ>` が gh の置き換え記法 `{owner}/{repo}` のときは、`cost-ledger-timeline` の「対象の解決」が `gh api` のきっかけに定めるのと同じ規則（その呼び出しの前置きの `GH_REPO=値` があればそのリポジトリ、無ければ hook の `cwd` のリポジトリ）で読み、付与と SHALL 見る。ラベルを外すコマンドや、文字列として `agent-review:passed` を含むだけのコマンドで投稿してはなら MUST NOT ない。

対象のリポジトリと番号は、コマンド文字列のリテラルに加えて、同じコマンドの中の単純な代入（`NAME=値`）と `for NAME in <リテラルの並び>; do` から `$NAME` / `${NAME}` を展開して SHALL 求める。`for` の場合は並びの各値を対象とする。`( )` のサブシェルの中の代入は、括弧の外の展開に使ってはなら MUST NOT ない。`gh pr edit` / `gh issue edit` のリポジトリは gh と同じ順で、`-R` / `--repo`、無ければその呼び出しの前置きの `GH_REPO=値`、どちらも無ければ hook の `cwd` のリポジトリと SHALL する。解決できなかった対象は投稿せずに飛ば MUST す。解決のためにコマンドを評価・再実行してはなら MUST NOT ない。

守備範囲: この判定が受け取る入力は、PostToolUse が渡す `tool_input.command`（Claude Code のセッションが Bash ツールで実行したコマンド文字列）と hook の `cwd` に限る。拾いたい誤りは、付与でないコマンド（ラベルを外す・ラベル名を文字列として含むだけ・オプションの値にラベルのパスやラベル名があるだけ）で投稿に進むことと、コマンドが触れていない PR を対象にすることの 2 つ。次の入力は誤ったまま通ることを許す: `--input` で渡した JSON の中の `labels` は見えず、付与と見ない／`gh pr edit` / `gh issue edit` の最初の位置引数が数字でないもの（ブランチ名、URL、位置引数を省いて現在のブランチの PR に付ける形）は対象にならない／`--add-label` を、語を分けた `--add-label 値` と `--add-label=値` 以外の書き方で渡したものは付与と見ない／`eval`・`bash -c '...'`・シェル関数・エイリアス・スクリプトファイルの中の付与は見えない／`gh api graphql` の mutation での付与は見えない／`false && gh pr edit 300 --add-label agent-review:passed` のように実行されなかった付与や、失敗した付与でもこの判定は通る（「付与を実測してから貼る」で落ちる。ラベルが前から付いていた PR では落ちず、投稿に進む）／`gh issue edit --add-label` を PR でない issue に向けたものもこの判定は通る（対象を PR として確かめる段で落ちる）／endpoint を完全な URL や `:owner/:repo` で書いた付与は対象にならない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: リテラルの付与コマンド
- **WHEN** `gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** oratta/claude-harness の #300 が投稿の対象になる

#### Scenario: `{owner}/{repo}` の endpoint での付与
- **WHEN** `gh api repos/{owner}/{repo}/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** `cwd` のリポジトリの #300 が投稿の対象になる。同じ呼び出しに前置きの `GH_REPO=acme/other` があれば acme/other の #300 が対象になり、前置きの値が解決できなければ投稿せずに飛ばす

#### Scenario: 同じコマンドで代入した変数の付与コマンド
- **WHEN** `R=oratta/claude-harness; N=300` のあとに `gh api -X POST repos/$R/issues/$N/labels -f 'labels[]=agent-review:passed'` が続くコマンドの hook JSON を流す
- **THEN** oratta/claude-harness の #300 が投稿の対象になる

#### Scenario: for で複数 PR に付与する
- **WHEN** `R=acme/repo-k` のあと `for N in 96 97; do` の中で `repos/$R/issues/$N/labels` に付与するコマンドの hook JSON を流す
- **THEN** #96 と #97 の両方が投稿の対象になる

#### Scenario: gh pr edit で付与する
- **WHEN** `gh pr edit 313 --remove-label agent-review:pending --add-label agent-review:passed` の hook JSON を流す
- **THEN** `cwd` のリポジトリの #313 が投稿の対象になる

#### Scenario: 前置きの GH_REPO で付与する
- **WHEN** `GH_REPO=acme/other gh pr edit 300 --add-label agent-review:passed` の hook JSON を流す
- **THEN** acme/other の #300 が投稿の対象になり、`cwd` のリポジトリは問い合わせない。前置きの値が解決できなければ投稿せずに飛ばす

#### Scenario: サブシェルの中の代入は外に効かない
- **WHEN** `N=300; (N=5; echo x); gh api -X POST repos/oratta/claude-harness/issues/$N/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** oratta/claude-harness の #300 が投稿の対象になり、#5 は対象にならない

#### Scenario: ラベルを外すコマンドでは投稿しない
- **WHEN** `gh api -X DELETE repos/oratta/claude-harness/issues/300/labels/agent-review:passed` だけのコマンドの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: GET を明示した呼び出しでは投稿しない
- **WHEN** `gh api -X GET repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 解決できない変数は飛ばす
- **WHEN** 番号が `N=$(gh pr view --json number -q .number)` のようにコマンド置換で代入されている付与コマンドの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、stdout は空で、終了コードは 0

#### Scenario: `--input` の値からラベルのパスを拾わない
- **WHEN** `gh api repos/acme/repo-a/issues/5/labels -X POST --input repos/acme/repo-a/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す（#5 と #300 のどちらにも合格ラベルが付いている）
- **THEN** 行が積まれるのは #5 だけで、#300 は問い合わせも書き込みもされない

#### Scenario: フィールドでない引数のラベル名は付与と見ない
- **WHEN** `gh api -X POST repos/acme/repo-a/issues/300/labels --jq 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

