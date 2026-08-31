#!/usr/bin/env bats
#
# loops / longrun / lr の解散（issue #205, epic #208）の構造検証
#
# spec: loops-longrun-retirement
#
# 3 プラグインの不在・marketplace からの除去・解散 capability の spec 不在・
# 参照の掃除（許容リスト外 0 件）・CHANGELOG の uninstall 手順・README の解散記録を
# grep / jq / find だけで検査する。テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。
#
# 掃除 grep の許容リスト（spec の例外 (a)〜(e)）:
#   (a) plugins/dev-workflow/CHANGELOG.md（解散記録・新旧パス対応表）
#   (b) plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md（由来説明）
#   (c) plugins/product-handover/CHANGELOG.md（「loops の解散は #205」）
#   (d) ルートの過去実行アーカイブ _longruns/ を指す行
#   (e) この掃除と解散を検査する bats 自身（plugins/dev-workflow/tests/*.bats, tests/marketplace-sync.bats）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
  CHANGELOG="${PLUGIN_DIR}/CHANGELOG.md"
  ROOT_README="${REPO_ROOT}/README.md"
  ALLOW_RE='^(plugins/dev-workflow/CHANGELOG\.md|plugins/dev-workflow/skills/develop/references/roles/spec-reviewer\.md|plugins/product-handover/CHANGELOG\.md|plugins/dev-workflow/tests/[^/]+\.bats|tests/marketplace-sync\.bats):|^[^:]*_longruns'
}

# --- Requirement: 3 ディレクトリの git 追跡削除 ---

@test "retired plugin directories loops, longrun and lr are absent" {
  [ ! -e "${REPO_ROOT}/plugins/loops" ]
  [ ! -e "${REPO_ROOT}/plugins/longrun" ]
  [ ! -e "${REPO_ROOT}/plugins/lr" ]
}

# --- Requirement: marketplace.json から 3 プラグインを外す ---

@test "marketplace plugins[] has no loops, longrun or lr entry" {
  n="$(jq -r '[.plugins[].name] | map(select(. == "loops" or . == "longrun" or . == "lr")) | length' "$MARKETPLACE")"
  [ "$n" = "0" ]
}

@test "marketplace bundle all does not list loops, longrun or lr" {
  n="$(jq -r '[.bundles[] | select(.name=="all") | .plugins[]] | map(select(. == "loops" or . == "longrun" or . == "lr")) | length' "$MARKETPLACE")"
  [ "$n" = "0" ]
}

# --- Requirement: 解散した capability の spec を消す ---

@test "retired capability spec directories are absent" {
  # loops-longrun-retirement は本 change 自身の spec（解散を規定する側）なので対象外
  for d in "${REPO_ROOT}"/openspec/specs/loops-* "${REPO_ROOT}"/openspec/specs/longrun-*; do
    case "$d" in */loops-longrun-retirement) continue ;; esac
    [ ! -e "$d" ] || { echo "still present: $d"; return 1; }
  done
  for n in workflow-exec workflow-tool-reference workflow-run-control legacy-command-removal loop-dev-agent-tripwires; do
    [ ! -e "${REPO_ROOT}/openspec/specs/${n}" ] || { echo "still present: ${n}"; return 1; }
  done
}

# --- Requirement: 解散プラグインへの参照を掃除する ---

@test "no references to loops:, /lr: or longrun outside the allow list" {
  run bash -c "cd '${REPO_ROOT}' && grep -rn 'loops:\|/lr:\|longrun' plugins rules docs README.md .claude-plugin .github scripts 2>/dev/null | grep -vE '${ALLOW_RE}'"
  [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "no references to the old loops/longrun references paths" {
  run bash -c "cd '${REPO_ROOT}' && grep -rn 'loops/references/\|longrun/references/' plugins rules docs README.md .github 2>/dev/null | grep -vE '^(plugins/dev-workflow/CHANGELOG\.md|plugins/dev-workflow/tests/[^/]+\.bats|tests/marketplace-sync\.bats):'"
  [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "PR template and worker.md point the body format at dev-workflow references" {
  grep -q 'plugins/dev-workflow/references/pr-body-format.md' "${REPO_ROOT}/.github/PULL_REQUEST_TEMPLATE.md"
  grep -q 'plugins/dev-workflow/references/pr-body-format.md' "${PLUGIN_DIR}/skills/develop/references/roles/worker.md"
}

# --- Requirement: アンインストール手順と契約の移設先を CHANGELOG に書く ---

@test "changelog exists with a 2.1.0 entry" {
  [ -f "$CHANGELOG" ]
  grep -qE '^## .*2\.1\.0' "$CHANGELOG"
}

@test "changelog lists the three uninstall commands and reload-plugins" {
  grep -qF '/plugin uninstall loops@oratta-claude-harness' "$CHANGELOG"
  grep -qF '/plugin uninstall longrun@oratta-claude-harness' "$CHANGELOG"
  grep -qF '/plugin uninstall lr@oratta-claude-harness' "$CHANGELOG"
  grep -qF '/reload-plugins' "$CHANGELOG"
  grep -qF 'enabledPlugins' "$CHANGELOG"
}

@test "changelog has the old-to-new path table for the relocated contracts" {
  grep -qF 'plugins/dev-workflow/references/self-verification.md' "$CHANGELOG"
  grep -qF 'plugins/dev-workflow/references/pr-body-format.md' "$CHANGELOG"
  grep -qF 'plugins/dev-workflow/references/model-tiers.md' "$CHANGELOG"
  grep -qF 'skills/issueify/SKILL.md' "$CHANGELOG"
  grep -q 'review-queue' "$CHANGELOG"
  grep -q 'feature-list-format' "$CHANGELOG"
  grep -qF '/lr:e' "$CHANGELOG"
  grep -qF '/lr:p' "$CHANGELOG"
}

@test "changelog names the flatmate follow-ups including the pre-push hook template" {
  grep -q 'agent-loop.md' "$CHANGELOG"
  grep -q 'burn-mode.md' "$CHANGELOG"
  grep -q 'pre-push' "$CHANGELOG"
  grep -q 'new-resident' "$CHANGELOG"
}

# --- Requirement: 憲法の正本は flatmate 側と宣言する ---

@test "plugin README states the constitution is owned by flatmate and no template ships here" {
  readme="${PLUGIN_DIR}/README.md"
  grep -q 'docs/agent-loop.md' "$readme"
  grep -q 'flatmate' "$readme"
  ! grep -q 'agent-loop-template' "$readme"
}

@test "root README drops the retired plugin sections and records the retirement" {
  ! grep -qF '/plugin install longrun@oratta-claude-harness' "$ROOT_README"
  ! grep -qF '/plugin install loops@oratta-claude-harness' "$ROOT_README"
  ! grep -qF '`/longrun:plan' "$ROOT_README"
  ! grep -qF '`/loops:design' "$ROOT_README"
  grep -q 'plugins/dev-workflow/CHANGELOG.md' "$ROOT_README"
}

# --- Requirement: 参照を直したプラグインの version を上げる ---

@test "dev-workflow is 2.1.0 or newer in plugin.json and marketplace agrees" {
  p="$(jq -r .version "${PLUGIN_DIR}/.claude-plugin/plugin.json")"
  m="$(jq -r '.plugins[] | select(.name=="dev-workflow") | .version' "$MARKETPLACE")"
  [ "$p" = "$m" ]
  printf '2.1.0\n%s\n' "$p" | sort -V -C
}
