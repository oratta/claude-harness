#!/usr/bin/env bats
#
# 仕様化判断の記録と、書いた仕様の実装前レビュー（issue #191 → #203 で develop 構造に移行）
#
# develop スキルでは、W（references/roles/worker/spec.md）が仕様化判断を固定書式で記録先に記録し、
# 本体の 1 ループ（SKILL.md）が W の openspec new change と W の再開（apply）の間に R1
# （references/roles/spec-reviewer.md）の仕様レビューを挟むことを検証する。
# 既存文（事前分類節・残量モード行）で偽合格しないよう、節を切り出してから grep する。
#
# spec: dev-workflow-spec-review

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  WORKER="${PLUGIN_DIR}/skills/develop/references/roles/worker/spec.md"
  REF="${PLUGIN_DIR}/skills/develop/references/roles/spec-reviewer.md"
  FIX_CHECK="${PLUGIN_DIR}/skills/develop/references/fix-check.md"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }
# worker/spec.md の仕様化判断節
decision_sec() { section "$WORKER" '仕様化判断'; }
# SKILL.md の 1 ループ節
loop_sec() { section "$SKILL" '1 ループ'; }
# SKILL.md の実行モード節
mode_sec() { section "$SKILL" '実行モード'; }
# spec-reviewer.md の条件の段の節（#1121）
cond_sec() { section "$REF" '指摘の条件を決める段'; }
# fix-check.md の条件の確かめの節（#1121）
fix_cond_sec() { section "$FIX_CHECK" '残った指摘の条件を確かめる'; }
# SKILL.md の 1 ループの (2)
step2_sec() { loop_sec | awk '/^\(2\) /{f=1} /^\(3\) /{f=0} f'; }

# --- Requirement: 仕様化要否の判定結果を固定書式で issue に記録する ---

@test "worker: records decision with exact first-line regex" {
  decision_sec | grep -qF '^仕様化判断: (する|しない)$'
}

@test "worker: posts the record to the record target via gh" {
  decision_sec | grep -qE 'gh (issue|pr) comment'
}

@test "worker: forbids proceeding before the record" {
  decision_sec | grep -qE '記録(する|して)(前|まで)|記録せずに.*進(ま|んでは)'
}

@test "mode table / unmanned: decision record is not exempt" {
  mode_sec | grep -qE '(仕様化判断|判定の記録).*免除しない'
}

@test "references: latest-one rule and PR->issue resolution rule with PR-comment fallback" {
  [ -f "$REF" ]
  grep -q '最新' "$REF"
  grep -qE 'Closes.*Fixes.*Refs|Refs.*Closes' "$REF"
  grep -q 'PR 自身のコメント' "$REF"
}

@test "criteria: step B section points at the record format" {
  awk '/^## Step B/{f=1} /^## Step C/{f=0} f' "$CRITERIA" | grep -q '仕様化判断'
}

# --- Requirement: 書いた仕様は実装前に別コンテキストがレビューする ---

@test "loop: R1 review sits between W's openspec new change and W's apply" {
  loop_sec | grep -q 'openspec new change'
  ff="$(loop_sec | grep -n 'openspec new change' | head -1 | cut -d: -f1)"
  rev="$(loop_sec | grep -n '仕様レビュー' | head -1 | cut -d: -f1)"
  apply="$(loop_sec | grep -n 'apply' | head -1 | cut -d: -f1)"
  [ -n "$ff" ] && [ -n "$rev" ] && [ -n "$apply" ]
  [ "$ff" -lt "$rev" ] && [ "$rev" -lt "$apply" ]
}

@test "loop: references spec-reviewer.md and blocks apply until APPROVE is recorded" {
  loop_sec | grep -q 'references/roles/spec-reviewer.md'
  loop_sec | grep -q 'APPROVE'
  loop_sec | grep -qE 'まで.*(apply|実装).*(進まない|進んではならない|入らない|再開しない)'
}

@test "worker: degraded path (openspec CLI only) also returns for the review" {
  grep -A3 'openspec CLI で artifact を作る場合' "$WORKER" | grep -q '仕様レビュー'
  grep -A3 'openspec CLI で artifact を作る場合' "$WORKER" | grep -q 'return'
}

@test "loop: interactive multi-change handling reviews each change" {
  grep -qE 'change ごと.*仕様レビュー|仕様レビュー.*change ごと' "$SKILL" "$WORKER"
}

# --- Requirement: 仕様レビューの観点は既存 spec との整合と受け入れ条件の一意性を含む ---

@test "references: six review criteria are listed" {
  grep -q '一意' "$REF"
  grep -q '守備範囲' "$REF"
  grep -qE '既存.*openspec/specs' "$REF"
  grep -qE 'config|引数' "$REF"
  grep -qE '前提' "$REF"
  grep -qE 'proposal.*specs.*design.*tasks' "$REF"
  grep -qE 'spec.*パス.*要件名|要件名.*パス' "$REF"
}

@test "references: read-only reviewer and grep-first" {
  grep -qE '読み取り専用|変更しない' "$REF"
  grep -q 'grep' "$REF"
}

# --- Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する ---

@test "review cap: default 2 rounds, needs-approval only when the approach must be re-chosen" {
  { loop_sec; cat "$REF"; } | grep -qE '2 ?周'
  { loop_sec; cat "$REF"; } | grep -q 'needs-approval'
  { loop_sec; cat "$REF"; } | grep -q 'AskUserQuestion'
  { loop_sec; cat "$REF"; } | grep -qE 'unmanned.*(サイクル|終了)'
  # 3 周目の禁止は直し方の判定を通す続行に置き換わった（#722）
  run grep -qE '3 ?周目.*(例外|設けない)' "$REF"
  [ "$status" -ne 0 ]
}

@test "review cap (#722): spec-reviewer.md and SKILL.md (2) continue without asking when the fix is settled" {
  # SKILL.md の 1 ループの (2)（列 0 の "(2) " から列 0 の "(3) " の手前まで）
  step2="$(loop_sec | awk '/^\(2\) /{f=1} /^\(3\) /{f=0} f')"
  [ -n "$step2" ] || { echo "no step (2)"; return 1; }
  for token in '直し方が決まっている' '主に聞かず次の周を回す' '方針の選び直し' '`pr-token-budget.sh` が exit 2'; do
    grep -qF "$token" "$REF" || { echo "spec-reviewer.md lacks: $token"; return 1; }
    echo "$step2" | grep -qF "$token" || { echo "SKILL.md (2) lacks: $token"; return 1; }
  done
  # 判定と書式の正本は develop の references/fix-check.md の節（#1222 で SKILL.md から移した）で、spec-reviewer.md は書式を再掲しない
  grep -F 'レビューの周を主に聞かずに続ける（直し方の判定）' "$REF" | grep -qF 'references/fix-check.md'
  run grep -qF '^直し方の判定:' "$REF"
  [ "$status" -ne 0 ]
  run grep -qF '^主に聞かずに回した周:' "$REF"
  [ "$status" -ne 0 ]
}

# --- Requirement: 仕様レビューの BLOCKER は指摘の条件がいつ成り立つかを決めてから残す（#1121） ---

@test "condition stage (#1121): spec-reviewer.md has the five-row table and points at triage stage B" {
  s="$(cond_sec)"
  [ -n "$s" ] || { echo "no section"; return 1; }
  echo "$s" | grep -qF '条件がいつ成り立つか'
  echo "$s" | grep -qF '`stages/triage.md` の段 B'
  for row in \
    '| 条件を書けない | 捨てる。理由を 1 行残す |' \
    '| いまのエピック（無ければ記録先）の範囲で成り立つ | BLOCKER に残す |' \
    '| 後で成り立つ | NOTE に条件を書く |' \
    '| 成り立つ予定が無い | 捨てる。条件と理由を 1 行残す |' \
    '| R1 が決められない | BLOCKER に残し `条件の問い:` を添える |'; do
    echo "$s" | grep -qF -- "$row" || { echo "lacks row: $row"; return 1; }
  done
}

@test "condition stage (#1121): evidence is limited and artifact assumptions are not evidence" {
  s="$(cond_sec)"
  echo "$s" | grep -qF 'エピックと記録先の本文、受け入れ条件、コード、本文の節 `## 条件の答え` の行に限る'
  echo "$s" | grep -qF 'change の artifact に書かれた想定は主の答えではないので、根拠にしない'
  echo "$s" | grep -qF '問いを付け直さず「いまの範囲で成り立つ」に当てる'
}

@test "condition stage (#1121): the question asks only about the condition and R1 stays read-only" {
  s="$(cond_sec)"
  echo "$s" | grep -qF '同じ枠を別アカウントで使い回すことは、今回あるか。今回は無くても後であるか'
  echo "$s" | grep -qF '指摘を直すか・捨ててよいかを問わない'
  echo "$s" | grep -qF '問いを主に聞かず、`## 条件の答え` を書かず、issue を作らない'
}

@test "condition stage (#1121): the flatmate #702 finding is the worked example" {
  s="$(cond_sec)"
  echo "$s" | grep -qF 'flatmate #702'
  echo "$s" | grep -qF '新しいアカウントは新しい枠を作る。同じ枠を別アカウントで使い回さない'
  echo "$s" | grep -F 'flatmate #702' | grep -qF '成り立つ予定が無い'
  echo "$s" | grep -qF '`捨てた指摘:`'
}

@test "condition stage (#1121): defects of the document itself stay as BLOCKERs and the list is closed" {
  s="$(cond_sec)"
  line="$(echo "$s" | grep -F '文書そのものの欠陥')"
  [ -n "$line" ]
  for k in '観点 1' '観点 2' '観点 4' '観点 5' '観点 6' '「いまの範囲で成り立つ」に当たる' 'この列挙は網羅' '観点 3 の指摘は条件'; do
    echo "$line" | grep -qF "$k" || { echo "lacks: $k"; return 1; }
  done
}

@test "condition stage (#1121): the stage states its scope" {
  s="$(cond_sec)"
  line="$(echo "$s" | grep -F 'この段の守備範囲は')"
  [ -n "$line" ]
  for k in 'R1 自身が見つけた指摘' '実装を止めること' '通ることを許す' '判定の誤りが 1 件も無いことをこの段の完了条件にしない'; do
    echo "$line" | grep -qF "$k" || { echo "lacks: $k"; return 1; }
  done
}

@test "condition stage (#1121): input, output, record, verdict and round-cap sections use the stage" {
  input="$(section "$REF" 'レビュアーへの入力')"
  echo "$input" | grep -qF '`## 条件の答え`'
  echo "$input" | grep -qF 'エピックの本文'
  # 出力書式の節はコードブロックに "## " の行を持つので、次の節の見出しまでを切り出す
  output="$(awk '/^## 出力書式/{f=1} /^## 結果を記録先に/{f=0} f' "$REF")"
  echo "$output" | grep -qF '成り立つ判定'
  echo "$output" | grep -qF '`条件の問い: <問い>`'
  echo "$output" | grep -F '判定基準' | grep -qF '指摘の条件を決める段'
  record="$(section "$REF" '結果を記録先に記録する')"
  echo "$record" | grep -qF '`捨てた指摘:`'
  echo "$record" | grep -qF '照合に使わない'
  cap="$(section "$REF" '往復の上限')"
  echo "$cap" | grep -qF '指摘の条件を決める段'
  echo "$cap" | grep -qF '当て直し'
  echo "$cap" | grep -qF 'この 2 つは方針の問いの数で、条件の問いは数えない'
}

# --- Requirement: 仕様レビューの残った指摘は直し方の判定の前に条件を確かめる（#1121） ---

@test "condition check (#1121): fix-check.md has the section exactly once and the two timings" {
  [ "$(grep -c '^## 残った指摘の条件を確かめる' "$FIX_CHECK")" -eq 1 ]
  s="$(fix_cond_sec)"
  echo "$s" | grep -qF '周によらず W を再開する前'
  echo "$s" | grep -qF '2 周目以降の周の終わりに BLOCKER が残ったとき、決める役を起こす前'
}

@test "condition check (#1121): fix-check.md tells when to read the file including the new cases" {
  head -3 "$FIX_CHECK" | grep -qF '`条件の問い:`'
  head -3 "$FIX_CHECK" | grep -qF '後で成り立つ指摘'
}

@test "condition check (#1121): rechecking is by R1, not counted as a round, and the budget check stays" {
  s="$(fix_cond_sec)"
  echo "$s" | grep -qF '当て直しは周に数えない'
  echo "$s" | grep -qF 'W を再開せず決める役も起こさず、R1 に指摘の当て直しをさせる'
  echo "$s" | grep -qF '条件の判定が書かれていない BLOCKER'
  echo "$s" | grep -qF '最新の `仕様レビュー:` のコメントより後に `## 条件の答え` へ行が足された'
  echo "$s" | grep -qF 'R1 を起こす前の PR トークン上限の計測は省かない'
  echo "$s" | grep -qF '結果コメントの周の欄は同じ周のまま'
}

@test "condition check (#1121): findings that will not hold are dropped before the fix verdict" {
  s="$(fix_cond_sec)"
  echo "$s" | grep -qF '成り立つ予定が無い指摘は判定に回さず捨てる'
  echo "$s" | grep -qF '当て直しの結果が `APPROVE` なら直し方の判定を起こさず (3) へ進む'
  echo "$s" | grep -qF '残った指摘の原文'
}

@test "condition check (#1121): the question to the owner, unmanned handover and label removal" {
  s="$(fix_cond_sec)"
  echo "$s" | grep -qF '指摘を直すか・捨ててよいかを聞かない'
  echo "$s" | grep -qF 'AskUserQuestion'
  echo "$s" | grep -qF '問いを PR（無ければ記録先）のコメントに書き'
  echo "$s" | grep -qF '待ち理由 `条件の問い`'
  echo "$s" | grep -qF '再開の手順 2 で得た答えを本体が同じ節に足して R1 に当て直させる'
  echo "$s" | grep -qF '本体は答えを節に足したら、ラベルの付け先から `needs-approval` を外す'
  echo "$s" | grep -qF 'R1（当て直し）'
}

@test "condition check (#1121): the NOTE sentence borrows the out-of-scope filing rule" {
  fix_cond_sec | grep -F '後で成り立つ指摘' | grep -qF '「範囲外の問題の起票」の行き先の決め方（段 B の表・段 D・段 E の問い。エピックの子なら段 C も）を借りて本体が決める'
  fix_cond_sec | grep -qF '起票してよいかを主に聞かない'
}

@test "condition check (#1121): not applied to G needs-fix-check and the scope is written" {
  s="$(fix_cond_sec)"
  echo "$s" | grep -qF '`needs-fix-check` には当てない'
  line="$(echo "$s" | grep -F 'この手順の守備範囲は')"
  [ -n "$line" ]
  for k in 'R1 の結果の BLOCKER' '「どの直し方か」の問いに回してしまうこと' '本体が疑わずに判定へ回す' '判定の誤りが 1 件も無いことをこの手順の完了条件にしない'; do
    echo "$line" | grep -qF "$k" || { echo "lacks: $k"; return 1; }
  done
}

@test "condition check (#1121): the two-question rule counts policy questions only" {
  section "$FIX_CHECK" 'レビューの周を主に聞かずに続ける（直し方の判定）' | grep -qF 'この 2 つは方針を聞くときの数で、指摘の条件を聞く問い（節「残った指摘の条件を確かめる」）は数えない'
}

@test "condition check (#1121): SKILL.md (2) points at the section and passes the condition answers" {
  s="$(step2_sec)"
  line="$(echo "$s" | grep -F '残った指摘の条件を確かめる')"
  [ -n "$line" ] || { echo "no line"; return 1; }
  echo "$line" | grep -qF '`references/fix-check.md`'
  echo "$line" | grep -qF 'Read'
  echo "$line" | grep -qF '直し方の判定の前'
  echo "$line" | grep -qF '成り立つ予定が無い指摘は判定に回さず捨てる'
  echo "$s" | grep -F '`## 条件の答え`' | grep -qF '依頼文に入れる'
}

@test "references: result comment format and posting steps live in spec-reviewer.md" {
  grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$' "$REF"
  grep -qE 'gh (issue|pr) comment' "$REF"
  grep -qE '周回|周目' "$REF"
}

# --- Requirement: 仕様レビュアーのモデルは役割で選ぶ ---

@test "review model: explicit model, default opus, decider type instead of model fable" {
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -q 'model'
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -q '`opus`'
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -qF 'dev-workflow:decider'
  # R1 を general-purpose + model: fable で立てる指示は残さない
  ! grep -qE '^- \*\*モデルは必ず明示する\*\*.*は `fable`（聖域パスだけでは上げない）' "$REF" || return 1
  grep -qF '`general-purpose` に `model: fable` を付けない' "$REF"
}

@test "review record: the decider route returns instead of posting and the main agent posts it" {
  grep -qF 'dev-workflow:decider' "$REF"
  grep -qF '本体が同じ書式で代理投稿する' "$REF"
  grep -qF 'レビュアー fable（dev-workflow:decider）・本体が代理投稿' "$REF"
  # 記録先の本文とコメントは呼び出し側が入力文に貼る
  grep -qF '入力文に貼り付けて渡す' "$REF"
  # SKILL.md の 1 ループ (2) と「本体がやること」にも同じ例外がある
  grep -qF 'その return は本体が同じ書式で代理投稿する' "$SKILL"
  grep -qF '投稿せず return し、本体が同じ書式で代理投稿する' "$SKILL"
}

@test "review model: reserve only for automatic runs, exhausted for all paths" {
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -qE 'reserve.*自動実行'
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -qE 'exhausted.*(全経路|すべて)'
}

# --- 配布 ---

@test "manifest: description mentions develop and not the retired issue wording" {
  jq -r '.description' "$MANIFEST" | grep -q 'develop'
  ! jq -r '.description' "$MANIFEST" | grep -q 'github-''issue' || return 1
}

@test "skill frontmatter: description mentions spec review" {
  awk '/^description:/{print; exit}' "$SKILL" | grep -q '仕様レビュー'
}
