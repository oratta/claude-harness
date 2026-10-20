## Why

Claude のリセット権（使うと 5 時間枠か週枠を戻せる権利）は期限を過ぎると消えるが、残数も期限も claude.ai の Settings > Usage を開かないと分からない。Codex の行には残数と最短期限が出ているのに、Claude の行には出ない（issue #1115）。ダッシュボード側（genetta-inc/flatmate#1654）も同じ値を `usage-probe.sh` が書く snapshot から読むので、書き出しの形を先に決めて両方に揃える。

取得元は調査 #1114 の結論: usage API に `?cedar_ember=1&skip_spend=1` を付けると、応答の `cedar_ember.grants[]` に束ごとの `resets_left`・`ends_at`・`paused` が入る（スコープ `user:profile` が要り、期限切れのトークンでは取れない。refresh はしない）。

## What Changes

- `usage-probe.sh` の既定の取得先を `https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1` に替える（呼び出しは今までどおり 1 スロット 1 回）
- snapshot の `accounts.<id>` に任意の欄 `reset_grants` を足す。`cedar_ember.grants` の各束から `resets_left`・`ends_at`・`paused` だけを値を変えずに写した配列。`cedar_ember` が無い・null、`eligible` が true でない、`grants` が配列でないときは欄を出さない。空配列はそのまま `[]`。束は選り分けない。`ends_at` は ISO 8601 の文字列か null のまま渡す
- 欄の寿命: 取得に成功したスロットはその応答から作り直す（欄の条件を満たさなければ欄なし）。取得を試みて失敗したスロットは欄を出さない（前回の値を写し直さない）。取得を試みなかったスロット（間隔内・オフ）は、既存の fail-open と同じく前回の値を `fetched_at` と一緒に保つ
- `statusline.sh` が snapshot の `accounts.<id>.reset_grants` を読み、そのアカウントの最後の行の末尾に Codex の行と同じ書式で `リセットN回・最短あとXdYh` を出す。期限まで 3 日以内は黄、24 時間以内は赤、期限の無い束だけなら `期限不明`、期限が過ぎていれば `期限経過（更新待ち）`。欄が無い・読めないときは何も足さず、出力は 1 バイトも変えない
- Codex の行と Claude の行が同じ書式の関数を使う（Codex の行の出力は変えない）
- README と、probe の契約の spec を直す

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `dev-workflow-escalation-tripwires`: 「usage-probe と snapshot 契約」に、取得先の URL・`reset_grants` 欄の形・欄の寿命を足す
- `statusline-multi-account-usage`: Claude のアカウントの行にリセット権の残数と期限を出す要件を足す

## Impact

- `plugins/dev-workflow/scripts/usage-probe.sh`、`plugins/dev-workflow/tests/usage-probe.bats`
- `plugins/statusline/scripts/statusline.sh`、`plugins/statusline/tests/`（新しい bats ファイル）、`plugins/statusline/README.md`
- 社内の実験名が付いた非公開の呼び方に頼るので、予告なく形が変わりうる。形が合わなければ欄を出さない・区画を出さないだけにして、使用率の表示は止めない
- 未確認: `cedar_ember=1&skip_spend=1` を付けた応答に `five_hour` / `seven_day` / `limits` も残るか。残らなければ使用率が取れなくなる。マージ前に主の Mac で確かめる（受け入れ条件の実機確認と同じ手順）
