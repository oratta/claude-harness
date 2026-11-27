#!/usr/bin/env bats
#
# エピックの子は主の返事を待つとき質問ツール（AskUserQuestion）を使わず、本文で質問してターンを終える（issue #1555）
#
#   skills/develop/references/epic-child-stop.md   子の止まりの手順。読み替えの規則を 1 か所に置く
#   skills/develop/ 配下の手順書                    AskUserQuestion を含む行の検査
#
# spec: dev-workflow-develop（要件「エピックの子は PR のリスク許容の返事を待って止まるときだけ記録を残す」）

setup() {
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DEV="${PLUGIN_DIR}/skills/develop"
  CHILD="${DEV}/references/epic-child-stop.md"
}

@test "epic-child-stop.md does not allow waiting inside the question tool" {
  if grep -qF '質問ツール（AskUserQuestion）の中で待つ' "$CHILD"; then return 1; fi
  if grep -qE '質問ツールの中で待つ(とき|ことを認める)' "$CHILD"; then return 1; fi
}

@test "epic-child-stop.md says epic children ask in the body and end the turn" {
  grep -qF '本文で質問してターンを終える' "$CHILD"
  grep -qF '本文に番号つきで書く' "$CHILD"
}

@test "epic-child-stop.md has the reading rule for nested epic children in one place" {
  local n
  n="$(grep -cF 'エピックの子ではこの聞き方に読む' "$CHILD")"
  [ "$n" -eq 1 ]
  grep -F 'エピックの子ではこの聞き方に読む' "$CHILD" | grep -qF 'nested'
  grep -F 'エピックの子ではこの聞き方に読む' "$CHILD" | grep -qF 'interactive は AskUserQuestion で聞く'
}

@test "no develop document tells an epic child to ask with the question tool" {
  local line f bad=0
  while IFS= read -r f; do
    while IFS= read -r line; do
      if printf '%s\n' "$line" | grep -qE 'interactive は|\*\*interactive\*\*|\*\*interactive モード\*\*|interactive モードでは|AskUserQuestion (は使わない|を呼ばない|を呼ばず|を使わず)'; then continue; fi
      echo "条件なしの指示と読める行: $f: ${line:0:120}" >&2
      bad=1
    done < <(grep -F 'AskUserQuestion' "$f")
  done < <(find "${DEV}/SKILL.md" "${DEV}/references" -name '*.md' | sort)
  [ "$bad" -eq 0 ]
}

@test "epic-child-stop.md lines with AskUserQuestion are in the negative form" {
  local line
  while IFS= read -r line; do
    if ! printf '%s\n' "$line" | grep -qE 'AskUserQuestion (は使わない|を呼ばない|を呼ばず|を使わず)|interactive は AskUserQuestion で聞く'; then
      echo "否定の形でない行: ${line:0:120}" >&2
      return 1
    fi
  done < <(grep -F 'AskUserQuestion' "$CHILD")
}
