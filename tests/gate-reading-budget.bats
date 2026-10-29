#!/usr/bin/env bats
# G の段別・条件別の合計。パスは plugins/dev-workflow/ 相対、wc -c で測る。
# 形式: <scenario> <byte-limit> <path>...。最終目標は全行 40000 以下。
# #580 段 1 は実測を暫定上限とする。後続の削減ごとに下げ、最終段で
# check_budget の strict を実 repo にも適用する（40000 と実測の 1.1 倍を検査）。
setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_DIR="$REPO_ROOT/plugins/dev-workflow"
  BUDGET_FILE="$REPO_ROOT/tests/gate-reading-budget.txt"
}

check_format() {
  local file=$1 line scenario budget path seen=" " paths n=0
  [ -f "$file" ] || { echo 'missing budget file' >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line" | grep -Eq '^[a-z][a-z0-9-]* [1-9][0-9]* [^ ]+( [^ ]+)*$' || return 1
    read -r scenario budget paths <<< "$line"
    case "$seen" in *" $scenario "*) echo 'duplicate scenario' >&2; return 1 ;; esac
    seen="$seen$scenario "
    local listed=" "
    for path in $paths; do
      case "/$path/" in *'/../'*|*'/./'*|*'//'*) echo 'invalid relative path' >&2; return 1 ;; esac
      case "$listed" in *" $path "*) echo 'duplicate path' >&2; return 1 ;; esac
      listed="$listed$path "
    done
    n=$((n + 1))
  done < "$file"
  [ "$n" -gt 0 ]
}

check_budget() {
  local root=$1 file=$2 mode=${3:-transitional} line scenario budget paths path total actual rc=0
  check_format "$file" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    read -r scenario budget paths <<< "$line"
    total=0
    for path in $paths; do
      [ -f "$root/$path" ] || { echo "missing file: $path" >&2; return 1; }
      actual=$(wc -c < "$root/$path" | tr -d '[:space:]')
      total=$((total + actual))
    done
    printf '%s: %s bytes, ~%s tokens (bytes/2.67), limit %s\n' "$scenario" "$total" "$(((total * 100 + 266) / 267))" "$budget"
    if [ "$total" -gt "$budget" ]; then echo "over budget: $scenario" >&2; rc=1; fi
    if [ "$mode" = strict ]; then
      if [ "$budget" -gt 40000 ]; then echo "over 40000: $scenario" >&2; rc=1; fi
      if [ $((budget * 10)) -gt $((total * 11)) ]; then echo "slack budget: $scenario" >&2; rc=1; fi
    fi
  done < "$file"
  return "$rc"
}

@test "real: stage reading totals stay within transitional budgets" {
  run check_budget "$PLUGIN_DIR" "$BUDGET_FILE"
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}

@test "real: common role is at most 12000 bytes and body is not a G input" {
  [ "$(wc -c < "$PLUGIN_DIR/skills/develop/references/roles/gate-runner.md")" -le 12000 ]
  ! grep -q 'gate-runner-body.md' "$BUDGET_FILE"
  grep -q 'gate-runner-body.md' "$PLUGIN_DIR/skills/develop/SKILL.md"
}

@test "real: all stages and conditional unions are measured" {
  [ "$(cut -d' ' -f1 "$BUDGET_FILE" | sort | tr '\n' ' ')" = 'hold pass pass-hold prepare prepare-rereview triage triage-row3 ' ]
  local scenario budget paths path expected common="skills/develop/references/roles/gate-runner.md" triage="skills/develop/references/roles/gate-runner-triage.md" prefix="skills/pr-review-gate"
  while read -r scenario budget paths; do
    case "$scenario" in
      prepare) expected="$common $prefix/stages/prepare.md" ;;
      prepare-rereview) expected="$common $prefix/stages/prepare.md $prefix/stages/triage.md" ;;
      triage) expected="$common $prefix/stages/triage.md $triage" ;;
      triage-row3) expected="$common $prefix/stages/triage.md $triage $prefix/stages/prepare.md" ;;
      pass) expected="$common $prefix/declarations.md $prefix/stages/pass.md" ;;
      pass-hold) expected="$common $prefix/declarations.md $prefix/stages/pass.md $prefix/stages/hold.md" ;;
      hold) expected="$common $prefix/stages/hold.md" ;;
    esac
    [ "$paths" = "$expected" ]
    for path in $paths; do
      [ "$path" = skills/develop/references/roles/gate-runner.md ] && continue
      grep -qF "${path#skills/pr-review-gate/}" "$PLUGIN_DIR/skills/develop/references/roles/gate-runner.md"
    done
  done < "$BUDGET_FILE"
}

@test "regress: sum exceeding budget fails even if each file fits" {
  printf '123456' > "$BATS_TEST_TMPDIR/a"
  printf '12345' > "$BATS_TEST_TMPDIR/b"
  printf 'prepare 10 a b\n' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget"
  [ "$status" -eq 1 ]
  [[ "$output" == *'over budget: prepare'* ]]
}

@test "regress: strict ceiling and slack are enforced at their boundaries" {
  head -c 40000 /dev/zero > "$BATS_TEST_TMPDIR/a"
  printf 'pass 40000 a\n' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget" strict
  [ "$status" -eq 0 ]
  printf 'pass 40001 a\n' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget" strict
  [ "$status" -eq 1 ]
  [[ "$output" == *'over 40000: pass'* ]]
  printf '1234567890' > "$BATS_TEST_TMPDIR/a"
  printf 'pass 11 a\n' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget" strict
  [ "$status" -eq 0 ]
  printf 'pass 12 a\n' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget" strict
  [ "$status" -eq 1 ]
  [[ "$output" == *'slack budget: pass'* ]]
}

@test "regress: missing files and malformed or duplicate entries fail" {
  local bad
  for bad in '' 'prepare 0 a' 'prepare 01 a' 'prepare 1' 'prepare 1 /a' 'prepare 1 ../a' 'prepare 1 a a'; do
    printf '%s\n' "$bad" > "$BATS_TEST_TMPDIR/budget"
    run check_format "$BATS_TEST_TMPDIR/budget"
    [ "$status" -eq 1 ]
  done
  printf 'prepare 10 a\nprepare 10 b\n' > "$BATS_TEST_TMPDIR/budget"
  run check_format "$BATS_TEST_TMPDIR/budget"
  [ "$status" -eq 1 ]
  printf 'prepare 10 missing\n' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget"
  [ "$status" -eq 1 ]
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/missing"
  [ "$status" -eq 1 ]
}

@test "regress: appending budget minus total plus one to a real input fails" {
  local scenario budget paths path total extra slack
  mkdir -p "$BATS_TEST_TMPDIR/root"
  while read -r scenario budget paths; do
    for slack in 0 10; do
      total=0
      for path in $paths; do
        mkdir -p "$BATS_TEST_TMPDIR/root/$(dirname "$path")"
        cp "$PLUGIN_DIR/$path" "$BATS_TEST_TMPDIR/root/$path"
        total=$((total + $(wc -c < "$PLUGIN_DIR/$path")))
      done
      path=${paths%% *}
      extra=$((budget + slack - total + 1))
      [ "$extra" -gt 0 ]
      head -c "$extra" /dev/zero >> "$BATS_TEST_TMPDIR/root/$path"
      printf '%s %s %s\n' "$scenario" "$((budget + slack))" "$paths" > "$BATS_TEST_TMPDIR/budget"
      run check_budget "$BATS_TEST_TMPDIR/root" "$BATS_TEST_TMPDIR/budget"
      [ "$status" -eq 1 ]
      [[ "$output" == *"over budget: $scenario"* ]]
    done
  done < "$BUDGET_FILE"
}

@test "regress: a final line without newline is still measured" {
  printf '123456' > "$BATS_TEST_TMPDIR/a"
  printf 'prepare 5 a' > "$BATS_TEST_TMPDIR/budget"
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/budget"
  [ "$status" -eq 1 ]
  [[ "$output" == *'over budget: prepare'* ]]
}
