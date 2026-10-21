#!/usr/bin/env bats
#
# scripts/lint.sh が shellcheck のあとに公式の検証（claude plugin validate）を走らせること、
# hooks.json の command が ${CLAUDE_PLUGIN_ROOT} を含むパスを二重引用符で囲むこと（issue #716）。
#
# spec: openspec/changes/lint-plugin-validate（archive 後は openspec/specs/lint-plugin-validate）
#
# 本物の claude は使わない（CI のランナーに無く、版で検証の中身が変わるとテストが揺れるため）。
# 一時ディレクトリに git リポジトリを作って scripts/lint.sh を複製し、PATH の先頭に偽の claude を置く。
# lint.sh は $0 の位置からリポジトリの根を決めるので、本物のリポジトリには触らない。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck is not installed"

  WORK="$(mktemp -d)"
  FAKE="${WORK}/repo"
  BIN="${WORK}/bin"
  LOG="${WORK}/claude-calls.log"
  mkdir -p "${FAKE}/scripts" "${FAKE}/plugins/alpha/.claude-plugin" "${FAKE}/plugins/alpha/scripts" \
    "${FAKE}/plugins/beta/.claude-plugin" "$BIN"
  cp "${REPO_ROOT}/scripts/lint.sh" "${FAKE}/scripts/lint.sh"
  printf '#!/bin/sh\necho ok\n' > "${FAKE}/scripts/ok.sh"
  printf '#!/bin/sh\necho alpha\n' > "${FAKE}/plugins/alpha/scripts/a.sh"
  printf '{"name":"alpha"}\n' > "${FAKE}/plugins/alpha/.claude-plugin/plugin.json"
  printf '{"name":"beta"}\n' > "${FAKE}/plugins/beta/.claude-plugin/plugin.json"
  git -C "$FAKE" init -q
  git -C "$FAKE" add -A

  # 偽の claude: 引数を 1 行で記録し、FAKE_CLAUDE_FAIL と同じ対象のときだけ 1 を返す。
  cat > "${BIN}/claude" <<EOF
#!/bin/sh
echo "\$*" >> "$LOG"
target=""
for a in "\$@"; do target="\$a"; done
if [ -n "\${FAKE_CLAUDE_FAIL:-}" ] && [ "\$target" = "\${FAKE_CLAUDE_FAIL}" ]; then
  echo "fake-validate-error for \$target"
  exit 1
fi
echo "fake-validate-ok for \$target"
exit 0
EOF
  chmod +x "${BIN}/claude"
  : > "$LOG"
}

teardown() {
  [ -n "${WORK:-}" ] && rm -rf "$WORK"
  return 0
}

run_lint() { # <lint.sh に渡す引数...>
  run env PATH="${BIN}:${PATH}" "${FAKE}/scripts/lint.sh" "$@"
}

calls() { cat "$LOG"; }

@test "all targets pass: exit 0, root and each plugin validated once without --strict" {
  run_lint
  echo "$output"
  [ "$status" -eq 0 ] || return 1
  [ "$(grep -cx 'plugin validate \.' "$LOG")" -eq 1 ] || return 1
  [ "$(grep -cx 'plugin validate plugins/alpha' "$LOG")" -eq 1 ] || return 1
  [ "$(grep -cx 'plugin validate plugins/beta' "$LOG")" -eq 1 ] || return 1
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 3 ] || return 1
  [ "$(grep -c -- '--strict' "$LOG")" -eq 0 ] || return 1
}

@test "one plugin fails: the other is still validated, its output is shown, exit is non-zero" {
  FAKE_CLAUDE_FAIL=plugins/alpha run_lint
  echo "$output"
  [ "$status" -ne 0 ] || return 1
  [ "$(grep -cx 'plugin validate plugins/beta' "$LOG")" -eq 1 ] || return 1
  echo "$output" | grep -q 'fake-validate-error for plugins/alpha' || return 1
}

@test "passing targets are reported in one line without the validator output" {
  run_lint
  [ "$status" -eq 0 ] || return 1
  echo "$output" | grep -q 'plugins/beta' || return 1
  [ "$(echo "$output" | grep -c 'fake-validate-ok')" -eq 0 ] || return 1
}

@test "no claude on PATH: exit 0 and the skip and its reason are printed" {
  NOCLAUDE="${WORK}/noclaude"
  mkdir -p "$NOCLAUDE"
  ln -s "$(command -v shellcheck)" "${NOCLAUDE}/shellcheck"
  ln -s "$(command -v git)" "${NOCLAUDE}/git"
  run env PATH="${NOCLAUDE}:/usr/bin:/bin" "${FAKE}/scripts/lint.sh"
  echo "$output"
  [ "$status" -eq 0 ] || return 1
  echo "$output" | grep -q 'claude plugin validate' || return 1
  echo "$output" | grep -q 'claude コマンドが見つからない' || return 1
  [ ! -s "$LOG" ] || return 1
}

@test "filter alpha: only plugins/alpha is validated (not beta, not the root)" {
  run_lint alpha
  echo "$output"
  [ "$status" -eq 0 ] || return 1
  [ "$(cat "$LOG")" = "plugin validate plugins/alpha" ] || return 1
}

@test "filter matching no plugin: validator is never called and exit is 0" {
  run_lint scripts/ok
  echo "$output"
  [ "$status" -eq 0 ] || return 1
  [ ! -s "$LOG" ] || return 1
}

@test "shellcheck findings do not stop the validation, exit is non-zero" {
  printf '#!/bin/sh\ncd /nonexistent\necho done\n' > "${FAKE}/scripts/bad.sh"
  git -C "$FAKE" add scripts/bad.sh
  run_lint
  echo "$output"
  [ "$status" -ne 0 ] || return 1
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 3 ] || return 1
}

@test "every tracked hooks.json command using CLAUDE_PLUGIN_ROOT quotes the whole path" {
  cd "$REPO_ROOT"
  run python3 - <<'PY'
import json, subprocess
files = subprocess.run(["git", "ls-files", "--", "plugins/*/hooks/hooks.json"],
                       capture_output=True, text=True, check=True).stdout.split()
bad, seen = [], 0
def walk(node, path):
    global seen
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "command" and isinstance(v, str) and "${CLAUDE_PLUGIN_ROOT}" in v:
                seen += 1
                if not (v.startswith('"${CLAUDE_PLUGIN_ROOT}/') and v.endswith('"')):
                    bad.append(f"{path}: {v}")
            walk(v, path)
    elif isinstance(node, list):
        for v in node:
            walk(v, path)
for f in files:
    with open(f, encoding="utf-8") as h:
        walk(json.load(h), f)
print(f"commands={seen}")
for b in bad:
    print("unquoted:", b)
raise SystemExit(1 if bad or seen == 0 else 0)
PY
  echo "$output"
  [ "$status" -eq 0 ] || return 1
}
