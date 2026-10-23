#!/usr/bin/env bats
#
# develop スキル（本体＝オーケストレータ）の構造検証（issue #203）
#
# SKILL.md は実行コードではないため、規定（いつ使うか・本体の禁止事項・入口 0・
# 1 ループ・モデル・実行モード・前提・エピック）の記述が存在することを文書アサーションで検証する。
# 節ごとに切り出してから grep し、他節の既存文で偽合格しないようにする。
#
# spec: dev-workflow-develop, dev-workflow-execution-strategy (REMOVED), dev-workflow-escalation-tripwires

setup() {
  # 文面検査の正規表現（[^。]* など）は多バイトを 1 文字として数える UTF-8 ロケールが前提。
  # LANG 未設定（C ロケール）だと [^。] が日本語の文字を構成するバイトを除外して空振りする（#662）
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_DIR="${PLUGIN_DIR}/skills/develop"
  SKILL="${SKILL_DIR}/SKILL.md"
  # エピックの 2 節は SKILL.md から references/ へ移した（#1219）
  EPIC="${SKILL_DIR}/references/epic.md"
  EPIC_CHILD_STOP="${SKILL_DIR}/references/epic-child-stop.md"
  TRIPWIRES="${PLUGIN_DIR}/templates/escalation-tripwires.md"
}

# 「## <見出し>」から次の「## 」までを切り出す
# 第 2 引数で読むファイルを変えられる（既定は SKILL.md）
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "${2:-$SKILL}"; }
frontmatter() { awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL"; }

# 「1 ループ」のコードブロックから工程の指示を切り出す。境界は**行頭の工程ラベル**だけで、
# 説明文の途中に出てくる "(3a)" / "(4)" のような参照では区切らない（本文に無害な行を足しても
# 切り出し位置がずれないようにするため）。
#   top_step 3  : 列 0 の "(3) " から次の列 0 の "(N) " の手前まで
#   substep 3a  : インデントされた "(3a) " から次の "(3a)/(3b)/(3)" ラベルか列 0 の "(N) " の手前まで
#                 （字下げした "(3) " の行は (3) 全体への注記で、(3a) にも (3b) にも属さない）
top_step() { awk -v s="$1" '$0 ~ "^\\(" s "\\)[[:space:]]" {f=1; print; next} f && /^\([0-9]+\)[[:space:]]/ {f=0} f'; }
substep() { awk -v s="$1" '$0 ~ "^[[:space:]]+\\(" s "\\)[[:space:]]" {f=1; print; next} f && (/^[[:space:]]+\(3[ab]?\)[[:space:]]/ || /^\([0-9]+\)[[:space:]]/) {f=0} f'; }

# 否定アサーション: refute "<本文>" -F|-E '<パターン>'
# bats（bash の set -e）は `!` を先頭に付けたコマンドの失敗を無視するため、テストの最終行以外に
# 書いた `! ... | grep -q ...` は退行を検出できない（bats 1.13 で実測）。否定はこの関数で書く。
refute() {
  local body="$1"; shift
  if printf '%s\n' "$body" | grep -q "$@"; then
    echo "一致してはならないパターンに一致した: $*" >&2
    return 1
  fi
}

# --- 存在・frontmatter ---

@test "skill: develop SKILL.md exists and the old issue-only skill dir is gone" {
  [ -f "$SKILL" ]
  [ ! -e "${PLUGIN_DIR}/skills/github-""issue" ]
}

@test "frontmatter: name is develop and version is at least 2.0.0" {
  frontmatter | grep -q '^name: develop$'
  v="$(frontmatter | awk -F': ' '/^version:/{print $2; exit}')"
  [ -n "$v" ]
  printf '2.0.0\n%s\n' "$v" | sort -V -C
}

@test "frontmatter: description carries the old issue trigger words" {
  d="$(frontmatter | awk '/^description:/{print; exit}')"
  echo "$d" | grep -q 'issue 番号'
  echo "$d" | grep -q 'URL'
  echo "$d" | grep -q 'この issue 対応して'
}

@test "frontmatter: description says the skill is mandatory for code/skill/command/normative changes" {
  d="$(frontmatter | awk '/^description:/{print; exit}')"
  echo "$d" | grep -q '規範文書'
  echo "$d" | grep -q '必ず'
}

# --- いつ使うか ---

@test "when-to-use: entry-agnostic with the read-only exception" {
  section 'いつ使うか' | grep -q '入口を問わず'
  section 'いつ使うか' | grep -q '規範文書'
  section 'いつ使うか' | grep -q '読むだけ'
  section 'いつ使うか' | grep -q '回答だけ'
  section 'いつ使うか' | grep -q '生成物'
}

# --- 本体の役割 ---

@test "orchestrator: main never edits code nor performs reviews itself" {
  section '本体の役割' | grep -q 'Edit でコードを書かない'
  section '本体の役割' | grep -qE 'レビュー.*代行しない'
  section '本体の役割' | grep -q '`model`'
  section '本体の役割' | grep -qE 'W / R1 / G|W・R1・G'
}

@test "orchestrator: decides the next role from return summaries and record-target comments/labels" {
  section '本体の役割' | grep -q 'return'
  section '本体の役割' | grep -qE '記録先.*(コメント|ラベル)'
}

# --- 入口 0 ---

@test "entry-0: issue if present, otherwise Draft PR before the spec decision" {
  section '入口 0' | grep -q 'issue があれば'
  section '入口 0' | grep -q 'git commit --allow-empty'
  section '入口 0' | grep -q 'gh pr create --draft'
  section '入口 0' | grep -qE '仕様化判断.*(前|先)'
}

@test "entry-0: acceptance criteria go to the PR body and no issue reference in the PR body" {
  section '入口 0' | grep -qE '受け入れ条件.*PR 本文'
  section '入口 0' | grep -q 'Closes'
  section '入口 0' | grep -qE '(Closes|Refs).*(書かない|書いてはならない)'
}

@test "entry-0: issues are opened only for epics, unmanned queues, or recorded discussions" {
  section '入口 0' | grep -q 'エピック'
  section '入口 0' | grep -q '無人キュー'
  section '入口 0' | grep -q '議論'
}

@test "entry-0: decision and review result live in record-target comments; the spec declaration always goes to a PR comment" {
  # 記録先のコメントに置くのは仕様化判断と仕様レビュー結果
  section '入口 0' | grep -qF '仕様化判断: する|しない'
  section '入口 0' | grep -qF '仕様レビュー: APPROVE|REQUEST_CHANGES'
  section '入口 0' | grep -F '仕様化判断: する|しない' | grep -q '記録先のコメント'
  # 仕様宣言は記録先ではなく PR コメント（issue #212。pr-review-gate 手順 3-b / 5 と worker/finish.md が正）:
  # 節内で仕様宣言に触れる行はすべて 'PR コメント' を含む（冒頭文の「…仕様宣言を置く「記録先」」の再発もここで落ちる）
  section '入口 0' | grep -q '仕様宣言'
  [ -z "$(section '入口 0' | grep '仕様宣言' | grep -v 'PR コメント')" ]
}

# --- worktree ---

@test "worktree: main prepares it (isolation worktree) and W never creates one" {
  grep -qF 'isolation: "worktree"' "$SKILL"
  grep -qE 'W は.*worktree を(切らない|作らない)' "$SKILL"
}

# --- 1 ループ ---

@test "loop: stages 0-4 run in W -> R1 -> W -> G order" {
  loop="$(section '1 ループ')"
  s0="$(echo "$loop" | grep -n '(0)' | head -1 | cut -d: -f1)"
  s1="$(echo "$loop" | grep -n '(1)' | head -1 | cut -d: -f1)"
  s2="$(echo "$loop" | grep -n '(2)' | head -1 | cut -d: -f1)"
  s3="$(echo "$loop" | grep -n '(3)' | head -1 | cut -d: -f1)"
  s4="$(echo "$loop" | grep -n '(4)' | head -1 | cut -d: -f1)"
  [ -n "$s0" ] && [ -n "$s1" ] && [ -n "$s2" ] && [ -n "$s3" ] && [ -n "$s4" ]
  [ "$s0" -lt "$s1" ] && [ "$s1" -lt "$s2" ] && [ "$s2" -lt "$s3" ] && [ "$s3" -lt "$s4" ]
  echo "$loop" | sed -n "${s1},${s2}p" | grep -q 'W'
  echo "$loop" | sed -n "${s2},${s3}p" | grep -q 'R1'
  echo "$loop" | sed -n "${s3},${s4}p" | grep -q 'W'
  echo "$loop" | sed -n "${s4},\$p" | grep -q 'G'
}

@test "loop: W does spec decision, split judgement and openspec new change, then R1 reviews before apply" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -q '仕様化判断'
  echo "$loop" | grep -q 'openspec new change'
  ff="$(echo "$loop" | grep -n 'openspec new change' | head -1 | cut -d: -f1)"
  rev="$(echo "$loop" | grep -n '仕様レビュー' | head -1 | cut -d: -f1)"
  apply="$(echo "$loop" | grep -n 'apply' | head -1 | cut -d: -f1)"
  [ "$ff" -lt "$rev" ] && [ "$rev" -lt "$apply" ]
  echo "$loop" | grep -qE '仕様化しない.*\(3\)'
}

@test "loop: R1 and G both have a two-round cap and needs-approval afterwards" {
  loop="$(section '1 ループ')"
  [ "$(echo "$loop" | grep -cE '2 ?周')" -ge 2 ]
  echo "$loop" | grep -q 'needs-approval'
}

@test "loop: G failed raises only the cause side (never W to fable) then resumes W and spawns the next-stage G" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -qE 'failed.*原因分類'
  echo "$loop" | grep -qF '実装品質起因のときだけ'
  echo "$loop" | grep -qF '一方だけ'
  echo "$loop" | grep -qF 'dev-workflow:decider'
  echo "$loop" | grep -qF 'W を fable にはしない'
  echo "$loop" | grep -qE 'W を再開'
  # #554: G は再開せず、failed の Gate Result の 次の段: どおりに新しく起こす
  echo "$loop" | grep -qF '`次の段:` どおりの G を新しく起こして再レビュー'
}

@test "loop: W is spawned by name, resumed via SendMessage, and never needs grandchildren" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -q '名前付き'
  echo "$loop" | grep -q 'SendMessage'
  echo "$loop" | grep -q '孫'
}

@test "loop: W's second run covers apply(TDD), verify, archive, the Draft PR and the spec declaration" {
  loop="$(section '1 ループ')"
  echo "$loop" | grep -q 'TDD'
  echo "$loop" | grep -q 'verify'
  echo "$loop" | grep -q 'archive'
  echo "$loop" | grep -q 'Draft'
  echo "$loop" | grep -q '仕様宣言'
}

# ゲート合格まで PR を Draft のまま進める（#304）。CI を Draft で止めるリポでは、W が (3b) で Ready にすると
# レビューと修正の周回ごとに CI が走る。Ready 化は G が pr-review-gate 手順 5 で passed の直前に行う。
@test "loop: (3b) hands the PR over as Draft and (4) makes it Ready before passed" {
  s3="$(section '1 ループ' | top_step 3)"
  segb="$(echo "$s3" | substep 3b)"
  [ -n "$segb" ] || { echo "no (3b) substep in the (3) block"; return 1; }
  echo "$segb" | grep -q 'Draft のまま'
  echo "$segb" | grep -q 'Draft で作成'
  # W が Ready に切り替える記述が無い（Ready に触れてよいのは G が手順 5 で行うという参照だけ）
  refute "$segb" -E 'Ready に(（|切り替え|する)'
  stray="$(echo "$segb" | grep -F 'Ready' | grep -vF '手順 5' || true)"
  [ -z "$stray" ] || { echo "Ready が (3b) の W の作業として書かれている: $stray"; return 1; }
  s4="$(section '1 ループ' | top_step 4)"
  [ -n "$s4" ] || { echo "no (4) step in the loop block"; return 1; }
  echo "$s4" | tr '\n' ' ' | grep -qE 'Draft なら Ready にしてから[^。]*agent-review:passed'
}

# (3) を (3a) 実装＋verify / (3b) archive＋PR＋仕様宣言 の 2 回の return に分ける（#262）。
# 本体がコンテキスト量を測れるのは W を再開する直前だけなので、return の区切りの数が計測点の数になる。
@test "loop: stage 3 splits into (3a) implement+verify and (3b) archive+PR+spec declaration" {
  s3="$(section '1 ループ' | top_step 3)"
  [ -n "$s3" ] || { echo "no (3) step in the loop block"; return 1; }
  sega="$(echo "$s3" | substep 3a)"
  segb="$(echo "$s3" | substep 3b)"
  [ -n "$sega" ] || { echo "no (3a) substep in the (3) block"; return 1; }
  [ -n "$segb" ] || { echo "no (3b) substep in the (3) block"; return 1; }
  # 工程ラベルの並び順（実装が archive より先）
  la="$(echo "$s3" | grep -nE '^[[:space:]]+\(3a\)[[:space:]]' | head -1 | cut -d: -f1)"
  lb="$(echo "$s3" | grep -nE '^[[:space:]]+\(3b\)[[:space:]]' | head -1 | cut -d: -f1)"
  [ "$la" -lt "$lb" ]
  # (3a) は実装と verify を行い、その return で「実装＋verify」の完了を宣言する
  echo "$sega" | grep -q 'TDD'
  echo "$sega" | grep -q 'verify'
  echo "$sega" | grep -F '工程完了: 実装＋verify' | grep -q 'return'
  refute "$sega" -F '工程完了: archive'
  # (3a) で archive しない。archive に触れてよいのは「archive は (3b)」という参照だけ
  stray="$(echo "$sega" | grep -F 'archive' | grep -vF '(3b)' || true)"
  [ -z "$stray" ] || { echo "archive が (3a) の作業として書かれている: $stray"; return 1; }
  # (3b) は archive・PR を Draft のまま用意・仕様宣言を行い、その return で「archive＋PR＋仕様宣言」の完了を宣言する
  echo "$segb" | grep -q 'archive'
  echo "$segb" | grep -q 'Draft'
  echo "$segb" | grep -q '仕様宣言'
  echo "$segb" | grep -F '工程完了: archive＋PR＋仕様宣言' | grep -q 'return'
  refute "$segb" -F '工程完了: 実装＋verify'
}

@test "loop: main measures between (3a) and (3b) and defers the cap handling to decision-criteria.md" {
  s3="$(section '1 ループ' | top_step 3)"
  sega="$(echo "$s3" | substep 3a)"
  [ -n "$sega" ] || { echo "no (3a) substep in the (3) block"; return 1; }
  # (3a) の return を受けたあと (3b) を指示する前に、本体がもう一度測る
  echo "$sega" | grep -F 'subagent-context.sh' | grep -q '測'
  echo "$sega" | grep -F 'subagent-context.sh' | grep -q '指示'
  # 閾値・環境変数名は再掲せず正本を指す（正本は decision-criteria.md「コンテキスト上限」）
  echo "$s3" | grep -F 'decision-criteria.md' | grep -q 'コンテキスト上限'
  echo "$s3" | grep -F 'decision-criteria.md' | grep -q '正本'
  refute "$s3" -F 'DEV_WORKFLOW_CONTEXT_CAP'
  refute "$s3" -E '150000|150K|220000'
  # (3a)/(3b) より細かく切らないこと（禁止であることまで検査する）
  echo "$s3" | grep -qE '細かく.*切らない'
}

# 旧世代の W（古いキャッシュの worker.md を読んだ W）が (3) を通しで終えて返してきたとき、
# 本体が (3b) を再指示して PR の作成と仕様宣言を二重に走らせないための工程ルーティング。
# 規定は 2 行にまたがるので、改行を空白に潰した上で条件と帰結を順序込みで検査する
# （「揃っていなければ (3b) を指示せず」のような意味の反転を落とすため）。
@test "loop: main routes stage 3 by what it instructed, not by matching the stage name string" {
  flat="$(section '1 ループ' | top_step 3 | tr '\n' ' ')"
  [ -n "$flat" ]
  echo "$flat" | grep -qE '自分が \(3a\) を指示したか \(3b\) を指示したかで決め[^。]*工程名の文字列照合では決めない'
  echo "$flat" | grep -qE '\(3a\) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば[^。]*\(3b\) を指示せず'
}

# --- モデル ---

@test "model: W defaults to sonnet and is capped at opus; R1 opus, G sonnet; fable only via the decider type" {
  m="$(section 'モデル')"
  echo "$m" | grep -qE '^\| W（実行役。`dev-workflow:worker`） \| `sonnet` \|'
  echo "$m" | grep -qE 'W.*`opus`'
  echo "$m" | grep -qE '^\| R1（読んで判断する役） \| `opus` \|'
  echo "$m" | grep -qE '^\| G（`dev-workflow:gate-runner`） \| `sonnet` \|'
  ! echo "$m" | grep -qE 'マージ条件・聖域・層間契約' || return 1
  echo "$m" | grep -q '事前分類'
  echo "$m" | grep -q 'マージ条件'
  echo "$m" | grep -q '聖域'
  echo "$m" | grep -q '層間契約'
  # W を fable にする行は無く、fable は決める役の種別だけ
  echo "$m" | grep -qF 'W の上限は `opus`'
  echo "$m" | grep -qF 'dev-workflow:decider'
  echo "$m" | grep -qF 'agent-model-guard.sh'
}

@test "model: reserve only for automatic runs, exhausted caps every path at opus" {
  m="$(section 'モデル')"
  echo "$m" | grep -qE 'reserve.*自動実行'
  echo "$m" | grep -qE 'exhausted.*全経路'
  echo "$m" | grep -q 'FABLE_BUDGET_MODE'
  echo "$m" | grep -q 'references/decision-criteria.md'
}

@test "model: the escalation tripwire survives as a one-side-only ladder" {
  m="$(section 'モデル')"
  echo "$m" | grep -q '2 連続'
  echo "$m" | grep -qF 'どちらか一方だけ'
  echo "$m" | grep -qF '両方同時に上げない'
  echo "$m" | grep -qF 'dev-workflow:decider'
}

@test "model: shared budget mode sets the floor and abundant no longer lifts W" {
  m="$(section 'モデル')"
  echo "$m" | grep -q 'SHARED_BUDGET_MODE'
  echo "$m" | grep -qE 'throttled.*`sonnet`'
  echo "$m" | grep -qE 'depleted.*`sonnet`'
  echo "$m" | grep -q 'どの役割の既定も上げない'
}

@test "model: G defaults to sonnet and every pre-classification lifts W only to opus" {
  m="$(section 'モデル')"
  echo "$m" | grep -qE '^\| G（`dev-workflow:gate-runner`） \| `sonnet` \|'
  echo "$m" | grep -qE '^\| R1（読んで判断する役） \| `opus` \|'
  echo "$m" | grep -q '聖域パス'
  echo "$m" | grep -qE 'マージ権限・層間契約・課金/法務'
}

@test "loop: W is measured with subagent-context.sh before every SendMessage resume, and G is never resumed" {
  loop="$(section '1 ループ（W → R1 → W → G）')"
  echo "$loop" | grep -q 'subagent-context.sh'
  echo "$loop" | grep -q '手渡し'
  # 閾値と環境変数名の正本は decision-criteria.md「コンテキスト上限」1 箇所（#261）。
  # ここでは再掲ではなく、その正本を指していることを固定する
  echo "$loop" | grep -q 'decision-criteria.md'
  echo "$loop" | grep -q 'コンテキスト上限'
  ! echo "$loop" | grep -q 'DEV_WORKFLOW_CONTEXT_CAP' || return 1
  # #554: G は段ごとに新しく起こすので、再開前の計測は W だけに掛かる
  echo "$loop" | grep -qF '再開前の計測は W だけに掛かる'
}

@test "model: no execution-strategy branches nor deterministic signal commands anywhere under develop" {
  ! grep -rq 'delegate+verify' "$SKILL_DIR" || return 1
  ! grep -rq 'workflow 型' "$SKILL_DIR" || return 1
  ! grep -rqE '4 ?象限' "$SKILL_DIR" || return 1
  ! grep -rq '決定論的シグナル' "$SKILL_DIR" || return 1
  ! grep -rq 'self-contained' "$SKILL_DIR" || return 1
  ! grep -rqF '| length' "$SKILL_DIR" || return 1
  ! grep -rqF "startswith(\"size:\")" "$SKILL_DIR" || return 1
}

# --- 実行モード ---

@test "mode table: unmanned main is the orchestrator, runs (0)-(3), W adds Draft PR + pending, G left to Step 1" {
  t="$(section '実行モード')"
  echo "$t" | grep -q 'interactive'
  echo "$t" | grep -q 'unmanned'
  echo "$t" | grep -q '憲法のメイン'
  echo "$t" | grep -qE 'W / R1.*spawn|W と R1.*spawn'
  echo "$t" | grep -qE '\(0\).*\(3\)'
  echo "$t" | grep -q 'Draft PR'
  echo "$t" | grep -q 'agent-review:pending'
  echo "$t" | grep -qE 'G.*Step 1'
}

@test "mode table: spec decision record and spec review are not exempt in unmanned" {
  t="$(section '実行モード')"
  echo "$t" | grep -qE '(仕様化判断|判定の記録).*免除しない'
  echo "$t" | grep -qE '仕様レビュー.*免除しない|免除しない.*仕様レビュー'
  echo "$t" | grep -q 'blocked_by'
}

# --- 前提 ---

@test "prerequisites: Agent / SendMessage / gh / opsx-or-openspec / Codex with their degraded paths" {
  p="$(section '前提')"
  echo "$p" | grep -q 'Agent'
  echo "$p" | grep -q '`model`'
  echo "$p" | grep -q '名前付き'
  echo "$p" | grep -qF 'isolation: "worktree"'
  echo "$p" | grep -q 'SendMessage'
  echo "$p" | grep -q '`gh`'
  echo "$p" | grep -q 'dependencies'
  echo "$p" | grep -q 'opsx'
  echo "$p" | grep -q 'openspec'
  echo "$p" | grep -q 'Codex'
  echo "$p" | grep -q 'needs-reviewer'
}

# --- エピック ---

@test "epic: four subsections exist (conditions / how to create / how to run / completion)" {
  e="$(section 'エピックの扱い' "$EPIC")"
  echo "$e" | grep -q '^### 条件'
  echo "$e" | grep -q '^### 作り方'
  echo "$e" | grep -q '^### 回し方'
  echo "$e" | grep -q '^### 完了条件'
}

@test "epic: conditions name 2+ PRs, multiple capabilities, or ordered children" {
  e="$(section 'エピックの扱い' "$EPIC")"
  echo "$e" | grep -qE '2 本以上'
  echo "$e" | grep -q 'capability'
  echo "$e" | grep -q '順序依存'
}

@test "epic: creation binds Closes to children and wires dependencies via blocked_by" {
  e="$(section 'エピックの扱い' "$EPIC")"
  echo "$e" | grep -q 'Closes'
  echo "$e" | grep -q 'dependencies/blocked_by'
  echo "$e" | grep -q '/develop <エピック番号>'
}

@test "epic: children run in parallel in isolated worktrees, new problems become new child issues" {
  e="$(section 'エピックの扱い' "$EPIC")"
  echo "$e" | grep -q '並列'
  echo "$e" | grep -qF 'isolation: "worktree"'
  echo "$e" | grep -q '新しい子 issue'
  echo "$e" | grep -qE 'スタック'
}

@test "epic: completion needs the epic's own verification, not just all children merged" {
  e="$(section 'エピックの扱い' "$EPIC")"
  echo "$e" | grep -q '閉じない'
  echo "$e" | grep -qE '証拠.*エピック'
}

# --- エピックの 2 節の移設（#1219） ---

@test "epic move (#1219): SKILL.md keeps only a short guide that says when to Read the moved files" {
  g="$(section 'エピックの扱い')"
  [ -n "$g" ]
  echo "$g" | grep -qF '`references/epic.md`'
  echo "$g" | grep -qF 'Read'
  echo "$g" | grep -qF '`/develop <エピック番号>` で起動したとき'
  echo "$g" | grep -qF '`nested` を返すエピックの子として動き'
  echo "$g" | grep -qF '単発の issue・会話依頼・Draft PR を記録先にする依頼の 1 ループでは読まない'
  [ "$(echo "$g" | grep -c '^### ')" -eq 0 ]
  c="$(section 'エピックの子が主の返事を待って止まるとき')"
  [ -n "$c" ]
  echo "$c" | grep -qF '`references/epic-child-stop.md` を Read'
  echo "$c" | grep -qF '主の返事を待って止まる前'
  echo "$c" | grep -qF '`主の返事（親エピック #`'
  echo "$c" | grep -qF '`nested` でないセッションは読まない'
  # 参照の節からも辿れる
  section '参照' | grep -qF '`references/epic.md`'
  section '参照' | grep -qF '`references/epic-child-stop.md`'
}

@test "epic move (#1219): phrases unique to the moved sections live in the moved files, not in SKILL.md" {
  [ -f "$EPIC" ]
  [ -f "$EPIC_CHILD_STOP" ]
  local p
  for p in '### 条件' '### 作り方' '### 回し方' '### 完了条件' '**経路の決め方**' '**エピックである子を外す**' \
           '**部品ごとの欄**' 'sub_issues_summary' 'dependencies/blocked_by -F issue_id' 'epic-dispatch.sh route <子>'; do
    grep -qF -- "$p" "$EPIC" || { echo "移設先に無い: $p" >&2; return 1; }
    if grep -qF -- "$p" "$SKILL"; then echo "SKILL.md に残っている: $p" >&2; return 1; fi
  done
  for p in '子の停止: 主の返事待ち' '**記録の形**' '**親から届いた返事**' 'mark stopped' 'mark resumed' 'owner-reply-check.sh --relayed'; do
    grep -qF -- "$p" "$EPIC_CHILD_STOP" || { echo "移設先に無い: $p" >&2; return 1; }
    if grep -qF -- "$p" "$SKILL"; then echo "SKILL.md に残っている: $p" >&2; return 1; fi
  done
}

@test "epic move (#1219): references inside the moved files point back to SKILL.md or to each other" {
  grep -qF 'SKILL.md の「保留で止まるときの引き継ぎ」→「新しいセッションでの再開」の手順 2' "$EPIC_CHILD_STOP"
  grep -qF '`references/epic.md` の「回し方」の別セッション方式の手順 8' "$EPIC_CHILD_STOP"
  grep -qF '子の側の手順は `references/epic-child-stop.md`' "$EPIC"
  # SKILL.md の他の節は移設先を指す（旧い節名の参照が残っていない）
  if grep -qF '「エピックの扱い」→「回し方」' "$SKILL"; then return 1; fi
  if grep -qF '「エピックの子が主の返事を待って止まるとき」の「親から届いた返事」' "$SKILL"; then return 1; fi
}

# --- 上流の壁打ち（旧 longrun:plan。#205 で /opsx:explore に） ---

@test "upstream brainstorming (opsx:explore) is explicitly not called from develop" {
  grep -q '^## 上流の壁打ち' "$SKILL"
  grep -q 'opsx:explore' "$SKILL"
  ! grep -q 'longrun' "$SKILL" || return 1
  ! grep -qF '/lr:' "$SKILL" || return 1
}

# --- 昇格トリップワイヤーのテンプレート（1.6b。hook 出力を検査する tripwire-hook.bats には混ぜない） ---

@test "tripwire template: wire 4 is the context cap handoff and wire 5 is the rate-limit reactive downgrade" {
  grep -qE '^4\. 【コンテキスト上限 → 手渡し】' "$TRIPWIRES"
  grep -qE '^5\. 【rate-limit 実エラー → reactive 降格】' "$TRIPWIRES"
  ! grep -qE '^6\. ' "$TRIPWIRES" || return 1
  w4="$(awk '/^4\. /{f=1} /^5\. /{f=0} f' "$TRIPWIRES")"
  echo "$w4" | grep -q 'subagent-context.sh'
  # 閾値の再掲ではなく正本を指す（#261）。あわせて途中計測 hook の経路に触れていること
  echo "$w4" | grep -q 'decision-criteria.md'
  echo "$w4" | grep -q 'context-tripwire.sh'
  ! echo "$w4" | grep -q 'DEV_WORKFLOW_CONTEXT_CAP' || return 1
  echo "$w4" | grep -q 'モデルは変えない'
}

@test "tripwire template: wire 1 routes to return-to-main split or native Workflow execution, keeps heading and five wires" {
  grep -q '^## 昇格トリップワイヤー' "$TRIPWIRES"
  w1="$(awk '/^1\. /{f=1} /^2\. /{f=0} f' "$TRIPWIRES")"
  echo "$w1" | grep -q '規模超過'
  echo "$w1" | grep -q '本体に return'
  echo "$w1" | grep -q 'エピック化'
  echo "$w1" | grep -q 'workflow-execution.md'
  ! echo "$w1" | grep -q 'workflow 型へ' || return 1
  ! grep -qF '/lr:' "$TRIPWIRES" || return 1
  grep -q '失敗ループ' "$TRIPWIRES"
  grep -q '仕様の発明' "$TRIPWIRES"
  w3="$(awk '/^3\. /{f=1} /^4\. /{f=0} f' "$TRIPWIRES")"
  echo "$w3" | grep -q 'opsx:explore'
  [ "$(grep -cE '^[1-4]\. 【' "$TRIPWIRES")" -eq 4 ]
}

@test "tripwire template: unmanned wiring names the flatmate-owned constitution, not a loops template" {
  grep -q 'docs/agent-loop.md' "$TRIPWIRES"
  ! grep -q 'loop-dev-agent-tripwires' "$TRIPWIRES" || return 1
  ! grep -q 'loops プラグイン' "$TRIPWIRES" || return 1
}

# --- PR トークン上限（#288。spec: dev-workflow-pr-token-budget） ---

@test "token budget: SKILL.md has one section that measures before every spawn / SendMessage / Codex delegation" {
  s="$(section 'PR トークン上限')"
  [ -n "$s" ] || { echo "no PR トークン上限 section"; return 1; }
  echo "$s" | grep -qF 'scripts/pr-token-budget.sh'
  echo "$s" | grep -q 'spawn する直前'
  echo "$s" | grep -q 'SendMessage で再開する直前'
  echo "$s" | grep -q 'Codex executor へ委譲する直前'
  echo "$s" | grep -q '役割と executor を問わず毎回'
  # 1 ループの工程から参照されている
  sed -n '/^## 1 ループ/,/^## モデル/p' "$SKILL" | grep -q '「PR トークン上限」'
}

@test "token budget: exit 2 stops before spawn / SendMessage / Codex and asks continue-or-close with materials" {
  s="$(section 'PR トークン上限')"
  echo "$s" | grep -q 'exit 2'
  echo "$s" | grep -q 'spawn / SendMessage / Codex への委譲をしない'
  echo "$s" | grep -q 'needs-approval'
  echo "$s" | grep -qF '続けるか、範囲外として閉じるか'
  echo "$s" | grep -q '合計（Claude 分と Codex 分の内訳）・体数・上限・残工程'
  echo "$s" | grep -q '・推奨（どちらを選ぶかとその理由）'
  echo "$s" | grep -q 'unmanned'
}

@test "token budget: description carries the record number #N regardless of role" {
  s="$(section 'PR トークン上限')"
  echo "$s" | grep -q 'description'
  echo "$s" | grep -qF '`#N`'
  echo "$s" | grep -q '役割を問わない'
}

@test "token budget: Codex consumption is posted as a comment and gathered into --codex-records" {
  s="$(section 'PR トークン上限')"
  echo "$s" | grep -qF 'Codex 消費: <thread_id> <tokens>'
  echo "$s" | grep -qF 'usage.total.totalTokens'
  echo "$s" | grep -q '`usage` が null'
  echo "$s" | grep -qF 'scripts/codex-records.sh --repo <owner>/<repo> --out "<scratchpad>/codex-records.txt"'
  echo "$s" | grep -qF -- '--codex-records "<scratchpad>/codex-records.txt"'
  echo "$s" | grep -qF -- '--codex-home'
  echo "$s" | grep -qF '${CODEX_HOME:-$HOME/.codex}'
}

@test "token budget: a failed comment fetch skips the budget and is handled as exit 1" {
  s="$(section 'PR トークン上限')"
  echo "$s" | grep -qF 'if scripts/codex-records.sh'
  echo "$s" | grep -q 'pr-token-budget.sh` を呼ばず'
  echo "$s" | grep -q 'Codex 消費コメントを取得できなかった'
  echo "$s" | grep -q '空の記録や前回のファイルで代えない'
}

@test "token budget: continue raises the cap via a comment, close stops Codex too, exit 1 comments once per cycle" {
  s="$(section 'PR トークン上限')"
  echo "$s" | grep -qF 'PR トークン上限: <'
  echo "$s" | grep -qF -- '--cap <新上限>'
  echo "$s" | grep -q '範囲外として閉じる'
  echo "$s" | grep -q 'Codex にも委譲しない'
  echo "$s" | grep -q 'exit 1'
  echo "$s" | grep -q '1 サイクルに 1 回まで'
}

@test "token budget: measurement is not placed in the Codex adapter reference" {
  body="$(cat "${PLUGIN_DIR}/references/codex-develop.md")"
  refute "$body" -F 'pr-token-budget'
  refute "$(cat "${PLUGIN_DIR}/scripts/codex-worker.py")" -F 'pr-token-budget'
}

@test "token budget: gate-runner.md tells G to put the Codex thread_id in its return" {
  g="${SKILL_DIR}/references/roles/gate-runner.md"
  # return の共通欄は gate-runner.md、thread_id の取り方は G が Codex を呼ぶ段（stages/review-run.md）にある
  r="${PLUGIN_DIR}/skills/pr-review-gate/stages/review-run.md"
  grep -q 'thread_id' "$g"
  grep -q 'Codex thread' "$g"
  grep -q 'thread_id を return に書く' "$r"
  grep -qF 'session id:' "$r"
  grep -qF 'threadId' "$r"
}

# --- レビューの周を主に聞かずに続ける（直し方の判定。#722） ---

@test "fix-check (#722): the section sits between the token budget and the handover sections" {
  heads="$(grep -nE '^## ' "$SKILL")"
  b="$(echo "$heads" | grep -F '## PR トークン上限' | cut -d: -f1)"
  f="$(echo "$heads" | grep -F '## レビューの周を主に聞かずに続ける（直し方の判定）' | cut -d: -f1)"
  h="$(echo "$heads" | grep -F '## 保留で止まるときの引き継ぎ' | cut -d: -f1)"
  [ -n "$b" ] && [ -n "$f" ] && [ -n "$h" ] || { echo "missing section: $b / $f / $h"; return 1; }
  [ "$b" -lt "$f" ] && [ "$f" -lt "$h" ]
}

@test "fix-check (#722): the decider is asked with the verdict-and-reasons contract, not the 3 points" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  [ -n "$s" ] || { echo "no fix-check section"; return 1; }
  echo "$s" | grep -qF 'subagent_type: dev-workflow:decider'
  echo "$s" | grep -qF '可否と根拠'
  echo "$s" | grep -qF '3 点ではなく'
  echo "$s" | grep -qF 'agents/decider.md'
  # 定義の 3 条件
  echo "$s" | grep -qF '直し方が 1 つに決まる'
  echo "$s" | grep -qF '記録先の範囲'
  echo "$s" | grep -qF '前の周で「決まっている」と判定した直し方を当てたのに閉じなかった'
}

@test "fix-check (#722): the five inputs are fixed" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  for token in '記録先の本文と関連コメント' '残った指摘の原文' '前の周の指摘の原文' '対象ファイルのパス' 'W の直近の return'; do
    echo "$s" | grep -qF "$token" || { echo "missing input: $token"; return 1; }
  done
}

@test "fix-check (#722): first-line answers, one retry on shortage, then treated as re-choosing" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  for token in '`裁定: 可`' '`裁定: 否`' '`不足: <足りないもの>`' '1 回だけ依頼し直し' '3 回目の依頼はしない'; do
    echo "$s" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  echo "$s" | grep -F '1 回だけ依頼し直し' | grep -qF '選び直しが要る'
}

@test "fix-check (#722): the record format is defined here with its first line and fields" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  echo "$s" | grep -qF '`^直し方の判定: (決まっている|選び直しが要る)$`'
  for f in '対象' '周' '判定役' '指摘ごとの判定' '入力不足'; do
    echo "$s" | grep -qE "^\| ${f} \|" || { echo "record lacks field: $f"; return 1; }
  done
}

@test "fix-check (#722): the after-the-fact report format is defined here with its first line and fields" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  echo "$s" | grep -qF '`^主に聞かずに回した周: [0-9]+ 周目$`'
  for f in '残っていた指摘' '判定の根拠' '使ったトークン' '周の結果'; do
    echo "$s" | grep -qE "^\| ${f} \|" || { echo "report lacks field: $f"; return 1; }
  done
  # トークンの 2 つの値は既存の計測から取る
  echo "$s" | grep -qF '新しい計測の仕組みは足さない'
}

@test "fix-check (#722): only two conditions ask the owner" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  echo "$s" | grep -qF '方針の選び直し'
  echo "$s" | grep -qF '`pr-token-budget.sh` が exit 2'
  echo "$s" | grep -qF '2 つだけ'
  echo "$s" | grep -qF '回数に上限は置かない'
  echo "$s" | grep -qF '`2 周キャップ超え`'
}

@test "fix-check (#722): step (4) handles needs-fix-check by posting the record and starting the triage G" {
  step4="$(awk '/^\(4\) G を/{f=1} f&&/^```$/{exit} f' "$SKILL")"
  echo "$step4" | grep -qF 'needs-decider / needs-fix-check / review-incomplete'
  nf="$(echo "$step4" | awk '/^      needs-fix-check →/{f=1; print; next} f&&/^      [^ ]/{exit} f')"
  [ -n "$nf" ] || { echo "no needs-fix-check line in step (4)"; return 1; }
  for token in 'PR トークン上限' 'dev-workflow:decider' '判定の記録' '照合と振り分けの G を新しく起こ' 'レビューの周を主に聞かずに続ける（直し方の判定）' 'W も再開しない' '事後報告'; do
    echo "$nf" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
  # needs-fix-check の段落は needs-decider の段落の前に置く
  a="$(echo "$step4" | grep -n '^      needs-fix-check →' | cut -d: -f1)"
  d="$(echo "$step4" | grep -n '^      needs-decider →' | cut -d: -f1)"
  [ "$a" -lt "$d" ]
}

@test "fix-check (#722): the handover scene for the two-round cap points at the re-choosing verdict" {
  s="$(section '保留で止まるときの引き継ぎ')"
  echo "$s" | grep -F 'レビューの 2 周キャップ超え' | grep -qF '選び直しが要る'
  echo "$s" | grep -qF '`2 周キャップ超え`'
}

# --- #1035: 主の側にしか無い情報が要るときだけ主に聞く ---

@test "ask-owner (#1035): exactly one section names when to ask the owner and the four types" {
  [ "$(grep -c '^## 主に聞かずに決めること$' "$SKILL")" -eq 1 ]
  s="$(section '主に聞かずに決めること')"
  for token in '主の側にしか無い情報' '主の手でしかできない操作' '規則が主の承認を求める操作' \
               '自分側の誤りの後始末' '範囲外の問題の起票' '小さな実装の選択' '閉じる操作'; do
    echo "$s" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "ask-owner (#1035): cleanup of own mistakes reverts with a backup and excludes git and the sanctuary" {
  s="$(section '主に聞かずに決めること')"
  for token in '控えを取って戻し' '事後報告' 'git の破壊的操作' 'destructive-git-guard' '聖域'; do
    echo "$s" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "ask-owner (#1035): out-of-scope filing defines search, record, pending condition and epic note" {
  s="$(section '主に聞かずに決めること')"
  for token in 'triage.md' 'review-issue-candidates.sh' 'gh issue list' '`範囲外の問題の振り分け`' \
               '`条件の確認待ち`' '`## 条件の答え`' '注意書き' 'needs-approval'; do
    echo "$s" | grep -qF "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "ask-owner (#1035): a failed candidate search is recorded in the out-of-scope comment, not a PR comment" {
  s="$(section '主に聞かずに決めること')"
  echo "$s" | grep -F '候補探し:' | grep -qF '再試行後の終了コードは記録先の `範囲外の問題の振り分け` コメントに書き、既存 issue への相乗りをせずに段 E へ進む'
}

@test "ask-owner (#1035): both cleanup and filing carry a scope paragraph" {
  s="$(section '主に聞かずに決めること')"
  echo "$s" | grep -qF '自分側の誤りの後始末の守備範囲は'
  echo "$s" | grep -qF '範囲外の問題の起票の守備範囲は'
}

@test "ask-owner (#1035): fix-check definition 1 accepts choices that do not change visible behaviour" {
  s="$(section 'レビューの周を主に聞かずに続ける（直し方の判定）')"
  echo "$s" | grep -E '^1\. ' | grep -qF '利用者に見える振る舞い'
}

@test "ask-owner (#1035): loop end closes PR-less record issues without handing it to the owner" {
  s="$(section 'ループの終わり')"
  echo "$s" | grep -qF 'gh issue close <N> --reason completed'
  echo "$s" | grep -qF '主に渡さない'
  echo "$s" | grep -qF 'PR を伴わない記録先 issue を閉じたときを除く'
}

# --- Requirement: 親は主の答えに発言の場所を添えて送り、子は親の会話ログで確かめてからリスク許容として受け取る（#1059） ---
# 照合の対象は SKILL.md の文だけで、openspec の spec の文言は照合しない。

@test "relayed reply (#1059): Orca step 8 reports in the body, locates the uuid, and appends the location" {
  line="$(grep -E '^8\. `stopped <N>\.\.\.` で起こされたら' "$EPIC")"
  echo "$line" | grep -qF '本文で報告する（質問ツールで聞かない）'
  echo "$line" | grep -qF 'owner-reply-check.sh --locate "$CLAUDE_CODE_SESSION_ID" <主の答え>'
  echo "$line" | grep -qF ' [主の発言: セッション <親のセッション ID> / uuid <uuid>]'
  echo "$line" | grep -qF '書き換えず'
  echo "$line" | grep -qF '子のタブ'
}

@test "relayed reply (#1059): the child's 'reply from the parent' item checks with --relayed before handing to G" {
  item="$(grep -F -- '- **親から届いた返事**' "$EPIC_CHILD_STOP")"
  echo "$item" | grep -qF '[主の発言: セッション <ID> / uuid <uuid>]'
  echo "$item" | grep -qF 'owner-reply-check.sh --relayed <ID> <uuid> <作成日時> <URL>'
  echo "$item" | grep -qF '子のタブ'
  echo "$item" | grep -qF 'REASON='
  echo "$item" | grep -qF '「親経由で受領」'
}

@test "relayed reply (#1059): a relayed reply on a relaunch is handled before resume step 2 without the own session ID" {
  item="$(grep -F -- '- **親から届いた返事**' "$EPIC_CHILD_STOP")"
  echo "$item" | grep -qF '手順 2 より先に当て'
  echo "$item" | grep -qF '自分のセッション ID で `owner-reply-check.sh` に掛けない'
}

@test "relayed reply (#1059): the hold line refers to 'reply from the parent' for a child that got the acceptance via the parent" {
  line="$(grep -F 'リスク許容を会話で受けたら主に PR へのコメントを求めず' "$SKILL")"
  echo "$line" | grep -qF 'エピックの子が親経由で'
  echo "$line" | grep -qF '「親から届いた返事」'
}

@test "relayed reply (#1059): Orca step 8 compares the full text with whitespace collapsed and re-reports when another owner message sits in between" {
  line="$(grep -E '^8\. `stopped <N>\.\.\.` で起こされたら' "$EPIC")"
  echo "$line" | grep -qF '全文が主の答えと同じ（どちらも連続する空白を 1 個にまとめて比べる）'
  echo "$line" | grep -qF 'not-direct'
}

@test "relayed reply (#1059): a confirmed relayed refusal is taken as the owner's refusal" {
  item="$(grep -F -- '- **親から届いた返事**' "$EPIC_CHILD_STOP")"
  echo "$item" | grep -qF '全文から不許容の意思が読め'
  echo "$item" | grep -qF '主本人の不許容として受け取り'
  echo "$item" | grep -qF '許容とも不許容とも読めない'
}

@test "skill: step 7 of the Orca route re-presents children waiting for the owner before launch" {
  p="$(grep -E '^7\. `回し方: Orca`' "$EPIC")"
  printf '%s\n' "$p" | grep -qF 'pending-owner'
  printf '%s\n' "$p" | grep -qF '記録の `stop` が `stopped-seen`'
  printf '%s\n' "$p" | grep -qF '手順 8 と同じに扱い（照らして通すか、報告を本文で出し直す）'
  printf '%s\n' "$p" | grep -qF '子 issue のコメントの新旧では再開を判定しない'
}

@test "reply-after-idle: the restore table has the child waiting for the owner" {
  f="$PLUGIN_DIR/skills/develop/references/reply-after-idle.md"
  row="$(grep -E '^\| 主の返事待ちの子 \|' "$f")"
  printf '%s\n' "$row" | grep -qF '記録の `stop` が `stopped-seen`'
  printf '%s\n' "$row" | grep -qF '子の停止: 主の返事待ち'
  printf '%s\n' "$row" | grep -qF '親の判断:'
}

@test "reply-after-idle: wait --resolve decides the relaunch itself with overridable thresholds" {
  f="$PLUGIN_DIR/skills/develop/references/reply-after-idle.md"
  grep -qF 'EPIC_DISPATCH_RELAUNCH_IDLE_SEC' "$f"
  grep -qF 'EPIC_DISPATCH_RELAUNCH_MIN_TOKENS' "$f"
}

@test "skill: step 7 drops a pending child whose pass on the epic matches the latest stop record" {
  p="$(grep -E '^7\. `回し方: Orca`' "$EPIC")"
  printf '%s\n' "$p" | grep -qF 'エピックのコメントの `親の判断: 子 #N 通した`'
  printf '%s\n' "$p" | grep -qF '停止の記録の URL が子の最新の `子の停止: 主の返事待ち` の URL と一致'
  printf '%s\n' "$p" | grep -qF '再報告から外す'
  row="$(grep -E '^\| 主の返事待ちの子 \|' "$PLUGIN_DIR/skills/develop/references/reply-after-idle.md")"
  printf '%s\n' "$row" | grep -qF '`親の判断: 子 #N 通した`'
}

@test "skill: an empty return from W asks for a report once and never relaunches with the same instruction (#1117)" {
  # spec: dev-workflow-develop「空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない」
  p="$(section '1 ループ' | grep -F 'returned no output')"
  [ -n "$p" ]
  [ "$(printf '%s\n' "$p" | wc -l | tr -d ' ')" = 1 ]
  printf '%s\n' "$p" | grep -qF 'SendMessage で 1 回だけ報告を求める'
  printf '%s\n' "$p" | grep -qF 'git -C <path> status --porcelain'
  printf '%s\n' "$p" | grep -qF '同じ指示で起こし直さない'
  printf '%s\n' "$p" | grep -qF '主に上げる'
  # 再報告が空のときも起こし直さない
  printf '%s\n' "$p" | grep -qF '1 回求めても報告が空'
  # 対象は W だけ。再開しない役は範囲外で既存の手順に従う
  printf '%s\n' "$p" | grep -qF '再開しない役'
  printf '%s\n' "$p" | grep -qF '範囲外'
}

# --- 別のリポジトリの子（cross-repo-children） ---
# spec: dev-workflow-develop「別のリポジトリの子を含むエピックの回し方を SKILL.md に書く」

xrepo_block() { section 'エピックの扱い' "$EPIC" | awk '/^\*\*別のリポジトリの子（複数リポジトリのエピック）\*\*/{f=1; print; next} /^子セッションは `launch` が/{f=0} f'; }

@test "skill (cross-repo): dependencies and sub-issue checks are read in the child's repository, the prerequisite's from repository_url" {
  b="$(xrepo_block)"
  [ -n "$b" ]
  printf '%s\n' "$b" | grep -qF 'repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by'
  printf '%s\n' "$b" | grep -qF 'repository_url'
  printf '%s\n' "$b" | grep -qF 'sub_issues_summary.total'
  printf '%s\n' "$b" | grep -qF '解けていないものとして待つ'
}

@test "skill (cross-repo): the child list is built from sub-issues and the epic's table, counting a child once" {
  b="$(xrepo_block)"
  printf '%s\n' "$b" | grep -qF 'sub_issues'
  printf '%s\n' "$b" | grep -qF 'エピック本文の子の表'
  printf '%s\n' "$b" | grep -qF '1 件に数える'
}

@test "skill (cross-repo): read targets are the child's repository (step 3 b, 4, 8, merge-waiting child, deferral match)" {
  b="$(xrepo_block)"
  printf '%s\n' "$b" | grep -qF '手順 3 (b) の起点ブランチ'
  printf '%s\n' "$b" | grep -qF '記録の `base`'
  printf '%s\n' "$b" | grep -qF 'repos/<子の owner>/<子の repo>/issues/<N> --jq .state_reason'
  printf '%s\n' "$b" | grep -qF 'repos/<子の owner>/<子の repo>/issues/<N>/comments'
  printf '%s\n' "$b" | grep -qF '照合も `<owner>/<repo>#N` の形の行'
}

@test "skill (cross-repo): children are passed to every subcommand as <owner>/<repo>#N" {
  b="$(xrepo_block)"
  printf '%s\n' "$b" | grep -qF '`route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt`'
  printf '%s\n' "$b" | grep -qF '`<owner>/<repo>#N` の形で渡す'
}

@test "skill (cross-repo): the subagent route does not hand a child in another repository to W" {
  s="$(section 'エピックの扱い' "$EPIC" | grep -F '**サブエージェント方式**')"
  printf '%s\n' "$s" | grep -qF '別のリポジトリの子は W に渡さない'
  printf '%s\n' "$s" | grep -qF '子 <owner>/<repo>#N は別のリポジトリなので別セッション方式でだけ起動する'
  printf '%s\n' "$s" | grep -qF '起こさずに、主に報告する'
}

@test "skill (cross-repo): comment formats for a child in another repository are written, the same-repository ones stay" {
  b="$(xrepo_block)"
  printf '%s\n' "$b" | grep -qF '後で別に起動するエピック: <owner>/<repo>#N'
  printf '%s\n' "$b" | grep -qF '親の判断: 子 <owner>/<repo>#N 通した'
  e="$(section 'エピックの扱い' "$EPIC")"
  printf '%s\n' "$e" | grep -qF '`後で別に起動するエピック: #N`'
  printf '%s\n' "$e" | grep -qF '`子 #N マージ → 残り k 件`'
}

@test "skill (cross-repo): the merge-waiting child works on the child's repository and escalates without permission there" {
  b="$(xrepo_block)"
  printf '%s\n' "$b" | grep -qF 'gh pr comment <PR> -R <子の repo>'
  printf '%s\n' "$b" | grep -qF 'gh api repos/<子の repo>/issues/<PR番号>/labels'
  printf '%s\n' "$b" | grep -qF '決める役を起こさず手順 8 の形で主に上げる'
}

@test "skill (cross-repo): a nested session comments on the epic's repository with -R" {
  n="$(section 'エピックの扱い' "$EPIC" | grep -F '**`nested` を受けたセッション**')"
  printf '%s\n' "$n" | grep -qF "gh issue comment <E> -R <エピックのリポジトリ>"
  printf '%s\n' "$n" | grep -qF '後で別に起動するエピック: <自分の owner>/<自分の repo>#<自分>'
  printf '%s\n' "$n" | grep -qF 'parent epic: <owner>/<repo>#<E>'
}

@test "skill (cross-repo): the child side and ci-watch accept the reply heads with (<owner>/<repo>)" {
  c="$(section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP")"
  printf '%s\n' "$c" | grep -qF '親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: '
  printf '%s\n' "$c" | grep -qF '主の返事（親エピック #<E>（<owner>/<repo>）経由）: '
  w="$(grep -F '親エピック #<E> の判断（主の承認ではない）:' "$PLUGIN_DIR/references/ci-watch.md")"
  printf '%s\n' "$w" | grep -qF '親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）:'
}

@test "skill (cross-repo): step 6 reports the new failed reasons and stops, step 1 warns about --base across repositories" {
  s6="$(section 'エピックの扱い' "$EPIC" | grep -F '6. `wait` の')"
  for r in no-clone ambiguous-clone not-in-orca no-push permission-lookup-failed base-lookup-failed; do
    printf '%s\n' "$s6" | grep -qF "$r" || { echo "missing: $r"; false; }
  done
  printf '%s\n' "$s6" | grep -qF 'サブエージェント方式に自動で振り替えない'
  s1="$(section 'エピックの扱い' "$EPIC" | grep -F '1. `scripts/epic-dispatch.sh launch')"
  printf '%s\n' "$s1" | grep -qF '1 回の `launch` の全部の子に掛かる'
  printf '%s\n' "$s1" | grep -qF '`launch` をリポジトリごとに分ける'
}

@test "skill: a denial report from W is handled by writing a permit and resuming, or escalating to the owner (#1135)" {
  # spec: dev-workflow-develop「破壊的 git 操作の拒否の報告を受けたら、条件を満たすときだけ許可を書いて再開し、それ以外はオーナーに上げる」
  p="$(section '1 ループ' | grep -F 'returned no output')"
  [ -n "$p" ]
  [ "$(printf '%s\n' "$p" | wc -l | tr -d ' ')" = 1 ]
  # 報告の 4 項目
  for t in 'コマンドの全文' '対象のパス' '自分で作った' 'なぜ'; do
    printf '%s\n' "$p" | grep -qF "$t" || { echo "missing $t"; return 1; }
  done
  # 許可を書く条件
  printf '%s\n' "$p" | grep -qF 'git-guard-permit.sh'
  printf '%s\n' "$p" | grep -qF 'scratchpad の中'
  printf '%s\n' "$p" | grep -qF '戻す'
  printf '%s\n' "$p" | grep -qF 'git を実行しない'
  # cwd と操作対象を同一視せず、-C の例を扱う
  printf '%s\n' "$p" | grep -qF 'cwd'
  printf '%s\n' "$p" | grep -qF 'git -C'
  # 再開
  printf '%s\n' "$p" | grep -qF '同じ W を SendMessage で再開'
  printf '%s\n' "$p" | grep -qF '1 文字も変えず'
  printf '%s\n' "$p" | grep -qF '15 分'
  printf '%s\n' "$p" | grep -qF 'hook が決める'
  printf '%s\n' "$p" | grep -qF 'コンテキスト上限（サブエージェントの手渡し）'
  printf '%s\n' "$p" | grep -qF '転用しない'
  # オーナーに上げる条件
  printf '%s\n' "$p" | grep -qF '0 以外で終わった'
  printf '%s\n' "$p" | grep -qF '再び返った'
  printf '%s\n' "$p" | grep -qF 'オーナーが自分で実行'
}

# --- 起動部品の差し替え（epic-launcher-tmux） ---
# spec: dev-workflow-develop（回し方は起動部品の差し替えとして 1 本で書く）

run_section() { section 'エピックの扱い' "$EPIC" | awk '/^### 回し方/{f=1} /^### 完了条件/{f=0} f'; }

@test "launcher parts: the run section is one procedure with a per-part table and no Orca-route heading" {
  r="$(run_section)"
  [ "$(printf '%s\n' "$r" | grep -c '^\*\*部品ごとの欄\*\*')" -eq 1 ]
  printf '%s\n' "$r" | grep -qF '| 点 | Orca の部品'
  printf '%s\n' "$r" | grep -qF 'tmux の部品'
  [ "$(printf '%s\n' "$r" | grep -c '^\*\*Orca 経路\*\*')" -eq 0 ]
  [ "$(grep -c 'Orca 経路' "$SKILL")" -eq 0 ]
  # 手順 1〜8 は 1 本だけ
  [ "$(printf '%s\n' "$r" | grep -cE '^[1-8]\. ')" -eq 8 ]
}

@test "launcher parts: the subagent mode writes no state record" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF 'サブエージェント方式は部品ではなく別の方式なので状態の記録を書かない'
}

@test "launcher parts: EPIC_DISPATCH_LAUNCHER and tmux are written in the route rule" {
  r="$(run_section | grep -F '**経路の決め方**')"
  printf '%s\n' "$r" | grep -qF 'EPIC_DISPATCH_LAUNCHER=orca'
  printf '%s\n' "$r" | grep -qF '`tmux`（Orca 管理外で'
  printf '%s\n' "$r" | grep -qF '`回し方: tmux（並列可能な子 k 件）`'
}

@test "launcher parts: resuming passes the part named in the latest note and stops if it is unusable" {
  r="$(run_section | grep -F '**経路の決め方**')"
  printf '%s\n' "$r" | grep -qF '`launch` と `adopt` に環境変数 `EPIC_DISPATCH_LAUNCHER=<そのコメントの部品名'
  printf '%s\n' "$r" | grep -qF '別の部品にもサブエージェント方式にも振り替えず'
  printf '%s\n' "$r" | grep -qF '部品名を渡さない'
  p="$(grep -E '^7\. `回し方: Orca`' "$EPIC")"
  printf '%s\n' "$p" | grep -qF '`回し方: tmux`'
  printf '%s\n' "$p" | grep -qF 'EPIC_DISPATCH_LAUNCHER=<部品名>'
}

@test "launcher parts: the kept-removal operation is per part and neither uses force" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF 'epic-launch-tmux.sh remove <path>'
  # orca のコマンドの文字列は手順 3 の 1 か所だけに書く（orca のコマンドの書き方の要件）ので、部品の欄は参照で書く
  printf '%s\n' "$r" | grep -qF 'Orca の worktree を消す（`--force` なし。コマンドは手順 3 に書いた）'
  printf '%s\n' "$r" | grep -F '3. `done <N>...`' | grep -qF '`orca worktree rm --worktree path:<path>`'
  p="$(printf '%s\n' "$r" | grep -F '3. `done <N>...`')"
  printf '%s\n' "$p" | grep -qF '部品の欄の操作'
  printf '%s\n' "$p" | grep -qF 'どちらも `--force` なし'
}

@test "launcher parts: a tmux epic is not told to reopen in the Orca parent worktree" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF 'tmux の部品では出ない'
  printf '%s\n' "$r" | grep -qF '開き直しを案内しない'
}

@test "launcher parts: the prerequisite table names orca or tmux for starting child sessions" {
  grep -qF '| **`orca`** または **`tmux`** |' "$SKILL"
}
