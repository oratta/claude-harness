#!/usr/bin/env bats
#
# memory-tripwire.sh: メモリ索引の肥大と放置を SessionStart で検知する（#294）
# 閾値未満は無出力、超過は条件の数によらず 1 行、ディレクトリ不在・読めないときは無出力で exit 0。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/memory-tripwire.sh"
  SESSION="${PLUGIN_DIR}/scripts/session-tripwires.sh"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  MEM="${WORK}/memory"
  mkdir -p "$MEM"
  # 閾値未満の既定状態: 索引 3 行・本文 2 件とも小さい・今作ったので新しい
  printf '# Memory Index\n- [a](a.md) — a\n- [b](b.md) — b\n' > "${MEM}/MEMORY.md"
  printf 'short a\n' > "${MEM}/a.md"
  printf 'short b\n' > "${MEM}/b.md"
}

teardown() {
  chmod -R u+rw "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
}

run_check() {
  run env -u DEV_WORKFLOW_MEMORY_INDEX_BYTES -u DEV_WORKFLOW_MEMORY_INDEX_LINES \
    -u DEV_WORKFLOW_MEMORY_FILE_BYTES -u DEV_WORKFLOW_MEMORY_STALE_DAYS \
    DEV_WORKFLOW_MEMORY_DIR="$MEM" "$@" "$SCRIPT"
}

line_count() { printf '%s' "$1" | grep -c '' ; }

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "under all thresholds: no output, exit 0" {
  run_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "index over the byte threshold: exactly one line" {
  head -c 5000 /dev/zero | tr '\0' 'x' >> "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == "[memory] "* ]]
  [[ "$output" == *"索引"*"閾値 4000 / 20"* ]]
  [[ "$output" == *"/memory-refresh"* ]]
}

@test "index over the line threshold: exactly one line" {
  for i in $(seq 1 25); do printf -- '- [m%s](m%s.md) — x\n' "$i" "$i"; done >> "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"28 行"* ]]
}

@test "one body file over the threshold: exactly one line naming the file" {
  head -c 3000 /dev/zero | tr '\0' 'y' > "${MEM}/b.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"本文 b.md が 3000 バイト（閾値 2500）"* ]]
  [[ "$output" != *"索引 "*"バイト /"* ]]
}

@test "index not updated for longer than the threshold: exactly one line" {
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"索引の最終更新から"*"日（閾値 30）"* ]]
}

@test "all three conditions at once: still one line carrying all of them" {
  for i in $(seq 1 25); do printf -- '- [m%s](m%s.md) — x\n' "$i" "$i"; done >> "${MEM}/MEMORY.md"
  head -c 3000 /dev/zero | tr '\0' 'y' > "${MEM}/b.md"
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"索引 "*"本文 b.md"*"最終更新から"* ]]
}

@test "fail-open: memory directory missing → no output, exit 0" {
  run env DEV_WORKFLOW_MEMORY_DIR="${WORK}/nope" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: index unreadable → no output, exit 0" {
  [ "$(id -u)" -ne 0 ] || skip "root can read mode 000 files"
  head -c 5000 /dev/zero | tr '\0' 'x' >> "${MEM}/MEMORY.md"
  chmod 000 "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: no project resolvable (not a git repo, no memory under CLAUDE_CONFIG_DIR) → no output" {
  mkdir -p "${WORK}/plain" "${WORK}/config"
  run env -u DEV_WORKFLOW_MEMORY_DIR CLAUDE_CONFIG_DIR="${WORK}/config" CLAUDE_PROJECT_DIR="${WORK}/plain" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "env overrides: each threshold can be lowered and raised" {
  run_check DEV_WORKFLOW_MEMORY_INDEX_LINES=1
  [[ "$output" == *"閾値 4000 / 1"* ]]
  run_check DEV_WORKFLOW_MEMORY_INDEX_BYTES=10
  [[ "$output" == *"閾値 10 / 20"* ]]
  run_check DEV_WORKFLOW_MEMORY_FILE_BYTES=3
  [[ "$output" == *"（閾値 3）"* ]]
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run_check DEV_WORKFLOW_MEMORY_STALE_DAYS=100000
  [ -z "$output" ]
}

@test "env overrides: a non-numeric value falls back to the default instead of failing" {
  run_check DEV_WORKFLOW_MEMORY_INDEX_LINES=abc
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "resolution: a worktree resolves to the main repository's memory directory" {
  git init -q "${WORK}/repo"
  git -C "${WORK}/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "${WORK}/repo" worktree add -q "${WORK}/wt" -b wt
  slug="$(printf '%s' "${WORK}/repo" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "${WORK}/config/projects/${slug}"
  cp -R "$MEM" "${WORK}/config/projects/${slug}/memory"
  touch -t 202001010000 "${WORK}/config/projects/${slug}/memory/MEMORY.md"
  run env -u DEV_WORKFLOW_MEMORY_DIR CLAUDE_CONFIG_DIR="${WORK}/config" CLAUDE_PROJECT_DIR="${WORK}/wt" "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"最終更新から"* ]]
}

@test "session-tripwires.sh: puts the notice at the top of additionalContext only when over a threshold" {
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${WORK}/missing.json" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SESSION"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
ctx = json.loads(sys.argv[1])["additionalContext"]
assert ctx.startswith("[memory] "), ctx[:80]
assert "昇格トリップワイヤー" in ctx
PY
  touch "${MEM}/MEMORY.md"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${WORK}/missing.json" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SESSION"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
ctx = json.loads(sys.argv[1])["additionalContext"]
assert "[memory]" not in ctx
PY
}
