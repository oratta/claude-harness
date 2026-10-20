## Why

`owner-reply-check.sh` は、会話ログの user 行のうち `origin` があれば `origin.kind == "human"` のものだけを主の発言として数える。2026-10-20 に住人 gene の会話ログを確かめると、Discord 経由の発言は `origin` が `{"kind":"channel","server":"plugin:discord:discord"}` で残っていた。そのため住人の環境では、主が Discord で「許容する」と答えても pr-review-gate の「会話で受領」の真正性確認が通らず、合格にならない。

チャンネルの発言はオーナー以外も送れる。このマシンの会話ログにある `origin.kind: "channel"` の 250 行のうち 2 行は主ではない別の Discord ユーザーの発言で、gene の Discord の設定（`access.json`）ではギルドのチャンネルの送信者を絞っていない（`groups.<id>.allowFrom` が空で、bot に言及すれば誰の発言でも届く）。チャンネルの発言をそのまま数えると、主以外の「許容する」で合格してしまう。送信者が主だと確かめられる発言だけを数える必要がある。

## What Changes

- チャンネル経由の行（`origin.kind: "channel"`）を、送信者が許可された送信者のときに限って主の発言として数える。送信者は、Claude Code が本文の先頭に付ける `<channel source="…" … user_id="…" …>` の開きタグの `user_id` 属性から読む
- 許可された送信者は、新しい環境変数 `OWNER_REPLY_CHANNEL_SENDERS` に `<origin.server の値>=<送信者の ID>` の形で並べる。未設定か空なら、チャンネルの行は今までどおり 1 件も数えない
- 送信者を読めない行（開きタグの形が崩れている・`user_id` が無い・属性名が重複している・`source` が `origin.server` と違う・閉じタグで終わらない）と、許可されていない送信者の行は数えない
- チャンネルの行は、開きタグと閉じタグを外した中身（主が Discord で書いた文）を本文として比べ、`MATCH:` 行にも中身を出す。ほかの数えない条件（転送・コマンド出力・親からの返事の頭など）は中身に当てる
- `OWNER_REPLY_CHANNEL_SENDERS` の値の形が崩れていたら、どの使い方でも exit 2（確かめられない）で終わる
- `origin.kind: "human"` の行と `origin` の無い行の判定は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-owner-reply-check`: 要件「主の発言として数える行と数えない行」の ④ に、許可された送信者からのチャンネルの行を足す。チャンネルの行の送信者の確かめ方・許可された送信者の置き場・設定の誤りの扱いを新しい要件として足す

## Impact

- `plugins/dev-workflow/scripts/owner-reply-check.sh`（判定と冒頭の説明）
- `plugins/dev-workflow/tests/owner-reply-check.bats`（チャンネルの行の入力を 2026-10-20 時点の実物の形で足す）
- 呼び出し側（pr-review-gate 手順 5・develop の本体・エピックの親と子）の手順と出力の形は変わらない。住人の環境で Discord の返事を通すには `OWNER_REPLY_CHANNEL_SENDERS` の設定が要り、その設定の決まりは後続の #1126（住人が develop を使うときの決まり）が design.md「#1126 への引き継ぎ」を読んで決める
