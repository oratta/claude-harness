#!/usr/bin/env bats
# 本体用の一回限りのタイマーを、実時間を待たずに正本から実行する。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REF="$PLUGIN_DIR/skills/develop/references/child-background-wait.md"
  SKILL="$PLUGIN_DIR/skills/develop/SKILL.md"
  SNIP="$BATS_TEST_TMPDIR/timer.sh"
  [ -f "$REF" ]
  awk '/^```bash$/{inside=1; next} inside && /^```$/{exit} inside' "$REF" > "$SNIP"
  [ -s "$SNIP" ]
  mkdir "$BATS_TEST_TMPDIR/bin"
  export SLEEP_LOG="$BATS_TEST_TMPDIR/sleep.log"
  export FAIL_AT=0
  cat > "$BATS_TEST_TMPDIR/bin/sleep" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$SLEEP_LOG"
[ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" -ne "$FAIL_AT" ]
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/sleep"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "timer sleeps 60 seconds 45 times and emits one notification" {
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = child-background-cache-refresh ]
  [ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" -eq 45 ]
  [ "$(sort -u "$SLEEP_LOG")" = 60 ]
}

@test "timer stops on sleep failure without a success notification" {
  export FAIL_AT=3
  run bash "$SNIP"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" -eq 3 ]
}
