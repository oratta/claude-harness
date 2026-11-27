#!/usr/bin/env bats
#
# 状態記録による停止検知とログ本文の非公開契約（#1744）。
# spec: dev-workflow-develop「wait は子の状態の記録だけで止まった子を検知する」「親の側は子の発言の本文を公開のコメントに載せない」
# 状態記録の有無と会話ログを独立に用意し、epic-dispatch.sh wait を当てる。
# 固定するのは stopped の検知、判断のコマンドに渡る止まりの JSON、子 issue のコメントの中身まで。判断の中身は対象外。
# 実行: scripts/test.sh epic-stop-from-log-scenario
# EPIC_STOP_SCENARIO_SCRIPT で対象のスクリプトを差し替えられる（スクリプトの写しを壊して落ちることを確かめるため）。
# 差し替え用の写しは scripts/ の中に置く（epic-dispatch.sh は同じディレクトリの epic-state.sh などを相対で読むため）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${EPIC_STOP_SCENARIO_SCRIPT:-${PLUGIN_DIR}/scripts/epic-dispatch.sh}"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  export STUB_CFG="$BATS_TEST_TMPDIR/cfg"
  export EPIC_STATE_ROOT="$BATS_TEST_TMPDIR/state"
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  export EPIC_DISPATCH_JUDGE="$STUB_BIN/judge"
  unset EPIC_DISPATCH_PARENT_EPIC EPIC_DISPATCH_STOP_TEXT_MAX EPIC_STATE_LOCK_TIMEOUT EPIC_DISPATCH_LAUNCHER TMUX EPIC_DISPATCH_TIMEOUT
  mkdir -p "$STUB_BIN" "$STUB_CFG"

  CHILD_WT="$BATS_TEST_TMPDIR/work/issue-11"
  SAID_UUID="dddddddd-0000-4000-8000-000000000001"
  SECRET="本文にだけある文字列 7f3a"
  mkdir -p "$CHILD_WT"

  stub git 'echo /work/parent'
  stub orca 'exit 0'
  # issue comment は本文を残し、一覧は空、それ以外は子 issue の state
  stub gh '
case "$1 $2" in
  "issue comment") printf "%s\n" "$5" >> "$STUB_CFG/comment_$3"; exit 0 ;;
esac
case "$2" in
  */comments) echo "[]"; exit 0 ;;
esac
echo open'
  stub judge '
printf "%s\n" "$#" > "$STUB_CFG/judge_argc"
[ -z "${3-}" ] || cp "$3" "$STUB_CFG/judge_json"
printf "判断: 主に上げる\n理由: 主の判断が要る\n返事:\n記録: なし\n"'

  # 記録: 親が起動しただけで、stop は空
  mkdir -p "$EPIC_STATE_ROOT/oratta.claude-harness-1122"
  RECORD="$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-11.json"
  jq -cn --arg w "$CHILD_WT" '{schema: 1, epic: "oratta/claude-harness#1122", child: "oratta/claude-harness#11",
    repo: "oratta/claude-harness", number: 11, launcher: "orca", parent_worktree: "/work/parent", worktree: $w,
    branch: "oratta/issue-11", base: "main", session: "", launch_failed: "", status: "running", stop: "",
    created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z"}' > "$RECORD"

  # 会話ログ: 起動時の入力（親が最初に送った行）のあと、子が 10 分前に問いを書いてターンを終え、そのあと何も無い
  local ts ts0 dir
  ts="$(jq -rn '(now - 600) | floor | todate')"
  ts0="$(jq -rn '(now - 660) | floor | todate')"
  dir="$CLAUDE_PROJECTS_DIR/$(printf '%s' "$CHILD_WT" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$dir"
  {
    jq -cn --arg ts "$ts0" '{type: "user", entrypoint: "cli", uuid: "00000000-0000-4000-8000-000000000000", timestamp: $ts, message: {role: "user", content: "/develop #11"}}'
    jq -cn --arg ts "$ts" --arg u "$SAID_UUID" --arg x "$SECRET どちらにしますか" \
      '{type: "assistant", entrypoint: "cli", uuid: $u, timestamp: $ts, message: {role: "assistant", content: [{type: "text", text: $x}]}}'
    jq -cn --arg ts "$ts" '{type: "system", subtype: "turn_duration", entrypoint: "cli", timestamp: $ts}'
  } > "$dir/s1.jsonl"
}

stub() {
  printf '#!/bin/bash\n%s\n' "$2" > "$STUB_BIN/$1"
  chmod +x "$STUB_BIN/$1"
}

dispatch() { PATH="$STUB_BIN:$PATH" bash "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"; }

record_turn() {
  jq '.turn_input={generation:1,session_id:"s1",sender:"parent",received_at:"2026-01-01T00:00:00Z",
      transcript_path:"/tmp/child.jsonl",transcript_offset:0}
    | .turn_state={generation:1,session_id:"s1",value:"主の返事待ち",summary:"確認待ち",recorded_at:"2026-01-01T00:00:01Z"}' \
    "$RECORD" > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
}

@test "stop scenario: a log alone never reaches the judge" {
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
  [ ! -e "$STUB_CFG/judge_argc" ]
  [ "$(jq -r .stop "$RECORD")" = '' ]
}

@test "stop scenario: wait returns a recorded parent wait with no mark" {
  record_turn
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(jq -r .stop "$RECORD")" = stopped-seen ]
  [ "$(jq -r .stop_uuid "$RECORD")" = "$SAID_UUID" ]
  [ ! -e "$STUB_CFG/judge_argc" ]
}

@test "stop scenario: --resolve hands the stop JSON to the judge" {
  record_turn
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(cat "$STUB_CFG/judge_argc")" -eq 3 ]
  [ "$(jq -r .uuid "$STUB_CFG/judge_json")" = "$SAID_UUID" ]
  jq -r .text "$STUB_CFG/judge_json" | grep -qF "$SECRET"
  [ "$(jq -r .marked "$STUB_CFG/judge_json")" = false ]
}

@test "stop scenario: an escalation posts the uuid and never the statement" {
  record_turn
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 主に上げる" ]
  [ "$(sed -n 2p "$STUB_CFG/comment_11")" = "止まりの発言: $SAID_UUID" ]
  [ "$(sed -n 3p "$STUB_CFG/comment_11")" = "停止の記録: なし" ]
  # 本文はどの公開のコメントにも載らない（子 issue だけでなくエピックへのコメントも）
  ! grep -qF "$SECRET" "$STUB_CFG/comment_11" || return 1
  local f
  for f in "$STUB_CFG"/comment_*; do
    ! grep -qF "$SECRET" "$f" || return 1
  done
}

@test "stop recovery: a missing uuid is filled without receiving or judging the turn again" {
  record_turn
  local projects="$CLAUDE_PROJECTS_DIR"
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/unavailable"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 0 ]; [ "$output" = 'stopped 11' ]
  [ "$(jq -r .stop_uuid "$RECORD")" = '' ]
  local received; received="$(jq -c '[.stop_turn,.stop_at]' "$RECORD")"
  rm -f "$STUB_CFG/judge_argc"
  export CLAUDE_PROJECTS_DIR="$projects"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
  [ "$(jq -r .stop_uuid "$RECORD")" = "$SAID_UUID" ]
  [ "$(jq -c '[.stop_turn,.stop_at]' "$RECORD")" = "$received" ]
  [ ! -e "$STUB_CFG/judge_argc" ]
  run dispatch told 11 "$SAID_UUID"
  [ "$status" -eq 0 ]; [ "$output" = 'told 11' ]
  run dispatch dismiss 11
  [ "$status" -eq 0 ]; [ "$output" = 'dismissed 11' ]
}

@test "stop recovery: another session cannot fill a missing uuid" {
  record_turn
  jq '.stop="stopped-seen" | .stop_uuid="" | .stop_turn={generation:1,session_id:"other"}
    | .turn_input.session_id="other" | .turn_state.session_id="other"' "$RECORD" > "$RECORD.tmp"
  mv "$RECORD.tmp" "$RECORD"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
  [ "$(jq -r .stop_uuid "$RECORD")" = '' ]
}

@test "stop types: float generations and offsets never reach stopped or the judge" {
  local mutation
  for mutation in '.turn_input.generation=1.0 | .turn_state.generation=1.0' '.turn_state.generation=1.0' '.turn_input.transcript_offset=0.0'; do
    record_turn
    jq "$mutation" "$RECORD" > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
    run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
    [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
    [ ! -e "$STUB_CFG/judge_argc" ]
  done
}

@test "stop legacy: stopped-seen without stop_turn is not received or judged again" {
  record_turn
  jq '.stop="stopped-seen" | .stop_uuid="old" | .stop_at="2026-01-01T00:00:02Z" | del(.stop_turn)' "$RECORD" > "$RECORD.tmp"
  mv "$RECORD.tmp" "$RECORD"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
  [ "$(jq -r .stop_uuid "$RECORD")" = old ]
  [ "$(jq -r .stop_at "$RECORD")" = '2026-01-01T00:00:02Z' ]
  [ ! -e "$STUB_CFG/judge_argc" ]
}

@test "stop legacy: an owner input resumes stopped-seen without stop_turn" {
  record_turn
  jq '.stop="stopped-seen" | del(.stop_turn) | .turn_input.generation=2
    | .turn_input.sender="owner" | .turn_state=null' "$RECORD" > "$RECORD.tmp"
  mv "$RECORD.tmp" "$RECORD"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
  [ "$(jq -r .stop "$RECORD")" = resumed ]
  [ ! -e "$STUB_CFG/judge_argc" ]
}

@test "stop resolve: read failures after detection preserve stopped output" {
  record_turn
  local failure original="$SCRIPT" copy="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$copy"
  cp -R "$PLUGIN_DIR/scripts" "$copy/scripts"
  for failure in 'child_record() { return 3; }' 'es_read() { return 1; }'; do
    python3 - "$original" "$copy/scripts/epic-dispatch.sh" "$failure" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
text = text.replace('resolve_stopped() {', 'resolve_stopped() {\n  ' + sys.argv[3])
pathlib.Path(sys.argv[2]).write_text(text)
PY
    SCRIPT="$copy/scripts/epic-dispatch.sh"
    record_turn
    jq '.stop="" | del(.stop_turn)' "$RECORD" > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
    run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
    [ "$status" -eq 0 ]; [ "$output" = 'stopped 11' ]
    [ ! -e "$STUB_CFG/judge_argc" ]
  done
}
