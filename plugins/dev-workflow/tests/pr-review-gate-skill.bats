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
  DECLARATIONS="${PLUGIN_DIR}/skills/pr-review-gate/declarations.md"
  PREPARE="${PLUGIN_DIR}/skills/pr-review-gate/stages/prepare.md"
  REVIEW_RUN="${PLUGIN_DIR}/skills/pr-review-gate/stages/review-run.md"
  REVIEWER_BRIEF="${PLUGIN_DIR}/skills/pr-review-gate/stages/reviewer-brief.md"
  TRIAGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/triage.md"
  PASS_STAGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/pass.md"
  HOLD="${PLUGIN_DIR}/skills/pr-review-gate/stages/hold.md"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  DEVELOP_SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
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

@test "skill: keeps the 6-step skeleton of the flatmate original" {
  grep -qF '### 1. 前提を揃える' "${PREPARE}"
  grep -qF '### 2. レビュー' "${PREPARE}"
  grep -qF '### 3. リスク宣言' "${DECLARATIONS}"
  grep -qF '### 4. 動作確認' "${PASS_STAGE}"
  grep -qF '### 5. 合格処理' "${PASS_STAGE}"
  grep -qF '### 6. 保留処理' "${HOLD}"
}

@test "skill: keeps the label vocabulary" {
  grep -qF 'agent-review:passed' "$SKILL"
  grep -qF 'agent-review:pending' "${PREPARE}"
  grep -qF 'agent-review:failed' "${PREPARE}"
  grep -qF 'needs-approval' "${DECLARATIONS}"
}

@test "skill: keeps fail-closed principle with HEAD SHA verification" {
  grep -q 'fail-closed' "$SKILL"
  grep -qF 'HEAD_SHA' "${DECLARATIONS}"
  # 宣言・証拠コメントの実在を API で実測してから passed を付ける規定
  grep -qF '.head.sha' "${PREPARE}"
}

# --- Requirement: スキルはリポ非依存で、flatmate 固有の仕組みには条件分岐で対応する ---

@test "portability: no hardcoded flatmate repo URL" {
  ! gate_all | grep -q 'genetta-inc/flatmate' || return 1
}

@test "portability: no reference to flatmate-only machinery" {
  ! gate_all | grep -q 'pending-mirror\.sh' || return 1
  ! gate_all | grep -q 'pending-owner\.md' || return 1
  ! gate_all | grep -q 'channel-reply-policy' || return 1
  ! gate_all | grep -q 'agent-loop-steps\.md' || return 1
}

@test "portability: degraded behavior for repos without auto-merge is specified" {
  grep -q '未配備' "${PASS_STAGE}"
}

@test "portability: direct merge by LLM remains forbidden" {
  # gh pr merge / merge API の直叩き禁止が明文化されている
  grep -q 'gh pr merge' "${PASS_STAGE}"
  grep -q '禁止' "${DECLARATIONS}"
}

# --- Requirement: flatmate issue #240 の収束ルールが織り込まれている ---

@test "convergence: two-round cap with high-severity-only third round" {
  grep -q '2周' "${TRIAGE}"
  grep -q '高深刻度' "${TRIAGE}"
}

@test "convergence: re-review is diff-limited, new findings go through the non-stopping triage table" {
  grep -q '差分' "${PREPARE}"
  grep -qF '再レビュー中の新規の気づきは止めない指摘の振り分け表に通す' "${TRIAGE}"
}

@test "convergence: mergeable-after fixes are not blocking" {
  grep -qF 'マージ後に issue で直せるものは blocking にしない' "${TRIAGE}"
}

@test "convergence: risk-acceptance link authenticity check with gh api author probe" {
  grep -q '真正性' "${PASS_STAGE}"
  grep -qF '.user.login' "${PASS_STAGE}"
}

@test "convergence: verification runs in parallel while awaiting risk acceptance" {
  grep -q '並行' "${HOLD}"
}

# --- Requirement: レビュー実行者を変更内容から事前判定する（light / full） ---

@test "triage: review weight section exists at the head of step 2" {
  # 手順 2 と 2-0 は索引の対応表で同じ段のファイル（stages/prepare.md）を指し、
  # その中で手順 2 の見出しの後、段の後ろの節（G として動くとき）より前に現れる
  f="$(step_file 2-0)"
  [ "$f" = "$PREPARE" ] && [ "$(step_file 2)" = "$PREPARE" ]
  triage="$(grep -n 'レビュー重量の判定' "$f" | head -1 | cut -d: -f1)"
  step2="$(grep -n '^### 2\. レビュー' "$f" | head -1 | cut -d: -f1)"
  tail_sec="$(grep -n '^## G として動くとき' "$f" | head -1 | cut -d: -f1)"
  [ -n "$triage" ] && [ -n "$step2" ] && [ -n "$tail_sec" ]
  [ "$triage" -gt "$step2" ]
  [ "$triage" -lt "$tail_sec" ]
}

@test "triage: decision inputs are mechanical (file list + changed line count)" {
  grep -qF 'gh pr diff' "${PREPARE}"
  grep -qF -- '--name-only' "${PREPARE}"
  grep -q '行数' "${PREPARE}"
}

@test "triage: light condition (a) excludes agent-behavior-defining files" {
  # 「md だけ」では light にならない — エージェントの行動を定義する md は full 側
  grep -qF 'エージェントの行動を定義するファイル' "${PREPARE}"
  grep -qF 'CLAUDE.md' "${PREPARE}"
  grep -qF '.github/workflows/' "${PREPARE}"
}

@test "triage: light condition (b) caps at 30 changed lines and requires behavior-neutral" {
  grep -qF '30 行' "${PREPARE}"
  grep -q '挙動を変えない' "${PREPARE}"
}

@test "triage: full is the default and ties break toward full (fail-closed)" {
  grep -q '既定.*full\|full.*既定' "${PREPARE}"
  grep -qF '迷ったら full' "${PREPARE}"
  grep -qF '「判断がつかない」は light の理由にならない' "${PREPARE}"
}

@test "triage: light swaps only the reviewer, exempts no gate step" {
  # 免除されない工程が名指しで列挙されている
  grep -q 'light.*変わるのは.*実行者\|レビュー実行者だけ' "${PREPARE}"
  grep -q '免除' "${PREPARE}"
}

@test "triage: decision and reason are recorded as a PR comment" {
  grep -qF 'レビュー重量: light' "${PREPARE}"
}

@test "triage: pre-triage and availability fallback are distinguished, fallback kept" {
  # 既存のフォールバック記述（Codex が使えないときの迂回路）が残っている（回帰ガード）
  grep -q 'フォールバック' "${REVIEW_RUN}"
  grep -q '実測したバイナリ無し・認証切れ・タイムアウト' "${REVIEW_RUN}"
  grep -q 'タイムアウト' "${PREPARE}"
  # 事前判定と障害時フォールバックの役割が書き分けられている（「レビュー実行者:」の段落は照合と振り分けの段、#554）
  grep -q '事前判定' "${TRIAGE}"
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
# 否定の検査（その文言がスキルのどこにも無いこと）は索引だけでなく段のファイル全部で見る
gate_all() { cat "$SKILL" "$DECLARATIONS" "$PREPARE" "$REVIEW_RUN" "$REVIEWER_BRIEF" "$TRIAGE" "$PASS_STAGE" "$HOLD"; }

# 手順が置かれた段のファイルは、索引（SKILL.md）の手順番号の対応表から引く（索引の表そのものも検査する）
step_file() {
  local rel
  rel="$(awk -F'|' -v n=" $1 " '$2==n {print $4; exit}' "$SKILL" | tr -d ' `')"
  [ -n "$rel" ] && printf '%s' "${PLUGIN_DIR}/skills/pr-review-gate/${rel}"
}
step() { awk -v h="### $1. " 'index($0, h)==1 {f=1; print; next} f && /^### / {f=0} f' "$(step_file "$1")"; }

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

# 手順 2-1 のレビュー実行者の部分（従来モードの表と不可判定）は stages/review-run.md にある
review_execution() {
  awk '/^#### 2-1[.]/{f=1; next} /^## /{f=0} f' "$REVIEW_RUN"
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

# --- Codex オフ（accounts.json の codex.enabled が false。#978） ---

# 日本語の文は固定文字列で照合する。LC_ALL=C では [^。] がバイト単位になり、
# 句点以外の日本語まで拒否するため（#1424）。

# 「Codex がオフのとき」の段落（2-1 の表の下に 1 つだけ置く）
codex_off_paragraph() {
  review_execution | grep -F '**Codex がオフのとき**'
}

@test "codex off (#978): review-run decides it with usage_view.py --codex-enabled before trying Codex" {
  local para
  para="$(codex_off_paragraph)"
  [ -n "$para" ] || { echo "no Codex off paragraph in step 2-1"; return 1; }
  [ "$(printf '%s\n' "$para" | wc -l | tr -d ' ')" -eq 1 ]
  echo "$para" | grep -qF 'scripts/usage_view.py --codex-enabled'
  echo "$para" | grep -qF 'full と判定したあと、Codex を試す前に'
  echo "$para" | grep -qF '`off`'
  echo "$para" | grep -qF '`on`'
}

@test "codex off (#1020): output that is neither on nor off is treated as on and recorded" {
  local para
  para="$(codex_off_paragraph)"
  echo "$para" | grep -qF '`on` なら表の既定どおり Codex から試す。出力が `on` でも `off` でもない（コマンドが失敗した）ときは `on` と同じに扱い、その出力を `実行コマンド` の証拠に書く。'
}

@test "codex off (#978): Codex is not called and the binary is not even looked up" {
  local para
  para="$(codex_off_paragraph)"
  echo "$para" | grep -qF '`off` なら、バイナリ探索（`command -v codex`）も Codex の呼び出しもしない'
  echo "$para" | grep -qF 'Task サブエージェント'
  echo "$para" | grep -qF 'dev-workflow:reviewer'
}

@test "codex off (#978): off is a setting, not one of the three measured conditions" {
  local para judge
  para="$(codex_off_paragraph)"
  echo "$para" | grep -qF 'オフは利用者が明示した設定で、下の三条件の実測ではない'
  echo "$para" | grep -qF '設定ファイルを自分で読まず'
  # 不可判定の段落も、オフが三条件とは別であることを一言で指す
  judge="$(review_execution | grep -F '**従来モードの不可判定**')"
  echo "$judge" | grep -qF '設定による Codex オフ（上の「Codex がオフのとき」）は三条件とは別'
  # 三条件の箇条書きは 3 つのまま（オフを 4 つ目として混ぜない）
  [ "$(review_execution | grep -cE '^- (バイナリ無し|認証切れ|タイムアウト): ')" -eq 3 ]
  ! review_execution | grep -E '^- ' | grep -q 'オフ' || return 1
}

@test "codex off (#978): light, the declarations and the fail-closed order are unchanged" {
  local para
  para="$(codex_off_paragraph)"
  echo "$para" | grep -qE '変わるのはレビュー実行者だけ'
  echo "$para" | grep -qF '新 Codex モードと develop の adapter 経路には適用しない'
}

@test "codex off (#978): the evidence template has the off form without the word measured" {
  local block line field
  block="$(awk '/^対象 HEAD: <40 桁フル SHA>/{f=1} f{print} f && /^```$/{exit}' "${REVIEW_RUN}")"
  [ -n "$block" ] || { echo "review evidence template missing"; return 1; }
  echo "$block" | grep -F 'レビュー実行者:' | grep -qF 'Task サブエージェント（full・Codex オフ）'
  for field in '選んだ経路:' '終了コード:' '実待ち時間:'; do
    echo "$block" | grep -F -- "$field" | grep -qF '未実行（Codex オフ）' || { echo "missing off value in ${field}"; return 1; }
  done
  echo "$block" | grep -F '実行コマンド:' | grep -qF 'usage_view.py --codex-enabled → off'
  echo "$block" | grep -F '出力の要点:' | grep -qF 'Codex オフの設定により Codex を試していない'
  # オフの書式そのものには「実測した」を含めない
  ! grep -oE '（full・Codex オフ[^）]*）' "$REVIEW_RUN" "$TRIAGE" | grep -q '実測した' || return 1
  review_execution | grep -F '書き分ける' | grep -qF 'レビュー実行者: Task サブエージェント（full・Codex オフ）'
}

@test "codex off (#978): G returns needs-reviewer with the off-by-setting reason" {
  local doc row
  doc="$(awk '/^### レビューの実行者/{f=1;print;next} /^##/{f=0} f' "$REVIEW_RUN")"
  row="$(echo "$doc" | grep -E '^\| \*\*full\*\* で Codex がオフ')"
  [ -n "$row" ] || { echo "no Codex off row in the G table"; return 1; }
  echo "$row" | grep -qF '`needs-reviewer`'
  echo "$row" | grep -qF '`Codex オフ（設定）`'
  echo "$row" | grep -qE 'Codex を(試さ|呼ば)ない'
  # 既定の行はオンのときだけ（オンの経路そのものは変えない）
  echo "$doc" | grep -F '| **full**（既定） | Codex CLI |' | grep -qF 'G の **Bash から直接**呼ぶ'
}

@test "codex off (#978): triage carries the reviewer line form for Codex off" {
  grep -F '「レビュー実行者:」の PR コメント（' "$TRIAGE" | grep -qF '（full・Codex オフ）'
}

@test "codex off (#978): the off check is written in review-run.md only" {
  local file gate_runner
  gate_runner="${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md"
  [ -f "$gate_runner" ]
  grep -qF -- '--codex-enabled' "$REVIEW_RUN"
  for file in "$SKILL" "$DECLARATIONS" "$REVIEWER_BRIEF" "$TRIAGE" "$PASS_STAGE" "$HOLD" "$gate_runner" "$DEVELOP_SKILL"; do
    if grep -qF -- '--codex-enabled' "$file"; then
      echo "off check repeated in ${file}"
      return 1
    fi
  done
  # prepare.md の needs-reviewer の証拠の値は手順ではないので、その文字列だけを除く（#1019）
  if sed 's|、Codex オフ: python3 <plugin>/scripts/usage_view.py --codex-enabled → off>|>|' "$PREPARE" | grep -qF -- '--codex-enabled'; then
    echo "off check repeated in ${PREPARE}"
    return 1
  fi
  # 手順を書く段落は 1 つ。G の表はそれを指すだけにする
  [ "$(grep -cF -- '--codex-enabled' "$REVIEW_RUN")" -le 3 ]
  [ "$(grep -cF 'バイナリ探索（`command -v codex`）も' "$REVIEW_RUN")" -eq 1 ]
}

@test "legacy: App Server mode cannot inherit exec or Claude fallback" {
  review_execution | grep -q '新 Codex モード.*App Server 固定.*適用しない'
}

@test "legacy: per-PC procedure records completion or unverified without fixed locations" {
  local doc token
  doc="$(awk '/^##### 各 PC の確認/{f=1; next} /^##### /{f=0} /^#### /{f=0} f' "${REVIEW_RUN}")"
  [ -n "$doc" ]
  for token in 'command -v codex' 'codex --version' 'PC 識別子:' '日時:' 'バイナリのパス・バージョン:' 'companion 有無:' '対象 HEAD・diff 範囲:' '経路・実行コマンド:' '完了状態・結果:' '可否 / 未確認:' '残課題:' '対象 issue' '認証情報' '実レビュー' 'subagent-waiting.md' '未実測は未確認' 'companion 導入は任意'; do
    echo "$doc" | grep -qF "$token"
  done
  ! echo "$doc" | grep -qE 'github.com/|/Users/|#715' || return 1
}

# ===== 収束ルールの適用手順（issue #281 PR-A）=====

convergence_section() {
  awk '/^\*\*収束ルール（レビュー周回のキャップ）\*\*/{f=1} f&&/^#/{exit} f' "$TRIAGE"
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
  ! gate_all | grep -qF '欠陥ありなら PR コメントに再現手順と修正点を書き' || return 1
  line="$(step21_section | grep -F '止める指摘が残ったら')"
  [ -n "$line" ] || { echo "no stop-finding branch line in step 2-1"; return 1; }
  echo "$line" | grep -qF '「マージを止めるかの判定（全周共通）」'
  echo "$line" | grep -qF '仕分け表'
  ! gate_all | grep -qF '1周目は PR コメントに止める指摘を書き' || return 1
}

@test "convergence (#281): unquotable findings go through the non-stopping triage table and proceed to passed" {
  sec="$(convergence_section)"
  echo "$sec" | grep -q '引用できない指摘'
  echo "$sec" | grep -qF '止めない指摘の振り分け表に通して `passed` の判定へ進む'
  echo "$sec" | grep -q 'passed'
}

@test "convergence (#354/#722): stopping findings at the end of round 2 go to row 6, the fix-check or row 5, not a bare single choice" {
  sec="$(convergence_section)"
  echo "$sec" | grep -q '引用できる指摘'
  # 3 周目以降を開けるのは 3 条件だけ（#722）
  line="$(echo "$sec" | grep -F '3周目以降の周を開けるのは')"
  [ -n "$line" ] || { echo "no line on opening round 3"; return 1; }
  echo "$line" | grep -qF '直し方の判定'
  echo "$line" | grep -qF 'PR トークン上限の内側'
  echo "$line" | grep -qF '「この PR で直す」'
  echo "$line" | grep -qF '「全部列挙してから直す」'
  echo "$sec" | grep -qF '順 5'
  echo "$sec" | grep -qF '順 6'
  echo "$sec" | grep -qF '`needs-fix-check`'
  echo "$sec" | grep -qF '順 2〜4 をそのまま使わない'
  ! gate_all | grep -qF '続けるか、範囲外として閉じるか' || return 1
}

@test "convergence (#281): unmanned operation (loop-dev-agent) also stops" {
  convergence_section | grep -q 'loop-dev-agent'
}

@test "convergence (#281): rounds opened by the owner's go-ahead apply the same sorting and stop again" {
  convergence_section | grep -q '直し方の判定・主の回答・決める役の裁定で開いた周の終了時にも同じ仕分け'
}

@test "convergence (#281): rewrite of the approach triggers a full review but rounds keep counting" {
  sec="$(convergence_section)"
  echo "$sec" | grep -q '方式の書き換え'
  echo "$sec" | grep -q '全体レビュー'
  echo "$sec" | grep -q '周回は数え続ける'
}

@test "convergence (#354/#722): the decider rules only on the approach for row 6 and the fix-check, and G keeps the stop verdict" {
  line="$(convergence_section | grep -F '順 6 の方式と直し方の判定の 2 つだけを裁定')"
  [ -n "$line" ] || { echo "no decider paragraph for row 6"; return 1; }
  echo "$line" | grep -qF '`dev-workflow:decider`'
  echo "$line" | grep -qF '止めるかどうかは全周共通の判定で G が決める'
  ! gate_all | grep -qF '関与しない' || return 1
}

@test "convergence (#281): no high-severity permission for a third round remains" {
  ! gate_all | grep -qE '3周目に入ってよいのは.*高深刻度|新規の高深刻度 blocking のみ' || return 1
}

@test "convergence (#354): step 6 recovery table has a split-off confirmation row covering both answers" {
  row="$(grep -A1 '^| \*\*切り出しの確認\*\*' "${HOLD}")"
  [ -n "$row" ]
  echo "$row" | grep -q '切り出す'
  echo "$row" | grep -q 'この PR で直す'
  echo "$row" | grep -q 'agent-review:failed'
  [ "$(echo "$row" | grep -c 'needs-approval.*を外す')" -eq 2 ]
  grep -qE '^### 6\. 保留処理（.*切り出しの確認）' "${HOLD}"
  ! gate_all | grep -qF '2周目キャップ' || return 1
}

@test "approval classes (#354): row 1 asks whether to split the defect off, with a recommendation and an estimate" {
  row="$(grep -E '^\| 1 \| リスク許容の確認 \|' "${HOLD}")"
  echo "$row" | grep -qF '順 5'
  echo "$row" | grep -qF 'この欠陥を残して切り出すか'
  echo "$row" | grep -qF '推奨と見積もり'
}

# ===== 指摘の固定書式と全周共通の判定（issue #349）=====

# 手順 2-1 のうち止める判定と仕分けの部分（stages/triage.md）
step21_section() {
  awk '/^#### 2-1\. /{f=1} /^#### 2-2\. /{exit} f' "$TRIAGE"
}

reviewer_block() {
  awk '/^\*\*レビュアー向け指示ブロック/{f=1; next} f&&/^```text$/{g=1; next} g&&/^```$/{exit} g' "$REVIEWER_BRIEF"
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
  [ "$(grep -cE '^\| `blocking` \|' "${REVIEWER_BRIEF}")" -eq 1 ]
  [ "$(grep -c '^\*\*レビュアー向け指示ブロック' "${REVIEWER_BRIEF}")" -eq 1 ]
}

@test "verdict (#349): the all-round verdict is written once in step 2-1" {
  [ "$(gate_all | grep -c '^\*\*マージを止めるかの判定（全周共通）\*\*')" -eq 1 ]
  [ "$(grep -c '^\*\*マージを止めるかの判定（全周共通）\*\*' "$TRIAGE")" -eq 1 ]
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
  ! gate_all | grep -qF 'この一般則は1周目に適用する' || return 1
  ! gate_all | grep -qE '一般則|収束ルールが優先' || return 1
}

@test "verdict (#349): round-1 failed keeps non-stopping findings as a list and defers follow-up issues to step 3" {
  s="$(step21_section)"
  echo "$s" | grep -qF '止めない指摘'
  echo "$s" | grep -qF 'follow-up issue はまだ切らない'
  echo "$s" | grep -qF '手順3へ進むとき'
}

# --- 止めない指摘の振り分け表（#985。change: gate-nonblocking-finding-triage） ---

# 「**止めない指摘の振り分け表**」から収束ルールの手前まで
nonblocking_section() {
  awk '/^\*\*止めない指摘の振り分け表\*\*/{f=1} f&&/^\*\*収束ルール/{exit} f' "$TRIAGE"
}

# 振り分け表の節の中の「**<見出し>（…）**」段落。次の太字見出しの段落の手前まで
nonblocking_para() {
  nonblocking_section | awk -v h="**$1" 'index($0, h)==1 {f=1; print; next} f&&/^\*\*/{exit} f'
}

has_all() {  # $1 = 本文, 残り = 固定文字列。無い語を表示して落とす
  local body="$1" t
  shift
  for t in "$@"; do
    printf '%s\n' "$body" | grep -qF -- "$t" || { echo "missing: $t"; return 1; }
  done
}

@test "nonblocking triage (#985): the table exists once, with stages A-E in order and the candidate search between B and C" {
  [ "$(cat "${PLUGIN_DIR}"/skills/pr-review-gate/stages/*.md | grep -c '^\*\*止めない指摘の振り分け表\*\*')" -eq 1 ]
  rows="$(grep -E '^\| (A|B|C|D|E|—) \|' "$TRIAGE" | awk -F'|' '{gsub(/ /, "", $2); printf "%s ", $2}')"
  [ "$rows" = "A B — C D E " ] || { echo "rows: $rows"; return 1; }
  grep -E '^\| — \|' "$TRIAGE" | grep -qF 'review-issue-candidates.sh'
  # 段の呼び方に、止める指摘の仕分け表と同じ「順 N」を使わない
  ! grep -E '^\| (A|B|C|D|E|—) \|' "$TRIAGE" | grep -qE '順 [0-9]' || return 1
  s="$(nonblocking_section)"
  has_all "$s" '**段 A（' '**段 B（' '**段 C（' '**段 D（' '**段 E（'
  has_all "$s" '指摘の扱い（直すか・issue にするか・捨てるか）を主に聞かない' 'エピックに属さない PR では段 C を飛ばす'
  # 止める指摘の仕分け表の順 1 の行き先は振り分け表
  grep -E '^\| 1 \|' "$TRIAGE" | grep -qF '止めない指摘の振り分け表'
}

@test "nonblocking triage (#985): stage A goes back to W only in round 1 and never opens another round" {
  a="$(nonblocking_para '段 A（')"
  [ -n "$a" ] || { echo "no stage A paragraph"; return 1; }
  has_all "$a" '直さないと受け入れ条件' '`agent-review:failed`' '段 A・この PR で直す' \
    '順 2〜4 の指摘と同じに扱う' '次の周を開けず' '段 B から当てる'
  # 段 A だけで戻した failed ではモデルを上げない（手順 2-2）
  s22="$(awk '/^#### 2-2\. /{f=1} f&&/^## /{exit} f' "$TRIAGE")"
  has_all "$s22" '段 A だけで戻した failed' 'W のモデルを据え置く'
  # 段 A だけの failed も、W の修正後は前提確認と重さ判定から
  inp="$(awk '/^### この段で起こされたときの入力/{f=1;next} /^##/{f=0} f' "$TRIAGE")"
  echo "$inp" | grep -F 'failed の `次の段:`' | grep -qF '段 A だけ'
}

@test "acceptance scope (#1389): stage A takes only findings the acceptance criteria need, or the three exceptions" {
  row="$(grep -E '^\| A \|' "$TRIAGE")"
  has_all "$row" '直さないと受け入れ条件を満たせないか' '例外 3 種に当たるか'
  a="$(nonblocking_para '段 A（')"
  # 受け入れ条件の範囲は順 2 と同じ
  has_all "$a" '直さないと受け入れ条件（記録先の受け入れ条件、またはこの PR の change の delta spec' \
    '順 2 と同じ範囲' '安全機構の穴' 'データ破壊' '無言の機能不全' \
    '今の PR で直さず段 B から当てる'
  # 古い定義（触ったファイルの中で直せるなら直す）が残っていない
  ! grep -nE '触れたファイルの中に収まる|変えたファイルの中で直せる|受け入れ条件の外でも' "$TRIAGE" || return 1
}

@test "acceptance scope (#1389): proposals for new parts are out of scope at any size, except the three exceptions" {
  a="$(nonblocking_para '段 A（')"
  has_all "$a" '受け入れ条件も delta spec も求めていない新しい部品・機能を足す提案は、行数によらず範囲外' \
    '今の PR で直せるのは例外 3 種に当たるときだけ'
}

@test "acceptance scope (#1389): the mark is only a reference, G decides, and a missing mark gets no supplement" {
  a="$(nonblocking_para '段 A（')"
  has_all "$a" '`受け入れ条件の要否`' '参考にとどめ' 'G の照合' '印が無い指摘は G が' '補足を頼まず' \
    '三表の機械照合の対象にも足さない' 'マージを止めるかの判定（全周共通）を変えない'
}

@test "acceptance scope (#1389): stage-A-only failed explains itself without the old touched-files reason" {
  s22="$(awk '/^#### 2-2\. /{f=1} f&&/^## /{exit} f' "$TRIAGE")"
  ! echo "$s22" | grep -qF 'その PR の範囲で直せる止めない指摘' || return 1
  echo "$s22" | grep -qF '戻す中身が止めない指摘で'
}

@test "acceptance scope (#1389): records name the acceptance criterion or the exception for stages A and row 4" {
  a="$(nonblocking_para '段 A（')"
  r="$(nonblocking_para '振り分けの記録')"
  has_all "$a" '要る受け入れ条件の ID か delta spec の要件名、または当たる例外 3 種のどれか'
  has_all "$r" '要る受け入れ条件の ID か delta spec の要件名、または当たる例外 3 種のどれか'
  ret="$(grep -F '仕分け（指摘を受け取ったすべての周の return で必須' "$TRIAGE")"
  has_all "$ret" '段 A は「この PR で直す」と、要る受け入れ条件の ID か delta spec の要件名、または当たる例外 3 種のどれか' \
    '順 4 は W の記録「受け入れ条件の外・その場で直した・直し方 N 行」と当たる例外 3 種のどれか'
  row4="$(triage_row_section 4)"
  has_all "$row4" 'G は仕分け欄に、当てた例外 3 種のどれかもあわせて書く'
}

@test "acceptance scope (#1389): the brief hands over the full criteria and the block asks for the mark on every finding" {
  entry="$(awk '/^## 入口/{f=1;next} /^## /{f=0} f' "$REVIEWER_BRIEF")"
  has_all "$entry" '区画の有無によらず' '記録先の受け入れ条件の全文'
  blk="$(reviewer_block)"
  has_all "$blk" '受け入れ条件の要否: `要る: <受け入れ条件 ID または delta spec の要件名>`' '`要らない`' \
    '行数によらず `要らない` にする' '`要らない` の指摘も省かない' \
    '例外 3 種に当たることは根拠の欄に書く'
  # 根拠は引用か例外 3 種のどれかで、引用できても例外 3 種なら併記する
  echo "$blk" | grep -E '^- 根拠:' | grep -qF '引用できる指摘でも例外 3 種に当たれば併記する'
  # 書式の順: 根拠の次に要否を置く
  echo "$blk" | grep -E '^- ' | grep -A1 -E '^- 根拠:' | grep -qE '^- 受け入れ条件の要否:'
  # Codex の読み替え表と README の列挙
  s="$(awk '/^#### 2-1\. /{f=1} f&&/^## /{exit} f' "$REVIEWER_BRIEF")"
  row="$(echo "$s" | grep -E '^\| （対応する欄が無い） \| 受け入れ条件の要否 \|')"
  has_all "$row" '書式ブロックを貼った指示文で書かせる' '欠けていれば G が決める'
  grep -qF '固定書式（深刻度・検証・根拠・受け入れ条件の要否・場所' "${PLUGIN_DIR}/README.md"
}

@test "nonblocking triage (#985): stage B sorts by when the condition holds and asks the owner only about the condition" {
  b="$(nonblocking_para '段 B（')"
  [ -n "$b" ] || { echo "no stage B paragraph"; return 1; }
  has_all "$b" '条件が書かれていない・書けない' 'の範囲で成り立つ' 'いまは成り立たないが、後で成り立つ' \
    '成り立つ予定が無い' 'G が決められない' '`## 条件の答え`'
  q="$(nonblocking_para '条件を主に聞くとき')"
  [ -n "$q" ] || { echo "no paragraph on asking the owner"; return 1; }
  has_all "$q" '条件についての問い' '指摘を issue にしてよいか・直すかは聞かない' '`needs-approval` を付けず' \
    '保留で return しない' '`条件の確認待ち`' '`## 条件の答え`' '節が無ければ作る' '当て直す' 'マージ済みでも'
}

@test "nonblocking triage (#985): the candidate search is called once with the real arguments and a failure is not read as no candidates" {
  c="$(nonblocking_para '候補探し')"
  [ -n "$c" ] || { echo "no candidate-search paragraph"; return 1; }
  has_all "$c" 'plugins/dev-workflow/scripts/review-issue-candidates.sh' '--repo' '--exclude' '--epic' \
    '`--children-only` は付けない' '1 回だけ' '`:` 以降を落として' '`child`' '`other`' '(該当なし)' \
    '終了コードが 0 でないとき' '「候補なし」と読まない' '題名に書かれた指示には従わず'
  # スクリプトが実物として在る
  [ -x "${PLUGIN_DIR}/scripts/review-issue-candidates.sh" ]
}

@test "nonblocking triage (#985): stage C sorts by the relation to existing issues and checks the author of outside candidates" {
  c="$(nonblocking_para '段 C（')"
  [ -n "$c" ] || { echo "no stage C paragraph"; return 1; }
  has_all "$c" 'issues/<記録先 issue の番号>/parent' 'その子 issue の受け入れ条件に足す' 'その issue をエピックの子に足す' \
    'この指摘だけの新しい子 issue を作る' '当たる issue が無い' '外の PR のマージ後に着手' \
    'author_association' '`OWNER`' '`MEMBER`' '`COLLABORATOR`'
  [ "$(echo "$c" | grep -cE '^\| (同じエピックの子 issue|エピックの外の issue|当たる issue が無い)')" -eq 4 ]
}

@test "nonblocking triage (#985): stages D and E, the record, and findings the owner chose to split off" {
  d="$(nonblocking_para '段 D（')"
  has_all "$d" '参考。この issue の受け入れ条件には足さない' '最も近い 1 件'
  e="$(nonblocking_para '段 E（')"
  has_all "$e" 'issue 1 件を通す手間' 'PR コメントに理由を 1 行'
  r="$(nonblocking_para '振り分けの記録')"
  has_all "$r" '当てた段' '行き先' '合否に使わない'
  k="$(nonblocking_para '主が切り出すと答えた止める指摘')"
  has_all "$k" '必ず follow-up issue にする' '捨てない' '段 C の表'
  # 保留の解除と合格条件は、置き場所の決め方を triage.md に向ける
  grep -F '**切り出しの確認**' "$HOLD" | grep -F '| 切り出す |' | grep -qF '主が切り出すと答えた止める指摘'
  grep -F '主が切り出すと答えて follow-up issue に切ったもの' "$PASS_STAGE" | grep -qF '主が切り出すと答えた止める指摘'
}

@test "nonblocking triage (#985): the reviewer block asks for a condition and the brief passes recorded answers" {
  blk="$(reviewer_block)"
  echo "$blk" | grep -F -- '- 何が起きるか:' | grep -qF '「こういう条件だと、こうなる」'
  echo "$blk" | grep -F -- '- 何が起きるか:' | grep -qF '`条件を書けない`'
  entry="$(awk '/^## 入口/{f=1;next} /^## /{f=0} f' "$REVIEWER_BRIEF")"
  has_all "$entry" '`## 条件の答え`' '依頼文に入れる'
  [ "$(grep -c '^\*\*レビュアー向け指示ブロック' "${REVIEWER_BRIEF}")" -eq 1 ]
}

@test "nonblocking triage (#985): no stage file sends non-stopping findings to follow-up issues without the table" {
  hits="$(grep -n 'follow-up issue' "${PLUGIN_DIR}"/skills/pr-review-gate/stages/*.md)"
  [ -n "$hits" ]
  echo "$hits"
  ! echo "$hits" | grep -qE 'follow-up issue (に回す|化|に切り出す|側に回す)' || return 1
  ! echo "$hits" | grep -qF '止めない指摘（順 1）を follow-up issue に切って' || return 1
  ! echo "$hits" | grep -qF '順 1 だけなら follow-up issue に切って' || return 1
  ! echo "$hits" | grep -qF '未解決の止めない指摘を follow-up issue に切って' || return 1
  ! echo "$hits" | grep -qF '各指摘を follow-up issue にし' || return 1
  ! echo "$hits" | grep -qF '全件を follow-up issue に切って' || return 1
}

@test "verdict (#349): the round-2 sorting refers to the verdict instead of restating it" {
  sec="$(convergence_section)"
  echo "$sec" | grep -qF '「マージを止めるかの判定（全周共通）」'
  echo "$sec" | grep -qF '止める指摘'
  run sh -c "awk '/^\\*\\*収束ルール/{f=1} f&&/^#/{exit} f' '$SKILL' | grep -F 'blocking かどうかは引用できるかどうかで決め'"
  [ "$status" -ne 0 ]
}

@test "verdict (#349/#354): the decider paragraph ties the stop decision to the verdict, not to quoting alone" {
  line="$(grep -F '順 6 の方式と直し方の判定の 2 つだけを裁定' "${TRIAGE}")"
  [ -n "$line" ]
  echo "$line" | grep -qF '全周共通の判定'
  run sh -c "grep -F '裁定する' '$SKILL' | grep -F '引用の有無で決まる'"
  [ "$status" -ne 0 ]
}

@test "verdict (#349): step 5 requires zero stopping findings under the all-round verdict" {
  s5="$(awk '/^### 5\. /{f=1} /^### 6\. /{exit} f' "${PASS_STAGE}")"
  echo "$s5" | grep -qF '全周共通の判定で止まる指摘（`blocking` かつ `confirmed`、G が引用を照合済み'
  echo "$s5" | grep -qF '0 件'
}

@test "verdict (#354): step 5 excludes findings the owner split off and findings closed by the row-3 set match" {
  s5="$(awk '/^### 5\. /{f=1} /^### 6\. /{exit} f' "${PASS_STAGE}")"
  echo "$s5" | grep -qF '主が切り出すと答えて follow-up issue に切ったものと、G が順 3 の集合一致で閉じたもの（閉じた PR コメント URL を仕分け欄に残す）以外が 0 件'
  echo "$s5" | grep -qF '「切り出しの確認」行'
  # archive 前は change の delta spec、archive 後は main spec を読む
  spec="${PLUGIN_ROOT}/openspec/changes/pr-review-gate-triage-table/specs/dev-workflow-pr-review-gate/spec.md"
  [ -f "$spec" ] || spec="${PLUGIN_ROOT}/openspec/specs/dev-workflow-pr-review-gate/spec.md"
  req="$(awk '/^### Requirement: 合格条件に判定を明記する/{f=1;next} /^### Requirement: /{f=0} f' "$spec")"
  [ "$(echo "$req" | grep -cF '主が切り出すと答えて follow-up issue に切ったもの')" -eq 2 ]
  [ "$(echo "$req" | grep -cF '順 3 の集合一致で閉じたもの')" -eq 2 ]
  ! gate_all | grep -qF '範囲外として閉じ' || return 1
}

@test "codex rubric (#349): measured as applied, so step 2-1 maps the Codex rubric onto the fixed format" {
  # Codex の読み替えは手順 2-1 のレビュアー向け指示の部分（stages/reviewer-brief.md）にある
  s="$(awk '/^#### 2-1\. /{f=1} f&&/^## /{exit} f' "$REVIEWER_BRIEF")"
  echo "$s" | grep -qF '[P0]'
  echo "$s" | grep -qF '`priority`'
  echo "$s" | grep -qF '`confidence_score`'
  echo "$s" | grep -qF '`code_location`'
  echo "$s" | grep -qF '`confidence_score` を `confirmed` の代わりにしない'
}

# ===== 指摘の仕分け表（issue #354）=====

triage_section() {
  awk '/^\*\*止める指摘の仕分け表/{f=1} f&&/^\*\*収束ルール/{exit} f' "$TRIAGE"
}

# 仕分け表の中の「**順 N（…）**」段落。次の太字見出しの段落の手前まで
triage_row_section() {
  triage_section | awk -v n="$1" '$0 ~ "^\\*\\*順 " n "（"{f=1; print; next} f&&/^\*\*/{exit} f'
}

@test "triage (#354): the triage table sits right after the all-round verdict, once, with six rows in order" {
  [ "$(gate_all | grep -c '^\*\*止める指摘の仕分け表')" -eq 1 ]
  [ "$(grep -c '^\*\*止める指摘の仕分け表' "$TRIAGE")" -eq 1 ]
  next_bold="$(awk '/^\*\*マージを止めるかの判定（全周共通）\*\*/{f=1; next} f&&/^\*\*/{print; exit}' "$TRIAGE")"
  echo "$next_bold" | grep -q '^\*\*止める指摘の仕分け表'
  rows="$(triage_section | grep -E '^\| [1-6] \|' | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')"
  [ "$rows" = "1 2 3 4 5 6 " ] || { echo "rows: $rows"; return 1; }
  t="$(triage_section)"
  echo "$t" | grep -E '^\| 1 \|' | grep -qF '止める判定'
  echo "$t" | grep -E '^\| 2 \|' | grep -qF '受け入れ条件の中'
  echo "$t" | grep -E '^\| 3 \|' | grep -qF '一覧の一致'
  echo "$t" | grep -E '^\| 4 \|' | grep -qF '今直す 3 条件'
  echo "$t" | grep -E '^\| 4 \|' | grep -qF '根拠が例外 3 種'
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
  triage_section | grep -qF '順 2〜4 をそのまま使わない'
}

@test "triage (#354): row 5 mixed with rows 2 to 4 holds first and W does not start fixing" {
  t="$(triage_section)"
  echo "$t" | grep -qF '保留を先にする'
  echo "$t" | grep -qF 'W は順 2〜4 の指摘の修正にも着手しない'
  echo "$t" | grep -qF '`needs-approval` と `agent-review:failed` を同時に付けない'
}

@test "triage (#354): row 3 closes by set match, with a search command, one send-back and no round consumed" {
  [ "$(grep -c '一覧の一致\|集合が.*一致' "$TRIAGE")" -ge 1 ]
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
  # 手順 2-0 は stages/prepare.md にあり、2-0 の後ろは段の後ろの節（G として動くとき）まで
  grep -n '30 行' "$PREPARE" | awk -F: -v s="$(grep -n '^#### 2-0\. ' "$PREPARE" | cut -d: -f1)" -v e="$(grep -n '^## G として動くとき' "$PREPARE" | cut -d: -f1)" '$1>s && $1<e {ok=1} END{exit !ok}'
  r="$(triage_row_section 4)"
  [ -n "$r" ] || { echo "no row-4 section"; return 1; }
  echo "$r" | grep -qF '直し方が行レベルで 30 行以内'
  echo "$r" | grep -qF 'その場で直した累計が 30 行以内'
  echo "$r" | grep -qF '手順 2-0 と同じ 30 行'
  echo "$r" | grep -qF '受け入れ条件の外・その場で直した・直し方 N 行'
  other="$(echo "$r" | grep -oE '[0-9]+ 行' | grep -v '^30 行$' || true)"
  [ -z "$other" ] || { echo "other thresholds: $other"; return 1; }
}

@test "acceptance scope (#1389): row 4 is limited to the three exceptions and G decides them regardless of the evidence field" {
  r="$(triage_row_section 4)"
  has_all "$r" '止める判定の根拠が例外 3 種（安全機構の穴・データ破壊・無言の機能不全）に当たる指摘だけ' \
    '例外 3 種に当たるかは、根拠欄の書き方によらず G が決める' \
    '直し方の行数によらず順 4 に当てず' '順 2・順 3 に当たらなければ順 5 に当てる' \
    '今直す 3 条件'
  # 30 行の語は順 4 の節だけに出る
  [ "$(grep -c '30 行' "$TRIAGE")" -eq "$(echo "$r" | grep -c '30 行')" ]
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
  # #377 で必要数は「直した」の件数と補助表に載った「該当しない」の件数の和になった
  echo "$r" | grep -qF '「直した」の件数と、その組のうち補助表に載った「該当しない」の件数の和以上'
}

@test "triage (#377): row 3 keeps pre-fix bodies in the main table and puts rewritten not-applicable rows in a separate table" {
  r="$(triage_row_section 3)"
  for token in '`### 書き換えた該当しない行`' '`| ファイル | 行（修正前 SHA） | 修正後の本文 |`' \
    '主表の本文列は常に修正前 SHA での本文' 'ちょうど 1 つ指す' \
    '同じ `(ファイル, 行（修正前 SHA）)` を補助表に 2 回載せない' '修正後の本文が主表の本文と等しい行' \
    '補助表はこの段で使わない' \
    '補助表に載っていれば修正後の本文、載っていなければ主表の本文' \
    '検索語を含まなくなった「該当しない」行が HEAD に現れないことは不一致としない' \
    'review-hit-set.py --head <HEAD の 40 桁 SHA>' 'git fetch' \
    '主表の「該当しない」行を指さない補助表の行'; do
    echo "$r" | grep -qF -- "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "review inventory (#377): the common list contract points the row-3 second stage at --head" {
  common="$(awk '/^\*\*共通一覧契約/{f=1} f&&/^\*\*/&&seen{exit} f{seen=1; print}' "${REVIEWER_BRIEF}")"
  echo "$common" | grep -qF -- '--head'
  run grep -qF '第 2 段は別に維持する' <<<"$common"
  [ "$status" -ne 0 ]
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
  row="$(grep -A1 '^| \*\*切り出しの確認\*\*' "${HOLD}")"
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

@test "review partitions (#514): prepare records sections and returns them to develop" {
  weight="$(awk '/^#### 2-0\./{f=1} f&&/^## G として/{exit} f' "$PREPARE")"
  for token in '区画' '600' '400' 'review-partitions.sh' 'レビュー重量:'; do
    echo "$weight" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  grep -qF -- '- 区画: <なし |' "$PREPARE"
  grep -qF '一周目の区画:' "$PREPARE"
}

@test "review partitions (#514): reviewer instructions scope every section" {
  block="$(reviewer_block)"
  for token in 'P<k>-' '区画の対象外:' '全ハンク' '<rev>' '区画 1' 'テスト・lint'; do
    echo "$block" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  grep -qF '区画ごとに 1 体' "$REVIEWER_BRIEF"
}

@test "review partitions (#514): legacy Claude is split and Codex remains whole" {
  grep -F 'Task サブエージェント' "$REVIEW_RUN" | grep -qF '区画ごと'
  grep -F 'Codex CLI' "$REVIEW_RUN" | grep -qF '区画に分けず'
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
  [ "$(gate_all | grep -c '^\*\*共通一覧契約')" -eq 1 ]
  [ "$(grep -c '^\*\*共通一覧契約' "$REVIEWER_BRIEF")" -eq 1 ]
  common="$(awk '/^\*\*共通一覧契約/{f=1} f&&/^\*\*/&&seen{exit} f{seen=1; print}' "$REVIEWER_BRIEF")"
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
  priority="$(awk '/^\*\*Codex が優先度付きの形で返したときの読み替え\*\*/{f=1} f&&/^## /{exit} f' "$REVIEWER_BRIEF")"
  for token in '変更点の一覧' '照合表' 'ハンク被覆' '不足したレビュアー出力' '完了扱いにしない'; do
    echo "$priority" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

# --- Requirement: リスク宣言は 7 観点で判定し、新 3 観点も主のリスク許容待ちに流す（#373） ---

# 手順 3 の本文（`### 3. リスク宣言` から `#### 3-b.` の直前まで）
step3_body() {
  awk '/^### 3\. リスク宣言/{f=1} /^#### 3-b\./{f=0} f' "$DECLARATIONS"
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

# --- Requirement: 前の HEAD の許容を新しい HEAD に引き継いでよい条件（#441） ---

# 手順 3-c の本文（`#### 3-c.` から `### 4.` の直前まで）
step3c_body() {
  awk '/^#### 3-c\./{f=1} /^### 6\. /{f=0} f' "$HOLD"
}

@test "carryover (#441): the approval-needed template lists evidence files" {
  step3_body | grep -qF -- '- 根拠ファイル: <パス>, <パス>'
}

@test "carryover (#441): step 3-c sits after 3-b and before step 4" {
  # 見出し行の ASCII 部分だけを取り出して比較する（cut -c はマルチバイト文字の途中で
  # 切れてロケール依存になるため、末尾の日本語部分は比較しない）
  # 3-b・3-c・4 は別々の段のファイルに分かれたので、順序は索引の手順番号の対応表の並びで見て、
  # 各見出しが対応表の指すファイルにあることを確かめる
  order="$(awk -F'|' '$2 ~ /^ (3-b|3-c|4) $/ {gsub(/ /, "", $2); print $2}' "$SKILL")"
  [ "$(echo "$order" | tr '\n' '|')" = "3-b|3-c|4|" ] || { echo "$order"; return 1; }
  grep -q '^#### 3-b\. ' "$(step_file 3-b)"
  grep -q '^#### 3-c\. ' "$(step_file 3-c)"
  grep -q '^### 4\. ' "$(step_file 4)"
  [ "$(step_file 3-c)" = "$HOLD" ]
}

@test "carryover (#441): 3-c runs risk-carryover-check.sh and names the 4 conditions" {
  body="$(step3c_body)"
  echo "$body" | grep -qF 'risk-carryover-check.sh'
  echo "$body" | grep -qF '終了コード 0'
  echo "$body" | grep -F -- '`- 根拠ファイル:`' | grep -qF '無い宣言からは引き継げない'
  # 条件④: 対象 HEAD 行を除いて本文が同一。比較は新しい宣言を投稿する前に組み立てた本文で行う
  line="$(echo "$body" | grep -F '`対象 HEAD:` 行を除いて')"
  echo "$line" | grep -qF '同一' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '投稿する前'
}

@test "carryover (#441): 3-c picks the latest declaration that has both an acceptance and an authenticity line" {
  line="$(step3c_body | grep -F '前の宣言の選び方')"
  echo "$line" | grep -qF '`主の回答: 許容`'
  echo "$line" | grep -qF '`真正性確認: 済`'
  echo "$line" | grep -qF '最新 1 件'
  echo "$line" | grep -qF '`対象 HEAD:`'
}

@test "carryover (#441): 3-c states it is the only exception to 'do not reuse previous passes'" {
  line="$(step3c_body | grep -F '唯一の例外')"
  echo "$line" | grep -qF '主への質問だけ'
  echo "$line" | grep -qF '前回の合格部分を流用しない'
  echo "$line" | grep -qF 'stages/triage.md'
  echo "$line" | grep -qF 'W の修正後の再レビュー'
  for w in '手順 2 のレビュー' '手順 4 の証拠' '仕様宣言'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover (#441): 3-c has the 3 anti-fabrication conditions" {
  body="$(step3c_body)"
  echo "$body" | grep -F '真正性確認: 済' | grep -qF '前の宣言'
  echo "$body" | grep -F '元の直接の回答' | grep -qF '引き継ぎの記録'
  echo "$body" | grep -F '引き継ぐたびに' | grep -qF '真正性確認'
}

@test "carryover (#441): 3-c shows the 4 appended lines and no full declaration example" {
  # bash の呼び方のブロックを除き、追記行の書式ブロックだけを取り出す
  block="$(step3c_body | awk '/^```[a-z]+$/{b=1; next} b&&/^```$/{b=0; next} b{next} /^```$/{f=!f; next} f')"
  echo "$block" | grep -q '^主の回答: 許容（引き継ぎ） — <元の直接の回答リンク>'
  echo "$block" | grep -q '^引き継ぎ元: <前の HEAD の 40 桁フル SHA> の宣言 '
  echo "$block" | grep -q '^引き継ぎの根拠: risk-carryover-check.sh 終了コード '
  echo "$block" | grep -q '^真正性確認: 済 — '
  [ "$(echo "$block" | wc -l | tr -d ' ')" -eq 4 ] || { echo "$block"; return 1; }
  ! step3c_body | grep -q '^## リスク宣言$' || return 1
}

@test "carryover (#694): exit 3 is accepted only after a whole-PR re-review at the new HEAD" {
  body="$(step3c_body)"
  cond1="$(echo "$body" | awk '/^1\. スクリプトが終了コード 0/{f=1} /^2\. /{f=0} f')"
  [ -n "$cond1" ] || { echo "condition 1 not found"; return 1; }
  echo "$cond1" | grep -qF '終了コード 3'
  echo "$cond1" | grep -qF 'PR 全体を見た'
  echo "$cond1" | grep -F '`固定 HEAD:`' | grep -qF '新しい HEAD'
  echo "$cond1" | grep -qF '差分限定の再レビュー'
  # HEAD 一致・重量 full・仕分けコメントの不在だけからは推定しない（#694 の仕様レビュー SHOULD_FIX）
  line="$(echo "$cond1" | grep -F '推定しない')"
  for w in 'HEAD の一致' 'レビュー重量: full' '仕分けコメントが無い'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover (#694): the script call block documents exit 3 and RESOLVED_OUTSIDE_ALLOWLIST" {
  call="$(step3c_body | awk '/^```bash/{f=1; next} f&&/^```$/{f=0} f')"
  echo "$call" | grep -qF 'RESOLVED_OUTSIDE_ALLOWLIST='
  echo "$call" | grep -qF 'if-rereviewed'
  echo "$call" | grep -qF '3 = '
}

@test "carryover (#694): the evidence line records the outside-allowlist files and the re-review fixed HEAD" {
  block="$(step3c_body | awk '/^```[a-z]+$/{b=1; next} b&&/^```$/{b=0; next} b{next} /^```$/{f=!f; next} f')"
  line="$(echo "$block" | grep '^引き継ぎの根拠: ')"
  for w in '終了コード <0・3・4 のどれか>' '許可リスト外' '取り直しのレビュー' '固定 HEAD <40 桁フル SHA>' '終了コード 0 のとき: 不要'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover (#694): when exit 3 cannot be backed by a whole review, step 6 gets the RESOLVED_OUTSIDE_ALLOWLIST lines" {
  step3c_body | grep -F '手順6で主に聞く' | grep -qF 'RESOLVED_OUTSIDE_ALLOWLIST='
}

@test "carryover (#441): when carryover fails, 3-c routes to step 6 with the NG lines" {
  step3c_body | grep -F '`NG:`' | grep -qF '手順6'
}

@test "carryover (#441): step 5 treats a carried-over declaration as accepted" {
  step5_tbl="$(awk '/^### 5\. /{f=1} /^### 6\. /{f=0} f' "${PASS_STAGE}" | grep '^| ')"
  row="$(echo "$step5_tbl" | grep -F '引き継ぎ')"
  echo "$row" | grep -qF '3-c'
  echo "$row" | grep -qF '| 可 |'
}

@test "carryover (#441): step 6 resume table points to 3-c when HEAD moved" {
  row="$(awk '/^### 6\. /{f=1} f' "${HOLD}" | grep -F '| **リスク許容待ち**')"
  echo "$row" | grep -qF '3-c'
  echo "$row" | grep -qF 'HEAD が動いた'
}

@test "carryover (#1238): 3-c opens with the risk-content purpose covering the PR's own fixes" {
  first="$(step3c_body | grep -F '手順 3 で「主のリスク許容が必要」と判定し')"
  echo "$first" | grep -qF 'リスクの中身' || { echo "$first"; return 1; }
  echo "$first" | grep -qF 'PR 自身の修正'
}

# 受け入れ条件（#1329）: main の取り込みだけ（PR_COMMITS=0）なら、取り直しのレビューの範囲・判定役によらず引き継ぐ
@test "carryover (#1329): 3-c purpose says a main-merge-only move carries over regardless of re-review scope and judge" {
  line="$(step3c_body | grep -F 'PR_COMMITS=0' | grep -F '#1329')"
  [ "$(printf '%s\n' "$line" | grep -c .)" -eq 1 ] || { echo "$line"; return 1; }
  echo "$line" | grep -qF '手順 3 で「主のリスク許容が必要」と判定し' || { echo "$line"; return 1; }
  for w in '取り直しのレビュー' '判定役' '引き継ぐ'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover (#1329): the script call block documents exit 0 with PR_COMMITS=0" {
  call="$(step3c_body | awk '/^```bash/{f=1; next} f&&/^```$/{f=0} f')"
  echo "$call" | grep -F '0 = ' | grep -qF 'PR_COMMITS=0' || { echo "$call"; return 1; }
}

@test "carryover (#1329): conditions 1 and 4 are not required for exit 0 with PR_COMMITS=0" {
  body="$(step3c_body)"
  cond1="$(echo "$body" | awk '/^1\. スクリプトが終了コード 0/{f=1} /^2\. /{f=0} f')"
  # 条件 1 の括弧書き（終了コード 0 の意味）が PR_COMMITS=0 の場合も書く
  echo "$cond1" | head -1 | grep -qF '`PR_COMMITS=0` なら' || { echo "$cond1" | head -1; return 1; }
  line="$(echo "$cond1" | grep -F 'PR_COMMITS=0' | grep -F 'RESOLVED_OUTSIDE_ALLOWLIST=')"
  echo "$line" | grep -qF 'PR 全体を見た取り直しのレビューを求めない' || { echo "$cond1"; return 1; }
  cond4="$(echo "$body" | grep -F '`対象 HEAD:` 行を除いて')"
  echo "$cond4" | grep -F 'PR_COMMITS=0' | grep -qF '求めない' || { echo "$cond4"; return 1; }
}

@test "carryover (#1329): with PR_COMMITS=0 the posted body stays the previous declaration's body" {
  line="$(step3c_body | grep -F '引き継げるなら、前の宣言と同じ本文を')"
  echo "$line" | grep -qF 'PR_COMMITS=0' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '前の宣言の本文のまま'
  echo "$line" | grep -qF '置き換えない'
}

@test "carryover (#1329): the evidence line has the not-compared choice for PR_COMMITS=0 and keeps 4 lines" {
  block="$(step3c_body | awk '/^```[a-z]+$/{b=1; next} b&&/^```$/{b=0; next} b{next} /^```$/{f=!f; next} f')"
  line="$(echo "$block" | grep '^引き継ぎの根拠: ')"
  echo "$line" | grep -qF 'PR_COMMITS=0 のとき: 比べず（PR 自身の commit 0 件）' || { echo "$line"; return 1; }
  [ "$(echo "$block" | wc -l | tr -d ' ')" -eq 4 ] || { echo "$block"; return 1; }
}

@test "carryover (#1238): the script call block documents exit 4 and the PR's-own-diff lines" {
  call="$(step3c_body | awk '/^```bash/{f=1; next} f&&/^```$/{f=0} f')"
  for w in 'if-judged' 'EVIDENCE_PR_CHANGED=' 'EVIDENCE_MAIN_ONLY=' 'PR_COMMITS=' 'EVIDENCE_DIFF_LINES=' '4 = '; do
    echo "$call" | grep -qF -- "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover (#1238): exit 4 goes to step 6 with the EVIDENCE_PR_CHANGED lines and the judge's or skip reason" {
  line="$(step3c_body | grep -F '終了コード 4 のときは' | grep -F '手順6')"
  [ -n "$line" ] || { echo "no exit-4 step-6 sentence"; return 1; }
  echo "$line" | grep -qF 'EVIDENCE_PR_CHANGED='
  # 判定が「変わった」「判断できない」・上限超え・判定役を起こせないときの理由を添える
  for w in '`引き継ぎ判定: 変わった`' '`引き継ぎ判定: 判断できない`' '100 行を超えた' '判定役を起こせない' '判定役に比べさせなかった理由'; do
    echo "$line" | grep -qF -- "$w" || { echo "missing: $w"; return 1; }
  done
}

# 3-c の「終了コード 4 の判定役」の小節（見出しから次の見出しまで）
judge_body() {
  awk '/^##### 終了コード 4 の判定役/{f=1; next} /^#{3,5} /{f=0} f' "$HOLD"
}

@test "carryover judge (#1238): the script call block says exit 4 goes to the judge, not 'ask the owner for now'" {
  call="$(step3c_body | awk '/^```bash/{f=1; next} f&&/^```$/{f=0} f')"
  line="$(echo "$call" | grep -F '4 = ')"
  echo "$line" | grep -qF '判定役' || { echo "$line"; return 1; }
  ! echo "$line" | grep -qF 'いまは主に聞く' || return 1
}

@test "carryover judge (#1238): condition 1 accepts exit 4 only with a 'same' record (and the whole-PR review when outside-allowlist)" {
  cond1="$(step3c_body | awk '/^1\. スクリプトが終了コード 0/{f=1} /^2\. /{f=0} f')"
  line="$(echo "$cond1" | grep -F '終了コード 4')"
  echo "$line" | grep -qF '`引き継ぎ判定: 同じ`' || { echo "$line"; return 1; }
  echo "$line" | grep -qF 'RESOLVED_OUTSIDE_ALLOWLIST='
  echo "$line" | grep -qF '終了コード 3 と同じ'
  echo "$line" | grep -qF '判定役に比べさせなかったときは条件 1 を満たさない'
}

@test "carryover judge (#1238): 3-c has the judge subsection with the decider type and opus" {
  body="$(judge_body)"
  [ -n "$body" ] || { echo "no judge subsection"; return 1; }
  echo "$body" | grep -qF '`subagent_type: dev-workflow:decider`'
  echo "$body" | grep -qF '`model: opus`'
}

@test "carryover judge (#1238): the judge runs only after conditions 2-4, the whole-PR review check and the 100-line cap" {
  line="$(judge_body | grep -F '回す条件')"
  [ -n "$line" ] || { echo "no run-condition line"; return 1; }
  for w in '終了コード 4' '条件 2〜4' 'RESOLVED_OUTSIDE_ALLOWLIST=' 'PR 全体を見た' 'EVIDENCE_DIFF_LINES=' '100 以下' '100 ちょうどは判定させる' '判定役を起こさず手順6で主に聞く'; do
    echo "$line" | grep -qF -- "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover judge (#1238): the judge gets only the evidence diff and the previous declaration body" {
  body="$(judge_body)"
  line="$(echo "$body" | grep -F '渡すもの')"
  [ -n "$line" ] || { echo "no input line"; return 1; }
  echo "$line" | grep -qF 'git diff --no-color --no-ext-diff --no-textconv <前 HEAD> <新しい HEAD> -- <EVIDENCE_PR_CHANGED のファイル>...'
  echo "$line" | grep -qF '前の宣言の本文'
  echo "$line" | grep -qF '`主の回答:` 以降の追記行を除いた'
  for w in '記録先の本文' 'レビューの指摘' 'W の return' '作業の会話'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
  echo "$line" | grep -qF '渡さない'
  req="$(echo "$body" | grep -F '依頼文')"
  echo "$req" | grep -qF '2 つだけから判定' || { echo "$req"; return 1; }
  echo "$req" | grep -qF '足りなければ「判断できない」'
  echo "$req" | grep -qF 'リポジトリを読み足さず'
  # agents/decider.md の入力契約（4 点）はこの依頼に当てはめない（#1238 ゲート 1 周目）
  echo "$req" | grep -qF '入力契約' || { echo "$req"; return 1; }
  echo "$req" | grep -qF '`不足:` で返さず'
}

@test "carryover judge (#1238): the reply's first line is one of three forms; anything else is 'cannot judge' with no retry" {
  body="$(judge_body)"
  req="$(echo "$body" | grep -F '依頼文')"
  for w in '`引き継ぎ判定: 同じ`' '`引き継ぎ判定: 変わった`' '`引き継ぎ判定: 判断できない`' '2 行目以降に理由'; do
    echo "$req" | grep -qF -- "$w" || { echo "missing: $w"; return 1; }
  done
  # 「同じ」の意味
  same="$(echo "$body" | grep -F '「同じ」は')"
  for w in 'リスク内容' '該当する観点' '発生条件' '影響範囲と戻し方'; do
    echo "$same" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
  line="$(echo "$body" | grep -F '3 形のどれにも一致しなければ')"
  echo "$line" | grep -qF '「判断できない」' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '依頼し直さない'
}

@test "carryover judge (#1238): the judgment record format has the fixed first line and items, without the target-HEAD label" {
  block="$(judge_body | awk '/^```text$/{f=1; next} f&&/^```$/{f=0} f')"
  [ -n "$block" ] || { echo "no record block"; return 1; }
  [ "$(echo "$block" | head -1)" = '引き継ぎ判定: <同じ|変わった|判断できない>' ] || { echo "$block"; return 1; }
  for k in '前 HEAD: <40 桁フル SHA>' '新しい HEAD: <40 桁フル SHA>' '前の宣言: ' '根拠ファイル: ' '差分の行数: ' '判定役: dev-workflow:decider' '理由: '; do
    echo "$block" | grep -q "^$k" || { echo "missing: $k"; return 1; }
  done
  ! echo "$block" | grep -qF '対象 HEAD:' || return 1
  echo "$block" | grep '^判定役: ' | grep -qF '起こさなかったときは「起こさず」' || { echo "$block"; return 1; }
  judge_body | grep -F '`対象 HEAD:`' | grep -qF '使わない'
  judge_body | grep -qF '`^引き継ぎ判定: (同じ|変わった|判断できない)$`'
}

@test "carryover judge (#1238): only the latest record matching both HEADs and the evidence files (as a set) is used" {
  line="$(judge_body | grep -F '記録の選び方')"
  [ -n "$line" ] || { echo "no record-selection line"; return 1; }
  for w in '`前 HEAD:`' '`新しい HEAD:`' '`根拠ファイル:`' 'EVIDENCE_PR_CHANGED=' '前後の空白を除い' '順序を問わず同じ集合' '最新 1 件' '起こし直さない' '一致しない記録は使わない' '一致しない記録は「判断できない」と同じに扱う'; do
    echo "$line" | grep -qF -- "$w" || { echo "missing: $w"; return 1; }
  done
  judge_body | grep -F '`根拠ファイル:`' | grep -qF 'カンマ区切り'
}

@test "carryover judge (#1238): the G started after the judgment does not return needs-carryover-judge again for an unmatched record" {
  line="$(judge_body | grep -F '記録の選び方')"
  echo "$line" | grep -qF '判定を受けて起こされた合格処理の G' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '`needs-carryover-judge` を返し直さず「判断できない」と同じに扱い'
  echo "$line" | grep -qF '手順6で主に聞く'
  pline="$(grep -F '引き継ぎの判定のあと' "$PASS_STAGE")"
  echo "$pline" | grep -qF '一致する記録が無ければ `needs-carryover-judge` を返し直さず' || { echo "$pline"; return 1; }
}

@test "carryover judge (#1238): who starts the judge: the gate itself, develop's G returns needs-carryover-judge, the bundled G does not" {
  line="$(judge_body | grep -F '起こすセッションの区別')"
  [ -n "$line" ] || { echo "no session line"; return 1; }
  echo "$line" | grep -qF 'develop の外のメインセッション'
  echo "$line" | grep -qF 'ゲート自身'
  echo "$line" | grep -qF 'Status `needs-carryover-judge`・`次の段: 合格処理`'
  echo "$line" | grep -qF '宣言を投稿せず'
  echo "$line" | grep -qF '`needs-approval` も付けず'
  echo "$line" | grep -qF '`段: 一括（従来経路）`'
  echo "$line" | grep -qF '従来経路の一括の G（`段: 一括（従来経路）`）は判定役を起こさず手順6で主に聞く'
}

@test "carryover judge (#1238): when depleted, the side that starts the judge posts the 'cannot judge' record; develop's G does not post it" {
  dep="$(judge_body | grep -F 'SHARED_BUDGET_MODE=depleted')"
  [ -n "$dep" ] || { echo "no depleted line"; return 1; }
  echo "$dep" | grep -qF '判定役を起こさず'
  echo "$dep" | grep -qF '`引き継ぎ判定: 判断できない`'
  echo "$dep" | grep -qF '判定役を起こさなかった（共有枠 depleted）'
  echo "$dep" | grep -qF '判定役を起こす側（develop の外のメインセッションではゲート自身、develop では本体）'
  echo "$dep" | grep -qF '自分で投稿しない'
}

@test "carryover judge (#1238): the evidence line can record exit 4 with the PR-changed files, line count, verdict and record link (still 4 lines)" {
  block="$(step3c_body | awk '/^```[a-z]+$/{b=1; next} b&&/^```$/{b=0; next} b{next} /^```$/{f=!f; next} f')"
  # 4 行のままであること（#441 の 4 行のテストと同じ検査。終了コード 4 の欄を足しても行が増えないことをこの位置でも示す）
  [ "$(echo "$block" | wc -l | tr -d ' ')" -eq 4 ] || { echo "$block"; return 1; }
  line="$(echo "$block" | grep '^引き継ぎの根拠: risk-carryover-check.sh 終了コード ')"
  for w in '終了コード <0・3・4 のどれか>' 'EVIDENCE_MAIN_ONLY' 'EVIDENCE_PR_CHANGED' 'EVIDENCE_DIFF_LINES' '判定 同じ' '判定の記録のリンク' '該当するものを並べて書く'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
}

@test "carryover judge (#1238): G as develop has a needs-carryover-judge section and a return heading for it" {
  nc="$(awk '/^### needs-carryover-judge のとき/{f=1;next} /^### |^```$/{f=0} f' "$HOLD")"
  [ -n "$nc" ] || { echo "no needs-carryover-judge section"; return 1; }
  for w in '前 HEAD' '新しい HEAD' '40 桁' '前の宣言のコメントのリンク' 'EVIDENCE_PR_CHANGED=' 'EVIDENCE_DIFF_LINES='; do
    echo "$nc" | grep -qF -- "$w" || { echo "missing: $w"; return 1; }
  done
  grep -E '^### return の書式' "$HOLD" | grep -qF 'needs-carryover-judge'
  line="$(grep -F -- '- **許容済みの PR で HEAD が動いたとき**' "$HOLD")"
  echo "$line" | grep -qF '終了コード 4' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '`needs-carryover-judge`'
}

@test "carryover judge (#1238): pass.md re-enters step 3 after the judgment and reads the record in 3-c" {
  line="$(grep -F '引き継ぎの判定のあと' "$PASS_STAGE")"
  [ -n "$line" ] || { echo "no after-judgment entry"; return 1; }
  echo "$line" | grep -qF '`段: 合格処理`'
  echo "$line" | grep -qF 'Status `needs-carryover-judge`'
  echo "$line" | grep -qF '`declarations.md` の手順 3 から入り直し'
  echo "$line" | grep -qF '判定の記録'
}

@test "carryover judge (#1238): declarations.md no longer says 3-c checks the evidence files are unchanged" {
  run grep -n '無変更' "$DECLARATIONS"
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  grep -F -- '`- 根拠ファイル:`' "$DECLARATIONS" | grep -F 'PR 自身の差分' | grep -qF '判定役'
}

@test "carryover (#1238): the evidence line records the PR's own commits and main-only evidence changes" {
  block="$(step3c_body | awk '/^```[a-z]+$/{b=1; next} b&&/^```$/{b=0; next} b{next} /^```$/{f=!f; next} f')"
  line="$(echo "$block" | grep '^引き継ぎの根拠: ')"
  for w in 'PR 自身の commit' 'EVIDENCE_MAIN_ONLY'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; return 1; }
  done
}

# ===== 周の終わりに残った指摘を直し方の判定に回す（issue #722）=====

@test "fix-check (#722): the end-of-round paragraph sends rows 2-4-only leftovers to the fix-check" {
  p="$(triage_section | grep -F '2 周目以降の周の終わり')"
  [ -n "$p" ] || { echo "no end-of-round paragraph"; return 1; }
  echo "$p" | grep -qF '順 6 を除いた全件が 1 周目なら順 2〜4'
  echo "$p" | grep -qF '`needs-fix-check`'
  echo "$p" | grep -qF '順 5'
}

@test "fix-check (#722): the triage table keeps exactly six rows" {
  n="$(triage_section | grep -cE '^\| [0-9]+ \|')"
  [ "$n" -eq 6 ] || { echo "rows: $n"; return 1; }
  ! triage_section | grep -E '^\| [0-9]+ \|' | grep -qF 'needs-fix-check' || return 1
}

@test "fix-check (#722): mixed with row 6, count rulings first; if used up, everything goes to one row-5 hold" {
  p="$(grep -F '直し方の判定に回す指摘と順 6 の指摘' "$TRIAGE")"
  [ -n "$p" ] || { echo "no mixed paragraph for fix-check and row 6"; return 1; }
  echo "$p" | grep -qF '^決める役の裁定:'
  echo "$p" | grep -qF '1 件以上なら'
  echo "$p" | grep -qF '1 回の保留にまとめる'
  echo "$p" | grep -qF '直し方の判定を先にする'
  echo "$p" | grep -qF '`needs-decider`'
}

@test "fix-check (#722): the fix-check is not counted as a row-6 ruling and leaves no ruling comment" {
  line="$(grep -F '直し方の判定は順 6 の回数に数えず' "$TRIAGE")"
  [ -n "$line" ] || { echo "no not-counted sentence"; return 1; }
  echo "$line" | grep -qF '`決める役の裁定:` のコメントも残さない'
}

@test "fix-check (#722): G as develop has a needs-fix-check section and a return heading for it" {
  nf="$(awk '/^### needs-fix-check のとき/{f=1;next} /^### |^```$/{f=0} f' "$TRIAGE")"
  [ -n "$nf" ] || { echo "no needs-fix-check section"; return 1; }
  echo "$nf" | grep -qF '仮の順'
  echo "$nf" | grep -qF '仕分けの PR コメント URL'
  echo "$nf" | grep -qF '順 6・未裁定'
  grep -E '^### return の書式' "$TRIAGE" | grep -qF 'needs-fix-check'
  # 判定を受け取った照合と振り分けの G の入力
  line="$(grep -F '直し方の判定の受領' "$TRIAGE")"
  [ -n "$line" ] || { echo "no fix-check receipt line"; return 1; }
  echo "$line" | grep -qF '仕分け欄'
  echo "$line" | grep -qF '仮の順'
  echo "$line" | grep -qF '`needs-decider`'
  echo "$line" | grep -qF '順 5'
}

@test "fix-check (#722): the re-review line opens round 3 only under the three conditions" {
  line="$(grep -F 'W の修正後の再レビュー' "$TRIAGE" | grep -F '3 周目に入るのは')"
  [ -n "$line" ]
  echo "$line" | grep -qF '直し方の判定・主の回答・決める役の裁定のどれか'
}

@test "fix-check (#722, #1222): triage.md points at the develop references/fix-check.md section and does not define the formats" {
  grep -qF 'レビューの周を主に聞かずに続ける（直し方の判定）' "$TRIAGE"
  # 節は #1222 で develop の SKILL.md から references/fix-check.md へ移した。参照する行はすべて移設先を名指しする
  run bash -c "grep -F 'レビューの周を主に聞かずに続ける（直し方の判定）' '$TRIAGE' | grep -vF 'references/fix-check.md'"
  [ "$status" -ne 0 ]
  run grep -qF '^直し方の判定:' "$TRIAGE"
  [ "$status" -ne 0 ]
  run grep -qF '^主に聞かずに回した周:' "$TRIAGE"
  [ "$status" -ne 0 ]
}

# --- Requirement: 合格条件は会話で受けた許容を正式な回答として受け付ける（#721） ---

step5_body() { awk '/^### 5\. /{f=1} /^### 6\. /{f=0} f' "${PASS_STAGE}"; }

@test "conversation reply (#721): step 5 has the conversation record format and the script check" {
  body="$(step5_body)"
  echo "$body" | grep -qF '主の回答: 許容 — 会話で受領（セッション <セッション ID> / <日時>）原文: <原文>'
  echo "$body" | grep -qF 'owner-reply-check.sh <セッション ID> <原文>'
  echo "$body" | grep -qF '真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh 終了コード 0）'
}

@test "conversation reply (#721): step 5 table treats a conversation record as accepted" {
  row="$(step5_body | grep '^| ' | grep -F '会話で受領')"
  echo "$row" | grep -qF '| 可 |'
}

@test "conversation reply (#721): step 5 reads intent from the full text with the same timestamp, not the excerpt" {
  body="$(step5_body)"
  echo "$body" | grep -F '同じ timestamp' | grep -qF '全文'
  echo "$body" | grep -F '終了コード 0 でも' | grep -qF '合格させない'
  echo "$body" | grep -qF '`許容しない`'
}

@test "conversation reply (#721): exit 2 routes to a PR comment or /develop on the same PC" {
  step5_body | grep -F 'exit 2' | grep -qF '/develop <記録先> 許容する'
}

@test "conversation reply (#721): hold.md does not ask the owner for a PR comment after a conversation reply" {
  grep -qF '会話で返事を受けたときは、主に PR へのコメントを求めない' "$HOLD"
}

@test "conversation reply (#721): step 6 resume row for risk acceptance handles a conversation record" {
  row="$(awk '/^### 6\. /{f=1} f' "${HOLD}" | grep -F '| **リスク許容待ち**' | head -1)"
  echo "$row" | grep -qF '会話で受領'
}

@test "conversation reply (#721): 3-c condition 3 accepts a conversation reply and rechecks with the script" {
  cond3="$(step3c_body | grep '^3\. ')"
  echo "$cond3" | grep -qF '会話で受領'
  echo "$cond3" | grep -qF 'owner-reply-check.sh'
  echo "$cond3" | grep -F '終了コード 0 でも' | grep -qF '同じ timestamp'
  echo "$cond3" | grep -qF '`許容しない`'
}

@test "conversation reply (#721): 3-c keeps the 4-line block and allows the conversation form on line 1" {
  step3c_body | grep -F '1 行目' | grep -qF '会話で受領（セッション'
}

@test "conversation reply (#721): step 5 binds the matched reply to this declaration (later than it, not about another PR)" {
  body="$(step5_body)"
  echo "$body" | grep -F '宣言コメントの作成日時' | grep -qF 'より後'
  echo "$body" | grep -F '別の PR' | grep -qF '合格させない'
}

@test "conversation reply (#721): 3-c condition 3 rechecks the binding against the first declaration" {
  cond3="$(step3c_body | grep '^3\. ')"
  echo "$cond3" | grep -F '最初の宣言' | grep -qF 'より後'
}

@test "conversation reply (#721): step 5 table does not fail a declaration only because the answer link is missing" {
  ! step5_body | grep '^| ' | grep -qF '回答リンクが無い' || return 1
  step5_body | grep '^| ' | grep -F '不可' | grep -qF 'いずれの許容済み条件も満たさない'
}

# --- Requirement: issue が目的として書いた効果は issue で承認済みとして主に聞き直さない（#723） ---

# 手順 3 の「issue で承認済み」の節（`#### issue で承認済み` から `#### 3-b.` の直前まで）
issue_approved_section() { awk '/^#### issue で承認済み/{f=1} /^#### 3-b\./{f=0} f' "$DECLARATIONS"; }

@test "issue approved (#723): declarations.md names the state and limits it to the 3 categories" {
  [ "$(grep -c 'issue で承認済み' "$DECLARATIONS")" -ge 1 ]
  sec="$(issue_approved_section)"
  [ -n "$sec" ] || { echo "section not found"; return 1; }
  # 手順 3 の本文（step3_body）の中に置かれている
  step3_body | grep -q '^#### issue で承認済み'
  echo "$sec" | grep -qF '資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張の 3 分類だけ'
}

@test "issue approved (#723): the 4 outward categories are asked even if the issue states them" {
  line="$(issue_approved_section | grep -F '外部公開面の変化・データ喪失・課金/法務・プロダクトのユーザーに及ぶ影響')"
  echo "$line" | grep -qF 'issue に書いてあっても主に聞く' || { echo "$line"; return 1; }
  issue_approved_section | grep -F '1 つでも' | grep -qF '宣言全体を手順6で主に聞く'
}

@test "issue approved (#723): the 3 conditions are listed" {
  sec="$(issue_approved_section)"
  c1="$(echo "$sec" | grep '^1\. ')"; c2="$(echo "$sec" | grep '^2\. ')"; c3="$(echo "$sec" | grep '^3\. ')"
  echo "$c1" | grep -qF '目的' && echo "$c1" | grep -qF '引用' || { echo "c1: $c1"; return 1; }
  for w in 'owner-reply-check.sh' '終了コード 0' '起票の承認' '`/develop <番号>`' 'lastEditedAt'; do
    echo "$c2" | grep -qF "$w" || { echo "c2 missing: $w"; return 1; }
  done
  echo "$c3" | grep -qF '実装中に発覚した影響ではない' && echo "$c3" | grep -qF '`issue 記載済み`' || { echo "c3: $c3"; return 1; }
}

@test "issue approved (#723): /develop evidence checks the number boundary in command-args" {
  line="$(issue_approved_section | grep -F '`<command-args>` の直後')"
  echo "$line" | grep -qF '`#<番号>`' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '`</command-args>`'
  echo "$line" | grep -qF 'MATCH:'
}

@test "issue approved (#723): the filing session is only a log whose first URL line is the create command's tool_result" {
  sec="$(issue_approved_section)"
  line="$(echo "$sec" | grep -F '初出行')"
  for w in '`gh issue create`' '`gh api -X POST repos/<R>/issues`' 'tool_result' '`gh issue view`' '`/develop` の引数'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; echo "$line"; return 1; }
  done
  # 探し先はスクリプトと同じ式で、subagents/ の下は見ない
  echo "$sec" | grep -F 'grep -l' | grep -F 'OWNER_REPLY_PROJECTS_DIR' | grep -qF 'subagents/'
  echo "$sec" | grep -F '候補が 0 件' | grep -qF '手順6で主に聞く'
}

@test "issue approved (#723): slash-command lines are not used as the filing approval" {
  issue_approved_section | grep -F '`<command-name>` を含む行' | grep -qF '使わない'
}

@test "issue approved (#723): an epic's filing approval covers children filed later in the same session only" {
  line="$(issue_approved_section | grep -F 'エピックの起票の承認')"
  echo "$line" | grep -qF '同じセッション' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '別のセッション'
  echo "$line" | grep -qF '証拠にならない'
}

# --- #802（PR #801 のゲート指摘 F1）: 起票承認の返事を、返事が答えた起票の提案と issue の目的・効果に結び付ける ---

# 「起票の承認」の箇条（`- **起票の承認**` から次の `当てない issue` の段落の直前まで）
filing_approval_block() { issue_approved_section | awk '/^- \*\*起票の承認\*\*/{f=1} /^当てない issue/{f=0} f'; }

@test "issue approved (#802): the last owner message is only a candidate; the answered proposal must contain the purpose and each quoted effect" {
  blk="$(filing_approval_block)"
  [ -n "$blk" ] || { echo "block not found"; return 1; }
  echo "$blk" | grep -F '主の発言のうち、最後のもの' | grep -qF '候補' || { echo "$blk"; return 1; }
  line="$(echo "$blk" | grep -F '返事が答えた起票の提案')"
  for w in '会話から特定' 'issue の目的' '引用した各効果' '特定できない' '証拠にせず手順6で主に聞く'; do
    echo "$line" | grep -qF "$w" || { echo "missing: $w"; echo "$line"; return 1; }
  done
}

@test "issue approved (#802): negative example - an OK to another proposal before the target issue was filed is not evidence" {
  line="$(filing_approval_block | grep -F '負例')"
  echo "$line" | grep -qF 'README の誤字修正' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '安全ゲートを撤去する issue'
  echo "$line" | grep -qF '起票の承認の証拠にならない'
}

@test "issue approved (#802): positive example - an OK to the target proposal is evidence" {
  line="$(filing_approval_block | grep -F '正例')"
  echo "$line" | grep -qF '安全ゲート X を撤去する issue を起票しますか' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '引用した効果を含む'
  echo "$line" | grep -qF '起票の承認の証拠になる'
  ! echo "$line" | grep -qF '証拠にならない' || return 1
}

@test "issue approved (#802): an epic's child counts only within the approved proposal" {
  line="$(issue_approved_section | grep -F 'エピックの起票の承認')"
  echo "$line" | grep -qF '承認された提案の範囲内' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '範囲外なら証拠にせず手順6'
}

@test "issue approved (#802): pass.md step 5 rechecks the answered proposal against the issue" {
  rc="$(step5_body | grep -F '確かめ直す' | grep -F 'issue で承認済み')"
  for w in '返事が答えた起票の提案' '引用した各効果' '承認された提案の範囲内'; do
    echo "$rc" | grep -qF "$w" || { echo "recheck missing: $w"; return 1; }
  done
}

@test "issue approved (#802): the main spec states the proposal check and fixes both examples as scenarios" {
  spec="${PLUGIN_ROOT}/openspec/specs/dev-workflow-pr-review-gate/spec.md"
  req="$(awk '/^### Requirement: issue が目的として書いた効果は/{f=1; print; next} /^### Requirement:/{f=0} f' "$spec")"
  echo "$req" | grep -F '返事が答えた起票の提案' | grep -F '引用した各効果' | grep -qF '手順 6' || { echo "proposal check missing"; return 1; }
  echo "$req" | grep -F 'エピックの起票を承認' | grep -qF '承認された提案の範囲内'
  echo "$req" | grep -qF '#### Scenario: 別の提案への承認のあとに起票された issue には当てない'
  echo "$req" | grep -qF '#### Scenario: 対象の提案への承認は起票の承認の証拠になる'
  pass_req="$(awk '/^### Requirement: 合格条件は issue で承認済みの宣言を受け付け/{f=1; print; next} /^### Requirement:/{f=0} f' "$spec")"
  echo "$pass_req" | grep -qF '返事が答えた起票の提案' || { echo "pass requirement missing"; return 1; }
}

@test "issue approved (#723): exclusions name agent-proposed, unapproved agent issues, EPIC_DISPATCH_PARENT_EPIC and --unmanned" {
  sec="$(issue_approved_section)"
  echo "$sec" | grep -F '`agent-proposed`' | grep -qF '主の承認の記録が無い'
  echo "$sec" | grep -qF '`EPIC_DISPATCH_PARENT_EPIC`'
  echo "$sec" | grep -qF '`--unmanned`'
  echo "$sec" | grep -F '保留や却下' | grep -qF '数えない'
}

@test "issue approved (#723): unmanned runs and paths without a post-report destination do not apply it (declarations and pass)" {
  for f in "$DECLARATIONS" "$PASS_STAGE"; do
    line="$(grep -F '無人運用（loop-dev-agent' "$f" | grep -F 'issue で承認済み')"
    echo "$line" | grep -qF '主に事後報告を届ける先が無い経路' || { echo "$f: $line"; return 1; }
    echo "$line" | grep -qF '当てない' || { echo "$f: $line"; return 1; }
  done
}

@test "issue approved (#723): the 3 appended lines block exists and does not start with the owner-answer prefix" {
  block="$(issue_approved_section | awk '/^```$/{f=!f; next} f')"
  echo "$block" | grep -q '^issue で承認済み — issue #<N> の目的: 「<本文からの引用>」$'
  echo "$block" | grep -q '^承認の証拠: <起票の承認 | /develop の打ち込み>（セッション <セッション ID> / <日時>）原文: <原文>$'
  echo "$block" | grep -q '^真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh 終了コード 0）$'
  [ "$(echo "$block" | wc -l | tr -d ' ')" -eq 3 ] || { echo "$block"; return 1; }
  ! echo "$block" | grep -q '^主の回答: 許容' || return 1
  issue_approved_section | grep -F '宣言の本文' | grep -qF '書き換えない'
}

@test "issue approved (#723): step 3 table routes an issue-approved declaration to step 4 and keeps step 6" {
  row="$(step3_body | grep '^| \*\*主のリスク許容が必要\*\*')"
  echo "$row" | grep -qF 'issue で承認済みなら手順 4 へ' || { echo "$row"; return 1; }
  echo "$row" | grep -qF '手順6へ'
}

@test "issue approved (#723): the exit of declarations.md tries 3-c, then issue approved, then step 6" {
  line="$(awk '/^## 出口/{f=1; next} /^## /{f=0} f' "$DECLARATIONS" | grep -F 'issue で承認済み')"
  [ -n "$line" ] || { echo "no exit line"; return 1; }
  echo "$line" | awk '{a=index($0,"3-c"); b=index($0,"issue で承認済み"); c=index($0,"手順 6"); exit !(a>0 && b>a && c>b)}' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '先に当たったほうだけ'
}

@test "issue approved (#723): step 5 table accepts it and the recheck line format is fixed" {
  row="$(step5_body | grep '^| ' | grep -F 'issue で承認済み')"
  echo "$row" | grep -qF '| 可 |' || { echo "$row"; return 1; }
  body="$(step5_body)"
  echo "$body" | grep -qF '確かめ直し: 済 — 確認者 <エージェント名> / <日時>（手順 5）'
  echo "$body" | grep -F '`真正性確認: 済` の行は足さない' | grep -qF '前の宣言の選び方'
  rc="$(echo "$body" | grep -F '確かめ直す' | grep -F 'issue で承認済み')"
  for w in 'owner-reply-check.sh' '`agent-proposed`' '`lastEditedAt`' '`EPIC_DISPATCH_PARENT_EPIC`' '`--unmanned`' '事後報告を届ける先' '手順6'; do
    echo "$rc" | grep -qF "$w" || { echo "recheck missing: $w"; return 1; }
  done
}

@test "issue approved (#723): pass.md has the post-report and the passed return line" {
  line="$(step5_body | grep -F '事後報告' | grep -F '1 回')"
  echo "$line" | grep -qF '宣言コメントの URL' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '引用'
  ret="$(awk '/^### return の書式（passed）/{f=1; next} /^### この段で/{f=0} f' "$PASS_STAGE")"
  echo "$ret" | grep -q '^- issue で承認済み: '
}

@test "issue approved (#723): hold.md does not carry over an issue-approved declaration and states unmet conditions" {
  grep -F 'issue で承認済み' "$HOLD" | grep -qF '引き継ぎの元にしない'
  awk '/^## 入口/{f=1; next} /^## /{f=0} f' "$HOLD" | grep -qF 'issue で承認済み'
  awk '/^### 6\. /{f=1} f' "$HOLD" | grep '^3\. ' | grep -qF '満たさなかった条件'
}

@test "issue approved (#723): develop (4) passed line relays the issue-approved line to the owner before CI watch" {
  line="$(grep -F '`issue で承認済み:`' "$DEVELOP_SKILL")"
  echo "$line" | grep -qF 'CI の見張り' || { echo "$line"; return 1; }
  echo "$line" | grep -qF '1 回'
  echo "$line" | grep -qF 'stages/pass.md'
}

# --- Requirement: 合格条件はエピックの親経由で受けた許容を、親の会話ログで確かめて受け付ける（#1059） ---
# 照合の対象は手順書（pass.md・hold.md）の文だけで、openspec の spec の文言は照合しない。

@test "relayed reply (#1059): step 5 has the relayed record format" {
  step5_body | grep -qF '主の回答: 許容 — 親経由で受領（親セッション <セッション ID> / 発言 <uuid> / <日時>）停止の記録: <URL> 原文: <原文>'
}

@test "relayed reply (#1059): step 5 table treats a relayed record as accepted" {
  row="$(step5_body | grep '^| ' | grep -F '親経由で受領')"
  echo "$row" | grep -qF '| 可 |'
}

@test "relayed reply (#1059): step 5 checks the stop record comment (first line, author association, record target)" {
  body="$(step5_body | awk '/親経由で受けた許容（親経由で受領）の真正性確認/{f=1} f')"
  echo "$body" | grep -qF '子の停止: 主の返事待ち'
  echo "$body" | grep -qF 'author_association'
  echo "$body" | grep -qF 'COLLABORATOR'
  echo "$body" | grep -qF '記録先'
}

@test "relayed reply (#1059): step 5 runs owner-reply-check.sh --relayed and records its exit 0" {
  body="$(step5_body)"
  echo "$body" | grep -qF 'owner-reply-check.sh --relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>'
  echo "$body" | grep -qF '真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --relayed 終了コード 0）'
  for r in not-found not-owner not-after not-asked not-direct; do
    echo "$body" | grep -qF "$r" || return 1
  done
}

@test "relayed reply (#1059): step 5 reads the full text, passes unnamed and jointly named answers, and rejects other-child-only answers" {
  body="$(step5_body | awk '/親経由で受けた許容（親経由で受領）の真正性確認/{f=1} f')"
  echo "$body" | grep -F 'この子・この PR への許容' | grep -F '名指しが無い許容' | grep -qF '通す'
  echo "$body" | grep -qF '別の PR・別の記録先・別の子・別のリスクだけを名指しした答えでない'
  echo "$body" | grep -F '宣言コメントの作成日時' | grep -qF 'より後'
  echo "$body" | grep -qF '子のタブ'
}

@test "relayed reply (#1059): the scope sentence says only the fixed heads are not counted" {
  scope="$(step5_body | grep '^守備範囲: 会話ログの改変')"
  echo "$scope" | grep -qF '決まった頭'
  echo "$scope" | grep -qF '主の返事（親エピック #'
  echo "$scope" | grep -qF '頭の無い'
}

@test "relayed reply (#1059): step 6 resume row for risk acceptance handles a relayed record" {
  row="$(awk '/^### 6\. /{f=1} f' "${HOLD}" | grep -F '| **リスク許容待ち**' | head -1)"
  echo "$row" | grep -qF '親経由で受領'
}

@test "relayed reply (#1059): 3-c condition 3 accepts a relayed record and rechecks with --relayed" {
  cond3="$(step3c_body | grep '^3\. ')"
  echo "$cond3" | grep -qF '親経由で受領'
  echo "$cond3" | grep -qF 'owner-reply-check.sh --relayed'
  echo "$cond3" | grep -qF '真正性確認」の 1〜3'
}

@test "relayed reply (#1059): 3-c allows the relayed form on line 1" {
  step3c_body | grep -F '1 行目' | grep -qF '親経由で受領（親セッション'
}

@test "relayed reply (#1059): step 5 reads html_url of the stop record and checks it is the latest stop record" {
  body="$(step5_body | awk '/親経由で受けた許容（親経由で受領）の真正性確認/{f=1} f')"
  echo "$body" | grep -qF "{body, author_association, issue_url, html_url, created_at}"
  echo "$body" | grep -F '1 で取った' | grep -qF 'html_url'
  echo "$body" | grep -qF 'last | .html_url'
  echo "$body" | grep -F '最新の停止の記録' | grep -qF '一致'
}

@test "relayed reply (#1059): the relayed check has its own scope sentence" {
  scope="$(step5_body | grep '^守備範囲: 親の会話ログの改変')"
  echo "$scope" | grep -qF '頭を付けずに打ち込まれた文'
  echo "$scope" | grep -qF '塞ぎ切る'
}

# --- Requirement: 合格条件は主の委任で親経由に受けた許容を、委任の確認と記録で確かめて受け付ける（#1293） ---
# 4 条件・6 条件・推奨の判定の文字列は develop-skill.bats の DELEG_STOP4・DELEG_VALID6・DELEG_RECOMMEND と同じ文字列にする
# （epic.md・epic-child-stop.md・pass.md の 3 か所が同じ文で確かめるため）。

PRG_DELEG_VALID6='委任の記録が、①エピック #<E> の issue のコメントで、1〜4 行目が定型の文ちょうど、2 行目の番号が <E> ②投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれか ③エピックの、投稿者が同じ 3 種の `主の委任:` で始まるコメントのうち最新 ④`lastEditedAt` が null ⑤エピックが開いている ⑥子 issue がエピックの子（sub-issue か本文の子の表にある）'
PRG_DELEG_STOP4='①子 issue の番号を、本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` に持つ開いた PR に `needs-approval` が付いている ②その PR の、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` で `## リスク宣言` で始まる最新のコメントが `主のリスク許容が必要。` の行を持ち、`対象 HEAD:` が PR の今の HEAD と同じで、`主の回答:` で始まる行をまだ持たない（G では、今確かめている委任の形の記録の行だけは除く） ③停止の記録の作成日時が、そのコメントの作成日時と委任の確認の timestamp の両方より後 ④停止の記録の `推奨:` の値（先頭の空白を除く）が `許容する` で始まる'
PRG_DELEG_RECOMMEND='`推奨:` の値（先頭の空白を除く）が `許容する` で始まる'

deleg_check_body() { step5_body | awk '/主の委任で親経由に受けた許容（親経由で受領（委任））の真正性確認/{f=1} /^\*\*issue で承認済みの確かめ直し/{f=0} f'; }

@test "delegated reply (#1293): step 5 has the delegated record format" {
  step5_body | grep -qF '主の回答: 許容 — 親経由で受領（委任）（親セッション <セッション ID> / 委任の確認 <uuid> / <日時>）委任の記録: <URL> 停止の記録: <URL> 原文: <原文>'
}

@test "delegated reply (#1293): step 5 table has a delegated row that is accepted" {
  row="$(step5_body | grep '^| ' | grep -F '親経由で受領（委任）')"
  [ -n "$row" ]
  echo "$row" | grep -qF '| 可 |'
}

@test "delegated reply (#1293): the delegated check section sits after the relayed check and before the issue approval recheck" {
  body="$(deleg_check_body)"
  [ -n "$body" ]
  relayed_line="$(step5_body | grep -nF '親経由で受けた許容（親経由で受領）の真正性確認' | head -1 | cut -d: -f1)"
  deleg_line="$(step5_body | grep -nF '主の委任で親経由に受けた許容（親経由で受領（委任））の真正性確認' | head -1 | cut -d: -f1)"
  [ "$relayed_line" -lt "$deleg_line" ]
}

@test "delegated reply (#1293): pass.md has the six validity conditions, four stop conditions and recommendation judgement as the same strings" {
  body="$(deleg_check_body)"
  echo "$body" | grep -qF "$PRG_DELEG_VALID6"
  echo "$body" | grep -qF "$PRG_DELEG_STOP4"
  echo "$body" | grep -qF "$PRG_DELEG_RECOMMEND"
}

@test "delegated reply (#1293): the strings in pass.md are the same as epic.md and epic-child-stop.md" {
  epic="$BATS_TEST_DIRNAME/../skills/develop/references/epic.md"
  child="$BATS_TEST_DIRNAME/../skills/develop/references/epic-child-stop.md"
  for f in "$epic" "$child"; do
    grep -qF "$PRG_DELEG_VALID6" "$f" || { echo "valid6 missing in $f"; return 1; }
    grep -qF "$PRG_DELEG_STOP4" "$f" || { echo "stop4 missing in $f"; return 1; }
  done
}

@test "delegated reply (#1293): step 5 checks the stop record is the latest one and runs --delegated" {
  body="$(deleg_check_body)"
  echo "$body" | grep -qF '子の停止: 主の返事待ち'
  echo "$body" | grep -qF 'last | .html_url'
  echo "$body" | grep -qF 'owner-reply-check.sh --delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>'
  for r in not-found not-owner not-after not-asked not-direct not-before; do
    echo "$body" | grep -qF "$r" || { echo "missing $r"; return 1; }
  done
  echo "$body" | grep -F '任せる意思' | grep -qF 'MATCH:'
}

@test "delegated reply (#1293): step 5 records the --delegated exit 0 and never uses --relayed for the delegated form" {
  body="$(deleg_check_body)"
  echo "$body" | grep -qF '真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --delegated 終了コード 0）'
  echo "$body" | grep -F -- '--relayed' | grep -F 'で確かめない' | grep -qF 'not-after'
  ! echo "$body" | grep -qF -- 'owner-reply-check.sh --relayed <' || return 1
}

@test "delegated reply (#1293): step 5 sends back to step 6 and the child's tab when any check fails" {
  body="$(deleg_check_body)"
  echo "$body" | grep -F '合格させず' | grep -F '手順6' | grep -qF '子のタブ'
}

@test "delegated reply (#1293): the delegated check has its own scope paragraph" {
  scope="$(deleg_check_body | grep '^守備範囲（委任の形）: ')"
  [ -n "$scope" ]
  echo "$scope" | grep -qF '起動し直した'
  echo "$scope" | grep -qF '塞ぎ切る'
}

@test "delegated reply (#1293): step 6 resume row for risk acceptance handles a delegated record" {
  row="$(awk '/^### 6\. /{f=1} f' "${HOLD}" | grep -F '| **リスク許容待ち**' | head -1)"
  echo "$row" | grep -qF '主の回答: 許容 — 親経由で受領（委任）（親セッション <セッション ID> / 委任の確認 <uuid> / <日時>）委任の記録: <URL> 停止の記録: <URL> 原文: <原文>'
  echo "$row" | grep -F '親経由で受領（委任）' | grep -qF '追記してから手順5'
}

@test "delegated reply (#1293): 3-c condition 3 rechecks the delegated form with --delegated, not --relayed" {
  cond3="$(step3c_body | grep '^3\. ')"
  echo "$cond3" | grep -qF '親経由で受領（委任）'
  echo "$cond3" | grep -qF 'owner-reply-check.sh --delegated'
  echo "$cond3" | grep -qF -- '`--relayed` で確かめ直さない'
  echo "$cond3" | grep -qF '取り消し'
  echo "$cond3" | grep -qF '`親経由で受領（委任）（親セッション ` で始まる行は委任の形、`親経由で受領（親セッション ` で始まる行は従来の形'
}

@test "delegated reply (#1293): 3-c allows four forms on line 1 and keeps four lines" {
  body="$(step3c_body)"
  echo "$body" | grep -F '1 行目' | grep -qF '親経由で受領（委任）（親セッション'
  echo "$body" | grep -qF '主の回答: 許容（引き継ぎ） — 親経由で受領（委任）（親セッション … / 委任の確認 … / …）委任の記録: … 停止の記録: … 原文: …'
  echo "$body" | grep -qF '4 つ'
}

@test "condition question delivery (#1013): the same sentence is in gate-runner.md, triage.md and the spec; develop SKILL.md points to it" {
  s='照合と振り分けの G の return の仕分け欄に `条件の確認待ち` の質問文があれば、G を起こした側（develop では本体）は、その質問文と `条件の確認待ち` の PR コメントの URL を主への次の報告にそのまま載せる（無人運用（loop-dev-agent）では記録先にコメントする）。'
  grep -qF -- "$s" "${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md"
  grep -qF -- "$s" "$TRIAGE"
  # archive 前は change の delta spec、archive 後は main spec を読む
  spec="${PLUGIN_ROOT}/openspec/changes/condition-question-delivery/specs/dev-workflow-pr-review-gate/spec.md"
  [ -f "$spec" ] || spec="${PLUGIN_ROOT}/openspec/specs/dev-workflow-pr-review-gate/spec.md"
  grep -qF -- "$s" "$spec"
  grep -qF '自分でゲートを回すセッションは、G を起こした側を兼ねる。' "$TRIAGE"
  grep -qF '自分でゲートを回すセッションは、G を起こした側を兼ねる。' "$spec"
  grep -F '次の段へ → `次の段:`' "$DEVELOP_SKILL" | grep -qF '`条件の確認待ち` の質問文があれば主へ届ける（gate-runner.md）'
}
