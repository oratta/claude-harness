#!/usr/bin/env bats
#
# Tests for change-7 (repo-cleanup-final).
# Capabilities: repo-root-cleanup / marketplace-final-sync / openspec-dedup-resolution
# spec: _longruns/2026-07-03_plugin-review-fixes/vg-fragments/change-7.md (S1-S21)
#
# Verifies:
#   - templates/rules/ and docs/cooking-mvp-mode-plan.md are gone (S7-S9)
#   - .gitignore + skill-pack SKILL.md no longer carry the 1h-cooking naming (S10-S11)
#   - skill-pack documents the skillOverrides scope boundary (S12)
#   - e2s-distill resolves the plugin root via ${CLAUDE_PLUGIN_ROOT}, not realpath "$0" (S13)
#   - skill-pack / experience-to-skill plugin.json versions are bumped (S14)
#   - all 8 edited plugins' plugin.json version == marketplace.json entry version (S16)
#   - all 8 descriptions are synced plugin.json -> marketplace.json (S17)
#   - the two retired plugins keep zero marketplace entries (S18)
#   - every *.json parses (S21)

setup() {
  RUN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "$RUN_DIR/../.." && pwd)"
  MARKETPLACE_JSON="${REPO_ROOT}/.claude-plugin/marketplace.json"
  SKILLPACK_SKILL="${REPO_ROOT}/plugins/skill-pack/skills/skill-pack/SKILL.md"
  E2S_DISTILL="${REPO_ROOT}/plugins/experience-to-skill/commands/e2s-distill.md"
  GITIGNORE="${REPO_ROOT}/.gitignore"
  PLUGINS=(infra longrun lr worktree daily-report weekly-report skill-pack experience-to-skill)
}

# --- S7 / S8: templates/rules removal ---

@test "S8: templates/rules directory and its 4 files are absent" {
  [ ! -d "${REPO_ROOT}/templates/rules" ]
  [ ! -f "${REPO_ROOT}/templates/rules/claude-code-operations.md" ]
  [ ! -f "${REPO_ROOT}/templates/rules/git-branch-and-pr.md" ]
  [ ! -f "${REPO_ROOT}/templates/rules/task-workflow.md" ]
  [ ! -f "${REPO_ROOT}/templates/rules/team-and-agent-usage.md" ]
}

@test "S7: no live references to templates/rules in the scoped surface" {
  cd "$REPO_ROOT"
  run bash -c 'grep -rn "templates/rules" plugins/ .claude-plugin/ README.md docs/ 2>/dev/null'
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# --- S9: cooking doc removal ---

@test "S9: docs/cooking-mvp-mode-plan.md is absent" {
  [ ! -f "${REPO_ROOT}/docs/cooking-mvp-mode-plan.md" ]
}

# --- S10: .gitignore cooking comment updated ---

@test "S10: .gitignore has no 1h-cooking naming" {
  run grep -n "1h-cooking" "$GITIGNORE"
  [ "$status" -ne 0 ]
}

@test "S10: .gitignore references harvest naming for session output" {
  run grep -in "harvest" "$GITIGNORE"
  [ "$status" -eq 0 ]
}

# --- S11: skill-pack cooking cleanup ---

@test "S11: skill-pack SKILL.md has no 1h-cooking / cooking@1h-cooking residue" {
  run grep -n "1h-cooking" "$SKILLPACK_SKILL"
  [ "$status" -ne 0 ]
}

# --- S12: skillOverrides scope note ---

@test "S12: skill-pack SKILL.md states skillOverrides does not control plugin skills" {
  # a note tying skillOverrides to personal (~/.claude/skills/) scope and
  # enabledPlugins to plugin-level control must exist near the on/off explanation.
  run grep -nE "skillOverrides.*(制御しない|制御できない|対象外)" "$SKILLPACK_SKILL"
  [ "$status" -eq 0 ]
  # and enabledPlugins must be named as the plugin-level control path in the same note
  run grep -nE "enabledPlugins.*(plugin 単位|plugin単位|プラグイン単位)" "$SKILLPACK_SKILL"
  [ "$status" -eq 0 ]
}

# --- S13: e2s realpath removal ---

@test "S13: e2s-distill.md has no realpath \"\$0\" plugin-root derivation" {
  run grep -n 'realpath "\$0"' "$E2S_DISTILL"
  [ "$status" -ne 0 ]
}

@test "S13: e2s-distill.md resolves plugin root via CLAUDE_PLUGIN_ROOT" {
  run grep -n 'CLAUDE_PLUGIN_ROOT' "$E2S_DISTILL"
  [ "$status" -eq 0 ]
}

# --- S14: skill-pack / e2s version bump ---

@test "S14: skill-pack plugin.json version is bumped above 0.1.0" {
  v="$(jq -r '.version' "${REPO_ROOT}/plugins/skill-pack/.claude-plugin/plugin.json")"
  [ "$v" != "0.1.0" ]
}

@test "S14: experience-to-skill plugin.json version is bumped above 0.2.0" {
  v="$(jq -r '.version' "${REPO_ROOT}/plugins/experience-to-skill/.claude-plugin/plugin.json")"
  [ "$v" != "0.2.0" ]
}

# --- S16: version parity plugin.json == marketplace.json ---

@test "S16: every edited plugin's plugin.json version == marketplace.json entry version" {
  for p in "${PLUGINS[@]}"; do
    pv="$(jq -r '.version' "${REPO_ROOT}/plugins/$p/.claude-plugin/plugin.json")"
    mv="$(jq -r --arg n "$p" '.plugins[] | select(.name==$n) | .version' "$MARKETPLACE_JSON")"
    [ "$pv" = "$mv" ] || {
      echo "version mismatch for $p: plugin.json=$pv marketplace=$mv"
      return 1
    }
  done
}

# --- S17: description parity plugin.json -> marketplace.json ---

@test "S17: every edited plugin's description is synced plugin.json -> marketplace.json" {
  for p in "${PLUGINS[@]}"; do
    pd="$(jq -r '.description' "${REPO_ROOT}/plugins/$p/.claude-plugin/plugin.json")"
    md="$(jq -r --arg n "$p" '.plugins[] | select(.name==$n) | .description' "$MARKETPLACE_JSON")"
    [ "$pd" = "$md" ] || {
      echo "description mismatch for $p"
      return 1
    }
  done
}

# --- S18: retired plugins carry zero marketplace entries ---

@test "S18: marketplace.json has no obsidian-llm-session-rules / skill-aware-workflow entries" {
  run jq -e '[.plugins[].name] | index("obsidian-llm-session-rules")' "$MARKETPLACE_JSON"
  [ "$output" = "null" ]
  run jq -e '[.plugins[].name] | index("skill-aware-workflow")' "$MARKETPLACE_JSON"
  [ "$output" = "null" ]
}

# --- S21: all *.json parse ---

@test "S21: all tracked *.json under repo parse as JSON" {
  cd "$REPO_ROOT"
  while IFS= read -r f; do
    jq empty "$f" || {
      echo "invalid JSON: $f"
      return 1
    }
  done < <(git ls-files '*.json')
}
