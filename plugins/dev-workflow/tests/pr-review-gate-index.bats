#!/usr/bin/env bats
#
# pr-review-gate の索引と段ごとのファイル（issue #553）
# SKILL.md が手順の本文を持たない索引であること、段の表と手順番号の対応表が
# 実在する段のファイルを指すこと、同じ手順の見出しが 2 か所に無いこと、
# description が変わっていないことを検証する。
# 見出し以外の本文で規則を言い換えて再掲したものはこの検査を通るので、PR レビューで見る。
# spec: dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  GATE_DIR="${PLUGIN_DIR}/skills/pr-review-gate"
  SKILL="${GATE_DIR}/SKILL.md"
}

# 索引の「## 段の表」節の表の本文行（見出し行と区切り行を除く）
stage_rows() {
  awk '/^## 段の表/{f=1; next} /^## /{f=0} f' "$SKILL" | grep '^| ' | grep -v '^| 段 |' | grep -v '^|---'
}

# 索引の「## 手順番号の対応表」節の表の本文行
map_rows() {
  awk '/^## 手順番号の対応表/{f=1; next} /^## /{f=0} f' "$SKILL" | grep '^| ' | grep -v '^| 手順 |' | grep -v '^|---'
}

# pr-review-gate 配下の全 .md から手順の見出し行を集める
step_headings() {
  find "$GATE_DIR" -name '*.md' -print0 | xargs -0 grep -hE '^#{3,4} [0-9](-[0-9a-z])?\. '
}

# --- Requirement: SKILL.md は索引で、手順の本文を持たない ---

@test "index: SKILL.md is 10,000 bytes or less" {
  [ "$(wc -c < "$SKILL")" -le 10000 ]
}

@test "index: SKILL.md has no code block" {
  ! grep -q '^[[:space:]]*```' "$SKILL"
}

@test "index: description is unchanged" {
  expected='description: PR を作成したら必ず通す品質ゲート。「PR を作った」「レビューして」「マージまで進めて」「auto-merge に載せたい」ときに必ず読み込む。保留中の PR の再開（「主の回答が来た」「リスクを許容する/しない」「動作確認の結果を伝える」「保留を進めて」「レビュー指摘を直したので再レビュー」）も必ずこのスキルで復帰手順を確認する。このゲートを通っていない PR は主の承認なしにマージしてはならない。'
  actual="$(awk '/^description:/{print; exit}' "$SKILL")"
  [ "$actual" = "$expected" ]
}

@test "index: stage files exist" {
  for f in prepare review-run reviewer-brief triage pass hold; do
    [ -f "${GATE_DIR}/stages/${f}.md" ]
  done
  [ -f "${GATE_DIR}/declarations.md" ]
}

@test "index: each stage-table row points to exactly one existing stage file" {
  rows="$(stage_rows)"
  [ "$(printf '%s\n' "$rows" | grep -c .)" -eq 6 ]
  while IFS= read -r row; do
    n="$(printf '%s' "$row" | grep -oE 'stages/[a-z-]+\.md' | sort -u | wc -l | tr -d ' ')"
    [ "$n" -eq 1 ] || { echo "row does not point to exactly one stage file: $row"; return 1; }
    f="$(printf '%s' "$row" | grep -oE 'stages/[a-z-]+\.md' | head -1)"
    [ -f "${GATE_DIR}/${f}" ] || { echo "missing: $f"; return 1; }
  done <<< "$rows"
}

@test "index: step map covers 1, 2-0, 2-1 (3 rows), 2-2, 3, 3-b, 3-c, 4, 5, 6" {
  rows="$(map_rows)"
  for id in 1 2-0 2-2 3 3-b 3-c 4 5 6; do
    [ "$(printf '%s\n' "$rows" | grep -c "^| ${id} |")" -eq 1 ] || { echo "missing or duplicated: $id"; return 1; }
  done
  [ "$(printf '%s\n' "$rows" | grep -c '^| 2-1 |')" -eq 3 ]
  printf '%s\n' "$rows" | grep '^| 2-1 |' | grep -qF '2-1. レビューの実行（レビュー実行者）'
  printf '%s\n' "$rows" | grep '^| 2-1 |' | grep -qF '2-1. レビューの実行（レビュアー向け指示）'
  printf '%s\n' "$rows" | grep '^| 2-1 |' | grep -qF '2-1. レビューの実行（止める判定と仕分け）'
}

@test "index: each step-map row's file has that heading" {
  while IFS= read -r row; do
    heading="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')"
    f="$(printf '%s' "$row" | grep -oE '(stages/[a-z-]+|declarations)\.md' | head -1)"
    [ -n "$f" ] && [ -f "${GATE_DIR}/${f}" ] || { echo "bad file in row: $row"; return 1; }
    grep -qE "^#{3,4} " "${GATE_DIR}/${f}"
    grep -E '^#{3,4} ' "${GATE_DIR}/${f}" | sed -E 's/^#{3,4} //' | grep -qxF "$heading" \
      || { echo "heading '$heading' not in $f"; return 1; }
  done <<< "$(map_rows)"
}

# --- Requirement: 同じ手順を 2 か所に書かない ---

@test "headings: each step heading appears in exactly one file, once" {
  # macOS の uniq は UTF-8 のロケールで 2-1 の括弧書きの違いを同じ行とみなすので、バイト比較にする
  dup="$(step_headings | LC_ALL=C sort | LC_ALL=C uniq -d)"
  [ -z "$dup" ] || { echo "duplicated: $dup"; return 1; }
}

@test "headings: SKILL.md has no step heading" {
  ! grep -qE '^#{3,4} [0-9](-[0-9a-z])?\. ' "$SKILL"
}

@test "stages: each stage file has an entry condition and an exit" {
  for f in stages/prepare stages/review-run stages/reviewer-brief stages/triage stages/pass stages/hold declarations; do
    grep -q '^## 入口' "${GATE_DIR}/${f}.md" || { echo "no entry: $f"; return 1; }
    grep -q '^## 出口' "${GATE_DIR}/${f}.md" || { echo "no exit: $f"; return 1; }
  done
}

# --- Requirement: develop 以外で本体がスキルを直接使うときは索引から段ごとに読む ---

@test "index: direct-use section names prepare.md first and hold.md for resuming" {
  sec="$(awk '/^## develop 以外で本体が直接使うとき/{f=1; next} /^## /{f=0} f' "$SKILL")"
  printf '%s' "$sec" | grep -qF 'stages/prepare.md'
  printf '%s' "$sec" | grep -qF 'stages/hold.md'
  printf '%s' "$sec" | grep -qF '出口'
}
