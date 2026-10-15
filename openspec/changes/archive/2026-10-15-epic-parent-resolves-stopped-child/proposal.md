## Why

Orca 経路のエピックで子のセッションが主の返事を待って止まると、親は #1033 の `wait --watch-stopped` で気づけるようになったが、気づいたあとは子の記録をそのまま主に報告するだけで、主が子のタブで答えるまで子は止まったままになる。2026-10-01〜10-14 に主が返答した子の停止 88 件のうち 35 件は、エピックの目的と完了条件を知っている親なら進めてよいと決められたもので、主の返答は「進めていいよ」「推奨どおり」の一言がほとんどだった。主の判断が要るものでも、子の説明が読めずに主が聞き返した例が 18 件あった（issue #1034、エピック #1038）。止まった子を親の側で解決し、解決できないものだけを、親がエピック全体を踏まえて主に分かる形に書き直して上げる。

## What Changes

- 親の `wait` が止まった子を見つけたら、親を起こさずに、`wait` の中から小さなモデルの判断を 1 回呼ぶ。判断に渡すのは、エピックの本文・子 issue の本文と親エピックからの注意書き・子の最新の停止の記録・このエピックで同じ子に親が通した判断・（あれば）観点の配役表だけで、親の会話は渡さない
- 判断が「通す」なら、`wait` が子の端末に返事を打ち込み、送ったあとでエピックに `親の判断:` で始まる 1 行を残して待ちを続ける（親は起きない）。返事は届いたのにエピックへの投稿に失敗したら、`unrecorded <N>` を出して親を起こし、親が 1 行を残し直す。「主に上げる」か、判断や送信に失敗したら、子 issue に判断の結果を残し、今までどおり `stopped <N>` を出して親を起こす
- 親は `stopped <N>` で起こされたら、子の記録と判断の結果を読み、エピックの目的と他の子との関係を含めて、主に分かる形（背景から推奨まで）に書き直して上げる。実機操作は、どの子の・どの画面で・何をするかを書く
- 主の答えは、親が `epic-dispatch.sh reply` で子の端末に届ける。送る前に `references/reply-after-idle.md` の表でそのまま送るか起動し直すかを決め、起動し直すときは `reply --relaunch` を使う。子の端末が無ければ `reply` が起動し直す
- 親が通してよい範囲の基準（「合理性があり危険が低い」の中身）の案を `references/parent-pass-criteria.md` に書く。判断はこのファイルを読んで行う。主は PR でこの案を見る
- 子の側には、親から届いた返事（`親エピック #<E> の判断（主の承認ではない）:` / `主の返事（親エピック #<E> 経由）:` で始まる入力）を、止まった件への返事として扱う 1 項目を足す
- `references/reply-after-idle.md` の「親が通した判断はまだ記録されない」を、エピックの `親の判断:` の行から復元できる形に直す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh` の `wait` に止まった子の判断と返事を足し、`reply` を足す。develop の SKILL.md の Orca 経路で `stopped` を受けたときの扱いを「報告する」から「主に上げる説明を書く・主の答えを届ける」に変え、親が通してよい範囲の基準と、時間がたった子への返事の規則のうち親が通した判断の記録を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`wait` の `--resolve <epic>`、`reply` サブコマンド、冒頭のコメントと使い方）
- `plugins/dev-workflow/scripts/stop-judge.sh`（新規。判断の入力を集めて小さなモデルを 1 回呼び、結果を決まった形で返す。`orca` の語を含まない）
- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`（新規。親が通してよい範囲の基準の案と、判断の出力の形）
- `plugins/dev-workflow/skills/develop/SKILL.md`（Orca 経路の手順 2 と 8、子が止まるときの節に 1 項目）
- `plugins/dev-workflow/skills/develop/references/reply-after-idle.md`（親が通した判断の復元、端末の有無の確かめ方）
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`plugins/dev-workflow/tests/stop-judge.bats`（新規）
- `plugins/dev-workflow/changes/1034.md`（変更の記録）
- 止まった件ごとに小さなモデルの判断が 1 回増える（既定 `sonnet`。`EPIC_DISPATCH_JUDGE_MODEL` で変えられる）。主に上げるときは親の説明 1 ターン
- 範囲外: 子の記録の 2 行目以降の形と完了報告（#1036）、子の PR のマージ（#1030。マージの可否はこの基準では通さない）、子が自分で決められることを主に聞かない規則（#1035）、主の判断が要るもののうち gene に任せるもの（この子が動いてから考える）
