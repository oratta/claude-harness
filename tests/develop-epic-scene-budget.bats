#!/usr/bin/env bats
# 固定した場面集合と独立した予算を照合する。単位は wc -c。
# 守備範囲: 上限超過・欠落・書式・重複・不足・1.1倍超の余白を検出する。
# 同字数/同bytesの内容入れ替えや参照指示の意味は予算では検出しない。
# 場面と段落の意味は仕様/PRレビューで確認し、穴の全封鎖は完了条件にしない。
setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_DIR="$REPO_ROOT/plugins/dev-workflow"
  BUDGET_FILE="$REPO_ROOT/tests/develop-epic-scene-budget.txt"
}

R=skills/develop/references

# scene_files <段> — その段で W が読むファイルを 1 行 1 件で出す。知らない段は 1。
SCENES="nested-entry nested-stop parent-start parent-stopped nested-delegated parent-delegated parent-merge-wait parent-merge-delegated parent-multirepo parent-subagent"
scene_files() {
  case "$1" in
    nested-entry) printf '%s\n' "$R/epic.md" ;;
    nested-stop) scene_files nested-entry; printf '%s\n' "$R/epic-child-stop.md" "$R/epic-keepalive.md" references/child-cache-keepalive.json "$R/parent-pass-criteria.md" ;;
    parent-start) scene_files nested-entry; printf '%s\n' "$R/epic-loop.md" ;;
    parent-stopped) scene_files parent-start; printf '%s\n' "$R/epic-stop.md" "$R/epic-child-stop.md" "$R/parent-pass-criteria.md" "$R/reply-after-idle.md" "$R/epic-keepalive.md" ;;
    nested-delegated) scene_files nested-stop; printf '%s\n' "$R/epic-delegation.md" ;;
    parent-delegated) scene_files parent-stopped; printf '%s\n' "$R/epic-delegation.md" ;;
    parent-merge-wait) scene_files parent-stopped; printf '%s\n' "$R/epic-merge-wait.md" "$R/parent-merge-criteria.md" ;;
    parent-merge-delegated) scene_files parent-merge-wait; printf '%s\n' "$R/epic-delegation.md" ;;
    parent-multirepo) scene_files parent-start; printf '%s\n' "$R/epic-multirepo.md" ;;
    parent-subagent) scene_files parent-start; printf '%s\n' "$R/epic-subagent.md" ;;
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
    if ! printf '%s' "$line" | grep -Eq '^(nested-entry|nested-stop|parent-start|parent-stopped|nested-delegated|parent-delegated|parent-merge-wait|parent-merge-delegated|parent-multirepo|parent-subagent) [1-9][0-9]*$'; then
      echo "予算ファイル $n 行目の形が違う（'<段> <バイト数>' のみ。段は spec / implement / finish）: $line" >&2
      return 1
    fi
    stage=${line% *}
    case "$seen" in *" $stage "*) echo "予算ファイルに段の重複: $stage" >&2; return 1 ;; esac
    seen="$seen$stage "
  done < "$f"
  [ "$n" -eq 10 ] || { echo "予算ファイルの段が 3 つ揃っていない（$n 行）" >&2; return 1; }
}

# scene_total <root> <段> — 一覧のファイルを足したバイト数。無いファイルがあれば stderr に出して 1。
scene_total() {
  local root=$1 stage=$2 p total=0 n
  while IFS= read -r p; do
    [ -f "$root/$p" ] || { echo "測定対象が無い: $stage の $p" >&2; return 1; }
    n=$(wc -c < "$root/$p" | tr -d '[:space:]')
    total=$((total + n))
  done < <(scene_files "$stage")
  echo "$total"
}

# check_budget <root> <budget-file> — 段ごとに上下両方向を判定する。違反は stderr に出して 1。
check_budget() {
  local root=$1 f=$2 rc=0 line stage budget actual
  check_format "$f" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    stage=${line% *}
    budget=${line##* }
    actual=$(scene_total "$root" "$stage") || { rc=1; continue; }
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


# 案内元と必須の参照先。親だけの操作本文を子に読ませない。
edges() {
  cat <<'EDGES'
epic.md epic-loop.md
epic.md epic-subagent.md
epic.md epic-multirepo.md
epic.md epic-stop.md
epic.md epic-child-stop.md
epic.md epic-merge-wait.md
epic.md epic-delegation.md
epic.md epic-keepalive.md
epic-loop.md epic-stop.md
epic-loop.md epic-subagent.md
epic-loop.md epic-multirepo.md
epic-loop.md reply-after-idle.md
epic-loop.md epic-keepalive.md
epic-stop.md epic-child-stop.md
epic-stop.md parent-pass-criteria.md
epic-stop.md epic-delegation.md
epic-stop.md epic-merge-wait.md
epic-stop.md epic-keepalive.md
epic-stop.md epic-loop.md
epic-merge-wait.md parent-merge-criteria.md
epic-merge-wait.md epic-delegation.md
epic-merge-wait.md epic-loop.md
epic-merge-wait.md epic-multirepo.md
epic-subagent.md epic-loop.md
epic-subagent.md epic-stop.md
epic-child-stop.md epic-delegation.md
epic-child-stop.md epic-keepalive.md
epic-child-stop.md parent-pass-criteria.md
reply-after-idle.md epic-keepalive.md
epic-keepalive.md child-cache-keepalive.json
EDGES
}
check_naming() {
  local root=$1 from to rc=0
  while read -r from to; do
    grep -qF "$to" "$root/$R/$from" || { echo "missing edge $from -> $to" >&2; rc=1; }
  done < <(edges)
  if grep -Eq '^([1-9]\. |\*\*(マージ待ちの子|PR トークン上限の子|主の委任|別のリポジトリの子|サブエージェント方式)\*\*)' "$root/$R/epic.md"; then
    echo 'entry contains parent operations' >&2; rc=1
  fi
  if grep -Eq 'epic-(loop|stop|merge-wait|multirepo|subagent)\.md` を読' "$root/$R/epic-child-stop.md"; then
    echo 'child reads parent operations' >&2; rc=1
  fi
  return "$rc"
}
copy_real() {
  local d=$1 s p
  for s in $SCENES; do
    while read -r p; do
      mkdir -p "$d/$(dirname "$p")"
      cp "$PLUGIN_DIR/$p" "$d/$p"
    done < <(scene_files "$s")
  done
}
# 予算checkerのfixtureは構造検査と独立。実ファイルの有無に依存しない。
fixture() {
  local s p
  for s in $SCENES; do
    while read -r p; do
      mkdir -p "$BATS_TEST_TMPDIR/r/$(dirname "$p")"
      printf 'abcdefghij' > "$BATS_TEST_TMPDIR/r/$p"
    done < <(scene_files "$s")
  done
  fixture_budget
}
fixture_budget() {
  local s
  for s in $SCENES; do printf '%s %s\n' "$s" "$(scene_total "$BATS_TEST_TMPDIR/r" "$s")"; done > "$BATS_TEST_TMPDIR/b.txt"
}
@test "real: scene budgets and entry connections" {
  run check_budget "$PLUGIN_DIR" "$BUDGET_FILE"
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  run check_naming "$PLUGIN_DIR"
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
}
@test "real: shared rule bodies each have one develop canonical source" {
  local r="$PLUGIN_DIR/$R"
  [ "$(grep -lF '委任の記録が、①' "$r"/*.md | wc -l | tr -d ' ')" = 1 ]
  grep -qF '委任の記録が、①' "$r/epic-delegation.md"
  ! grep -qF '60 分以上: timeout' "$r/epic-loop.md"
  grep -qF '型どおり' "$r/epic-keepalive.md"
  ! grep -qF 'request_template' "$r/epic-child-stop.md"
}
@test "regress: exact budget and same size content substitution pass" {
  fixture
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 0 ]
  printf '0123456789' > "$BATS_TEST_TMPDIR/r/$R/epic.md"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 0 ]
}
@test "regress: one byte over budget and missing file fail" {
  fixture
  printf x >> "$BATS_TEST_TMPDIR/r/$R/epic.md"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nested-entry"* ]]
  rm "$BATS_TEST_TMPDIR/r/$R/parent-pass-criteria.md"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"parent-pass-criteria.md"* ]]
}
@test "regress: exactly 1.1 times passes but one byte more fails" {
  fixture
  sed 's/nested-entry 10/nested-entry 11/' "$BATS_TEST_TMPDIR/b.txt" > "$BATS_TEST_TMPDIR/bound.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/bound.txt"
  [ "$status" -eq 0 ]
  sed 's/nested-entry 10/nested-entry 12/' "$BATS_TEST_TMPDIR/b.txt" > "$BATS_TEST_TMPDIR/bound.txt"
  run check_budget "$BATS_TEST_TMPDIR/r" "$BATS_TEST_TMPDIR/bound.txt"
  [ "$status" -eq 1 ]
}
@test "regress: malformed unknown duplicate and missing keys fail" {
  local bad
  for bad in 'nested-entry' 'nested-entry 0' 'nested-entry 010' 'nested-entry 1e3' 'nested-entry 1 2' 'nested-entry  10' ' nested-entry 10' 'nested-entry 10 ' 'unknown 10'; do
    fixture
    sed "1s/.*/$bad/" "$BATS_TEST_TMPDIR/b.txt" > "$BATS_TEST_TMPDIR/bad.txt"
    run check_format "$BATS_TEST_TMPDIR/bad.txt"
    [ "$status" -eq 1 ] || return 1
  done
  fixture
  sed '1d' "$BATS_TEST_TMPDIR/b.txt" > "$BATS_TEST_TMPDIR/bad.txt"
  run check_format "$BATS_TEST_TMPDIR/bad.txt"
  [ "$status" -eq 1 ]
  printf 'nested-entry 10\n' >> "$BATS_TEST_TMPDIR/b.txt"
  run check_format "$BATS_TEST_TMPDIR/b.txt"
  [ "$status" -eq 1 ]
  run check_format "$BATS_TEST_TMPDIR/no.txt"
  [ "$status" -eq 1 ]
}
@test "regress: removing each scene connection fails" {
  local from to r="$BATS_TEST_TMPDIR/r"
  copy_real "$r"
  run check_naming "$r"
  [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
  while read -r from to; do
    sed "s/$to/gone.md/g" "$PLUGIN_DIR/$R/$from" > "$r/$R/$from"
    run check_naming "$r"
    [ "$status" -eq 1 ] || { echo "$from -> $to survived" >&2; return 1; }
    cp "$PLUGIN_DIR/$R/$from" "$r/$R/$from"
  done < <(edges)
}
@test "regress: parent operations in entry or child read fail" {
  local r="$BATS_TEST_TMPDIR/r"
  copy_real "$r"
  printf '\n1. launch parent operations\n' >> "$r/$R/epic.md"
  run check_naming "$r"
  [ "$status" -eq 1 ]
  cp "$PLUGIN_DIR/$R/epic.md" "$r/$R/epic.md"
  printf '\nreferences/epic-loop.md を読む。\n' >> "$r/$R/epic-child-stop.md"
  run check_naming "$r"
  [ "$status" -eq 1 ]
}
