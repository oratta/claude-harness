#!/usr/bin/env bats
#
# discord-reaction-delivery: 動的検証（issue #110）
#
# tests/reaction-order-harness.ts が server.ts を子プロセス起動し、合成 gateway
# イベント（同一キーの add→remove を間隔ゼロで投入。add は fetch が遅い partial）を
# 流して、MCP stdio の notifications/claude/channel が受信順（+👍 → -👍）で届くことを
# 検証する。実 Discord への接続・実トークンは不要。
#
# PR #109 の構造検査（promise チェーンの「形」の grep）はこの動的検証に置き換えた —
# 形ではなく観測可能な配送順そのものを固定する（逆転・欠落・重複で fail）。
#
# 注意: @test 名はマルチバイト不可（bats がテスト名をエンコードする際に壊れる）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SERVER="${PLUGIN_DIR}/server.ts"
}

@test "ordering: synthetic add then remove delivers in arrival order over MCP stdio" {  # 付けてすぐ外しても remove が先に届かない
  if ! command -v bun >/dev/null 2>&1; then
    # bun は discord プラグインの実行ランタイムそのもの。無いのに無言で成功扱いにしない。
    echo "bun が見つかりません（server.ts の実行に必要）。https://bun.sh で導入してください" >&2
    return 1
  fi
  run bun "${PLUGIN_DIR}/tests/reaction-order-harness.ts"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "seam: synth driver activates only via DISCORD_SYNTH_DRIVER env, login path intact" {  # 本番経路（client.login）は不変
  grep -q 'process.env.DISCORD_SYNTH_DRIVER' "$SERVER"
  grep -q 'client.login(TOKEN)' "$SERVER"
}
