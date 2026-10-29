#!/usr/bin/env bats
# #558: Execute the documented blocks, never a copied implementation.
# Block numbers include non-shell fences; see the inventory prepared for the PR.

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export HOME="${BATS_TEST_TMPDIR}/home"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="${HOME}/.gitconfig"
  export R=fixture/repo N=42
  export CALLS="${BATS_TEST_TMPDIR}/gh.calls"
  export GH_MODE=default GH_DRAFT=true GH_PASSED=yes GH_FAIL_READY=0
  mkdir -p "$HOME" "${BATS_TEST_TMPDIR}/bin" "${BATS_TEST_TMPDIR}/repo"
  : > "$CALLS"
  cat > "${BATS_TEST_TMPDIR}/bin/gh" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$CALLS"
case "$*" in
  'pr list '*) echo '1 0' ;;
  'pr ready '*) [ "$GH_FAIL_READY" = 0 ] ;;
  'pr diff 42 --name-only') printf 'alpha.md\nbeta.sh\n' ;;
  'pr diff 42') printf '%s\n' '--- a/alpha.md' '+++ b/alpha.md' '-old' '+new' ' unchanged' ;;
  *'.head.sha') echo '1111111111111111111111111111111111111111' ;;
  *'.draft') echo "$GH_DRAFT" ;;
  *'.labels[].name') [ "$GH_PASSED" != yes ] || echo 'agent-review:passed' ;;
  *'.body')
    case "$*" in
      *pulls*) if [ "$GH_MODE" = no-issue ]; then echo 'PR acceptance criteria'; else echo 'Closes #558'; fi ;;
      *issues/558*) echo 'issue acceptance criteria' ;;
    esac ;;
  *'/comments --jq '*) printf 'review: fixed HEAD\n' ;;
  *'-X DELETE '*|*'-X POST '*) ;;
  *) echo "unexpected gh call: $*" >&2; exit 97 ;;
esac
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  cd "${BATS_TEST_TMPDIR}/repo" || return 1
  git init -q
}

# Extract exactly one complete fence. Only literal argument/path placeholders are
# substituted by callers; executable command text and control flow stay intact.
extract_block() {
  python3 - "$PLUGIN_DIR/$1" "$2" "${BATS_TEST_TMPDIR}/snippet.sh" <<'PY'
import re, sys
from pathlib import Path
src, ordinal, dest = sys.argv[1:]
blocks = []
body = None
for line in Path(src).read_text().splitlines(keepends=True):
    if re.match(r'^\s*```', line):
        if body is None:
            body = []
        else:
            blocks.append(''.join(body))
            body = None
    elif body is not None:
        body.append(line)
assert body is None, 'unclosed fence'
assert 0 < int(ordinal) <= len(blocks), 'missing block'
Path(dest).write_text(blocks[int(ordinal) - 1])
PY
  SNIP="${BATS_TEST_TMPDIR}/snippet.sh"
}

replace_literal() {
  python3 - "$SNIP" "$1" "$2" <<'PY'
from pathlib import Path
import sys
p, old, new = sys.argv[1:]
s = Path(p).read_text()
assert old in s, f'missing placeholder: {old}'
Path(p).write_text(s.replace(old, new))
PY
}

prepare_block() { extract_block skills/pr-review-gate/stages/prepare.md "$1"; }
pass_block() { extract_block skills/pr-review-gate/stages/pass.md "$1"; }
push_block() { extract_block skills/push-guard-setup/SKILL.md "$1"; }

memory_fixture() {
  mkdir -p "$HOME/memory"
  printf '%s\n' '- [topic](topic.md)' > "$HOME/memory/MEMORY.md"
  printf 'retained knowledge\n' > "$HOME/memory/topic.md"
  extract_block skills/memory-refresh/SKILL.md "$1"
  replace_literal '<メモリディレクトリ>' '"$HOME/memory"'
}

install_fixture() {
  push_block 2
  mkdir -p "$HOME/.githooks"
  cp "$SNIP" "$HOME/.githooks/pre-push"
  push_block 3
  bash "$SNIP"
}

@test "memory backup block copies every file and refuses an existing backup" {
  memory_fixture 1
  # Freeze only the timestamp so the collision branch is deterministic.
  printf '#!/bin/sh\necho 20261029-000000\n' > "${BATS_TEST_TMPDIR}/bin/date"
  chmod +x "${BATS_TEST_TMPDIR}/bin/date"
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [[ "$output" == "BACKUP OK: $HOME/memory.bak-20261029-000000" ]] || return 1
  diff -r "$HOME/memory" "$HOME/memory.bak-20261029-000000"
  printf 'new knowledge\n' >> "$HOME/memory/topic.md"
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [[ "$output" == STOP:* ]] || return 1
  [ "$(cat "$HOME/memory.bak-20261029-000000/topic.md")" = 'retained knowledge' ]
}

@test "memory audit block counts entries and executes the tripwire" {
  memory_fixture 2
  replace_literal '<dev-workflow のディレクトリ>' '"$PLUGIN_DIR"'
  export PLUGIN_DIR
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ files:[[:space:]]+1[[:space:]]+entries:[[:space:]]+1 ]] || return 1
  [[ "$output" == *'no orphan/missing'* ]] || return 1
  [[ "$output" != *'[memory]'* ]] || return 1
  DEV_WORKFLOW_MEMORY_INDEX_BYTES=1 run bash "$SNIP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'[memory]'* ]] || return 1
}

@test "nonce block creates a prompt and an alphanumeric nonce in the sandbox" {
  extract_block references/subagent-waiting.md 2
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  dir="$(printf '%s\n' "$output" | sed -n 's/^dir=//p')"
  nonce="$(printf '%s\n' "$output" | sed -n 's/^nonce=//p')"
  [[ "$dir" == "$BATS_TEST_TMPDIR"/* ]] || return 1
  [ -s "$dir/prompt.txt" ]
  [[ "$nonce" =~ ^[A-Za-z0-9]{16,}$ ]] || return 1
}

@test "push hook block rejects merged branches and allows open branches" {
  push_block 2
  run bash "$SNIP" <<< 'refs/heads/x 111 refs/heads/x 222'
  [ "$status" -eq 1 ]
  [[ "$output" == *'PREPUSH_ALLOW_MERGED=1'* ]] || return 1
  # A second fixture response exercises the allowed branch without real GitHub.
  printf '#!/bin/sh\necho "1 1"\n' > "${BATS_TEST_TMPDIR}/bin/gh"
  run bash "$SNIP" <<< 'refs/heads/x 111 refs/heads/x 222'
  [ "$status" -eq 0 ]
}

@test "push install block configures an executable hook under the isolated home" {
  install_fixture
  [ -x "$HOME/.githooks/pre-push" ]
  [ "$(git config --global --get core.hooksPath)" = "$HOME/.githooks" ]
}

@test "push verification block reports an installed hook" {
  install_fixture
  push_block 4
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.githooks"$'\nhook installed' ]
}

@test "push opt out block sets a repository local hooks path" {
  push_block 6
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$(git config --local --get core.hooksPath)" = .git/hooks ]
}

@test "push inspection block lists only non sample hooks" {
  mkdir -p "$HOME/path/to/repo/.git/hooks"
  touch "$HOME/path/to/repo/.git/hooks/example.sample" "$HOME/path/to/repo/.git/hooks/pre-push"
  push_block 7
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = pre-push ]
}

@test "prepare reset block removes passed and returns a ready PR to draft" {
  prepare_block 1
  GH_DRAFT=false run bash "$SNIP"
  [ "$status" -eq 0 ]
  grep -qx 'api -X DELETE repos/fixture/repo/issues/42/labels/agent-review:passed' "$CALLS"
  grep -qx 'pr ready --undo 42 --repo fixture/repo' "$CALLS"
}

@test "prepare reset block leaves an unpassed PR alone" {
  prepare_block 1
  GH_PASSED=no run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$CALLS")" -eq 1 ]
}

@test "prepare criteria block selects the linked issue or falls back to the PR" {
  prepare_block 2
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = 'issue acceptance criteria' ]
  GH_MODE=no-issue run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = 'PR acceptance criteria' ]
  grep -qx 'api repos/fixture/repo/pulls/42 --jq .body' "$CALLS"
  # Two reads of PR body in the fallback invocation (discovery and criteria).
  [ "$(grep -c 'pulls/42 --jq .body' "$CALLS")" -eq 3 ]
}

@test "prepare head block captures the fixed review SHA" {
  prepare_block 3
  printf '\nprintf "HEAD=%%s\\n" "$HEAD_SHA"\n' >> "$SNIP"
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = HEAD=1111111111111111111111111111111111111111 ]
}

@test "prepare diff block counts changed lines excluding diff headers" {
  prepare_block 4
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = $'alpha.md\nbeta.sh\n2' ]
}

@test "pass head block retrieves comments for the fixed SHA" {
  pass_block 11
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = 'review: fixed HEAD' ]
  grep -q 'contains("1111111111111111111111111111111111111111")' "$CALLS"
}

@test "pass label block makes a draft ready before adding passed" {
  pass_block 13
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  ready="$(grep -n '^pr ready ' "$CALLS" | cut -d: -f1)"
  label="$(grep -n 'labels\[\]=agent-review:passed' "$CALLS" | cut -d: -f1)"
  [ "$ready" -lt "$label" ]
  grep -qx 'api -X DELETE repos/fixture/repo/issues/42/labels/agent-review:pending' "$CALLS"
}

@test "pass label block refuses an invalid draft response" {
  pass_block 13
  GH_DRAFT=unknown run bash "$SNIP"
  [ "$status" -eq 1 ]
  [[ "$output" == *'draft を取得できない'* ]] || return 1
  ! grep -q 'labels\[\]=agent-review:passed' "$CALLS"
}

@test "pass label block stops when ready fails" {
  pass_block 13
  GH_FAIL_READY=1 run bash "$SNIP"
  [ "$status" -eq 1 ]
  [[ "$output" == *'gh pr ready に失敗'* ]] || return 1
  ! grep -q 'labels\[\]=agent-review:passed' "$CALLS"
}
