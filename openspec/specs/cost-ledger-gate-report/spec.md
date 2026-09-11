# cost-ledger-gate-report Specification

## Purpose
ゲート通過（合格ラベル `agent-review:passed` の付与）を PostToolUse の hook で捕まえ、対象 PR のコストを LLM のトークンを使わずにコメントで 1 行貼る。数字は `/cost` と同じ入口（`cost_ledger.py cost`）から取り、hook は集計・単価・書式を自分で持たない。

## Requirements
### Requirement: ゲート通過を PostToolUse の hook で捕まえる
システムは `plugins/cost-ledger/hooks/hooks.json` に `PostToolUse`・matcher `Bash` の hook を 1 つ持ち、`plugins/cost-ledger/scripts/gate-report.sh` を呼 MUST ぶ。ゲート通過は合格ラベル `agent-review:passed` を付けるコマンドとして Bash の呼び出しに現れ、そのコマンド文字列から対象の PR が分かるため。`Stop` のように PR と結びつかない event を使ってはなら MUST NOT ない。

hook は全 Bash 呼び出しで起動するので、スクリプトは stdin に文字列 `agent-review:passed` が含まれなければ、JSON のパースも jq・python3 の起動もせずに即 `exit 0` MUST する。

#### Scenario: 対象外の Bash では何も起動しない
- **WHEN** `agent-review:passed` を含まない Bash 呼び出しの hook JSON を stdin に流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 対象外の Bash での実行時間
- **WHEN** 対象外の Bash 呼び出しの hook JSON を stdin に流して実行時間を `time` で測る
- **THEN** 実行時間は 50 ms 未満

#### Scenario: hook の登録
- **WHEN** `plugins/cost-ledger/hooks/hooks.json` を読む
- **THEN** `PostToolUse` に matcher `Bash`・`timeout: 60` の hook があり、`async` は指定されていない

### Requirement: ラベル付与コマンドの判定と対象 PR の取り出し
システムは `tool_input.command` が `agent-review:passed` の**付与**であるときだけ投稿に進 MUST む。付与とは、パスが `repos/<リポジトリ>/issues/<番号>/labels` の `gh api` 呼び出しで同じ呼び出しに `labels[]=agent-review:passed` があり DELETE でないもの、または `gh pr edit` / `gh issue edit` の `--add-label` の値に `agent-review:passed` を含むものと SHALL する。ラベルを外すコマンドや、文字列として `agent-review:passed` を含むだけのコマンドで投稿してはなら MUST NOT ない。

対象のリポジトリと番号は、コマンド文字列のリテラルに加えて、同じコマンドの中の単純な代入（`NAME=値`）と `for NAME in <リテラルの並び>; do` から `$NAME` / `${NAME}` を展開して SHALL 求める。`for` の場合は並びの各値を対象とする。`gh pr edit` / `gh issue edit` でリポジトリが書かれていなければ hook の `cwd` のリポジトリと SHALL する。解決できなかった対象は投稿せずに飛ば MUST す。解決のためにコマンドを評価・再実行してはなら MUST NOT ない。

#### Scenario: リテラルの付与コマンド
- **WHEN** `gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'` の hook JSON を流す
- **THEN** oratta/claude-harness の #300 が投稿の対象になる

#### Scenario: 同じコマンドで代入した変数の付与コマンド
- **WHEN** `R=oratta/claude-harness; N=300` のあとに `gh api -X POST repos/$R/issues/$N/labels -f 'labels[]=agent-review:passed'` が続くコマンドの hook JSON を流す
- **THEN** oratta/claude-harness の #300 が投稿の対象になる

#### Scenario: for で複数 PR に付与する
- **WHEN** `R=oratta/kg-recruit` のあと `for N in 96 97; do` の中で `repos/$R/issues/$N/labels` に付与するコマンドの hook JSON を流す
- **THEN** #96 と #97 の両方が投稿の対象になる

#### Scenario: gh pr edit で付与する
- **WHEN** `gh pr edit 313 --remove-label agent-review:pending --add-label agent-review:passed` の hook JSON を流す
- **THEN** `cwd` のリポジトリの #313 が投稿の対象になる

#### Scenario: ラベルを外すコマンドでは投稿しない
- **WHEN** `gh api -X DELETE repos/oratta/claude-harness/issues/300/labels/agent-review:passed` だけのコマンドの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われない

#### Scenario: 解決できない変数は飛ばす
- **WHEN** 番号が `N=$(gh pr view --json number -q .number)` のようにコマンド置換で代入されている付与コマンドの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、stdout は空で、終了コードは 0

### Requirement: 付与を実測してから貼る
システムは対象ごとに、その PR に `agent-review:passed` が実際に付いていることを GitHub に問い合わせて確かめてから投稿 MUST する。付いていなければ投稿してはなら MUST NOT ない。PostToolUse はツールが終わったことしか伝えず、複合コマンドの中の付与が成功したかは分からないため。

#### Scenario: 付与に失敗していた
- **WHEN** 付与コマンドの hook JSON を流すが、問い合わせた PR のラベルに `agent-review:passed` が無い
- **THEN** コメントの作成も書き換えも行われない

### Requirement: 貼る数字は `/cost` と同じ入口から取る
システムは貼る数字を `cost_ledger.py cost <番号>`（`/cost` と同じ入口）の出力の 1 行目から SHALL 取る。hook が集計・単価・書式を自分で持ってはなら MUST NOT ない。番号の判別が付与コマンドのリポジトリに問い合わせるよう、そのリポジトリを `GH_REPO` として渡 SHALL す。`transcript_path` は使ってはなら MUST NOT ない。貼るのは PR 全体（そのブランチの全セッション合計）であり、自セッションのログ 1 本から出る区間コストではないため。

子2（台帳）が `/cost` の読み取り元を台帳に切り替えたとき、hook は変更なしでその値を貼ることになる。

#### Scenario: 1 行目が `/cost` と一致する
- **WHEN** ゲート通過で hook がコメントを貼り、同じ時点で `/cost <その PR 番号>` を実行する
- **THEN** コメントの 1 行目と `/cost` の出力の 1 行目が一致する

#### Scenario: サブエージェントの中で付与しても動く
- **WHEN** `transcript_path` を含まない（またはサブエージェントのトランスクリプトを指す）hook JSON で付与コマンドを流す
- **THEN** 同じようにコメントが貼られる

### Requirement: 貼る形はマーカー付きのコメント 1 本
システムは PR 1 本につき、隠しマーカー `<!-- cost-ledger:gate-report -->` を持つコメントを 1 本だけ SHALL 保つ。マーカー付きのコメントが既にあれば `gh api -X PATCH` でその本文を書き換え、無ければ新規作成 MUST する。本文の 1 行目は `cost` の出力の 1 行目そのもの、2 行目は `YYYY-MM-DD HH:MM 時点・ゲート通過時に自動投稿`、マーカーは最終行と SHALL する。書き換えに失敗したときに新規作成へ切り替えてはなら MUST NOT ない。

#### Scenario: 初回のゲート通過
- **WHEN** マーカー付きのコメントが無い PR に付与コマンドの hook JSON を流す
- **THEN** マーカー付きのコメントが 1 本新規作成され、1 行目がコストの行、2 行目が時点の行になっている

#### Scenario: 再ゲート
- **WHEN** マーカー付きのコメントが既にある PR に付与コマンドの hook JSON を流す
- **THEN** そのコメントが PATCH で書き換えられ、新しいコメントは作成されない

### Requirement: 投稿するのはゲート通過のときだけ
システムはラベル付与のときだけ投稿 MUST する。PR へのコメント投稿や Ready への切り替えなど、他の操作に相乗りして投稿してはなら MUST NOT ない。子2 の hook（台帳への焼き付け）と役割を混ぜないため。数字はラベル付与のターンより前の分しか含まないが、これを許容し、コメントに時点を書くことで示 SHALL す。

#### Scenario: PR へのコメント投稿では貼らない
- **WHEN** `gh pr comment 300 --body "..."` の hook JSON を流す
- **THEN** `gh` は一度も呼ばれない

### Requirement: 有効・無効の設定を持たず、緊急停止だけを持つ
システムは有効・無効を切り替える設定項目を持ってはなら MUST NOT ない。発火条件がラベル付与コマンドそのものなので、pr-review-gate を使うリポジトリでしか動かない。緊急停止用に、環境変数 `COST_LEDGER_GATE_REPORT=off` のときは何もせず `exit 0` MUST する。

#### Scenario: 緊急停止
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて付与コマンドの hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、stdout は空で、終了コードは 0

### Requirement: どの失敗でも無出力で抜ける
システムは次のどれに当たっても、stdout と stderr に何も出さず終了コード 0 で終わ MUST る: コマンドが対象外 / `gh` か `python3` が無い / `cost_ledger.py` が失敗する / GitHub に届かない・`gh` が失敗する。終了コード 2 を返してはなら MUST NOT ない。hook の失敗でゲートを止めず、文脈にも何も入れないため。

#### Scenario: `gh` が失敗する
- **WHEN** `gh` がすべて失敗する環境で付与コマンドの hook JSON を流す
- **THEN** stdout は空で、終了コードは 0

#### Scenario: cost の集計が失敗する
- **WHEN** `cost_ledger.py cost` が 0 以外で終わる状況で付与コマンドの hook JSON を流す
- **THEN** コメントの作成も書き換えも行われず、stdout は空で、終了コードは 0

