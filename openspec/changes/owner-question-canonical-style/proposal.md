## Why

主に判断や確認を求める文章が、疲れているときに 1 回読んでも答えられない。過去 90 日の会話ログでは、エピックの親が子の判断待ちを主に上げ、主が「意味わからん」「説明して」と返した場面が 9 場面あった（issue #1176 の背景の表）。原因は、番号で物を指す・子の作業の言葉のまま書く・論点が無い・1 通に複数の判断が混ざる・聞かなくてよいことを聞く、などである。

いまの書き方の型（目的 → いま取り組んでいる場所 → 起きた事実 → 決めてほしいこと → 推奨とリスク）は質問が 4 番目に来る。主に聞く理由を書く決まりも、リスクの起こりやすさを書く決まりも無い。さらに、主に問いを返す場所（develop の手順書、pr-review-gate の保留、ci-watch、one-off、casting など）がそれぞれ自前で書き方を決めていて、1 か所を直しても他が古い型のまま残る。

## What Changes

- `output-styles/readable.md` の「3. 判断を求めるときは」の節を書き直し、主に問いを返す文章の書き方の正本にする。中身は issue #1176「決めた書き方」のとおり。
  - 6 段の順で書く: 質問 → 主に聞く理由 → いま困っていること → 推奨と根拠 → 受け入れるリスク → 答え方
  - 主に聞く理由として成り立つのは 3 つだけ。どれにも当たらなければ聞かずに自分で決めて進め、事後報告する
  - リスクは 3 つの要素で書く（何が起きるか・どれくらい起きるか・分からないときは何を調べれば分かるか）
  - 1 通で聞くのは 1 件。issue・PR の番号を主語にしない。背景の詳しい説明は区切って下に置く。確認作業の細部は書かない
  - 例を 1 つ置く
- 同じ節で、主への発言の 1 行目の書き分けを 1 か所で決める。判断・確認・操作を求める発言は 1 行目を質問にし、最後を答え方にする。主の操作も判断も要らない報告は、1 行目を `主がすること: なし` にする。
- `rules/communication-style.md` の 3 番目を、正本の要点に縮めて書き直す（6 段の順、理由が無ければ聞かない、リスクの被害と頻度、1 通 1 件）。Output Style が効かないサブエージェントに届くのはこちらだけなので、要点は残す。
- 主に問いを返す各所から、問いの書く順とリスクの書き方を独自に決めた文を外し、正本への参照に置き換える。その場所に固有の事柄（記録の書式・投稿先・URL の添え方・返事の場所）だけを残す。
  - develop の `SKILL.md`: 保留の依頼の出し直し・主への案内・channel の主への発言・Orca 経路の親の発言の 1 行目・手順 8 の報告の順
  - pr-review-gate の `stages/hold.md`（手順 6・切り出しの確認・主に承認を求めてよい 4 分類）
  - pr-review-gate の `stages/pass.md`（動作確認の依頼）
  - `references/ci-watch.md`（オーナーへのマージの依頼）
  - `rules/one-off-no-script.md`・`references/one-off-operations.md`（「飲めるか」を 1 問だけ聞く）
  - casting の `SKILL.md`・`rules/perspective-casting.md`（主に上げるかの判定）
- **BREAKING（文面の約束）**: develop の Orca 経路と channel の発言の 1 行目に使っていた `主がすること: <どこで> <何を>` の形をやめる。主の操作が要る発言は 1 行目が質問になり、どこで何を打つかは最後の答え方に移る。`主がすること: なし` は残す。

この change に含めないもの:
- 子の停止の記録への `主に聞く理由:` の追加、手順 8 の「同じ項目名のまま」の撤去、`parent-pass-criteria.md`、`stop-judge.sh`・`epic-dispatch.sh` とその bats の項目名、実機確認。これらは後続の change `stop-record-ask-reason` で扱う
- 「わからん」系の発言で言い直しを差し込む UserPromptSubmit hook。後続の change `unclear-reply-rephrase-hook` で扱う

## Capabilities

### New Capabilities
- `owner-question-style`: 主に判断・確認・操作を求める文章の書き方の正本の置き場所と中身（6 段の順・主に聞く理由の 3 つ・リスクの 3 要素・1 通 1 件・1 行目の書き分け）、短い版との対応、主に問いを返す各所が正本を参照する形

### Modified Capabilities
- `dev-workflow-develop`: 次の 4 つの要件で、1 行目と問いの書く順を正本の型に合わせる
  - 「エピックの親が主に出す報告は、主がすることを 1 行目に書く」
  - 「channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を 1 行目に書く」
  - 「channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける」（シナリオの 1 行目）
  - 「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」（主に上げる説明の順だけ。停止の記録の項目名の扱いは後続の change）

## Impact

- 文書: `output-styles/readable.md`、`rules/communication-style.md`、`rules/one-off-no-script.md`、`rules/perspective-casting.md`、`rules/README.md`（communication-style の行の説明）、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`、`plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`、`plugins/dev-workflow/references/ci-watch.md`、`plugins/dev-workflow/references/one-off-operations.md`、`plugins/casting/skills/casting/SKILL.md`
- テスト: 文言を固定している bats を新しい文言に合わせる（`plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/tests/develop-channel-mode.bats`、`plugins/dev-workflow/tests/develop-handover.bats`、`tests/always-on-injection-scope.bats`）。新しい正本の中身を検査する bats を足す
- 常時注入の予算: `rules/` と `output-styles/` が増えるため、`tests/injection-budget.txt` を上げる見込み（理由は design.md）。予算ファイルは聖域なので、この PR は主がマージする
- 変更の記録: `plugins/dev-workflow/changes/1176.md`、`plugins/casting/changes/1176.md`
- スクリプトの振る舞いは変えない
