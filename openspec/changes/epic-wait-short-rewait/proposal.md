## Why

別セッション方式の親は `epic-dispatch.sh wait` を背景で起動して待つ。親の会話に何かが書き込まれるのは、子が閉じた・終わった・止まったときと、上限（既定 21600 秒＝6 時間）に達したときだけなので、子に動きの無い時間が 1 時間を超えると親の会話キャッシュが切れ、起きた 1 ターンで会話全体を書き直す。エピック #1038 を回した親の実測では、165〜359 分静かだったあとの 1 ターンが $1.7〜1.8、5〜30 分おきに起きたときは $0.14〜0.47 だった（#1324 の本文）。上限を 1 時間より短くして、上限で起きたら何もせずに同じ `wait` を掛け直せば、起床 1 回の費用は会話の読み出し（会話 15 万トークンで約 $0.03〜0.05 の見込み）で済む。

ただし使用量の超過中（Claude Code がクレジットを使っている間）は、Claude Code が会話のキャッシュの有効期限を 5 分に縮める（https://code.claude.com/docs/en/prompt-caching の "Claude Code drops the main conversation to the five-minute TTL"）。このときは短く起きてもキャッシュは残らず、起きるたびに書き直しの費用だけがかかるので、今の 6 時間に戻す。

## What Changes

- `epic-dispatch.sh wait` の上限の既定を、親の会話キャッシュの有効期限で決める。`--timeout` も `EPIC_DISPATCH_TIMEOUT` も無いとき、親のワークツリーのトランスクリプトで、対話の CLI のセッション（`entrypoint` が `cli`）が最後にキャッシュを書き込んだ行が 5 分の有効期限だけ（`ephemeral_5m_input_tokens` が正で `ephemeral_1h_input_tokens` が 0）なら 21600 秒、それ以外（1 時間の書き込みがある・判定できない）なら 2700 秒にする。選んだ上限と判定を stderr に 1 行出す。`--timeout` と `EPIC_DISPATCH_TIMEOUT` は今までどおりその値をそのまま使う（判定しない）
- 親のキャッシュの有効期限を読む関数を `epic-dispatch.sh` に置く。順番 2 の change（`epic-child-cache-keepalive`。子への声かけ）が子のワークツリーに同じ関数を使うので、入力と出力の契約を design に書く
- develop の `references/epic.md` 手順 5 を書き換える。`timeout` で起こされたら、親は子の issue を見に行かず、主に報告もせず、同じ引数の `wait` を背景で 1 回掛け直してターンを終える。`needs-approval` を見て報告する確認と、子エピックの行で子を外す確認は `timeout` からは外す（`closed` などで起こされたときと、待ちをやめる直前の確認には残す）。記録を残さずに子のタブで質問して止まった子に気づけない旨は手順 5 に注記として残し、主へは `launch` のあと最初に手順 2 で待ちに入る通知で一度だけ伝える
- 手順 4 の、片付け待ちの子だけを待つ `wait` には `--timeout 21600` を付ける（この待ちは `timeout` で終わったらやめる待ちなので、短い上限にすると子のマージを待つ時間が 45 分に縮むため）
- `references/reply-after-idle.md` に、親の待ちの費用の扱い（短い上限で起きて掛け直す理由・使用量の超過中は長い上限に戻すこと・有効期限を固定した人の扱い・PC が寝ていたときに効かないこと）を別の節として足す。#1323 が触る閾値の表と、そのまま送るか起動し直すかの表には手を出さない

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 上限の既定の決め方と、親が上限で起きたときの掛け直しの要件を足し、同じ振る舞いを規定している次の既存要件を変える
  - 「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」: `wait` の上限の既定
  - 「エピックの条件・作り方・回し方・完了条件を規定する」: `timeout` で起こされた親の扱い
  - 「エピックの並列起動は 1 段で止める」: 子エピックの行で子を外す確認を `closed` で起こされたときだけにする
  - 「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」: 記録を残さずに止まった子に気づけないことを主へ伝える場所を、手順 5 から、`launch` のあと最初に待ちに入る通知に移す
  - 「別のリポジトリの子を含むエピックの回し方を epic.md に書く」: 読み替えの表の「手順 2・`timeout` と `closed` の確認」を「手順 2・`closed` の確認」にする
  - 「エピックの親が主に出す発言は、正本の 1 行目の書き分けに従う」: 発言の一覧から手順 5 の `timeout` の報告を外す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_wait` と、有効期限を読む関数の追加、冒頭の説明）
- `plugins/dev-workflow/skills/develop/references/epic.md`（手順 4・5・6 と、子エピックの行で子を外す確認の段落）
- `plugins/dev-workflow/skills/develop/references/reply-after-idle.md`（節の追加）
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`plugins/dev-workflow/tests/develop-skill.bats`（テストの追加）
- `plugins/dev-workflow/changes/1324.md`（変更の記録）
- 常時注入される部品（`rules/`・`CLAUDE.md`・`description`）は触らない
