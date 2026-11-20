#!/usr/bin/env bats
#
# pr-token-measure.sh: codex-records.sh と pr-token-budget.sh を同じ順でつなぐ 1 コマンドのラッパー。
# 同じディレクトリの 2 つのスクリプトを呼ぶので、ラッパーだけを一時ディレクトリへ写し、
# 隣に 2 つのスタブを置いて検査する。スタブは呼ばれた引数を $WORK/calls に追記する。
#
# spec: openspec/changes/script-out-pr-token-and-dispatch-help（dev-workflow-pr-token-budget）

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  SD="${WORK}/scripts"
  mkdir -p "$SD"
  cp "${PLUGIN_DIR}/scripts/pr-token-measure.sh" "$SD/" 2>/dev/null || true
  SCRIPT="${SD}/pr-token-measure.sh"
  export CALLS="${WORK}/calls"
  : > "$CALLS"
  export CODEX_HOME="${WORK}/codex-default"
  # codex-records.sh のスタブ: 引数を記録し、--out のファイルに 1 行書く。CR_EXIT が 0 以外ならその終了コードで終わる
  cat > "${SD}/codex-records.sh" <<'SH'
#!/usr/bin/env bash
echo "records $*" >> "$CALLS"
out=""
while [ $# -gt 0 ]; do [ "$1" = "--out" ] && out="$2"; shift; done
if [ "${CR_EXIT:-0}" -ne 0 ]; then echo "codex-records: boom" >&2; exit "$CR_EXIT"; fi
echo "t1 1000" > "$out"
echo "$out" > "${CALLS}.out"
SH
  # pr-token-budget.sh のスタブ: 引数と記録ファイルの中身を記録し、1 行 JSON を出して PB_EXIT で終わる
  cat > "${SD}/pr-token-budget.sh" <<'SH'
#!/usr/bin/env bash
echo "budget $*" >> "$CALLS"
prev=""
for a in "$@"; do
  if [ "$prev" = "--codex-records" ]; then cat "$a" >> "${CALLS}.rec"; fi
  prev="$a"
done
echo '{"total_tokens":1,"over_cap":false}'
exit "${PB_EXIT:-0}"
SH
  chmod +x "${SD}/codex-records.sh" "${SD}/pr-token-budget.sh"
}

teardown() {
  rm -rf "$WORK"
}

run_measure() { run --separate-stderr "$SCRIPT" "$@"; }

@test "chains records and budget and returns the budget stdout" {
  run_measure --repo o/r 288
  [ "$status" -eq 0 ]
  [ "$output" = '{"total_tokens":1,"over_cap":false}' ]
  grep -qE '^records --repo o/r --out [^ ]+ 288$' "$CALLS"
  grep -qE '^budget 288 --codex-records [^ ]+ ' "$CALLS"
  [ "$(cat "${CALLS}.rec")" = "t1 1000" ]
}

@test "passes every record number to both scripts" {
  run_measure --repo o/r 288 400
  [ "$status" -eq 0 ]
  grep -qE '^records .* 288 400$' "$CALLS"
  grep -qE '^budget 288 400 --codex-records ' "$CALLS"
}

@test "exit 2 from the budget script is returned as is" {
  PB_EXIT=2 run_measure --repo o/r 288
  [ "$status" -eq 2 ]
  [ "$output" = '{"total_tokens":1,"over_cap":false}' ]
}

@test "exit 1 from the budget script is returned as is" {
  PB_EXIT=1 run_measure --repo o/r 288
  [ "$status" -eq 1 ]
}

@test "--cap is passed only when given" {
  run_measure --repo o/r --cap 60000000 288
  [ "$status" -eq 0 ]
  grep -qE '^budget .*--cap 60000000' "$CALLS"
  : > "$CALLS"
  run_measure --repo o/r 288
  [ "$status" -eq 0 ]
  ! grep -q -- '--cap' "$CALLS"
}

@test "--codex-home values are passed along with the CODEX_HOME default" {
  run_measure --repo o/r --codex-home /x 288
  [ "$status" -eq 0 ]
  grep -qF -- "--codex-home /x --codex-home ${CODEX_HOME}" "$CALLS"
}

@test "the default codex home falls back to HOME/.codex when CODEX_HOME is unset" {
  unset CODEX_HOME
  HOME="${WORK}/home" run_measure --repo o/r 288
  [ "$status" -eq 0 ]
  grep -qF -- "--codex-home ${WORK}/home/.codex" "$CALLS"
}

@test "a failed fetch does not call the budget script and exits 1 with empty stdout" {
  CR_EXIT=1 run_measure --repo o/r 288
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -n "$stderr" ]
  ! grep -q '^budget' "$CALLS"
}

@test "a non-1 failure of the fetch also exits 1" {
  CR_EXIT=3 run_measure --repo o/r 288
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  ! grep -q '^budget' "$CALLS"
}

@test "missing --repo calls nothing and exits 1" {
  run_measure 288
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -s "$CALLS" ]
}

@test "no record number calls nothing and exits 1" {
  run_measure --repo o/r
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -s "$CALLS" ]
}

@test "a non-numeric record number calls nothing and exits 1" {
  run_measure --repo o/r 28a
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -s "$CALLS" ]
}

@test "the temporary directory is removed after success, a failed fetch and exit 2" {
  export TMPDIR="${WORK}/tmp"
  mkdir -p "$TMPDIR"
  run_measure --repo o/r 288
  [ -z "$(ls -A "$TMPDIR")" ]
  PB_EXIT=2 run_measure --repo o/r 288
  [ -z "$(ls -A "$TMPDIR")" ]
  CR_EXIT=1 run_measure --repo o/r 288
  [ -z "$(ls -A "$TMPDIR")" ]
}
