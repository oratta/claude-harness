#!/usr/bin/env bats
#
# 記録も印も無い止まりの検知（issue #1382 の受け入れ条件 1 件目。実機の子の止まり方の回帰）。
# spec: dev-workflow-develop「wait は子の会話ログから止まった子を検知する」「親の側は子の発言の本文を公開のコメントに載せない」
# 子が停止の記録も mark も残さずターンを終えた会話ログを置き、epic-dispatch.sh wait だけを当てる。
# 固定するのは stopped の検知、判断のコマンドに渡る止まりの JSON、子 issue のコメントの中身まで。判断の中身は対象外。
# 実行: scripts/test.sh epic-stop-from-log-scenario
# EPIC_STOP_SCENARIO_SCRIPT で対象のスクリプトを差し替えられる（スクリプトの写しを壊して落ちることを確かめるため）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${EPIC_STOP_SCENARIO_SCRIPT:-${PLUGIN_DIR}/scripts/epic-dispatch.sh}"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  export STUB_CFG="$BATS_TEST_TMPDIR/cfg"
  export EPIC_STATE_ROOT="$BATS_TEST_TMPDIR/state"
  export CLAUDE_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  export EPIC_DISPATCH_JUDGE="$STUB_BIN/judge"
  unset EPIC_DISPATCH_PARENT_EPIC EPIC_STATE_LOCK_TIMEOUT EPIC_DISPATCH_LAUNCHER TMUX EPIC_DISPATCH_TIMEOUT
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

  # 会話ログ: 子が 10 分前に問いを書いてターンを終え、そのあと何も無い
  local ts dir
  ts="$(jq -rn '(now - 600) | floor | todate')"
  dir="$CLAUDE_PROJECTS_DIR/$(printf '%s' "$CHILD_WT" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$dir"
  {
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

@test "stop scenario: wait returns a child that left no record and no mark" {
  run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(jq -r .stop "$RECORD")" = stopped-seen ]
  [ "$(jq -r .stop_uuid "$RECORD")" = "$SAID_UUID" ]
  [ ! -e "$STUB_CFG/judge_argc" ]
}

@test "stop scenario: --resolve hands the stop JSON to the judge" {
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$output" = "stopped 11" ]
  [ "$(cat "$STUB_CFG/judge_argc")" -eq 3 ]
  [ "$(jq -r .uuid "$STUB_CFG/judge_json")" = "$SAID_UUID" ]
  jq -r .text "$STUB_CFG/judge_json" | grep -qF "$SECRET"
  [ "$(jq -r .marked "$STUB_CFG/judge_json")" = false ]
}

@test "stop scenario: an escalation posts the uuid and never the statement" {
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 1122 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "$(sed -n 1p "$STUB_CFG/comment_11")" = "親の判断: 主に上げる" ]
  [ "$(sed -n 2p "$STUB_CFG/comment_11")" = "止まりの発言: $SAID_UUID" ]
  [ "$(sed -n 3p "$STUB_CFG/comment_11")" = "停止の記録: なし" ]
  ! grep -qF "$SECRET" "$STUB_CFG/comment_11"
}
