#!/usr/bin/env bats
#
# ci-watch.sh: ゲート合格後の PR の CI を見張る。wait は決着するまで黙って待って 1 行の JSON を出し、
# next は PR を取り直して pr-state.sh の annotations → observe → decide に通し、PR ごとの状態ファイルを
# 書き換える。あわせて、見張りの手順の正本 references/ci-watch.md と、それを参照する
# pr-review-gate / develop / gate-runner の記述を確かめる。
#
# spec: openspec/changes/ci-watch-after-gate（dev-workflow-ci-watch / dev-workflow-pr-review-gate /
#       dev-workflow-develop）

bats_require_minimum_version 1.5.0

LOST='The self-hosted runner lost communication with the server.'
# ジョブが上限時間（timeout-minutes）で打ち切られたときに GitHub が付ける annotation
TIMED_OUT='The job running on runner mac-1 has exceeded the maximum execution time of 40 minutes.'
CANCELED='The operation was canceled.'

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/ci-watch.sh"
  REF="${PLUGIN_DIR}/references/ci-watch.md"
  GATE_SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  PASS_STAGE="$BATS_TEST_TMPDIR/pass-all.md"
  cat "${PLUGIN_DIR}/skills/pr-review-gate/stages/pass-verify.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/pass.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/pass-wording.md" > "$PASS_STAGE"
  HOLD_CORE="${PLUGIN_DIR}/skills/pr-review-gate/stages/hold.md"
  HOLD="$BATS_TEST_TMPDIR/hold-all.md"
  cat "$HOLD_CORE" "${PLUGIN_DIR}/skills/pr-review-gate/stages/hold-resume.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/hold-categories.md" > "$HOLD"
  CARRYOVER_CORE="${PLUGIN_DIR}/skills/pr-review-gate/stages/carryover.md"
  CARRYOVER_JUDGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/carryover-judge.md"
  CARRYOVER_ORIGIN="${PLUGIN_DIR}/skills/pr-review-gate/stages/carryover-origin.md"
  CARRYOVER_RUN="${PLUGIN_DIR}/skills/pr-review-gate/stages/carryover-judge-run.md"
  CARRYOVER="$BATS_TEST_TMPDIR/carryover-all.md"
  cat "$CARRYOVER_CORE" "$CARRYOVER_ORIGIN" "$CARRYOVER_RUN" "$CARRYOVER_JUDGE" > "$CARRYOVER"
  AUTH="$BATS_TEST_TMPDIR/authenticity-all.md"
  cat "${PLUGIN_DIR}/skills/pr-review-gate/stages/authenticity.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/authenticity-relayed.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/authenticity-delegated.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/authenticity-delegated-first.md" "${PLUGIN_DIR}/skills/pr-review-gate/stages/issue-approved.md" > "$AUTH"
  DEVELOP="${PLUGIN_DIR}/skills/develop/SKILL.md"
  GATE_RUNNER="${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  GH_LOG="${WORK}/gh.log"
  STATE_DIR="${WORK}/state"
  mkdir -p "${WORK}/bin" "${WORK}/view" "${WORK}/ann"
  # gh の偽物: 呼び出しを記録する。pr view は呼ばれた回数 n ごとに view/<n>.json を返し、無ければ
  # 最後に返したものを返す。view/fail があれば非 0 で終わる。check-runs/<job>/annotations には
  # ann/<job>.json（無ければ []）を返す。それ以外の呼び出しは記録だけして 0 で終わる
  cat > "${WORK}/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${GH_LOG}"
if [ "\$1 \$2" = "pr view" ]; then
  [ -e "${WORK}/view/fail" ] && { echo "gh: HTTP 502" >&2; exit 1; }
  n=\$(( \$(cat "${WORK}/view/count" 2>/dev/null || echo 0) + 1 ))
  echo "\$n" > "${WORK}/view/count"
  [ -e "${WORK}/view/\${n}.json" ] && cp "${WORK}/view/\${n}.json" "${WORK}/view/last.json"
  cat "${WORK}/view/last.json"
  exit 0
fi
job="\$(printf '%s' "\$*" | sed -nE 's#.*check-runs/([0-9]+)/annotations.*#\1#p')"
if [ -n "\$job" ]; then
  cat "${WORK}/ann/\${job}.json" 2>/dev/null || echo '[]'
fi
exit 0
EOF
  chmod +x "${WORK}/bin/gh"
  export PATH="${WORK}/bin:${PATH}"
  export DEV_WORKFLOW_PR_STATE_DIR="$STATE_DIR"
  export DEV_WORKFLOW_CI_WATCH_INTERVAL=1
  export DEV_WORKFLOW_CI_WATCH_TIMEOUT=30
}

teardown() {
  rm -rf "$WORK"
}

# Actions のチェック: $1=名前 $2=conclusion（空なら実行中） $3=run $4=job
actions_check() {
  if [ -n "$2" ]; then
    jq -cn --arg n "$1" --arg c "$2" --arg u "https://github.com/o/r/actions/runs/$3/job/$4" \
      '{name: $n, status: "COMPLETED", conclusion: $c, detailsUrl: $u}'
  else
    jq -cn --arg n "$1" --arg u "https://github.com/o/r/actions/runs/$3/job/$4" \
      '{name: $n, status: "IN_PROGRESS", conclusion: "", detailsUrl: $u}'
  fi
}

# gh pr view の JSON を view/<n>.json に置く: $1=n $2=state $3=mergeable $4=statusCheckRollup $5=headRefOid
put_view() {
  jq -cn --arg s "$2" --arg m "$3" --argjson c "$4" --arg h "$5" \
    '{state: $s, mergeable: $m, statusCheckRollup: $c, headRefOid: $h}' > "${WORK}/view/$1.json"
}

state_file() {
  printf '%s/o__r__5.json' "$STATE_DIR"
}

pr_view_calls() {
  grep -c '^pr view' "$GH_LOG" || true
}

# ── wait ──────────────────────────────────────────────────

@test "wait: stays silent while running and prints settled once the CI fails" {  # 実行中は黙り、落ちたら settled
  put_view 1 OPEN MERGEABLE "[$(actions_check build '' 11 77)]" h1
  put_view 2 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
  [ "$(jq -r .result <<<"$output")" = settled ]
  [ "$(jq -r .obs.state <<<"$output")" = ci-fail ]
  [ "$(jq -c .obs.runs <<<"$output")" = '["11"]' ]
}

@test "wait: fetches annotations only on the settled observation" {  # 決着した回だけ annotation を取る
  put_view 1 OPEN MERGEABLE "[$(actions_check build '' 11 77)]" h1
  put_view 2 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$(grep -c 'check-runs/77/annotations' "$GH_LOG")" -eq 1 ]
  # annotation の呼び出しは 2 回目の pr view より後にある
  [ "$(grep -n 'check-runs/77/annotations' "$GH_LOG" | cut -d: -f1)" -gt "$(grep -n '^pr view' "$GH_LOG" | sed -n 2p | cut -d: -f1)" ]
}

@test "wait: a runner-lost annotation reaches the settled observation" {  # 通信切れの annotation は観測に入る
  put_view 1 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  jq -cn --arg m "$LOST" '[{message: $m}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r '.obs.checks[0].cause' <<<"$output")" = runner-lost ]
  [ "$(jq -r .obs.retry <<<"$output")" = true ]
}

@test "wait: a time-limit annotation reaches the settled observation as job-timeout" {  # 打ち切りの annotation は観測に入る
  put_view 1 OPEN MERGEABLE "[$(actions_check test CANCELLED 11 77)]" h1
  jq -cn --arg m "$TIMED_OUT" --arg c "$CANCELED" '[{message: $m}, {message: $c}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .result <<<"$output")" = settled ]
  [ "$(jq -r '.obs.checks[0].cause' <<<"$output")" = job-timeout ]
  [ "$(jq -r .obs.retry <<<"$output")" = true ]
}

@test "wait: prints merged when the PR is merged" {  # マージされたら merged
  put_view 1 MERGED UNKNOWN "[$(actions_check build SUCCESS 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$output" = '{"result":"merged","obs":null}' ]
}

@test "wait: prints closed when the PR is closed" {  # 閉じられたら closed
  put_view 1 CLOSED MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$output" = '{"result":"closed","obs":null}' ]
}

@test "wait: settles on ready without --until-merged" {  # --until-merged なしは ready で決着
  put_view 1 OPEN MERGEABLE "[$(actions_check build SUCCESS 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .result <<<"$output")" = settled ]
  [ "$(jq -r .obs.state <<<"$output")" = ready ]
}

@test "wait: --until-merged keeps waiting through ready" {  # --until-merged は ready でも待つ
  put_view 1 OPEN MERGEABLE "[$(actions_check build SUCCESS 11 77)]" h1
  put_view 2 MERGED UNKNOWN "[$(actions_check build SUCCESS 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5 --until-merged
  [ "$status" -eq 0 ]
  [ "$output" = '{"result":"merged","obs":null}' ]
  [ "$(pr_view_calls)" -eq 2 ]
}

@test "wait: --until-merged settles on ci-fail after ready without waiting for the timeout" {  # ready のあとの失敗は settled
  put_view 1 OPEN MERGEABLE "[$(actions_check build SUCCESS 11 77)]" h1
  put_view 2 OPEN MERGEABLE "[$(actions_check build FAILURE 12 78)]" h1
  jq -cn --arg m "$LOST" '[{message: $m}]' > "${WORK}/ann/78.json"
  DEV_WORKFLOW_CI_WATCH_TIMEOUT=10 run --separate-stderr "$SCRIPT" wait o/r 5 --until-merged
  [ "$status" -eq 0 ]
  [ "$(jq -r .result <<<"$output")" = settled ]
  [ "$(jq -r .obs.state <<<"$output")" = ci-fail ]
  [ "$(jq -r '.obs.checks[0].cause' <<<"$output")" = runner-lost ]
  [ "$(grep -c 'check-runs/78/annotations' "$GH_LOG")" -eq 1 ]
  [ "$(pr_view_calls)" -eq 2 ]
}

@test "wait: --until-merged settles on conflict after ready without waiting for the timeout" {  # ready のあとの競合は settled
  put_view 1 OPEN MERGEABLE "[$(actions_check build SUCCESS 11 77)]" h1
  put_view 2 OPEN CONFLICTING "[$(actions_check build SUCCESS 11 77)]" h1
  DEV_WORKFLOW_CI_WATCH_TIMEOUT=10 run --separate-stderr "$SCRIPT" wait o/r 5 --until-merged
  [ "$status" -eq 0 ]
  [ "$(jq -r .result <<<"$output")" = settled ]
  [ "$(jq -r .obs.state <<<"$output")" = conflict ]
  [ "$(pr_view_calls)" -eq 2 ]
}

@test "wait: prints timeout with the last observation when the limit passes" {  # 上限時間を超えたら timeout
  put_view 1 OPEN MERGEABLE "[$(actions_check build '' 11 77)]" h1
  DEV_WORKFLOW_CI_WATCH_TIMEOUT=3 run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .result <<<"$output")" = timeout ]
  [ "$(jq -r .obs.state <<<"$output")" = wait ]
}

@test "wait: prints error after five consecutive gh failures" {  # gh が 5 回続けて失敗したら error
  touch "${WORK}/view/fail"
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ "$output" = '{"result":"error","obs":null}' ]
  [ "$(pr_view_calls)" -eq 5 ]
  [ -n "$stderr" ]
}

@test "wait: does not touch the state directory" {  # 状態ファイルに触れない
  mkdir -p "$STATE_DIR"
  put_view 1 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" wait o/r 5
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$STATE_DIR")" ]
}

@test "wait: missing arguments exit non-zero with empty stdout" {  # 引数不足は非 0
  run --separate-stderr "$SCRIPT" wait o/r
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# ── next ──────────────────────────────────────────────────

@test "next: first sight decides from an empty state and writes the state file" {  # 初見で状態ファイルを作る
  put_view 1 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = fix ]
  [ -f "$(state_file)" ]
  [ "$(jq -r .fixes "$(state_file)")" = 1 ]
  [ "$(jq -r .head "$(state_file)")" = h1 ]
}

@test "next: reads the previous state and escalates on the third failure" {  # 前回の状態を読んで escalate
  mkdir -p "$STATE_DIR"
  echo '{"state":"ci-fail","head":"h1","fixes":2}' > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h2
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = escalate ]
  [ "$(jq -r .raised "$(state_file)")" = true ]
}

@test "next: passes --unrelated to observe and reruns" {  # --unrelated を observe に渡して rerun
  put_view 1 OPEN MERGEABLE "[$(actions_check flaky FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" next o/r 5 --unrelated flaky
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = rerun ]
  [ "$(jq -r '.obs.checks[0].cause' <<<"$output")" = unrelated ]
  [ "$(jq -r .reran_head "$(state_file)")" = h1 ]
}

@test "next: the first job-timeout is rerun without counting a fix" {  # 1 回目の打ち切りはやり直す
  put_view 1 OPEN MERGEABLE "[$(actions_check test CANCELLED 11 77)]" h1
  jq -cn --arg m "$TIMED_OUT" '[{message: $m}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = rerun ]
  [ "$(jq -r .reran_head "$(state_file)")" = h1 ]
  [ "$(jq -r .fixes "$(state_file)")" = null ]
}

@test "next: a job-timeout on a HEAD whose rerun is used up escalates" {  # やり直しを使い切った HEAD の打ち切りはオーナーに上げる
  mkdir -p "$STATE_DIR"
  echo '{"state":"wait","head":"h1","reran_head":"h1"}' > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check test CANCELLED 11 77)]" h1
  jq -cn --arg m "$TIMED_OUT" '[{message: $m}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = escalate ]
  [ "$(jq -r '.obs.checks[0].cause' <<<"$output")" = job-timeout ]
  [ "$(jq -r .raised "$(state_file)")" = true ]
  [ "$(jq -r .fixes "$(state_file)")" = null ]
}

@test "next: the same timed-out job after rerun is none and preserves the previous state" {
  mkdir -p "$STATE_DIR"
  local previous='{"state":"wait","head":"h1","reran_head":"h1","reran_jobs":["77"]}'
  echo "$previous" > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check test CANCELLED 11 77)]" h1
  jq -cn --arg m "$TIMED_OUT" '[{message: $m}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = none ]
  [ "$(jq -r .obs.state <<<"$output")" = ci-fail ]
  [ "$(jq -r .next.state <<<"$output")" = wait ]
  [ "$(jq -c .next <<<"$output")" = "$previous" ]
  [ "$(cat "$(state_file)")" = "$previous" ]
}

@test "next: a different timed-out job after rerun escalates without counting a fix" {
  mkdir -p "$STATE_DIR"
  echo '{"state":"wait","head":"h1","reran_head":"h1","reran_jobs":["76"]}' > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check test CANCELLED 11 77)]" h1
  jq -cn --arg m "$TIMED_OUT" '[{message: $m}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = escalate ]
  [ "$(jq -r .next.raised <<<"$output")" = true ]
  [ "$(jq -r .raised "$(state_file)")" = true ]
  jq -e 'has("fixes") | not' "$(state_file)"
}

@test "next: a cancel without the time-limit annotation is fix as before" {  # 上限時間の annotation が無い取り消しは直しに回る
  put_view 1 OPEN MERGEABLE "[$(actions_check test CANCELLED 11 77)]" h1
  jq -cn --arg c "$CANCELED" '[{message: $c}]' > "${WORK}/ann/77.json"
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = fix ]
  [ "$(jq -r '.obs.checks[0].cause' <<<"$output")" = real ]
}

@test "next: --after-fix reruns an unrelated failure on the same HEAD and keeps fixes" {  # 直しの担い手が関係ないと返したあと
  mkdir -p "$STATE_DIR"
  echo '{"state":"ci-fail","head":"h1","fixes":1}' > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check flaky FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" next o/r 5 --unrelated flaky --after-fix
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = rerun ]
  [ "$(jq -r .fixes "$(state_file)")" = 1 ]
  [ "$(jq -r .reran_head "$(state_file)")" = h1 ]
}

@test "next: without --after-fix the same failure on the same HEAD is none" {  # --after-fix なしは規則 3 で none
  mkdir -p "$STATE_DIR"
  echo '{"state":"ci-fail","head":"h1","fixes":1}' > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check flaky FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" next o/r 5 --unrelated flaky
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = none ]
}

@test "next: a gh failure leaves the state file unchanged" {  # gh の失敗で状態を書き換えない
  mkdir -p "$STATE_DIR"
  echo '{"fixes":1}' > "$(state_file)"
  touch "${WORK}/view/fail"
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$(cat "$(state_file)")" = '{"fixes":1}' ]
}

@test "next: an unreadable state file exits non-zero and is left as is" {  # 読めない状態ファイルで非 0
  mkdir -p "$STATE_DIR"
  echo 'not json' > "$(state_file)"
  put_view 1 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$(cat "$(state_file)")" = 'not json' ]
}

@test "next: does not run the move itself (no gh run rerun)" {  # 一手を実行しない
  put_view 1 OPEN MERGEABLE "[$(actions_check flaky FAILURE 11 77)]" h1
  run --separate-stderr "$SCRIPT" next o/r 5 --unrelated flaky
  [ "$status" -eq 0 ]
  [ "$(jq -r .act <<<"$output")" = rerun ]
  ! grep -q '^run rerun' "$GH_LOG" || return 1
}

@test "next: state directory defaults under XDG_STATE_HOME" {  # 状態ディレクトリの既定
  unset DEV_WORKFLOW_PR_STATE_DIR
  put_view 1 OPEN MERGEABLE "[$(actions_check build FAILURE 11 77)]" h1
  XDG_STATE_HOME="${WORK}/xdg" run --separate-stderr "$SCRIPT" next o/r 5
  [ "$status" -eq 0 ]
  [ -f "${WORK}/xdg/dev-workflow/pr-state/o__r__5.json" ]
}

# ── references/ci-watch.md ────────────────────────────────

@test "reference: names the words of the watch procedure" {  # spec の語が現れる
  [ -f "$REF" ]
  for w in run_in_background 'ci-watch.sh wait' 'ci-watch.sh next' '--unrelated' '--after-fix' 'gh run rerun' \
           '--log-failed' 'agent-review:passed' 'gh pr ready --undo' '--until-merged'; do
    grep -qF -- "$w" "$REF" || { echo "missing: $w"; return 1; }
  done
}

@test "reference: only the main session waits, citing subagent-waiting.md" {  # 待つのは本体だけ
  grep -q '見張りを始めるのは本体（メインセッション）だけ' "$REF"
  grep -q 'サブエージェントは見張りを始めない' "$REF"
  grep -qF 'references/subagent-waiting.md' "$REF"
}

@test "reference: the LLM never merges" {  # gh pr merge を叩かない
  grep -qF 'LLM が `gh pr merge` や merge API を叩いてはならない' "$REF"
}

@test "reference: --unrelated has a scope paragraph (3 inputs, 2 errors, allowed misses, not a completion condition)" {
  grep -q '守備範囲: この判断が受け取る入力は' "$REF"
  grep -qF 'gh run view --log-failed' "$REF"
  grep -qF 'gh pr diff --name-only' "$REF"
  grep -q '拾いたい誤りは' "$REF"
  grep -q '誤った一手のまま通ることを許す' "$REF"
  grep -q 'これらの穴を塞ぎ切ることはこの要件の完了条件にしない' "$REF"
}

@test "reference: next none/rerun-failure judgement has a scope paragraph" {
  grep -q '守備範囲: この判断（`next.state` が `wait` の `none`' "$REF"
  grep -qF '`gh run rerun` の終了コードの 2 つ' "$REF"
  grep -qF 'GitHub の反映遅れで実際は進行中なのに連続 3 回' "$REF"
  grep -q 'これらの穴を塞ぎ切ることはこの手順の完了条件にしない' "$REF"
}

@test "reference: ready checks the four merge-blocking labels and until-merged timeout asks for the merge" {
  for l in human-merge needs-human-merge human-only needs-approval; do
    grep -qF -- "\`$l\`" "$REF" || { echo "missing label: $l"; return 1; }
  done
  grep -q '待たずに PR の URL を添えてオーナーにマージを頼み' "$REF"
  grep -q '`--until-merged` を付けて起動した `wait` なら、マージされなかったとして' "$REF"
}

@test "reference: none restarts wait for pending CI or a stale rerun failure with a caller limit" {
  local row
  row="$(grep -F '| `none` |' "$REF")"
  grep -qF '`obs.state` が `wait` のときは `wait` を起動し直す' <<<"$row"
  grep -qF '`obs.state` が `ci-fail` でも `next.state`（状態ファイルの `state`）が `wait`' <<<"$row"
  grep -qF '続けて 3 回この `none` で `wait` を起動し直しても決着しなければ' <<<"$row"
  grep -qF '呼び出し側' <<<"$row"
  grep -qF '状態ファイルや `pr-state.sh` の判定は増やさない' <<<"$row"
  grep -q 'それ以外の `none`.*見張りを終え、PR の URL を添えてオーナーに' "$REF"
}

@test "reference: rerun errors comment and escalate including the epic child stop" {
  local row
  row="$(grep -F '| `rerun` |' "$REF")"
  grep -qF 'やり直しに失敗したら、`wait` を起動し直さず' <<<"$row"
  grep -qF 'PR にコメントして `needs-approval` を付け' <<<"$row"
  grep -qF 'オーナーに上げて見張りを終える' <<<"$row"
  grep -qF 'エピックの子の止まり方も `escalate` と同じ' <<<"$row"
}

@test "reference: one session per PR via start/end comments, clearing raised, and no re-check after a fix" {
  grep -qF 'CI 見張り開始:' "$REF"
  grep -qF 'CI 見張り終了:' "$REF"
  grep -q 'ほかのセッションが見張り中として始めず' "$REF"
  grep -q '`raised` を消すだけで済ませない' "$REF"
  grep -q '同じセッションが `fix` の直しのあとに `wait` から始め直すときは、開始の判定も開始のコメントもしない' "$REF"
  grep -q '直しの担い手に渡すときも、終了のコメントは投稿しない' "$REF"
}

@test "reference: after a fix push the watch resumes with passed removed and the gate is re-run only at ready" {
  grep -q '`agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直し' "$REF"
  grep -q 'ゲートの取り直しは `ready` になってから行う' "$REF"
  grep -q 'push のあとすぐにはゲートを取り直さない' "$REF"
  grep -q '`agent-review:pending` が付いている.*先にゲートを取り直す' "$REF"
  grep -q '合格するまで.*マージ待ち・マージ依頼.*に進まない' "$REF"
}

@test "reference: resuming checks the unfinished move and runs the owner's instruction after escalate" {
  grep -q '中断した一手が済んでいるかを確かめる' "$REF"
  grep -q '`next` を呼ばずに.*実装者への修正依頼から再開する' "$REF"
  grep -q '`escalate` のあと.*オーナーの具体的な指示.*を先に実行してから' "$REF"
}

@test "reference: a --until-merged wait that settles on ci-fail or conflict goes to next" {
  grep -q '`--until-merged` の `wait` も `ci-fail`・`conflict` では `settled` を返す' "$REF"
}

@test "reference: passed removal and gate re-run are limited to PRs that had agent-review:passed" {
  grep -q '`agent-review:passed` が付いていた PR のとき' "$REF"
  grep -q '`agent-review:passed` を外した PR' "$REF"
  grep -q '`ready` を受けたあとの扱いは呼び出し側が決める' "$REF"
}

@test "reference: an implementer's unrelated verdict leads to one next --unrelated --after-fix" {
  grep -qF '`next --unrelated <チェック名> --after-fix` を 1 回だけ実行' "$REF"
}

@test "reference: escalate with a job-timeout tells the owner to check the runner and asks no fix" {  # 打ち切りの伝え方
  local row
  row="$(grep -F '| `escalate` |' "$REF")"
  [ -n "$row" ]
  grep -qF 'job-timeout' <<<"$row"
  grep -qF '上限時間で打ち切られた' <<<"$row"
  grep -qF 'ランナーの状態を確かめてほしい' <<<"$row"
  grep -qF '実装者に直しを頼まない' <<<"$row"
}

@test "reference: escalate points an epic child to the stop record without copying the HEAD rule" {  # エピックの子は停止の記録の正本を指すだけ
  local row
  row="$(grep -F '| `escalate` |' "$REF")"
  [ -n "$row" ]
  grep -qF 'エピックの子' <<<"$row"
  grep -qF '`skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まる' <<<"$row"
  ! grep -qF '先頭 7 文字' <<<"$row" || return 1
  ! grep -qF 'obs.head' <<<"$row" || return 1
  ! grep -qF 'headRefOid' <<<"$row" || return 1
}

@test "reference: a non-wait none points an epic child to the stop record without copying the HEAD rule" {  # 同じ HEAD で再び落ちた none でも停止の記録を残す
  local row
  row="$(grep -F '| `none` |' "$REF")"
  [ -n "$row" ]
  grep -qF 'エピックの子' <<<"$row"
  grep -qF '`skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まる' <<<"$row"
  ! grep -qF '先頭 7 文字' <<<"$row" || return 1
  ! grep -qF 'obs.head' <<<"$row" || return 1
  ! grep -qF 'headRefOid' <<<"$row" || return 1
}

@test "reference: job-timeout is outside the --unrelated judgement and differs from the wait timeout" {  # --unrelated の対象外・見張りの timeout とは別
  grep -qF '`job-timeout`（ジョブが上限時間で打ち切られた）のチェックはこの判断の対象でない' "$REF"
  grep -qF '`job-timeout` は CI のジョブが自分の上限時間で打ち切られたことで、4 の表の `timeout`（見張りの上限時間内に決着を見られなかった）とは別の出来事' "$REF"
}

# 節の外に同じ語があっても再開の契約の証拠にはしない。
resume_section() {
  sed -n '/^## 9\./,/^## 10\./p' "$REF" | sed '/^## 10\./d'
}

@test "reference: resume section identifies its own wait notification and excludes TaskStop" {
  local section word
  section="$(resume_section)"
  [ -n "$section" ]
  for word in stopped killed run_in_background 'ci-watch.sh wait' '--until-merged' \
              'task id' 'tool-use id' '自分の会話' 'TaskStop' '対象外'; do
    grep -qF -- "$word" <<<"$section" || { echo "missing: $word"; return 1; }
  done
}

@test "reference: resume runs next without asking on the first turn from any input" {
  local section word
  section="$(resume_section)"
  for word in '主やオーナーに' '聞き返さず' '最初のターン' '通知そのもの' '親の返事' '主の入力' \
              'ci-watch.sh next <owner/repo> <PR番号>' '`--unrelated` なし' '6 の表' '#1084'; do
    grep -qF -- "$word" <<<"$section" || { echo "missing: $word"; return 1; }
  done
}

@test "reference: resume checks all comment pages and ends settled watches" {
  local section word
  section="$(resume_section)"
  for word in 'gh pr view' 'gh api --paginate' '全ページ' '1 行目' '最新の' \
              'CI 見張り開始:' 'CI 見張り終了:' 'open' '無いときだけ再開' \
              '終了のコメントがあれば何もしない' 'merged' 'closed' '投稿' '終えた理由' 'マージを報告'; do
    grep -qF -- "$word" <<<"$section" || { echo "missing: $word"; return 1; }
  done
}

@test "reference: resume states the inputs errors and accepted gaps of its decision" {
  local scope word
  scope="$(resume_section | sed -n '/^守備範囲:/p')"
  [ -n "$scope" ]
  for word in '通知' 'PR の状態' '全ページ' '3 つ' '二重の修正' '数え落とし' '放置' \
              '別のセッション' '重なる' '消したり書き換えたり' '通知が届かない' '/clear' \
              '通ることを許す' '完了条件にしない'; do
    grep -qF -- "$word" <<<"$scope" || { echo "missing: $word"; return 1; }
  done
}

@test "reference: resume continues the same watch and section 2 points to section 9" {
  local section start
  section="$(resume_section)"
  grep -qF '2 の開始の判定も開始のコメントもしない' <<<"$section"
  grep -qF '同じ見張りの続き' <<<"$section"
  start="$(sed -n '/^## 2\./,/^## 3\./p' "$REF")"
  grep -q '通知を受けていない別のセッション' <<<"$start"
  grep -q 'stopped.*killed.*9 に従う.*オーナーの指示を待たない' <<<"$start"
}

@test "develop skill: resume notification points to section 9 without copying the decision" {
  local row
  row="$(grep 'stopped.*killed' "$DEVELOP")"
  [ "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" -eq 1 ]
  grep -qF 'references/ci-watch.md' <<<"$row"
  grep -qF '9 に従う' <<<"$row"
  ! grep -qE 'CI 見張り終了:|gh pr view|--paginate|ci-watch.sh next' "$DEVELOP" || return 1
}

# ── pr-review-gate / develop / gate-runner ────────────────

@test "gate skill: run_in_background sits after the step-5 check and before the step-6 heading" {
  local after before lines l
  # 手順 5 は stages/pass.md、手順 6 は stages/hold.md に分かれた。pass.md の中で手順 5 の実測確認より後、
  # 手順 5 の後ろの節（G として動くとき）より前にあること、手順 6 の見出しが hold.md にあることで見る
  grep -q '^### 6\. 保留処理' "$HOLD"
  local pass_core="${PLUGIN_DIR}/skills/pr-review-gate/stages/pass.md"
  after="$(grep -n '最後の実測確認は次の' "$pass_core" | head -1 | cut -d: -f1)"
  before="$(grep -n '^## G として動くとき' "$pass_core" | head -1 | cut -d: -f1)"
  [ -n "$after" ] && [ -n "$before" ]
  lines="$(grep -n 'run_in_background' "$pass_core" | cut -d: -f1)"
  [ -n "$lines" ]
  for l in $lines; do
    [ "$l" -gt "$after" ] && [ "$l" -lt "$before" ] || { echo "line $l out of range ($after, $before)"; return 1; }
  done
}

@test "gate skill: refers to references/ci-watch.md and a subagent returns passed without watching" {
  grep -qF 'references/ci-watch.md' "$PASS_STAGE"
  grep -q 'サブエージェント.*見張りを始めずに `passed` を return' "$PASS_STAGE"
  grep -q '直しで commit が積まれたら.*`ready`.*手順 1 から' "$PASS_STAGE"
  grep -q '合格するまでマージ待ち・マージ依頼に進まない' "$PASS_STAGE"
}

@test "develop skill: (4) hands passed to the main session's watch and loops fix through W and G" {
  grep -qF 'references/ci-watch.md' "$DEVELOP"
  grep -q 'passed → 本体が .*ci-watch.md.*見張りを始める' "$DEVELOP"
  grep -q '`fix` なら W に直させ' "$DEVELOP"
  grep -q 'W が push したら.*passed を外したまま.*`wait` → `next` を続け' "$DEVELOP"
  grep -q '`ready` になってから前提確認と重さ判定の G を新しく起こして.*取り直させ' "$DEVELOP"
}

@test "gate-runner: G returns passed without starting the CI watch" {
  grep -q 'G は CI の見張りを始めずに `passed` を return する' "$PASS_STAGE"
}
