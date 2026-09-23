#!/usr/bin/env bats
#
# develop スキルの役割別指示書（W / R1 / G）の構造検証（issue #203）
#
#   references/roles/worker.md        W: 仕様化判断の記録・Draft PR 記録先の作成順序・事前分類表・TDD
#   references/roles/spec-reviewer.md R1: 6 観点（守備範囲を含む）・読み取り専用・2 周キャップ・結果書式・判断記録の契約
#   references/roles/gate-runner.md   G: pr-review-gate 手順 1〜5・Codex の呼び方・needs-reviewer・failed の原因分類
#
# spec: dev-workflow-develop, dev-workflow-spec-review

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  ROLES="${PLUGIN_DIR}/skills/develop/references/roles"
  WORKER="${ROLES}/worker.md"
  REVIEWER="${ROLES}/spec-reviewer.md"
  GATE="${ROLES}/gate-runner.md"
}

section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }

@test "roles: all three role files exist" {
  [ -f "$WORKER" ]
  [ -f "$REVIEWER" ]
  [ -f "$GATE" ]
}

# ===== worker.md =====

@test "worker: does not re-run /opsx:ff when the change already has its artifacts" {
  grep -qF '`/opsx:ff` を再実行しない' "$WORKER"
  grep -qF 'そのまま' "$WORKER"
}


@test "worker: records the spec decision with the exact first-line regex via gh, and does not proceed before" {
  grep -qF '^仕様化判断: (する|しない)$' "$WORKER"
  grep -qE 'gh (issue|pr) comment' "$WORKER"
  grep -qE '記録(する|して)(前|まで)|記録せずに.*進(ま|んでは)' "$WORKER"
}

@test "worker: also carries the spec review result format for the record target" {
  grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$' "$WORKER"
}

@test "worker: Draft PR record target is created (empty commit -> push -> draft) before the spec decision" {
  grep -q 'git commit --allow-empty' "$WORKER"
  grep -q 'git push' "$WORKER"
  grep -q 'gh pr create --draft' "$WORKER"
  draft="$(grep -n 'gh pr create --draft' "$WORKER" | head -1 | cut -d: -f1)"
  decision="$(grep -nF '^仕様化判断: (する|しない)$' "$WORKER" | head -1 | cut -d: -f1)"
  [ "$draft" -lt "$decision" ]
}

@test "worker: PR body carries acceptance criteria and no Closes/Fixes/Refs when the PR is the record target" {
  grep -qE '受け入れ条件.*PR 本文|PR 本文.*受け入れ条件' "$WORKER"
  grep -qE '(Closes|Fixes|Refs).*(書かない|書いてはならない)' "$WORKER"
}

@test "worker: never creates a worktree itself (main prepares it)" {
  grep -qE 'worktree.*(切らない|作らない)' "$WORKER"
  ! grep -q 'git worktree add' "$WORKER"
}

@test "worker: pre-classification table names all 4 categories and is the single source" {
  grep -qF '重要実装の事前分類' "$WORKER"
  grep -qF '聖域パス' "$WORKER"
  grep -qF 'マージ権限' "$WORKER"
  grep -qF '層間契約' "$WORKER"
  grep -qF '課金/法務' "$WORKER"
  grep -q '正本' "$WORKER"
}

@test "worker: fable from the first round, AGENT_MODEL unchanged, budget modes cap escalation" {
  grep -qF '`model: fable`' "$WORKER"
  grep -q '最初から' "$WORKER"
  grep -qF 'AGENT_MODEL' "$WORKER"
  grep -qF 'FABLE_BUDGET_MODE=reserve' "$WORKER"
  grep -qF 'exhausted' "$WORKER"
}

@test "worker: fallback record format points back to pr-review-gate" {
  grep -qF 'pr-review-gate' "$WORKER"
}

@test "worker: openspec CLI degraded path returns to main for the same spec review" {
  grep -A3 'openspec CLI だけある場合' "$WORKER" | grep -q '仕様レビュー'
  grep -A3 'openspec CLI だけある場合' "$WORKER" | grep -q 'return'
}

@test "worker: spec path returns after /opsx:ff and does not apply before R1 APPROVE" {
  grep -q '/opsx:ff' "$WORKER"
  grep -q '/opsx:apply' "$WORKER"
  grep -qE 'APPROVE.*(まで|前).*(apply|実装).*(進まない|進んではならない|入らない)|(apply|実装).*APPROVE.*(まで|前)' "$WORKER"
}

@test "worker: TDD with evidence-backed completion, no execution-strategy branches" {
  grep -q 'Red' "$WORKER"
  grep -q 'Green' "$WORKER"
  grep -q 'exit code' "$WORKER"
  ! grep -q 'delegate+verify' "$WORKER"
  ! grep -q 'workflow 型' "$WORKER"
  ! grep -q 'solo' "$WORKER"
}

# (3) は (3a) 実装＋verify と (3b) archive＋PR＋仕様宣言 の 2 回の return に分かれる（#262）。
@test "worker: (3a) and (3b) are separate sections that each list their return contents" {
  a="$(section "$WORKER" '(3a) 実装＋verify')"
  b="$(section "$WORKER" '(3b) archive＋PR＋仕様宣言')"
  [ -n "$a" ] || { echo "no (3a) section in worker.md"; return 1; }
  [ -n "$b" ] || { echo "no (3b) section in worker.md"; return 1; }
  # (3a): 実装と verify まで。archive には進まない
  echo "$a" | grep -qF '工程完了: 実装＋verify'
  echo "$a" | grep -q 'テストコマンド'
  echo "$a" | grep -q 'exit code'
  echo "$a" | grep -qF '/opsx:apply'
  echo "$a" | grep -qF '/opsx:verify'
  # 否定は `!` で書かない。bats（set -e）は `!` 付きコマンドの失敗を最終行以外で無視するため、
  # `! ... | grep -q ...` は退行を検出できない（bats 1.13 で実測）。
  if echo "$a" | grep -qF '/opsx:archive'; then
    echo "(3a) の節に /opsx:archive が書かれている（archive は (3b)）" >&2
    return 1
  fi
  # (3b): archive 以降。PR 番号と仕様宣言のコメント URL を return に載せる
  echo "$b" | grep -qF '工程完了: archive＋PR＋仕様宣言'
  echo "$b" | grep -qF '/opsx:archive'
  echo "$b" | grep -q 'PR #'
  echo "$b" | grep -q '仕様宣言のコメント URL'
}

# ゲート合格まで PR を Draft のまま進める（#304）。W は Ready にせず、G が pr-review-gate 手順 5 で行う。
@test "worker: (3b) keeps the PR as Draft (gh pr create --draft) and leaves Ready to G" {
  b="$(section "$WORKER" '(3b) archive＋PR＋仕様宣言')"
  [ -n "$b" ] || { echo "no (3b) section in worker.md"; return 1; }
  echo "$b" | grep -q 'Draft のまま'
  echo "$b" | grep -qF 'gh pr create --draft'
  echo "$b" | grep -F 'Ready 化' | grep -qF '手順 5'
  if echo "$b" | grep -qE 'gh pr ready|Ready for Review.*切り替え'; then
    echo "(3b) の節に W が Ready に切り替える記述がある（Ready 化は G の手順 5）" >&2
    return 1
  fi
}

# opsx スラッシュコマンドが無く openspec CLI だけある経路も、(3a)/(3b) の区切りは同じでなければ
# ならない（#262 のゲート指摘。この段落だけ旧来の「実装 → archive」一括のまま残っていた）。
@test "worker: the openspec-CLI-only path stops at verify in (3a) and archives in (3b)" {
  s="$(section "$WORKER" '仕様化する場合（(1) の終わり）')"
  [ -n "$s" ] || { echo "no spec-writing section in worker.md"; return 1; }
  # フォールバック経路の箇条書き 1 個ぶんを切り出す（次の行頭 "- " まで）
  fb="$(echo "$s" | awk '/openspec CLI だけある場合/{f=1; print; next} f && /^- /{f=0} f {print}')"
  [ -n "$fb" ] || { echo "no openspec-CLI-only fallback paragraph in worker.md"; return 1; }
  flat="$(echo "$fb" | tr '\n' ' ')"
  # /opsx:verify の代わりの検証手順が名指しされている
  echo "$flat" | grep -qF 'openspec validate'
  echo "$flat" | grep -qF -- '--strict'
  # (3a) は検証まで、archive は (3b)
  echo "$flat" | grep -qE '\(3a\)[^。]*openspec validate'
  echo "$flat" | grep -qE 'openspec archive[^。]*\(3b\)'
}

@test "worker: the context cap section names the three stages and forbids finer splits" {
  s="$(section "$WORKER" 'コンテキスト上限と手渡し')"
  [ -n "$s" ] || { echo "no context cap section in worker.md"; return 1; }
  echo "$s" | grep -qF '(1) 仕様化まで'
  echo "$s" | grep -qF '(3a) 実装＋verify'
  echo "$s" | grep -qF '(3b) archive＋PR＋仕様宣言'
  echo "$s" | grep -qF 'これより細かく'
  echo "$s" | grep -q '固定分'
}

@test "worker: split judgement is based on the issue text, and unmanned splits into child issues with blocked_by" {
  grep -q 'dependencies/blocked_by' "$WORKER"
  grep -q 'references/decision-criteria.md' "$WORKER"
}

# ===== spec-reviewer.md =====

@test "reviewer: six review criteria are listed with spec path + requirement name on conflict" {
  grep -q '一意' "$REVIEWER"
  grep -qE '既存.*openspec/specs' "$REVIEWER"
  grep -qE 'config|引数' "$REVIEWER"
  grep -q '前提' "$REVIEWER"
  grep -qE 'proposal.*specs.*design.*tasks' "$REVIEWER"
  grep -qE 'spec.*パス.*要件名|要件名.*パス' "$REVIEWER"
}

@test "reviewer (#287): coverage criterion is in the review criteria section, limited to input-checking requirements, missing one is REQUEST_CHANGES" {
  s="$(section "$REVIEWER" 'レビュー観点')"
  [ -n "$s" ] || { echo "no review criteria section in spec-reviewer.md"; return 1; }
  echo "$s" | grep -qF '## レビュー観点（6 つ'
  echo "$s" | grep -q '守備範囲'
  echo "$s" | grep -qF '入力を検査・判定する要件'
  echo "$s" | grep -qE '守備範囲.*REQUEST_CHANGES|REQUEST_CHANGES.*守備範囲'
}

@test "reviewer (#287): coverage criterion is not applied retroactively to existing specs" {
  section "$REVIEWER" 'レビュー観点' | grep -qF '遡及しない'
}

@test "reviewer: read-only and grep-first" {
  grep -qE '読み取り専用|変更しない' "$REVIEWER"
  grep -q 'grep' "$REVIEWER"
}

@test "reviewer: two-round cap, no third round, needs-approval / AskUserQuestion / unmanned cycle end" {
  grep -qE '2 ?周' "$REVIEWER"
  grep -qE '3 ?周目.*(例外|設けない)' "$REVIEWER"
  grep -q 'needs-approval' "$REVIEWER"
  grep -q 'AskUserQuestion' "$REVIEWER"
  grep -qE 'unmanned.*(サイクル|終了)' "$REVIEWER"
}

@test "reviewer: result comment format and posting steps" {
  grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$' "$REVIEWER"
  grep -qE 'gh (issue|pr) comment' "$REVIEWER"
  grep -qE '周回|周目' "$REVIEWER"
}

@test "reviewer: decision-record contract (latest one wins, Closes/Fixes/Refs, PR comments fallback)" {
  section "$REVIEWER" '判断記録の契約' | grep -q '最新'
  section "$REVIEWER" '判断記録の契約' | grep -qE 'Closes.*Fixes.*Refs|Refs.*Closes'
  section "$REVIEWER" '判断記録の契約' | grep -q 'PR 自身のコメント'
  section "$REVIEWER" '判断記録の契約' | grep -qF '^仕様化判断: (する|しない)$'
}

@test "reviewer: spawned with explicit model, default opus, fable via worker.md pre-classification" {
  grep -q 'model' "$REVIEWER"
  grep -q '`opus`' "$REVIEWER"
  grep -qE '事前分類.*fable|fable.*事前分類' "$REVIEWER"
  grep -q 'worker.md' "$REVIEWER"
}

@test "reviewer: reserve only for automatic runs, exhausted for all paths" {
  grep -qE 'reserve.*自動実行' "$REVIEWER"
  grep -qE 'exhausted.*(全経路|すべて)' "$REVIEWER"
}

@test "reviewer: return format has Spec Review Result with BLOCKER / SHOULD_FIX / NOTE" {
  grep -q 'Spec Review Result' "$REVIEWER"
  grep -q 'BLOCKER' "$REVIEWER"
  grep -q 'SHOULD_FIX' "$REVIEWER"
}

# ===== gate-runner.md =====

@test "gate-runner: reads pr-review-gate and runs steps 1-5" {
  grep -q 'pr-review-gate' "$GATE"
  grep -qE '手順 ?1 ?〜 ?5|1〜5' "$GATE"
}

@test "gate-runner: Codex is invoked from Bash (codex exec with flags or codex-companion.mjs), not via slash/subagent" {
  grep -qF 'codex exec -c approval_policy=never -c model_reasoning_effort=medium' "$GATE"
  grep -qF 'codex-companion.mjs' "$GATE"
  grep -q '/codex:adversarial-review' "$GATE"
  grep -q 'codex:codex-rescue' "$GATE"
  grep -qE '(使えない|使わない|呼べない)' "$GATE"
}

@test "gate-runner: needs-reviewer return payload (light/full + reason, PR + HEAD SHA, model + reason, acceptance criteria location)" {
  n="$(section "$GATE" 'needs-reviewer')"
  echo "$n" | grep -q 'light'
  echo "$n" | grep -q 'full'
  echo "$n" | grep -q '根拠'
  echo "$n" | grep -q 'HEAD SHA'
  echo "$n" | grep -q 'PR 番号'
  echo "$n" | grep -q '推奨モデル'
  echo "$n" | grep -q '受け入れ条件の所在'
}

@test "gate-runner: spawned by name, resumed with the reviewer summary via SendMessage, and G posts the reviewer line" {
  grep -q '名前付き' "$GATE"
  grep -q 'SendMessage' "$GATE"
  grep -qF 'レビュー実行者:' "$GATE"
  grep -qE 'レビュー実行者:.*G が|G が.*レビュー実行者:' "$GATE"
}

@test "gate-runner: failed return carries the step 2-2 cause classification" {
  grep -q '実装品質起因' "$GATE"
  grep -q '仕様が曖昧' "$GATE"
  grep -q '誤検出' "$GATE"
}

@test "gate-runner: step 5 summary includes Ready (only when Draft) and the passed return has a Ready result field" {
  todo="$(section "$GATE" 'やること')"
  [ -n "$todo" ] || { echo "no やること section in gate-runner.md"; return 1; }
  echo "$todo" | grep -F 'agent-review:passed' | grep -qF 'Draft なら Ready'
  grep -qF 'Ready 化: 実施した | 対象外（元から非 Draft）' "$GATE"
}

@test "gate-runner (#281): round-2 return sorts findings by quote or follow-up issue URL" {
  grep -q '仕分け' "$GATE"
  grep -q '引用' "$GATE"
  grep -q 'follow-up issue' "$GATE"
}

@test "gate-runner (#354): row-5 findings return as on-hold for split-off confirmation, not proposing a third round" {
  grep -q '切り出しの確認' "$GATE"
  grep -q '3周目を提案しない' "$GATE"
  run grep -F '2周目キャップ' "$GATE"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#281): round field covers round 3+ after owner go-ahead and full review line counts" {
  grep -qE '周回: .*3以降（主の回答または決める役の裁定あり）' "$GATE"
  grep -q '全体レビュー' "$GATE"
}

@test "gate-runner (#281): no high-severity-only third round permission remains" {
  run grep -F '新規の高深刻度 blocking のみ' "$GATE"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#354): resume covers the owner's answer to the split-off confirmation" {
  line="$(grep -E '保留の解除' "$GATE")"
  echo "$line" | grep -qF '切り出しの確認'
  echo "$line" | grep -qF '切り出す'
  echo "$line" | grep -qF 'この PR で直す'
}

@test "gate-runner (#281): the round-2 sorting field sits above the Status-specific sections" {
  common="$(awk '/^## Gate Result/{f=1} f&&/^### /{exit} f' "$GATE")"
  [ -n "$common" ] || { echo "no Gate Result block in gate-runner.md"; return 1; }
  echo "$common" | grep -q '仕分け'
  echo "$common" | grep -q 'follow-up issue'
  run sh -c "awk '/^### failed のとき/{f=1;next} /^### /{f=0} f' '$GATE' | grep -F '2周目の終わりにやること'"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#354): resuming with the reviewer's summary branches by triage row, not by round" {
  line="$(grep -F 'レビュアーの要約受領' "$GATE" | grep -v '「レビュアーの要約受領」')"
  [ -n "$line" ] || { echo "no reviewer-summary resume line"; return 1; }
  echo "$line" | grep -qF '周の数に関係なく'
  echo "$line" | grep -qF '仕分け表'
  echo "$line" | grep -qF '順 2〜4 は `agent-review:failed`'
  echo "$line" | grep -qF '順 5 は保留'
  echo "$line" | grep -qF '順 6 は `needs-decider`'
  run sh -c "grep -F 'レビュアーの要約受領' '$GATE' | grep -E '1周目は|2周目と'"
  [ "$status" -ne 0 ]
}

@test "gate-runner: return formats cover passed / failed / on-hold" {
  grep -q 'passed' "$GATE"
  grep -q 'failed' "$GATE"
  grep -q '保留' "$GATE"
}

@test "gate-runner: G itself defaults to sonnet; the reviewer is opus or the decider type for merge conditions / cross-layer contracts" {
  grep -q 'G の既定は `sonnet`' "$GATE"
  grep -q '`opus`' "$GATE"
  ! grep -q 'マージ条件・聖域・層間契約' "$GATE"
  ! grep -q '聖域・層間契約による' "$GATE"
  ! grep -qE '実装品質起因なら.*`model: fable`' "$GATE"
  # 旧ラダー（実行役を 1 段ずつ上げる）は残さず、決める役の種別で上げる
  ! grep -q '1 段上' "$GATE"
  grep -qF 'dev-workflow:decider' "$GATE"
  grep -qF '一方だけ' "$GATE"
  grep -qF 'W を `fable` にはしない' "$GATE"
  grep -qF '`general-purpose` に `model: fable` は付けない' "$GATE"
  grep -q 'マージ条件' "$GATE"
  grep -q '聖域' "$GATE"
  grep -q '層間契約' "$GATE"
}

# 上のテストは新文言の存在と一部の旧文言の不在しか見ておらず、同じ文書の別の段落
# （needs-reviewer 節のレビュアー説明・モデル節の優先順位）に「fable に触れれば model: fable」
# という旧案内が残っていても緑になっていた（PR #252 の agent-review:failed の指摘）。
# 文書全体を行単位で走査し、Fable に触れる行が決める役の種別を伴うことを要求する。
@test "gate-runner: every line that mentions Fable also names the decider type" {
  offenders="$(grep -in 'fable' "$GATE" | grep -iv 'decider' || true)"
  if [ -n "$offenders" ]; then
    echo "決める役の種別を伴わない Fable の言及が残っている:"
    echo "$offenders"
    false
  fi
}

# ---------- コンテキスト上限の規則は decision-criteria.md 1 箇所に置く（#261） ----------
#
# spec: dev-workflow-develop「コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く」
# 同じ規則を複数の面に言い換えて置くと、次に閾値が変わったときどれかが必ず取り残される
# （#253 で 3 周続けて言い換え漏れが出た）。数値と環境変数名の在処をテストで固定する。

# 節の範囲だけを見るための切り出し。`## コンテキスト上限（サブエージェントの手渡し）` の行から
# 次の `## ` 見出し（`### ` 小見出しは含む）の直前までを取り出す。全文 grep だと、節の外へ
# 内容が移っても素通りしてしまう（G のレビュー指摘、#269 で対応）。
extract_context_cap_section() {
  awk '
    /^## コンテキスト上限（サブエージェントの手渡し）$/ { flag=1 }
    flag && /^## / && !/^## コンテキスト上限（サブエージェントの手渡し）$/ { exit }
    flag
  ' "$1"
}

@test "context cap: the canonical section holds the thresholds, the routes and the return prefixes" {
  dc="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  section="$(extract_context_cap_section "$dc")"
  [ -n "$section" ] || { echo "section not found in decision-criteria.md"; return 1; }
  # 3 つの環境変数と 2 つの既定値
  for token in DEV_WORKFLOW_CONTEXT_CAP DEV_WORKFLOW_CONTEXT_HARD_CAP DEV_WORKFLOW_CONTEXT_TRIPWIRE 150000 220000; do
    echo "$section" | grep -q -- "$token" || { echo "missing in the context cap section: $token"; return 1; }
  done
  # 2 経路・通知時と強制停止時の振る舞い・return の 1 行目の書き分け
  echo "$section" | grep -q '再開前チェック'
  echo "$section" | grep -q '途中計測'
  echo "$section" | grep -q '工程完了:'
  echo "$section" | grep -q '工程中断:'
  echo "$section" | grep -q 'pr-review-gate の手順 1〜5 を 1 グループ'
}

@test "context cap: the other five faces point at the canonical section and restate nothing" {
  faces=(
    "${PLUGIN_DIR}/skills/develop/SKILL.md"
    "${PLUGIN_DIR}/skills/develop/references/roles/worker.md"
    "${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md"
    "${PLUGIN_DIR}/templates/escalation-tripwires.md"
    "${PLUGIN_DIR}/README.md"
  )
  for f in "${faces[@]}"; do
    [ -f "$f" ] || { echo "missing face: $f"; return 1; }
    # 正本への参照があること
    grep -q 'decision-criteria.md' "$f" || { echo "no pointer to decision-criteria.md: $f"; return 1; }
    grep -q 'コンテキスト上限' "$f" || { echo "no reference to the context cap section: $f"; return 1; }
    # 閾値の数値・環境変数名の再掲が無いこと
    for token in DEV_WORKFLOW_CONTEXT_CAP DEV_WORKFLOW_CONTEXT_HARD_CAP DEV_WORKFLOW_CONTEXT_TRIPWIRE 150000 220000 150K; do
      if grep -q -- "$token" "$f"; then
        echo "restated in ${f}: ${token}（正本は decision-criteria.md「コンテキスト上限」）"
        return 1
      fi
    done
  done
}

@test "context cap: worker.md tells the handoff target to look at uncommitted changes first" {
  grep -q '未コミット差分' "$WORKER"
  grep -q 'git status' "$WORKER"
}

@test "context cap: gate-runner returns the review body when the hard stop denies gh" {
  grep -q '工程中断:' "${ROLES}/gate-runner.md"
  grep -q 'gh pr comment' "${ROLES}/gate-runner.md"
  grep -q '代理投稿' "${ROLES}/gate-runner.md"
  # 本体側にも代理投稿する側の手順がある
  grep -q '代理投稿' "${PLUGIN_DIR}/skills/develop/SKILL.md"
}

# ---------- 窓を閉じる（強制停止中の Bash 全件拒否）後の後片付けは本体が担う（#261, PR #269 2 回目の決定） ----------
#
# 強制停止中は Bash がコマンド内容によらず全件拒否されるため、止まったサブエージェント
# 自身は commit できない。手渡し先が拾うのは「次に起こされた」サブエージェントの
# git status / git diff だけなので、手渡しが発生しない経路や後継が G の場合は
# 本体自身が未コミット差分を引き取らないと作業が失われたまま残る（R1-261 の BLOCKER B2/B3）。

@test "SKILL.md: main takes over uncommitted work left by a hard-stopped subagent" {
  grep -q '本体が commit する\|本体が.*commit' "${PLUGIN_DIR}/skills/develop/SKILL.md"
  grep -q 'git -C .*status --porcelain' "${PLUGIN_DIR}/skills/develop/SKILL.md"
  # 発火条件が 工程中断: の受領だけに縛られていない（手渡し・spawn・サイクル終了・worktree 撤去も含む）
  grep -q '手渡し' "${PLUGIN_DIR}/skills/develop/SKILL.md"
  grep -q 'spawn' "${PLUGIN_DIR}/skills/develop/SKILL.md"
  grep -q 'worktree の撤去' "${PLUGIN_DIR}/skills/develop/SKILL.md"
}

@test "SKILL.md forbids isolation: remote for W / G" {
  grep -q 'isolation: "remote"' "${PLUGIN_DIR}/skills/develop/SKILL.md"
  grep -qE '(remote.*使わない|remote.*起こしてはならない)' "${PLUGIN_DIR}/skills/develop/SKILL.md"
}

@test "gate-runner.md: commit is also main's job, not G's" {
  grep -qE 'commit.*本体が行う|本体が.*commit' "${ROLES}/gate-runner.md"
}

@test "gate-runner: legacy fallback is measured and App Server mode stays separate" {
  local doc token
  doc="$(section "$GATE" 'レビューの実行者')"
  for token in '従来モード' '実測したバイナリ無し・認証切れ・タイムアウト' 'companion / slash command が無ければ' 'exec を試す' 'companion 導入は任意' 'command -v codex' 'auth.json' '未試行' '引数誤り・権限拒否・通信障害' '暗黙にフォールバックしない'; do
    echo "$doc" | grep -qF "$token"
  done
  echo "$doc" | grep -q '新 Codex モード.*App Server 固定.*適用しない'
  ! echo "$doc" | grep -q 'サブスク切れ'
}

@test "gate-runner: full needs-reviewer carries evidence also used in PR comment" {
  local doc token
  doc="$(section "$GATE" 'needs-reviewer')"
  for token in '選んだ経路:' '実行コマンド:' '終了コード:' '出力の要点:' '実待ち時間:' '完了未確認' '架空の終了コード' 'light 判定のため' 'full・実測した Codex 不可' '同じ証拠'; do
    echo "$doc" | grep -qF "$token"
  done
}

# ===== gate-runner.md: 指摘の固定書式と要約受領の分岐（issue #349・#352） =====

@test "gate-runner (#349): needs-reviewer payload names the step 2-1 reviewer block as the reviewer instruction" {
  n="$(section "$GATE" 'needs-reviewer')"
  line="$(echo "$n" | grep -F 'レビュアーに渡す指示:')"
  [ -n "$line" ] || { echo "no reviewer-instruction line in needs-reviewer"; return 1; }
  echo "$line" | grep -qF 'SKILL.md 手順 2-1'
  echo "$line" | grep -qF 'レビュアー向け指示ブロック'
  run grep -E '^\| `(blocking|should|nit)` \||`plausible`' "$GATE"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#352): needs-reviewer does not tell G to continue with step 3 unconditionally" {
  run grep -n '手順 3 以降を続ける' "$GATE"
  [ "$status" -ne 0 ]
  n="$(section "$GATE" 'needs-reviewer')"
  echo "$n" | grep -qF '「レビュアーの要約受領」'
}

@test "gate-runner (#349): the reviewer-summary resume branches through the all-round verdict" {
  line="$(grep -F 'レビュアーの要約受領' "$GATE" | grep -v '「レビュアーの要約受領」')"
  [ -n "$line" ] || { echo "no reviewer-summary resume line"; return 1; }
  echo "$line" | grep -qF '全周共通の判定'
  echo "$line" | grep -qF '止める指摘'
  echo "$line" | grep -qF 'follow-up issue'
  echo "$line" | grep -q 'failed'
  echo "$line" | grep -q '仕分け'
  run sh -c "grep -F 'レビュアーの要約受領' '$GATE' | grep -F '一般則'"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#349): the sorting field and on-hold section speak of stopping findings, not quotable ones" {
  common="$(awk '/^## Gate Result/{f=1} f&&/^### /{exit} f' "$GATE")"
  echo "$common" | grep -qF '全周共通の判定で止める指摘が残'
  hold="$(awk '/^### 保留のとき/{f=1;next} /^### /{f=0} f' "$GATE")"
  echo "$hold" | grep -qF '全周共通の判定で止める指摘が残'
  run grep -F '引用できる指摘が残' "$GATE"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#349 gate round 1): the sorting field and the round-2 cap record which of the three exceptions applies" {
  common="$(awk '/^## Gate Result/{f=1} f&&/^### /{exit} f' "$GATE")"
  echo "$common" | grep -F '仕分け' | grep -qF '例外 3 種のどれか'
  hold="$(awk '/^### 保留のとき/{f=1;next} /^### /{f=0} f' "$GATE")"
  echo "$hold" | grep -F '切り出しの確認' | grep -qF '例外 3 種のどれか'
}

# ===== 指摘の仕分け表（issue #354）=====

@test "gate-runner (#354): on-hold split-off confirmation carries the four points of row 5" {
  hold="$(awk '/^### 保留のとき/{f=1;next} /^### /{f=0} f' "$GATE")"
  line="$(echo "$hold" | grep -F '切り出しの確認')"
  [ -n "$line" ] || { echo "no split-off line in on-hold section"; return 1; }
  for token in 'マージ後に何を起こすか' '見積もり' '固定費' '推奨'; do
    echo "$line" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  run grep -F '続けるか、範囲外として閉じるか' "$GATE"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#354): Status has needs-decider and a section says what the main session receives" {
  grep -E '^- Status: ' "$GATE" | grep -qF 'needs-decider'
  nd="$(awk '/^### needs-decider のとき/{f=1;next} /^### |^```$/{f=0} f' "$GATE")"
  [ -n "$nd" ] || { echo "no needs-decider section"; return 1; }
  echo "$nd" | grep -qF '同じ型の指摘'
  echo "$nd" | grep -qF '前の周の指摘'
  echo "$nd" | grep -qF '対象ファイルのパス'
  echo "$nd" | grep -qF 'SendMessage'
}

@test "gate-runner (#354): the sorting field covers every round and records row 3, row 4 and decider rulings" {
  common="$(awk '/^## Gate Result/{f=1} f&&/^### /{exit} f' "$GATE")"
  line="$(echo "$common" | grep -F '仕分け')"
  echo "$line" | grep -qF '指摘を受け取ったすべての周'
  echo "$line" | grep -qF '仕分け表'
  echo "$line" | grep -qF '受け入れ条件の外・その場で直した・直し方 N 行'
  echo "$line" | grep -qF '閉じた PR コメント URL'
  echo "$line" | grep -qF '決める役の裁定:'
}

@test "gate-runner (#354): resume has a line for the decider ruling that records it and counts from PR comments" {
  line="$(grep -F '決める役の裁定受領' "$GATE")"
  [ -n "$line" ] || { echo "no decider-ruling resume line"; return 1; }
  echo "$line" | grep -qF '決める役の裁定:'
  echo "$line" | grep -qF 'PR コメント'
  echo "$line" | grep -qF '全部列挙してから直す'
  echo "$line" | grep -qF '切り出す'
  grep -E 'W の修正後の再レビュー' "$GATE" | grep -qF '主の回答または決める役の裁定'
}

@test "worker (#354): W posts the row-3 table with the search command before pushing, and records row-4 fixes" {
  [ "$(grep -c '検索コマンド' "$WORKER")" -ge 1 ]
  grep -qF '投稿してから push' "$WORKER"
  grep -qF 'SKILL.md 手順 2-1 の仕分け表の順 3' "$WORKER"
  ret="$(awk '/^\*\*\(3a\) の return に書くこと\*\*/{f=1} f&&/^## /{exit} f' "$WORKER")"
  echo "$ret" | grep -qF '受け入れ条件の外・その場で直した・直し方 N 行'
}

@test "develop SKILL.md (#354): step (4) handles needs-decider with the verdict-and-reasons contract" {
  sk="${PLUGIN_DIR}/skills/develop/SKILL.md"
  step4="$(awk '/^\(4\) G を/{f=1} f&&/^```$/{exit} f' "$sk")"
  [ -n "$step4" ] || { echo "no step (4) block"; return 1; }
  echo "$step4" | grep -qF 'passed / failed / 保留 / needs-reviewer / needs-decider'
  nd="$(echo "$step4" | awk '/^      needs-decider →/{f=1; print; next} f&&/^      [^ ]/{exit} f')"
  [ -n "$nd" ] || { echo "no needs-decider line in step (4)"; return 1; }
  for token in 'dev-workflow:decider' 'マージ可否と同じ可否と根拠の形で問う' '同じ型の指摘' '前の周の指摘' '対象ファイルのパス' '仕分け欄' '全部列挙してから直す' '切り出す' 'SendMessage' '代理投稿しない'; do
    echo "$nd" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "develop SKILL.md (#354): the proxy-posting rule for decider returns names the row-6 exception" {
  sk="${PLUGIN_DIR}/skills/develop/SKILL.md"
  line="$(grep -F '本体がやること:' "$sk")"
  echo "$line" | grep -qF '代理投稿する'
  echo "$line" | grep -qF '順 6'
}

# ===== 一周目レビューの機械照合と補足上限（issue #355） =====

@test "gate-runner (#355): first-pass tables are mechanically checked before triage" {
  first="$(section "$GATE" '一周目の三表を機械照合する')"
  [ -n "$first" ] || { echo 'no first-pass reconciliation section'; return 1; }
  for token in '受け入れ条件' '変更点 ID' 'review-hit-set.py' '全ヒット集合' '固定した PR diff' '全ハンク' '指摘の仕分け前'; do
    echo "$first" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "gate-runner (#355): a no-findings summary cannot reach passing steps without all three tables" {
  line="$(grep -F '**レビュアーの要約受領**' "$GATE")"
  for token in '変更点の一覧' '照合表' 'ハンク被覆' '最初に' '照合が完了したあと' '不足' 'needs-reviewer' 'review-incomplete'; do
    echo "$line" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  echo "$line" | grep -qF '指摘が無ければ手順 3 以降'
}

@test "gate-runner (#355): one supplemental pass is payload state and residual is terminal" {
  n="$(section "$GATE" 'needs-reviewer')"
  for token in '固定 HEAD' '元の三表' '残差' '補足済み回数: 0' '不足した項目だけ' 'SKILL.md 手順 2-1'; do
    echo "$n" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  common="$(awk '/^## Gate Result/{f=1} f&&/^### /{exit} f' "$GATE")"
  echo "$common" | grep -qF 'review-incomplete'
  residual="$(section "$GATE" '補足レビュー結果の受領')"
  echo "$residual" | grep -qF '補足済み回数: 1'
  echo "$residual" | grep -qF 'review-incomplete'
  echo "$residual" | grep -qF '2 回目の `needs-reviewer` を返さない'
}

@test "gate-runner (#355): later-round findings carry exactly one measurement category without changing routing" {
  common="$(awk '/^## Gate Result/{f=1} f&&/^### /{exit} f' "$GATE")"
  for token in '同じ文が複数か所' '場合分けの漏れ' '直したつもりで直っていない' '直しで新しく入った' 'いずれか 1 つ'; do
    echo "$common" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  echo "$common" | grep -qF '停止判定と仕分け順を変えない'
  echo "$common" | grep -qF '仕分けの PR コメントにも記録'
  echo "$common" | grep -qF 'PR コメント URL'
}

@test "develop SKILL.md (#355): review-incomplete stops without a fresh reviewer and supplement payload is conditional" {
  sk="${PLUGIN_DIR}/skills/develop/SKILL.md"
  step4="$(awk '/^\(4\) G を/{f=1} f&&/^```$/{exit} f' "$sk")"
  echo "$step4" | grep -qF 'review-incomplete'
  echo "$step4" | grep -qF 'reviewer を再起動しない'
  echo "$step4" | grep -qF 'agent-review:pending'
  echo "$step4" | grep -qF '通常の初回レビュー依頼'
  echo "$step4" | grep -qF '一周目照合の補足要求である場合に限り'
  for token in '固定 HEAD' '元の三表' '残差' '補足済み回数'; do
    echo "$step4" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

# ===== 仕分け表の追補（issue #357 #358 #359）=====

@test "develop SKILL.md (#358): needs-decider passes the record body, related comments and W's last return, and branches on the first line" {
  sk="${PLUGIN_DIR}/skills/develop/SKILL.md"
  step4="$(awk '/^\(4\) G を/{f=1} f&&/^```$/{exit} f' "$sk")"
  nd="$(echo "$step4" | awk '/^      needs-decider →/{f=1; print; next} f&&/^      [^ ]/{exit} f')"
  [ -n "$nd" ] || { echo "no needs-decider line in step (4)"; return 1; }
  for token in '記録先の本文' '関連コメント' 'W の直近の return' '`裁定: 可`' '`裁定: 否`' '`不足: <足りないもの>`' \
    '1 行目で分岐' '裁定として扱わず' '1 回だけ依頼し直す' '裁定なし（入力不足）' '3 形のどれにも一致しなければ'; do
    echo "$nd" | grep -qF -- "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "gate-runner (#359): on-hold lists unprocessed row 6, and needs-decider also covers the return after the owner's answer" {
  hold="$(awk '/^### 保留のとき/{f=1;next} /^### /{f=0} f' "$GATE")"
  echo "$hold" | grep -qF '順 6・未裁定'
  nd="$(awk '/^### needs-decider のとき/{f=1;next} /^### |^```$/{f=0} f' "$GATE")"
  echo "$nd" | grep -qF '主の回答のあとに未処理の順 6'
}

@test "gate-runner (#359): owner-answer and decider-ruling resumes refer to the mixed paragraph and do not go to failed early" {
  for key in '保留の解除' '決める役の裁定受領'; do
    line="$(grep -F -- "**$key**" "$GATE")"
    [ -n "$line" ] || { echo "no line: $key"; return 1; }
    echo "$line" | grep -qF 'pr-review-gate 手順 2-1 の混在の段落' || { echo "$key lacks mixed ref"; return 1; }
    echo "$line" | grep -qF 'failed に進まない' || { echo "$key lacks guard"; return 1; }
  done
  grep -F '**決める役の裁定受領**' "$GATE" | grep -qF '裁定なし（入力不足）'
}

@test "gate-runner (#357): the post-fix re-review matches row 3 in two stages, pre-fix SHA and HEAD" {
  line="$(grep -F '**W の修正後の再レビュー**' "$GATE")"
  echo "$line" | grep -qF '修正前 SHA と HEAD の 2 段'
  echo "$line" | grep -qF 'pr-review-gate 手順 2-1 の仕分け表の順 3'
}

@test "gate-runner (#359): the reviewer-summary resume returns only the hold when row 5 mixes with rows 2-4 or row 6" {
  line="$(grep -F '**レビュアーの要約受領**' "$GATE")"
  echo "$line" | grep -qF '順 5 と順 2〜4、または順 5 と順 6 が混ざれば保留だけを先に返す'
  echo "$line" | grep -qF '保留と `needs-decider` を同じ return で指示しない'
}

@test "worker (#357): the row-3 list paragraph records the pre-fix SHA and does not restate the columns" {
  para="$(grep -F '**G から一覧を求められた指摘' "$WORKER")"
  echo "$para" | grep -qF '修正前 SHA'
  echo "$para" | grep -qF '修正に着手する直前の HEAD'
  echo "$para" | grep -qF 'SKILL.md 手順 2-1 の仕分け表の順 3'
  run grep -F '| ファイル | 行（修正前 SHA） |' "$WORKER"
  [ "$status" -ne 0 ]
}

@test "worker (#377): the row-3 list paragraph puts rewritten not-applicable rows in the rewritten-rows table without restating its columns" {
  para="$(grep -F '**G から一覧を求められた指摘' "$WORKER")"
  echo "$para" | grep -qF '`### 書き換えた該当しない行`'
  echo "$para" | grep -qF '主表の本文は修正前のまま'
  echo "$para" | grep -qF '修正後の本文'
  run grep -F '| 修正後の本文 |' "$WORKER"
  [ "$status" -ne 0 ]
}

@test "gate-runner (#377): the row-3 second stage runs review-hit-set.py with --head and the fetched 40-digit HEAD" {
  line="$(grep -F '**W の修正後の再レビュー**' "$GATE")"
  echo "$line" | grep -qF 'review-hit-set.py'
  echo "$line" | grep -qF -- '--head <HEAD の 40 桁 SHA>'
  echo "$line" | grep -qF 'git fetch'
  echo "$line" | grep -qF 'pr-review-gate 手順 2-1 の仕分け表の順 3'
}
