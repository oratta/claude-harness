#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/develop-idle-compaction.py"
  FIXTURE="$(mktemp -d)"
  TEST_HOME="$FIXTURE/home"
  mkdir -p "$TEST_HOME/.claude" "$FIXTURE/repo"
  git -C "$FIXTURE/repo" init -q
  WORKTREE="$FIXTURE/repo"
  SETTINGS="$WORKTREE/.claude/settings.local.json"
}

teardown() { rm -rf "$FIXTURE"; }

config() { mkdir -p "$WORKTREE/.claude"; printf '%s\n' "$1" > "$SETTINGS"; }
cli() { python3 "$SCRIPT" "$1" "$WORKTREE"; }

@test "missing settings: check exits 2 without creating anything, apply creates only false" {
  run cli --check
  [ "$status" -eq 2 ]
  [ ! -e "$WORKTREE/.claude" ]
  run cli --apply
  [ "$status" -eq 0 ]
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1])) == {"idleCompaction":False}' "$SETTINGS"
  [[ "$output" == *"disk"* ]]
}

@test "single-key atomic update preserves permissions hooks unknown values and file mode" {
  config '{"idleCompaction":true,"permissions":{"allow":["secret"]},"hooks":{"Stop":[]},"unknown":[1,{"x":null}]}'
  chmod 640 "$SETTINGS"
  python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_ino)' "$SETTINGS" > "$FIXTURE/inode"
  run cli --check
  [ "$status" -eq 2 ]
  run cli --apply
  [ "$status" -eq 0 ]
  python3 - "$SETTINGS" "$FIXTURE/inode" <<'PY'
import json, os, stat, sys
p = sys.argv[1]
assert json.load(open(p)) == {"idleCompaction":False,"permissions":{"allow":["secret"]},"hooks":{"Stop":[]},"unknown":[1,{"x":None}]}
assert stat.S_IMODE(os.stat(p).st_mode) == 0o640
assert os.stat(p).st_ino != int(open(sys.argv[2]).read())
PY
}

@test "false is a byte and mtime preserving no-op in check and repeated apply" {
  config '{ "idleCompaction" : false, "n": 42 }'
  python3 -c 'import os,sys; os.utime(sys.argv[1],ns=(1000000000,1000000000))' "$SETTINGS"
  cp "$SETTINGS" "$FIXTURE/before"
  for mode in --check --apply --apply; do
    run cli "$mode"
    [ "$status" -eq 0 ]
  done
  cmp "$SETTINGS" "$FIXTURE/before"
  python3 -c 'import os,sys; assert os.stat(sys.argv[1]).st_mtime_ns == 1000000000' "$SETTINGS"
}

@test "home and shared settings stay unchanged and are never copied" {
  printf '%s\n' '{"secret":"home"}' > "$TEST_HOME/.claude/settings.json"
  mkdir -p "$WORKTREE/.claude"
  printf '%s\n' '{"secret":"shared"}' > "$WORKTREE/.claude/settings.json"
  cp "$TEST_HOME/.claude/settings.json" "$FIXTURE/home-before"
  cp "$WORKTREE/.claude/settings.json" "$FIXTURE/shared-before"
  run cli --apply
  [ "$status" -eq 0 ]
  cmp "$TEST_HOME/.claude/settings.json" "$FIXTURE/home-before"
  cmp "$WORKTREE/.claude/settings.json" "$FIXTURE/shared-before"
  python3 -c 'import json,sys; assert json.load(open(sys.argv[1])) == {"idleCompaction":False}' "$SETTINGS"
}

@test "all values other than boolean false require an update" {
  for value in true null 0 '"false"' '[]' '{}'; do
    config "{\"idleCompaction\":$value}"
    run cli --check
    [ "$status" -eq 2 ]
    run cli --apply
    [ "$status" -eq 0 ]
    run cli --check
    [ "$status" -eq 0 ]
  done
}

@test "invalid JSON non-object and duplicate keys fail unchanged without leaking content" {
  for body in '{"secret-leak":' '[]' 'null' '42' '{"a":1,"a":2}' '{"x":{"a":1,"a":2}}'; do
    config "$body"
    cp "$SETTINGS" "$FIXTURE/before"
    for mode in --check --apply; do
      run cli "$mode"
      [ "$status" -eq 1 ]
      [[ "$output" == *"$SETTINGS"* ]]
      [[ "$output" != *"secret-leak"* ]]
      cmp "$SETTINGS" "$FIXTURE/before"
    done
  done
}

@test "unreadable settings fail unchanged" {
  config '{"idleCompaction":true}'
  chmod 000 "$SETTINGS"
  for mode in --check --apply; do
    run cli "$mode"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$SETTINGS"* ]]
  done
  chmod 600 "$SETTINGS"
  [ "$(cat "$SETTINGS")" = '{"idleCompaction":true}' ]
}

@test "non-root nested directory non-git and missing worktrees fail without writes" {
  mkdir -p "$WORKTREE/nested" "$FIXTURE/plain"
  for path in "$WORKTREE/nested" "$FIXTURE/plain" "$FIXTURE/absent"; do
    for mode in --check --apply; do
      run python3 "$SCRIPT" "$mode" "$path"
      [ "$status" -eq 1 ]
      [ ! -e "$path/.claude" ]
    done
  done
}

@test "settings and directory symlinks including dangling links are rejected unchanged" {
  for target in "$TEST_HOME/.claude" "$FIXTURE/missing-dir"; do
    ln -s "$target" "$WORKTREE/.claude"
    for mode in --check --apply; do
      run cli "$mode"
      [ "$status" -eq 1 ]
      [ -L "$WORKTREE/.claude" ]
      [ ! -e "$target/settings.local.json" ]
    done
    unlink "$WORKTREE/.claude"
  done
  mkdir "$WORKTREE/.claude"
  printf '%s\n' '{"secret":"do not touch"}' > "$FIXTURE/target"
  cp "$FIXTURE/target" "$FIXTURE/before"
  for target in "$FIXTURE/target" "$FIXTURE/missing-file"; do
    ln -s "$target" "$SETTINGS"
    for mode in --check --apply; do
      run cli "$mode"
      [ "$status" -eq 1 ]
      [ -L "$SETTINGS" ]
      cmp "$FIXTURE/target" "$FIXTURE/before"
      [ ! -e "$FIXTURE/missing-file" ]
    done
    unlink "$SETTINGS"
  done
}
