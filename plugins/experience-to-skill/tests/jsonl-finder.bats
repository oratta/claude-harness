#!/usr/bin/env bats
#
# Tests for plugins/experience-to-skill/scripts/jsonl-finder.sh
#
# Covers:
#   - e2s_encode_cwd: absolute path -> ~/.claude/projects/ directory name
#   - e2s_resolve_jsonl_dir: encoded lookup + prefix-match fallback
#   - e2s_list_jsonl: 4-stage scan order (dir existence -> mtime -> size -> grep)

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FINDER_SH="$SCRIPT_DIR/scripts/jsonl-finder.sh"
  [ -f "$FINDER_SH" ] || skip "jsonl-finder.sh not yet present"
  # shellcheck source=/dev/null
  source "$FINDER_SH"

  TMP_PROJECTS="$(mktemp -d)"
  export E2S_PROJECTS_DIR="$TMP_PROJECTS"
}

teardown() {
  if [ -n "${TMP_PROJECTS:-}" ] && [ -d "$TMP_PROJECTS" ]; then
    rm -rf "$TMP_PROJECTS"
  fi
}

# ---------------------------------------------------------------------------
# e2s_encode_cwd
# ---------------------------------------------------------------------------

@test "e2s_encode_cwd: standard cwd is encoded" {
  run e2s_encode_cwd /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [ "$output" = "-Users-oratta-foo-bar" ]
}

@test "e2s_encode_cwd: dotted directory produces double hyphen" {
  run e2s_encode_cwd /Users/oratta/.claude-mem
  [ "$status" -eq 0 ]
  [ "$output" = "-Users-oratta--claude-mem" ]
}

@test "e2s_encode_cwd: worktree-style cwd encodes correctly" {
  run e2s_encode_cwd /Users/oratta/.superset/worktrees/abc/foo-bar
  [ "$status" -eq 0 ]
  [ "$output" = "-Users-oratta--superset-worktrees-abc-foo-bar" ]
}

@test "e2s_encode_cwd: trailing slash is normalized" {
  run e2s_encode_cwd /Users/oratta/foo/
  [ "$status" -eq 0 ]
  [ "$output" = "-Users-oratta-foo" ]
}

# ---------------------------------------------------------------------------
# e2s_resolve_jsonl_dir
# ---------------------------------------------------------------------------

@test "e2s_resolve_jsonl_dir: primary encoded dir exists" {
  mkdir -p "$TMP_PROJECTS/-Users-oratta-foo-bar"
  run e2s_resolve_jsonl_dir /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [ "$output" = "$TMP_PROJECTS/-Users-oratta-foo-bar" ]
}

@test "e2s_resolve_jsonl_dir: prefix fallback when primary missing" {
  # Simulate a slight encoding mismatch by having only a prefix-matching entry.
  mkdir -p "$TMP_PROJECTS/-Users-oratta-foo-bar-baz"
  run e2s_resolve_jsonl_dir /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [ "$output" = "$TMP_PROJECTS/-Users-oratta-foo-bar-baz" ]
}

@test "e2s_resolve_jsonl_dir: no candidates returns non-zero" {
  run e2s_resolve_jsonl_dir /nonexistent/path/here
  [ "$status" -ne 0 ]
}

@test "e2s_resolve_jsonl_dir: longest prefix wins when multiple match" {
  mkdir -p "$TMP_PROJECTS/-Users-oratta"
  mkdir -p "$TMP_PROJECTS/-Users-oratta-foo"
  mkdir -p "$TMP_PROJECTS/-Users-oratta-foo-bar-extra"
  run e2s_resolve_jsonl_dir /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [ "$output" = "$TMP_PROJECTS/-Users-oratta-foo-bar-extra" ]
}

# ---------------------------------------------------------------------------
# e2s_list_jsonl (4-stage scan order)
# ---------------------------------------------------------------------------

@test "e2s_list_jsonl: missing dir short-circuits with non-zero" {
  run e2s_list_jsonl /no/such/cwd
  [ "$status" -ne 0 ]
}

@test "e2s_list_jsonl: lists jsonl files in resolved dir" {
  dir="$TMP_PROJECTS/-Users-oratta-foo-bar"
  mkdir -p "$dir"
  touch "$dir/aaa.jsonl"
  touch "$dir/bbb.jsonl"
  run e2s_list_jsonl /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [[ "$output" == *"aaa.jsonl"* ]]
  [[ "$output" == *"bbb.jsonl"* ]]
}

@test "e2s_list_jsonl: size filter excludes files larger than max" {
  dir="$TMP_PROJECTS/-Users-oratta-foo-bar"
  mkdir -p "$dir"
  # 1KB small file
  dd if=/dev/zero of="$dir/small.jsonl" bs=1024 count=1 >/dev/null 2>&1
  # 200KB "large" file with a tiny max threshold
  dd if=/dev/zero of="$dir/large.jsonl" bs=1024 count=200 >/dev/null 2>&1
  E2S_JSONL_MAX_SIZE=$((100 * 1024)) run e2s_list_jsonl /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [[ "$output" == *"small.jsonl"* ]]
  [[ "$output" != *"large.jsonl"* ]]
}

@test "e2s_list_jsonl: ignores non-jsonl files" {
  dir="$TMP_PROJECTS/-Users-oratta-foo-bar"
  mkdir -p "$dir"
  touch "$dir/aaa.jsonl"
  touch "$dir/notes.txt"
  run e2s_list_jsonl /Users/oratta/foo/bar
  [ "$status" -eq 0 ]
  [[ "$output" == *"aaa.jsonl"* ]]
  [[ "$output" != *"notes.txt"* ]]
}
