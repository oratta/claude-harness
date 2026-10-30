#!/usr/bin/env bats
# synced-skills-name-only.sh と /dev-workflow:synced-skills-slim の検査（issue #1470）。
# 設定ディレクトリは一時ディレクトリ（CLAUDE_CONFIG_DIR）で、実物の ~/.claude/settings.json には触れない。
# テスト名は ASCII のみ（bats の制約）。

setup() {
  PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_DIR/scripts/synced-skills-name-only.sh"
  CMD="$PLUGIN_DIR/commands/synced-skills-slim.md"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$CLAUDE_CONFIG_DIR" "$HOME"
  S="$CLAUDE_CONFIG_DIR/settings.json"
}

mk_skill() { # <バケット> <名>
  mkdir -p "$CLAUDE_CONFIG_DIR/skills/synced/$1/$2"
  : > "$CLAUDE_CONFIG_DIR/skills/synced/$1/$2/SKILL.md"
}
baks() { ls "$CLAUDE_CONFIG_DIR"/settings.json.bak-* 2>/dev/null | wc -l | tr -d ' '; }

@test "script and command files exist" {
  [ -f "$SCRIPT" ]
  [ -f "$CMD" ]
}

@test "dry-run lists only real skill dirs of non-dot buckets" {
  mk_skill org_acct pdf; mk_skill org_acct docs
  mk_skill .bucket-x pdf2; mk_skill org_acct .hidden
  : > "$CLAUDE_CONFIG_DIR/skills/synced/org_acct/.last-complete-round"
  echo '{"model":"opus"}' > "$S"
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"anthropic-skills:pdf"* ]]
  [[ "$output" == *"anthropic-skills:docs"* ]]
  [[ "$output" != *pdf2* ]]
  [[ "$output" != *hidden* ]]
  [ "$(jq -c . "$S")" = '{"model":"opus"}' ]
  [ "$(baks)" = 0 ]
}

@test "existing values and other keys are kept" {
  mk_skill o pdf; mk_skill o docs
  echo '{"model":"opus","skillOverrides":{"anthropic-skills:pdf":"off","mine":"on"}}' > "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c . "$S")" = '{"model":"opus","skillOverrides":{"anthropic-skills:docs":"name-only","anthropic-skills:pdf":"off","mine":"on"}}' ]
  [[ "$output" == *"anthropic-skills:docs"* ]]
  [ "$(baks)" = 1 ]
}

@test "skillOverrides is created when absent" {
  mk_skill o pdf
  echo '{"model":"opus"}' > "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c . "$S")" = '{"model":"opus","skillOverrides":{"anthropic-skills:pdf":"name-only"}}' ]
}

@test "no synced skills writes nothing and says so" {
  echo '{"model":"opus"}' > "$S"
  cp "$S" "$BATS_TEST_TMPDIR/before"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"同期スキルが無い"* ]]
  cmp "$S" "$BATS_TEST_TMPDIR/before"
  [ "$(baks)" = 0 ]
}

@test "no synced skills exits 0 even when settings.json is broken" {
  echo 'not json' > "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$S")" = 'not json' ]
}

@test "missing settings.json is created without a backup" {
  mk_skill o pdf
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -c . "$S")" = '{"skillOverrides":{"anthropic-skills:pdf":"name-only"}}' ]
  [ "$(baks)" = 0 ]
}

@test "symlinked settings.json stays a symlink and keeps permissions" {
  mk_skill o pdf
  mkdir -p "$BATS_TEST_TMPDIR/real"
  echo '{"model":"opus"}' > "$BATS_TEST_TMPDIR/real/s.json"
  chmod 644 "$BATS_TEST_TMPDIR/real/s.json"
  ln -s "$BATS_TEST_TMPDIR/real/s.json" "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$S" ]
  [ "$(jq -r '.skillOverrides["anthropic-skills:pdf"]' "$BATS_TEST_TMPDIR/real/s.json")" = name-only ]
  [ "$(stat -f %Lp "$BATS_TEST_TMPDIR/real/s.json" 2>/dev/null || stat -c %a "$BATS_TEST_TMPDIR/real/s.json")" = 644 ]
}

@test "second run changes nothing" {
  mk_skill o pdf
  echo '{}' > "$S"
  bash "$SCRIPT"
  cp "$S" "$BATS_TEST_TMPDIR/after1"
  touch -t 202001010000 "$S"
  m1="$(stat -f %m "$S" 2>/dev/null || stat -c %Y "$S")"
  n1="$(baks)"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  cmp "$S" "$BATS_TEST_TMPDIR/after1"
  [ "$(stat -f %m "$S" 2>/dev/null || stat -c %Y "$S")" = "$m1" ]
  [ "$(baks)" = "$n1" ]
}

@test "only newly added skills are added on a later run" {
  mk_skill o pdf
  echo '{}' > "$S"
  bash "$SCRIPT"
  jq '.skillOverrides["anthropic-skills:pdf"]="on"' "$S" > "$S.t" && mv "$S.t" "$S"
  mk_skill o docs
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c .skillOverrides "$S")" = '{"anthropic-skills:docs":"name-only","anthropic-skills:pdf":"on"}' ]
}

@test "broken settings.json fails without writing when skills exist" {
  mk_skill o pdf
  echo 'not json' > "$S"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = 'not json' ]
  [ "$(baks)" = 0 ]
}

@test "non-object top level fails without writing" {
  mk_skill o pdf
  for v in '[]' 'null'; do
    echo "$v" > "$S"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [ "$(cat "$S")" = "$v" ]
  done
  [ "$(baks)" = 0 ]
}

@test "non-object skillOverrides fails without writing" {
  mk_skill o pdf
  echo '{"skillOverrides":["x"]}' > "$S"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{"skillOverrides":["x"]}' ]
  [ "$(baks)" = 0 ]
}

@test "unknown argument fails without writing, with or without skills" {
  mk_skill o pdf
  echo '{}' > "$S"
  run bash "$SCRIPT" --dry-rnu
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{}' ]
  [ "$(baks)" = 0 ]
  rm -rf "$CLAUDE_CONFIG_DIR/skills"
  run bash "$SCRIPT" --dry-rnu
  [ "$status" -ne 0 ]
}

@test "missing jq fails, with or without skills" {
  mkdir -p "$BATS_TEST_TMPDIR/emptybin"
  echo '{}' > "$S"
  run env PATH="$BATS_TEST_TMPDIR/emptybin" /bin/bash "$SCRIPT"
  [ "$status" -ne 0 ]
  mk_skill o pdf
  run env PATH="$BATS_TEST_TMPDIR/emptybin" /bin/bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{}' ]
}

@test "command is registered in plugin.json and the file exists" {
  jq -e '.commands | index("./commands/synced-skills-slim.md")' "$PLUGIN_DIR/.claude-plugin/plugin.json" >/dev/null
  [ -f "$CMD" ]
}

@test "command asks for confirmation between dry-run and apply, and declining writes nothing" {
  head -8 "$CMD" | grep -q '^allowed-tools:.*AskUserQuestion'
  d=$(grep -n 'name-only.sh" --dry-run$' "$CMD" | head -1 | cut -d: -f1)
  q=$(grep -n '^### 3\..*AskUserQuestion' "$CMD" | head -1 | cut -d: -f1)
  a=$(grep -n 'name-only.sh"$' "$CMD" | head -1 | cut -d: -f1)
  [ -n "$d" ] && [ -n "$q" ] && [ -n "$a" ]
  [ "$d" -lt "$q" ] && [ "$q" -lt "$a" ]
  grep -q '断られたらスクリプトを `--dry-run` なしで呼ばずに終了' "$CMD"
}

@test "command documents undo, name-only caveat and the measured version" {
  grep -q 'settings.json.bak-' "$CMD"
  grep -q 'del(.skillOverrides' "$CMD"
  grep -q '自動' "$CMD"
  grep -q '2.1.314' "$CMD"
}

@test "no hook calls the script" {
  ! grep -rq 'synced-skills-name-only' "$PLUGIN_DIR/hooks"
}
