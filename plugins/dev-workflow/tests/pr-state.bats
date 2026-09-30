#!/usr/bin/env bats
#
# pr-state.sh: PR の状態（conflict / ci-fail / ready / wait）の分類と、前回の状態から
# 次の一手（none / ready / rerun / fix / escalate）を決める。observe / decide は gh を呼ばず、
# annotations だけが落ちた Actions のジョブの annotation を gh api で取る。
#
# flatmate の scripts/test-pending-pr-merge-wait.sh の (K)(N) から移したケースは、
# テスト名の先頭に元のケース名を書く（移し方は tasks.md 2.1）。
#
# spec: openspec/changes/pr-state-classifier（dev-workflow-pr-state）

LOST='The self-hosted runner lost communication with the server.'

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/pr-state.sh"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  GH_LOG="${WORK}/gh.log"
  mkdir -p "${WORK}/bin" "${WORK}/gh"
  # gh の偽物: 呼び出しを記録し、check-runs/<job>/annotations には gh/<job>.json を返す。
  # gh/<job>.fail があれば非 0 で終わる
  cat > "${WORK}/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${GH_LOG}"
job="\$(printf '%s' "\$*" | sed -nE 's#.*check-runs/([0-9]+)/annotations.*#\1#p')"
[ -n "\$job" ] || exit 1
[ -e "${WORK}/gh/\${job}.fail" ] && { echo "gh: HTTP 502" >&2; exit 1; }
cat "${WORK}/gh/\${job}.json" 2>/dev/null || echo '[]'
EOF
  chmod +x "${WORK}/bin/gh"
  export PATH="${WORK}/bin:${PATH}"
  PREV='{}'
  ACT=''
}

teardown() {
  rm -rf "$WORK"
}

# gh pr view の JSON: $1=mergeable $2=statusCheckRollup の配列 $3=headRefOid
view() {
  jq -cn --arg m "$1" --argjson c "$2" --arg h "$3" '{mergeable: $m, statusCheckRollup: $c, headRefOid: $h}'
}

# Actions のチェック: $1=名前 $2=conclusion $3=run $4=job
actions_check() {
  jq -cn --arg n "$1" --arg c "$2" --arg u "https://github.com/o/r/actions/runs/$3/job/$4" \
    '{name: $n, conclusion: $c, detailsUrl: $u}'
}

observe_of() {
  printf '%s' "$1" | "$SCRIPT" observe "${@:2}"
}

decide_of() {
  printf '%s' "$1" | "$SCRIPT" decide "${@:2}"
}

# 観測 $1（observe の出力）を前回の状態 $PREV で decide し、ACT と PREV（= next）を進める
step() {
  local out
  out="$(printf '%s' "$1" | "$SCRIPT" decide "$PREV")" || return 1
  ACT="$(jq -r .act <<<"$out")"
  PREV="$(jq -c .next <<<"$out")"
}

# gh pr view の JSON $1 を observe（$2 以降はその引数）してから step する
watch() {
  local obs
  obs="$(observe_of "$@")" || return 1
  step "$obs"
}

# decide 用の観測を直接作る: $1=state $2=head $3=retry（省略時 false）
obs() {
  jq -cn --arg s "$1" --arg h "$2" --argjson r "${3:-false}" \
    '{head: $h, state: $s, failed: [], runs: [], checks: [], retry: $r}'
}

no_gh_called() {
  [ ! -e "$GH_LOG" ]
}

# ── observe: 分類（flatmate (K)(N) から移す）─────────────────────────

@test "K2: conflict wins over failed checks" {  # K2: コンフリクトはチェックより先に conflict
  run observe_of "$(view CONFLICTING "[$(actions_check test FAILURE 1 2)]" h)"
  [ "$status" -eq 0 ]
  [ "$(jq -r .state <<<"$output")" = conflict ]
  no_gh_called
}

@test "K3: a failure without name or URL is ci-fail named ?" {  # K3: 名前も URL も無い失敗は ci-fail で名前は ?
  run observe_of "$(view MERGEABLE '[{"conclusion":"FAILURE"}]' h)"
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.state, .failed, .runs]' <<<"$output")" = '["ci-fail",["?"],[]]' ]
}

@test "K4: a PENDING check means wait" {  # K4: state が PENDING のチェックがあれば wait
  run observe_of "$(view MERGEABLE '[{"state":"PENDING"}]' h)"
  [ "$(jq -r .state <<<"$output")" = wait ]
}

@test "K5: only SUCCESS and NEUTRAL on MERGEABLE is ready" {  # K5: 成功と中立だけの MERGEABLE は ready
  run observe_of "$(view MERGEABLE '[{"conclusion":"SUCCESS"},{"conclusion":"NEUTRAL"}]' h)"
  [ "$(jq -r .state <<<"$output")" = ready ]
}

@test "observe: SKIPPED counts as success and UNKNOWN mergeable is wait" {  # observe: SKIPPED も成功、UNKNOWN の mergeable は wait
  run observe_of "$(view MERGEABLE '[{"conclusion":"SKIPPED"}]' h)"
  [ "$(jq -r .state <<<"$output")" = ready ]
  run observe_of "$(view UNKNOWN '[{"conclusion":"SUCCESS"}]' h)"
  [ "$(jq -r .state <<<"$output")" = wait ]
}

@test "Nb1: an in-progress check means wait and decide does nothing" {  # Nb1: 実行中のチェックがあれば wait
  run observe_of "$(view MERGEABLE '[{"name":"test","status":"IN_PROGRESS","detailsUrl":"https://github.com/o/r/actions/runs/551/job/1"}]' b1)"
  [ "$(jq -r .state <<<"$output")" = wait ]
  step "$output"
  [ "$ACT" = none ]
  no_gh_called
}

@test "Nb2: a pending check without URL is never ready" {  # Nb2: URL の無い未確定のチェックもマージ可能にしない
  run observe_of "$(view MERGEABLE '[{"context":"ext/ci","state":"PENDING"},{"name":"ok","conclusion":"SUCCESS"}]' b1)"
  [ "$(jq -r .state <<<"$output")" = wait ]
}

@test "observe: a failure reports its name, run ID and job" {  # observe: 失敗は落ちたチェック名と run ID と job を返す
  run observe_of "$(view MERGEABLE "[$(actions_check test FAILURE 555 9),$(actions_check lint SUCCESS 555 10)]" h1)"
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.head, .state, .failed, .runs]' <<<"$output")" = '["h1","ci-fail",["test"],["555"]]' ]
  [ "$(jq -c '.checks' <<<"$output")" = '[{"name":"test","run":"555","job":"9","cause":"real"}]' ]
}

@test "Ng1 (classify): a non-Actions failure has no run ID and no job" {  # Ng1 の分類: Actions 以外の失敗は run ID も job も持たない
  run observe_of "$(view MERGEABLE '[{"context":"ext/ci","state":"FAILURE","targetUrl":"https://ci.example.com/1"}]' g1)"
  [ "$(jq -c '[.state, .failed, .runs, .checks[0].run, .checks[0].job]' <<<"$output")" = '["ci-fail",["ext/ci"],[],null,null]' ]
}

@test "observe: an unknown conclusion is a failure" {  # observe: 知らない結論は失敗
  run observe_of "$(view MERGEABLE '[{"name":"a","conclusion":"STARTUP_FAILURE"},{"name":"b","conclusion":"WHATEVER"},{"name":"c","conclusion":"SUCCESS"}]' h)"
  [ "$(jq -c '[.state, .failed]' <<<"$output")" = '["ci-fail",["a","b"]]' ]
}

@test "observe: tabs, newlines and commas in names become spaces and names are unique" {  # observe: 名前のタブ・改行・カンマは空白にし、重複は 1 つにする
  run observe_of "$(view MERGEABLE '[{"name":"a\tb,c\nd","conclusion":"FAILURE"},{"name":"a\tb,c\nd","conclusion":"FAILURE"}]' h)"
  [ "$(jq -c .failed <<<"$output")" = '["a b c d"]' ]
}

@test "observe: prints a single line" {  # observe: 出力は 1 行
  run observe_of "$(view MERGEABLE "[$(actions_check test FAILURE 1 2)]" h)"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "observe: unreadable input prints nothing and exits non-zero" {  # observe: 読めない入力は標準出力が空で非 0
  run bash -c "printf 'not json' | '$SCRIPT' observe 2>/dev/null"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  run bash -c "printf '[1,2]' | '$SCRIPT' observe 2>/dev/null"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# ── observe: やり直しに当たるかの仕分け ─────────────────────────────

@test "observe: a runner-lost annotation makes the check retryable" {  # observe: 通信切れの annotation はやり直しに当たる
  jq -cn --arg m "$LOST" '{annotations_by_job: {"77": ["Process completed with exit code 1.", $m]}}' > "${WORK}/hints.json"
  run observe_of "$(view MERGEABLE "[$(actions_check build FAILURE 700 77)]" h)" --hints "${WORK}/hints.json"
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.checks[0].cause, .retry]' <<<"$output")" = '["runner-lost",true]' ]
  no_gh_called
}

@test "observe: a check passed with --unrelated is retryable" {  # observe: --unrelated で渡した失敗はやり直しに当たる
  run observe_of "$(view MERGEABLE "[$(actions_check e2e FAILURE 700 5)]" h)" --unrelated e2e
  [ "$(jq -c '[.checks[0].cause, .retry]' <<<"$output")" = '["unrelated",true]' ]
}

@test "observe: --unrelated can be given more than once" {  # observe: --unrelated は複数回指定できる
  run observe_of "$(view MERGEABLE "[$(actions_check e2e FAILURE 700 5),$(actions_check smoke FAILURE 701 6)]" h)" --unrelated e2e --unrelated smoke
  [ "$(jq -c '[.checks[].cause, .retry]' <<<"$output")" = '["unrelated","unrelated",true]' ]
}

@test "observe: one real failure among retryable ones means fix" {  # observe: 本当の失敗が 1 件でも混ざれば直しに回す
  jq -cn --arg m "$LOST" '{annotations_by_job: {"77": [$m]}}' > "${WORK}/hints.json"
  run observe_of "$(view MERGEABLE "[$(actions_check build FAILURE 700 77),$(actions_check lint FAILURE 700 78)]" h)" --hints "${WORK}/hints.json"
  [ "$(jq -c '[(.checks[] | select(.name == "lint") | .cause), .retry]' <<<"$output")" = '["real",false]' ]
}

@test "observe: a runner-lost hint does not leak to a same-named check in another job" {  # observe: 同名チェックの通信切れを別のジョブに移さない
  jq -cn --arg m "$LOST" '{annotations_by_job: {"77": [$m]}}' > "${WORK}/hints.json"
  run observe_of "$(view MERGEABLE "[$(actions_check test FAILURE 700 77),$(actions_check test FAILURE 800 88)]" h)" --hints "${WORK}/hints.json"
  [ "$(jq -c '[(.checks[] | select(.job == "77") | .cause), (.checks[] | select(.job == "88") | .cause), .retry]' <<<"$output")" = '["runner-lost","real",false]' ]
  [ "$(jq -c .failed <<<"$output")" = '["test"]' ]
}

@test "observe: without hints every failure is real and retry is false" {  # observe: 手がかりが無ければやり直さない
  run observe_of "$(view MERGEABLE "[$(actions_check test FAILURE 555 9)]" h)"
  [ "$(jq -c '[([.checks[].cause] | unique), .retry]' <<<"$output")" = '[["real"],false]' ]
}

@test "observe: no run ID means no retry even with --unrelated" {  # observe: run ID が無ければ --unrelated でもやり直さない
  run observe_of "$(view MERGEABLE '[{"context":"ext/ci","state":"FAILURE","targetUrl":"https://ci.example.com/1"}]' h)" --unrelated ext/ci
  [ "$(jq -c '[.checks[0].cause, .retry]' <<<"$output")" = '["unrelated",false]' ]
}

@test "observe: retry is false on conflict even with hints" {  # observe: コンフリクトのときは手がかりがあっても retry は false
  run observe_of "$(view CONFLICTING "[$(actions_check e2e FAILURE 700 5)]" h)" --unrelated e2e
  [ "$(jq -c '[.state, .retry]' <<<"$output")" = '["conflict",false]' ]
}

@test "observe: an unreadable or non-JSON --hints file exits non-zero" {  # observe: --hints が読めない・JSON でないときは非 0
  run observe_of "$(view MERGEABLE '[]' h)" --hints "${WORK}/missing.json"
  [ "$status" -ne 0 ]
  printf 'not json' > "${WORK}/bad.json"
  run observe_of "$(view MERGEABLE '[]' h)" --hints "${WORK}/bad.json"
  [ "$status" -ne 0 ]
}

# ── decide: flatmate (N) から移す ───────────────────────────────

@test "Na1-Na3: conflict is fix and the same state again is none with fixes still 1" {  # Na1〜Na3: コンフリクトは fix、同じ状態の 2 回目は none で fixes は 1 のまま
  watch "$(view CONFLICTING '[]' h1)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 1 ]
  watch "$(view CONFLICTING '[]' h1)"
  [ "$ACT" = none ]
  [ "$(jq -r .fixes <<<"$PREV")" = 1 ]
  no_gh_called
}

@test "Nc1-Nc3: mergeable is ready every time" {  # Nc1〜Nc3: マージ可能は毎回 ready
  watch "$(view MERGEABLE '[{"name":"test","conclusion":"SUCCESS"}]' c1)"
  [ "$ACT" = ready ]
  watch "$(view MERGEABLE '[{"name":"test","conclusion":"SUCCESS"}]' c1)"
  [ "$ACT" = ready ]
}

@test "Nd1-Nd3: fix, fix, escalate across new heads, then none" {  # Nd1〜Nd3: HEAD を変えて fix → fix → escalate、上げたあとは none
  watch "$(view CONFLICTING '[]' d1)"
  [ "$ACT" = fix ]
  watch "$(view CONFLICTING '[]' d2)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 2 ]
  watch "$(view CONFLICTING '[]' d3)"
  [ "$ACT" = escalate ]
  [ "$(jq -r .raised <<<"$PREV")" = true ]
  watch "$(view CONFLICTING '[]' d4)"
  [ "$ACT" = none ]
}

@test "Ne1-Ne2 (changed): an Actions failure without hints is fix at once, none on the same head" {  # Ne1・Ne2（期待値を変更）: 手がかりの無い Actions の失敗は 1 回目から fix、同じ HEAD の 2 回目は none
  local v
  v="$(view MERGEABLE "[$(actions_check test FAILURE 555 1)]" e1)"
  watch "$v"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 1 ]
  watch "$v"
  [ "$ACT" = none ]
  no_gh_called
}

@test "Ne1-Ne2 (runner-lost hint): rerun first, then fix on the same head" {  # Ne1・Ne2（通信切れの手がかりつき）: 1 回目は rerun、同じ HEAD でまた落ちたら fix
  local v
  v="$(view MERGEABLE "[$(actions_check test FAILURE 555 1)]" e1)"
  jq -cn --arg m "$LOST" '{annotations_by_job: {"1": [$m]}}' > "${WORK}/hints.json"
  watch "$v" --hints "${WORK}/hints.json"
  [ "$ACT" = rerun ]
  watch "$v" --hints "${WORK}/hints.json"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 1 ]
}

@test "Nf1-Nf2 decide part (changed): first failure without hints is fix" {  # Nf1・Nf2 の decide 部分（期待値を変更）: 手がかり無しの 1 回目は fix
  watch "$(view MERGEABLE "[$(actions_check lint FAILURE 556 1)]" f1)"
  [ "$ACT" = fix ]
}

@test "Ng1: a non-Actions failure is fix, not rerun" {  # Ng1: Actions 以外の失敗は rerun せず fix
  watch "$(view MERGEABLE '[{"context":"ext/ci","state":"FAILURE","targetUrl":"https://ci.example.com/1"}]' g1)" --unrelated ext/ci
  [ "$ACT" = fix ]
}

@test "Nj1-Nj2: with state and head removed the same head stopping again is fix with fixes 2" {  # Nj1・Nj2: state と head を消した状態で同じ HEAD がまた止まれば fix で fixes 2
  watch "$(view CONFLICTING '[]' j1)"
  [ "$ACT" = fix ]
  # 住人の done failed: 状態名と head を消して修正回数は残す
  PREV="$(jq -c 'del(.state, .head) + {last_done: "failed"}' <<<"$PREV")"
  watch "$(view CONFLICTING '[]' j1)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 2 ]
}

@test "Nl1-Nl3: after two failed fixes the third is escalate and the fourth none" {  # Nl1〜Nl3: 2 回失敗後の 3 回目は escalate、4 回目は none
  watch "$(view CONFLICTING '[]' l1)"
  [ "$ACT" = fix ]
  PREV="$(jq -c 'del(.state, .head) + {last_done: "failed"}' <<<"$PREV")"
  watch "$(view CONFLICTING '[]' l1)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 2 ]
  PREV="$(jq -c 'del(.state, .head) + {last_done: "failed"}' <<<"$PREV")"
  watch "$(view CONFLICTING '[]' l1)"
  [ "$ACT" = escalate ]
  [ "$(jq -r .raised <<<"$PREV")" = true ]
  watch "$(view CONFLICTING '[]' l1)"
  [ "$ACT" = none ]
}

# ── decide: 足すケース ────────────────────────────────────────

@test "decide: two failures on the same head rerun only once" {  # decide: 同じ HEAD で 2 回落ちてもやり直しは 1 回
  step "$(obs ci-fail e1 true)"
  [ "$ACT" = rerun ]
  [ "$(jq -c '[.state, .reran_head]' <<<"$PREV")" = '["wait","e1"]' ]
  step "$(obs ci-fail e1 true)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 1 ]
  no_gh_called
}

@test "decide: a new head restores the rerun but keeps fixes" {  # decide: HEAD が変わればやり直しの権利が戻り、修正回数は戻らない
  PREV='{"state":"ci-fail","head":"e1","reran_head":"e1","fixes":1}'
  step "$(obs ci-fail e2 true)"
  [ "$ACT" = rerun ]
  [ "$(jq -c '[.reran_head, .fixes]' <<<"$PREV")" = '["e2",1]' ]
}

@test "decide: ci-fail is fixed twice across heads and escalated the third time" {  # decide: CI 失敗を HEAD を変えて直すのは 2 回まで、3 回目は escalate
  step "$(obs ci-fail d1)"
  [ "$ACT" = fix ]
  step "$(obs ci-fail d2)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 2 ]
  step "$(obs ci-fail d3)"
  [ "$ACT" = escalate ]
  [ "$(jq -r .raised <<<"$PREV")" = true ]
}

@test "decide: once raised, even a retryable failure is none" {  # decide: 上げ済みなら retry があっても none
  PREV='{"state":"conflict","head":"x1","fixes":2,"raised":true}'
  step "$(obs ci-fail x2 true)"
  [ "$ACT" = none ]
}

@test "decide: a wait in between does not reset fixes (flatmate#899)" {  # decide: UNKNOWN を挟んでも修正回数が戻らない（flatmate#899）
  local acts=''
  for s in conflict wait conflict wait conflict; do
    step "$(obs "$s" h1)"
    acts="${acts}${ACT} "
  done
  [ "$acts" = "fix none none none none " ]
  [ "$(jq -r .fixes <<<"$PREV")" = 1 ]
  [ "$(jq -r .state <<<"$PREV")" = conflict ]
}

@test "decide: wait after a new head records state wait and the next stop is fix" {  # decide: HEAD が変わったあとの wait は状態名を wait にし、次の止まりは fix
  PREV='{"state":"conflict","head":"h1","fixes":1}'
  step "$(obs wait h2)"
  [ "$ACT" = none ]
  [ "$(jq -c '[.state, .head]' <<<"$PREV")" = '["wait","h2"]' ]
  step "$(obs conflict h2)"
  [ "$ACT" = fix ]
  [ "$(jq -r .fixes <<<"$PREV")" = 2 ]
}

@test "decide: omitted, null and {} previous state are a first sight" {  # decide: 前回の状態が省略・null・{} なら初見
  run decide_of "$(obs conflict h1)"
  [ "$(jq -c '[.act, .next.fixes]' <<<"$output")" = '["fix",1]' ]
  run decide_of "$(obs conflict h1)" null
  [ "$(jq -c '[.act, .next.fixes]' <<<"$output")" = '["fix",1]' ]
  run decide_of "$(obs conflict h1)" '{}'
  [ "$(jq -c '[.act, .next.fixes]' <<<"$output")" = '["fix",1]' ]
}

@test "decide: keeps unknown keys and echoes the observation" {  # decide: 知らないキーを引き継ぎ、obs は観測をそのまま返す
  local o
  o="$(obs conflict h1)"
  run decide_of "$o" '{"fixes":1,"last_done":"failed"}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "$(jq -r .next.last_done <<<"$output")" = failed ]
  [ "$(jq -c .obs <<<"$output")" = "$o" ]
}

@test "decide: ready is ready and next is the seen state" {  # decide: マージ可能は ready で、次の状態は見た状態
  run decide_of "$(obs ready r1)" '{"state":"conflict","head":"r0","fixes":1}'
  [ "$(jq -c '[.act, .next.state, .next.head, .next.fixes]' <<<"$output")" = '["ready","ready","r1",1]' ]
}

@test "decide: unreadable previous state or observation exits non-zero" {  # decide: 読めない前回の状態・読めない観測は非 0
  run decide_of "$(obs conflict h1)" 'not json'
  [ "$status" -ne 0 ]
  run decide_of 'not json' '{}'
  [ "$status" -ne 0 ]
}

# ── annotations ───────────────────────────────────────────

@test "annotations: fetches only the failed job" {  # annotations: 落ちたジョブの annotation だけを取る
  jq -cn --arg m "$LOST" '[{message: $m}, {message: "Process completed with exit code 1."}]' > "${WORK}/gh/77.json"
  run bash -c "printf '%s' '$(view MERGEABLE "[$(actions_check build FAILURE 700 77),$(actions_check lint SUCCESS 700 78)]" h)' | '$SCRIPT' annotations o/r"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.annotations_by_job | keys' <<<"$output")" = '["77"]' ]
  jq -e --arg m "$LOST" '.annotations_by_job."77" | index($m)' <<<"$output" >/dev/null
  [ "$(grep -c . "$GH_LOG")" = 1 ]
  grep -qF 'repos/o/r/check-runs/77/annotations' "$GH_LOG"
}

@test "annotations: one failed fetch warns and the rest is still printed with exit 0" {  # annotations: 1 件の取得に失敗しても残りを出して exit 0
  jq -cn --arg m "$LOST" '[{message: $m}]' > "${WORK}/gh/77.json"
  : > "${WORK}/gh/88.fail"
  run bash -c "printf '%s' '$(view MERGEABLE "[$(actions_check a FAILURE 700 77),$(actions_check b FAILURE 800 88)]" h)' | '$SCRIPT' annotations o/r 2>'${WORK}/err'"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.annotations_by_job | keys' <<<"$output")" = '["77"]' ]
  [ -s "${WORK}/err" ]
}

@test "annotations: no failed check means gh is never called" {  # annotations: 落ちたチェックが無ければ gh を呼ばない
  run bash -c "printf '%s' '$(view MERGEABLE '[{"name":"a","conclusion":"SUCCESS"}]' h)' | '$SCRIPT' annotations o/r"
  [ "$status" -eq 0 ]
  [ "$output" = '{"annotations_by_job":{}}' ]
  no_gh_called
}

@test "annotations: output can be passed to observe --hints as is" {  # annotations: 出力をそのまま observe --hints に渡せる
  local v
  jq -cn --arg m "$LOST" '[{message: $m}]' > "${WORK}/gh/77.json"
  v="$(view MERGEABLE "[$(actions_check build FAILURE 700 77)]" h)"
  printf '%s' "$v" | "$SCRIPT" annotations o/r > "${WORK}/hints.json"
  run observe_of "$v" --hints "${WORK}/hints.json"
  [ "$(jq -c '[.checks[0].cause, .retry]' <<<"$output")" = '["runner-lost",true]' ]
}
