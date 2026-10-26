#!/usr/bin/env bats
# develop-startup-budget.bats — /develop の起動時に本体が必ず読むファイルの大きさに予算を置く（issue #1224、エピック #1225）
#
# SKILL.md は 2026-09-06 の約 1.1 万字から 2026-10-22 の約 8.1 万字まで、誰も気づかないまま
# 増えた。常時注入の固定分は tests/injection-budget.bats が見ているが、/develop の起動時に
# 読むファイルは対象外だった。ここで編集時に止めて「削るか、予算を動かすか」を PR の diff に出す。
#
# 測るもの（plugins/dev-workflow/ からの相対パス。バイト数は wc -c。文字数はロケール依存で
# CI と手元で値が変わるため使わない）:
#   skills/develop/SKILL.md       本体の手順書。起動時に必ず Read する
#   commands/develop.md           起動した時点でコマンド本文として載る
#   references/codex-develop.md   commands/develop.md が、実行先オプションが無くても Read させる
# 測らないもの: references/codex-develop-explicit.md（実行先を明示したときだけ読む）と、
# SKILL.md が必要なときだけ辿る他の references（どちらも条件付き）。
#
# 予算はファイルごとに持つ（合計にしない）。合計だと、あるファイルを増やしても別のファイルを
# 削れば通ってしまい、SKILL.md だけが増えた今回の事故を検知できない。
# 予算値は tests/develop-startup-budget.txt（1 行 1 ファイル: "<相対パス> <バイト数>"）。
# 閾値をこのファイルに直書きしない。判定は injection-budget.bats と同じ上下両方向:
# 実測が予算を超えたら fail、予算が実測の 1.1 倍を超えても fail（削減 PR に予算の引き下げを
# 強制し、削った分が次の増加の余地として残らないようにする）。
#
# 測定対象が commands/develop.md の実態とずれないよう、commands/develop.md が測定対象の
# 各ファイルを名指ししていること（SKILL.md と codex-develop.md の Read）も確かめる。
#
# 異常系の退行テストは、実 repo のファイルを書き換えず、使い捨ての root と予算ファイルを渡して作る。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_DIR="$REPO_ROOT/plugins/dev-workflow"
  BUDGET_FILE="$REPO_ROOT/tests/develop-startup-budget.txt"
}

# check_format <budget-file> — 全行が "<相対パス> <先頭ゼロなしの正整数>" で、パスの重複が無く、1 行以上あること。
# 違反は stderr に出して 1。
check_format() {
  local f=$1 n=0 line path num seen=" "
  [ -f "$f" ] || { echo "予算ファイルが無い: $f" >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if ! printf '%s' "$line" | grep -Eq '^[^ ]+ [1-9][0-9]*$'; then
      echo "予算ファイル $n 行目の形が違う（'<相対パス> <バイト数>' のみ）: $line" >&2
      return 1
    fi
    path=${line% *}
    case "$seen" in *" $path "*) echo "予算ファイルにパスの重複: $path" >&2; return 1 ;; esac
    seen="$seen$path "
  done < "$f"
  [ "$n" -ge 1 ] || { echo "予算ファイルが空" >&2; return 1; }
}

# check_budget <root> <budget-file> — 各ファイルについて上下両方向を判定する。違反は stderr に出して 1。
check_budget() {
  local root=$1 f=$2 rc=0 line path budget actual
  check_format "$f" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    path=${line% *}
    budget=${line##* }
    if [ ! -f "$root/$path" ]; then
      echo "測定対象が無い: $path" >&2; rc=1; continue
    fi
    actual=$(wc -c < "$root/$path" | tr -d '[:space:]')
    if [ "$actual" -gt "$budget" ]; then
      printf '予算超過: %s 実測 %s > 予算 %s バイト（削るか、予算ファイルを動かして理由を PR に書く）\n' \
        "$path" "$actual" "$budget" >&2
      rc=1
    elif [ $((budget * 10)) -gt $((actual * 11)) ]; then
      printf '予算が緩すぎる: %s 予算 %s > 実測 %s の 1.1 倍（予算を実測に合わせて引き下げる）\n' \
        "$path" "$budget" "$actual" >&2
      rc=1
    fi
  done < "$f"
  return "$rc"
}

# mk_root <dir> <path:bytes>... — 指定バイト数のファイルを持つ使い捨て root を作る。
mk_root() {
  local d=$1 spec p n
  shift
  for spec in "$@"; do
    p=${spec%%:*}; n=${spec##*:}
    mkdir -p "$d/$(dirname "$p")"
    head -c "$n" /dev/zero | tr '\0' 'x' > "$d/$p"
  done
}

# ── 実 repo ───────────────────────────────────────────────

@test "real: budget file lists the three startup files" {
  run check_format "$BUDGET_FILE"
  [ "$status" -eq 0 ]
  [ "$(cut -d' ' -f1 "$BUDGET_FILE" | sort | tr '\n' ' ')" = \
    "commands/develop.md references/codex-develop.md skills/develop/SKILL.md " ]
}

@test "real: every measured file is within budget and the budget is not slack" {
  run check_budget "$PLUGIN_DIR" "$BUDGET_FILE"
  if [ "$status" -ne 0 ]; then printf '%s\n' "$output" >&2; fi
  [ "$status" -eq 0 ]
}

@test "real: commands/develop.md names the SKILL.md and codex-develop.md it makes the body read" {
  local line path
  while IFS= read -r line; do
    path=${line% *}
    [ "$path" = "commands/develop.md" ] && continue
    run grep -cF -- "$path" "$PLUGIN_DIR/commands/develop.md"
    [ "$status" -eq 0 ] || { echo "commands/develop.md が $path を名指ししていない" >&2; return 1; }
  done < "$BUDGET_FILE"
}

# ── 退行テスト（差し替えた一覧）───────────────────────────────

@test "regress: growing one file over its budget fails" {
  mk_root "$BATS_TEST_TMPDIR/r" a/one.md:101 a/two.md:100
  printf 'a/one.md 100\na/two.md 100\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"予算超過: a/one.md"* ]]
}

@test "regress: shrinking another file does not hide growth (per-file, not sum)" {
  mk_root "$BATS_TEST_TMPDIR/r" a/one.md:150 a/two.md:60
  printf 'a/one.md 100\na/two.md 100\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
}

@test "regress: budget above 1.1 times actual fails" {
  mk_root "$BATS_TEST_TMPDIR/r" a/one.md:100
  printf 'a/one.md 111\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"予算が緩すぎる"* ]]
}

@test "regress: budget exactly 1.1 times actual and exactly actual both pass" {
  mk_root "$BATS_TEST_TMPDIR/r" a/one.md:100 a/two.md:100
  printf 'a/one.md 110\na/two.md 100\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 0 ]
}

@test "regress: a measured file that disappeared fails" {
  mk_root "$BATS_TEST_TMPDIR/r" a/one.md:100
  printf 'a/one.md 100\na/gone.md 100\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"測定対象が無い: a/gone.md"* ]]
}

@test "regress: malformed budget lines are rejected" {
  local bad
  for bad in 'a/one.md' 'a/one.md 0' 'a/one.md 010' 'a/one.md 1e3' 'a/one.md 100 200' 'a/one.md  100' ' a/one.md 100' 'a/one.md 100 '; do
    printf '%s\n' "$bad" > "$BATS_TEST_TMPDIR/b.txt"
    run check_format "$BATS_TEST_TMPDIR/b.txt"
    [ "$status" -eq 1 ] || { echo "受理された: [$bad]" >&2; return 1; }
  done
}

@test "regress: empty budget file and duplicate path are rejected" {
  : > "$BATS_TEST_TMPDIR/b.txt"
  run check_format "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  printf 'a/one.md 100\na/one.md 100\n' > "$BATS_TEST_TMPDIR/b.txt"
  run check_format "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
}

@test "regress: missing budget file is rejected" {
  run check_budget "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR/none.txt"
  [ "$status" -eq 1 ]
}

# budget_of <budget-file> <path> — 予算ファイルからそのパスの予算を返す。
budget_of() { awk -v p="$2" '$1 == p { print $2 }' "$1"; }

# 実ファイルの複製に「予算 - 実測 + 1」バイトを足すと、予算に余裕があっても必ず予算超過になる。
# 固定バイト数の追記だと、予算が実測より大きい（1.0〜1.1 倍は許される）ときに誤って通る。
@test "regress: appending budget-minus-actual-plus-1 bytes to a copy of a real file fails, with or without slack" {
  local r="$BATS_TEST_TMPDIR/real" line path p slack budget actual b2
  while IFS= read -r line; do
    path=${line% *}
    mkdir -p "$r/$(dirname "$path")"
    cp "$PLUGIN_DIR/$path" "$r/$path"
  done < "$BUDGET_FILE"
  for p in skills/develop/SKILL.md commands/develop.md; do
    for slack in 0 10; do
      # 予算ファイルの複製で、対象の予算を実測より slack バイト大きくする
      actual=$(wc -c < "$r/$p" | tr -d '[:space:]')
      b2="$BATS_TEST_TMPDIR/b-$slack.txt"
      awk -v p="$p" -v n=$((actual + slack)) '$1 == p { print $1, n; next } { print }' "$BUDGET_FILE" > "$b2"
      budget=$(budget_of "$b2" "$p")
      [ "$budget" -eq $((actual + slack)) ]
      cp "$PLUGIN_DIR/$p" "$r/$p"
      head -c $((budget - actual + 1)) /dev/zero | tr '\0' 'x' >> "$r/$p"
      run check_budget "$r" "$b2"
      [ "$status" -eq 1 ]
      [[ "$output" == *"予算超過: $p"* ]]
      cp "$PLUGIN_DIR/$p" "$r/$p"
    done
  done
}
