#!/usr/bin/env bats
#
# Tests for capabilities:
#   - loops-cost-guardrails            (S115-S119)
#   - loops-integration-verification   (S120-S126)
#   - loops-marketplace-sync           (S127-S133)
#   - loops-readme-positioning         (S134-S138)
# Spec: openspec/changes/loops-integration/specs/*/spec.md
#
# Constraints: grep / jq / find only. No custom verification runtime / wrapper CLI.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  RECIPES="${PLUGIN_DIR}/recipes"
  REFERENCES="${PLUGIN_DIR}/references"
  COST="${REFERENCES}/cost-guardrails.md"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
  README="${PLUGIN_ROOT}/README.md"
  HEADINGS=("ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション")
}

# Extract the body of a level-2 (##) markdown section whose heading contains $2.
section_of() {
  awk -v h="$2" '
    /^## / { if (inx) exit; if (index($0, h)) { inx=1; next } }
    inx { print }
  ' "$1"
}

# Resolve the branch point ("main 時点") baseline. Empty when origin/main is
# unavailable. See design.md D8: origin/main diverged via an unrelated PR, so
# the merge-base is the honest baseline for "changed by this run / bumped".
base_ref() {
  if git -C "$PLUGIN_ROOT" rev-parse --verify -q origin/main >/dev/null 2>&1; then
    git -C "$PLUGIN_ROOT" merge-base HEAD origin/main 2>/dev/null
  fi
}

# ============================================================
# loops-cost-guardrails  (S115-S119)
# ============================================================

# --- S115: 6 items counted in a numbered form ---
@test "S115: cost-guardrails token-management section lists exactly 6 numbered items" {
  [ -f "$COST" ]
  section="$(section_of "$COST" "トークン管理")"
  [ -n "$section" ]
  count="$(echo "$section" | grep -Ec '^[0-9]+\. ')"
  [ "$count" -eq 6 ]
}

# --- S116: three key item phrasings present ---
@test "S116: cost-guardrails names frequency, scripting, and pilot items" {
  section="$(section_of "$COST" "トークン管理")"
  echo "$section" | grep -q "頻度"
  echo "$section" | grep -q "スクリプト化"
  echo "$section" | grep -q "パイロット"
}

# --- S117: quantitative facts 4x / 15x ---
@test "S117: cost-guardrails states the ~4x and ~15x token facts" {
  grep -Eq '約 ?4 ?倍|4倍' "$COST"
  grep -Eq '約 ?15 ?倍|15倍' "$COST"
}

# --- S118: /usage and /workflows review procedure ---
@test "S118: cost-guardrails documents /usage and /workflows review" {
  grep -q '/usage' "$COST"
  grep -q '/workflows' "$COST"
  # includes "when to check"
  grep -Eq 'パイロット|定期見直し|定常運用' "$COST"
}

# --- S119: no hardcoded model id ---
@test "S119: cost-guardrails has no hardcoded claude- model id" {
  run grep -Eq 'claude-[a-z0-9]' "$COST"
  [ "$status" -ne 0 ]
}

# ============================================================
# loops-integration-verification  (S120, S122-S125)
# S120 (this file all-pass) and S121 (full suite) are validated by execution.
# ============================================================

# --- S122: every recipe has all 7 fixed headings ---
@test "S122: all recipes have the 7 fixed headings (no missing)" {
  for f in "${RECIPES}"/*.md; do
    for h in "${HEADINGS[@]}"; do
      if ! grep -Eq "^#+ .*${h}" "$f"; then
        echo "missing heading '${h}' in ${f}"
        return 1
      fi
    done
  done
}

# --- S123: no recipe lacks 停止基準 heading ---
@test "S123: no recipe is missing the stop-criteria heading" {
  run grep -L '停止基準' "${RECIPES}"/*.md
  [ -z "$output" ]
}

# --- S124: no resident loop-runner / driver script in plugins/loops ---
@test "S124: no runner scripts (.sh/.js/.py) under plugins/loops" {
  run bash -c "find '${PLUGIN_DIR}' -type f \( -name '*.sh' -o -name '*.js' -o -name '*.py' \) ! -name '*.bats'"
  [ -z "$output" ]
}

@test "S124b: no while-true / sleep-loop resident processes in plugins/loops" {
  run bash -c "grep -rEl 'while +true|sleep +[0-9].*done' '${PLUGIN_DIR}' || true"
  [ -z "$output" ]
}

# --- S125: every recipe startup command is a native primitive ---
@test "S125: every recipe startup section uses native primitives only" {
  for f in "${RECIPES}"/*.md; do
    section="$(section_of "$f" "起動コマンド")"
    # at least one native slash-command invocation line
    if ! echo "$section" | grep -Eq '^/(goal|loop|schedule|[a-z][a-z-]*)'; then
      echo "no native slash-command line in 起動コマンド of ${f}"
      return 1
    fi
    # no custom CLI / wrapper script invocation
    if echo "$section" | grep -Eq 'bash .*\.sh|\./[A-Za-z0-9_./-]*\.sh|node .*\.js'; then
      echo "custom script invocation found in 起動コマンド of ${f}"
      return 1
    fi
  done
}

# ============================================================
# loops-marketplace-sync  (S127-S133)
# ============================================================

# --- S127: loops entry exists with correct source ---
@test "S127: marketplace.json has a loops entry with source ./plugins/loops" {
  src="$(jq -r '.plugins[] | select(.name=="loops") | .source' "$MARKETPLACE")"
  [ "$src" = "./plugins/loops" ]
  desc="$(jq -r '.plugins[] | select(.name=="loops") | .description' "$MARKETPLACE")"
  ver="$(jq -r '.plugins[] | select(.name=="loops") | .version' "$MARKETPLACE")"
  [ -n "$desc" ] && [ "$desc" != "null" ]
  [ -n "$ver" ] && [ "$ver" != "null" ]
}

# --- S128: loops marketplace version == plugin.json version ---
@test "S128: loops version matches between marketplace.json and plugin.json" {
  m="$(jq -r '.plugins[] | select(.name=="loops") | .version' "$MARKETPLACE")"
  p="$(jq -r '.version' "${PLUGIN_DIR}/.claude-plugin/plugin.json")"
  [ "$m" = "$p" ]
}

# --- S130 / S133: every marketplace entry version == its plugin.json (parity) ---
@test "S130: all marketplace plugins[] versions match their plugin.json" {
  names="$(jq -r '.plugins[].name' "$MARKETPLACE")"
  for n in $names; do
    m="$(jq -r --arg n "$n" '.plugins[] | select(.name==$n) | .version' "$MARKETPLACE")"
    pj="${PLUGIN_ROOT}/plugins/${n}/.claude-plugin/plugin.json"
    [ -f "$pj" ]
    p="$(jq -r '.version' "$pj")"
    if [ "$m" != "$p" ]; then
      echo "version mismatch for ${n}: marketplace=${m} plugin.json=${p}"
      return 1
    fi
  done
}

# --- S131: plugins changed by THIS run are bumped above the branch point ---
@test "S131: edited plugins have version bumped above merge-base" {
  base="$(base_ref)"
  [ -n "$base" ] || skip "origin/main unavailable"
  changed="$(git -C "$PLUGIN_ROOT" diff "$base" HEAD --name-only | grep '^plugins/' | sed -E 's#(plugins/[^/]+)/.*#\1#' | sort -u)"
  [ -n "$changed" ] || skip "no plugin changes vs merge-base"
  for d in $changed; do
    n="${d#plugins/}"
    cur="$(jq -r '.version' "${PLUGIN_ROOT}/${d}/.claude-plugin/plugin.json")"
    old="$(git -C "$PLUGIN_ROOT" show "${base}:${d}/.claude-plugin/plugin.json" 2>/dev/null | jq -r '.version' 2>/dev/null)"
    # new plugin (absent at base) needs no bump, only registration
    [ -z "$old" ] || [ "$old" = "null" ] && continue
    if [ "$cur" = "$old" ]; then
      echo "plugin ${n} changed by this run but version not bumped (still ${cur})"
      return 1
    fi
    lowest="$(printf '%s\n%s\n' "$cur" "$old" | sort -V | head -1)"
    [ "$lowest" = "$old" ] || { echo "${n}: ${cur} is not above ${old}"; return 1; }
  done
}

# --- S132: marketplace top-level version bumped above merge-base ---
@test "S132: marketplace top-level version bumped above merge-base" {
  base="$(base_ref)"
  [ -n "$base" ] || skip "origin/main unavailable"
  cur="$(jq -r '.version' "$MARKETPLACE")"
  old="$(git -C "$PLUGIN_ROOT" show "${base}:.claude-plugin/marketplace.json" 2>/dev/null | jq -r '.version' 2>/dev/null)"
  [ -n "$old" ] || skip "no marketplace at base"
  [ "$cur" != "$old" ] || { echo "top-level version not bumped (still ${cur})"; return 1; }
  lowest="$(printf '%s\n%s\n' "$cur" "$old" | sort -V | head -1)"
  [ "$lowest" = "$old" ]
}

# --- S133: all JSON files parse ---
@test "S133: marketplace.json and all plugin.json parse" {
  jq empty "$MARKETPLACE"
  for pj in "${PLUGIN_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
    jq empty "$pj"
  done
}

# ============================================================
# loops-readme-positioning  (S134-S138)
# ============================================================

# --- S134: four loop-type names present ---
@test "S134: README names all 4 loop types" {
  for w in "ターンベース" "ゴールベース" "タイムベース" "プロアクティブ"; do
    grep -q "$w" "$README"
  done
}

# --- S135: official article link present ---
@test "S135: README links the official loops article" {
  grep -q 'https://claude.com/blog/getting-started-with-loops' "$README"
}

# --- S136: install command present ---
@test "S136: README has the loops install command" {
  grep -q '/plugin install loops@oratta-claude-harness' "$README"
}

# --- S137: pointer to plugins/loops/ present ---
@test "S137: README points to plugins/loops/ for details" {
  grep -q 'plugins/loops/' "$README"
}

# --- S138: recipe fixed headings are NOT duplicated into README ---
@test "S138: README has no recipe fixed-heading structure" {
  run grep -Ec '^#+ .*(停止基準|エスカレーション)' "$README"
  [ "$output" = "0" ]
}
