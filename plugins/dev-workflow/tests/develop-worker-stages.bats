#!/usr/bin/env bats
#
# W の指示書の索引と段ごとのファイル（issue #556）
# roles/worker.md が手順の本文を持たない索引であること、段の表が実在する段の
# ファイルを指すこと、どの段でも要る規則が common.md にあること、同じ節の見出しが
# 2 か所に無いこと、事前分類表が pre-classification.md にだけあることを検証する。
# 段ごとの読み込み字数（common.md＋段のファイル）は fd 3 に出すだけで、大きさでは落とさない。
# 見出しを変えて同じ節を書いたもの・本文で規則を言い換えて再掲したもの・移すときの
# 文言の変更・段のファイル以外を読む分はこの検査を通るので、PR レビューで見る。
# spec: dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DEVELOP_DIR="${PLUGIN_DIR}/skills/develop"
  INDEX="${DEVELOP_DIR}/references/roles/worker.md"
  WDIR="${DEVELOP_DIR}/references/roles/worker"
  PRE="${DEVELOP_DIR}/references/pre-classification.md"
  SKILL="${DEVELOP_DIR}/SKILL.md"
  AGENT="${PLUGIN_DIR}/agents/worker.md"
}

# 索引の「## 段の表」節の表の本文行（見出し行と区切り行を除く）
stage_rows() {
  awk '/^## 段の表/{f=1; next} /^## /{f=0} f' "$INDEX" | grep '^| ' | grep -v '^| 段 |' | grep -v '^|---'
}

nchars() {
  python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$1"
}

# --- Requirement: W の指示書は索引・共通・段のファイルに分かれている ---

@test "index: worker.md has no code block" {
  ! grep -q '^[[:space:]]*```' "$INDEX" || return 1
}

@test "index: common.md and the three stage files exist" {
  for f in common spec implement finish; do
    [ -f "${WDIR}/${f}.md" ] || { echo "missing: worker/${f}.md"; return 1; }
  done
}

@test "index: spec / implement / finish rows each point to exactly one existing stage file" {
  rows="$(stage_rows)"
  for stage in spec implement finish; do
    row="$(printf '%s\n' "$rows" | grep -F "| \`${stage}\` |")"
    [ "$(printf '%s\n' "$row" | grep -c .)" -eq 1 ] || { echo "row missing or duplicated: $stage"; return 1; }
    files="$(printf '%s' "$row" | grep -oE 'worker/(spec|implement|finish)\.md' | sort -u)"
    [ "$files" = "worker/${stage}.md" ] || { echo "row does not point to exactly worker/${stage}.md: $row"; return 1; }
    [ -f "${WDIR}/${stage}.md" ]
  done
}

@test "common: rules needed by every stage are headings in common.md, not in stage files" {
  for h in 'W がしないこと' '昇格トリップワイヤー' 'コンテキスト上限と手渡し'; do
    grep -q "^## ${h}" "${WDIR}/common.md" || { echo "not in common.md: $h"; return 1; }
    for stage in spec implement finish; do
      if grep -q "^## ${h}" "${WDIR}/${stage}.md"; then echo "in ${stage}.md: $h"; return 1; fi
    done
  done
}

@test "stages: per-stage read size (common.md + stage file) is reported on fd 3" {
  common="$(nchars "${WDIR}/common.md")"
  echo "# 分割前 worker.md 全体: 13416 字" >&3
  echo "# common.md: ${common} 字" >&3
  for stage in spec implement finish; do
    n="$(nchars "${WDIR}/${stage}.md")"
    echo "# ${stage}: $((common + n)) 字（common.md ${common} ＋ ${stage}.md ${n}）" >&3
  done
  echo "# 索引 worker.md: $(nchars "$INDEX") 字 / pre-classification.md: $(nchars "$PRE") 字" >&3
}

@test "headings: each ## heading appears in only one of index, worker/*, pre-classification.md" {
  dup="$(for f in "$INDEX" "${WDIR}/common.md" "${WDIR}/spec.md" "${WDIR}/implement.md" "${WDIR}/finish.md" "$PRE"; do
    grep '^## ' "$f" | LC_ALL=C sort -u
  done | LC_ALL=C sort | LC_ALL=C uniq -d)"
  [ -z "$dup" ] || { echo "duplicated: $dup"; return 1; }
}

# --- Requirement: 事前分類表は W が読まないファイルに置く ---

@test "pre-classification: the 4 table rows are only in pre-classification.md" {
  for row in '| 聖域パス |' '| マージ権限 |' '| 層間契約 |' '| 課金/法務 |'; do
    grep -qF "$row" "$PRE" || { echo "not in pre-classification.md: $row"; return 1; }
    for f in "$INDEX" "${WDIR}/common.md" "${WDIR}/spec.md" "${WDIR}/implement.md" "${WDIR}/finish.md"; do
      if grep -qF "$row" "$f"; then echo "table row in $f: $row"; return 1; fi
    done
  done
}

@test "pre-classification: referrers point to pre-classification.md, not roles/worker.md" {
  for f in skills/develop/SKILL.md skills/develop/references/roles/spec-reviewer.md \
           skills/develop/references/decision-criteria.md skills/pr-review-gate/stages/triage.md \
           references/model-tiers.md README.md; do
    grep -qF 'pre-classification.md' "${PLUGIN_DIR}/${f}" || { echo "no pointer: $f"; return 1; }
    if grep -n '事前分類' "${PLUGIN_DIR}/${f}" | grep -qE '(roles/)?worker\.md'; then
      echo "still points to worker.md for 事前分類: $f"; return 1
    fi
  done
}

# --- Requirement: 本体は W の起動指示と再開指示に段を書く ---

@test "agent: worker.md body reads worker/common.md and the stage named by 段:" {
  body="$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$AGENT")"
  printf '%s' "$body" | grep -qF 'worker/common.md'
  printf '%s' "$body" | grep -qF '段:'
}

@test "common: the implement stage's read set carries the pre-implementation gate (spec decision and R1 APPROVE)" {
  s="$(cat "${WDIR}/common.md" "${WDIR}/implement.md")"
  printf '%s' "$s" | grep -qF '記録先に記録される前に実装へ進まない'
  printf '%s' "$s" | grep -qF 'R1 の APPROVE が記録先に記録されるまで実装に進まない'
  printf '%s' "$s" | grep -qF 'W はそのコメントを確認してから実装に入る'
  grep -qF '## 実装に入る前の確認' "${WDIR}/common.md"
  ! grep -qF '記録されるまで実装に進まない' "${WDIR}/spec.md" || return 1
  grep -qF '`worker/common.md`「実装に入る前の確認」' "${WDIR}/spec.md"
}

@test "skill: the handover's next role carries the W 段: value and the new-session resume uses it" {
  grep -F '| 次に起こす役割 |' "$SKILL" | grep -qF '段:'
  grep -F '手渡し: 不要` なら「次に起こす役割」の入力で初回の W を起こす' "$SKILL" | grep -qF '`段:` の行は「次に起こす役割」に書かれた値を使う'
}

@test "skill: SKILL.md writes 段: spec / implement / finish" {
  for stage in spec implement finish; do
    grep -qF "段: ${stage}" "$SKILL" || { echo "missing: 段: ${stage}"; return 1; }
  done
}
