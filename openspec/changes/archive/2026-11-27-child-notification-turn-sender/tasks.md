# Tasks

## 1. 入力フックの送り手の決め方

- [x] 1.1 `epic-child-state.sh` の input で、予約文・起動形の判定のあと、先頭の空白を除いた `prompt` が `<task-notification` / `<local-command-` / `<bash-input>` / `<bash-stdout>` / `<bash-stderr>` のどれかで始まれば `sender = i['sender']`（同じセッションの直前の送り手）にする。世代・受付時刻・`transcript_offset`・`turn_state: null` の扱いは通常入力と同じまま。接頭辞の一覧は `epic-dispatch.sh` の `not_input` と同じ順・同じ 5 つで書き、コメントにその出典を書く。確かめ方: 下の 1.2 のテストが通る。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:163-180（`if mode == 'input':` の送り手を決める部分）、plugins/dev-workflow/scripts/epic-dispatch.sh:1626-1633（`not_input` の一覧。読むだけ）
- [x] 1.2 `epic-child-state.bats` に記録のテストを足す: 登録（`startup`）→ `<task-notification>` の入力で `sender` が `startup` のまま世代が 1 増え `turn_state` が `null`、`親エピック #1 の判断: ok`（`parent`）のあと 5 つの接頭辞（先頭に空白・改行を置いた形を含む）でどれも `parent`、主の通常入力（`owner`）のあとの通知で `owner`、本文の途中にだけ `<task-notification>` がある入力は `owner`、`parent` の入力のあと `<command-name>` を含むプロンプト（例 `<command-name>/compact</command-name>`）は `owner`（design.md 決定 3 の確認）。確かめ方: `bats plugins/dev-workflow/tests/epic-child-state.bats` が通り、1.1 を戻すと通知の分が落ちる。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:1-43（setup・`input`・`register`・`stop` の helper）、plugins/dev-workflow/tests/epic-child-state.bats:54-70（送り手のテストの書き方）

## 2. 親の見張りまでつないだテスト

- [x] 2.1 `epic-child-state.bats` に、`parent_fixture` の記録と会話ログに対して、入力フックで `parent` の入力 → `<task-notification>` の入力 → Stop（`状態: 主の返事待ち — <中身>`）を通して記録を作り、`dispatch wait --interval 0 --timeout 0 --watch-stopped 11` が `stopped 11` を返す（exit 0、`stop` が `stopped-seen`）テストを足す。入力フックの payload の `cwd` / `transcript_path` / `session_id` は記録の `worktree` と `put_chat` の会話ログに合わせる（合わせにくければ、入力フックが作った `turn_input` を `put_turn` 相当で記録に写す形でもよいが、`sender` は入力フックの出力から取る）。確かめ方: そのテストが通り、1.1 を戻すと `stopped 11` が出ず落ちる。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:206-211（`parent_fixture`）、plugins/dev-workflow/tests/epic-child-state.bats:1014-1030（`parent_fixture` で `wait --watch-stopped` を回す既存テスト）、plugins/dev-workflow/tests/epic-dispatch.bats:88-130（`put_record`・`put_turn`）、plugins/dev-workflow/tests/epic-dispatch.bats:7124-7140（`put_chat`）、plugins/dev-workflow/tests/epic-dispatch.bats:7445-7446（`said`・`turn_end`）
- [x] 2.2 同じ形で、主の通常入力（`owner`）→ Stop（`主の返事待ち`）の記録と、主の通常入力 → `<task-notification>` の入力 → Stop（`主の返事待ち`）の記録のどちらでも、`wait --watch-stopped 11` が `stopped` を返さず、`turn_state.recorded_at` を既定 3600 秒より前にした記録では `owner-away 11` を一度だけ返し、子への送信・`stop` の変更が無いことを確かめるテストを足す。確かめ方: そのテストが通る（今の実装でも通る回帰のテスト）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9748-9822（既存の `wait owner-away` のテストの書き方）、plugins/dev-workflow/tests/epic-child-state.bats:994-1013（owner の作業報告を `parent_fixture` で確かめる既存テスト）

## 3. 子向けの手順

- [x] 3.1 `epic-child-stop.md` の「毎ターンの入力と状態行」の送り手の説明に、`<task-notification` など 5 つの接頭辞で始まる入力（裏の作業の終わりの通知など）は直前の送り手を引き継ぐことを 1 文で足す。確かめ方: `bats plugins/dev-workflow/tests/epic-child-state.bats` の docs のテスト（`docs:` で始まるもの）が通り、`grep -n '直前の送り手' plugins/dev-workflow/skills/develop/references/epic-child-stop.md` が 1 行出る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:5-8

## 4. 全体の確認

- [x] 4.1 `bats plugins/dev-workflow/tests/epic-child-state.bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/owner-message-number-check.bats` が通り、`openspec validate child-notification-turn-sender --type change --strict` が通る

## Workflow follow-up

- 聖域（`epic-child-state.sh`）に触るので、PR は auto-merge されず主の承認でマージする
- レビューの要件を満たしたら change を archive する
