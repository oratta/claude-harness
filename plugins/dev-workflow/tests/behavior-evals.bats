#!/usr/bin/env bats
#
# claude plugin eval 用のお題集（plugins/*/evals/）の構造検査。
# 読み込めること・実際のスコアは有料の実行（docs/plugin-evals.md）でしか確かめられないので、ここでは見ない。
# spec: openspec/changes/dev-workflow-behavior-evals（archive 後は openspec/specs/dev-workflow-behavior-evals）

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  DEV="${ROOT}/plugins/dev-workflow/evals"
  CAST="${ROOT}/plugins/casting/evals"
}

@test "dev-workflow has at least 5 eval cases" {
  n="$(ls "$DEV"/*/prompt.md | wc -l | tr -d ' ')"
  [ "$n" -ge 5 ]
}

@test "casting has at least 1 eval case" {
  n="$(ls "$CAST"/*/prompt.md | wc -l | tr -d ' ')"
  [ "$n" -ge 1 ]
}

@test "every case has graders/*.md and each grader frontmatter has type" {
  for d in "$DEV"/*/ "$CAST"/*/; do
    [ "$(basename "$d")" = results ] && continue  # 実行結果の置き場（gitignore 済み）
    [ -f "${d}prompt.md" ]
    n="$(ls "${d}"graders/*.md | wc -l | tr -d ' ')"
    [ "$n" -ge 1 ]
    for g in "${d}"graders/*.md; do
      # frontmatter（先頭の --- から次の ---）内に type: がある
      awk 'NR==1 && $0!="---"{exit 1} NR>1 && $0=="---"{exit f?0:1} /^type: /{f=1}' "$g" || { echo "type: が無い: $g"; return 1; }
    done
  done
}

@test "cases with a tool_used Skill grader also have a regex or llm result grader" {
  for d in "$DEV"/*/ "$CAST"/*/; do
    [ "$(basename "$d")" = results ] && continue
    if grep -lE '^tool: Skill' "${d}"graders/*.md >/dev/null 2>&1; then
      grep -lE '^type: (llm|regex)' "${d}"graders/*.md >/dev/null || { echo "結果 grader が無い: $d"; return 1; }
    fi
  done
}

@test "cases exist for develop and pr-review-gate firing" {
  grep -rlE 'input_match:.*develop' "$DEV"/*/graders >/dev/null
  grep -rlE 'input_match:.*pr-review-gate' "$DEV"/*/graders >/dev/null
}

@test "destructive-git cases have a scaffold and grade file contents" {
  found=0
  for d in "$DEV"/destructive-git-*/; do
    [ -d "$d" ] || continue
    found=1
    grep -q 'scaffold_script:' "${d}case.yaml"
    [ -f "${d}$(sed -n 's/^ *scaffold_script: *//p' "${d}case.yaml")" ]
    grep -rq 'source: file' "${d}graders"
  done
  # hook が効かないと分かった場合は 0 件でよい（spec の例外）。その場合は docs に理由がある
  if [ "$found" = 0 ]; then grep -q 'hook が働かなかった' "${ROOT}/docs/plugin-evals.md"; fi
}

@test "casting cases inject rules via append_system_prompt and judge with llm" {
  for d in "$CAST"/*/; do
    [ "$(basename "$d")" = results ] && continue
    grep -q '^append_system_prompt:' "${d}prompt.md"
    grep -lE '^type: llm' "${d}"graders/*.md >/dev/null
  done
}

@test "docs has the full command and the cost estimate" {
  doc="${ROOT}/docs/plugin-evals.md"
  [ -f "$doc" ]
  grep -q -- '--scaffold' "$doc"
  grep -q -- '--allow-tools "Bash(git \*)"' "$doc"
  grep -q -- '--max-cost-usd 10' "$doc"
  grep -q -- '--model sonnet' "$doc"
  grep -q 'Claude Code' "$doc"
  grep -q 'Δ' "$doc"
}

@test "evals/results is gitignored" {
  grep -qE '^evals/results/|^\*\*/evals/results/' "${ROOT}/.gitignore"
}

@test "change record 709.md exists" {
  [ -f "${ROOT}/plugins/dev-workflow/changes/709.md" ]
}

@test "no CI workflow runs plugin eval" {
  ! grep -rq 'plugin eval' "${ROOT}/.github/workflows"
}
