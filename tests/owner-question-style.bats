#!/usr/bin/env bats
#
# 主に問いを返す文章の書き方の正本（output-styles/readable.md の節 3）と、短い版
# （rules/communication-style.md の 3 番目）と、正本を参照する各所の文面の検査（issue #1176）。
#
# spec: owner-question-style
#
# 守備範囲: 正本と短い版が決まりの語を持つこと、参照先に旧い型の写しと自前の 1 行目の形が
# 残っていないこと、正本を指すパスの形。個々の発言が型を守っているか、文の良し悪しは見ない。
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  READABLE="${REPO_ROOT}/output-styles/readable.md"
  SHORT="${REPO_ROOT}/rules/communication-style.md"
}

# 正本の節 3（`## 3. ` から次の `## ` の手前まで）
section3() {
  awk '/^## 3\. /{f=1; print; next} /^## /{f=0} f' "$READABLE"
}

# 短い版の 3 番目（`3. ` で始まる行）
short3() {
  grep -E '^3\. ' "$SHORT"
}

# 正本を参照する各所（spec の要件「主に問いを返す各所は正本を参照し、固有の事柄だけを残す」の一覧）
referrers() {
  printf '%s\n' \
    plugins/dev-workflow/skills/develop/SKILL.md \
    plugins/dev-workflow/skills/pr-review-gate/stages/hold.md \
    plugins/dev-workflow/skills/pr-review-gate/stages/pass.md \
    plugins/dev-workflow/references/ci-watch.md \
    rules/one-off-no-script.md \
    plugins/dev-workflow/references/one-off-operations.md \
    plugins/casting/skills/casting/SKILL.md \
    rules/perspective-casting.md
}

@test "canonical: section 3 lists the six steps in order" {
  local s steps
  s="$(section3)"
  [ -n "$s" ]
  steps="$(printf '%s\n' "$s" | grep -E '^[1-6]\. ')"
  [ "$(printf '%s\n' "$steps" | wc -l | tr -d ' ')" -eq 6 ]
  printf '%s\n' "$steps" | sed -n 1p | grep -qE '^1\. \*\*質問'
  printf '%s\n' "$steps" | sed -n 2p | grep -qE '^2\. \*\*主に聞く理由'
  printf '%s\n' "$steps" | sed -n 3p | grep -qE '^3\. \*\*いま困っていること'
  printf '%s\n' "$steps" | sed -n 4p | grep -qE '^4\. \*\*推奨と根拠'
  printf '%s\n' "$steps" | sed -n 5p | grep -qE '^5\. \*\*受け入れるリスク'
  printf '%s\n' "$steps" | sed -n 6p | grep -qE '^6\. \*\*答え方'
}

@test "canonical: three reasons to ask and proceed without asking otherwise" {
  local s; s="$(section3)"
  printf '%s\n' "$s" | grep -qF '主の側にしか答えが無い'
  printf '%s\n' "$s" | grep -qF '決まりで主の承認が要る'
  printf '%s\n' "$s" | grep -qF '主の手でしかできない操作'
  printf '%s\n' "$s" | grep -qF 'どれにも当たらなければ聞かずに自分で決めて進め、事後報告する'
}

@test "canonical: risk has three elements" {
  local s; s="$(section3)"
  printf '%s\n' "$s" | grep -qF '何が起きるか'
  printf '%s\n' "$s" | grep -qF 'どれくらい起きるか'
  printf '%s\n' "$s" | grep -qF '何を調べれば分かるか'
}

@test "canonical: one question per message, no number as subject, details below" {
  local s; s="$(section3)"
  printf '%s\n' "$s" | grep -qF '1 通で聞くのは 1 件'
  printf '%s\n' "$s" | grep -qF '番号を主語にせず'
  printf '%s\n' "$s" | grep -qF '区切って下に置く'
  printf '%s\n' "$s" | grep -qF '確かめ済み'
}

@test "canonical: first line rule, answers excluded, one example" {
  local s; s="$(section3)"
  printf '%s\n' "$s" | grep -qF '1 行目を質問にし'
  printf '%s\n' "$s" | grep -qF '`主がすること: なし`'
  printf '%s\n' "$s" | grep -qF '主の質問に答える発言'
  [ "$(printf '%s\n' "$s" | grep -c '^```')" -eq 2 ]
}

@test "canonical: casting is named only conditionally and owner terms are paraphrased" {
  local line
  line="$(grep -F 'casting' "$READABLE")"
  [ -n "$line" ]
  while IFS= read -r l; do
    [[ "$l" == *"入っていれば"* ]] || return 1
  done <<<"$line"
  section3 | grep -qF '主（'
  section3 | grep -qF '聖域（'
}

@test "canonical and short: the old five-step form is gone" {
  ! grep -qF '目的 → いま取り組んでいる場所' "$READABLE" || return 1
  ! grep -qF 'これを飲めるならAで進める' "$READABLE" || return 1
  ! grep -qF '目的 → いま取り組んでいる場所' "$SHORT" || return 1
  ! grep -qF 'これを飲めるならAで進める' "$SHORT" || return 1
  ! grep -qF '判断依頼は背景から' "$READABLE" || return 1
}

@test "short: item 3 keeps the order, the three reasons and not asking without a reason" {
  local s; s="$(short3)"
  [ -n "$s" ]
  printf '%s\n' "$s" | grep -qF '質問 → 主に聞く理由 → 困りごと → 推奨と根拠 → リスク（被害・頻度） → 答え方'
  printf '%s\n' "$s" | grep -qF '主の側にしか答えが無い'
  printf '%s\n' "$s" | grep -qF '決まりで主の承認が要る'
  printf '%s\n' "$s" | grep -qF '主の手でしかできない操作'
  printf '%s\n' "$s" | grep -qF '理由が無ければ聞かずに'
  printf '%s\n' "$s" | grep -qF '`主がすること: なし`'
  if printf '%s\n' "$s" | grep -qF 'casting'; then
    printf '%s\n' "$s" | grep -qF '入っていれば'
  fi
}

@test "referrers: no copy of the old form and each points at the canonical style" {
  local f
  while IFS= read -r f; do
    if grep -qF '目的 → いま取り組んでいる場所' "${REPO_ROOT}/$f"; then echo "old order: $f"; return 1; fi
    if grep -qF '決めてほしいこと・推奨・受け入れるリスク' "${REPO_ROOT}/$f"; then echo "old items: $f"; return 1; fi
    if grep -qF '「飲めるか」を 1 問だけ' "${REPO_ROOT}/$f"; then echo "old ask: $f"; return 1; fi
    grep -qE 'readable\.md|communication-style' "${REPO_ROOT}/$f" || { echo "no reference: $f"; return 1; }
  done < <(referrers)
}

@test "referrers: readable.md is named by the home path" {
  local f
  while IFS= read -r f; do
    if sed 's|~/\.claude/output-styles/readable\.md||g' "${REPO_ROOT}/$f" | grep -qF 'output-styles/readable.md'; then
      echo "repo-relative path: $f"; return 1
    fi
  done < <(referrers)
}

@test "no document keeps its own first-line form for the owner" {
  local hits
  hits="$(cd "$REPO_ROOT" && git grep -n -F \
    -e '主がすること: このチャンネルで' -e '主がすること: PR #' -e '主がすること: 親のタブで' \
    -e '主がすること: 子のタブで' -e '主がすること: <どの画面' \
    -- plugins rules ':!plugins/*/changes/*' ':!plugins/*/tests/*' || true)"
  [ -z "$hits" ] || { echo "$hits"; return 1; }
  if grep -qF '`主がすること:` の規定' "${REPO_ROOT}/plugins/dev-workflow/skills/develop/SKILL.md"; then return 1; fi
}
