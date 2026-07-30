#!/usr/bin/env bats
#
# global-push-guard: 全リポジトリに効くグローバル pre-push ガード（issue #64）
#
# SKILL.md のフックテンプレートを実際に抽出して実行し、拒否条件・main を通すこと・
# バイパス・削除 push・タイムアウトを exit code で検証する。
# 記述だけの要件（層の優先関係・副作用・冪等性・既存設定の確認）は grep で検証する。
#
# spec: global-push-guard

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/push-guard-setup/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  ZERO="0000000000000000000000000000000000000000"
  SHA="1111111111111111111111111111111111111111"

  TMP="$BATS_TEST_TMPDIR"
  HOOK="${TMP}/pre-push"
  extract_hook "$SKILL" "$HOOK"

  GH_CALLS="${TMP}/gh-calls"
  : > "$GH_CALLS"
  export GH_CALLS
  mkdir -p "${TMP}/bin"
  cat > "${TMP}/bin/gh" <<'STUB'
#!/bin/sh
echo "call" >> "$GH_CALLS"
[ "${GH_HANG:-0}" = "1" ] && exec sleep 30
[ "${GH_FAIL:-0}" = "1" ] && exit 1
echo "${GH_MERGED:-0} ${GH_OPEN:-0}"
STUB
  chmod +x "${TMP}/bin/gh"
  PATH="${TMP}/bin:${PATH}"
}

# SKILL.md の "グローバルフックのテンプレート" 以降にある最初の ```sh ブロックを取り出す
extract_hook() {
  python3 - "$1" "$2" <<'PY'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
i = text.find("グローバルフックのテンプレート")
assert i >= 0, "hook template heading not found"
m = re.search(r"```sh\n(.*?)```", text[i:], re.S)
assert m, "sh code block not found under the template heading"
open(dst, "w", encoding="utf-8").write(m.group(1))
PY
  chmod +x "$2"
}

# run_hook <remote_ref> <local_sha>
run_hook() {
  printf 'refs/heads/x %s %s %s\n' "$2" "$1" "$SHA" | sh "$HOOK"
}

# --- Requirement: グローバル pre-push ガードの導入スキル ---

@test "skill: SKILL.md exists" {
  [ -f "$SKILL" ]
}

@test "manifest: push-guard-setup is registered in skills" {
  python3 - "$MANIFEST" <<'PY'
import json, sys
skills = json.load(open(sys.argv[1], encoding="utf-8"))["skills"]
assert "./skills/push-guard-setup" in skills, skills
PY
}

@test "skill: install steps cover file, chmod and global config" {
  grep -q '~/.githooks/pre-push' "$SKILL"
  grep -q 'chmod +x' "$SKILL"
  grep -q 'git config --global core.hooksPath' "$SKILL"
}

# --- Requirement: グローバル層はマージ済みチェックのみを持つ ---

@test "hook: does NOT reject direct push to main" {
  GH_MERGED=0 GH_OPEN=0 run run_hook "refs/heads/main" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: does NOT reject direct push to master" {
  GH_MERGED=0 GH_OPEN=0 run run_hook "refs/heads/master" "$SHA"
  [ "$status" -eq 0 ]
}

@test "skill: explains why the main guard is excluded from the global layer" {
  grep -q 'ローカル main 運用' "$SKILL"
}

# --- Requirement: グローバル層のマージ済み判定はローカル層と同一条件 ---

@test "hook: rejects push to a merged branch with no open PR" {
  GH_MERGED=1 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 1 ]
}

@test "hook: allows first push and reopened PR" {
  GH_MERGED=0 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
  GH_MERGED=1 GH_OPEN=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: allows bypass and branch deletion" {
  GH_MERGED=1 GH_OPEN=0 PREPUSH_ALLOW_MERGED=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
  GH_MERGED=1 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$ZERO"
  [ "$status" -eq 0 ]
}

@test "hook: rejection message advertises the bypass" {
  GH_MERGED=1 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PREPUSH_ALLOW_MERGED=1"* ]]
}

@test "hook: calls gh exactly once per pushed ref" {
  GH_MERGED=0 GH_OPEN=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$(wc -l < "$GH_CALLS" | tr -d ' ')" -eq 1 ]
}

@test "hook: fails open when gh exits non-zero" {
  GH_FAIL=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: gives up within a few seconds when gh hangs" {
  start=$SECONDS
  GH_HANG=1 run run_hook "refs/heads/feature-a" "$SHA"
  elapsed=$((SECONDS - start))
  [ "$status" -eq 0 ]
  [ "$elapsed" -lt 6 ]
}

@test "hook: does not depend on the timeout / gtimeout commands" {
  ! grep -Eq '(^|[^a-zA-Z-])g?timeout ' "$HOOK"
}

@test "hook: runs gh with stdin detached" {
  grep -q '</dev/null' "$HOOK"
}

# --- Requirement: 層の優先関係と副作用の明文化 ---

@test "skill: documents that repo-local hooksPath wins over global" {
  python3 - "$SKILL" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
assert "優先" in text, "precedence not explained"
assert "loops-dev-agent-install" in text, "local layer not referenced"
PY
}

@test "skill: documents the .git/hooks side effect and the opt-out" {
  grep -q '.git/hooks' "$SKILL"
  grep -q 'git config core.hooksPath .git/hooks' "$SKILL"
}

# --- Requirement: 導入の冪等性と既存設定の保護 ---

@test "skill: checks an existing global hooksPath before overwriting" {
  grep -q 'git config --global --get core.hooksPath' "$SKILL"
}

@test "skill: states the install is idempotent" {
  grep -q '冪等' "$SKILL"
}

# --- Requirement: プラグインバージョンの更新 ---

@test "manifest: dev-workflow version is bumped past 1.5.1" {
  python3 - "$MANIFEST" <<'PY'
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))["version"]
assert tuple(int(p) for p in v.split(".")) > (1, 5, 1), f"version not bumped: {v}"
PY
}

@test "marketplace: dev-workflow version matches plugin.json" {
  python3 - "$PLUGIN_ROOT" <<'PY'
import json, sys, pathlib
root = pathlib.Path(sys.argv[1])
mk = json.loads((root / ".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
pj = json.loads((root / "plugins/dev-workflow/.claude-plugin/plugin.json").read_text(encoding="utf-8"))
entry = next(p for p in mk["plugins"] if p["name"] == "dev-workflow")
assert entry.get("version") == pj["version"], f'{entry.get("version")} != {pj["version"]}'
PY
}
