## Why

エピックの子の PR が既定のトークン上限（3,000 万。`DEV_WORKFLOW_PR_TOKEN_CAP`）を超えると、今の規則（develop SKILL.md「PR トークン上限」の exit 2）は毎回主の「続ける」を待つ。親が通せる基準（`parent-pass-criteria.md`）も、この止まりを通らない例の先頭に置いている。2026-10-17〜19 の 5 件はどれも主の答えが「続ける」で、夜のあいだ合わせて約 48 時間止まった（記録先 https://github.com/oratta/claude-harness/issues/1245 ）。

主の決定（https://github.com/oratta/claude-harness/issues/1245#issuecomment-6359136416 ）: エピックの親に「子 1 件あたりの PR トークンの権限」（既定は合計 6,000 万）を持たせ、子の見込みがその権限の内に収まるなら親が続けさせる。既定の上限 3,000 万は変えない（止まることで、develop の工程の中の無駄に気づかせるため）。本文の推奨（1 回目の超過は「合計 ＋ 既定」まで親が通す）と別案（既定の上限を上げる）はどちらも採らない。

## What Changes

- エピックの親は、起動したときにエピックへ 1 行目 `子の PR トークン権限: <値>`（既定 60000000）のコメントを投稿し、interactive と channel では主に「子 1 件 6,000 万で回す。広げたければ声をかけて」と伝える。主が広げたら、新しい値で同じ形のコメントを投稿し直す。正とするのは投稿者が OWNER・MEMBER・COLLABORATOR の最新の 1 件
- エピックの子は、今までどおり既定の上限で止まる。そのときの停止の記録には、続けるべきか・終わるまでの見込み（あと何トークンで、合計がいくつになるか）・次に何に範囲を絞るかを書く
- 別セッション方式で起こされた親（`epic.md` 手順 8）は、`止まった理由:` が `PR トークン上限（` で始まる止まりを、`parent-pass-criteria.md` に照らし直さずに専用の手順で扱う。「合計の見込み ≤ 権限」かつ「今の上限 < 権限」なら、`reply --as parent` で新しい上限 ＝ 権限として続けさせる。それ以外は主に上げる
- 返事を受けた子の本体が、記録先に `PR トークン上限: <権限>` を投稿する。2 行目以降には、親の判断で上げたことと、権限のコメントと停止の記録の URL を書く
- サブエージェント方式のエピックでは、本体が親を兼ねる。本体は子の記録先の exit 2 で、自分の見込みを同じ条件で照らし、同じ書式で `PR トークン上限:` を書く
- `stop-judge.sh`・`epic-dispatch.sh` は変えない（判断のモデルは今までどおりこの止まりを主に上げる側に倒し、起こされた親が扱う）
- エピックの子でない作業の上限と「続ける」の扱いは変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-pr-token-budget`: 要件「本体は spawn と再開の前に測り、上限超なら止まる」の exit 2 の扱いに、エピックの子の記録先では親の権限の内なら親（サブエージェント方式では本体）が続けさせてよいことと、そのときの `PR トークン上限:` の書き方を足す
- `dev-workflow-develop`: 要件「親が通してよい範囲の基準を 1 つのファイルに置く」の通らない例の理由を直す。要件「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」の手順 8 に、PR トークン上限の止まりの振り分けを足す。権限の置き場・起動時の案内・子の記録・通す条件・記録の書式を、新しい要件として足す

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（「PR トークン上限」の exit 2）
- `plugins/dev-workflow/skills/develop/references/epic.md`（経路を決めたあとの権限のコメントと主への案内、手順 7 の再開、手順 8 の振り分けと専用の手順）
- `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`（PR トークン上限で止まるときの記録の書き方）
- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`（通す条件の 1 行目と通らない例の先頭）
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`plugins/dev-workflow/tests/develop-skill.bats`（文面のテスト）
- `plugins/dev-workflow/changes/1245.md`（変更の記録）
- スクリプトと常時注入の文（description・rules）は変えない
