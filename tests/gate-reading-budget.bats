#!/usr/bin/env bats
# G の段別・条件別の合計。パスは plugins/dev-workflow/ 相対、wc -c で測る。
# 形式: <scenario> <byte-limit> <path>...。最終目標は全行 40000 以下。
# 上限は実測値（40000 を超える経路は OVER_TARGET に列挙し、実測の 1.1 倍）。strict（40000 以下かつ実測の 1.1 倍以内）は列挙外に掛ける。
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

# 40000 を超える経路（#580 の残り）。合格処理の引き継ぎ・動作確認代行で保留に進む経路・保留の解除の引き継ぎは、
# 条件付きで加わる段のファイルが大きく、この PR では 40000 以下に収められなかった。実測値を上限にして増えないことだけ固定する。
OVER_TARGET=" pass-carryover pass-hold hold-carryover "

@test "real: strict ceiling and slack hold for every scenario except the listed over-target paths" {
  local line scenario
  : > "$BATS_TEST_TMPDIR/strict.txt"
  while IFS= read -r line; do
    scenario=${line%% *}
    case "$OVER_TARGET" in *" $scenario "*) continue ;; esac
    printf '%s\n' "$line" >> "$BATS_TEST_TMPDIR/strict.txt"
  done < "$BUDGET_FILE"
  run check_budget "$PLUGIN_DIR" "$BATS_TEST_TMPDIR/strict.txt" strict
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}

@test "real: all stages and conditional unions are measured" {
  [ "$(cut -d' ' -f1 "$BUDGET_FILE" | sort | tr '\n' ' ')" = 'hold hold-carryover pass pass-auth pass-carryover pass-hold prepare rereview triage-escalation triage-failed triage-nonblocking triage-row3 triage-summary ' ]
  local scenario budget paths path expected common="skills/develop/references/roles/gate-runner.md" triage="skills/develop/references/roles/gate-runner-triage.md" p="skills/pr-review-gate" st="skills/pr-review-gate/stages"
  while read -r scenario budget paths; do
    case "$scenario" in
      prepare) expected="$common $st/prepare.md $st/prepare-step1.md" ;;
      rereview) expected="$common $st/prepare.md $st/prepare-step1.md $st/convergence.md" ;;
      triage-summary) expected="$common $st/triage.md $st/triage-summary.md $triage" ;;
      triage-failed) expected="$common $st/triage.md $st/triage-failed.md" ;;
      triage-row3) expected="$common $st/triage.md $st/triage-row3.md $st/row3-list-format.md $st/prepare-step1.md" ;;
      triage-nonblocking) expected="$common $st/triage.md $st/triage-nonblocking.md" ;;
      triage-escalation) expected="$common $st/triage.md $st/triage-escalation.md" ;;
      pass) expected="$common $p/declarations.md $st/pass.md" ;;
      pass-auth) expected="$common $p/declarations.md $st/pass.md $st/authenticity.md" ;;
      pass-carryover) expected="$common $p/declarations.md $st/pass.md $st/carryover.md" ;;
      pass-hold) expected="$common $p/declarations.md $st/pass.md $st/hold.md" ;;
      hold) expected="$common $st/hold.md" ;;
      hold-carryover) expected="$common $st/hold.md $st/carryover.md" ;;
    esac
    [ "$paths" = "$expected" ]
    for path in $paths; do
      [ "$path" = skills/develop/references/roles/gate-runner.md ] && continue
      # row3-list-format.md は triage-row3.md が指す（共通 role には書かない）
      [ "$path" = skills/pr-review-gate/stages/row3-list-format.md ] && { grep -qF row3-list-format.md "$PLUGIN_DIR/skills/pr-review-gate/stages/triage-row3.md" || return 1; continue; }
      grep -qF "${path#skills/pr-review-gate/}" "$PLUGIN_DIR/skills/develop/references/roles/gate-runner.md" || { echo "not named in the common role: $path"; return 1; }
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
