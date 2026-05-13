#!/usr/bin/env bash
#
# measure-tdd-fidelity.sh — classify each commit reachable from HEAD by the
# kinds of files it touches, then emit a "no-test-rate" metric.
#
# Categories per commit:
#   - tests-only       : touches only *.test.ts / *.spec.ts files
#   - production-only  : touches only src/**/*.ts (non-test) files
#   - both             : touches both test and production files
#   - neither          : touches neither (docs, config, etc.)
#
# no-test-rate = production-only / total  (rendered as a percentage)
#
# By default we walk *all* commits reachable from HEAD on the current branch.
# A future iteration can scope this to e.g. `main..HEAD`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
LONGRUN_REL="_longruns/2026-05-13_codex-build-agent-eval"
EVAL_FILE="$REPO_ROOT/$LONGRUN_REL/evaluation.md"

tests_only=0
prod_only=0
both=0
neither=0
total=0

while IFS= read -r sha; do
  [ -z "$sha" ] && continue
  total=$((total + 1))

  files=$(git -C "$REPO_ROOT" show --no-renames --name-only --pretty=format: "$sha" | sed '/^$/d')

  has_test=0
  has_prod=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) has_test=1 ;;
      *.ts|*.tsx)
        # *.ts that wasn't caught above is production TS.
        has_prod=1
        ;;
    esac
  done <<<"$files"

  if [ "$has_test" -eq 1 ] && [ "$has_prod" -eq 1 ]; then
    both=$((both + 1))
  elif [ "$has_test" -eq 1 ]; then
    tests_only=$((tests_only + 1))
  elif [ "$has_prod" -eq 1 ]; then
    prod_only=$((prod_only + 1))
  else
    neither=$((neither + 1))
  fi
done < <(git -C "$REPO_ROOT" log --pretty=%H)

if [ "$total" -eq 0 ]; then
  rate="0"
else
  # Use awk for portable float math.
  rate=$(awk -v p="$prod_only" -v t="$total" 'BEGIN { printf "%.1f", (p / t) * 100 }')
fi

printf 'Commit classification (n=%d)\n' "$total"
printf '  tests-only      : %d\n' "$tests_only"
printf '  production-only : %d\n' "$prod_only"
printf '  both            : %d\n' "$both"
printf '  neither         : %d\n' "$neither"
printf '\n'
printf 'no-test-rate: %s%%\n' "$rate"

if [ -f "$EVAL_FILE" ]; then
  tmp="$(mktemp)"
  awk -v rate="${rate}%" '
    { line = $0 }
    line ~ /^- no-test-rate:/ { line = "- no-test-rate: " rate }
    { print line }
  ' "$EVAL_FILE" > "$tmp"
  mv "$tmp" "$EVAL_FILE"

  if ! grep -q "^- no-test-rate:" "$EVAL_FILE"; then
    printf '\n- no-test-rate: %s%%\n' "$rate" >> "$EVAL_FILE"
  fi
fi
