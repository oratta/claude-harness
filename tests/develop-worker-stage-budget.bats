#!/usr/bin/env bats
# develop-worker-stage-budget.bats — W が段ごとに読むファイルの合計に予算を置く（issue #1683、エピック #1682）
#
# 段ごとに読むファイルの一覧はこのファイルに固定する（plugins/dev-workflow/ からの相対パス）。
# 一覧は openspec の要件「W が段ごとに読むファイルの合計に予算を置く」のシナリオ「段ごとに測るファイル」のとおり。
# 予算値は tests/develop-worker-stage-budget.txt（1 行 1 段: "<段> <バイト数>"）。閾値をこのファイルに直書きしない。
# 単位はバイト数（wc -c。字数はロケールで値が変わり、CI と手元でずれるため使わない）。
# 判定は develop-startup-budget.bats と同じ上下両方向: 実測が予算を超えたら fail、予算が実測の
# 1.1 倍を超えても fail（減らした変更に予算の引き下げを求める）。
#
# 一覧が手順書とずれないよう、worker/common.md が return-declaration.md を、worker/spec.md が
# spec-decision.md を、worker/finish.md が skills/pr-review-gate/declarations.md を名指ししていることと、
# W の段のファイルと common.md が decision-criteria.md を読むよう指していないことも確かめる。
#
# 守備範囲: 入力は一覧のファイルの中身と予算ファイル。同じ大きさでの中身の入れ替えと、一覧に無い
# ファイルを読ませる指示の追加は通る（エピック #1682 で主が受け入れた残り。仕様レビューと PR レビューが見る）。
#
# 異常系は実 repo のファイルを書き換えず、使い捨ての root と予算ファイルで作る。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_DIR="$REPO_ROOT/plugins/dev-workflow"
  BUDGET_FILE="$REPO_ROOT/tests/develop-worker-stage-budget.txt"
}

R=skills/develop/references

# stage_files <段> — その段で W が読むファイルを 1 行 1 件で出す。知らない段は 1。
stage_files() {
  case "$1" in
    spec) printf '%s\n' agents/worker.md "$R/roles/worker/common.md" "$R/roles/worker/spec.md" \
            "$R/spec-decision.md" "$R/return-declaration.md" ;;
    implement) printf '%s\n' agents/worker.md "$R/roles/worker/common.md" "$R/roles/worker/implement.md" \
            "$R/return-declaration.md" ;;
    finish) printf '%s\n' agents/worker.md "$R/roles/worker/common.md" "$R/roles/worker/finish.md" \
            skills/pr-review-gate/declarations.md "$R/return-declaration.md" ;;
    *) return 1 ;;
  esac
}

# check_format <budget-file> — 全行が "<段> <先頭ゼロなしの正整数>" で、段が spec / implement / finish の
# どれかで重複が無く、3 段とも揃っていること。違反は stderr に出して 1。
check_format() {
  local f=$1 n=0 line stage seen=" "
  [ -f "$f" ] || { echo "予算ファイルが無い: $f" >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if ! printf '%s' "$line" | grep -Eq '^(spec|implement|finish) [1-9][0-9]*$'; then
      echo "予算ファイル $n 行目の形が違う（'<段> <バイト数>' のみ。段は spec / implement / finish）: $line" >&2
      return 1
    fi
    stage=${line% *}
    case "$seen" in *" $stage "*) echo "予算ファイルに段の重複: $stage" >&2; return 1 ;; esac
    seen="$seen$stage "
  done < "$f"
  [ "$n" -eq 3 ] || { echo "予算ファイルの段が 3 つ揃っていない（$n 行）" >&2; return 1; }
}

# stage_total <root> <段> — 一覧のファイルを足したバイト数。無いファイルがあれば stderr に出して 1。
stage_total() {
  local root=$1 stage=$2 p total=0 n
  while IFS= read -r p; do
    [ -f "$root/$p" ] || { echo "測定対象が無い: $stage の $p" >&2; return 1; }
    n=$(wc -c < "$root/$p" | tr -d '[:space:]')
    total=$((total + n))
  done < <(stage_files "$stage")
  echo "$total"
}

# check_budget <root> <budget-file> — 段ごとに上下両方向を判定する。違反は stderr に出して 1。
check_budget() {
  local root=$1 f=$2 rc=0 line stage budget actual
  check_format "$f" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    stage=${line% *}
    budget=${line##* }
    actual=$(stage_total "$root" "$stage") || { rc=1; continue; }
    if [ "$actual" -gt "$budget" ]; then
      printf '予算超過: 段 %s 実測 %s > 予算 %s バイト（削るか、予算ファイルを動かして理由を PR に書く）\n' \
        "$stage" "$actual" "$budget" >&2
      rc=1
    elif [ $((budget * 10)) -gt $((actual * 11)) ]; then
      printf '予算が緩すぎる: 段 %s 予算 %s > 実測 %s の 1.1 倍（予算を実測に合わせて引き下げる）\n' \
        "$stage" "$budget" "$actual" >&2
      rc=1
    fi
  done < "$f"
  return "$rc"
}

# check_naming <root> — 手順書が一覧の追加分を名指しし、decision-criteria.md を読ませていないこと。
check_naming() {
  local root=$1 rc=0 f
  grep -qF 'return-declaration.md' "$root/$R/roles/worker/common.md" \
    || { echo "worker/common.md が return-declaration.md を名指ししていない" >&2; rc=1; }
  grep -qF 'spec-decision.md' "$root/$R/roles/worker/spec.md" \
    || { echo "worker/spec.md が spec-decision.md を名指ししていない" >&2; rc=1; }
  grep -qF 'skills/pr-review-gate/declarations.md' "$root/$R/roles/worker/finish.md" \
    || { echo "worker/finish.md が skills/pr-review-gate/declarations.md を名指ししていない" >&2; rc=1; }
  for f in common spec implement finish; do
    if grep -F 'decision-criteria.md' "$root/$R/roles/worker/$f.md" | grep -qF '読'; then
      echo "worker/$f.md が decision-criteria.md を読ませている" >&2; rc=1
    fi
  done
  return "$rc"
}

# copy_real <dir> — 一覧の実ファイルを使い捨て root に写す。
copy_real() {
  local d=$1 s p
  for s in spec implement finish; do
    while IFS= read -r p; do
      mkdir -p "$d/$(dirname "$p")"
      cp "$PLUGIN_DIR/$p" "$d/$p"
    done < <(stage_files "$s")
  done
}

# ── 実 repo ───────────────────────────────────────────────

@test "real: budget file has the three stages" {
  run check_format "$BUDGET_FILE"
  if [ "$status" -ne 0 ]; then printf '%s\n' "$output" >&2; fi
  [ "$status" -eq 0 ]
  [ "$(cut -d' ' -f1 "$BUDGET_FILE" | sort | tr '\n' ' ')" = "finish implement spec " ]
}

@test "real: every stage total is within budget and the budget is not slack" {
  run check_budget "$PLUGIN_DIR" "$BUDGET_FILE"
  if [ "$status" -ne 0 ]; then printf '%s\n' "$output" >&2; fi
  [ "$status" -eq 0 ]
}

@test "real: stage instructions name the extra files and do not tell to read decision-criteria.md" {
  run check_naming "$PLUGIN_DIR"
  if [ "$status" -ne 0 ]; then printf '%s\n' "$output" >&2; fi
  [ "$status" -eq 0 ]
}

# ── 退行テスト（使い捨ての root と予算ファイル）─────────────────

@test "regress: adding text to common.md that pushes spec over budget fails with stage, actual and budget" {
  local r="$BATS_TEST_TMPDIR/r" actual
  copy_real "$r"
  actual=$(stage_total "$r" spec)
  printf 'spec %s\nimplement %s\nfinish %s\n' "$actual" "$(stage_total "$r" implement)" "$(stage_total "$r" finish)" \
    > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 0 ]
  printf 'x' >> "$r/$R/roles/worker/common.md"
  run check_budget "$r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"予算超過: 段 spec 実測 $((actual + 1)) > 予算 $actual"* ]] || return 1
}

@test "regress: budget above 1.1 times actual fails; exactly 1.1 times passes" {
  local r="$BATS_TEST_TMPDIR/r" s i m
  copy_real "$r"
  s=$(stage_total "$r" spec); i=$(stage_total "$r" implement); m=$(stage_total "$r" finish)
  printf 'spec %s\nimplement %s\nfinish %s\n' "$s" "$((i * 11 / 10))" "$m" > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 0 ]
  printf 'spec %s\nimplement %s\nfinish %s\n' "$s" "$((i * 11 / 10 + 1))" "$m" > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"予算が緩すぎる: 段 implement"* ]] || return 1
}

@test "regress: dropping each named file from the stage instructions fails" {
  local r="$BATS_TEST_TMPDIR/r" spec
  for spec in 'common:return-declaration\.md' 'spec:spec-decision\.md' 'finish:skills/pr-review-gate/declarations\.md'; do
    rm -rf "$r"; copy_real "$r"
    sed -i.bak "s#${spec#*:}#gone.md#g" "$r/$R/roles/worker/${spec%%:*}.md"
    run check_naming "$r"
    [ "$status" -eq 1 ] || { echo "名指しを消しても通った: $spec" >&2; return 1; }
  done
}

@test "regress: a stage file that tells to read decision-criteria.md fails" {
  local r="$BATS_TEST_TMPDIR/r"
  copy_real "$r"
  printf '\n`skills/develop/references/decision-criteria.md` を読む。\n' >> "$r/$R/roles/worker/implement.md"
  run check_naming "$r"
  [ "$status" -eq 1 ]
  [[ "$output" == *"worker/implement.md"* ]] || return 1
}

@test "regress: a missing listed file fails" {
  local r="$BATS_TEST_TMPDIR/r"
  copy_real "$r"
  rm "$r/$R/spec-decision.md"
  printf 'spec 1\nimplement 1\nfinish 1\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"測定対象が無い: spec の $R/spec-decision.md"* ]] || return 1
}

@test "regress: malformed, duplicate, unknown-stage and incomplete budget files are rejected" {
  local bad
  for bad in 'spec' 'spec 0' 'spec 010' 'spec 1e3' 'spec 100 200' 'spec  100' ' spec 100' 'spec 100 ' 'review 100' \
             $'spec 1\nspec 1\nimplement 1' $'spec 1\nimplement 1'; do
    printf '%s\n' "$bad" > "$BATS_TEST_TMPDIR/b.txt"
    run check_format "$BATS_TEST_TMPDIR/b.txt"
    [ "$status" -eq 1 ] || { echo "受理された: [$bad]" >&2; return 1; }
  done
  run check_format "$BATS_TEST_TMPDIR/none.txt"
  [ "$status" -eq 1 ]
}
