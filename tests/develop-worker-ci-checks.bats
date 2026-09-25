#!/usr/bin/env bats
# issue #508: (3a) の検査指示と return 契約を固定する。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  WORKER="$REPO_ROOT/plugins/dev-workflow/skills/develop/references/roles/worker.md"
}

common_principles() {
  awk '$0 == "**全経路共通の大原則**:" {printing=1; next} /^\*\*G から一覧を求められた指摘/ {printing=0} printing' "$WORKER"
}

return_contract() {
  awk '/^\*\*\(3a\) の return に書くこと/ {printing=1; next} /^## \(3b\)/ {printing=0} printing' "$WORKER"
}

@test "all (3a) paths read PR and push workflow checks" {
  section="$(common_principles)"
  [[ "$section" == *'.github/workflows/'* ]] || return 1
  [[ "$section" == *'*.yml'* && "$section" == *'*.yaml'* ]] || return 1
  [[ "$section" == *'pull_request'* && "$section" == *'push'* ]] || return 1
  [[ "$section" == *'run:'* && "$section" == *'収集してすべて実行'* ]] || return 1
  [[ "$section" == *'sudo apt-get install'* && "$section" == *'環境セットアップ'* ]] || return 1
  [[ "$section" == *'フォールバック'* && "$section" == *'未導入'* ]] || return 1
}

@test "worker states the scope and its known limits" {
  section="$(common_principles)"
  [[ "$section" == *'PR #489'* && "$section" == *'shellcheck'* ]] || return 1
  [[ "$section" == *'matrix'* && "$section" == *'services'* && "$section" == *'env'* && "$section" == *'if:'* ]] || return 1
  [[ "$section" == *'ランナー依存'* && "$section" == *'誤実行'* ]] || return 1
  [[ "$section" == *'完了条件にしない'* && "$section" == *'G'* ]] || return 1
}

@test "return lists collected checks and each result without treating missing tools as success" {
  section="$(return_contract)"
  [[ "$section" == *'収集した検査コマンド'* && "$section" == *'各 exit code'* ]] || return 1
  [[ "$section" == *'未導入'* && "$section" == *'合格扱いしない'* ]] || return 1
  [[ "$section" == *'openspec validate'* ]] || return 1
}
