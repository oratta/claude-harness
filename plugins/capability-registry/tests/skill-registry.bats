#!/usr/bin/env bats
#
# capability-registry-skill: 発見層スキル索引とプラグイン登録
#
# spec: capability-registry-skill

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/capability-registry/SKILL.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
}

@test "SKILL.md: exists" {
  [ -f "$SKILL" ]
}

@test "SKILL.md: description is the before-external-service trigger phrase" {
  python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r"---\n(.*?)\n---", text, re.S)
assert m, "frontmatter missing"
fm = m.group(1)
assert re.search(r"^name:\s*capability-registry\s*$", fm, re.M), fm
desc = re.search(r"^description:\s*(.+)$", fm, re.M).group(1)
assert "外部サービスを操作する前" in desc, desc
PY
}

@test "SKILL.md: stays within one screen (80 lines)" {
  lines="$(wc -l <"$SKILL")"
  [ "$lines" -le 80 ]
}

@test "SKILL.md: initial 5 proven services are in the index" {
  for svc in "op" "gh" "supabase" "vercel" "stripe"; do
    grep -q "$svc" "$SKILL"
  done
}

@test "SKILL.md: fmtoken.sh token retrieval and verify principle documented" {
  grep -q "fmtoken.sh" "$SKILL"
  grep -q "CLAUDE_PLUGIN_ROOT" "$SKILL"
  # 「記述を信じず verify を実行する」原則
  grep -Eq "(verify|認証確認)" "$SKILL"
}

@test "SKILL.md: negative entries (no CLI) section exists" {
  grep -Eq "CLI (が|の)?(無い|なし)" "$SKILL"
}

@test "per-service detail files exist (lazy-loaded)" {
  for f in 1password.md github.md supabase.md vercel.md stripe.md; do
    [ -f "${PLUGIN_DIR}/skills/capability-registry/${f}" ]
  done
}

@test "plugin.json: exists, parses, registers the skill" {
  [ -f "$PLUGIN_JSON" ]
  python3 - "$PLUGIN_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["name"] == "capability-registry"
assert "./skills/capability-registry" in d["skills"], d.get("skills")
PY
}

@test "marketplace.json: capability-registry is registered" {
  python3 - "$MARKETPLACE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
entries = [p for p in d["plugins"] if p["name"] == "capability-registry"]
assert entries, "capability-registry not registered"
assert entries[0]["source"] == "./plugins/capability-registry", entries[0]
PY
}
