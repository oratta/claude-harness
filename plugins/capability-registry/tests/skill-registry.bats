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

# 公開版の部分（「資格情報の階層」の節は個人版に決まった部品なので除く）
public_part() {
  awk '/^## 資格情報の階層/{skip=1} /^## 索引/{skip=0} !skip' "$SKILL"
}

@test "SKILL.md: the 4 public services are in the index, 1Password row is not" {
  for svc in "gh" "supabase" "vercel" "stripe"; do
    grep -q "^| .* | ${svc} |" "$SKILL"
  done
  ! grep -q "^| 1Password |" "$SKILL" || return 1
}

@test "SKILL.md: public part has no private token tool, points token location to the owner's index, keeps verify principle" {
  ! public_part | grep -q "fmt[o]ken" || return 1
  public_part | grep -q "オーナーの環境の索引"
  # 「記述を信じず verify を実行する」原則
  grep -Eq "(verify|認証確認)" "$SKILL"
}

@test "SKILL.md: negative entries (no CLI) section exists" {
  grep -Eq "CLI (が|の)?(無い|なし)" "$SKILL"
}

@test "per-service detail files exist (lazy-loaded)" {
  for f in github.md supabase.md vercel.md stripe.md; do
    [ -f "${PLUGIN_DIR}/skills/capability-registry/${f}" ]
    ! grep -q "fmt[o]ken" "${PLUGIN_DIR}/skills/capability-registry/${f}" || return 1
  done
  # 1password.md は個人版に決まった部品。公開版の索引は参照しない
  ! grep -q "1password.md" "$SKILL" || return 1
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
