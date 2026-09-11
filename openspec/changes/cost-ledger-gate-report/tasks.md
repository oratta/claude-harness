## 1. テストの足場

- [x] 1.1 `plugins/cost-ledger/tests/gate-report.bats` を作り、`helper.bash` と同じ形で読み込む。各テストは `gate-report.sh` を `$BATS_TEST_TMPDIR/scripts/` に複製し、同じディレクトリに stub の `cost_ledger.py`（受け取った引数と環境変数 `GH_REPO` をログに書き、固定の 1 行目 `コスト: ...` を出す。終了コードは環境変数で切り替える）を置く。これで `cost_ledger.py` を `$(dirname "$0")` から引くこと（design 決定 7）と、`GH_REPO` の受け渡し（design 決定 4）を実物に触れずに確かめられる
- [x] 1.2 stub の `gh` を `$BATS_TEST_TMPDIR/bin` に置いて PATH の先頭にする。呼ばれた引数を 1 行ずつログに書き、ラベルの問い合わせ（`repos/<A>/issues/<N>` と `--jq`）・既存コメントの検索（`--paginate .../issues/<N>/comments`）・`gh repo view` への応答を fixture で返す。既存コメントの検索はページ単位の fixture を持ち、`--jq` があれば各ページに jq を当てた出力を、無ければ各ページの JSON を連結して返す（本物の `gh --paginate` と同じ形）。環境変数で「すべて失敗する」に切り替えられるようにする
- [x] 1.3 fast path で python3 が起動しないことを見るための stub の `python3`（起動されたらログに書いて 0 以外で終わる）を、そのテストのときだけ PATH の先頭に置けるようにする
- [x] 1.4 hook の JSON（`tool_name: Bash`・`tool_input.command`・`tool_response`・`cwd`・`transcript_path` を持つ）を組み立てて stdin に流すヘルパを書く。コマンド文字列は JSON として正しくエスケープする（python3 の `json.dumps` で組み立てる）

## 2. hook の登録と fast path（Red → Green）

- [x] 2.1 「`hooks.json` の `PostToolUse` に matcher `Bash`・`timeout: 60` の hook があり、`async` が指定されていない」テストを先に書く（Red）
- [x] 2.2 「`agent-review:passed` を含まない Bash の hook JSON を流すと、`gh` と `python3` が一度も呼ばれず、`$output` が空（bats の `run` は stdout と stderr を合わせて取る）で、終了コードが 0」テストを先に書く（Red）
- [x] 2.3 「`gh pr comment 300 --body "..."` の hook JSON では `gh` が一度も呼ばれない」テストを先に書く（Red）
- [x] 2.4 「`COST_LEDGER_GATE_REPORT=off` を付けて付与コマンドの hook JSON を流すと、`gh` が一度も呼ばれず、`$output` が空で、終了コードが 0」テストを先に書く（Red）
- [x] 2.5 `plugins/cost-ledger/hooks/hooks.json` を作る（`PostToolUse`・matcher `Bash`・`timeout: 60`・同期実行。`if` フィールドで絞らない。command は `${CLAUDE_PLUGIN_ROOT}/scripts/gate-report.sh`。書式は `plugins/dev-workflow/hooks/hooks.json` に合わせる）（Green）
- [x] 2.6 `plugins/cost-ledger/scripts/gate-report.sh` の骨格を書く（実行権限を付ける）。`COST_LEDGER_GATE_REPORT=off` で抜ける → `payload="$(cat)"` → `case` で `*agent-review:passed*` に当たらなければ `exit 0`。ここまで jq も python3 も起動しない。payload は環境変数や引数に載せない（design 決定 1）（Green）

## 3. 付与の判定と対象 PR の取り出し（Red → Green）

- [x] 3.1 「リテラルの `gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'` で oratta/claude-harness の #300 が対象になる」テストを先に書く（Red）。対象になったことは、stub の `gh` のログに #300 のラベル問い合わせが出ることで見る
- [x] 3.2 「`R=oratta/claude-harness; N=300` のあとに `repos/$R/issues/$N/labels` で付与するコマンドで #300 が対象になる」テストと、`${R}` / `${N}` の形と引用符付きの代入（`R="oratta/claude-harness"`）の形のテストを先に書く（Red）
- [x] 3.3 「`R=oratta/kg-recruit` のあと `for N in 96 97; do` の中で付与するコマンドで #96 と #97 の両方が対象になる」テストを先に書く（Red）
- [x] 3.4 「`gh pr edit 313 --remove-label agent-review:pending --add-label agent-review:passed` で `cwd` のリポジトリの #313 が対象になる」テストと、`-R owner/repo` / `--repo owner/repo` が書かれていればそのリポジトリが対象になるテストを先に書く（Red）
- [x] 3.5 「`-X POST` を書かない `gh api repos/.../issues/300/labels -f 'labels[]=agent-review:passed'` も付与として扱う」テストを先に書く（Red）
- [x] 3.6 「`gh api -X DELETE repos/oratta/claude-harness/issues/300/labels/agent-review:passed` だけのコマンドではコメントの作成も書き換えも行われない」テストと、`--method DELETE` の形のテストを先に書く（Red）
- [x] 3.7 「文字列として `agent-review:passed` を含むだけのコマンド（`gh pr view 300 --json labels` の出力にラベル名が出る・`echo agent-review:passed`）では投稿しない」テストと、「`echo "gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"` のように付与のコマンドを文字列として含むだけのコマンドでは投稿しない」テストを先に書く（Red）
- [x] 3.8 「番号が `N=$(gh pr view --json number -q .number)` のようにコマンド置換で代入されている付与コマンドでは、コメントの作成も書き換えも行われず、`$output` が空で、終了コードが 0」テストと、値に別の変数やバッククォートを含む代入も解決しないテストを先に書く（Red）
- [x] 3.9 fd 3 のヒアドキュメントで渡す python3 に、payload の JSON パースと design 決定 2 の判定（コマンドを `;` `&&` `||` `|` 改行で断片に区切り、先頭の `do` / `then` と代入を除いた先頭語が `gh` の断片だけを見る → 付与の形 → 単純な代入と `for NAME in <リテラルの並び>; do` の収集と `$NAME` / `${NAME}` の展開（同じ変数の再代入は使う位置より前の直近の代入で解決） → リポジトリの決定 → 解決できない対象は黙って飛ばす）を書く。`eval` もシェルでの再実行もしない。`gh pr edit` / `gh issue edit` で `-R` / `--repo` が無いときの `cwd` のリポジトリは、`gh` 自身の解決と揃えるため `cwd` で `gh repo view --json nameWithOwner -q .nameWithOwner` を実行して得る（Green）

## 4. 付与の実測・数字の取得・投稿（Red → Green）

- [x] 4.1 「問い合わせた PR のラベルに `agent-review:passed` が無ければ、コメントの作成も書き換えも行われない」テストを先に書く（Red）
- [x] 4.2 「マーカー付きのコメントが無い PR では `gh api -X POST repos/<owner>/<repo>/issues/<N>/comments` で 1 本新規作成され、本文の 1 行目が stub の `cost_ledger.py` の 1 行目そのもの、2 行目が `YYYY-MM-DD HH:MM 時点・ゲート通過時に自動投稿` の形、最終行が `<!-- cost-ledger:gate-report -->`」テストを先に書く（Red）
- [x] 4.3 「マーカー付きのコメントが既にある PR では `gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id>` で書き換えられ、POST は呼ばれない」テストと、マーカー付きのコメントが 2 ページ目にあるときも PATCH になるテストを先に書く（Red）
- [x] 4.4 「PATCH が失敗しても POST に切り替えない」テストを先に書く（Red）
- [x] 4.5 「stub の `cost_ledger.py` が `cost <N> --repo <cwd>` の引数と `GH_REPO=<付与先の owner/repo>` で呼ばれる。`cwd` のリポジトリと付与先が違うときも `GH_REPO` は付与先になる」テストを先に書く（Red）
- [x] 4.6 「`transcript_path` を含まない hook JSON でも、サブエージェントのトランスクリプトを指す hook JSON でも同じようにコメントが貼られる」テストを先に書く（Red）
- [x] 4.7 「`for` で 2 件付与したとき、#96 と #97 のそれぞれにコメントが貼られる」テストを先に書く（Red）
- [x] 4.8 対象ごとに、ラベルの実測（`gh api repos/<owner>/<repo>/issues/<N> --jq '.labels[].name'`）→ `GH_REPO=<owner/repo> python3 <スクリプトのディレクトリ>/cost_ledger.py cost <N> --repo <cwd>` の実行（スクリプトのディレクトリは bash 側で解決し、環境変数 `COST_LEDGER_SCRIPTS_DIR` で python3 に渡す）（終了コード 0 で 1 行目が `コスト: ` で始まるときだけ使う）→ 本文の組み立て（時刻はローカル時刻）→ 既存コメントの検索（`--paginate` と `--jq` でページごとにマーカーを含むコメントの id を出させ、先頭行を取る。検索が失敗したら貼らない）→ PATCH か POST、を書く。`for` の複数件は順に処理する（design 決定 3〜6）（Green）

## 5. 失敗時の抜け方（Red → Green）

- [x] 5.1 「`gh` がすべて失敗する環境で付与コマンドの hook JSON を流すと、`$output` が空で、終了コードが 0」テストを先に書く（Red）
- [x] 5.2 「stub の `cost_ledger.py` が 0 以外で終わると、コメントの作成も書き換えも行われず、`$output` が空で、終了コードが 0」テストと、1 行目が `コスト: ` で始まらないときも貼らないテストを先に書く（Red）
- [x] 5.3 「PATH に `gh` が無い・`python3` が無いとき、`$output` が空で、終了コードが 0」テストを先に書く（Red）
- [x] 5.4 「壊れた JSON を stdin に流しても `$output` が空で、終了コードが 0」テストを先に書く（Red）
- [x] 5.5 bash 側と python3 側の両方で、stdout・stderr に何も出さず、どの経路でも終了コード 0 で終わるようにする（`exit 2` を返す経路を作らない）（Green）

## 6. prototypes の削除と参照の付け替え

- [x] 6.1 `plugins/cost-ledger/prototypes/`（スクリプト 5 本と README）を `git rm -r` で消す
- [x] 6.2 `plugins/cost-ledger/scripts/cost_ledger.py` の、`prototypes/issue-rescue.py` と `prototypes/per-post-cost.py` を名指しするコメント 2 か所（`ISSUE_RE` と `POST_MARKERS` の直前）を、根拠の計測が archive 済みの change `cost-ledger-aggregation` の design に記録されている旨に書き換える（コマンドと境界の集合そのものは変えない）
- [x] 6.3 `plugins/cost-ledger/README.md` の `## prototypes/` の節を消し、ゲート通過時の自動投稿の節（何をきっかけに・何を・どこに貼るか、1 本を書き換えること、`COST_LEDGER_GATE_REPORT=off` での停止、数字はラベル付与のターンより前の分しか含まないこと）を足す
- [x] 6.4 pricing spec の置き換え後のシナリオ「手計算と同じ値になる」に対応するテストの有無を確認する。着手前の調査では `plugins/cost-ledger/tests/pricing.bats` に、トークン 5 種すべてが 0 でない行の金額を料金表の単価から手計算した値と突き合わせるテストが無い（既存は入力だけ・キャッシュ読出だけのもの）ので、`pricing.bats` に 1 件足す（実装は変えないので、足した時点で green になるのが正しい）
- [x] 6.5 `grep -rn 'prototypes' plugins/cost-ledger/ openspec/changes/cost-ledger-gate-report/specs/` で、削除したディレクトリを実在するものとして名指しする箇所が残っていないことを確かめる（spec の「計測スクリプトは change `cost-ledger-gate-report` で削除した」という記述は残してよい）

## 7. バージョンと検証

- [x] 7.1 `plugins/cost-ledger/.claude-plugin/plugin.json` の version を 0.1.0 から 0.2.0 に上げ、description にゲート通過時の自動投稿（PostToolUse の hook）と `COST_LEDGER_GATE_REPORT=off` での停止を足す。`.claude-plugin/marketplace.json` の cost-ledger の行の version と description を同じ値にする（S131・S130b の同期）
- [x] 7.2 対象外コマンドの hook JSON を流したときの実行時間を `time` で 10 回ほど測り、すべて 50 ms 未満であることを確かめる。測ったコマンドと値を控え、PR に貼る（貼るのは (3b) で PR を作ったあと）
- [x] 7.3 `bats plugins/cost-ledger/tests/` を実行し、exit code 0 を確認する
- [x] 7.4 `bash scripts/test.sh` を実行し、全件 green（exit code 0）を確認する
- [x] 7.5 `openspec validate cost-ledger-gate-report --strict` を実行し、exit code 0 を確認する
- [x] 7.6 `.claude/casting/precedents.md` に 1 判例を追記する。題は「本文に無い設計判断 6 件を主に上げず仕様レビューに回した（#276）」。観点は技術設計・品質（エージェント担当）、経路は「作業者が design / spec に書き、主に上げず R1 の審査に回した」。6 件は、対象 PR の取り出しで変数と `for` と `gh pr edit` を展開すること、hooks.json の `if` で絞らないこと、貼る前にラベルを API で実測すること、`GH_REPO` を付けて `cost` を呼ぶこと、本文の形（マーカーは最終行・PATCH 失敗で新規作成しない・ローカル時刻）、`cost_ledger.py` をスクリプト自身の位置から引き fd 3 の python3 で判定すること。帰結・還元・根拠・飲んだリスクは **R1 の結果確定後に追記**する。書式はファイル内の既存ブロック（`### 日付 題` のあとに観点・経路・帰結・還元・根拠・飲んだリスク）に合わせる
- [ ] 7.7 (3b) で archive する（`/opsx:archive cost-ledger-gate-report`。specs の `cost-ledger-pricing`・`cost-ledger-attribution` の MODIFIED と、新 capability `cost-ledger-gate-report` を正本へ同期する）

## 8. 本体が後工程で行うもの（この change の作業者はしない）

- [ ] 8.1 実機確認: この PR 自身を pr-review-gate に通し、PR にマーカー付きのコメントが 1 本付くこと、その 1 行目が同時点の `/cost <この PR の番号>` の 1 行目と一致すること、再ゲートでコメントが増えず書き換わることを確かめて、証拠を PR に貼る（マージ前の確認は `claude --plugin-dir <worktree のパス>/plugins/cost-ledger` のセッションで行う）
- [ ] 8.2 エピック #272 の本文の「prototypes の扱い」の記述を、削除済み（この change で削除。数字と測り方は archive 済みの `cost-ledger-aggregation` の design とエピックに残る）に更新する
- [ ] 8.3 エピック #272 に、完了条件「ゲート通過時に PR へ自動で 1 行載る」の達成報告（実機確認で付いたコメントの URL）をコメントする
