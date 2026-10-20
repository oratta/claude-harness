#!/usr/bin/env bats
#
# rm-permission-guard.sh: PermissionRequest（Bash）で、子の rm の確認画面に親の許可に従って答える。
# 判定は git-guard-scratchpad.py の check_rm。許可を書くのは git-guard-permit.sh。
# spec: rm-permission-hook（openspec/changes/rm-permission-parent-permit）
# 出力の形（hookSpecificOutput.decision.behavior / message）は実機（claude -p --plugin-dir）で確かめた形。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/rm-permission-guard.sh"
  PERMIT="${PLUGIN_DIR}/scripts/git-guard-permit.sh"
  COMMON="${PLUGIN_DIR}/scripts/git-guard-scratchpad.py"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  unset CDPATH GIT_DIR GIT_WORK_TREE DEV_WORKFLOW_UNATTENDED
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "$TMPDIR"
  SID="0a1b2c3d-sid1"
  SP="$(scratch_dir "$SID")"
  mkdir -p "$SP/tbl/x" "$SP/other"
  touch "$SP/tbl/x/a" "$SP/tbl/x/b" "$SP/other/keep"
  OUT="${BATS_TEST_TMPDIR}/outside"
  mkdir -p "$OUT/dir"
  touch "$OUT/dir/f"
}

scratch_dir() {
  local d="${2:-$TMPDIR}/claude-$(id -u)/slug/$1/scratchpad"
  mkdir -p "$d"
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$d"
}

BASE() { printf '%s' "$TMPDIR/dev-workflow-git-guard"; }

# call <command> <agent_id(JSON か "-")> <cwd> [session_id] — PermissionRequest の payload を hook に渡す
call() {
  local json
  json="$(printf '%s' "$1" | python3 -c '
import json, sys
p = {"hook_event_name": "PermissionRequest", "tool_name": "Bash", "permission_mode": "default",
     "tool_input": {"command": sys.stdin.read()}, "cwd": sys.argv[2], "session_id": sys.argv[3]}
if sys.argv[1] != "-":
    p["agent_id"] = json.loads(sys.argv[1])
print(json.dumps(p))' "$2" "$3" "${4:-$SID}")"
  run "$SCRIPT" <<<"$json"
}

behavior() {
  python3 -c '
import json, sys
try:
    o = json.loads(sys.stdin.read())["hookSpecificOutput"]
    assert o["hookEventName"] == "PermissionRequest"
    print(o["decision"]["behavior"])
except Exception:
    pass' <<<"$output"
}

message() {
  python3 -c '
import json, sys
print(json.loads(sys.stdin.read())["hookSpecificOutput"]["decision"].get("message", ""))' <<<"$output"
}

only_record() {
  local fs
  fs=("$(BASE)"/denied/*.json)
  [ "${#fs[@]}" -eq 1 ] && [ -f "${fs[0]}" ] || { echo "records: ${fs[*]}" >&2; return 1; }
  printf '%s' "${fs[0]}"
}

permits_empty() {
  local d="$(BASE)/permits"
  [ ! -d "$d" ] || [ -z "$(ls -A "$d")" ] || { ls -la "$d"; return 1; }
}

# deny_then_permit <command> <cwd> — 子 a1 の拒否を作り、その記録で許可を書く
deny_then_permit() {
  call "$1" '"a1"' "$2"
  [ "$(behavior)" = "deny" ] || { echo "first call: $output"; return 1; }
  local rec
  rec="$(only_record)" || return 1
  run "$PERMIT" "$rec" "検証用の片づけ"
  [ "$status" -eq 0 ] || { echo "permit failed: $output"; return 1; }
}

# chk <session_id> <cwd> <command> — rm 用の判定。満たせば exit 0、満たさなければ理由を出して exit 1
chk() {
  python3 -I -c '
import sys
ns = {"__name__": "x"}
exec(compile(open(sys.argv[1]).read(), sys.argv[1], "exec"), ns)
err, sp, t = ns["check_rm"](sys.argv[2], sys.argv[3], sys.argv[4])
if err:
    print(err); sys.exit(1)
print(sp)' "$COMMAND_PY" "$1" "$2" "$3"
}

COMMAND_PY="" # setup 後に COMMON を入れる
chk_() { COMMAND_PY="$COMMON"; chk "$@"; }

@test "hooks.json registers rm-permission-guard on PermissionRequest for Bash" {
  run python3 - "$HOOKS_JSON" <<'PY'
import json, sys
h = json.load(open(sys.argv[1]))["hooks"]["PermissionRequest"]
assert any(e["matcher"] == "Bash" and any("rm-permission-guard.sh" in x["command"] for x in e["hooks"]) for e in h), h
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# --- hook ---

@test "hook: a child's rm without a permit is denied with the report guidance and a record" {
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"
  [ "$status" -eq 0 ]
  [ "$(behavior)" = "deny" ] || { echo "$output"; return 1; }
  m="$(message)"
  [[ "$m" == *"何を"* && "$m" == *"なぜ"* && "$m" == *"報告"* ]] || { echo "$m"; return 1; }
  rec="$(only_record)"
  [[ "$m" == *"$rec"* ]] || return 1
  python3 - "$rec" "$SP" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
assert r["agent_id"] == "a1" and r["cwd"] == sys.argv[2] and r["kinds"] == ["rm"] and r["command"].startswith("rm -rf "), r
PY
}

@test "hook: a child's deny message names a way to get the parent's permit" {
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ] || { echo "$output"; return 1; }
  m="$(message)"
  [[ "$m" == *'実パスで単独のコマンド'* && "$m" == *'変数'* ]] || { echo "$m"; return 1; }
}

@test "hook: the main session, a non-rm command and an empty agent_id get no output" {
  deny_then_permit "rm -rf $SP/tbl/x/*" "$SP"
  call "rm -rf $SP/tbl/x/*" '-' "$SP"
  [ "$status" -eq 0 ] && [ -z "$output" ]
  call "rm -rf $SP/tbl/x/*" '""' "$SP"
  [ "$status" -eq 0 ] && [ -z "$output" ]
  call "rm -rf $SP/tbl/x/*" '7' "$SP"
  [ "$status" -eq 0 ] && [ -z "$output" ]
  call "ls -la" '"a1"' "$SP"
  [ "$status" -eq 0 ] && [ -z "$output" ]
  call "git status" '"a1"' "$SP"
  [ "$status" -eq 0 ] && [ -z "$output" ]
  [ "$(ls "$(BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
}

@test "hook: a broken payload gets no output" {
  run "$SCRIPT" <<<'not json'
  [ "$status" -eq 0 ] && [ -z "$output" ]
  run "$SCRIPT" <<<''
  [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "hook: a matching permit allows the call exactly once and the log has permit then use" {
  deny_then_permit "cd $SP/tbl; rm -rf x/*" "$SP"
  call "cd $SP/tbl; rm -rf x/*" '"a1"' "$SP"
  [ "$(behavior)" = "allow" ] || { echo "$output"; return 1; }
  permits_empty
  call "cd $SP/tbl; rm -rf x/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  python3 - "$(BASE)/permit-log.jsonl" <<'PY'
import json, sys
ev = [json.loads(l)["event"] for l in open(sys.argv[1])]
assert ev == ["permit", "use"], ev
PY
}

@test "hook: calls that do not match do not use the permit" {
  deny_then_permit "rm -rf $SP/tbl/x/*" "$SP"
  call "rm -rf $SP/tbl/x/* " '"a1"' "$SP"; [ "$(behavior)" = "deny" ]
  call "rm -rf $SP/tbl/x/*" '"a2"' "$SP"; [ "$(behavior)" = "deny" ]
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP/tbl"; [ "$(behavior)" = "deny" ]
  [ "$(ls "$(BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"; [ "$(behavior)" = "allow" ]
}

@test "hook: an expired permit is not used and is removed" {
  deny_then_permit "rm -rf $SP/tbl/x/*" "$SP"
  f="$(ls "$(BASE)"/permits/*.json)"
  python3 - "$f" <<'PY'
import json, sys
p = json.load(open(sys.argv[1])); p["expires_at"] = 1
json.dump(p, open(sys.argv[1], "w"))
PY
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  permits_empty
  grep -qF '"expired"' "$(BASE)/permit-log.jsonl"
}

@test "hook: if the parent directory is swapped to point outside after the permit, the hook denies" {
  deny_then_permit "rm -rf $SP/tbl/x/*" "$SP"
  mv "$SP/tbl/x" "$SP/tbl/x.moved"
  ln -s "$OUT/dir" "$SP/tbl/x"
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  [[ "$(message)" == *"許可はあるが行き先を確かめられない"* ]] || { echo "$output"; return 1; }
  permits_empty
  [ -f "$OUT/dir/f" ]
  grep -qF '"rejected"' "$(BASE)/permit-log.jsonl"
}

@test "hook: a permit written directly for an outside target is denied" {
  call "rm -rf $OUT/dir/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  rec="$(only_record)"
  k="$(basename "$rec" .json)"
  mkdir -p "$(BASE)/permits"
  python3 - "$(BASE)/permits/$k.json" "$SID" "$SP" "$OUT" <<'PY'
import json, sys, time
json.dump({"session_id": sys.argv[2], "agent_id": "a1", "cwd": sys.argv[3], "command": "rm -rf %s/dir/*" % sys.argv[4],
           "expires_at": int(time.time()) + 600}, open(sys.argv[1], "w"))
PY
  call "rm -rf $OUT/dir/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  [[ "$(message)" == *"許可はあるが行き先を確かめられない"* ]] || return 1
  permits_empty
}

@test "hook: without the common file it denies, writes no record, keeps the permit and does not show a path" {
  deny_then_permit "rm -rf $SP/tbl/x/*" "$SP"
  rm -rf "$(BASE)/denied"
  iso="${BATS_TEST_TMPDIR}/iso"
  mkdir -p "$iso"
  cp "$SCRIPT" "$iso/rm-permission-guard.sh"
  SCRIPT="$iso/rm-permission-guard.sh"
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  m="$(message)"
  [[ "$m" == *"作れなかった"* && "$m" != *"denied/"* ]] || { echo "$m"; return 1; }
  [ ! -d "$(BASE)/denied" ]
  [ "$(ls "$(BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
}

@test "hook: when the record cannot be written it still denies and says so" {
  mkdir -p "$(BASE)"
  printf x >"$(BASE)/denied"
  call "rm -rf $SP/tbl/x/*" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  m="$(message)"
  [[ "$m" == *"作れなかった"* && "$m" != *"denied/"* ]] || { echo "$m"; return 1; }
}

@test "hook: a command with an unreadable form is denied even with a permit written directly" {
  call "rm -rf \"$SP/tbl/x\"" '"a1"' "$SP"
  [ "$(behavior)" = "deny" ]
  rec="$(only_record)"
  run "$PERMIT" "$rec" "検証"
  [ "$status" -ne 0 ]
  permits_empty
}

# --- git-guard-permit.sh ---

@test "permit: an rm record gets a permit decided by the command, not by kinds" {
  call "cd $SP/tbl && rm -rf x/*" '"a1"' "$SP"
  rec="$(only_record)"
  python3 - "$rec" <<'PY'
import json, sys
r = json.load(open(sys.argv[1])); r["kinds"] = ["git"]; json.dump(r, open(sys.argv[1], "w"))
PY
  run "$PERMIT" "$rec" "検証"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(ls "$(BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
  [[ "$output" == *"$SP"* ]] || return 1
}

@test "permit: an rm record for an outside target gets no permit" {
  call "rm -rf $OUT/dir/*" '"a1"' "$SP"
  run "$PERMIT" "$(only_record)" "検証"
  [ "$status" -ne 0 ]
  permits_empty
}

# --- rm 用の判定 ---

@test "check_rm: targets inside the scratchpad are satisfied" {
  chk_ "$SID" "$SP" "rm -rf ./a"
  chk_ "$SID" "$SP" "rm -f $SP/tbl/x/*.tmp"
  chk_ "$SID" "$SP" "cd ./tbl; rm -rf x/*"
  chk_ "$SID" "$SP" "cd ./tbl && rm -f a b"
  chk_ "$SID" "$SP" "rm -rf ./link"
  chk_ "$SID" "$SP" "rm -rf $SP/tbl"
  chk_ "$SID" "$SP" "rm -fr a
rm -R b"
}

@test "check_rm: a symlink as the last element is removed itself, not followed" {
  ln -s "$OUT/dir" "$SP/link"
  chk_ "$SID" "$SP" "rm -rf $SP/link"
  [ -f "$OUT/dir/f" ]
}

@test "check_rm: outside, too-wide and unreadable targets are not satisfied" {
  local c
  for c in "rm -rf /" "rm -rf ~" 'rm -rf $HOME/x' "rm -rf ../../.." "rm -rf $SP" "rm -rf $SP/*" \
           "rm -rf $SP/tbl/." "rm -rf $SP/tbl/" "rm -rf $OUT/dir" "rm -rf $SP/a/*/b" "rm -rf $SP/.*" \
           "rm -- x" "rm -i x" "rm -rf" 'rm -rf "x"' "rm -rf x > o" "rm -rf x | cat" "rm -rf x && ls" "ls && rm -rf x" \
           "rm -rf x; cd ./y" "cd ./tbl; cd ./x; rm -rf a" 'rm -rf $(echo x)' "rm -rf {a,b}" "rm -rf x &" \
           "cd tbl; rm -rf x" "cd -P; rm -rf x"; do
    run chk_ "$SID" "$SP" "$c"
    [ "$status" -ne 0 ] || { echo "satisfied: $c"; return 1; }
  done
}

@test "check_rm: a zsh = expansion word is not satisfied (judge and shell would disagree)" {
  local c
  for c in "rm -f =python3" "rm -f ./=python3" "cd ./tbl; rm -f =python3" "rm -f $SP/tbl/x/=python3"; do
    run chk_ "$SID" "$SP" "$c"
    [ "$status" -ne 0 ] || { echo "satisfied: $c"; return 1; }
  done
}

@test "hook: rm -f =python3 cannot get a permit and is denied, also with cwd inside the scratchpad" {
  call "rm -f =python3" '"a1"' "$SP/tbl"
  [ "$(behavior)" = "deny" ]
  run "$PERMIT" "$(only_record)" "検証"
  [ "$status" -ne 0 ]
  permits_empty
}

@test "check_rm: a parent that is a symlink pointing outside is not satisfied" {
  ln -s "$OUT/dir" "$SP/linkdir"
  run chk_ "$SID" "$SP" "rm -rf $SP/linkdir/f"
  [ "$status" -ne 0 ]
}

@test "check_rm: another session's scratchpad is not satisfied" {
  other="$(scratch_dir other-sid)"
  run chk_ "$SID" "$SP" "rm -rf $other/x"
  [ "$status" -ne 0 ]
}

@test "check_rm: cd that may fail is checked against the cwd too" {
  run chk_ "$SID" "$OUT" "cd $SP/tbl; rm -rf x/*"
  [ "$status" -ne 0 ]
  chk_ "$SID" "$SP" "cd ./tbl; rm -rf x/*"
  # 絶対パスの削除先は cd の成否によらず同じ
  chk_ "$SID" "$OUT" "cd $SP/tbl; rm -rf $SP/tbl/x/*"
}

@test "check_rm: judging does not run rm" {
  mkdir -p "$BATS_TEST_TMPDIR/stub"
  printf '#!/bin/sh\ntouch %s/called\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/stub/rm"
  chmod +x "$BATS_TEST_TMPDIR/stub/rm"
  PATH="$BATS_TEST_TMPDIR/stub:$PATH" chk_ "$SID" "$SP" "rm -rf $SP/tbl/x/*"
  [ ! -e "$BATS_TEST_TMPDIR/called" ]
  [ -f "$SP/tbl/x/a" ]
}
