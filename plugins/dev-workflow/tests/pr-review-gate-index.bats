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
  ! grep -q '^[[:space:]]*```' "$SKILL" || return 1
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
  ! grep -qE '^#{3,4} [0-9](-[0-9a-z])?\. ' "$SKILL" || return 1
}

@test "stages: each stage file has an entry condition and an exit" {
  for f in stages/prepare stages/review-run stages/reviewer-brief stages/triage stages/pass stages/hold declarations; do
    grep -q '^## 入口' "${GATE_DIR}/${f}.md" || { echo "no entry: $f"; return 1; }
    grep -q '^## 出口' "${GATE_DIR}/${f}.md" || { echo "no exit: $f"; return 1; }
  done
}

@test "stages: each conditional detail opens with its read condition and ends with its exit" {
  local count=0 f name first last
  for f in "${GATE_DIR}"/stages/*.md; do
    name="$(basename "$f" .md)"
    case "$name" in prepare|review-run|reviewer-brief|triage|pass|hold) continue ;; esac
    count=$((count + 1))
    # 1 行目はタイトル、その次の非空行が「入口:」
    [ "$(head -1 "$f")" = "# ${name} — pr-review-gate" ] || { echo "title: $name"; return 1; }
    first="$(sed -n '2,$p' "$f" | grep -v '^[[:space:]]*$' | head -1)"
    [[ "$first" == 入口:\ * ]] || { echo "entry not first: $name: $first"; return 1; }
    last="$(grep -v '^[[:space:]]*$' "$f" | tail -1)"
    [[ "$last" == 出口:\ * ]] || { echo "exit not last: $name: $last"; return 1; }
    [ "$(grep -c '^入口: ' "$f")" -eq 1 ] || { echo "entry count: $name"; return 1; }
    [ "$(grep -c '^出口: ' "$f")" -eq 1 ] || { echo "exit count: $name"; return 1; }
  done
  [ "$count" -eq 22 ] || { echo "detail count: $count"; return 1; }
}

# --- Requirement: develop 以外で本体がスキルを直接使うときは索引から段ごとに読む ---

@test "index: direct-use section names prepare.md first and hold.md for resuming" {
  sec="$(awk '/^## develop 以外で本体が直接使うとき/{f=1; next} /^## /{f=0} f' "$SKILL")"
  printf '%s' "$sec" | grep -qF 'stages/prepare.md'
  printf '%s' "$sec" | grep -qF 'stages/hold.md'
  printf '%s' "$sec" | grep -qF '出口'
}

# --- issue #1708: 分割後の入口条件と参照先 ---

@test "routing (#1708): gate-triage accepts every round and points to convergence rules" {
  local file="${GATE_DIR}/stages/gate-triage.md"
  grep '^入口:' "$file" | grep -qF '周の数に関係なく'
  ! grep -qF '入口: 一周目' "$file" || return 1
  grep -qF '`stages/triage-convergence.md` の周の終わりの段落' "$file"
  grep -qF '`stages/triage-convergence.md` の混在の段落' "$file"
  ! grep -qE 'pr-review-gate 手順 2-1 の(周の終わり|混在)の段落' "$file" || return 1
}

@test "routing (#1708): carryover reads record selection even when a judgment already exists" {
  local file="${GATE_DIR}/stages/carryover.md" line
  for line in "$(grep '^入口:' "$file")" "$(grep '^終了コード 4 のとき' "$file")" "$(grep '^出口:' "$file")"; do
    printf '%s' "$line" | grep -qF '判定の記録の有無にかかわらず'
    printf '%s' "$line" | grep -qF '`stages/carryover-judge.md` の「記録の選び方」'
  done
  grep '^入口:' "${GATE_DIR}/stages/carryover-judge.md" | grep -qF '判定の記録を選ぶとき'
  ! grep -qF '回す条件を満たすときだけ' "$file" || return 1
}

@test "routing (#1708): carryover references existing judge and no-point sections" {
  local file="${GATE_DIR}/stages/carryover.md"
  ! grep -qE '下の「終了コード 4 の判定役」|下の 6-0' "$file" || return 1
  [ "$(grep -cF 'stages/carryover-judge.md` の「終了コード 4 の判定役」' "$file")" -eq 2 ]
  grep '^論点なしの確認の記録' "$file" | grep -qF '`stages/no-point-check.md` の 6-0'
  grep -q '^##### 終了コード 4 の判定役' "${GATE_DIR}/stages/carryover-judge.md"
  grep -q '^#### 6-0\.' "${GATE_DIR}/stages/no-point-check.md"
}

@test "routing (#1708): callers point directly to carryover for step 3-c" {
  local file
  for file in pass prepare triage; do
    grep '^このファイルが番号で指す' "${GATE_DIR}/stages/${file}.md" | grep -qF '`stages/carryover.md`（手順 3-c）'
    ! grep -qF '`stages/hold.md`（手順 3-c・6）' "${GATE_DIR}/stages/${file}.md" || return 1
  done
  grep '^..照合と振り分けのあと' "${GATE_DIR}/stages/pass.md" | grep -qF '`stages/carryover.md` を読んで手順 3-c'
  grep '^..保留の解除のあと' "${GATE_DIR}/stages/pass.md" | grep -qF '`stages/carryover.md` の 3-c'
}
