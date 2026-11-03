#!/usr/bin/env bats
# エピックの親が human-merge の付いた子の PR を基準で判断し、判断の印を付ける手順（#1054）の文書を確かめる。
#
# spec: dev-workflow-develop（Orca 経路の親はマージ待ちの子の PR を基準で判断し、通せるものに判断の印を付ける／
#       親がマージに回してよい子の PR の基準を 1 つのファイルに置く／エピックの条件・作り方・回し方・完了条件を規定する）
#       dev-workflow-ci-watch（エピックの子は聖域接触だけの human-merge で親の判断を待つ）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  # エピックの 2 節は SKILL.md から references/ へ移した（#1219）
  EPIC="${PLUGIN_DIR}/skills/develop/references/epic.md"
  EPIC_CHILD_STOP="${PLUGIN_DIR}/skills/develop/references/epic-child-stop.md"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/parent-merge-criteria.md"
  PASS_CRITERIA="${PLUGIN_DIR}/skills/develop/references/parent-pass-criteria.md"
  CI_WATCH="${PLUGIN_DIR}/references/ci-watch.md"
  OPS="${PLUGIN_DIR}/references/commit-and-pr-operations.md"
}

# 第 2 引数で読むファイルを変えられる（既定は SKILL.md）
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "${2:-$SKILL}"; }
run_section() { section 'エピックの扱い' "$EPIC" | awk '/^### 回し方/{f=1; print; next} /^### /{f=0} f'; }
# 「回し方」の中の、マージ待ちの子の段落（`**マージ待ちの子**` で始まる段落から次の空行まで）
merge_para() { run_section | awk '/^\*\*マージ待ちの子\*\*/{f=1} f && /^$/{exit} f'; }
# ci-watch.md の「`ready` を受けたあと」の節
ready_section() { awk '/^### `ready` を受けたあと/{f=1; print; next} /^#+ /{f=0} f' "$CI_WATCH"; }

# --- 基準のファイル ---

@test "criteria: parent-merge-criteria.md has the six conditions and escalates when unsure" {
  [ -f "$CRITERIA" ]
  for c in '見送りが聖域接触だけ' 'ゲートが今の HEAD で済んでいる' '主の側の情報が要らない' '範囲の内側' '戻せる' '配役表で主の観点が無い'; do
    grep -qF -- "| $c |" "$CRITERIA" || { echo "missing condition: $c"; return 1; }
  done
  grep -qF '**迷ったとき**' "$CRITERIA"
  grep -qF '判断できなければ「主に上げる」' "$CRITERIA"
}

@test "criteria: output is the verdict line with a reason line" {
  grep -qxF '裁定: 可' "$CRITERIA"
  grep -qF '`裁定: 否`' "$CRITERIA"
  grep -qF '`不足: <足りないもの>`' "$CRITERIA"
  grep -qF '理由: <1 行>' "$CRITERIA"
}

@test "criteria: maps each condition to parent-pass-criteria.md and leaves the merge to the auto-merge workflow" {
  grep -qF 'parent-pass-criteria.md' "$CRITERIA"
  grep -qF '既存の規則が主に聞く止まりでない' "$CRITERIA"
  grep -qF '聖域でない' "$CRITERIA"
  grep -qF 'マージを実行するのは自動マージの処理' "$CRITERIA"
}

@test "criteria: parent-pass-criteria.md does not gain the merge conditions" {
  ! grep -qF '裁定:' "$PASS_CRITERIA" || return 1
  grep -qF 'PR のマージの可否は、この基準で通さない' "$PASS_CRITERIA"
}

# --- develop の SKILL.md ---

@test "skill: the old no-auto-merge sentence is gone and direct merges stay forbidden" {
  ! grep -qF '本体は自動でマージしない' "$SKILL" || return 1
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F '直接マージしない' | grep -qF 'gh pr merge'
}

@test "skill: the merge-wait paragraph sits in the Orca procedure and runs before step 8 escalates" {
  p="$(merge_para)"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -qF '今回の止まった理由が `PR のマージ待ち（` で始まる'
  printf '%s\n' "$p" | grep -qF '一致する `親の判断:` が無い'
  printf '%s\n' "$p" | grep -qF '手順 8'
}

@test "skill: the merge-wait paragraph lists the four preconditions on the PR's base branch" {
  p="$(merge_para)"
  printf '%s\n' "$p" | grep -qF 'contents/.github/workflows/auto-merge.yml?ref=<PR の base ブランチ>'
  printf '%s\n' "$p" | grep -qF 'parent-merge-approved'
  printf '%s\n' "$p" | grep -qF '`human-merge` だけ'
  printf '%s\n' "$p" | grep -qF '最初に現れる `Closes #N`・`Fixes #N`・`Refs #N`'
  printf '%s\n' "$p" | grep -qF 'トラブルシュートの項目 10'
}

@test "skill: the merge-wait paragraph has the decider judge with the criteria and the pasted inputs" {
  p="$(merge_para)"
  printf '%s\n' "$p" | grep -qF 'dev-workflow:decider'
  printf '%s\n' "$p" | grep -qF 'references/parent-merge-criteria.md'
  printf '%s\n' "$p" | grep -qF '# >>> sacred-paths'
  printf '%s\n' "$p" | grep -qF '# <<< merge-condition-paths'
  printf '%s\n' "$p" | grep -qF 'auto-merge 対象外（聖域パス接触）'
}

@test "skill: on approval the parent rechecks HEAD, comments before labeling, replies and records" {
  p="$(merge_para)"
  printf '%s\n' "$p" | grep -qF 'headRefOid'
  printf '%s\n' "$p" | grep -qF '親のマージ判断: 可'
  printf '%s\n' "$p" | grep -qF '親が見た HEAD: <40 桁 SHA>'
  printf '%s\n' "$p" | grep -qF 'コメントを先に'
  printf '%s\n' "$p" | grep -qF 'epic-dispatch.sh reply --as parent'
  printf '%s\n' "$p" | grep -qF '親の判断: 子 #N マージに回した'
}

@test "skill: only the parent marks, and marks count only from an OWNER/MEMBER/COLLABORATOR account" {
  p="$(merge_para)"
  printf '%s\n' "$p" | grep -qF '子は付けない'
  printf '%s\n' "$p" | grep -qF 'OWNER・MEMBER・COLLABORATOR'
  printf '%s\n' "$p" | grep -qF '否・不足'
}

# --- ci-watch.md ---

@test "ci-watch: an epic child with only human-merge records a merge-wait stop instead of asking the owner" {
  r="$(ready_section)"
  printf '%s\n' "$r" | grep -qF '`nested`'
  printf '%s\n' "$r" | grep -qF '止まった理由: PR のマージ待ち（human-merge）: <PR の URL>'
  printf '%s\n' "$r" | grep -qF 'contents/.github/workflows/auto-merge.yml?ref=<PR の base ブランチ>'
  for k in '聖域のどのパス' 'ゲートの合格の HEAD' '親の判断で自動マージの処理に回す' '今の HEAD の SHA'; do
    printf '%s\n' "$r" | grep -qF -- "$k" || { echo "missing content: $k"; return 1; }
  done
  ! printf '%s\n' "$r" | grep -qF '残りの 6 項目' || return 1
  printf '%s\n' "$r" | grep -F '決まりで主の承認が要る' | grep -qF '聖域のファイルに触れた PR'
  # 従来のオーナーへの依頼の文は残る（ci-watch.bats が見ている）
  printf '%s\n' "$r" | grep -qF '待たずに PR の URL を添えてオーナーにマージを頼み'
}

@test "ci-watch: after the parent's reply the child watches with --until-merged and never marks" {
  r="$(ready_section)"
  printf '%s\n' "$r" | grep -qF '親エピック #<E> の判断（主の承認ではない）:'
  printf '%s\n' "$r" | grep -F 'until-merged' | grep -qF 'run_in_background'
  printf '%s\n' "$r" | grep -qF 'PR のマージ待ち（human-merge、親の返事のあともマージされない）'
  printf '%s\n' "$r" | grep -qF '子は `parent-merge-approved` ラベルも `親のマージ判断:` のコメントも付けない'
  ! printf '%s\n' "$r" | grep -qF '親の判断の印のあともマージされない' || return 1
}

# --- commit-and-pr-operations.md ---

@test "ops: the only-merge-path paragraph mentions the parent's merge judgment" {
  p="$(grep -F '唯一のマージ経路' "$OPS")"
  printf '%s\n' "$p" | grep -qF 'parent-merge-approved'
  printf '%s\n' "$p" | grep -qF '親のマージ判断: 可'
  printf '%s\n' "$p" | grep -qF 'human-merge'
}

# --- ゲート一周目の指摘（#1067） ---

@test "ci-watch: after the parent's reply the child checks for a duplicate watch and posts a start comment before --until-merged" {
  line="$(ready_section | grep -F '親エピック #<E> の判断（主の承認ではない）:')"
  [ -n "$line" ]
  printf '%s\n' "$line" | grep -qF '上の 2 の重複の確認'
  printf '%s\n' "$line" | grep -qF '`CI 見張り開始:` のコメントの投稿をしてから、`ci-watch.sh wait <owner/repo> <PR番号> --until-merged`'
}

@test "skill: re-approving a new HEAD removes the stale parent-merge-approved label before commenting and labeling" {
  p="$(merge_para)"
  printf '%s\n' "$p" | grep -qF '古い HEAD の判断で付けた `parent-merge-approved` が PR に残っていれば先に外し'
  printf '%s\n' "$p" | grep -qF 'gh api -X DELETE "repos/<owner>/<repo>/issues/<PR番号>/labels/parent-merge-approved"'
  # 外す → HEAD の取り直し → コメント → ラベルの順
  printf '%s\n' "$p" | awk '{
    a=index($0,"labels/parent-merge-approved"); b=index($0,"headRefOid` で取り直して"); c=index($0,"1 行目 `親のマージ判断: 可`"); d=index($0,"投稿してから `parent-merge-approved` ラベルを付ける")
    if (a && b && c && d && a<b && b<c && c<d) ok=1
  } END { exit ok ? 0 : 1 }'
}
