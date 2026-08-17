#!/usr/bin/env bats
#
# discord-reaction-delivery: リアクションの push 配送（server.ts の構造検査）
#
# spec: openspec/specs/discord-reaction-delivery/spec.md
# telegram fork（plugins/telegram/server.ts の message_reaction）と同一契約:
#   content は "(reaction) +👍"（付与 +、除去 -）、message_id は元メッセージの ID、
#   allowlist 外は gate() でなく単純 drop。
#
# 注意: @test 名はマルチバイト不可（bats がテスト名をエンコードする際に壊れる）。
# 日本語は行末コメントで添える。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SERVER="${PLUGIN_DIR}/server.ts"
  README="${PLUGIN_DIR}/README.md"
}

# handleReaction 関数の本体だけを切り出す（他のハンドラの記述に誤マッチしないため）
reaction_block() {
  awk '/^async function handleReaction/,/^}/' "$SERVER"
}

# --- gateway intents ---

@test "intents: GuildMessageReactions enabled" {  # guild のリアクション intent
  grep -q 'GatewayIntentBits.GuildMessageReactions' "$SERVER"
}

@test "intents: DirectMessageReactions enabled" {  # DM のリアクションも拾う
  grep -q 'GatewayIntentBits.DirectMessageReactions' "$SERVER"
}

@test "intents: comment notes reactions are not privileged" {  # Portal 申請不要の旨をコメントに残す
  grep -qi 'privileged' "$SERVER"
}

# --- partials（bot 起動前のメッセージへのリアクションを落とさない） ---

@test "partials: Partials.Message and Partials.Reaction enabled" {
  grep -q 'Partials.Message' "$SERVER"
  grep -q 'Partials.Reaction' "$SERVER"
}

@test "partials: handler resolves reaction.partial / user.partial via fetch" {  # 世代交代前の投稿への 👍 を落とさない
  reaction_block | grep -q 'reaction.partial'
  reaction_block | grep -q 'reaction.fetch()'
  reaction_block | grep -q 'user.partial'
  reaction_block | grep -q 'user.fetch()'
}

# --- ハンドラ登録 ---

@test "handlers: both messageReactionAdd and messageReactionRemove subscribed" {
  grep -q "client.on('messageReactionAdd'" "$SERVER"
  grep -q "client.on('messageReactionRemove'" "$SERVER"
}

@test "handlers: add passes '+' and remove passes '-'" {  # 付与 + / 除去 - の符号
  grep -A2 "client.on('messageReactionAdd'" "$SERVER" | grep -q "'+'"
  grep -A2 "client.on('messageReactionRemove'" "$SERVER" | grep -q "'-'"
}

@test "handlers: ignores the bot's own reactions" {  # ackReaction の自己反応を配送しない
  reaction_block | grep -q 'user.bot'
}

# --- 配送契約（telegram fork と同一） ---

@test "delivery: content uses the '(reaction) ' format" {
  reaction_block | grep -q '(reaction) '
}

@test "delivery: notification method is notifications/claude/channel" {  # 受信メッセージと同じ経路
  reaction_block | grep -q "notifications/claude/channel'"
}

@test "delivery: meta.message_id is the reacted-to message id" {  # 新規メッセージ ID ではない
  reaction_block | grep -q 'message_id: reaction.message.id'
}

@test "delivery: meta carries chat_id / user_id / ts / reaction" {
  reaction_block | grep -q 'chat_id:'
  reaction_block | grep -q 'user_id:'
  reaction_block | grep -q 'ts:'
  reaction_block | grep -q 'reaction:'
}

@test "delivery: notification failure only logs to stderr" {  # throw しない
  reaction_block | grep -q 'process.stderr.write'
}

# --- allowlist（gate() ではなく単純 drop） ---

@test "allowlist: DM checks access.allowFrom, guild checks access.groups" {
  reaction_block | grep -q 'allowFrom.includes'
  reaction_block | grep -q 'access.groups'
}

@test "allowlist: dmPolicy disabled drops everything" {
  reaction_block | grep -q "dmPolicy === 'disabled'"
}

@test "allowlist: empty guild allowFrom falls back to access.allowFrom" {  # requireMention の代替。空 allowFrom で第三者の 👍 を主の承認と誤認しない
  reaction_block | grep -q 'groupAllowFrom : access.allowFrom'
}

@test "allowlist: drop with no allowlist at all leaves a stderr breadcrumb" {  # guild 専用構成（DM ペアリング未実施）で無言で全滅しない
  reaction_block | grep -q 'allowed.length === 0'
  reaction_block | grep -q 'group add'
  reaction_block | grep -q -- '--allow'
}

@test "ordering: same-key reaction events are serialized via a promise chain" {  # 付けてすぐ外しても remove が先に届かない
  block="$(awk '/^function enqueueReaction/,/^}/' "$SERVER")"
  [ -n "$block" ]
  echo "$block" | grep -q 'reactionChains.get(key)'
  echo "$block" | grep -q 'then(() => handleReaction'
  echo "$block" | grep -q 'reactionChains.delete(key)'
}

@test "delivery: uncached DM channel is fetched, not dropped" {  # 起動後まだ会話の無い DM への 👍 も拾う
  reaction_block | grep -q 'fetchTextChannel(reaction.message.channelId)'
}

# --- custom emoji の無害化 ---

@test "emoji: custom emoji rendered as <:name:id> with delimiter-sanitized name" {
  block="$(awk '/^function formatReactionEmoji/,/^}/' "$SERVER")"
  [ -n "$block" ]
  echo "$block" | grep -q '<:'
  echo "$block" | grep -q '.replace('
}

# --- エージェント向けの説明 ---

@test "instructions: explain the (reaction) event format and message_id meaning" {
  grep -q '(reaction) +👍' "$SERVER"
  grep -qi 'reacted to' "$SERVER"
}

@test "README: documents the inbound reaction contract" {
  grep -q '(reaction) +' "$README"
  grep -qi '^## Reactions' "$README"
}
