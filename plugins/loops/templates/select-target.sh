#!/usr/bin/env bash
# select-target.sh — 自律開発ループ Step 1〜4 の「モード選定」を決定論的に行う。
#
# なぜ存在するか: モード選定（どのモードで・どの issue/PR 番号を対象にするか）は
# 完全に決定論的なのに、LLM が gh 出力を目視して選ぶと存在しない番号を「対象」に
# 捏造する事故が起きうる（実例: 2026-07-07 に存在しない issue #20 を対象化）。
# レートガード（憲法 Step 0）を jq でスクリプト化したのと同じ理由で、選定も
# ここに閉じ込め、LLM は本スクリプトの出力する target/mode に従うだけにする。
#
# 出力: stdout に JSON 1 オブジェクト。診断は stderr。gh/jq 失敗時は mode:"error"。
# 契約: LLM は candidates に無い番号を絶対に対象にしてはならない。
#
# 環境変数: AGENT_PROPOSE_LIMIT — 提案ストック上限（未設定時 {{PROPOSAL_CAP}}）
set -uo pipefail

PROPOSE_LIMIT="${AGENT_PROPOSE_LIMIT:-{{PROPOSAL_CAP}}}"

emit() { printf '%s\n' "$1"; exit 0; }
fail() { jq -n --arg m "$1" '{mode:"error",target:null,target_kind:null,reason:$m,candidates:[]}'; exit 0; }

command -v gh >/dev/null 2>&1 || fail "gh 未インストール"
command -v jq >/dev/null 2>&1 || fail "jq 未インストール"

# --- Step 1: agent-review:pending の最古 PR → レビューモード ---
pending=$(gh pr list --label "agent-review:pending" --state open --json number,createdAt 2>/dev/null) \
  || fail "gh pr list (pending) 失敗"
n=$(printf '%s' "$pending" | jq -r 'sort_by(.createdAt) | (.[0].number // empty)')
if [ -n "$n" ]; then
  emit "$(jq -n --argjson t "$n" '{mode:"review",target:$t,target_kind:"pr",reason:"agent-review:pending の最古 PR",candidates:[$t]}')"
fi

# --- Step 2: agent-review:failed の最古 PR → 修正モード ---
failed=$(gh pr list --label "agent-review:failed" --state open --json number,createdAt 2>/dev/null) \
  || fail "gh pr list (failed) 失敗"
n=$(printf '%s' "$failed" | jq -r 'sort_by(.createdAt) | (.[0].number // empty)')
if [ -n "$n" ]; then
  emit "$(jq -n --argjson t "$n" '{mode:"fix",target:$t,target_kind:"pr",reason:"agent-review:failed の最古 PR",candidates:[$t]}')"
fi

# --- Step 3: 実装可能な issue → 実装モード ---
# 適格 = open ∧ agent-ready ∧ ¬(agent-wip|agent-blocked|size:large)
issues=$(gh issue list --state open --limit 100 --json number,labels 2>/dev/null) \
  || fail "gh issue list 失敗"
label_eligible=$(printf '%s' "$issues" | jq -r '
  [ .[] | . as $i | ([$i.labels[].name]) as $l
    | select($l|index("agent-ready"))
    | select(($l|index("agent-wip"))|not)
    | select(($l|index("agent-blocked"))|not)
    | select(($l|index("size:large"))|not)
    | $i.number ] | sort | .[]')

cands=""
for num in $label_eligible; do
  # open な PR が既に紐づく issue は除外
  linked=$(gh pr list --state open --search "$num in:body" --json number 2>/dev/null | jq 'length' 2>/dev/null || printf '0')
  [ "${linked:-0}" != "0" ] && continue
  # open issue に blocked_by されているものは除外（API 非対応/失敗時は 0=非ブロック扱いで続行）
  blk=$(gh api "repos/{owner}/{repo}/issues/$num/dependencies/blocked_by" \
        --jq '[.[] | select(.state=="open")] | length' 2>/dev/null || printf '0')
  [ "${blk:-0}" != "0" ] && continue
  cands="$cands $num"
done

cands="${cands# }"
if [ -n "$cands" ]; then
  cand_json=$(printf '%s\n' $cands | jq -R 'tonumber' | jq -s 'sort')
  emit "$(jq -n --argjson c "$cand_json" '{mode:"implement",target:($c[0]),target_kind:"issue",reason:"実装可能 issue の最小番号（受け入れ条件の測定可能性は LLM が最終確認し、不適なら candidates 内の次番号へ）",candidates:$c}')"
fi

# --- Step 4: 上記に該当なし → 提案モード or skip ---
proposed=$(printf '%s' "$issues" | jq -r '[.[] | select([.labels[].name]|index("agent-proposed"))] | length')
if [ "${proposed:-0}" -ge "$PROPOSE_LIMIT" ]; then
  emit "$(jq -n --argjson c "$proposed" --argjson lim "$PROPOSE_LIMIT" '{mode:"skip",target:null,target_kind:null,reason:"未トリアージ提案が \($c) 件（上限 \($lim)）。新規起票せず報告のみ",candidates:[]}')"
else
  emit "$(jq -n --argjson c "$proposed" '{mode:"propose",target:null,target_kind:null,reason:"該当モードなし。提案枠に空き（現 \($c) 件）",candidates:[]}')"
fi
