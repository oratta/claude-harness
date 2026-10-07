# cost-ledger-issue-total — issue を閉じたときに、閉じた PR の分も重複なしで合わせた合計を載せる

エピック #272 の子（issue #689）。節目ごとに 1 行積む仕組み（#303、PR #704）はマージ済みで、この change はその行の積み方に乗る。

## Why

issue のコメントに積まれる累計は「その issue の番号を `gh` で触った区間」の合計で、`/cost <issue番号>` と同じ値になっている。実装の大半は PR のブランチ上で issue の番号に触れずに進むので、この値は issue にかかった額より小さい。一方で PR の値（ヘッドブランチの行の合計）と issue の値は同じ行を両方が数えることがあり、単純に足すと二重に数える。spec `cost-ledger-attribution` の「2 つの鍵は独立である」は、この理由で 2 つの値を足すことを禁じている。

issue を閉じた時点で「この issue に結局いくらかかったか」を 1 つの数字で見たい。そのためには、足し方を定義して二重に数えない合計を出す必要がある。

## What Changes

- **合計の定義を決める。** issue の合計 =（その issue を閉じた PR のヘッドブランチの行の合計）+（その issue に帰属した区間の行のうち、それらの PR のヘッドブランチ上に無い行の合計）。1 つの行は必ず 1 つのブランチにしか属さないので、この 2 つは重ならない
- **`gh issue close` を実行したときに、合計の行を 1 行足す。** 今までどおりの `issue クローズ` の行（区間だけの累計）の直後に、きっかけの欄が `合計（PR #704 $39.62 + PR 外 $2.00）` の形の行を積む。金額・入出力トークン・キャッシュトークンの 3 項目は、他の行と同じ「累計 (増分)」の書式で書く
- **閉じた PR は GitHub に 1 回だけ問い合わせる。** hook の裏のプロセス（`gate_report.py`）が GraphQL の `closedByPullRequestsReferences` を 1 回呼び、結果を `cost_ledger.py timeline --issue <N>` に `--closing-pr <番号>:<ヘッドブランチ>` で渡す。`cost_ledger.py` は `gh` を呼ばない。`issue クローズ` で 1 行積むときの `gh` は 3 回から 4 回になる（PR の数には比例しない）。ほかのきっかけの回数は変わらない
- **コメントの 1 行目**は、最後の行が合計の行のときだけ合計の金額になり、帰属の種別が `区間+閉じた PR` になる
- **増分の基準を「合計でない、1 つ前の行」に変える。** 合計の行は区間だけの累計より大きいので、再オープン後に積まれる行が合計の行を基準にすると、何も使っていなくても増分が負になる。それを避ける
- **手で引く入口を足す。** `cost_ledger.py issue <N> --closing-pr <番号>:<ヘッドブランチ>` で、同じ合計と内訳（PR ごとの額と、PR の外の区間の額）を JSON と表示の両方に出す。`--closing-pr` を渡さなければ、合計は今の `total_usd` と同じ値になる
- 閉じた PR が 0 件のとき、問い合わせが失敗したとき、結果が 100 件を超えるときは、合計の行を積まない（`issue クローズ` の行は今までどおり積む）
- LLM のトークンは使わない。スキル本文には何も足さず、hook は何も出力しない。問い合わせは既に切り離してある裏のプロセスの中で行うので、hook がセッションを止める時間は変わらない

## やらないこと（他の子 issue の範囲、または今回は見送るもの）

| やらないこと | 受け持つ issue |
|---|---|
| auto-merge のマージや PR の `Closes` による自動クローズのときに合計の行を積む（手元でコマンドが走らないので hook から見えない） | #691 |
| エピックで子 issue ごとの内訳と合計を出す | #690 |
| `/cost <issue番号>` の 1 行目と `gh` の呼び出しを変える（`/cost <issue番号>` は今までどおり区間だけの合計を出す） | 新しい子 issue の候補 |
| 会話ログからの事実の抽出・単価表のずれの検出・テストの `__pycache__` | #695・#701・#699 |

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `cost-ledger-attribution`: issue の合計（閉じた PR 込み）の定義を足す。「2 つの鍵は独立である」に、定義された合計だけを例外として認める記述を足す
- `cost-ledger-timeline`: `issue クローズ` のときに合計の行を積む要件を足す。行を 1 行だけ足す・1 行目は `/cost` と同じ・増分は 1 つ前の行との差・`gh` は 3 回以下、と定めている要件を、合計の行に合わせて直す

## Impact

- コード: `plugins/cost-ledger/scripts/cost_ledger.py`（`timeline`・`issue` の `--closing-pr`、合計の計算、増分の基準）、`plugins/cost-ledger/scripts/gate_report.py`（閉じた PR の問い合わせ）
- テスト: `plugins/cost-ledger/tests/issue-total.bats`（新規）、`plugins/cost-ledger/tests/gate-report.bats`（`gh` の stub に GraphQL の応答、回数のテスト）
- 文書: `plugins/cost-ledger/README.md`、`plugins/cost-ledger/changes/689.md`（新規）
- 既に積まれているコメント: 形は変わらない。合計の行は、この change のあとで `gh issue close` を実行した issue にだけ付く
- `hooks.json` は変えない（反映に `/reload-plugins` は要らない）
