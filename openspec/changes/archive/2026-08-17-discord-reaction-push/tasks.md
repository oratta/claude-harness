## 1. テスト（先に Red）

- [x] 1.1 `plugins/discord/tests/reaction-push.bats` を新設し、server.ts の構造検査（intent / partials / ハンドラ / 書式 / allowlist / instructions / README）を書いて Red を確認する

## 2. server.ts 実装

- [x] 2.1 `GatewayIntentBits.GuildMessageReactions` / `DirectMessageReactions` を intent に追加（特権 intent ではない旨をコメント）
- [x] 2.2 `Partials.Message` / `Partials.Reaction` / `Partials.User` を追加
- [x] 2.3 `messageReactionAdd` / `messageReactionRemove` ハンドラを追加（partial fetch → bot 無視 → allowlist drop → `(reaction) ±絵文字` を `notifications/claude/channel` へ）
- [x] 2.4 custom emoji の `<:name:id>` 表現と名前の無害化
- [x] 2.5 MCP instructions にリアクションイベントの読み方を追記

## 3. ドキュメントとバージョン

- [x] 3.1 `plugins/discord/README.md` にリアクション受信の契約を追記
- [x] 3.2 `plugins/discord/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` のバージョン上げ

## 4. 検証

- [x] 4.1 `scripts/test.sh discord` が exit 0（新規スイート Green）
- [x] 4.2 `scripts/test.sh` 全件と `scripts/lint.sh` が exit 0
- [x] 4.3 change を archive する（PR 作成前に実施し、同じ PR に含める）
