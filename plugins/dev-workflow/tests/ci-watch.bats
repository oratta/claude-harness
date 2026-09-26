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

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/ci-watch.sh"
  REF="${PLUGIN_DIR}/references/ci-watch.md"
  GATE_SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
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
           '--log-failed' 'agent-review:passed' 'gh pr ready --undo' '--until-merged' CLAUDE_HARNESS_DEV_DIR; do
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

@test "reference: ready checks the four merge-blocking labels and until-merged timeout asks for the merge" {
  for l in human-merge needs-human-merge human-only needs-approval; do
    grep -qF -- "\`$l\`" "$REF" || { echo "missing label: $l"; return 1; }
  done
  grep -q '待たずに PR の URL を添えてオーナーにマージを頼み' "$REF"
  grep -q '`--until-merged` を付けて起動した `wait` なら、マージされなかったとして' "$REF"
}

@test "reference: none restarts wait only when obs.state is wait" {  # none で起動し直すのは wait のときだけ
  grep -q '`obs.state` が `wait` のときだけ `wait` を起動し直す' "$REF"
  grep -q 'それ以外の `none`.*見張りを終え、PR の URL を添えてオーナーに' "$REF"
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

# ── pr-review-gate / develop / gate-runner ────────────────

@test "gate skill: run_in_background sits after the step-5 check and before the step-6 heading" {
  local after before lines l
  after="$(grep -n '最後の実測確認は次の' "$GATE_SKILL" | head -1 | cut -d: -f1)"
  before="$(grep -n '^### 6\. 保留処理' "$GATE_SKILL" | head -1 | cut -d: -f1)"
  [ -n "$after" ] && [ -n "$before" ]
  lines="$(grep -n 'run_in_background' "$GATE_SKILL" | cut -d: -f1)"
  [ -n "$lines" ]
  for l in $lines; do
    [ "$l" -gt "$after" ] && [ "$l" -lt "$before" ] || { echo "line $l out of range ($after, $before)"; return 1; }
  done
}

@test "gate skill: refers to references/ci-watch.md and a subagent returns passed without watching" {
  grep -qF 'references/ci-watch.md' "$GATE_SKILL"
  grep -q 'サブエージェント.*見張りを始めずに `passed` を return' "$GATE_SKILL"
  grep -q '直しで commit が積まれたら.*`ready`.*手順 1 から' "$GATE_SKILL"
  grep -q '合格するまでマージ待ち・マージ依頼に進まない' "$GATE_SKILL"
}

@test "develop skill: (4) hands passed to the main session's watch and loops fix through W and G" {
  grep -qF 'references/ci-watch.md' "$DEVELOP"
  grep -q 'passed → 本体が .*ci-watch.md.*見張りを始める' "$DEVELOP"
  grep -q '`fix` なら W に直させ' "$DEVELOP"
  grep -q 'W が push したら.*passed を外したまま.*`wait` → `next` を続け' "$DEVELOP"
  grep -q '`ready` になってから G を.*取り直させ' "$DEVELOP"
}

@test "gate-runner: G returns passed without starting the CI watch" {
  grep -q 'G は CI の見張りを始めずに `passed` を return する' "$GATE_RUNNER"
}
