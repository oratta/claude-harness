# discord-reaction-delivery

## ADDED Requirements

### Requirement: リアクションイベントを受信メッセージと同じ経路で push 配送する

discord プラグインの MCP サーバは、`messageReactionAdd` / `messageReactionRemove` の両イベントを受け、`notifications/claude/channel`（受信メッセージと同じ通知メソッド）でセッションに配送しなければならない（MUST）。gateway intent には `GatewayIntentBits.GuildMessageReactions` と `GatewayIntentBits.DirectMessageReactions` の両方を含める（どちらも特権 intent ではない）。bot 自身のリアクション（`user.bot`）は配送しない。

#### Scenario: 付与イベントが届く

- **WHEN** allowlist 済みの送信者がチャンネル内のメッセージに 👍 を付ける
- **THEN** `notifications/claude/channel` 通知が 1 件送られる
- **AND** `content` は `(reaction) +👍` である

#### Scenario: 除去イベントが届く

- **WHEN** allowlist 済みの送信者が付けた 👍 を外す
- **THEN** `content` が `(reaction) -👍` の通知が送られる

#### Scenario: bot 自身のリアクションは配送されない

- **WHEN** bot 自身（ackReaction 等）がメッセージにリアクションを付ける
- **THEN** 通知は送られない

### Requirement: 配送書式は telegram fork と同一の契約に揃える

配送する通知の `content` は `(reaction) ` に続けて付与は `+絵文字`・除去は `-絵文字` としなければならない（MUST）。`meta` には chat_id / message_id / user / user_id / ts / reaction を含め、`meta.message_id` は**リアクションが付いた元メッセージの ID**（新規メッセージの ID ではない）とする。custom emoji は `<:name:id>` 形式で表現し、名前はサーバー管理者が任意に付けられるため、`<channel>` 通知内で区切り文字を偽装されないよう既存の `safeAttName` と同方針（delimiter 文字の置換）で無害化する。

#### Scenario: message_id が元メッセージを指す

- **WHEN** message_id `M` のメッセージにリアクションが付く
- **THEN** 通知の `meta.message_id` は `M` である

#### Scenario: custom emoji が無害化される

- **WHEN** サーバー独自の custom emoji でリアクションが付く
- **THEN** `content` の絵文字部分は `<:name:id>` 形式で、name 中の区切り文字（`<` `>` `[` `]` `:` 改行 等）は置換されている

### Requirement: allowlist に無い送信者のリアクションは配送しない

リアクションの送信者がアクセス制御を通らない場合、通知を配送してはならない（MUST NOT）。DM は `access.allowFrom` で判定する。guild チャンネルは `access.groups` に登録済みであることに加え、チャンネルの `allowFrom`（空のときは `access.allowFrom` にフォールバック）に送信者が含まれることを要求する — テキスト経路で空の `allowFrom` を補っている requireMention はリアクションには適用できないため、代替としてペアリング済み送信者に絞る（これが無いと、登録チャンネルにいる第三者の 👍 が主の承認として配送されてしまう）。リアクションにはペアリング案内を返せないため、`gate()` のペアリングフローには載せず単純に drop する。`dmPolicy: "disabled"` のときは一切配送しない。ただし、チャンネルの `allowFrom` とフォールバック先の `access.allowFrom` が両方空で drop する場合（guild 専用構成で DM ペアリング未実施のとき恒常的に起きる）は、無言で捨てず stderr に 1 行（対処方法 `/discord:access group add <channelId> --allow <id>` または DM ペアリングを含む）を残す。

#### Scenario: 未登録チャンネルのリアクションは落ちる

- **WHEN** `access.groups` に無い guild チャンネルのメッセージにリアクションが付く
- **THEN** 通知は送られず、ペアリング案内も送られない

#### Scenario: allowlist 外の送信者のリアクションは落ちる

- **WHEN** DM で `access.allowFrom` に無いユーザーがリアクションを付ける
- **THEN** 通知は送られない

#### Scenario: guild の allowFrom が空でも第三者のリアクションは落ちる

- **GIVEN** `access.groups` に登録済みで `allowFrom` が空の guild チャンネル
- **WHEN** `access.allowFrom` に無いユーザーがリアクションを付ける
- **THEN** 通知は送られない（`access.allowFrom` へのフォールバック判定で drop）

#### Scenario: allowlist が両方空の drop は stderr に痕跡を残す

- **GIVEN** チャンネルの `allowFrom` も `access.allowFrom` も空
- **WHEN** そのチャンネルのメッセージにリアクションが付く
- **THEN** 通知は送られず、stderr に対処方法（`--allow` 指定または DM ペアリング）を含む 1 行が出る

### Requirement: 同一対象へのリアクションイベントは受信順に配送する

同じチャンネル・メッセージ・ユーザー・絵文字の組に対する付与/除去イベントは、受信した順に配送しなければならない（MUST）。ハンドラは partial 解決等で await するため、素直に並行実行すると「付けてすぐ外す」で除去が先に配送され、実際は取り消された承認をセッションが最後に見てしまう。実装はこの組をキーにした promise チェーンで直列化し、決着したキーのエントリは削除してリークさせない。

#### Scenario: 付けてすぐ外しても順序が保たれる

- **GIVEN** bot 起動前のメッセージ（partial 解決の待ちが発生する）
- **WHEN** 同一ユーザーが 👍 を付けて即座に外す
- **THEN** セッションには `(reaction) +👍` → `(reaction) -👍` の順で届き、最後に見えるのは除去である

### Requirement: bot 起動前のメッセージへのリアクションも partial 解決で拾う

bot 起動（＝世代交代）より前に投稿されたメッセージへのリアクションは discord.js のキャッシュに無く partial で届くため、`Partials.Message` / `Partials.Reaction` / `Partials.User` を有効化し、ハンドラ内で `reaction.partial` / `user.partial` のとき `fetch()` で解決してから配送しなければならない（MUST）。同様に、キャッシュに無いチャンネル（起動後まだ会話の無い DM 等）は `channelId` からの fetch で解決する。fetch 失敗（元メッセージ削除等）は stderr への 1 行ログに留め、throw しない。

#### Scenario: 世代交代をまたいだ承認が届く

- **GIVEN** bot が再起動し、再起動前に投稿された自分のメッセージがキャッシュに無い
- **WHEN** そのメッセージに allowlist 済みの送信者が 👍 を付ける
- **THEN** partial が fetch で解決され、通常どおり `(reaction) +👍` が配送される

### Requirement: リアクションイベントの読み方をエージェントに説明する

MCP サーバの instructions には、`(reaction) +👍` という形の `<channel>` イベントの意味（`+` は付与・`-` は除去、message_id はリアクションが付いた元メッセージの ID、返信不要の軽い合図として扱う旨）を含めなければならない（MUST）。`plugins/discord/README.md` にも同じ契約を記載する。

#### Scenario: instructions に書式説明がある

- **WHEN** MCP サーバの instructions を読む
- **THEN** `(reaction) +👍` の書式・message_id の意味・軽い合図として扱う旨が書かれている
