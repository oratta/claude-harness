#!/usr/bin/env bats
#
# spec: cost-ledger-pricing（issue と子 issue 込みの経路でも、未知モデルの名前と行数を示す / 未知モデルの行の位置）
#       cost-ledger-cost-command（未知モデルの行は利用者に見せる）
#
# issue 経路（cost_ledger.py issue）の出力に、branch 経路と同じ文言で未知モデルの名前と行数が出ることと、
# commands/cost.md の指示を固定する。epic 経路の同じ検査は epic.bats に置く（gh の偽物とデータを共有する）。
#
# 共通のデータ（リポジトリ acme/ra）: S1 が issue #12 を触り、r1 r2 は haiku で $1.00、r3 は未知モデル claude-nope-9。

bats_require_minimum_version 1.5.0

load helper

WORDING='  未知モデル: claude-nope-9 1 行（料金表に単価が無いため 0 円として扱っている）'

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
}

issue_out() { python3 "$CL" issue 12 --repo "$RA"; }

known_rows() {
  cl_row S1 r1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12"
  cl_row S1 r2 2026-09-01T00:00:20.000Z main "$RA" 1000000
}

@test "unknown-model: the issue route shows the unknown model with the same wording as the branch route" {  # 区間に未知モデルの行が 1 行 → branch と同じ文字列の行が出る。1 行目は変わらない
  { known_rows; cl_row_unknown S1 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000; } | cl_write_log s1
  run issue_out
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF -- "$WORDING" || { echo "$output"; return 1; }
  [ "${lines[0]}" = 'コスト: $2.00 / ¥300 @150 — issue #12 (acme/ra) 帰属: 区間' ] || { echo "$output"; return 1; }
  # branch 経路の文言と同じ
  cl_mini_log mini claude-nope-9 '{"input_tokens":1,"output_tokens":1,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  printf '%s\n' "$output" | grep -qxF -- "$WORDING" || { echo "$output"; return 1; }
}

@test "unknown-model: the issue route counts the lines of the model" {  # 未知モデル 2 行 → 2 行
  { known_rows; cl_row_unknown S1 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000
    cl_row_unknown S1 r4 2026-09-01T00:00:40.000Z main "$RA" 1000000; } | cl_write_log s1
  run issue_out
  [[ "$output" == *'未知モデル: claude-nope-9 2 行（'* ]] || { echo "$output"; return 1; }
}

@test "unknown-model: no line appears when every model has a price" {  # 全部単価あり → 未知モデルの行は無い
  known_rows | cl_write_log s1
  run issue_out
  [ "$status" -eq 0 ]
  [[ "$output" != *'未知モデル'* ]] || { echo "$output"; return 1; }
}

@test "unknown-model: --json keeps stdout JSON and carries unknown_models" {  # 標準出力は JSON だけで unknown_models が入る。無いときは空
  { known_rows; cl_row_unknown S1 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000; } | cl_write_log s1
  python3 "$CL" issue 12 --repo "$RA" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["unknown_models"]=={"claude-nope-9":1}, d'
  known_rows | cl_write_log s1
  python3 "$CL" issue 12 --repo "$RA" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["unknown_models"]=={}, d'
}

@test "unknown-model: a row of unknown repository is not counted, and the line sits after it" {  # リポジトリ不明の行は数えない。位置は リポジトリ不明 → 未知モデル → ※
  { known_rows; cl_row_unknown S1 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000; } | cl_write_log s1
  {
    cl_row SU rU1 2026-09-01T00:02:00.000Z main /nonexistent/gone 1000000 "gh issue view 12"
    cl_row_unknown SU rU2 2026-09-01T00:02:10.000Z main /nonexistent/gone 1000000
  } | cl_write_log su
  # 推定で数えた行が出るデータ（置き場 ws/ra に A のリンクされた作業ツリー wt1 があり、cwd が削除済みの wt2）
  mkdir -p "$BATS_TEST_TMPDIR/ws/ra"
  git -C "$RA" worktree add -q -b wt-inf "$BATS_TEST_TMPDIR/ws/ra/wt1" >/dev/null 2>&1
  cl_row SI rI1 2026-09-01T00:03:00.000Z main "$BATS_TEST_TMPDIR/ws/ra/wt2" 1000000 "gh issue view 12" | cl_write_log si
  run issue_out
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *'未知モデル: claude-nope-9 1 行（'* ]] || { echo "$output"; return 1; }
  a="$(printf '%s\n' "$output" | grep -n 'リポジトリ不明' | head -1 | cut -d: -f1)"
  b="$(printf '%s\n' "$output" | grep -n '未知モデル:' | head -1 | cut -d: -f1)"
  c="$(printf '%s\n' "$output" | grep -n '推定で数えた行:' | head -1 | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] || { echo "$a $b $c"; echo "$output"; return 1; }
}

@test "unknown-model: several unknown models are listed in name order, one line each" {  # 名前の順（claude-aaa-1 → claude-zzz-9）で 1 行ずつ。出す順は行の順ではない
  { known_rows
    cl_row_unknown S1 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000 | sed 's/claude-nope-9/claude-zzz-9/'
    cl_row_unknown S1 r4 2026-09-01T00:00:40.000Z main "$RA" 1000000 | sed 's/claude-nope-9/claude-aaa-1/'; } | cl_write_log s1
  run issue_out
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  a="$(printf '%s\n' "$output" | grep -n '未知モデル: claude-aaa-1 1 行' | cut -d: -f1)"
  b="$(printf '%s\n' "$output" | grep -n '未知モデル: claude-zzz-9 1 行' | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || { echo "$output"; return 1; }
}

# 閉じた PR（--closing-pr）の行。feat/a の区間に属さない行に未知モデルがある
pr_rows() {
  { known_rows; cl_row S1 r3 2026-09-01T00:00:30.000Z feat/a "$RA" 1000000; } | cl_write_log s1
  cl_row_unknown S2 r4 2026-09-01T00:00:40.000Z feat/a "$RA" 1000000 | cl_write_log s2
}

@test "unknown-model: --closing-pr counts an unknown model on the closing PR's branch" {  # 閉じた PR のブランチ上の未知モデル 1 行 → 通常出力と --json の両方に出る。--closing-pr 無しでは出ない
  pr_rows
  run python3 "$CL" issue 12 --repo "$RA" --closing-pr 300:feat/a
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF -- "$WORDING" || { echo "$output"; return 1; }
  python3 "$CL" issue 12 --repo "$RA" --closing-pr 300:feat/a --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["unknown_models"]=={"claude-nope-9":1}, d'
  run issue_out
  [[ "$output" != *'未知モデル'* ]] || { echo "$output"; return 1; }
}

@test "unknown-model: --closing-pr counts a row on the branch and in the interval once" {  # 区間にも PR のブランチにも属する未知モデル 1 行 → 1 行（二重に数えない）
  { known_rows; cl_row_unknown S1 r3 2026-09-01T00:00:30.000Z feat/a "$RA" 1000000; } | cl_write_log s1
  python3 "$CL" issue 12 --repo "$RA" --closing-pr 300:feat/a --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["unknown_models"]=={"claude-nope-9":1}, d'
}

@test "unknown-model: cost.md tells to show the unknown-model line after the first line" {  # cost.md の指示（未知モデル: の行を見せる・<synthetic> は額に影響しない・PR に貼るのは 1 行目だけ）
  md="$PLUGIN_DIR/commands/cost.md"
  grep -q '未知モデル:' "$md" || return 1
  grep -F '1 行目に続けて' "$md" | grep -q '未知モデル:' || return 1
  grep -q '<synthetic>' "$md" || return 1
  grep -q 'PR に貼るのは 1 行目だけ' "$md" || return 1
}
