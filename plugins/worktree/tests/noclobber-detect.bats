#!/usr/bin/env bats
# wt-clean の稼働シグナル検出が noclobber 下でも黙って飛ばされないことの検査（#626）。
# SKILL.md から ORPHAN_NOTE_TMP の 3 行を取り出し、検出関数を差し替えて bash / zsh で実行する。
# zsh が無い環境（CI の ubuntu など）では zsh の検査は skip になる。

setup() {
  SKILL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/skills/wt-clean/SKILL.md"
  SNIP="$BATS_TEST_TMPDIR/snippet.sh"
  {
    echo 'detect_active_procs_under() { echo "4242(node)"; echo "居残りプロセス: x" >&2; }'
    echo 'WT=/nonexistent'
    grep -E '^(ORPHAN_NOTE_TMP=|ACTIVE_PROCS=|STALE_ORPHANS=)' "$SKILL"
    echo 'echo "PROCS=$ACTIVE_PROCS"'
    echo 'echo "NOTE=$STALE_ORPHANS"'
  } >"$SNIP"
}

@test "snippet is extracted from SKILL.md" {
  [ "$(grep -c . "$SNIP")" -ge 6 ]
  grep -q '^ACTIVE_PROCS=' "$SNIP"
}

@test "bash: detection result is kept under noclobber" {
  run bash -c 'set -o noclobber; . "$1"' _ "$SNIP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROCS=4242(node)"* ]]
  [[ "$output" == *"NOTE=居残りプロセス: x"* ]]
}

@test "zsh: detection result is kept under noclobber" {
  command -v zsh >/dev/null || skip "zsh が無い"
  run zsh -c 'setopt noclobber; . "$1"' _ "$SNIP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROCS=4242(node)"* ]]
  [[ "$output" == *"NOTE=居残りプロセス: x"* ]]
}

@test "skill: documents the noclobber pitfall" {
  grep -q 'noclobber' "$SKILL"
}
