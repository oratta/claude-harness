#!/usr/bin/env bats
#
# loops-pre-push-guard: pre-push フックのマージ済み PR ブランチ push 拒否 (issue #60)
#
# SKILL.md Step 6 の sh コードブロックを実際に抽出して実行し、
# 拒否条件・fail-open・削除 push・バイパスの振る舞いを exit code で検証する。
# 記述だけの要件（再適用手順・レシピ言及・version bump）は grep で検証する。
#
# spec: loops-pre-push-guard

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  INSTALL="${PLUGIN_DIR}/skills/loops-dev-agent-install/SKILL.md"
  RECIPE="${PLUGIN_DIR}/recipes/loop-dev-agent.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  ZERO="0000000000000000000000000000000000000000"
  SHA="1111111111111111111111111111111111111111"

  TMP="$BATS_TEST_TMPDIR"
  HOOK="${TMP}/pre-push"
  extract_hook "$INSTALL" "$HOOK"

  # gh スタブ: GH_MERGED / GH_OPEN が件数、GH_FAIL=1 で非 0 終了
  mkdir -p "${TMP}/bin"
  cat > "${TMP}/bin/gh" <<'STUB'
#!/bin/sh
[ "${GH_FAIL:-0}" = "1" ] && exit 1
for a in "$@"; do
  case "$a" in
    merged) echo "${GH_MERGED:-0}"; exit 0 ;;
    open)   echo "${GH_OPEN:-0}";   exit 0 ;;
  esac
done
exit 1
STUB
  chmod +x "${TMP}/bin/gh"
  PATH="${TMP}/bin:${PATH}"
}

# SKILL.md の "## Step 6" 以降にある最初の ```sh ブロックをフックとして取り出す
extract_hook() {
  python3 - "$1" "$2" <<'PY'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
i = text.find("## Step 6")
assert i >= 0, "Step 6 heading not found"
m = re.search(r"```sh\n(.*?)```", text[i:], re.S)
assert m, "sh code block not found under Step 6"
open(dst, "w", encoding="utf-8").write(m.group(1))
PY
  chmod +x "$2"
}

# run_hook <remote_ref> <local_sha>
run_hook() {
  printf 'refs/heads/x %s %s %s\n' "$2" "$1" "$SHA" | sh "$HOOK"
}

# --- Requirement: マージ済み PR ブランチへの push 拒否 ---

@test "hook: rejects push to a branch whose PR is merged and has no open PR" {
  GH_MERGED=1 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 1 ]
}

@test "hook: allows first push (no PR exists yet)" {
  GH_MERGED=0 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: allows push when an open PR exists alongside a merged one" {
  GH_MERGED=1 GH_OPEN=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: still rejects direct push to main and master" {
  GH_MERGED=0 GH_OPEN=0 run run_hook "refs/heads/main" "$SHA"
  [ "$status" -eq 1 ]
  GH_MERGED=0 GH_OPEN=0 run run_hook "refs/heads/master" "$SHA"
  [ "$status" -eq 1 ]
}

# --- Requirement: gh 失敗時の fail-open ---

@test "hook: fails open when gh exits non-zero" {
  GH_FAIL=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: fails open when gh is not on PATH" {
  PATH="/usr/bin:/bin" run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "skill: fail-open policy is documented" {
  grep -q 'fail-open' "$INSTALL"
}

# --- Requirement: ブランチ削除 push の許可 ---

@test "hook: allows branch deletion push (all-zero local sha)" {
  GH_MERGED=1 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$ZERO"
  [ "$status" -eq 0 ]
}

# --- Requirement: 環境変数による明示バイパス ---

@test "hook: PREPUSH_ALLOW_MERGED=1 bypasses the merged check" {
  GH_MERGED=1 GH_OPEN=0 PREPUSH_ALLOW_MERGED=1 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 0 ]
}

@test "hook: PREPUSH_ALLOW_MERGED=1 does not bypass the main guard" {
  PREPUSH_ALLOW_MERGED=1 run run_hook "refs/heads/main" "$SHA"
  [ "$status" -eq 1 ]
}

@test "hook: rejection message advertises the bypass" {
  GH_MERGED=1 GH_OPEN=0 run run_hook "refs/heads/feature-a" "$SHA"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PREPUSH_ALLOW_MERGED=1"* ]]
}

# --- Requirement: 導入済みリポジトリへの再適用手順 ---

@test "skill: documents re-applying Step 6 to already-installed repos" {
  python3 - "$INSTALL" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
assert "再適用" in text, "re-apply section missing"
i = text.find("再適用")
window = text[i:i + 1200]
assert "core.hooksPath" in window, "core.hooksPath not mentioned in re-apply section"
assert "chmod +x" in window, "chmod +x not mentioned in re-apply section"
PY
}

# --- Requirement: レシピ本文へのガード説明の反映 ---

@test "recipe: mentions the merged-PR push guard" {
  grep -q 'マージ済み PR' "$RECIPE"
}

# --- Requirement: プラグインバージョンの更新 ---

@test "manifest: loops plugin version is bumped past 0.17.0" {
  python3 - "$MANIFEST" <<'PY'
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))["version"]
cur = tuple(int(p) for p in v.split("."))
assert cur > (0, 17, 0), f"version not bumped: {v}"
PY
}
