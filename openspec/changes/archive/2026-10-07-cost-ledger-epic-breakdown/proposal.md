# cost-ledger-epic-breakdown — エピックで子 issue ごとの内訳と合計を出す

エピック #272 の子（issue #690）。issue の合計（閉じた PR 込み）の定義は #689（PR #738）でマージ済みで、この change はその定義をエピックに広げる。

## Why

今の `/cost <エピックの番号>` は、エピックの番号そのものを `gh` で触った区間しか数えない。実際の作業は子 issue と、子 issue を閉じた PR のブランチで起きるので、エピックの額はほぼ 0 に見える。どの子 issue が高くついたかを後から比べる手段も無い。

子 issue ごとに #689 の合計を出して足すだけでは、正しい総額にならない。1 本の PR が複数の子 issue を閉じると、その PR の分は閉じた各 issue の合計に全額入るので、足すと issue の数だけ重なる（#689 からの申し送り。実データでも PR #719 が #699 と #702 を閉じている）。足し方をこの change で決める。

## What Changes

- **`/cost <番号>` が、子 issue を持つ issue では子 issue ごとの内訳と合計を返す。** 1 行目の金額はエピックの合計で、帰属の種別は `子 issue 込み`。2 行目以降に「子 issue の合計」と「エピック自身」の額を 1 行ずつ出し（1 行目の合計はこの 2 つの和。子 issue の合計は子の行の額の和と一致する）、続けてエピック自身と子孫の issue を 1 件 1 行で、入れ子の深さだけ字下げして並べる
- **エピックかどうかは、今も呼んでいる issue の問い合わせの応答で決める。** REST の `repos/{owner}/{repo}/issues/<番号>` の `sub_issues_summary.total` が 1 以上ならエピック。判別のための `gh` は増えない。子を持たない issue と PR の `/cost` は、出力も `gh` の回数も変わらない
- **子 issue と、それぞれを閉じた PR は GraphQL でまとめて取る。** 子を持つ issue 1 件につき 1 回の問い合わせで、その子すべてと、子ごとの閉じた PR を取る。`gh` の回数は「番号の判別の 2 回 + 子を持つ issue の数」で、子を持たない子 issue の数と PR の数では増えない（実機の #272 は子 20 件で 3 回。子が 1 件ずつ入れ子になった鎖では段の数だけ呼ぶ）
- **エピックの合計の定義を決める。** エピック自身と子孫の issue が数える行（閉じた PR のヘッドブランチの行と、その issue に帰属した区間の行）を、行ごとに 1 回だけ足した額。同じ PR を複数の子が参照していても 1 回しか数えない
- **重なった行は 1 つの issue に割り当てる。** 閉じた PR のヘッドブランチ上の行は、そのブランチの PR が閉じた issue のうち番号がいちばん小さい issue へ。それ以外の区間の行は、その issue へ。内訳の額はこの「割り当てた額」なので、和が合計と一致する。#689 の定義で出した額（単独の合計）と違う issue の行には `（単独 $3.00、PR #300 は #11 に計上）` を添える
- **孫も辿る。** 一度出た番号は数えず辿らない（循環で止まる）。深さはエピックから 8 段下まで。open の子も closed の子も数える。別のリポジトリの子は数えず、別立ての 1 行に出す
- **読み切れないときは合計を出さない。** GraphQL の失敗、応答の形の崩れ、子や閉じた PR が 100 件を超える場合、8 段より深い場合は、標準出力を空にして終了コード 2 を返す
- **`--json`** に、issue ごとの `usd`・`own_usd`・`standalone_usd`・`closing_prs[].counted_in` と `total_usd`・`children_usd`・`self_usd`・`skipped` を出す
- 台帳への差分の追記は 1 回の呼び出しで 1 回。台帳を読み通す回数は子 issue の数にも PR の数にも比例しない
- LLM のトークンは使わない。集計は `cost_ledger.py` だけで行い、スキル本文と `description` には何も足さない（`commands/cost.md` の呼び方の表に 1 行足すだけ）

## やらないこと（他の子 issue の範囲、または今回は見送るもの）

| やらないこと | 受け持つ issue |
|---|---|
| auto-merge のマージや PR の `Closes` による自動クローズのときに合計の行を積む（`hooks.json`・新しいスクリプト・gate-report 側の spec） | #691 |
| 会話ログからの事実の抽出（`facts_from_lines`）と、`cost-ledger-attribution` のそれに関わる要件 | #695 |
| `plugins/cost-ledger/changes/701.md` の記載 | #726 |
| `/cost <子 issue の番号>` に閉じた PR の分を足す（今までどおり区間だけの合計。エピックの内訳のその issue の額とは一致しない） | 新しい子 issue の候補（#689 の proposal でも同じ扱い） |
| エピックのコメントに hook が積む行と、エピックを閉じたときの合計の行に子 issue の分を入れる（`timeline` は `gh` を呼ばない決まりなので、今までどおりエピックの番号を触った区間だけの累計） | 新しい子 issue の候補 |
| #272 の本文の表にだけ書かれていて GitHub の子 issue として登録されていない #273・#274・#276 を登録する（スクリプトの外の、GitHub 上の操作） | 新しい子 issue の候補 |
| `cost_ledger.py issue`・`cost_ledger.py timeline`・`gate_report.py` の振る舞いを変える | なし（変えない） |

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `cost-ledger-cost-command`: 「`/cost <番号>` の入力解釈」に子 issue を持つ issue の分岐を足し、「出力の 1 行目は固定書式」の帰属の種別に `子 issue 込み` を足す。内訳と合計を返す要件と、`gh` は子を持つ issue ごとに 1 回で台帳の読み取りは issue の数に比例しない、という要件を足す
- `cost-ledger-attribution`: エピックの合計と、重なった行の割り当ての定義を足す。「2 つの鍵は独立である」に、定義された合計としてエピックの合計を足す
- `cost-ledger-timeline`: 「数字と書式は `timeline` サブコマンドから取る」に、子 issue を持つ issue では節目の行の累計が一致する相手が `cost_ledger.py issue` の値になることを足す（`timeline` の振る舞いは変えない。`/cost` の 1 行目が変わるので、一致の相手を言い直す）

## Impact

- コード: `plugins/cost-ledger/scripts/cost_ledger.py`（`resolve_number`、子 issue の木を取る関数、issue の集合での区間の読み取り、行の割り当て、`cmd_epic`、`cmd_cost` の分岐、parser の help）
- テスト: `plugins/cost-ledger/tests/epic.bats`（新規）
- 文書: `plugins/cost-ledger/commands/cost.md`（呼び方の表に 1 行。`description` は触らないので常時注入の予算は動かない）、`plugins/cost-ledger/README.md`、`plugins/cost-ledger/changes/690.md`（新規）
- `gate_report.py`・`gate-report.sh`・`hooks.json`・`helper.bash`・`pricing.json` は変えない（反映に `/reload-plugins` は要らない）
- 既に積まれているコメント: 変わらない
- 既存の利用者から見える変化: 子 issue を持つ issue に `/cost` を実行したときだけ、1 行目の金額が区間だけの額から子 issue 込みの合計に変わり、`gh` が子を持つ issue の数だけ増える
