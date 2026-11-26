## MODIFIED Requirements

### Requirement: 子 1 ファイルの記録は決まった項目を持つ

子 1 ファイルの記録は JSON のオブジェクト 1 つで、次の項目を持たなければならない（MUST）。読み手は知らない項目を無視しなければならない（MUST）。

| 項目 | 型 | 中身 |
|---|---|---|
| `schema` | 数 | 書式の版。`1` |
| `epic` | 文字列 | `<owner>/<repo>#<エピック番号>` |
| `child` | 文字列 | `<owner>/<repo>#<子の番号>` |
| `repo` | 文字列 | 子のリポジトリ `<owner>/<repo>` |
| `number` | 数 | 子の issue 番号 |
| `launcher` | 文字列 | 子を起動した起動部品（この版では `orca`） |
| `parent_worktree` | 文字列 | 親のワークツリーの絶対パス |
| `worktree` | 文字列 | 子のワークツリーの絶対パス（作る前は空） |
| `branch` | 文字列 | 子のワークツリーのブランチ名（`refs/heads/` を除く。読めなければ空） |
| `base` | 文字列 | 子のワークツリーの起点ブランチ |
| `session` | 文字列 | 起動部品が子のセッションに届く手がかり（Orca は端末のハンドル。無ければ空） |
| `launch_failed` | 文字列 | `launch` が記録を書いたあとで失敗した段（`create`: 作成の呼び出しは成功したが path を読めない／`terminal`／`ready`／`send`。成功なら空） |
| `status` | 文字列 | `running`・`waiting`・`done` のどれか |
| `stop` | 文字列 | 空・`stopped`・`stopped-seen`・`resumed` のどれか |
| `stop_uuid` | 文字列 | 親の `wait` が止まりとして受けた最後の子の発言の uuid（任意。無ければ空として読む） |
| `stop_at` | 文字列 | 親の `wait` が止まりとして受けた UTC の時刻（任意。無ければ空として読む） |
| `keepalive` | 文字列 | 親の `wait` が止まった子へ出すキャッシュの声かけの、最後の判定の結果 `<UTC の時刻> <結果>`（任意。無ければ空として読む。結果は要件「声かけの判定結果は子の記録の keepalive に残す」の語彙） |
| `created_at` / `updated_at` | 文字列 | UTC の `YYYY-MM-DDTHH:MM:SSZ` |

`status` は今のボードの列（`running` は印なし、`waiting` は `in-review`、`done` は `completed`）に、`stop` は今のコメント欄（`stopped` は `epic-stopped`、`stopped-seen` は `epic-stopped-seen`、`resumed` は `epic-resumed`）に当たり、値の遷移は今の印と同じにしなければならない（MUST）。ただし `stop` は子の `mark` に加えて親の `wait` と `dismiss` も書き（`wait` は空・`resumed` から `stopped-seen`、`stopped-seen` から `resumed`。`dismiss` は `stopped-seen` から `resumed`）、`resumed` への書き換えも Orca の印へ写す（MUST）。`keepalive` は親の `wait` だけが書く（MUST）。`stop_uuid` と `stop_at` は親の `wait` だけが書き（MUST）、子の `mark` と `dismiss` は変えない（MUST NOT）。止まった理由の本文は記録に持たず、子 issue の `子の停止: 主の返事待ち` のコメントを正本のままにする。そのコメントを持たない止まりでは、子の最後の発言を正本とする。`session` はこの版では Orca の `launch` と、起動し直した `reply`（`notify-closed`・`wait --resolve` の起動し直しを含む）が端末のハンドルを書き、`adopt` は空のまま書く（見張りの判定には使わない。子の会話ログのファイル名とも一致しないので、会話ログを選ぶ根拠にしてはならない（MUST NOT））。

次のどれかに当たる記録は「読めない記録」とする: JSON のオブジェクトとして読めない／`schema` が `1` でない／`status` か `stop` が上の表に無い値／`epic`・`child`・`repo`・`number`・`parent_worktree`・`worktree` のどれかが無いか型が違う／`stop_uuid`・`stop_at`・`keepalive` があって文字列でない。読めない記録は書き換えも削除もしてはならず（MUST NOT）、サブコマンドごとに次のとおり扱わなければならない（MUST）。どの場合も stderr にその記録のパスを出す。

| サブコマンド | 読めない記録の扱い |
|---|---|
| `wait` | その子の印を読めなかったポーリングとして、今の「一覧を読めない」と同じく失敗したポーリングに数える（3 回続けば `gh` で失敗した子がいなければ `error workspaces`） |
| `reap` | `kept <N> state-unreadable`（何も消さない） |
| `pending-owner` | その子を飛ばす（`pending` を出さない） |
| `notify-closed`・`reply`・`dismiss` | `failed <N> state-unreadable` |
| `launch` | その子自身の記録なら `failed <N> state-unreadable`（作り直さない）。枠の数では、ほかの子の読めない記録を使用中の 1 枠に数える |
| `adopt` | `failed <N> state-unreadable` |
| `clear` | 消す対象のエピックのディレクトリにある読めない記録は、stderr に `remaining state record: unreadable (<パス>)` と出してからディレクトリごと消す（ディレクトリ単位の削除で、個別の書き換え・削除はしない） |
| `mark`・`route`（今のワークツリーのパスで探すとき） | その記録を候補から外す |

この要件の守備範囲で入力として扱うのは、`launch`・`adopt`・`mark`・`wait`・`dismiss` 自身が書いた記録のファイルで、人が手で書く想定はしない。拾いたい誤りは、書き込みの途中で殺されたプロセスや版の違うスクリプトが残した記録を、正しい状態として読んで子を片付けたり見張りから落としたりすることである。次は通してよく、この要件では止めない: 項目の値どうしの矛盾（`child` の番号と `number` が違う・`worktree` が別のリポジトリを指す）／`created_at` と `updated_at` の形の崩れ／`mark`・`route` が読めない記録を候補から外したために、その子が自分を `no-workspace` と判定すること（一時ファイルからの置き換えで途中まで書かれた記録は生じないので、起きるのは人が手で壊したときだけ）。壊れ方を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 壊れた記録の子は reap で残す
- **WHEN** 子 12 の記録の中身が `{` だけの状態で `epic-dispatch.sh reap 12` を実行する
- **THEN** stdout は `kept 12 state-unreadable` で、記録もワークツリーも消されず、stderr に記録のパスが出る

#### Scenario: 読めない記録が続くと wait は error workspaces
- **WHEN** 子 11 が open で、記録の `stop` が `paused`（表に無い値）の状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error workspaces` の 1 行で exit 1、記録は変わらない

#### Scenario: 起動した子の記録の項目
- **WHEN** `epic-dispatch.sh launch 1122 1123` が `launched 1123` を返す
- **THEN** 記録の `schema` は 1、`epic` は `oratta/claude-harness#1122`、`child` は `oratta/claude-harness#1123`、`repo` は `oratta/claude-harness`、`number` は 1123、`launcher` は `orca`、`worktree` は子のワークツリーのパス、`status` は `running`、`stop` は空、`launch_failed` は空で、`created_at` と `updated_at` が UTC の形である

#### Scenario: 知らない項目があっても読める
- **WHEN** 記録に `extra: 1` の項目を足してから `epic-dispatch.sh mark done 1123` を子のワークツリーで実行する
- **THEN** `status` が `done` になり、`extra` は残っている

#### Scenario: 止まりの項目が無い記録も読める
- **WHEN** `stop_uuid` と `stop_at` の無い以前の記録を `wait` と `pending-owner` が読む
- **THEN** 読めない記録にならず、どちらも空として扱う

#### Scenario: keepalive の項目が無い記録も読める
- **WHEN** `keepalive` の無い以前の記録を `wait` と `pending-owner` が読む
- **THEN** 読めない記録にならず、空として扱う

#### Scenario: keepalive が文字列でない記録は読めない記録
- **WHEN** 記録の `keepalive` が数で `epic-dispatch.sh reap 12` を実行する
- **THEN** stdout は `kept 12 state-unreadable` で、記録は変わらない

## ADDED Requirements

### Requirement: 止まった子への声かけは本体の会話ログ 1 本で判定する

親の `wait` が止まった子（`stop` が `stopped-seen`）へ出すキャッシュの声かけの可否は、子の会話ログの置き場に複数の `.jsonl` があっても、本体の会話のログ 1 本だけで判定しなければならない（MUST）。本体のログは次の順で 1 本に決める（MUST）。(1) 置き場の直下の `*.jsonl` のうち、`entrypoint` が `cli` ちょうどで `isSidechain` が true でない assistant の行を持つファイルを候補にする。(2) 候補のうち、全行の `timestamp` の最大値が最も新しい 1 本を選ぶ。最大値が最も新しいファイルが 2 本以上あるとき、または最大値を決められないときは決めない。(3) 記録の `stop_uuid` が空のときは決めない。空でないときは、選んだファイルがその uuid の行を持たなければ決めない。

#### Scenario: 置き場に複数のログがあっても本体のログで送る
- **WHEN** 子の会話ログの置き場に、`entrypoint` が `cli` の本体のログ、`entrypoint` が `sdk-py` の短いログ、古い `cli` の過去のセッションのログがあり、本体のログが最も新しく、ほかの送る条件を満たす
- **THEN** 起動部品の `keepalive` が 1 回呼ばれ、記録の `keepalive` は `<時刻> sent` になる

#### Scenario: 最終活動が同時刻の候補は決めない
- **WHEN** 2 本の `cli` のログの `timestamp` の最大値が同じで、どちらも記録の `stop_uuid` を持つ
- **THEN** 起動部品の `keepalive` は呼ばれず、`skipped no-transcript` になる

### Requirement: 本体のログを決められないときは声かけを送らない

本体の会話のログを決められないときは本体のログなしとし、声かけを送ってはならない（MUST NOT）。本体が書けなくなって過去の `cli` のログだけが残る場合も、`stop_uuid` の確認で本体のログなしになる。記録の `session` は端末のハンドルなので、会話ログの選択に使ってはならない（MUST NOT）。

#### Scenario: 本体のログが無く過去の cli のログだけ残るときは送らない
- **WHEN** 置き場に過去の `cli` のログだけがあり、記録の `stop_uuid` がそのログに無い
- **THEN** 起動部品の `keepalive` は呼ばれず、記録の `keepalive` は `<時刻> skipped no-transcript` になる

#### Scenario: stop_uuid が空の記録には送らない
- **WHEN** 本体のログが欠けて過去の `cli` のログが 1 本だけ残り、記録の `stop_uuid` が空である
- **THEN** 起動部品の `keepalive` は呼ばれず、`skipped no-transcript` になる

#### Scenario: 本体のログが無ければ送らない
- **WHEN** 置き場の `*.jsonl` が `entrypoint` が `sdk-py` のものだけ、または 0 本である
- **THEN** 起動部品の `keepalive` は呼ばれず、記録の `keepalive` は `<時刻> skipped no-transcript` になる

### Requirement: 声かけの判定は選んだ 1 本のログだけから読む

声かけの判定に使う会話ログの読み取り（最後のキャッシュの書き込みの時刻と枠の長さ、質問、主の答え、最後のリクエスト）は、選んだ 1 本だけから行わなければならない（MUST）。ほかのログのキャッシュの書き込みを採用してはならない（MUST NOT）。`wait` の待ち時間の上限の既定を決める読み取りは対象外で、今までどおり置き場の全ログを読む。

#### Scenario: キャッシュの書き込みは選んだログのものだけを使う
- **WHEN** 本体のログの最後のキャッシュの書き込みは 5 分の枠で、過去の `cli` のログに 1 時間の枠の書き込みがある
- **THEN** 起動部品の `keepalive` は呼ばれず、`skipped cache-unknown` になる

### Requirement: wait --resolve の起動し直しの判定も同じ本体のログを使う

`wait --resolve` の起動し直しの判定（会話量と経過時間）も、同じ選び方で本体のログを決めなければならない（MUST。詳細は dev-workflow-develop の「wait --resolve は通す返事を送る前に起動し直すかを表で決める」）。ログが複数あることだけを理由に「起動し直さない」へ倒してはならない（MUST NOT）。

#### Scenario: 複数のログがあっても起動し直しの判定は本体のログを使う
- **WHEN** 置き場に本体のログと `sdk-py` の短いログがあり、本体のログが 90 分前で会話量が閾値以上である
- **THEN** `wait --resolve` は起動し直す

### Requirement: 声かけの判定結果は子の記録の keepalive に残す

声かけの判定をしたとき、`wait` はその結果を子の記録の `keepalive` に `<UTC の時刻> <結果>` で書かなければならない（MUST）。結果は `sent`、`skipped <理由>`、`failed <理由>` の形とし、語彙に無い理由を書いてはならない（MUST NOT）。直前の結果が時刻を除いて同じときは書き直してはならない（MUST NOT。ポーリングごとの書き込みを避ける）。

#### Scenario: 同じ結果は書き直さない
- **WHEN** 同じ理由で続けて 2 回ポーリングする
- **THEN** 2 回目は記録の `keepalive` の時刻が変わらない

### Requirement: 判定より前に外れる skipped の理由は次の語に限る

判定より前に外れるときの `skipped` の理由は次の語に限る（MUST）。`not-stopped`（`stop` が `stopped-seen` でないか `status` が `done`）・`no-session`（`session` が空）・`launch-failed`・`no-worktree`・`unsupported-launcher`（`launcher` が `orca`・`tmux` でない）・`gh-failed`（子かエピックのコメントを読めない）。

#### Scenario: 止まっていない子には not-stopped が 1 回だけ書かれる
- **WHEN** `stop` が `stopped-seen` でない子を 2 回続けてポーリングする
- **THEN** 記録の `keepalive` は `<時刻> skipped not-stopped` で、2 回目は時刻が変わらない

### Requirement: 会話ログによる skipped の理由は次の語に限る

会話ログによって送らないときの `skipped` の理由は次の語に限る（MUST）。`no-transcript`（本体のログなし）・`cache-unknown`（選んだログの最後のキャッシュの書き込みが 1 時間の枠でないか読めない）・`cache-future`（その時刻が今より未来）・`expired`（止まりから 24 時間以上、または基点を読めない）・`answered`（親が通した判断がある、または主が答えた）・`no-question`・`out-of-window`（最後のリクエストからの経過が送る範囲にない）・`too-large`（会話量が起動し直しの閾値以上）・`pending`（前の声かけに返事が来ていない）。

#### Scenario: 送らなかった理由が記録から読める
- **WHEN** 起動部品が `skipped dialog` を返す、止まりから 24 時間を過ぎている、画面は送れるが親が通した判断が既にある、をそれぞれ用意する
- **THEN** 記録の `keepalive` はそれぞれ `skipped dialog`、`skipped expired`、`skipped answered` で終わる

### Requirement: 起動部品の結果も keepalive に残す

起動部品が `skipped` を返したときは起動部品の理由（`no-terminal`・`ambiguous-terminal`・`busy`・`dialog`・`input-not-empty`・`unknown-state`）を `skipped <理由>` に、`failed` を返したときはその語を `failed <理由>` に入れなければならない（MUST）。

#### Scenario: 起動部品が skipped を返すと理由が残る
- **WHEN** 起動部品が `skipped dialog` を返す
- **THEN** 記録の `keepalive` は `<時刻> skipped dialog` で終わる

### Requirement: 記録の書き込みは wait の出力を変えない

記録を書けなくても、`wait` の判定・送信・stdout の行・exit code を変えてはならない（MUST NOT）。stderr の出力も、記録を書けなかった旨の 1 行を除いて変えない（MUST NOT）。

#### Scenario: wait の stdout と exit code は変わらない
- **WHEN** 声かけの判定が `sent`・`skipped`・`failed` のそれぞれになる状況で `wait` を実行する
- **THEN** stdout の行と exit code は、この変更の前と同じである
