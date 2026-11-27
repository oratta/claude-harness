# Proposal

## Why

エピックの子の入力フック（`scripts/epic-child-state.sh` の input）は、予約文でも起動時の指示でも `親エピック #` / `主の返事（親エピック #` で始まる返事でもないプロンプトを、すべて `sender = owner`（主が子のタブで打った入力）と記録する。裏で走らせたコマンドの終わりの通知（`<task-notification>` で始まるプロンプト）もここで `owner` になるため、その通知で起こされたターンが `主の返事待ち` で終わっても、親の見張り（`epic-dispatch.sh wait --watch-stopped`）は「主が打った入力から始まった返事待ち」とみなして止まりに数えない。親は `EPIC_DISPATCH_OWNER_AWAY_SEC`（既定 3600 秒）がたつまで気づかず、2026-11-25 のエピック genetta-inc/flatmate#2333 で子 #2348（PR のマージ待ちに 30 分以上気づかず）と子 #2332 の 2 回続けて起きた。`epic-dispatch.sh` の別の場所（声かけの判定・作業待ちの判定）と `child-log-read.py` はこの通知を主の発言から外しており、記録の側だけが見分けていない（https://github.com/oratta/claude-harness/issues/1821 ）。

## What Changes

- 入力フックは、先頭の空白を除いたプロンプトが `<task-notification` / `<local-command-` / `<bash-input>` / `<bash-stdout>` / `<bash-stderr>` のどれかで始まる入力を `owner` と記録しない。これは `epic-dispatch.sh` が主の発言から外している接頭辞の一覧と同じ 5 つで、`<command-name>` の見分け（後ろの行を見る必要がある）は入力の時点では使えないので含めない
- そうした入力の送り手は、同じセッションの直前の入力の `sender`（`owner` / `parent` / `startup`）を引き継ぐ。世代は 1 増やし、受付時刻・会話ログの位置を更新し、`turn_state` を `null` にする（ほかの通常入力と同じ無効化）。送り手の値の種類（`owner` / `parent` / `startup`）は増やさない
- 結果として、親か起動時の指示から始まった作業の通知で起こされたターンが `主の返事待ち` で終われば `wait --watch-stopped` が `stopped <N>` を返し、主が打った入力から始まった作業の通知のターンは今までどおり `owner` で `owner-away` の扱いになる
- 子向けの手順 `skills/develop/references/epic-child-stop.md` の送り手の説明に、この引き継ぎを 1 文足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-epic-state`: 要件「入力の送り手は予約文と起動形と先頭の接頭辞で決める」の「残りを `owner`」から非主の接頭辞の入力を外し、その入力が直前の送り手を引き継ぐ要件を足す

## Impact

- `plugins/dev-workflow/scripts/epic-child-state.sh`（input の送り手の決め方。聖域）
- `plugins/dev-workflow/tests/epic-child-state.bats`（通知のターンの記録と、`wait --watch-stopped` の `stopped` / 本当の主の入力の `owner-away` のテスト）
- `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`（送り手の説明）
- `epic-dispatch.sh`・`child-log-read.py`・記録の型の検査（`owner` / `parent` / `startup` の 3 値）は変えない。以前の版の親の見張りも新しい記録をそのまま読める
