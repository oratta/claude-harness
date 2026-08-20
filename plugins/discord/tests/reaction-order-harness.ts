#!/usr/bin/env bun
/**
 * Reaction-delivery order harness (issue #110, follow-up to PR #109).
 *
 * Spawns plugins/discord/server.ts as a child process with the
 * DISCORD_SYNTH_DRIVER seam active, completes the MCP initialize handshake
 * over stdio, then lets the driver (tests/synth-driver.ts) inject a same-key
 * messageReactionAdd → messageReactionRemove pair with zero gap. The add is
 * a partial whose fetch() is slow; without same-key serialization the remove
 * would be delivered first.
 *
 * PASS (exit 0): exactly two notifications/claude/channel events arrive, in
 * order "+👍" then "-👍", both carrying the synthetic message id.
 * FAIL (exit 1): reversed order, missing/extra events, or timeout — with the
 * observed events and the child's stderr dumped for diagnosis.
 *
 * No real Discord token or connection is involved.
 */
import { spawn, spawnSync } from 'child_process'
import { mkdtempSync, writeFileSync, rmSync } from 'fs'
import { tmpdir } from 'os'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const PLUGIN_DIR = dirname(dirname(fileURLToPath(import.meta.url)))
const USER_ID = '900000000000000003'
const MESSAGE_ID = '900000000000000002'
const TIMEOUT_MS = 15000
// After the 2nd event, wait this long to catch duplicates/strays.
const SETTLE_MS = 250

// server.ts imports discord.js — make sure deps exist (fresh worktrees and CI
// don't have node_modules). Frozen: an out-of-sync lockfile should fail loud,
// not be rewritten by a test run.
const install = spawnSync('bun', ['install', '--no-summary', '--frozen-lockfile'], {
  cwd: PLUGIN_DIR,
  stdio: 'inherit',
})
if (install.status !== 0) {
  console.error(`bun install failed (exit ${install.status})`)
  process.exit(1)
}

// Hermetic state dir: allowlisted synthetic user, no pairing, static mode so
// the server never writes back.
const stateDir = mkdtempSync(join(tmpdir(), 'discord-synth-'))
writeFileSync(
  join(stateDir, 'access.json'),
  JSON.stringify({ dmPolicy: 'allowlist', allowFrom: [USER_ID], groups: {}, pending: {} }, null, 2) + '\n',
)
const trigger = join(stateDir, 'handshake-done')

const child = spawn(process.execPath, [join(PLUGIN_DIR, 'server.ts')], {
  env: {
    ...process.env,
    DISCORD_BOT_TOKEN: 'synthetic-token-never-sent-anywhere',
    DISCORD_STATE_DIR: stateDir,
    DISCORD_ACCESS_MODE: 'static',
    DISCORD_SYNTH_DRIVER: join(PLUGIN_DIR, 'tests', 'synth-driver.ts'),
    DISCORD_SYNTH_TRIGGER: trigger,
    DISCORD_SYNTH_USER_ID: USER_ID,
  },
  stdio: ['pipe', 'pipe', 'pipe'],
})

let stderrBuf = ''
child.stderr.on('data', (d: Buffer) => { stderrBuf += d.toString() })

type ChannelEvent = { content: string; meta: { message_id: string; reaction: string } }
const events: ChannelEvent[] = []
let initialized = false
let done = false

function finish(code: number, verdict: string): void {
  if (done) return
  done = true
  console.log(verdict)
  if (code !== 0) {
    console.log(`observed events: ${JSON.stringify(events, null, 2)}`)
    console.log(`server stderr:\n${stderrBuf}`)
  }
  child.kill()
  rmSync(stateDir, { recursive: true, force: true })
  process.exit(code)
}

const timeout = setTimeout(() => finish(1, `FAIL: timeout after ${TIMEOUT_MS}ms (${events.length} event(s) arrived)`), TIMEOUT_MS)

child.on('exit', code => finish(1, `FAIL: server exited early (code ${code})`))

function evaluate(): void {
  if (events.length !== 2) {
    finish(1, `FAIL: expected exactly 2 events, got ${events.length}`)
    return
  }
  const [first, second] = events
  const ok =
    first.meta.reaction === '+👍' &&
    second.meta.reaction === '-👍' &&
    first.content === '(reaction) +👍' &&
    second.content === '(reaction) -👍' &&
    first.meta.message_id === MESSAGE_ID &&
    second.meta.message_id === MESSAGE_ID
  finish(ok ? 0 : 1, ok
    ? 'PASS: add→remove delivered in arrival order (+👍 then -👍)'
    : 'FAIL: events arrived but order/shape is wrong')
}

// MCP stdio framing is newline-delimited JSON-RPC.
let stdoutBuf = ''
child.stdout.on('data', (d: Buffer) => {
  stdoutBuf += d.toString()
  let nl: number
  while ((nl = stdoutBuf.indexOf('\n')) >= 0) {
    const line = stdoutBuf.slice(0, nl).trim()
    stdoutBuf = stdoutBuf.slice(nl + 1)
    if (!line) continue
    let msg: any
    try { msg = JSON.parse(line) } catch { continue }

    if (msg.id === 1 && msg.result && !initialized) {
      initialized = true
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n')
      // Handshake complete — unblock the driver.
      writeFileSync(trigger, '')
      continue
    }
    if (msg.method === 'notifications/claude/channel') {
      events.push(msg.params as ChannelEvent)
      if (events.length === 2) setTimeout(evaluate, SETTLE_MS)
      if (events.length > 2) finish(1, `FAIL: more than 2 events delivered`)
    }
  }
})

child.stdin.write(JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'reaction-order-harness', version: '0.0.0' },
  },
}) + '\n')
