# discord-reaction-push — 主のリアクションを push でセッションに届ける

## Why

Discord bot の gateway intent にリアクション系が無く、`messageReactionAdd` ハンドラも無いため、主が 👍 を押しても bot には一切届かない。承認リアクションの検知は `fetch_messages` によるプル（cron の同期ジョブ）に依存しており、押してから最大で半日、住人は気づかない。telegram fork は既に `message_reaction` を `notifications/claude/channel` で push 配送しており（`plugins/telegram/server.ts`）、Discord 住人だけが取り残されている（claude-harness issue #108 / flatmate epic #348）。

## What Changes

- **gateway intent の追加**: `GuildMessageReactions` と `DirectMessageReactions` を追加する。どちらも特権 intent ではないため Developer Portal での申請は不要（コードとコメントに明記）。
- **partials の追加**: `Partials.Message` / `Partials.Reaction` / `Partials.User` を追加し、ハンドラ内で partial を `fetch()` で解決する。これが無いと bot 起動前（＝世代交代前）に投稿されたメッセージへのリアクションだけが落ちる。
- **ハンドラの追加**: `messageReactionAdd` / `messageReactionRemove` を受け、telegram fork と同一の契約で `notifications/claude/channel` に配送する:
  - `content` は `(reaction) +👍`（付与は `+`、除去は `-`）
  - `meta.message_id` はリアクションが付いた元メッセージの ID（新規メッセージ ID ではない）
  - `meta` に chat_id / user / user_id / ts / reaction
  - 送信者が allowlist に無ければ配送しない。リアクションにはペアリング応答を返せないので `gate()` ではなく単純 drop（telegram と同じ理由）
  - custom emoji は `<:name:id>` 形式。名前はサーバー管理者の管理下にあるため、既存の `safeAttName` と同方針で区切り文字を無害化する
- **MCP instructions / README**: `(reaction) +👍` 形式のイベントの読み方（message_id の意味・返信不要の軽い合図として扱う旨）を telegram 側の記述に合わせて追記する。
- **バージョン上げ**: `plugins/discord/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json`（S130-S132 のバージョン整合ガード対象）。

## Capabilities

### New Capabilities

- `discord-reaction-delivery`: Discord のリアクション付与/除去イベントを、受信メッセージと同じ `notifications/claude/channel` 経路・telegram fork と同一の書式でセッションに push 配送する契約。

## Impact

- **コード**: `plugins/discord/server.ts`（intent / partials / ハンドラ / instructions）、`plugins/discord/README.md`、`plugins/discord/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`。
- **テスト**: `plugins/discord/tests/reaction-push.bats` を新設（server.ts の構造検査）。
- **運用**: 住人の bot 再起動だけで効く（Developer Portal の操作不要）。cron のリアクション同期ジョブは取りこぼしの保険に降格できる。
- **セキュリティ**: 配送対象は allowlist 済み送信者のみ。custom emoji 名の無害化で `<channel>` 通知内の区切り文字偽装を防ぐ。
