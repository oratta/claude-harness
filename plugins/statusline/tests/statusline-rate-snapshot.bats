#!/usr/bin/env bats
# Writer A-I from flatmate/scripts/test-statusline.sh, with all paths isolated.

setup() {
  SL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home" CLAUDE_CONFIG_DIR="$WORK/config"
  export FLATMATE_RATE_SHARE_CONF="$WORK/no-conf" STATUSLINE_API_PACE=0 STATUSLINE_CODEX=0
  unset FLATMATE_RATE_SHARE_DIR CLAUDE_SECURESTORAGE_CONFIG_DIR
  mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR"
  SNAP="$CLAUDE_CONFIG_DIR/.rate-limit-snapshot"
  NOW="$(date +%s)"
}

teardown() { rm -rf "$WORK"; }

payload() {
  jq -cn --arg cwd "$WORK" --argjson five "$1" --argjson seven "$2" --argjson now "$NOW" \
    '{session_id:"writer-a",workspace:{current_dir:$cwd},model:{display_name:"Opus"},context_window:{remaining_percentage:80},rate_limits:{five_hour:{used_percentage:$five,resets_at:($now+9000)},seven_day:{used_percentage:$seven,resets_at:($now+302400)}}}'
}

render() { printf '%s' "$1" | bash "$SL"; }

@test "writer A-D: values and timestamps distinguish redraw from a new observation" {
  render "$(payload 12.5 34.5)" > /dev/null
  [ -f "$SNAP" ]
  run jq -e --argjson now "$NOW" '.five_hour_pct == 12.5 and .seven_day_pct == 34.5 and .ts == .observed_at and .written_at >= $now and .observed_at >= $now' "$SNAP"
  [ "$status" -eq 0 ]
  jq '.observed_at=1 | .ts=1 | .written_at=1' "$SNAP" > "$WORK/old"
  mv "$WORK/old" "$SNAP"
  render "$(payload 12.5 34.5)" > /dev/null
  run jq -e '.observed_at == 1 and .ts == 1 and .written_at > 1' "$SNAP"
  [ "$status" -eq 0 ]
  render "$(payload 13.5 34.5)" > /dev/null
  run jq -e '.observed_at > 1 and .ts == .observed_at' "$SNAP"
  [ "$status" -eq 0 ]
}

@test "writer E-F: shared file matches local and no share is created by default" {
  render "$(payload 12.5 34.5)" > /dev/null
  [ ! -d "$WORK/share" ]
  export FLATMATE_RATE_SHARE_DIR="$WORK/share"
  render "$(payload 21 35)" > /dev/null
  host="$(jq -r .host "$SNAP")"
  [ -f "$WORK/share/$host.json" ]
  cmp "$SNAP" "$WORK/share/$host.json"
  [ "$(find "$WORK/share" -name '*.json' | wc -l | tr -d ' ')" = 1 ]
}

@test "writer G: inaccessible share preserves local and display" {
  render "$(payload 23 37)" > "$WORK/baseline"
  : > "$WORK/blocked"
  FLATMATE_RATE_SHARE_DIR="$WORK/blocked/dir" render "$(payload 23 37)" > "$WORK/failed"
  cmp "$WORK/baseline" "$WORK/failed"
  [ "$(jq -r .seven_day_pct "$SNAP")" = 37 ]
}

@test "writer H: missing rate limits leaves snapshot unchanged" {
  render "$(payload 23 37)" > /dev/null
  cp "$SNAP" "$WORK/before"
  render "$(payload 23 37 | jq 'del(.rate_limits)')" > "$WORK/output"
  cmp "$SNAP" "$WORK/before"
  grep -q Opus "$WORK/output"
}

@test "writer I: config file resolves share; empty override disables it" {
  printf '# comment\n\n  ~/shared  \n' > "$FLATMATE_RATE_SHARE_CONF"
  render "$(payload 24 38)" > /dev/null
  host="$(jq -r .host "$SNAP")"
  cmp "$SNAP" "$HOME/shared/$host.json"
  rm -rf "$HOME/shared"
  FLATMATE_RATE_SHARE_DIR='' render "$(payload 24 38)" > /dev/null
  [ ! -e "$HOME/shared" ]
}
