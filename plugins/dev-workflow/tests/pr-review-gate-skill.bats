#!/usr/bin/env bats
#
# pr-review-gate スキルの移植検証（issue #82）
#
# flatmate PR #232 の正本を dev-workflow プラグインへ昇格したもの。
# 手順の骨格（6手順・ラベル体系・fail-closed）が flatmate 版と同一であること、
# flatmate 固有の仕組みへの無条件参照が無いこと（リポ非依存）、
# flatmate issue #240 の収束ルール（2周キャップ・差分限定再レビュー・blocking 限定・
# リスク許容リンクの真正性確認・承認待ち中の並行動作確認）が織り込まれていることを検証する。
#
# spec: dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# --- Requirement: pr-review-gate スキルがプラグインとして全リポに配布される ---

@test "skill: SKILL.md exists" {
  [ -f "$SKILL" ]
}

@test "skill: frontmatter declares name pr-review-gate" {
  head -10 "$SKILL" | grep -q '^name: pr-review-gate$'
}

@test "skill: description contains trigger phrases (create-PR / review / merge / resume-pending)" {
  desc="$(awk '/^description:/{print; exit}' "$SKILL")"
  printf '%s' "$desc" | grep -q 'PR'
  printf '%s' "$desc" | grep -q 'レビュー'
  printf '%s' "$desc" | grep -q 'マージ'
  printf '%s' "$desc" | grep -q '保留'
}

@test "manifest: plugin.json registers ./skills/pr-review-gate" {
  jq -e '.skills | index("./skills/pr-review-gate")' "$MANIFEST" >/dev/null
}

@test "manifest: version bumped above 1.6.2" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$v" != "1.6.2" ]
  highest="$(printf '1.6.2\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "manifest: marketplace entry version matches plugin.json" {
  v="$(jq -r '.version' "$MANIFEST")"
  m="$(jq -r '.plugins[] | select(.name == "dev-workflow") | .version' "$MARKETPLACE")"
  [ "$m" = "$v" ]
}

@test "skill: keeps the 6-step skeleton of the flatmate original" {
  grep -qF '### 1. 前提を揃える' "$SKILL"
  grep -qF '### 2. レビュー' "$SKILL"
  grep -qF '### 3. リスク宣言' "$SKILL"
  grep -qF '### 4. 動作確認' "$SKILL"
  grep -qF '### 5. 合格処理' "$SKILL"
  grep -qF '### 6. 保留処理' "$SKILL"
}

@test "skill: keeps the label vocabulary" {
  grep -qF 'agent-review:passed' "$SKILL"
  grep -qF 'agent-review:pending' "$SKILL"
  grep -qF 'agent-review:failed' "$SKILL"
  grep -qF 'needs-approval' "$SKILL"
}

@test "skill: keeps fail-closed principle with HEAD SHA verification" {
  grep -q 'fail-closed' "$SKILL"
  grep -qF 'HEAD_SHA' "$SKILL"
  # 宣言・証拠コメントの実在を API で実測してから passed を付ける規定
  grep -qF '.head.sha' "$SKILL"
}

# --- Requirement: スキルはリポ非依存で、flatmate 固有の仕組みには条件分岐で対応する ---

@test "portability: no hardcoded flatmate repo URL" {
  ! grep -q 'genetta-inc/flatmate' "$SKILL" || return 1
}

@test "portability: no reference to flatmate-only machinery" {
  ! grep -q 'pending-mirror\.sh' "$SKILL" || return 1
  ! grep -q 'pending-owner\.md' "$SKILL" || return 1
  ! grep -q 'channel-reply-policy' "$SKILL" || return 1
  ! grep -q 'agent-loop-steps\.md' "$SKILL" || return 1
}

@test "portability: degraded behavior for repos without auto-merge is specified" {
  grep -q '未配備' "$SKILL"
}

@test "portability: direct merge by LLM remains forbidden" {
  # gh pr merge / merge API の直叩き禁止が明文化されている
  grep -q 'gh pr merge' "$SKILL"
  grep -q '禁止' "$SKILL"
}

# --- Requirement: flatmate issue #240 の収束ルールが織り込まれている ---

@test "convergence: two-round cap with high-severity-only third round" {
  grep -q '2周' "$SKILL"
  grep -q '高深刻度' "$SKILL"
}

@test "convergence: re-review is diff-limited, new findings go to follow-up issues" {
  grep -q '差分' "$SKILL"
  grep -q 'follow-up issue' "$SKILL"
}

@test "convergence: mergeable-after fixes are not blocking" {
  grep -qF 'マージ後に issue で直せるものは blocking にしない' "$SKILL"
}

@test "convergence: risk-acceptance link authenticity check with gh api author probe" {
  grep -q '真正性' "$SKILL"
  grep -qF '.user.login' "$SKILL"
}

@test "convergence: verification runs in parallel while awaiting risk acceptance" {
  grep -q '並行' "$SKILL"
}

# --- Requirement: レビュー実行者を変更内容から事前判定する（light / full） ---

@test "triage: review weight section exists at the head of step 2" {
  grep -qF 'レビュー重量の判定' "$SKILL"
  # 手順2（レビュー）の中にあること — 手順3 より前に現れる
  triage="$(grep -n 'レビュー重量の判定' "$SKILL" | head -1 | cut -d: -f1)"
  step2="$(grep -n '^### 2\. レビュー' "$SKILL" | head -1 | cut -d: -f1)"
  step3="$(grep -n '^### 3\. リスク宣言' "$SKILL" | head -1 | cut -d: -f1)"
  [ "$triage" -gt "$step2" ]
  [ "$triage" -lt "$step3" ]
}

@test "triage: decision inputs are mechanical (file list + changed line count)" {
  grep -qF 'gh pr diff' "$SKILL"
  grep -qF -- '--name-only' "$SKILL"
  grep -q '行数' "$SKILL"
}

@test "triage: light condition (a) excludes agent-behavior-defining files" {
  # 「md だけ」では light にならない — エージェントの行動を定義する md は full 側
  grep -qF 'エージェントの行動を定義するファイル' "$SKILL"
  grep -qF 'CLAUDE.md' "$SKILL"
  grep -qF '.github/workflows/' "$SKILL"
}

@test "triage: light condition (b) caps at 30 changed lines and requires behavior-neutral" {
  grep -qF '30 行' "$SKILL"
  grep -q '挙動を変えない' "$SKILL"
}

@test "triage: full is the default and ties break toward full (fail-closed)" {
  grep -q '既定.*full\|full.*既定' "$SKILL"
  grep -qF '迷ったら full' "$SKILL"
  grep -qF '「判断がつかない」は light の理由にならない' "$SKILL"
}

@test "triage: light swaps only the reviewer, exempts no gate step" {
  # 免除されない工程が名指しで列挙されている
  grep -q 'light.*変わるのは.*実行者\|レビュー実行者だけ' "$SKILL"
  grep -q '免除' "$SKILL"
}

@test "triage: decision and reason are recorded as a PR comment" {
  grep -qF 'レビュー重量: light' "$SKILL"
}

@test "triage: pre-triage and availability fallback are distinguished, fallback kept" {
  # 既存のフォールバック記述（Codex が使えないときの迂回路）が残っている（回帰ガード）
  grep -q 'フォールバック' "$SKILL"
  grep -q '実測したバイナリ無し・認証切れ・タイムアウト' "$SKILL"
  grep -q 'タイムアウト' "$SKILL"
  # 事前判定と障害時フォールバックの役割が書き分けられている
  grep -q '事前判定' "$SKILL"
}

@test "manifest: version bumped above 1.7.0" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$v" != "1.7.0" ]
  highest="$(printf '1.7.0\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "skill: frontmatter version bumped above 1.0.0" {
  v="$(awk -F': ' '/^version:/{print $2; exit}' "$SKILL")"
  [ -n "$v" ]
  [ "$v" != "1.0.0" ]
  highest="$(printf '1.0.0\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

# --- Requirement: ゲート合格まで PR を Draft のまま扱い、合格処理で Ready にする（#304） ---

# 「### <N>. 」から次の「### 」見出しまでを切り出す（「#### 」の小見出しでは区切らない）
step() { awk -v h="### $1. " 'index($0, h)==1 {f=1; print; next} f && /^### / {f=0} f' "$SKILL"; }

# 行の並びを grep するだけでは条件の反転や終了コードの無視を検出できないので、
# 手順 1 と手順 5 の bash 断片そのものを偽の gh で実行し、呼ばれたコマンドと終了コードで確かめる
# （pr-review-gate-spec-declaration.bats と同じ手口）。
# 偽の gh は呼び出しを $GH_LOG に記録し、ラベル一覧に $MOCK_LABELS 、.draft に $MOCK_DRAFT を返し、
# `gh pr ready`（--undo なし）だけ $MOCK_READY_RC で終わる。

# 手順 $1 の fenced bash ブロックのうち、固定文字列 $2 を含むものを返す
step_block() {
  step "$1" | awk -v m="$2" '/^ *```bash/{f=1; b=""; next} /^ *```/{ if (f && index(b, m)) printf "%s", b; f=0; next } f{ b = b $0 "\n" }'
}

install_draft_gh() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case " $* " in
  *" pr ready "*--undo*) exit 0 ;;
  *" pr ready "*)        exit "${MOCK_READY_RC:-0}" ;;
  *" -X "*)              exit 0 ;;                               # ラベルの POST / DELETE
  *"/pulls/"*".draft"*)  printf '%s\n' "$MOCK_DRAFT" ;;
  *".labels[].name"*)    printf '%s\n' $MOCK_LABELS ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  : > "$GH_LOG"
  export R="o/r" N="42"
}

run_block() {  # $1 = 手順番号, $2 = ブロックを特定する文字列。終了コードは $status 、出力は $output
  cmds="$(step_block "$1" "$2")"
  [ -n "$cmds" ] || { echo "手順 $1 に「$2」を含む bash ブロックが無い"; return 1; }
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash -c "$cmds"
}

@test "draft: step 5 snippet on a Draft PR runs gh pr ready before POSTing passed" {
  install_draft_gh
  MOCK_LABELS="agent-review:pending" MOCK_DRAFT=true run_block 5 '--jq .draft'
  [ "$status" -eq 0 ]
  ln_ready="$(grep -nE '^pr ready 42 ' "$GH_LOG" | grep -vF -- '--undo' | head -1 | cut -d: -f1)"
  ln_passed="$(grep -nF 'labels[]=agent-review:passed' "$GH_LOG" | head -1 | cut -d: -f1)"
  [ -n "$ln_ready" ] || { cat "$GH_LOG"; echo "gh pr ready が呼ばれていない"; return 1; }
  [ -n "$ln_passed" ] || { cat "$GH_LOG"; echo "passed が付いていない"; return 1; }
  [ "$ln_ready" -lt "$ln_passed" ]
}

@test "draft: step 5 snippet on a non-Draft PR does not run gh pr ready but POSTs passed" {
  install_draft_gh
  MOCK_LABELS="agent-review:pending" MOCK_DRAFT=false run_block 5 '--jq .draft'
  [ "$status" -eq 0 ]
  ! grep -qE '^pr ready' "$GH_LOG" || return 1
  grep -qF 'labels[]=agent-review:passed' "$GH_LOG"
}

@test "draft: step 5 snippet stops without POSTing passed when gh pr ready fails" {
  install_draft_gh
  MOCK_LABELS="agent-review:pending" MOCK_DRAFT=true MOCK_READY_RC=1 run_block 5 '--jq .draft'
  [ "$status" -ne 0 ]
  grep -qE '^pr ready 42 ' "$GH_LOG"
  ! grep -qF 'labels[]=agent-review:passed' "$GH_LOG" || return 1
}

@test "draft: step 1 snippet moves a non-Draft PR back to Draft after removing a stale passed" {
  install_draft_gh
  MOCK_LABELS="agent-review:pending agent-review:passed" MOCK_DRAFT=false run_block 1 'gh pr ready --undo'
  grep -qF -- '-X DELETE repos/o/r/issues/42/labels/agent-review:passed' "$GH_LOG"
  grep -qE '^pr ready --undo 42 ' "$GH_LOG"
}

@test "draft: step 1 snippet leaves a Draft PR alone after removing a stale passed" {
  install_draft_gh
  MOCK_LABELS="agent-review:passed" MOCK_DRAFT=true run_block 1 'gh pr ready --undo'
  grep -qF -- '-X DELETE repos/o/r/issues/42/labels/agent-review:passed' "$GH_LOG"
  ! grep -qE '^pr ready' "$GH_LOG" || return 1
}

@test "draft: step 1 snippet does not undo Ready when no passed label was present" {
  install_draft_gh
  MOCK_LABELS="agent-review:pending" MOCK_DRAFT=false run_block 1 'gh pr ready --undo'
  ! grep -qF 'labels/agent-review:passed' "$GH_LOG" || return 1
  ! grep -qE '^pr ready' "$GH_LOG" || return 1
}

@test "draft: step 5 states why Ready comes before passed and that a failed Ready stops before passed" {
  s5="$(step 5)"
  flat="$(printf '%s\n' "$s5" | tr '\n' ' ')"
  echo "$flat" | grep -qE 'Ready 化に失敗したら[^。]*passed を付けず'
  echo "$flat" | grep -qE 'labeled[^。]*draft[^。]*スキップ'
  echo "$flat" | grep -qE '日次'
}

@test "draft: step 5 measured table has a draft=false row" {
  step 5 | grep -qE '^\| PR の `draft` \| \*\*`false`\*\* \|$'
}

@test "draft: step 1 moves a non-Draft PR back to Draft only when a stale passed was removed" {
  s1="$(step 1)"
  [ -n "$s1" ] || { echo "no step 1 section"; return 1; }
  echo "$s1" | grep -qF 'gh pr ready --undo'
  flat="$(printf '%s\n' "$s1" | tr '\n' ' ')"
  echo "$flat" | grep -qE 'passed を外したら[^。]*Draft でなければ[^。]*gh pr ready --undo'
  echo "$flat" | grep -qE 'passed が付いていなかった[^。]*Draft に戻さない'
}

review_execution() {
  awk '/^#### 2-1[.]/{f=1; next} /^#### 2-2[.]/{f=0} f' "$SKILL"
}

@test "legacy: default table includes exec and companion with measured fallback" {
  local doc
  doc="$(review_execution)"
  echo "$doc" | grep '^| .*既定' | grep -q 'codex exec'
  echo "$doc" | grep '^| .*既定' | grep -q 'companion'
  echo "$doc" | grep '^| フォールバック' | grep -q '実測したバイナリ無し・認証切れ・タイムアウト'
}

@test "legacy: availability requires measurement and rejects unsupported fallback" {
  local doc token
  doc="$(review_execution)"
  for token in 'companion / slash command が無ければ' 'exec を試す' 'command -v codex' '実際の Codex 呼び出し' '認証切れ' '総待ちの上限' '未試行' 'auth.json' '引数誤り・権限拒否・通信障害' '暗黙にフォールバックしない' '単一回の待ち終了'; do
    echo "$doc" | grep -qF "$token"
  done
}

@test "legacy: PR evidence distinguishes light and full and records actual results" {
  local doc token
  doc="$(review_execution)"
  for token in 'light 判定のため' 'full・実測した Codex 不可' '対象 HEAD:' '選んだ経路:' '実行コマンド:' '終了コード:' '出力の要点:' '実待ち時間:' '完了未確認' '架空の終了コード'; do
    echo "$doc" | grep -qF "$token"
  done
}

@test "legacy: App Server mode cannot inherit exec or Claude fallback" {
  review_execution | grep -q '新 Codex モード.*App Server 固定.*適用しない'
}

@test "legacy: per-PC procedure records completion or unverified without fixed locations" {
  local doc token
  doc="$(awk '/^##### 各 PC の確認/{f=1; next} /^##### /{f=0} /^#### /{f=0} f' "$SKILL")"
  [ -n "$doc" ]
  for token in 'command -v codex' 'codex --version' 'PC 識別子:' '日時:' 'バイナリのパス・バージョン:' 'companion 有無:' '対象 HEAD・diff 範囲:' '経路・実行コマンド:' '完了状態・結果:' '可否 / 未確認:' '残課題:' '対象 issue' '認証情報' '実レビュー' 'subagent-waiting.md' '未実測は未確認' 'companion 導入は任意'; do
    echo "$doc" | grep -qF "$token"
  done
  ! echo "$doc" | grep -qE 'github.com/|/Users/|#715' || return 1
}

# ===== 収束ルールの適用手順（issue #281 PR-A）=====

convergence_section() {
  awk '/^\*\*収束ルール（レビュー周回のキャップ）\*\*/{f=1} f&&/^#/{exit} f' "$SKILL"
}

@test "convergence (#281): G quotes the violated sentence right after receiving the round-2 result" {
  sec="$(convergence_section)"
  [ -n "$sec" ]
  echo "$sec" | grep -q '2周目の結果を受け取った直後'
  echo "$sec" | grep -q 'G'
  echo "$sec" | grep -q '引用'
  echo "$sec" | grep -q '受け入れ条件'
}

@test "convergence (#281): reviewer severity labels are reference only" {
  convergence_section | grep -q '深刻度ラベルは参考'
}

@test "convergence (#281): no quotable source means every finding is treated as unquoted" {
  convergence_section | grep -q '引用元が無い'
}

@test "convergence (#349): the per-round general rule is gone and step 2-1 refers to the all-round verdict" {
  run grep -F '欠陥ありなら PR コメントに再現手順と修正点を書き' "$SKILL"
  [ "$status" -ne 0 ]
  line="$(step21_section | grep -F '止める指摘が残ったら')"
  [ -n "$line" ] || { echo "no stop-finding branch line in step 2-1"; return 1; }
  echo "$line" | grep -qF '「マージを止めるかの判定（全周共通）」'
  echo "$line" | grep -qF '仕分け表'
  run grep -F '1周目は PR コメントに止める指摘を書き' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "convergence (#281): unquotable findings go to follow-up issues and proceed to passed" {
  sec="$(convergence_section)"
  echo "$sec" | grep -q '引用できない指摘'
  echo "$sec" | grep -q 'follow-up issue'
  echo "$sec" | grep -q 'passed'
}

@test "convergence (#354): stopping findings at the end of round 2 go to triage rows 5 or 6, not a bare single choice" {
  sec="$(convergence_section)"
  echo "$sec" | grep -q '引用できる指摘'
  echo "$sec" | grep -q '3周目を自動で開けない'
  echo "$sec" | grep -qF '順 5'
  echo "$sec" | grep -qF '順 6'
  echo "$sec" | grep -qF '順 2〜4 を使わない'
  run grep -F '続けるか、範囲外として閉じるか' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "convergence (#281): unmanned operation (loop-dev-agent) also stops" {
  convergence_section | grep -q 'loop-dev-agent'
}

@test "convergence (#281): rounds opened by the owner's go-ahead apply the same sorting and stop again" {
  convergence_section | grep -q '主の回答または決める役の裁定で開いた周の終了時にも同じ仕分け'
}

@test "convergence (#281): rewrite of the approach triggers a full review but rounds keep counting" {
  sec="$(convergence_section)"
  echo "$sec" | grep -q '方式の書き換え'
  echo "$sec" | grep -q '全体レビュー'
  echo "$sec" | grep -q '周回は数え続ける'
}

@test "convergence (#354): the decider rules only on the approach for row 6 and G keeps the stop verdict" {
  line="$(convergence_section | grep -F '順 6 の方式だけを裁定')"
  [ -n "$line" ] || { echo "no decider paragraph for row 6"; return 1; }
  echo "$line" | grep -qF '`dev-workflow:decider`'
  echo "$line" | grep -qF '止めるかどうかは全周共通の判定で G が決める'
  run grep -F '関与しない' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "convergence (#281): no high-severity permission for a third round remains" {
  run grep -E '3周目に入ってよいのは.*高深刻度|新規の高深刻度 blocking のみ' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "convergence (#354): step 6 recovery table has a split-off confirmation row covering both answers" {
  row="$(grep -A1 '^| \*\*切り出しの確認\*\*' "$SKILL")"
  [ -n "$row" ]
  echo "$row" | grep -q '切り出す'
  echo "$row" | grep -q 'この PR で直す'
  echo "$row" | grep -q 'agent-review:failed'
  [ "$(echo "$row" | grep -c 'needs-approval.*を外す')" -eq 2 ]
  grep -qE '^### 6\. 保留処理（.*切り出しの確認）' "$SKILL"
  run grep -F '2周目キャップ' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "approval classes (#354): row 1 asks whether to split the defect off, with a recommendation and an estimate" {
  row="$(grep -E '^\| 1 \| リスク許容の確認 \|' "$SKILL")"
  echo "$row" | grep -qF '順 5'
  echo "$row" | grep -qF 'この欠陥を残して切り出すか'
  echo "$row" | grep -qF '推奨と見積もり'
}

# ===== 指摘の固定書式と全周共通の判定（issue #349）=====

step21_section() {
  awk '/^#### 2-1\. /{f=1} /^#### 2-2\. /{exit} f' "$SKILL"
}

reviewer_block() {
  awk '/^\*\*レビュアー向け指示ブロック/{f=1; next} f&&/^```text$/{g=1; next} g&&/^```$/{exit} g' "$SKILL"
}

@test "finding format (#349): step 2-1 has a pasteable reviewer block with every field" {
  blk="$(reviewer_block)"
  [ -n "$blk" ] || { echo "no reviewer block in step 2-1"; return 1; }
  for token in '見出し' '深刻度' '検証' '根拠' '場所' '何が起きるか' '直し方'; do
    echo "$blk" | grep -qF "$token" || { echo "missing field: $token"; return 1; }
  done
}

@test "finding format (#349): the block defines severity, verification and re-review status values" {
  blk="$(reviewer_block)"
  for token in '`blocking`' '`should`' '`nit`' '`confirmed`' '`plausible`' '`fixed`' '`unresolved`' '`wontfix`'; do
    echo "$blk" | grep -qF "$token" || { echo "missing value: $token"; return 1; }
  done
  echo "$blk" | grep -qE '^\| `blocking` \|'
  echo "$blk" | grep -qE '^\| `should` \|'
  echo "$blk" | grep -qE '^\| `nit` \|'
}

@test "finding format (#349): the block names the three exceptions for unquotable blocking findings" {
  blk="$(reviewer_block)"
  echo "$blk" | grep -qF '安全機構の穴'
  echo "$blk" | grep -qF 'データ破壊'
  echo "$blk" | grep -qF '無言の機能不全'
}

@test "finding format (#349): the block asks to enumerate every finding and limits re-reviews" {
  blk="$(reviewer_block)"
  echo "$blk" | grep -qF '該当する指摘を全部列挙するまで止まらない'
  echo "$blk" | grep -qF '新規の指摘を出さない'
  echo "$blk" | grep -qF '新規に出してよいのは `blocking` だけ'
  echo "$blk" | grep -qF '直し方」どおりに直した箇所を再指摘しない'
}

@test "finding format (#349): the format and severity table appear only once in the skill" {
  [ "$(grep -cE '^\| `blocking` \|' "$SKILL")" -eq 1 ]
  [ "$(grep -c '^\*\*レビュアー向け指示ブロック' "$SKILL")" -eq 1 ]
}

@test "verdict (#349): the all-round verdict is written once in step 2-1" {
  [ "$(grep -c '^\*\*マージを止めるかの判定（全周共通）\*\*' "$SKILL")" -eq 1 ]
  v="$(step21_section | awk '/^\*\*マージを止めるかの判定（全周共通）\*\*/{f=1; print; next} f&&/^\*\*/{exit} f')"
  echo "$v" | grep -qF '`blocking`'
  echo "$v" | grep -qF '`confirmed`'
  echo "$v" | grep -qF '照合'
  echo "$v" | grep -qF '安全機構の穴'
  echo "$v" | grep -qF 'follow-up issue'
  echo "$v" | grep -qF '深刻度ラベルは参考'
  echo "$v" | grep -qF '全周'
}

@test "verdict (#349): no text splits the verdict by round" {
  run grep -F 'この一般則は1周目に適用する' "$SKILL"
  [ "$status" -ne 0 ]
  run grep -E '一般則|収束ルールが優先' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "verdict (#349): round-1 failed keeps non-stopping findings as a list and defers follow-up issues to step 3" {
  s="$(step21_section)"
  echo "$s" | grep -qF '止めない指摘'
  echo "$s" | grep -qF 'follow-up issue はまだ切らない'
  echo "$s" | grep -qF '手順3へ進むとき'
}

@test "verdict (#349): the round-2 sorting refers to the verdict instead of restating it" {
  sec="$(convergence_section)"
  echo "$sec" | grep -qF '「マージを止めるかの判定（全周共通）」'
  echo "$sec" | grep -qF '止める指摘'
  run sh -c "awk '/^\\*\\*収束ルール/{f=1} f&&/^#/{exit} f' '$SKILL' | grep -F 'blocking かどうかは引用できるかどうかで決め'"
  [ "$status" -ne 0 ]
}

@test "verdict (#349/#354): the decider paragraph ties the stop decision to the verdict, not to quoting alone" {
  line="$(grep -F '順 6 の方式だけを裁定' "$SKILL")"
  [ -n "$line" ]
  echo "$line" | grep -qF '全周共通の判定'
  run sh -c "grep -F '順 6 の方式だけを裁定' '$SKILL' | grep -F '引用の有無で決まる'"
  [ "$status" -ne 0 ]
}

@test "verdict (#349): step 5 requires zero stopping findings under the all-round verdict" {
  s5="$(awk '/^### 5\. /{f=1} /^### 6\. /{exit} f' "$SKILL")"
  echo "$s5" | grep -qF '全周共通の判定で止まる指摘（`blocking` かつ `confirmed`、G が引用を照合済み'
  echo "$s5" | grep -qF '0 件'
}

@test "verdict (#354): step 5 excludes findings the owner split off and findings closed by the row-3 set match" {
  s5="$(awk '/^### 5\. /{f=1} /^### 6\. /{exit} f' "$SKILL")"
  echo "$s5" | grep -qF '主が切り出すと答えて follow-up issue に切ったものと、G が順 3 の集合一致で閉じたもの（閉じた PR コメント URL を仕分け欄に残す）以外が 0 件'
  echo "$s5" | grep -qF '「切り出しの確認」行'
  # archive 前は change の delta spec、archive 後は main spec を読む
  spec="${PLUGIN_ROOT}/openspec/changes/pr-review-gate-triage-table/specs/dev-workflow-pr-review-gate/spec.md"
  [ -f "$spec" ] || spec="${PLUGIN_ROOT}/openspec/specs/dev-workflow-pr-review-gate/spec.md"
  req="$(awk '/^### Requirement: 合格条件に判定を明記する/{f=1;next} /^### Requirement: /{f=0} f' "$spec")"
  [ "$(echo "$req" | grep -cF '主が切り出すと答えて follow-up issue に切ったもの')" -eq 2 ]
  [ "$(echo "$req" | grep -cF '順 3 の集合一致で閉じたもの')" -eq 2 ]
  run grep -F '範囲外として閉じ' "$SKILL"
  [ "$status" -ne 0 ]
}

@test "codex rubric (#349): measured as applied, so step 2-1 maps the Codex rubric onto the fixed format" {
  s="$(step21_section)"
  echo "$s" | grep -qF '[P0]'
  echo "$s" | grep -qF '`priority`'
  echo "$s" | grep -qF '`confidence_score`'
  echo "$s" | grep -qF '`code_location`'
  echo "$s" | grep -qF '`confidence_score` を `confirmed` の代わりにしない'
}

# ===== 指摘の仕分け表（issue #354）=====

triage_section() {
  awk '/^\*\*止める指摘の仕分け表/{f=1} f&&/^\*\*収束ルール/{exit} f' "$SKILL"
}

# 仕分け表の中の「**順 N（…）**」段落。次の太字見出しの段落の手前まで
triage_row_section() {
  triage_section | awk -v n="$1" '$0 ~ "^\\*\\*順 " n "（"{f=1; print; next} f&&/^\*\*/{exit} f'
}

@test "triage (#354): the triage table sits right after the all-round verdict, once, with six rows in order" {
  [ "$(grep -c '^\*\*止める指摘の仕分け表' "$SKILL")" -eq 1 ]
  next_bold="$(awk '/^\*\*マージを止めるかの判定（全周共通）\*\*/{f=1; next} f&&/^\*\*/{print; exit}' "$SKILL")"
  echo "$next_bold" | grep -q '^\*\*止める指摘の仕分け表'
  rows="$(triage_section | grep -E '^\| [1-6] \|' | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')"
  [ "$rows" = "1 2 3 4 5 6 " ] || { echo "rows: $rows"; return 1; }
  t="$(triage_section)"
  echo "$t" | grep -E '^\| 1 \|' | grep -qF '止める判定'
  echo "$t" | grep -E '^\| 2 \|' | grep -qF '受け入れ条件の中'
  echo "$t" | grep -E '^\| 3 \|' | grep -qF '一覧の一致'
  echo "$t" | grep -E '^\| 4 \|' | grep -qF '今直す 3 条件'
  echo "$t" | grep -E '^\| 5 \|' | grep -qF '主に'
  echo "$t" | grep -E '^\| 6 \|' | grep -qF '決める役'
}

@test "triage (#354): rows 2 to 4 return to W with agent-review:failed, row 5 holds, row 6 returns needs-decider" {
  t="$(triage_section)"
  for n in 2 3 4; do
    echo "$t" | grep -E "^\| $n \|" | grep -qF 'agent-review:failed' || { echo "row $n lacks failed"; return 1; }
  done
  echo "$t" | grep -E '^\| 5 \|' | grep -qF 'needs-approval'
  echo "$t" | grep -E '^\| 6 \|' | grep -qF 'needs-decider'
}

@test "triage (#354): at the end of round 2 and later rounds, rows 2 to 4 are not used" {
  triage_section | grep -qF '2 周目以降の周の終わり'
  triage_section | grep -qF '順 2〜4 を使わない'
}

@test "triage (#354): row 5 mixed with rows 2 to 4 holds first and W does not start fixing" {
  t="$(triage_section)"
  echo "$t" | grep -qF '保留を先にする'
  echo "$t" | grep -qF 'W は順 2〜4 の指摘の修正にも着手しない'
  echo "$t" | grep -qF '`needs-approval` と `agent-review:failed` を同時に付けない'
}

@test "triage (#354): row 3 closes by set match, with a search command, one send-back and no round consumed" {
  [ "$(grep -c '一覧の一致\|集合が.*一致' "$SKILL")" -ge 1 ]
  r="$(triage_row_section 3)"
  [ -n "$r" ] || { echo "no row-3 section"; return 1; }
  echo "$r" | grep -qF '検索コマンド'
  echo "$r" | grep -qF '投稿してから push'
  echo "$r" | grep -qF '差し戻しは 1 回まで'
  echo "$r" | grep -qF 'レビューの周に数えない'
  echo "$r" | grep -qF '周を消費しない'
  echo "$r" | grep -qF '「該当しない理由」の正否を判定しない'
  echo "$r" | grep -qF '順 3 に当てない'
}

@test "triage (#354): row 4 uses the same 30-line threshold as step 2-0 and no other line count" {
  grep -n '30 行' "$SKILL" | awk -F: -v s="$(grep -n '^#### 2-0\. ' "$SKILL" | cut -d: -f1)" -v e="$(grep -n '^#### 2-1\. ' "$SKILL" | cut -d: -f1)" '$1>s && $1<e {ok=1} END{exit !ok}'
  r="$(triage_row_section 4)"
  [ -n "$r" ] || { echo "no row-4 section"; return 1; }
  echo "$r" | grep -qF '直し方が行レベルで 30 行以内'
  echo "$r" | grep -qF 'その場で直した累計が 30 行以内'
  echo "$r" | grep -qF '手順 2-0 と同じ 30 行'
  echo "$r" | grep -qF '受け入れ条件の外・その場で直した・直し方 N 行'
  other="$(echo "$r" | grep -oE '[0-9]+ 行' | grep -v '^30 行$' || true)"
  [ -z "$other" ] || { echo "other thresholds: $other"; return 1; }
}

@test "triage (#354): row 5 asks the owner in the same round with the four points" {
  r="$(triage_row_section 5)"
  [ -n "$r" ] || { echo "no row-5 section"; return 1; }
  for token in 'マージ後に何を起こすか' '見積もり' '固定費' '推奨' 'その周で聞く' 'needs-approval' '「切り出しの確認」' 'loop-dev-agent'; do
    echo "$r" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "triage (#354): row 6 fires on recurrence at round 2+ ends or on fall-through from rows 3 and 4" {
  r="$(triage_row_section 6)"
  [ -n "$r" ] || { echo "no row-6 section"; return 1; }
  echo "$r" | grep -qF '2 周目以降の周の終わり'
  echo "$r" | grep -qF '順 3 の照合が差し戻し後の 2 回目も一致しない'
  echo "$r" | grep -qF '順 4 で直した指摘が 1 回で閉じない'
  echo "$r" | grep -qF '周の終わりを待たず'
}

@test "triage (#354): row 6 is ruled once per PR, counted from PR comments by exact first line over all pages" {
  r="$(triage_row_section 6)"
  echo "$r" | grep -qF '`needs-decider`'
  echo "$r" | grep -qF 'PR ごとに 1 回まで'
  echo "$r" | grep -qF '^決める役の裁定: (全部列挙してから直す|切り出す)$'
  echo "$r" | grep -qF -- '--paginate --slurp'
  echo "$r" | grep -qF '1 回目の裁定が「切り出す」だった場合も'
  echo "$r" | grep -qF '止めるかどうかの判定は G'
  echo "$r" | grep -qF '可否と根拠'
}

@test "reviewer block (#354): the no-new-findings rule has the three-exception proviso" {
  line="$(reviewer_block | grep -F '新規の指摘を出さない')"
  [ -n "$line" ]
  echo "$line" | grep -qF '例外 3 種'
  echo "$line" | grep -qF '安全機構の穴'
  echo "$line" | grep -qF '差分限定の周でも出してよい'
}

@test "convergence (#354): only an owner answer or a decider ruling opens round 3" {
  sec="$(convergence_section)"
  echo "$sec" | grep -qF '「この PR で直す」'
  echo "$sec" | grep -qF '「全部列挙してから直す」'
  echo "$sec" | grep -qF 'PR ごとに 1 回まで'
  echo "$sec" | grep -qF '例外 3 種'
}

# ===== 仕分け表の追補（issue #357 #358 #359）=====

@test "triage (#357): row 3 fixes the list comment format with a pre-fix SHA and a git grep command taking <rev>" {
  r="$(triage_row_section 3)"
  [ -n "$r" ] || { echo "no row-3 section"; return 1; }
  for token in '`## 一覧（順 3）`' '`修正前 SHA: <40 桁>`' '`検索コマンド: <コマンド>`' '<rev>' \
    '`| 軸の値 | 扱い |`' '`直した`' '`該当しない: <理由>`' \
    '修正に着手する直前の HEAD' '40 桁' '`grep -rn`'; do
    echo "$r" | grep -qF -- "$token" || { echo "missing: $token"; return 1; }
  done
  # 軸のときも修正前 SHA を書き、検索コマンドの行に軸とその全域を書く
  echo "$r" | grep -qF '場合分けの軸のときも `修正前 SHA:` の行は同じく書き'
  echo "$r" | grep -qF '`検索コマンド:` の行には軸とその全域'
  # 順 6 の「全部列挙してから直す」の一覧も同じ見出しと書式
  echo "$r" | grep -qF '順 6 の裁定「全部列挙してから直す」で W が作る一覧も、同じ見出し `## 一覧（順 3）`'
}

@test "triage (#357): row 3 checks the pre-fix SHA exists after a fetch and matches in two stages by file and line body" {
  r="$(triage_row_section 3)"
  echo "$r" | grep -qF 'git cat-file -e <修正前 SHA>^{commit}'
  echo "$r" | grep -qF '解決できないときだけ'
  # git fetch を実在確認より前に置く
  f="$(echo "$r" | grep -bo 'git fetch' | head -1 | cut -d: -f1)"
  c="$(echo "$r" | grep -bo 'git cat-file -e' | head -1 | cut -d: -f1)"
  [ -n "$f" ] && [ -n "$c" ] && [ "$f" -lt "$c" ] || { echo "fetch=$f cat-file=$c"; return 1; }
  # 2 段の照合
  echo "$r" | grep -qF '修正前 SHA で検索コマンドを実行したヒット集合が表の全行（扱いを問わない）と一致する'
  echo "$r" | grep -qF 'HEAD で同じ検索コマンドを実行し、残ったヒットがすべて、扱いが「該当しない」の行に対応する'
  echo "$r" | grep -qF '「ファイル」と「ヒットした行の本文」の組で取り、行番号では取らない'
  echo "$r" | grep -qF '件数で照合'
  echo "$r" | grep -qF '2 段目を行わない'
  echo "$r" | grep -qF '表の出し直しを求めた場合を含む'
  # 扱いが混在する組は git diff の削除行の件数で裏取りする
  echo "$r" | grep -qF '扱いが混在する組'
  echo "$r" | grep -qF 'git diff <修正前 SHA> HEAD -- <ファイル>'
  echo "$r" | grep -qF '「直した」の件数以上'
}

@test "triage (#359): the mixed paragraph handles rows 5 and 6 together, hold first, then needs-decider, then one failed" {
  mix="$(triage_section | awk '/^同じ周に順 5 の指摘と順 6 の指摘が混ざったら/{f=1} f&&/^\*\*/{exit} f')"
  [ -n "$mix" ] || { echo "no row-5/row-6 mixed paragraph"; return 1; }
  for token in '順 2〜4 の指摘を含んでもよい' '順 6・未裁定' '順 5 の指摘についてだけ' '未処理の順 6' \
    '`agent-review:failed` を付けずに Status `needs-decider` で return' '1 回の `agent-review:failed` で W に戻す' \
    '1 回の保留にまとめる' '主の回答と裁定の両方が済むまで'; do
    echo "$mix" | grep -qF -- "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "triage (#358 #359): row 6 handles 'no ruling (missing input)' and does not flip to failed while row 5 is unanswered" {
  r="$(triage_row_section 6)"
  echo "$r" | grep -qF '裁定なし（入力不足）'
  echo "$r" | grep -qF '`決める役の裁定:` の PR コメントを残さず'
  echo "$r" | grep -qF '裁定の回数に数えない'
  echo "$r" | grep -qF '主がまだ回答していなければ、failed に付け替えずに保留のまま待つ'
}

@test "convergence (#359): step 6 split-off confirmation row sends unprocessed row 6 to needs-decider" {
  row="$(grep -A1 '^| \*\*切り出しの確認\*\*' "$SKILL")"
  [ "$(echo "$row" | grep -c '未処理の順 6')" -eq 2 ] || { echo "$row"; return 1; }
  echo "$row" | grep -qF '`agent-review:failed` を付けずに Status `needs-decider` で return'
}

# ===== 一周目レビューの変更点一覧・照合表・ハンク被覆（issue #355） =====

@test "review inventory (#355): reviewer block emits the three artifacts before self-check and findings" {
  block="$(reviewer_block)"
  for token in '変更点の一覧' '照合表' 'ハンク被覆' '自己点検' '指摘'; do
    echo "$block" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  inventory="$(echo "$block" | grep -n '^1\. `変更点の一覧`:' | cut -d: -f1)"
  reconcile="$(echo "$block" | grep -n '^2\. `照合表`:' | cut -d: -f1)"
  hunks="$(echo "$block" | grep -n '^3\. `ハンク被覆`:' | cut -d: -f1)"
  selfcheck="$(echo "$block" | grep -n '^三表を自己点検してから指摘へ進む' | cut -d: -f1)"
  findings="$(echo "$block" | grep -n '^- 見出し:' | cut -d: -f1)"
  [ "$inventory" -lt "$reconcile" ] || return 1
  [ "$reconcile" -lt "$hunks" ] || return 1
  [ "$hunks" -lt "$selfcheck" ] || return 1
  [ "$selfcheck" -lt "$findings" ] || return 1
  echo "$block" | grep -qF '受け入れ条件'
  echo "$block" | grep -qF '検索語'
  echo "$block" | grep -qF 'git grep -n'
  echo "$block" | grep -qF '<rev> -- .'
  echo "$block" | grep -qF '全ヒット'
  echo "$block" | grep -qF '問題なし'
}

@test "review inventory (#355): swapping artifact definition order fails the order assertions" {
  block="$(reviewer_block)"
  swapped="$(echo "$block" | awk '
    /^1\. `変更点の一覧`:/ { first=$0; next }
    /^2\. `照合表`:/ { print; print first; next }
    { print }
  ')"
  inventory="$(echo "$swapped" | grep -n '^1\. `変更点の一覧`:' | cut -d: -f1)"
  reconcile="$(echo "$swapped" | grep -n '^2\. `照合表`:' | cut -d: -f1)"
  run test "$inventory" -lt "$reconcile"
  [ "$status" -ne 0 ]
}

@test "review inventory (#355): common list contract is repository-wide and differs only in handling" {
  [ "$(grep -c '^\*\*共通一覧契約' "$SKILL")" -eq 1 ]
  common="$(awk '/^\*\*共通一覧契約/{f=1} f&&/^\*\*/&&seen{exit} f{seen=1; print}' "$SKILL")"
  for token in '修正前 SHA: <40 桁>' 'git grep -n' '<rev> -- .' \
    '| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |' \
    '本文全体' 'backtick fence' '\\' '\|' 'backtick' \
    '追跡対象パスの除外' '検索起点' '一周目' '順 3' '一致' '食い違い:' '直した' '該当しない:'; do
    echo "$common" | grep -qF -- "$token" || { echo "missing: $token"; return 1; }
  done
  r="$(triage_row_section 3)"
  echo "$r" | grep -qF '共通一覧契約'
  echo "$r" | grep -qF '| 軸の値 | 扱い |'
  echo "$r" | grep -qF '共通一覧契約の対象外'
}

@test "review inventory (#355): inconsistency location and priority output fail closed on missing tables" {
  line="$(reviewer_block | grep -F 'diff と重なる範囲で 10 行以内')"
  echo "$line" | grep -qF '食い違い'
  echo "$line" | grep -qF 'diff 外'
  echo "$line" | grep -qF '2 か所'
  priority="$(awk '/^\*\*Codex が優先度付きの形で返したときの読み替え\*\*/{f=1} f&&/^\*\*マージを止めるか/{exit} f' "$SKILL")"
  for token in '変更点の一覧' '照合表' 'ハンク被覆' '不足したレビュアー出力' '完了扱いにしない'; do
    echo "$priority" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

# --- Requirement: リスク宣言は 7 観点で判定し、新 3 観点も主のリスク許容待ちに流す（#373） ---

# 手順 3 の本文（`### 3. リスク宣言` から `#### 3-b.` の直前まで）
step3_body() {
  awk '/^### 3\. リスク宣言/{f=1} /^#### 3-b\./{f=0} f' "$SKILL"
}

@test "risk (#373): the 'no risk' boilerplate names all 7 viewpoints" {
  line="$(step3_body | grep '^リスクなし — ')"
  [ "$(echo "$line" | wc -l | tr -d ' ')" -eq 1 ] || { echo "$line"; return 1; }
  for w in 'プロダクトのユーザーに及ぶ影響' 'データ喪失' '課金/法務' '外部公開面の変化' \
           '資格情報' '安全ゲートの弱体化' 'エージェント権限の拡張'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
  echo "$line" | grep -qF 'いずれも無い'
}

@test "risk (#373): the classification table lists the 3 new viewpoints and routes them to step 6" {
  table="$(step3_body | grep '^| \*\*')"
  for w in '資格情報' '安全ゲートの弱体化' 'エージェント権限の拡張'; do
    echo "$table" | grep '^| \*\*リスクなし\*\*' | grep -qF "$w" || { echo "missing in no-risk row: $w"; return 1; }
  done
  echo "$table" | grep '^| \*\*主のリスク許容が必要\*\*' | grep -qF '手順6へ'
  # 新 3 観点も needs-approval の経路に入ることが明記されている
  step3_body | grep -F '資格情報・安全ゲートの弱体化・エージェント権限の拡張' | grep -qF 'needs-approval'
}

@test "risk (#373): the 3 new viewpoints are defined with their boundaries" {
  body="$(step3_body)"
  echo "$body" | grep -F '**資格情報**' | grep -qF '取得・保管・利用'
  echo "$body" | grep -F '**安全ゲートの弱体化**' | grep -qF '厳しくする変更は当たらない'
  def="$(echo "$body" | grep -F '**エージェント権限の拡張**')"
  echo "$def" | grep -qF '権限'
  echo "$def" | grep -qF '外部サービス'
  echo "$def" | grep -qF '書き込み先'
}

@test "risk (#373): the approval-needed template asks which viewpoint applies" {
  step3_body | grep -qF -- '- 該当する観点: '
}

@test "risk (#373): both templates keep line 1 heading and line 2 target HEAD" {
  blocks="$(step3_body | awk '/^```$/{if(f){f=0; n++} else {f=1; l=0}; next} f{l++; if(l<=2) print n": "l": "$0}')"
  [ "$(echo "$blocks" | grep -c '^[0-9]*: 1: ## リスク宣言$')" -eq 2 ] || { echo "$blocks"; return 1; }
  [ "$(echo "$blocks" | grep -c '^[0-9]*: 2: 対象 HEAD: <\$HEAD_SHA 40桁フル>$')" -eq 2 ] || { echo "$blocks"; return 1; }
  # 雛形の実際の位置に合わせ、必須の説明も 2 行目と書く
  step3_body | grep -qF '2 行目の `対象 HEAD:` は必須'
}

@test "risk (#381): the credential definition covers agent behavior instructions, not only code/config" {
  def="$(step3_body | grep -F -- '- **資格情報**')"
  echo "$def" | grep -qF 'エージェントへの行動指示' || { echo "$def"; return 1; }
  echo "$def" | grep -qF 'SKILL.md'
  # 安全ゲート・権限の定義も手段（コード・設定・行動指示）を問わない
  for w in '**安全ゲートの弱体化**' '**エージェント権限の拡張**'; do
    step3_body | grep -F -- "- $w" | grep -qF 'エージェントへの行動指示' || { echo "missing in: $w"; return 1; }
  done
}
