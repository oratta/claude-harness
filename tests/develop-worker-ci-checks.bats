#!/usr/bin/env bats
# issue #508: (3a) の検査指示と return 契約を固定する。
# issue #1211: テストの全体実行は手元で回さず CI に任せる（作業者・レビュアー・ゲートの担当）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  WORKER="$REPO_ROOT/plugins/dev-workflow/skills/develop/references/roles/worker/implement.md"
  REVIEWER_BRIEF="$REPO_ROOT/plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md"
  PASS="$REPO_ROOT/plugins/dev-workflow/skills/pr-review-gate/stages/pass.md"
}

common_principles() {
  awk '$0 == "**全経路共通の大原則**:" {printing=1; next} /^\*\*G から一覧を求められた指摘/ {printing=0} printing' "$WORKER"
}

return_contract() {
  awk '/^\*\*\(3a\) の return に書くこと/ {printing=1; next} /^## \(3b\)/ {printing=0} printing' "$WORKER"
}

reviewer_stance() {
  awk '/^#### 2-1\. / {printing=1; next} /^\*\*レビュアー向け指示ブロック\*\*/ {printing=0} printing' "$REVIEWER_BRIEF"
}

pass_step4() {
  awk '/^### 4\. 動作確認/ {printing=1; next} /^### 5\. / {printing=0} printing' "$PASS"
}

human_merge_paragraph() {
  awk 'BEGIN {RS=""} /マージは人間の操作待ち/' "$PASS"
}

@test "all (3a) paths read PR and push workflow checks" {
  section="$(common_principles)"
  [[ "$section" == *'.github/workflows/'* ]] || return 1
  [[ "$section" == *'*.yml'* && "$section" == *'*.yaml'* ]] || return 1
  [[ "$section" == *'pull_request'* && "$section" == *'push'* ]] || return 1
  [[ "$section" == *'run:'* ]] || return 1
  [[ "$section" != *'収集してすべて実行'* ]] || return 1
  [[ "$section" == *'sudo apt-get install'* && "$section" == *'環境セットアップ'* ]] || return 1
  [[ "$section" == *'フォールバック'* && "$section" == *'未導入'* ]] || return 1
}

@test "worker runs static checks locally and leaves the full test run and build to CI" {
  section="$(common_principles)"
  [[ "$section" == *'静的検査'* && "$section" == *'手元で実行する'* ]] || return 1
  [[ "$section" == *'テストの全体実行'* && "$section" == *'ビルド'* && "$section" == *'CI に任せる'* ]] || return 1
  [[ "$section" == *'手元で実行しない'* ]] || return 1
}

@test "worker selects related tests by changed files" {
  section="$(common_principles)"
  [[ "$section" == *'関係するテスト'* ]] || return 1
  [[ "$section" == *'足した・変えたテスト'* ]] || return 1
  [[ "$section" == *'パスかファイル名'* && "$section" == *'git grep -l'* ]] || return 1
  [[ "$section" == *'テストランナー'* && "$section" == *'選ぶ機能'* ]] || return 1
  [[ "$section" == *'log-failed'* ]] || return 1
}

@test "worker runs the full test locally only when no CI job runs it" {
  section="$(common_principles)"
  [[ "$section" == *'全体のテストを回すジョブが無い'* && "$section" == *'手元で全体を実行する'* ]] || return 1
  [[ "$section" == *'Draft'* ]] || return 1
}

@test "worker names scripts/test.sh only as a fallback example" {
  run bash -c "awk '\$0 == \"**全経路共通の大原則**:\" {p=1; next} /^\\*\\*G から一覧を求められた指摘/ {p=0} p' '$WORKER' | grep -F 'scripts/test.sh' | grep -vF 'フォールバック'"
  [ "$status" -eq 1 ]
}

@test "worker states the scope and its known limits" {
  section="$(common_principles)"
  [[ "$section" == *'PR #489'* && "$section" == *'shellcheck'* ]] || return 1
  [[ "$section" == *'matrix'* && "$section" == *'services'* && "$section" == *'`env`'* && "$section" == *'if:'* ]] || return 1
  [[ "$section" == *'ランナー依存'* && "$section" == *'誤実行'* ]] || return 1
  [[ "$section" == *'完了条件にしない'* && "$section" == *'G が pr-review-gate 手順 4 で対象 HEAD の CI の結果'* ]] || return 1
  [[ "$section" == *'変えたファイルの一覧'* ]] || return 1
  [[ "$section" == *'間接的に読むテスト'* ]] || return 1
  [[ "$section" == *'CI の見張り'* && "$section" == *'ci-watch.md'* ]] || return 1
  [[ "$section" != *'G による CI 結果の確認'* ]] || return 1
}

@test "return lists collected checks and each result without treating missing tools as success" {
  section="$(return_contract)"
  [[ "$section" == *'収集した検査コマンド'* && "$section" == *'各 exit code'* ]] || return 1
  [[ "$section" == *'未導入'* && "$section" == *'合格扱いしない'* ]] || return 1
  [[ "$section" == *'openspec validate'* ]] || return 1
  [[ "$section" == *'関係するテストを探したコマンド'* ]] || return 1
  [[ "$section" == *'CI に任せた検査'* && "$section" == *'ジョブ名'* ]] || return 1
  [[ "$section" != *'フルテストを回し直す'* ]] || return 1
}

@test "reviewer reruns only related tests and lint and uses worker or CI evidence for the full run" {
  section="$(reviewer_stance)"
  [[ "$section" == *'報告を信用せず自分で再実行'* ]] || return 1
  [[ "$section" == *'関係するテスト'* && "$section" == *'lint'* ]] || return 1
  [[ "$section" == *'全体のテストは手元で回さない'* ]] || return 1
  [[ "$section" == *'作業者の結果か CI の結果'* ]] || return 1
  [[ "$section" == *'証拠が無いこと'* && "$section" == *'要約'* ]] || return 1
}

@test "gate uses the CI result of the target HEAD for the full test run" {
  section="$(pass_step4)"
  [[ "$section" == *'テストの全体実行を手元で行わない'* ]] || return 1
  [[ "$section" == *'対象 HEAD の CI の結果'* && "$section" == *'gh pr checks'* ]] || return 1
  [[ "$section" == *'結論がまだ無い'* && "$section" == *'CI の見張り'* ]] || return 1
  [[ "$section" == *'失敗した run の URL'* ]] || return 1
  [[ "$section" == *'成功として書かない'* ]] || return 1
  [[ "$section" == *'作業者が PR に載せた証拠'* ]] || return 1
  [[ "$section" == *'「テストが通った」だけは証拠にならない'* ]] || return 1
}

@test "human-merge note carries the CI state when CI is failing or undecided" {
  section="$(human_merge_paragraph)"
  [[ -n "$section" ]] || return 1
  [[ "$section" == *'CI の状態'* ]] || return 1
  [[ "$section" == *'失敗か未決着'* ]] || return 1
  [[ "$section" == *'見張りが結論を出すまでマージしない'* ]] || return 1
}
