#!/usr/bin/env bats
#
# memory-tripwire.sh: メモリ索引の肥大と放置を SessionStart で検知する（#294）
# 閾値未満は無出力、超過は条件の数によらず 1 行、ディレクトリ不在・読めないときは無出力で exit 0。
# frontmatter の patches: の issue が閉じたメモリも同じ 1 行で知らせる（#1654）。
# 実ホームの控えと本物の gh に触れないよう、控えは一時ディレクトリに向け、偽の gh を PATH の先頭に置く。

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
  # session-tripwires.sh が内部で呼ぶ usage-probe を実環境（実 API・~/.claude の試行状態とロック）から切り離す
  USAGE_ISOLATION=(
    CLAUDE_ACCOUNTS_FILE="${WORK}/accounts.json"
    USAGE_SESSIONS_DIR="${WORK}/.usage-sessions"
    USAGE_PROBE_STATE="${WORK}/.usage-probe-state"
    USAGE_PROBE_LOCK="${WORK}/.usage-probe.lock"
    USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json"
  )
  # 偽の gh: 呼ばれたら引数を gh.log に残し、gh-responses の「URL<TAB>応答」で決めた状態を返す。
  # 応答は "CLOSED COMPLETED" / "CLOSED NOT_PLANNED" / "OPEN" / "fail" / "hang"。載っていない URL は fail。
  mkdir -p "${WORK}/bin"
  cat > "${WORK}/bin/gh" <<'GH'
#!/bin/sh
w="$(dirname "$0")/.."
printf '%s\n' "$*" >> "$w/gh.log"
url="$3"
resp="$(awk -F '\t' -v u="$url" '$1 == u { print $2 }' "$w/gh-responses" 2>/dev/null)"
case "$resp" in
  "CLOSED "*) printf '{"state":"CLOSED","stateReason":"%s"}\n' "${resp#CLOSED }" ;;
  OPEN) printf '{"state":"OPEN","stateReason":""}\n' ;;
  hang) sleep 30 ;;
  *) echo "HTTP 401: Bad credentials" >&2; exit 1 ;;
esac
GH
  chmod +x "${WORK}/bin/gh"
  : > "${WORK}/gh-responses"
  CACHE="${WORK}/cache/patches-cache.tsv"
  mkdir -p "${WORK}/cache"
  PATCHES_ISOLATION=(
    PATH="${WORK}/bin:${PATH}"
    DEV_WORKFLOW_MEMORY_PATCHES_CACHE="$CACHE"
  )
  TODAY="$(date +%Y-%m-%d)"
}

teardown() {
  chmod -R u+rw "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
}

run_check() {
  run env -u DEV_WORKFLOW_MEMORY_INDEX_BYTES -u DEV_WORKFLOW_MEMORY_INDEX_LINES \
    -u DEV_WORKFLOW_MEMORY_FILE_BYTES -u DEV_WORKFLOW_MEMORY_STALE_DAYS \
    -u DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT \
    "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$@" "$SCRIPT"
}

# 索引に載せたメモリを 1 件足す: add_mem <ファイル名> <frontmatter の中身（改行は \n）> [本文]
add_mem() {
  printf -- '---\n%b\n---\n%b\n' "$2" "${3:-body}" > "${MEM}/$1"
  printf -- '- [%s](%s) — x\n' "$1" "$1" >> "${MEM}/MEMORY.md"
}
respond() { printf '%s\t%s\n' "$1" "$2" >> "${WORK}/gh-responses"; }
gh_calls() { if [ -f "${WORK}/gh.log" ]; then grep -c '' "${WORK}/gh.log"; else echo 0; fi; }
# コマンドの実行にかかった時間（ミリ秒）。bash 3.2 でも測れるよう python3 で測る
elapsed_ms() {
  python3 -c 'import subprocess, sys, time
t = time.time(); subprocess.run(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(int((time.time() - t) * 1000))' "$@"
}
I1="https://github.com/acme/tools/issues/11"
I2="https://github.com/acme/tools/issues/12"
I3="https://github.com/acme/tools/issues/13"

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
  [[ "$output" == "[memory] "* ]] || return 1
  [[ "$output" == *"索引"*"閾値 4000 / 20"* ]] || return 1
  [[ "$output" == *"/memory-refresh"* ]] || return 1
}

@test "index over the line threshold: exactly one line" {
  for i in $(seq 1 25); do printf -- '- [m%s](m%s.md) — x\n' "$i" "$i"; done >> "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"28 行"* ]] || return 1
}

@test "one body file over the threshold: exactly one line naming the file" {
  head -c 3000 /dev/zero | tr '\0' 'y' > "${MEM}/b.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"本文 b.md が 3000 バイト（閾値 2500）"* ]] || return 1
  [[ "$output" != *"索引 "*"バイト /"* ]] || return 1
}

@test "index not updated for longer than the threshold: exactly one line" {
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"索引の最終更新から"*"日（閾値 30）"* ]] || return 1
}

@test "all three conditions at once: still one line carrying all of them" {
  for i in $(seq 1 25); do printf -- '- [m%s](m%s.md) — x\n' "$i" "$i"; done >> "${MEM}/MEMORY.md"
  head -c 3000 /dev/zero | tr '\0' 'y' > "${MEM}/b.md"
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"索引 "*"本文 b.md"*"最終更新から"* ]] || return 1
}

@test "fail-open: memory directory missing → no output, exit 0" {
  run env "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="${WORK}/nope" "$SCRIPT"
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
  run env -u DEV_WORKFLOW_MEMORY_DIR "${PATCHES_ISOLATION[@]}" CLAUDE_CONFIG_DIR="${WORK}/config" CLAUDE_PROJECT_DIR="${WORK}/plain" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "env overrides: each threshold can be lowered and raised" {
  run_check DEV_WORKFLOW_MEMORY_INDEX_LINES=1
  [[ "$output" == *"閾値 4000 / 1"* ]] || return 1
  run_check DEV_WORKFLOW_MEMORY_INDEX_BYTES=10
  [[ "$output" == *"閾値 10 / 20"* ]] || return 1
  run_check DEV_WORKFLOW_MEMORY_FILE_BYTES=3
  [[ "$output" == *"（閾値 3）"* ]] || return 1
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
  run env -u DEV_WORKFLOW_MEMORY_DIR "${PATCHES_ISOLATION[@]}" CLAUDE_CONFIG_DIR="${WORK}/config" CLAUDE_PROJECT_DIR="${WORK}/wt" "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"最終更新から"* ]] || return 1
}

@test "session-tripwires.sh: puts the notice at the top of additionalContext only when over a threshold" {
  touch -t 202001010000 "${MEM}/MEMORY.md"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${WORK}/missing.json" "${USAGE_ISOLATION[@]}" "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SESSION"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
ctx = json.loads(sys.argv[1])["additionalContext"]
assert ctx.startswith("[memory] "), ctx[:80]
assert "昇格トリップワイヤー" in ctx
PY
  touch "${MEM}/MEMORY.md"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${WORK}/missing.json" "${USAGE_ISOLATION[@]}" "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SESSION"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
ctx = json.loads(sys.argv[1])["additionalContext"]
assert "[memory]" not in ctx
PY
}

# --- #1654: frontmatter の patches: の issue が閉じたら知らせる ---

@test "patches: reads both metadata-nested and top-level values" {
  add_mem nested.md "name: n\nmetadata:\n  type: feedback\n  patches: ${I1}"
  add_mem top.md "name: t\npatches: ${I2}\nmetadata:\n  type: feedback"
  respond "$I1" "CLOSED COMPLETED"
  respond "$I2" "CLOSED COMPLETED"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == "[memory] "* ]] || return 1
  [[ "$output" == *"nested.md ← ${I1}"* ]] || return 1
  [[ "$output" == *"top.md ← ${I2}"* ]] || return 1
  [[ "$output" == *"/memory-refresh"* ]] || return 1
}

@test "patches: values outside the frontmatter or not an issue URL are ignored" {
  add_mem body.md "name: b" "本文\npatches: ${I1}"
  add_mem pr.md "name: p\npatches: https://github.com/acme/tools/pull/5"
  add_mem text.md "name: x\nmetadata:\n  patches: issue 11 を直したら消す"
  respond "$I1" "CLOSED COMPLETED"
  run_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" -eq 0 ]
  [ ! -e "$CACHE" ]
}

@test "patches: a value written outside the supported form does not stop the session start" {
  add_mem quoted.md "name: q\nmetadata:\n  patches: \"${I1}\""
  respond "$I1" "CLOSED COMPLETED"
  run_check
  [ "$status" -eq 0 ]
}

@test "patches: today's cache entry skips gh and finishes within 0.5 seconds" {
  add_mem a1.md "name: a\nmetadata:\n  patches: ${I1}"
  add_mem a2.md "name: a\npatches: ${I2}"
  printf '%s\t%s\t%s\t%s\n' "$I1" "$TODAY" CLOSED COMPLETED "$I2" "$TODAY" OPEN "" > "$CACHE"
  respond "$I1" "OPEN"
  run_check
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 0 ]
  [[ "$output" == *"a1.md ← ${I1}"* ]] || return 1
  [[ "$output" != *"a2.md"* ]] || return 1
  ms="$(elapsed_ms env "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SCRIPT")"
  echo "elapsed ${ms}ms"
  [ "$ms" -lt 500 ]
  [ "$(gh_calls)" -eq 0 ]
}

@test "patches: no patches at all finishes within 0.5 seconds without gh" {
  ms="$(elapsed_ms env "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SCRIPT")"
  echo "elapsed ${ms}ms"
  [ "$ms" -lt 500 ]
  [ "$(gh_calls)" -eq 0 ]
}

@test "patches: an entry from a previous day is checked again and rewritten with today's date" {
  add_mem old.md "name: o\nmetadata:\n  patches: ${I1}"
  printf '%s\t%s\t%s\t%s\n' "$I1" "2020-01-01" OPEN "" > "$CACHE"
  respond "$I1" "CLOSED COMPLETED"
  run_check
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 1 ]
  grep -qF "issue view ${I1}" "${WORK}/gh.log"
  [[ "$output" == *"old.md ← ${I1}"* ]] || return 1
  [ "$(grep -c '' "$CACHE")" -eq 1 ]
  awk -F '\t' -v u="$I1" -v d="$TODAY" '$1 == u && $2 == d && $3 == "CLOSED" && $4 == "COMPLETED" { f = 1 } END { exit !f }' "$CACHE"
}

@test "patches: the memory directory is left unchanged and holds no cache" {
  add_mem keep.md "name: k\nmetadata:\n  patches: ${I1}"
  respond "$I1" "CLOSED COMPLETED"
  before="$(cd "$MEM" && ls -lA && shasum ./*)"
  run_check
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  after="$(cd "$MEM" && ls -lA && shasum ./*)"
  [ "$before" = "$after" ]
  [ -s "$CACHE" ]
}

@test "patches: the default cache lives under CLAUDE_CONFIG_DIR, outside the memory directory" {
  add_mem keep.md "name: k\nmetadata:\n  patches: ${I1}"
  respond "$I1" "OPEN"
  mkdir -p "${WORK}/config"
  run env -u DEV_WORKFLOW_MEMORY_PATCHES_CACHE PATH="${WORK}/bin:${PATH}" CLAUDE_CONFIG_DIR="${WORK}/config" \
    DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -s "${WORK}/config/.memory-patches-cache.tsv" ]
  [ ! -e "${MEM}/.memory-patches-cache.tsv" ]
}

@test "patches: a cache that cannot be written still reports what was checked" {
  add_mem done.md "name: d\nmetadata:\n  patches: ${I1}"
  respond "$I1" "CLOSED COMPLETED"
  run_check DEV_WORKFLOW_MEMORY_PATCHES_CACHE="${WORK}/no-such-dir/cache.tsv"
  [ "$status" -eq 0 ]
  [[ "$output" == *"done.md ← ${I1}"* ]] || return 1
  [ ! -e "${WORK}/no-such-dir" ]
}

@test "patches: gh missing → no output, no cache, exit 0" {
  add_mem a.md "name: a\nmetadata:\n  patches: ${I1}"
  run env -u DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT PATH="/usr/bin:/bin" DEV_WORKFLOW_MEMORY_PATCHES_CACHE="$CACHE" \
    DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$CACHE" ]
}

@test "patches: gh failing → no output, unknown for today, not asked again the same day" {
  add_mem a.md "name: a\nmetadata:\n  patches: ${I1}"
  respond "$I1" "fail"
  run_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" -eq 1 ]
  awk -F '\t' -v u="$I1" -v d="$TODAY" '$1 == u && $2 == d && $3 == "UNKNOWN" { f = 1 } END { exit !f }' "$CACHE"
  run_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" -eq 1 ]
}

@test "patches: gh hanging past the timeout → stopped in time, unknown for today, no output" {
  add_mem a.md "name: a\nmetadata:\n  patches: ${I1}"
  respond "$I1" "hang"
  ms="$(elapsed_ms env "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT=1 DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SCRIPT")"
  echo "elapsed ${ms}ms"
  [ "$ms" -ge 1000 ]
  [ "$ms" -lt 2000 ]
  awk -F '\t' -v u="$I1" -v d="$TODAY" '$1 == u && $2 == d && $3 == "UNKNOWN" { f = 1 } END { exit !f }' "$CACHE"
  run_check DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT=1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" -eq 1 ]
}

@test "patches: a failed lookup does not hide the threshold or another closed issue" {
  for i in $(seq 1 25); do printf -- '- [m%s](m%s.md) — x\n' "$i" "$i"; done >> "${MEM}/MEMORY.md"
  add_mem bad.md "name: b\nmetadata:\n  patches: ${I1}"
  add_mem done.md "name: d\nmetadata:\n  patches: ${I2}"
  respond "$I1" "fail"
  respond "$I2" "CLOSED COMPLETED"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == "[memory] "*"索引 "*"閾値 4000 / 20"* ]] || return 1
  [[ "$output" == *"done.md ← ${I2}"* ]] || return 1
  [[ "$output" != *"bad.md"* ]] || return 1
  [[ "$output" != *"${I1}"* ]] || return 1
  [[ "$output" != *"401"* ]] || return 1
}

@test "patches: timeout 0 never calls gh and writes no cache" {
  add_mem a.md "name: a\nmetadata:\n  patches: ${I1}"
  respond "$I1" "CLOSED COMPLETED"
  run_check DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT=0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" -eq 0 ]
  [ ! -e "$CACHE" ]
}

@test "patches: only open issues → no output" {
  add_mem a.md "name: a\nmetadata:\n  patches: ${I1}"
  add_mem b2.md "name: b\npatches: ${I2}"
  respond "$I1" "OPEN"
  respond "$I2" "OPEN"
  run_check
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(gh_calls)" -eq 2 ]
}

@test "patches: an issue closed as not planned is reported too" {
  add_mem np.md "name: n\nmetadata:\n  patches: ${I3}"
  respond "$I3" "CLOSED NOT_PLANNED"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"np.md ← ${I3}"* ]] || return 1
}

@test "patches: threshold and closed issue together still give one line" {
  for i in $(seq 1 25); do printf -- '- [m%s](m%s.md) — x\n' "$i" "$i"; done >> "${MEM}/MEMORY.md"
  add_mem done.md "name: d\nmetadata:\n  patches: ${I1}"
  respond "$I1" "CLOSED COMPLETED"
  run_check
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"索引 "*"done.md ← ${I1}"* ]] || return 1
}

@test "patches: runs under the macOS system bash 3.2 (closed and hanging lookups)" {
  [ -x /bin/bash ] || skip "no /bin/bash"
  /bin/bash -c '[ "${BASH_VERSINFO[0]}" -le 3 ]' || skip "/bin/bash is not 3.x"
  add_mem done.md "name: d\nmetadata:\n  patches: ${I1}"
  add_mem slow.md "name: s\nmetadata:\n  patches: ${I2}"
  respond "$I1" "CLOSED COMPLETED"
  respond "$I2" "hang"
  run env "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_PATCHES_TIMEOUT=1 DEV_WORKFLOW_MEMORY_DIR="$MEM" /bin/bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(line_count "$output")" -eq 1 ]
  [[ "$output" == *"done.md ← ${I1}"* ]] || return 1
  [[ "$output" != *"slow.md"* ]] || return 1
}

@test "session-tripwires.sh: a closed patches: issue puts the notice at the top of additionalContext" {
  add_mem done.md "name: d\nmetadata:\n  patches: ${I1}"
  respond "$I1" "CLOSED COMPLETED"
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" USAGE_SNAPSHOT="${WORK}/missing.json" "${USAGE_ISOLATION[@]}" "${PATCHES_ISOLATION[@]}" DEV_WORKFLOW_MEMORY_DIR="$MEM" "$SESSION"
  [ "$status" -eq 0 ]
  python3 - "$output" "$I1" <<'PY'
import json, sys
ctx = json.loads(sys.argv[1])["additionalContext"]
assert ctx.startswith("[memory] "), ctx[:80]
assert ("done.md ← " + sys.argv[2]) in ctx.splitlines()[0], ctx.splitlines()[0]
assert "昇格トリップワイヤー" in ctx
PY
}
