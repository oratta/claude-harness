#!/usr/bin/env bats
# All CLI/config/cache writes are confined to BATS_TEST_TMPDIR.
setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REAL_CODEX="$(command -v codex || true)"
  export HOME="$BATS_TEST_TMPDIR/home"
  export CODEX_HOME="$HOME/.codex"
  export CLAUDE_CONFIG_DIR="$HOME/.claude"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  mkdir -p "$CODEX_HOME"
  FIXTURE="$BATS_TEST_TMPDIR/source"
  mkdir -p "$FIXTURE/scripts" "$FIXTURE/.claude-plugin" "$FIXTURE/rules" "$FIXTURE/output-styles"
  cp "$REPO_ROOT/scripts/sync.sh" "$FIXTURE/scripts/sync.sh"
  echo '{"name":"fixture","plugins":[{"name":"dev-workflow","source":"./plugins/dev-workflow","description":"fixture"}]}' > "$FIXTURE/.claude-plugin/marketplace.json"
  echo rule > "$FIXTURE/rules/example.md"
  echo style > "$FIXTURE/output-styles/example.md"
  SYNC="$FIXTURE/scripts/sync.sh"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  export LIST_JSON="$BATS_TEST_TMPDIR/list.json" UPGRADE_JSON="$BATS_TEST_TMPDIR/upgrade.json"
  export LIST_RC=0 UPGRADE_RC=0
  echo '{"marketplaces":[{"name":"fixture","marketplaceSource":{"sourceType":"git"}},{"name":"other","marketplaceSource":{"sourceType":"git"}}]}' > "$LIST_JSON"
  echo '{"selectedMarketplaces":["fixture"],"upgradedRoots":[],"errors":[]}' > "$UPGRADE_JSON"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  cat > "$BIN/codex" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$CALLS"
case "$*" in
  'plugin marketplace list --json') cat "$LIST_JSON"; exit "$LIST_RC" ;;
  'plugin marketplace upgrade fixture --json') cat "$UPGRADE_JSON"; exit "$UPGRADE_RC" ;;
  *) exit 99 ;;
esac
SH
  chmod +x "$BIN/codex"
}

fake_cli() { export PATH="$BIN:$PATH"; }
assert_links() {
  [ -L "$CLAUDE_CONFIG_DIR/rules/claude-harness/example.md" ]
  [ -L "$CLAUDE_CONFIG_DIR/output-styles/example.md" ]
}
assert_failure() {
  run sh "$SYNC" --no-pull
  [ "$status" -eq 1 ]
  [[ "$output" == *"[harness-sync] Codex"* ]] || return 1
  assert_links
}
# A restricted PATH exercises missing dependencies without using the host CLI.
restricted_path() {
  for tool in dirname mkdir basename ln readlink rm rmdir; do
    ln -s "$(command -v "$tool")" "$BIN/$tool"
  done
  export PATH="$BIN"
}

@test "only matching Git marketplace is upgraded even with no-pull; repeat preserves settings" {
  fake_cli
  echo 'sentinel disabled config' > "$CODEX_HOME/config.toml"
  cp "$CODEX_HOME/config.toml" "$BATS_TEST_TMPDIR/config.before"
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "$(printf '%s\n' 'plugin marketplace list --json' 'plugin marketplace upgrade fixture --json' 'plugin marketplace list --json' 'plugin marketplace upgrade fixture --json')" ]
  cmp "$CODEX_HOME/config.toml" "$BATS_TEST_TMPDIR/config.before"
  assert_links
}

@test "missing CLI silently retains existing wiring" {
  rm "$BIN/codex"
  restricted_path
  run /bin/sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$CALLS" ]
  assert_links
}

@test "missing jq warns and continues wiring" {
  restricted_path
  run /bin/sh "$SYNC" --no-pull
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq"* ]] || return 1
  assert_links
}

@test "absent or local-only target silently skips upgrade" {
  fake_cli
  for payload in '{"marketplaces":[]}' '{"marketplaces":[{"name":"fixture","marketplaceSource":{"sourceType":"local"}},{"name":"other","marketplaceSource":{"sourceType":"git"}}]}'; do
    echo "$payload" > "$LIST_JSON"
    run sh "$SYNC" --no-pull
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  [ "$(wc -l < "$CALLS" | tr -d ' ')" -eq 2 ]
  assert_links
}

@test "list and upgrade nonzero exits fail while wiring continues" {
  fake_cli
  export LIST_RC=7
  assert_failure
  [ "$(wc -l < "$CALLS" | tr -d ' ')" -eq 1 ]
  export LIST_RC=0 UPGRADE_RC=8
  assert_failure
}

@test "malformed and structurally invalid list JSON fails closed" {
  fake_cli
  for payload in 'not-json' '{}' '{"marketplaces":{}}' '{"marketplaces":[{"name":"fixture"}]}' '{"marketplaces":[{"name":3,"marketplaceSource":{"sourceType":"git"}}]}'; do
    echo "$payload" > "$LIST_JSON"
    assert_failure
  done
  ! grep -q upgrade "$CALLS" || return 1
}

@test "malformed upgrade results and nonempty errors fail while wiring continues" {
  fake_cli
  for payload in 'not-json' '{}' '{"errors":{}}' '{"errors":["failed"]}'; do
    echo "$payload" > "$UPGRADE_JSON"
    assert_failure
  done
}

@test "unreadable or invalid manifest is an error without upgrade" {
  fake_cli
  for payload in 'not-json' '{}' '{"name":""}' '{"name":3}'; do
    echo "$payload" > "$FIXTURE/.claude-plugin/marketplace.json"
    assert_failure
  done
  rm "$FIXTURE/.claude-plugin/marketplace.json"
  assert_failure
  [ ! -e "$CALLS" ]
}

init_real_fixture() {
  [ -n "$REAL_CODEX" ] || skip 'codex CLI not installed: real cache acceptance unverified'
  P="$FIXTURE/plugins/dev-workflow"
  mkdir -p "$P/.claude-plugin" "$P/skills/develop" "$P/commands"
  echo '{"name":"dev-workflow","description":"fixture"}' > "$P/.claude-plugin/plugin.json"
  printf '%s\n' '---' 'name: develop' 'description: fixture' '---' 'old-native' > "$P/skills/develop/SKILL.md"
  printf '%s\n' '---' 'description: fixture' '---' 'old-command' > "$P/commands/keep.md"
  cp "$P/commands/keep.md" "$P/commands/remove.md"
  git init -b main "$FIXTURE"
  git -C "$FIXTURE" add .
  git -C "$FIXTURE" -c user.name=Test -c user.email=test@example.com commit -qm initial
  # Only this temporary HOME's Git config redirects the synthetic HTTPS URL to local Git.
  git config --global "url.file://$FIXTURE.insteadOf" https://fixture.invalid/harness.git
  "$REAL_CODEX" plugin marketplace add https://fixture.invalid/harness.git --ref main --json
  "$REAL_CODEX" plugin marketplace list --json > "$LIST_JSON"
  SNAPSHOT="$(jq -r '.marketplaces[] | select(.name == "fixture") | .root' "$LIST_JSON")"
  "$REAL_CODEX" plugin add dev-workflow@fixture --json > "$UPGRADE_JSON"
  CACHE="$(jq -r '.installedPath' "$UPGRADE_JSON")"
  MIGRATED="$CACHE/.codex-plugin/migrated-command-skills"
  cmp "$P/skills/develop/SKILL.md" "$CACHE/skills/develop/SKILL.md"
  grep -q old-command "$MIGRATED/source-command-keep/SKILL.md"
  [ -f "$MIGRATED/source-command-remove/SKILL.md" ]
  # Preserve unrelated marketplace and disabled plugin settings across upgrades.
  mkdir -p "$BATS_TEST_TMPDIR/other/.claude-plugin"
  echo '{"name":"other","plugins":[]}' > "$BATS_TEST_TMPDIR/other/.claude-plugin/marketplace.json"
  "$REAL_CODEX" plugin marketplace add "$BATS_TEST_TMPDIR/other" --json
  printf '\n[plugins."disabled@fixture"]\nenabled = false\n' >> "$CODEX_HOME/config.toml"
  cp "$CODEX_HOME/config.toml" "$BATS_TEST_TMPDIR/config.before"
  git clone "$FIXTURE" "$BATS_TEST_TMPDIR/marketplace"
  SYNC="$BATS_TEST_TMPDIR/marketplace/scripts/sync.sh"
  sed 's/old-native/new-native/' "$P/skills/develop/SKILL.md" > "$BATS_TEST_TMPDIR/new-skill"
  cp "$BATS_TEST_TMPDIR/new-skill" "$P/skills/develop/SKILL.md"
  sed 's/old-command/new-command/' "$P/commands/keep.md" > "$BATS_TEST_TMPDIR/new-command"
  cp "$BATS_TEST_TMPDIR/new-command" "$P/commands/keep.md"
  rm "$P/commands/remove.md"
  git -C "$FIXTURE" add .
  git -C "$FIXTURE" -c user.name=Test -c user.email=test@example.com commit -qm update
  # Both Codex locations and the calling clone are still old before sync.
  grep -q old-native "$SNAPSHOT/plugins/dev-workflow/skills/develop/SKILL.md"
  grep -q old-native "$CACHE/skills/develop/SKILL.md"
}

assert_real_updated() {
  cmp "$P/skills/develop/SKILL.md" "$SNAPSHOT/plugins/dev-workflow/skills/develop/SKILL.md"
  cmp "$P/skills/develop/SKILL.md" "$CACHE/skills/develop/SKILL.md"
  grep -q new-command "$MIGRATED/source-command-keep/SKILL.md"
  ! grep -q old-command "$MIGRATED/source-command-keep/SKILL.md" || return 1
  [ ! -e "$MIGRATED/source-command-remove" ]
  cmp "$CODEX_HOME/config.toml" "$BATS_TEST_TMPDIR/config.before"
  [ ! -e "$CODEX_HOME/plugins/cache/fixture/disabled" ]
  assert_links
}

@test "real CLI updates snapshot/cache and migrated skills from local main with default pull" {
  init_real_fixture
  run sh "$SYNC"
  [ "$status" -eq 0 ]
  assert_real_updated
  cmp "$P/skills/develop/SKILL.md" "$BATS_TEST_TMPDIR/marketplace/plugins/dev-workflow/skills/develop/SKILL.md"
  run sh "$SYNC"
  [ "$status" -eq 0 ]
  assert_real_updated
}

@test "real CLI no-pull updates separate Codex snapshot after caller already pulled" {
  init_real_fixture
  git -C "$BATS_TEST_TMPDIR/marketplace" pull --ff-only
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  assert_real_updated
  run sh "$SYNC" --no-pull
  [ "$status" -eq 0 ]
  assert_real_updated
}
