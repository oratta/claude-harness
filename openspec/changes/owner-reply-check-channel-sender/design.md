## Context

`owner-reply-check.sh` は pr-review-gate 手順 5 の「会話で受領」の真正性確認と、develop の本体・エピックの親と子が使う。主の発言として数える行の 4 つ目の条件が「`origin` のキーがあるなら `origin.kind` が `"human"`」なので、チャンネル（Discord など）経由の発言は 1 件も数えない。

2026-10-20 にこのマシンの `~/.claude/projects/*/*.jsonl` で `origin.kind: "channel"` の行を全件（250 行）調べた結果:

- `origin` は全件 `{"kind":"channel","server":"plugin:discord:discord"}`。`type: "user"`、`isMeta: false`、`isSidechain: false`、`message.content` は文字列
- 本文は全件、次の形だった（開きタグは 1 行目、中身はそのあと、最後の行が閉じタグ。開きタグは 1 行に 1 個で、本文の中に 2 個目の `<channel ` は無かった）

  ```
  <channel source="plugin:discord:discord" chat_id="…" message_id="…" user="<ユーザー名>" user_id="<数字の ID>" ts="<ISO 8601>">
  <Discord で書かれた文>
  </channel>
  ```

- 属性は `source`・`chat_id`・`message_id`・`user`・`user_id`・`ts` の 6 つが基本で、リアクションの行には `reaction`、添付ファイルのある行には `attachment_count`・`attachments` が足される。`source` は全件 `origin.server` と同じ値
- 送信者は 2 人いた（主が 248 行、別のユーザーが 2 行）。チャンネルの行には主以外の発言が実際に混ざる

公式の Discord プラグイン（`~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/server.ts`）は、Discord のメッセージを `notifications/claude/channel` の通知で `content`（メッセージの本文そのまま）と `meta`（`chat_id`・`message_id`・`user`・`user_id: msg.author.id`・`ts` など）に分けて Claude Code に渡す。開きタグの属性はこの `meta` から Claude Code が組み立てたもので、送信者の書いた文（`content`）はタグの中身にだけ入る。`user_id` は Discord が付ける送信者のアカウントの ID で、送信者が自分で変えられない（`user` のユーザー名は変えられる）。

プラグインの受け付けの設定（`$DISCORD_STATE_DIR/access.json`、既定は `~/.claude/channels/discord/`）は、DM の送信者を `allowFrom` で絞り、ギルドのチャンネルはチャンネルごとの `groups.<id>.allowFrom` で絞る。住人 gene の設定では `allowFrom` が主の ID 1 件、`groups` の 6 チャンネルはどれも `allowFrom` が空（bot に言及すれば誰の発言でも届く）だった。

## Goals / Non-Goals

**Goals:**

- 許可された送信者が書いたチャンネルの発言を、主の発言として数える
- 許可されていない送信者の発言と、送信者を読めない発言は数えない（通さない側に倒す）
- `origin.kind: "human"` の行と `origin` の無い行の判定を変えない
- 後続の #1126 が、住人の環境でこの確かめ方を使うための設定の決まりを作れるよう、方法と設定の形をここに残す

**Non-Goals:**

- Discord プラグイン以外のチャンネル（Telegram など）の実物を確かめること。形が同じなら同じ規則で通るが、実物で確かめてから許可された送信者に足す
- 会話ログの改変、チャンネルプラグインやその設定の改ざん、呼び出し側が環境変数を偽って渡すことを検知すること
- 主が Discord で書いた文の許容の意思を読むこと（今までどおり呼び出し側が `MATCH:` の全文で読む）
- 住人の環境に `OWNER_REPLY_CHANNEL_SENDERS` を設定すること（#1126 の範囲）

## Decisions

### 送信者は本文の開きタグの `user_id` から読む

送信者の ID が会話ログの行に載るのは、本文の先頭の開きタグの `user_id` 属性だけだった（`origin` には `kind` と `server` しか無い）。開きタグは `meta` から Claude Code が組み立てて本文の先頭に置くので、送信者が書いた文で開きタグを差し替えることはできない。送信者が中身に `</channel><channel … user_id="<主の ID>">` と書いても、それは中身の一部で、先頭の開きタグは送信者本人の ID のまま残る。

そのため先頭の開きタグだけを読み、次をすべて満たす行だけを「送信者を読めた」とする。どれか 1 つでも外れたら数えない。

- 本文（`message.content` が文字列ならそのまま、`type: "text"` の要素だけの配列なら改行でつないだもの）が、先頭の空白なしに `<channel` で始まり、`<channel` のあとに 0 個以上の ` <名前>="<値>"`（名前は英字か `_` で始まり英数字と `_` だけ、値は `"` と改行を含まない）が続き、`>` と改行で 1 行目が終わる
- 開きタグの属性名に重複が無い（`meta` の値に `"` が混じって ` user_id="…"` が後から現れる形を、送信者を読めない側に倒す）
- `source` 属性が `origin.server` と同じ文字列で、`origin.server` が空でない文字列
- `user_id` 属性が空でない
- 本文の末尾（後ろの空白を除く）が改行のあとの `</channel>` で終わる

中身は、1 行目の改行の次から末尾の改行と `</channel>` の前まで。比べる本文と `MATCH:` 行に出す全文は中身にする（タグの属性は主が書いた文ではないので、原文の部分一致の相手にしない）。

検討した別案:

- `user`（ユーザー名）で照合する: ユーザー名は送信者が変えられ、別の人が同じ名前を名乗れるので採らない
- `origin.kind: "channel"` をすべて数える: 主以外の送信者が実際にいたので採らない

### 許可された送信者は環境変数 `OWNER_REPLY_CHANNEL_SENDERS` に置く

値は `<origin.server の値>=<送信者の ID>` を空白かカンマで区切って並べたもの（例: `plugin:discord:discord=<主の Discord のユーザー ID>`）。行の `(origin.server, user_id)` の組が並べた組のどれかと完全に一致するときだけ数える。チャンネルの種類ごとに ID の体系が違い、別のチャンネルで同じ文字列の ID が別人を指しうるので、ID だけでなくチャンネル（`origin.server`）と組にする。

- 未設定、または空白とカンマだけの値: チャンネルの行は 1 件も数えない（今までと同じ）
- 区切ったあとの各項目が `<空白・カンマ・= を含まない 1 文字以上>=<空白・カンマ・= を含まない 1 文字以上>` の形でないものが 1 つでもあれば、使い方によらず stderr に理由を出して exit 2（確かめられない）。誤った設定を「一致なし」の exit 1 と区別して気づけるようにする。値はチャンネルの行が無い会話ログでも確かめる（チャンネルの返事が来た時点で初めて設定の誤りに気づく、という遅れを作らない）

検討した別案:

- Discord プラグインの `access.json` の `allowFrom` を読む: (a) 置き場が住人ごとに違い（`DISCORD_STATE_DIR` で `~/.claude/channels/discord-gene/` などに分けている）、ゲートを回すプロセスからどの設定が今のセッションのものか決められない (b) `allowFrom` は「DM を送れる人」の一覧で、主だけとは限らない（ギルドのチャンネルの `allowFrom` は空のこともある） (c) Discord プラグインの内部の形に結び付き、他のチャンネルに広げられない。この 3 点で採らない
- 設定ファイルを新しく作る: 1 行の値のためにファイルの置き場と読み方の決まりが増える。環境変数なら `settings.json` の `env` で住人のセッションごとに置け、bats でも差し替えやすい

### チャンネルの行にも、ほかの数えない条件を中身に当てる

⑥（転送）・⑦（コマンド出力）・⑨（親からの返事の頭・起動の指示）は中身に当てる。主が Discord に `親エピック #…` と書き始めた文は数えない（今の対話の発言と同じ扱い。確かめられない側に倒れ、主に聞き直す）。⑤ の本文の形（文字列か text の要素だけの配列）と ①〜③・⑧ は行に当てる（今までどおり）。

### 3 つの使い方で同じに扱う

既定の使い方・`--locate`・`--relayed` は同じ判定（`owner_text`）を使うので、チャンネルの行も 3 つで同じに扱う。`--relayed` の not-direct（親の報告と主の答えのあいだに別の主の発言がある）も、許可された送信者のチャンネルの発言を主の発言として数える。

## Risks / Trade-offs

- [Claude Code が開きタグの形を変える] → 送信者を読めない側に倒れて数えなくなる（合格しないだけで、誤って通さない）。気づいたら bats の入力を実物から取り直す
- [呼び出し側（G・本体）が `OWNER_REPLY_CHANNEL_SENDERS=… owner-reply-check.sh` のように値を偽って渡す] → 検知しない。既存の `OWNER_REPLY_PROJECTS_DIR`（テスト用の差し替え口）と同じく、呼び出し側は協力的だが誤る前提で、偽造の経路を塞ぎ切ることを目的にしない。設定は `settings.json` の `env` に置き、呼び出しのたびに渡さない決まりにすることで、写し間違いの余地を減らす（#1126）
- [許可された送信者の Discord アカウントが乗っ取られる] → 検知しない。PR コメントで主のアカウントが乗っ取られた場合と同じ扱い
- [`meta` の値に `"` が入る（ユーザー名・リアクション・添付ファイル名など）] → 属性の形が崩れるか属性名が重複するので、送信者を読めない側に倒れる。主の発言でも数えられなくなることがあり、そのときは主に PR コメントか対話の端末で答え直してもらう

## Migration Plan

設定が無ければ振る舞いは変わらない（チャンネルの行は今までどおり数えない）。住人の環境で Discord の返事を通すには、`OWNER_REPLY_CHANNEL_SENDERS` を設定する。戻すときは設定を消せばよい。

## #1126 への引き継ぎ（住人の環境で使うための決まり）

#1126 は次を前提に、住人が develop を使うときの決まりを作る。

- チャンネル経由の主の返事は、そのセッションの会話ログに `origin.kind: "channel"` で残り、`OWNER_REPLY_CHANNEL_SENDERS` に `<origin.server>=<主の ID>` が設定されているときだけ、`owner-reply-check.sh` が主の発言として数える。Discord の公式プラグインなら `<origin.server>` は `plugin:discord:discord`、主の ID は主の Discord のユーザー ID（会話ログのチャンネルの行の開きタグの `user_id` 属性か、住人の `access.json` の `allowFrom` で確かめられる。個人の ID なのでリポジトリに書かない）
- 設定の置き場は、ゲートを回すセッションの環境（住人の `settings.json` の `env` など）。G と本体はサブエージェントや Bash からこのスクリプトを呼ぶので、セッションの環境変数がそのまま届く
- 設定が無い・ID が違う・送信者を読めない行は数えない。そのときゲートは今までどおり「会話の返事を確かめられない」として PR コメントか対話の端末で受け直す
- 主以外の送信者がチャンネルに書けること自体は止めない。数える相手を設定で絞るだけなので、主以外の ID を足さない

## Open Questions

なし
