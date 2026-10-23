## Why

主への確認が、決まった型の項目（質問・聞く理由・困りごと・推奨・リスク・答え方）を全部埋めた形で届き、何を決めればよいかが読み取れない。2026-10-22 に 2 つの実例が起きた。

- 実例 1: ゲートの決まりでトークンの扱いを変える PR の OK を求めた確認の 1 行目が「リスク宣言を許容するかを決めてください」だった。主から「何を許容するの？」「質問が書いてない」と返された。中身はレビュー済みで主が考える点は無く、決まりで聞いていただけだった。困りごとの欄も、止めているのはエージェント側なのに作文して埋めていた
- 実例 2: 別リポのエピックの親の報告の 1 行目が「PR #1712 のリスクを許容しますか？」で、リポ名もリンクも無かった。主は PR を探し、長いコメントからリスク宣言を探し当てないと何を許容するのか分からなかった。受け入れるリスクの欄は「手順書の例に見落としがあると、全住人のトークンの扱いに同じ誤りが広がる」という、どの変更にも当てはまる作文だった

原因は 3 つある。ゲートの宣言の書式が 7 分類に当たっただけの変更にもリスク内容の作文と「これを許容するか」の問いを求め、「この形式以外で主にリスク承認を求めない」としていること。正本 `readable.md` の節 3 が番号を主語にすることだけを禁じ、主語でない番号の並びを禁じていないこと。正本の「受け入れるリスク」が何と比べたリスクかを問わないこと。

## What Changes

- **論点**を定義する: 主が持っていてエージェントが持っていない観点（事業判断・好み・許せる被害の範囲など）を足すと結論がよくなる点。判断材料がエージェント側にあるものに論点は無い
- 正本 `output-styles/readable.md` の節 3 と短い版 `rules/communication-style.md` の 3 番目に、主に聞く理由として論点の有無を書くこと、論点あり／論点なし（決まりで聞いている）の書き分け、1 行目は OK すると何が起きるかを中身で書いた質問にすること、番号で物を指さず番号は末尾の URL にだけ置くこと、困りごとが無ければ書かないこと、受け入れるリスクは推奨を選ぶことで新たに生じるものだけにすること、論点なしの確認は 3〜4 行に収めることを足す。例は論点ありの 1 つと、実例 2 つを論点なしで書き直したもの（各 4 行以内）にする
- pr-review-gate `declarations.md` の手順 3: 「主のリスク許容が必要」の雛形の、`主のリスク許容が必要。` のあとの空行に続く行を論点なし／論点ありの 2 つの形にし、分類に当たっただけのときにリスク内容を作文させない。「この形式以外で主にリスク承認を求めない」と「これを許容するか」を外し、主への依頼文は正本の型で書くとする。`stages/hold.md` は論点なしの宣言には論点なしの 3〜4 行で依頼すると書く
- develop: エピックの子の停止の記録の `主に聞く理由:` に論点の有無を書き、`受け入れるリスク:` は新たに生じるものだけにする。親の手順 8 の「親経由のリスク許容の依頼」を、子の記録の推奨を主に OK してもらう報告として正本の型で書く形に置き換える。`references/ci-watch.md` の記録の例も揃える
- `rules/perspective-casting.md` の手順 2 を「論点に必要な観点を特定する」から「判断に必要な観点を特定する」に言い換え、論点の定義と食い違わないようにする（casting の SKILL.md と eval の prompt 2 つも同じ）
- 宣言の行頭の `リスクなし` / `主のリスク許容が必要`、`対象 HEAD:` 行、`主の回答: 許容` の照合、`owner-reply-check.sh`、自動マージの判定は変えない。送る前に書き直させる hook は別の子 issue #1215 で扱う

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `owner-question-style`: 論点の有無の書き分けと論点なしの確認を短くする要件を足し、正本の節 3 の要件を番号で物を指さない形と新しい例の構成に直す
- `casting-catalog`: 返信前チェックの rule の手順 2 を「判断に必要な観点の特定」に直す
- `dev-workflow-develop`: 子の停止の記録の `主に聞く理由:` と `受け入れるリスク:` の書き方、親が主に出す発言から「親経由のリスク許容の依頼」をなくす
- `dev-workflow-pr-review-gate`: 「主のリスク許容が必要」の宣言を論点の有無で書き分け、リスクを作文させない要件を足す

## Impact

- `output-styles/readable.md`（節 3）、`rules/communication-style.md`、`rules/perspective-casting.md`
- `plugins/casting/skills/casting/SKILL.md`、`plugins/casting/evals/casting-escalate-sanctuary/prompt.md`、`plugins/casting/evals/casting-no-escalate-delegated/prompt.md`
- `plugins/dev-workflow/skills/pr-review-gate/declarations.md`（手順 3）、`plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`
- `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`、`plugins/dev-workflow/skills/develop/references/epic.md`（手順 8）、`plugins/dev-workflow/references/ci-watch.md`
- `tests/owner-question-style.bats`、変更の記録 `plugins/dev-workflow/changes/1209.md`・`plugins/casting/changes/1209.md`
- 常時注入される `rules/` と `output-styles/` の文が変わる。予算 `tests/injection-budget.txt` は動かさず、文を詰めて収める
