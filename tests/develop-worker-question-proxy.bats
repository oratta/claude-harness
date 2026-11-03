#!/usr/bin/env bats
# issue #594: W の質問 return と本体による代理送信を固定する。実サービスは呼ばない。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DEVELOP="$REPO_ROOT/plugins/dev-workflow/skills/develop"
  WORKER="$DEVELOP/references/roles/worker"
  AGENT="$REPO_ROOT/plugins/dev-workflow/agents/worker.md"
}

# Discord の行は送信禁止、または送らず本体へ返す文脈のみ許す。
# 自然文の全言い換えは扱わず、grep の全ヒットの目視確認を併用する。
check_discord_lines() {
  local line
  while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -qi discord; then
      [[ "$line" == *'W は'* ]] || return 1
      [[ "$line" == *'直接送信しない'* || "$line" == *'送信せず'* ]] || return 1
      [[ "$line" == *'本体'* ]] || return 1
    fi
  done
}

question_contract() {
  local section=$1 token
  for token in unmanned 質問文 理由 return 記録先 needs-approval 経緯 コメント 本体; do
    [[ "$section" == *"$token"* ]] || { echo "missing: $token" >&2; return 1; }
  done
  [[ "$section" == *'作業を止め'* ]] || return 1
}

ambiguous_criteria() {
  awk '/^### 割り方が判断できないほど曖昧な場合/ {p=1; next} /^## / {p=0} p' "$DEVELOP/references/decision-criteria.md"
}

execution_modes() {
  awk '/^## 実行モード$/ {p=1; next} /^### / || /^## / {p=0} p' "$DEVELOP/SKILL.md"
}

@test "worker documents and agent contain no direct Discord instruction" {
  local file
  while IFS= read -r file; do
    check_discord_lines < "$file" || { echo "invalid Discord instruction: $file" >&2; return 1; }
  done < <(find "$WORKER" -type f)
  check_discord_lines < "$AGENT"
}

@test "Discord classifier accepts negative context and rejects direct MCP or CLI instructions" {
  run check_discord_lines <<< 'W は Discord に送信せず、質問文を本体に返す'
  [ "$status" -eq 0 ]
  run check_discord_lines <<< 'W は Discord（MCP・CLI とも）へ直接送信しない。本体が送る'
  [ "$status" -eq 0 ]
  local instruction
  for instruction in 'unmanned は Discord で質問する' 'W は MCP で Discord に送信する' 'W は CLI で Discord に送信する'; do
    run check_discord_lines <<< "$instruction"
    [ "$status" -eq 1 ]
  done
}

@test "worker tools remain unchanged" {
  run grep '^tools:' "$AGENT"
  [ "$status" -eq 0 ]
  [ "$output" = 'tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop' ]
}

@test "invented decisions return the decisions question and reason with approval record" {
  section="$(sed -n '/^- \*\*仕様の発明\*\*/p' "$WORKER/common.md")"
  question_contract "$section"
  [[ "$section" == *'2 回'* && "$section" == *'埋めた決定を列挙'* ]] || return 1
  [[ "$section" == *'interactive は本体が AskUserQuestion'* ]] || return 1
  [[ "$section" == *'W は Discord（MCP・CLI とも）へ直接送信しない'* ]] || return 1
}

@test "ambiguous split returns question without creating child issues" {
  section="$(sed -n '/^- \*\*割り方が判断できないほど曖昧\*\*/p' "$WORKER/spec.md")"
  question_contract "$section"
  [[ "$section" == *'子 issue を作らず'* ]] || return 1
  [[ "$section" == *'interactive は return で本体に聞いてもらう'* ]] || return 1
}

@test "decision criteria delegate sending to the body and reference execution modes" {
  section="$(ambiguous_criteria)"
  question_contract "$section"
  [[ "$section" == *'本体が代理送信'* ]] || return 1
  [[ "$section" == *'SKILL.md'* && "$section" == *'実行モード'* ]] || return 1
  check_discord_lines <<< "$section"
}

@test "unmanned execution modes receive worker return and send via the constitutional main" {
  section="$(execution_modes)"
  paragraph="$(printf '%s\n' "$section" | sed -n '/^unmanned で W の return/p')"
  for token in 質問文 理由 本体 憲法のメイン自身 受け取り Discord 代理送信 needs-approval サイクルを終了; do
    [[ "$paragraph" == *"$token"* ]] || { echo "missing: $token" >&2; return 1; }
  done
  row="$(printf '%s\n' "$section" | sed -n '/^| \*\*unmanned/p')"
  [[ "$row" == *'本体が代理送信'* && "$row" != *'聞けない'* ]] || return 1
  split="$(printf '%s\n' "$section" | sed -n '/^unmanned で複数 change/p')"
  [[ "$split" == *'質問文・理由を return'* && "$split" == *'本体が代理送信'* ]] || return 1
}
