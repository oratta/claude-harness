#!/usr/bin/env bats
#
# product-handover プラグインの構造テスト（issue #206）
#
# agent-owner を product-handover に作り直す変更の受け入れ条件を固定する:
#   (a) 旧 plugins/agent-owner/ が消えていること
#   (b) product-handover が「法務ドラフト・サポート窓口・教訓ログ」の雛形と
#       README / plugin.json だけで構成されること（オーケストレーターを持たない）
#   (c) marketplace.json が product-handover に差し替わり agent-owner を含まないこと
#   (d) 旧名の参照が repo に残っていないこと。例外は2つだけで、移行手順を書く
#       CHANGELOG.md と、その不在を検査する本テスト自身
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
  TPL="${PLUGIN_DIR}/templates"
}

# --- (a) 旧プラグインの削除 ---

@test "old plugins/agent-owner directory is gone" {
  [ ! -e "${REPO_ROOT}/plugins/agent-owner" ]
}

# --- (b) 新プラグインの構成 ---

@test "plugin.json parses, name is product-handover, version is semver" {
  local pj="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  [ -f "$pj" ]
  run jq . "$pj"
  [ "$status" -eq 0 ]
  [ "$(jq -r .name "$pj")" = "product-handover" ]
  jq -r .version "$pj" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "README.md exists" {
  [ -f "${PLUGIN_DIR}/README.md" ]
}

@test "legal draft templates exist (terms, privacy, refund)" {
  [ -f "${TPL}/legal/terms.md" ]
  [ -f "${TPL}/legal/privacy-policy.md" ]
  [ -f "${TPL}/legal/refund-policy.md" ]
}

@test "legal drafts are marked as pre-review drafts" {
  for f in terms privacy-policy refund-policy; do
    grep -q "ドラフト" "${TPL}/legal/${f}.md"
  done
}

@test "support desk template exists" {
  [ -f "${TPL}/support-desk.md" ]
}

@test "autonomy lessons template exists" {
  [ -f "${TPL}/autonomy-lessons-skeleton.md" ]
}

@test "no orchestrator skill remains" {
  [ ! -d "${PLUGIN_DIR}/skills" ]
  run jq -e '.skills' "${PLUGIN_DIR}/.claude-plugin/plugin.json"
  [ "$status" -ne 0 ]
}

@test "no dependency on the loops dev-agent-install command" {
  # 検査するのは「現に依存しているか」なので、稼働する部品（雛形・plugin.json・README）だけを見る。
  # tests/ と CHANGELOG.md は依存を外したこと自体を記録するため旧コマンド名を持つ。
  run bash -c "grep -rn 'dev-agent-install' '${TPL}' '${PLUGIN_DIR}/README.md' '${PLUGIN_DIR}/.claude-plugin/plugin.json'"
  [ "$status" -ne 0 ]
}

@test "auto-merge wiring templates are not duplicated here" {
  run bash -c "find '${TPL}' -name 'auto-merge.yml' -o -name 'staging-smoke.yml' -o -name 'settings-permissions-deny.json' | grep ."
  [ "$status" -ne 0 ]
}

@test "README states the setup order and the repo-side / resident-side split" {
  local readme="${PLUGIN_DIR}/README.md"
  grep -q "infra" "$readme"
  grep -q "dev-workflow" "$readme"
  grep -q "auto-merge" "$readme"
  grep -q "product-handover" "$readme"
  grep -q "sns" "$readme"
  grep -q "new-resident" "$readme"
  grep -q "flatmate" "$readme"
}

# --- (c) marketplace.json ---

@test "marketplace.json lists product-handover and not agent-owner" {
  run jq -e '.plugins[] | select(.name == "product-handover")' "$MARKETPLACE"
  [ "$status" -eq 0 ]
  run jq -e '.plugins[] | select(.name == "agent-owner")' "$MARKETPLACE"
  [ "$status" -ne 0 ]
  [ "$(jq -r '.plugins[] | select(.name == "product-handover") | .source' "$MARKETPLACE")" = "./plugins/product-handover" ]
}

@test "marketplace.json bundles reference product-handover only" {
  run jq -e '.bundles[] | select(.plugins | index("agent-owner"))' "$MARKETPLACE"
  [ "$status" -ne 0 ]
  run jq -e '.bundles[] | select(.name == "all") | select(.plugins | index("product-handover"))' "$MARKETPLACE"
  [ "$status" -eq 0 ]
}

# --- (d) 旧名の残存 ---

@test "no old plugin name references remain outside changelog and this suite" {
  # 見る場所を列挙する許可リストではなく、repo 全体から2ファイルを除く除外リスト方式にする。
  # 許可リストだと .github/ や openspec/ など新しい場所への再混入を捕まえられない。
  # 除外は2つだけ: 移行手順を書く CHANGELOG.md と、旧名を検査語として持つ本テスト自身。
  # _longruns/ は過去の自律実行のアーカイブなので対象外（scripts/test.sh の除外と同じ理由）。
  run bash -c "cd '${REPO_ROOT}' && grep -rn 'agent-owner' . --exclude-dir=.git --exclude-dir=_longruns | grep -v '/product-handover/CHANGELOG.md:' | grep -v '/product-handover/tests/plugin-structure.bats:'"
  [ "$status" -ne 0 ]
}

@test "CHANGELOG documents the uninstall/install migration steps" {
  local cl="${PLUGIN_DIR}/CHANGELOG.md"
  [ -f "$cl" ]
  grep -q "plugin uninstall agent-owner@oratta-claude-harness" "$cl"
  grep -q "plugin install product-handover@oratta-claude-harness" "$cl"
}
