/**
 * Synthetic gateway driver — runs INSIDE the server process, imported via the
 * DISCORD_SYNTH_DRIVER seam at the bottom of server.ts. Never used in
 * production (the seam is env-gated).
 *
 * Scenario: the same allowlisted user adds then immediately removes the same
 * emoji on the same message ("approve, then take it back"). The add arrives
 * as a partial whose fetch() resolves only after FETCH_DELAY_MS — modelling
 * the real await in handleReaction for reactions on pre-restart (uncached)
 * messages. The remove is non-partial and could deliver instantly. Without
 * enqueueReaction's same-key promise chain, the remove would overtake the add
 * and the session would see "+👍" last — acting on a withdrawn approval.
 *
 * The driver waits for the trigger file (written by the harness once the MCP
 * initialize handshake is done) so no notification is emitted before the
 * client is listening.
 */
import { ChannelType } from 'discord.js'
import { existsSync } from 'fs'

const TRIGGER = process.env.DISCORD_SYNTH_TRIGGER
const USER_ID = process.env.DISCORD_SYNTH_USER_ID ?? '900000000000000003'
const CHANNEL_ID = '900000000000000001'
const MESSAGE_ID = '900000000000000002'
const FETCH_DELAY_MS = 80

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

// Shapes below are the minimal subset of discord.js's reaction/user payloads
// that enqueueReaction + handleReaction read. Kept as plain objects so the
// test needs no gateway; `any`-typed emit keeps discord.js's strict event
// typings out of a test-only file.
export default async function drive(client: { emit: (event: string, ...args: unknown[]) => boolean }): Promise<void> {
  if (!TRIGGER) throw new Error('DISCORD_SYNTH_TRIGGER not set')
  while (!existsSync(TRIGGER)) await sleep(10)

  const dmChannel = { type: ChannelType.DM, isThread: () => false }
  const emoji = { id: null, name: '👍' }
  const user = { id: USER_ID, partial: false, bot: false, username: 'synth-user' }
  const message = { id: MESSAGE_ID, channelId: CHANNEL_ID, channel: dmChannel }

  const resolvedAdd = { partial: false, message, emoji }
  const partialAdd = {
    partial: true,
    message,
    emoji,
    // The slow path: handleReaction awaits this before delivering the add.
    fetch: async () => {
      await sleep(FETCH_DELAY_MS)
      return resolvedAdd
    },
  }
  const remove = { partial: false, message, emoji }

  // Emit back-to-back with zero gap — the ordering-hostile case.
  client.emit('messageReactionAdd', partialAdd, user)
  client.emit('messageReactionRemove', remove, user)
}
