## MODIFIED Requirements

### Requirement: 子の声かけには最後のリクエストと停止期間の期限を適用する

判定の守備範囲は要件「子への声かけ文と返事の形は一か所の定義を共有する」の「判定要件に共通の守備範囲」に従う。

声かけは、子の最後の成功した CLI リクエストからの経過が 3000 秒以上かつ 3600 秒未満で、記録の `stop_at`（空なら同じ停止の記録の作成時刻）から `EPIC_DISPATCH_OWNER_WAIT_SEC`（0 以上の整数。既定 43200）秒未満のときだけ送らなければならない（MUST）。この値は要件「wait は主に伝え済みの止まりだけが残るあいだ上限で起きずに待つ」の長い待ちの上限と同じ値である。声かけや wait 掛け直しで停止の基点を延ばしてはならない（MUST NOT）。起動し直しの会話量条件に該当する子、時刻・会話量・現行セッションを判定できない子、前の声かけの返事が未着の子には送らない（MUST NOT）。

#### Scenario: 最後のキャッシュ読み出しをリクエストとして扱う
- **WHEN** 1h のキャッシュ書き込みは 2 時間前だが、現在の一意の CLI セッションの最後の有効な assistant usage は cache-read のみで 3000 秒前であり、他の条件も満たす
- **THEN** 固定文を送る。書き込みの時刻をリクエストの時刻として使わない

#### Scenario: 境界とスリープ復帰
- **WHEN** 他の条件を満たす子について最後のリクエストから 2999 秒・3000 秒・3599 秒・3600 秒、またはスリープ等で 1 時間を超える経過をそれぞれ用意する
- **THEN** 3000 秒・3599 秒の場合だけ送る。3600 秒以上では起動も声かけもせず、実際の返事時に #1323 の規則へ渡す

#### Scenario: 同じ停止の 24 時間を超えない
- **WHEN** `EPIC_DISPATCH_OWNER_WAIT_SEC=86400` で、記録の `stop_at`（空なら最新の停止記録の作成時刻）が 86400 秒以上前で、直前の声かけの返事と wait の掛け直しは 3000 秒前である
- **THEN** 固定文を送らず、停止の印を保ち、記録の `keepalive` は `skipped expired` で終わる。同じ値で停止から 86399 秒（43200 秒を過ぎていても）で他の条件を満たす場合は送る

#### Scenario: 同じ停止の既定の上限を超えない
- **WHEN** `EPIC_DISPATCH_OWNER_WAIT_SEC` を設定せず、記録の `stop_at`（空なら最新の停止記録の作成時刻）が 43200 秒以上前で、直前の声かけの返事と wait の掛け直しは 3000 秒前である
- **THEN** 固定文を送らず、停止の印を保つ。停止から 43199 秒で他の条件を満たす場合は送る

#### Scenario: 多重送信と起動し直しを避ける
- **WHEN** 前の固定文にまだ返事が無い、または会話量が既存の起動し直し閾値以上である
- **THEN** 固定文を送らず、そのために新しいセッションを起動しない

### Requirement: 声かけは wait を終了させず親の起床を増やさない

判定の守備範囲は要件「子への声かけ文と返事の形は一か所の定義を共有する」の「判定要件に共通の守備範囲」に従う。

wait は声かけの送信・返事だけを理由に stdout の行を追加したり終了したりしてはならない（MUST NOT）。送信の失敗は stderr の診断にとどめ、通常のポーリングを続ける（SHALL）。本当の closed/done/stopped と既存のエラーは従来どおり扱う（SHALL）。上限の扱いは位置引数の子で分ける。伝え済みでない子（記録の `told_uuid` が無い・文字列でない・`stop_uuid` と違う）が 1 件でもいれば、従来どおり上限で `timeout` を返す（SHALL）。全員が伝え済みの止まりなら、要件「wait は主に伝え済みの止まりだけが残るあいだ上限で起きずに待つ」の長い待ちに入り、上限で `timeout` を返さず、`EPIC_DISPATCH_OWNER_WAIT_SEC` 秒で `expired` を返す（SHALL）。どちらでも声かけの送信・返事は、長い待ちに入るか出るかの判定を変えない（MUST NOT）。規則に、打ち手が wait であり、親の追加 LLM ターンが不要なことと既存の timeout の掛け直しの費用を記す（SHALL）。

#### Scenario: 声かけの後も timeout まで待つ
- **WHEN** issue は open、status は done でなく、stop=stopped-seen で記録の `told_uuid` が無いか `stop_uuid` と違う（主に伝え済みでない）子が声かけに返し、そのあと状態に変化が無い
- **THEN** wait は声かけの時点では終了せず、既定のポーリングを続け、上限で従来の `timeout <子>` と exit 2 を返す。主の質問とその timestamp は child-log に残る

#### Scenario: 型違いの返事だけでは停止を変えず親を起こさない
- **WHEN** stop=stopped-seen の子が固定文に複数行または型違いの返事をし、他の状態は変わらない
- **THEN** child-log はその返事を表示して最後の子の発言とし、元の質問の保持は保証しない。status/stop・停止コメントは変えず、停止の基点も延ばさず、wait は声かけに由来する stdout や終了理由を追加せず通常のポーリングを続ける。別途 stopped/done/closed が発生した場合は従来どおり扱う

#### Scenario: 失敗と実際のイベントを区別する
- **WHEN** 声かけの送信に失敗し、後のポーリングで子が新しい mark stopped または done を付ける
- **THEN** 送信失敗だけでは親を起こさず、実際の stopped/done は既存の出力・終了コードで親に届く

#### Scenario: 伝え済みの子は声かけの後も上限で起こさない
- **WHEN** issue は open、status は done でなく、stop=stopped-seen で記録の `told_uuid` が `stop_uuid` と同じ（主に伝え済み）の子だけを位置引数に、`wait --watch-stopped` を掛け、その子が声かけに定義どおりの一行で返し、そのあと状態に変化が無い
- **THEN** wait は声かけの時点でも上限でも終了せず、待ちに入ってから `EPIC_DISPATCH_OWNER_WAIT_SEC` 秒で `expired <子>` と exit 0 を返す。声かけへの返事で会話ログが進んでも、記録の `stop` は `stopped-seen` のままで長い待ちから出ない

## ADDED Requirements

### Requirement: 親は主に上げた止まりを told で記録に書く

`epic-dispatch.sh told <子> <止まりの uuid>` は、今のワークツリーを `parent_worktree` に持つ子の記録について、排他の中で `stop` が `stopped-seen`・`status` が `done` でない・`stop_uuid` が空でなく引数の uuid と同じ、を確かめてから `told_uuid` にその uuid、`told_at` に UTC の時刻を書き、`told <子>` を出して exit 0 で終わらなければならない（MUST）。Orca の印へは写さない。子にも issue にも送らない（MUST NOT）。

#### Scenario: 受けた止まりを伝え済みにする
- **WHEN** 子 11 の記録が `stop` `stopped-seen`・`stop_uuid` `d1` で、`epic-dispatch.sh told 11 d1` を実行する
- **THEN** stdout は `told 11` で exit 0、記録の `told_uuid` は `d1`、`told_at` は UTC の形で、`stop`・`stop_uuid`・`stop_at` は変わらず、`orca` は呼ばれない

#### Scenario: 止まりが違えば書かない
- **WHEN** 子 11 の記録の `stop_uuid` が `d2`（または空）で、`epic-dispatch.sh told 11 d1` を実行する
- **THEN** stdout は `skipped 11 uuid-mismatch` で exit 0、記録は変わらない

### Requirement: told は書けない子を理由つきで返す

`told` は、記録が無いか `stop` が `stopped-seen` でないか `status` が `done` の子に `skipped <子> not-stopped`、記録が 2 件以上の子に `failed <子> ambiguous-worktree`、読めない記録の子に `failed <子> state-unreadable`、排他が取れない・書けない子に `failed <子>` を出さなければならない（MUST）。`failed` なら exit 1、それ以外は exit 0。引数が 2 つでない・子の形が誤り・uuid が空なら使い方を出して exit 1。jq が無い・今のワークツリーを読めなければ stdout 空で exit 1。

#### Scenario: 止まっていない子は書かない
- **WHEN** 子 11 の記録の `stop` が `resumed` で `epic-dispatch.sh told 11 d1` を実行する
- **THEN** stdout は `skipped 11 not-stopped` で exit 0、記録は変わらない

#### Scenario: 読めない記録は書かない
- **WHEN** 子 11 の記録の中身が `{` だけで `epic-dispatch.sh told 11 d1` を実行する
- **THEN** stdout は `failed 11 state-unreadable` で exit 1、記録は変わらない

### Requirement: wait は主に伝え済みの止まりだけが残るあいだ上限で起きずに待つ

`wait --watch-stopped` は、位置引数の子が 1 件以上・間隔と上限がどちらも 0 より大きく、ポーリングで出す行が無く失敗したポーリングでもなく、位置引数の子の全員の記録が「伝え済みの止まり」（`stop` が `stopped-seen`・`status` が `done` でない・`stop_uuid` が空でなく `told_uuid` と同じ）のとき、上限（自動で決めたものも明示したものも）で `timeout` を返してはならない（MUST NOT）。この待ちのあいだもポーリングと声かけは今までどおり続け、親の LLM を起こす出力をしない。一度この待ちに入ったあとの失敗したポーリング（子 issue の取得の失敗・読めない記録など、失敗の回数に数えるもの）では、待ちに入った時刻を保ち、条件を判定し直さず、普通の上限の判定も `expired` の判定もしてはならない（MUST NOT）。失敗の回数は今までどおり数え、連続 3 回で既存の `error` の行と exit 1 で返る（SHALL）。

#### Scenario: 伝え済みの子だけなら上限を過ぎても timeout を返さない
- **WHEN** 子 11 が open、記録が `stop` `stopped-seen`・`stop_uuid` `d1`・`told_uuid` `d1` で、会話ログが `d1` から進まない状態で、`EPIC_DISPATCH_OWNER_WAIT_SEC=6` を付けて `epic-dispatch.sh wait --interval 1 --timeout 2 --watch-stopped 11` を実行する
- **THEN** 2 秒の上限では終わらず、stdout は `timeout 11` を含まない

#### Scenario: 伝え済みでない子が 1 件でもいれば今までどおり
- **WHEN** 子 11 は伝え済みの止まり、子 12 は `stop` が空で作業中の状態で `wait --interval 1 --timeout 2 --watch-stopped 11 12` を実行する
- **THEN** 上限 2 秒で stdout は `timeout 11 12` の 1 行で exit 2

#### Scenario: 伝えた止まりと違う止まりなら待たない
- **WHEN** 子 11 の記録が `stop_uuid` `d2`・`told_uuid` `d1` で、同じく `wait --interval 1 --timeout 2 --watch-stopped 11` を実行する
- **THEN** 上限 2 秒で stdout は `timeout 11` の 1 行で exit 2

#### Scenario: 待ちをやめる前の 1 回の確認は長い待ちに入らない
- **WHEN** 子 11 が伝え済みの止まりで `wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stdout は `timeout 11` の 1 行、stderr は空で exit 2

#### Scenario: 上限を過ぎてからの一時の取得の失敗では起こさない
- **WHEN** 子 11 が伝え済みの止まりのまま変わらず、`EPIC_DISPATCH_OWNER_WAIT_SEC=6` で `wait --interval 1 --timeout 2 --watch-stopped 11` を実行し、2 秒の上限を過ぎたあとのポーリングで子 11 の issue の取得が 1 回だけ失敗し、次のポーリングから成功する
- **THEN** 失敗したポーリングでも次のポーリングでも `timeout` を出さず、待ちに入ってから 6 秒で stdout は `expired 11` の 1 行で exit 0

#### Scenario: 長い待ちでも取得の失敗が続けば error で返る
- **WHEN** 子 11 が伝え済みの止まりで長い待ちに入ったあと、子 11 の issue の取得が 3 回続けて失敗する
- **THEN** stdout は `error gh 11` の 1 行で exit 1。`timeout` と `expired` の行は出ない

### Requirement: 長い待ちは止まりの変化で既存の行で返る

長い待ちのあいだに、子の止まりの uuid が変わったら `stopped`、子 issue が閉じたら `closed`、会話ログが止まりの発言より進んで記録が `resumed` になったら（主の返事が届いた）普通の上限の判定に戻し、その上限を過ぎていれば `timeout` の行で返らなければならない（MUST）。新しい行を足してはならない（MUST NOT）。

#### Scenario: 子 issue が閉じたら closed で返る
- **WHEN** 伝え済みの止まりの子 11 で長い待ちに入ったあと、子 11 の issue が `closed` を返すようになる
- **THEN** stdout は `closed 11` の 1 行で exit 0

#### Scenario: 止まりが変わったら stopped で返る
- **WHEN** 長い待ちに入ったあと、子 11 の会話ログに `d1` より新しい問いの発言 `d2` が足される
- **THEN** 記録の `stop_uuid` が `d2` になり、stdout は `stopped 11` を含んで exit 0

#### Scenario: 主の返事が届いたら timeout で返る
- **WHEN** `--timeout 2` で長い待ちに入り、2 秒を過ぎてから子 11 の会話ログに `d1` のあとの主の発言が足される
- **THEN** 記録の `stop` が `resumed` になり、そのポーリングで stdout は `timeout 11` の 1 行で exit 2

### Requirement: 長い待ちは上限を過ぎたら expired の行で返る

長い待ちに入ってから `EPIC_DISPATCH_OWNER_WAIT_SEC`（0 以上の整数。既定 43200）秒たっても変化が無ければ、`wait` は stdout に `expired <位置引数の子>...` の 1 行を出して exit 0 で終わらなければならない（MUST）。判定は普通の上限と同じく、ポーリングのあとで「待ちに入ってからの経過 >= 上限」か「経過 + 間隔 > 上限」のとき。待ちの条件から外れたら入った時刻を捨て、もう一度入れば測り直す。値が 0 以上の整数でなければ、`--watch-stopped` のとき待つ前に使い方を出して exit 1。

#### Scenario: 上限を過ぎたら expired で返る
- **WHEN** 子 11 が伝え済みの止まりのまま変わらず、`EPIC_DISPATCH_OWNER_WAIT_SEC=3` で `wait --interval 1 --timeout 1 --watch-stopped 11` を実行する
- **THEN** stdout は `expired 11` の 1 行で exit 0。`timeout` の行は出ない

#### Scenario: 値の誤りは待つ前に止める
- **WHEN** `EPIC_DISPATCH_OWNER_WAIT_SEC=abc` で `wait --interval 1 --timeout 2 --watch-stopped 11` を実行する
- **THEN** 使い方を出して exit 1 で、`gh` は呼ばれない

### Requirement: 長い待ちのあいだは材料が更新されたときだけ判断し直す

`--resolve` 付きの長い待ちでは、エピックと位置引数の各子の issue について「材料の版」を持ち、版が処理済みの版から変わったときだけ、エピックの版が変われば全員を、子の版が変わればその子を、`wait --resolve` と同じ判断に 1 回かけなければならない（MUST）。材料の版は、その issue の本文と、投稿者が OWNER・MEMBER・COLLABORATOR のコメントのうち 1 行目が `親の判断: ` で始まらないもの（`id` と `updated_at`）から作る。`親の判断: ` で始まる親自身の投稿・ラベル・タイトルの変化だけでは判断してはならない（MUST NOT）。

#### Scenario: 子 issue が更新されたら 1 回だけ判断し、通せば返事を送る
- **WHEN** 長い待ちのあいだに子 11 の issue に主のコメントが 1 件足され、判断のコマンドが `判断: 通す` と返事を返す
- **THEN** 判断のコマンドはちょうど 1 回呼ばれ、子に返事が送られ、エピックに `親の判断: 子 #11 通した` の行が投稿される

#### Scenario: 更新が無ければ判断しない
- **WHEN** 長い待ちのあいだ、エピックと子 11 の `updated_at` が変わらない
- **THEN** 判断のコマンドは 1 回も呼ばれない

#### Scenario: 判断し直して主に上げても親を起こさない
- **WHEN** 子 11 の版が変わり、判断のコマンドが `判断: 主に上げる` を返す
- **THEN** 子 issue に `親の判断: 主に上げる` が投稿され、stdout に `stopped 11` は出ず、長い待ちが続く

### Requirement: 判断し直しは判断した版を処理済みにする

版は `updated_at` が前段の基準から変わったときだけ読む（SHALL）。待ちに入ったポーリングで `updated_at` と版を読んで前段の基準と処理済みの版にする。判断にかけるときは、判断の直前に読んだ版を判断した版とし、判断のあとは処理済みの版をその判断した版に、前段の基準をその版と同じときに読んだ `updated_at` にしなければならない（MUST）。判断のあとに読み直した値を処理済みにしてはならない（MUST NOT）。これにより、判断のあいだ（判断のコマンドが材料を読んでからモデルの応答を待つあいだ）に足された更新は次のポーリングで判断にかかり、判断が書いた親自身のコメントは判断にかからない。`updated_at` と版を読めないポーリングでは判断せず、前段の基準と処理済みの版を変えず、失敗したポーリングにも数えない。

#### Scenario: 親自身の判断のコメントでは判断し直さない
- **WHEN** 子 11 の issue に主のコメントが 1 件足されて判断のコマンドが `判断: 主に上げる` を返し、子 issue に `親の判断: 主に上げる` が投稿されて `updated_at` が変わり、そのあと材料が変わらない
- **THEN** 判断のコマンドはちょうど 1 回だけ呼ばれる

#### Scenario: 判断のあいだに足された更新は次のポーリングで判断する
- **WHEN** 子 11 の issue に主のコメント A が足されて判断にかかり、判断のコマンドが材料を読んだあと応答を返す前に、子 11 の本文が主によって書き換えられる（判断のコマンドのスタブが、呼ばれたときに gh のスタブの返す本文と `updated_at` を変える）
- **THEN** 判断のコマンドは 2 回呼ばれる（コメント A の版で 1 回、書き換え後の本文の版で 1 回）。2 回目のあとに材料が変わらなければ 3 回目は呼ばれない

### Requirement: 親は主に上げた止まりで told を呼び、expired で見張りを終える

`references/epic.md` は、手順 7・8 で止まった子を主に上げる報告を出したら 2 に戻る前に上げた子ごとに `told <子> <止まりの uuid>` を呼ぶこと、`expired` で起こされたらエピックに 60 分以上の再開と同じ項目の再開の記録を残し、主に 1 通だけ「見張りを止めた。子のタブで答えたら `/develop <エピック番号>` で親を再開する」と伝えて `wait` を掛けずに終えることを書かなければならない（MUST）。「待ちをやめてよい条件」にこの場合を足す（MUST）。

#### Scenario: 手順の文言がある
- **WHEN** `references/epic.md` を読む
- **THEN** `told <子> <止まりの uuid>`、`expired <N>...`、`/develop <エピック番号>` で親を再開する旨、待ちをやめてよい条件の `expired` の場合、`wait` を掛けないことが書かれている
