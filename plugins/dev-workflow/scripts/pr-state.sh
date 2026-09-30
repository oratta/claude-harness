#!/usr/bin/env bash
# PR の状態を分類し、前回の状態から次の一手を決める。セッションと住人（flatmate の pr-watch）が
# 同じ判断を呼ぶための共有部品で、状態の保存・依頼の列・あなた待ち・`gh run rerun` の実行は
# 呼び出し側が持つ。
#
#   view="$(gh pr view "$n" --repo "$repo" --json mergeable,statusCheckRollup,headRefOid)"
#   printf '%s' "$view" | pr-state.sh annotations "$repo" > "$hints"
#   printf '%s' "$view" | pr-state.sh observe --hints "$hints" [--unrelated <check名>]... \
#     | pr-state.sh decide "$prev"      # → {"act":..., "next":{...}, "obs":{...}}
#
# サブコマンド（入力はどれも標準入力、出力は 1 行 JSON）:
#   observe [--hints <file>] [--unrelated <check名>]...
#       gh pr view の JSON → {head, state, failed, runs, checks, retry}
#       state: conflict / ci-fail / ready / wait。checks は落ちたチェックごとの
#       {name, run, job, cause}、cause は runner-lost（--hints の annotations_by_job.<job> に
#       通信切れの文言）→ unrelated（--unrelated の名前）→ real の順。retry は ci-fail で、
#       落ちたチェックがすべて real でなく、すべてに run ID があるときだけ true
#   decide [<前回の状態の JSON>]
#       observe の出力 → {act, next, obs}。act: none / ready / rerun / fix / escalate
#       状態のキー: state / head / reran_head（やり直した HEAD）/ fixes（PR ごとの修正回数の累計）/
#       raised（オーナーに上げ済み）。知らないキーは next にそのまま引き継ぐ。
#       前回の状態が省略・null・{} なら初見。やり直しは HEAD ごとに 1 回、fix は 2 回まで、
#       3 回目は escalate
#   annotations <owner/repo>
#       gh pr view の JSON → {"annotations_by_job": {"<job>": [<message>, ...]}}
#       落ちた Actions のジョブごとに gh api repos/<owner/repo>/check-runs/<job>/annotations を呼ぶ
#       （Actions ではジョブ ID とチェックラン ID が同じ）。gh の認証と対象リポジトリの checks の
#       読み取り権限が要る。1 件の取得に失敗したらそのジョブを除いて警告し、残りを続けて exit 0
#
# gh を呼ぶのは annotations だけ。observe / decide は入力だけで決まる。
# 読めない入力（JSON でない標準入力・前回の状態・--hints）は標準出力に何も出さず exit 1。
# 仕様の正本: openspec の dev-workflow-pr-state。
set -uo pipefail

# 実行マシンの通信切れを示す annotation の文言（GitHub が変えたらここだけ直す）
RUNNER_LOST_MSG='The self-hosted runner lost communication with the server'

PR_STATE_JQ='
def verdict:
  ((.conclusion // "") | tostring) as $c
  | (if $c != "" then $c else ((.state // .status // "") | tostring) end) | ascii_upcase
  | if IN("SUCCESS","NEUTRAL","SKIPPED") then "ok"
    elif IN("PENDING","EXPECTED","QUEUED","IN_PROGRESS","WAITING","REQUESTED","") then "pending"
    else "fail" end;
def checks:
  [.statusCheckRollup[]?
   | ((.detailsUrl // .targetUrl // "") | tostring) as $u
   | { name: ((.name // .context // "?") | tostring | gsub("[\t\n,]"; " ")),
       v: verdict,
       run: ($u | (capture("/actions/runs/(?<id>[0-9]+)(/|$)") | .id) // null),
       job: ($u | (capture("/actions/runs/[0-9]+/job/(?<id>[0-9]+)") | .id) // null) }];
def observe($hints; $unrelated):
  checks as $cs
  | ($cs | map(select(.v == "fail"))) as $f
  | ($f | map({name, run, job,
               cause: (.job as $j | .name as $n
                       | if $j != null and any(($hints.annotations_by_job[$j] // [])[];
                                               tostring | contains($lost)) then "runner-lost"
                         elif any($unrelated[]; . == $n) then "unrelated"
                         else "real" end)})) as $fc
  | (if .mergeable == "CONFLICTING" then "conflict"
     elif ($f | length) > 0 then "ci-fail"
     elif .mergeable == "MERGEABLE" and all($cs[]; .v == "ok") then "ready"
     else "wait" end) as $state
  | { head: ((.headRefOid // "") | tostring),
      state: $state,
      failed: ($f | map(.name) | unique),
      runs: ($f | map(.run // empty) | unique),
      checks: $fc,
      retry: ($state == "ci-fail" and ($fc | length) > 0
              and all($fc[]; .cause != "real" and .run != null)) };
def decide($prev; $obs):
  ($prev // {}) as $p
  | ($p + {state: $obs.state, head: $obs.head}) as $seen
  | if $obs.state == "wait" then {act: "none", next: (if $p.head == $obs.head then $p else $seen end)}
    elif $obs.state == "ready" then {act: "ready", next: $seen}
    elif $p.state == $obs.state and $p.head == $obs.head then {act: "none", next: $seen}
    elif $p.raised == true then {act: "none", next: $seen}
    elif $obs.state == "ci-fail" and $obs.retry == true and $p.reran_head != $obs.head
      then {act: "rerun", next: ($seen + {state: "wait", reran_head: $obs.head})}
    elif ($p.fixes // 0) >= 2 then {act: "escalate", next: ($seen + {raised: true})}
    else {act: "fix", next: ($seen + {fixes: (($p.fixes // 0) + 1)})} end
  | . + {obs: $obs};
'

die() { echo "pr-state.sh: $*" >&2; exit 1; }

cmd_observe() {
  local hints='{}' unrelated=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --hints)
        [ -n "${2-}" ] || die "--hints needs a file"
        hints="$(jq -ce 'if type == "object" then . else error("not an object") end' "$2" 2>/dev/null)" \
          || die "cannot read --hints file: $2"
        shift 2 ;;
      --unrelated)
        [ -n "${2-}" ] || die "--unrelated needs a check name"
        unrelated+=("$2"); shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  local names
  names="$(jq -cn '$ARGS.positional' --args ${unrelated[@]+"${unrelated[@]}"})"
  jq -ce --arg lost "$RUNNER_LOST_MSG" --argjson hints "$hints" --argjson unrelated "$names" \
    "$PR_STATE_JQ"' if type == "object" then observe($hints; $unrelated) else error("not an object") end' \
    2>/dev/null || die "cannot read gh pr view JSON from stdin"
}

cmd_decide() {
  local prev="${1:-null}" obs
  jq -e 'type == "object" or type == "null"' <<<"$prev" >/dev/null 2>&1 \
    || die "cannot read previous state: $prev"
  obs="$(jq -ce 'if type == "object" then . else error("not an object") end' 2>/dev/null)" \
    || die "cannot read observe output from stdin"
  jq -cn --argjson p "$prev" --argjson o "$obs" "$PR_STATE_JQ"' decide($p; $o)'
}

cmd_annotations() {
  local repo="${1-}" view jobs job msgs out='{}'
  [ -n "$repo" ] || die "usage: pr-state.sh annotations <owner/repo>"
  view="$(jq -ce 'if type == "object" then . else error("not an object") end' 2>/dev/null)" \
    || die "cannot read gh pr view JSON from stdin"
  jobs="$(jq -r "$PR_STATE_JQ"' [checks[] | select(.v == "fail" and .job != null) | .job] | unique[]' <<<"$view")"
  for job in $jobs; do
    if ! msgs="$(gh api "repos/${repo}/check-runs/${job}/annotations?per_page=100" 2>/dev/null \
                 | jq -ce '[.[] | .message // empty | tostring]' 2>/dev/null)"; then
      echo "pr-state.sh: warning: cannot fetch annotations for job ${job} in ${repo}" >&2
      continue
    fi
    out="$(jq -c --arg j "$job" --argjson m "$msgs" '.[$j] = $m' <<<"$out")"
  done
  jq -cn --argjson a "$out" '{annotations_by_job: $a}'
}

case "${1-}" in
  observe) shift; cmd_observe "$@" ;;
  decide) shift; cmd_decide "$@" ;;
  annotations) shift; cmd_annotations "$@" ;;
  *) die "usage: pr-state.sh observe [--hints F] [--unrelated NAME]... | decide [PREV] | annotations OWNER/REPO" ;;
esac
