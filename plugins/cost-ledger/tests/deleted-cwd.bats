#!/usr/bin/env bats
#
# spec: cost-ledger-attribution（削除済みの cwd からの推定・repo_inferred）
#       cost-ledger-persistence（補正行の追記・台帳を読むときの補正の適用）
#       cost-ledger-cost-command（推定で数えた行の表示と --json）
#
# 作業ツリーを消したあとの行（cwd が削除済み）を、パスからリポジトリに結び付けることを固定する。
# 会話ログ・台帳・git リポジトリはすべて $BATS_TEST_TMPDIR に置く。gh は偽物に差し替える。
#
# 共通の配置（どの行も haiku の input_tokens=1000000 で $1.00）:
#   $MAIN_A = main/ra … リポジトリ A（origin acme/ra）のメインの作業ツリー
#   $MAIN_B = main/rb … リポジトリ B（origin acme/rb）のメインの作業ツリー
#   $PLACE_A = ws/ra … A の置き場（git リポジトリではない）。直下の wt1 が A のリンクされた作業ツリー
#   $PLACE_B = ws/rb … B の置き場。直下の wt1 が B のリンクされた作業ツリー
# 置き場は、テストごとに place_a / place_b を呼んだ時点で作る（「あとから置き場ができる」形を作るため）。

load helper

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  LEDGER="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  HOOK="$PLUGIN_DIR/scripts/ledger-hook.sh"
  OUT="$BATS_TEST_TMPDIR/out"
  MAIN_A="$BATS_TEST_TMPDIR/main/ra"
  MAIN_B="$BATS_TEST_TMPDIR/main/rb"
  PLACE_A="$BATS_TEST_TMPDIR/ws/ra"
  PLACE_B="$BATS_TEST_TMPDIR/ws/rb"
  mkdir -p "$BATS_TEST_TMPDIR/main"
  cl_init_repo "$MAIN_A" acme/ra
  cl_init_repo "$MAIN_B" acme/rb
  A_ID="$(repo_id_of "$MAIN_A")"
  B_ID="$(repo_id_of "$MAIN_B")"
  WT_SERIAL=0
}

# cost_ledger.py と同じ求め方のリポジトリ識別子
repo_id_of() {  # $1=作業ツリー
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' \
    "$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)"
}

# リンクされた作業ツリーを 1 つ足す。$1=メインの作業ツリー $2=置く場所
add_worktree() {
  WT_SERIAL=$((WT_SERIAL + 1))
  mkdir -p "$(dirname "$2")"
  git -C "$1" worktree add -q -b "wt-$WT_SERIAL-$(basename "$2")" "$2" >/dev/null 2>&1
}

place_a() { add_worktree "$MAIN_A" "$PLACE_A/wt1"; }
place_b() { add_worktree "$MAIN_B" "$PLACE_B/wt1"; }

# 会話ログ直読みの事実を $OUT に書く
facts() { env -u COST_LEDGER_PATH python3 "$CL" facts > "$OUT"; }

# $OUT（JSONL）に python の式を当て、偽なら落とす。rows が全行、by が request_id から引く辞書。
# eval に渡す式は、このファイルの各テストに書いた固定の文字列だけ（外から来る入力は渡さない）
check_rows() {  # $1=式 $2..=式から argv で見える値
  python3 - "$OUT" "$@" <<'PY'
import json, sys
rows = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
by = {row["request_id"]: row for row in rows}
argv = sys.argv[3:]
assert eval(sys.argv[2]), rows
PY
}

# 標準入力の JSON に python の式を当て、偽なら落とす。d が JSON
check() {  # $1=式
  python3 -c '
import json, sys
d = json.load(sys.stdin)
near = lambda a, b: abs(a - b) < 1e-9
i = {row["number"]: row for row in d.get("issues", []) if isinstance(row, dict)} if isinstance(d.get("issues"), list) else {}
assert eval(sys.argv[1]), d
' "$1"
}

ledger_lines() { wc -l < "$LEDGER" | tr -d ' '; }
fix_rows() { grep -c '"repo_fix": true' "$LEDGER" || true; }
sync() { python3 "$CL" ledger-sync --quiet "$@"; }
issue_a() { python3 "$CL" issue "$@" --repo "$MAIN_A"; }

INFERRED_ONE='  推定で数えた行: 1 件 $1.00（cwd が削除済みで、パスからリポジトリを推定した。合計に入れている）'

# ---- cost-ledger-attribution: 削除済みの cwd からの推定 ---------------------

@test "deleted-cwd: a deleted sibling of a remaining worktree is inferred and marked" {  # 置き場 ws/ra に A の wt1 が残り、cwd が削除済みの ws/ra/wt2 → A の識別子で repo_inferred が true
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt2" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and by["r1"]["repo_inferred"] is True' "$A_ID"
}

@test "deleted-cwd: a deleted directory deep under the location is inferred from the nearest existing ancestor" {  # ws/ra/wt2/sub/dir（wt2 から下が削除済み）も置き場 ws/ra で決まる
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt2/sub/dir" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and by["r1"]["repo_inferred"] is True' "$A_ID"
}

@test "deleted-cwd: the location name may match the origin repository name instead of the directory name" {  # メインのディレクトリ名は other-name、origin は acme/repo-o、置き場は ws/repo-o
  local main="$BATS_TEST_TMPDIR/main/other-name"
  cl_init_repo "$main" acme/repo-o
  add_worktree "$main" "$BATS_TEST_TMPDIR/ws/repo-o/wt1"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/ws/repo-o/gone" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and by["r1"]["repo_inferred"] is True' "$(repo_id_of "$main")"
}

@test "deleted-cwd: a location whose name matches no repository stays unknown" {  # 置き場 workspaces に A の作業ツリーだけ → 不明で repo_inferred の欄は無い
  add_worktree "$MAIN_A" "$BATS_TEST_TMPDIR/ws2/workspaces/wt1"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/ws2/workspaces/gone" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

@test "deleted-cwd: the location name is compared case-sensitively" {  # 置き場 RA は ra と一致しない
  add_worktree "$MAIN_A" "$BATS_TEST_TMPDIR/ws2/RA/wt1"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/ws2/RA/gone" 1000000 | cl_write_log a
  facts
  # 大文字と小文字を区別しないファイルシステムでは ws2/RA と ws2/ra が同じ場所になるが、
  # 比べるのは cwd の文字列から取った置き場の名前（RA）なので結果は変わらない
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

@test "deleted-cwd: a location holding worktrees of two repositories stays unknown" {  # ws3/ra に A と B の作業ツリーが 1 つずつ → 不明
  add_worktree "$MAIN_A" "$BATS_TEST_TMPDIR/ws3/ra/wt1"
  add_worktree "$MAIN_B" "$BATS_TEST_TMPDIR/ws3/ra/wt2"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/ws3/ra/gone" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

@test "deleted-cwd: a location with no linked worktree stays unknown" {  # 置き場の直下が git でないディレクトリだけ → 不明
  mkdir -p "$PLACE_A/plain"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

@test "deleted-cwd: other directories in the location do not block the inference" {  # 置き場に git でないディレクトリとファイルが混ざっていても、作業ツリーが 1 リポジトリなら決まる
  place_a
  mkdir -p "$PLACE_A/plain"
  : > "$PLACE_A/note.txt"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0]' "$A_ID"
}

@test "deleted-cwd: a deleted directory inside a git repository stays unknown" {  # 現存する A の作業ツリーの中の削除済みサブディレクトリ（.claude/worktrees を含まない）→ 不明
  place_a
  {
    cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$MAIN_A/sub/gone" 1000000
    cl_row S1 r2 2026-09-01T00:00:02.000Z feat/x "$PLACE_A/wt1/sub/gone" 1000000
  } | cl_write_log a
  facts
  check_rows 'all(by[r]["repo_id"] == "不明" and "repo_inferred" not in by[r] for r in ("r1", "r2"))'
}

@test "deleted-cwd: .claude/worktrees resolves to the repository in front of it" {  # <A の作業ツリー>/.claude/worktrees/x（削除済み）→ A で repo_inferred が true
  place_a
  {
    cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$MAIN_A/.claude/worktrees/x" 1000000
    cl_row S1 r2 2026-09-01T00:00:02.000Z feat/x "$PLACE_A/wt1/.claude/worktrees/y/deep" 1000000
  } | cl_write_log a
  facts
  check_rows 'all(by[r]["repo_id"] == argv[0] and by[r]["repo_inferred"] is True for r in ("r1", "r2"))' "$A_ID"
}

@test "deleted-cwd: .claude/worktrees under a deleted worktree is inferred from the location" {  # ws/ra/wt2/.claude/worktrees/x で wt2 も削除済み → wt2 を置き場の規則で推定して A
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt2/.claude/worktrees/x" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and by["r1"]["repo_inferred"] is True' "$A_ID"
}

@test "deleted-cwd: .claude/worktrees in front of a non-repository stays unknown" {  # 手前が現存するが git でない → 不明
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/plain/.claude/worktrees/x" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

@test "deleted-cwd: rows resolved by git and unknown rows carry no repo_inferred field" {  # 存在する cwd・存在するが git でない cwd・祖先が / しか無い cwd
  place_a
  {
    cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt1" 1000000
    cl_row S1 r2 2026-09-01T00:00:02.000Z feat/x "$PLACE_A" 1000000
    cl_row S1 r3 2026-09-01T00:00:03.000Z feat/x "/nonexistent-750/x" 1000000
  } | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and [by[r]["repo_id"] for r in ("r2", "r3")] == ["不明", "不明"] and not any("repo_inferred" in row for row in rows)' "$A_ID"
}

@test "deleted-cwd: git is not started again for a second deleted cwd in the same location" {  # 同じ置き場の削除済み cwd が 1 つでも 3 つでも git の起動回数は同じ
  place_a
  add_worktree "$MAIN_A" "$PLACE_A/wt-b"
  mkdir -p "$BATS_TEST_TMPDIR/gitbin"
  local real; real="$(command -v git)"
  printf '#!/bin/sh\necho x >> "%s"\nexec "%s" "$@"\n' "$BATS_TEST_TMPDIR/git.log" "$real" > "$BATS_TEST_TMPDIR/gitbin/git"
  chmod +x "$BATS_TEST_TMPDIR/gitbin/git"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone1" 1000000 | cl_write_log a
  : > "$BATS_TEST_TMPDIR/git.log"
  PATH="$BATS_TEST_TMPDIR/gitbin:$PATH" facts
  local once; once=$(wc -l < "$BATS_TEST_TMPDIR/git.log" | tr -d ' ')
  check_rows 'by["r1"]["repo_id"] == argv[0]' "$A_ID"
  {
    cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone1" 1000000
    cl_row S1 r2 2026-09-01T00:00:02.000Z feat/x "$PLACE_A/gone2" 1000000
    cl_row S1 r3 2026-09-01T00:00:03.000Z feat/x "$PLACE_A/gone3/sub" 1000000
  } | cl_write_log a
  : > "$BATS_TEST_TMPDIR/git.log"
  PATH="$BATS_TEST_TMPDIR/gitbin:$PATH" facts
  check_rows 'all(by[r]["repo_id"] == argv[0] for r in ("r1", "r2", "r3"))' "$A_ID"
  [ "$once" -gt 0 ]
  [ "$(wc -l < "$BATS_TEST_TMPDIR/git.log" | tr -d ' ')" = "$once" ]
}

# 置き場の子の識別子を .git ファイルから読んだ値（git を起動しない）
linked_id_of() {  # $1=リンクされた作業ツリー
  python3 -c 'import os, sys
sys.path.insert(0, os.path.dirname(sys.argv[1]))
import cost_ledger
print(cost_ledger.RepoResolver._linked_id(sys.argv[2]))' "$CL" "$1"
}

@test "deleted-cwd: the identifier read from a worktree's .git file equals the one git rev-parse gives" {  # リンクされた作業ツリー 2 つ（片方は gitdir を相対パスに書き換える）で、ファイルから読んだ識別子が git rev-parse の識別子と同じ文字列
  place_a
  add_worktree "$MAIN_A" "$PLACE_A/wt-b"
  [ "$(linked_id_of "$PLACE_A/wt1")" = "$A_ID" ]
  [ "$(linked_id_of "$PLACE_A/wt1")" = "$(repo_id_of "$PLACE_A/wt1")" ]
  local rel; rel="$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$MAIN_A/.git/worktrees/wt-b" "$PLACE_A/wt-b")"
  printf 'gitdir: %s\n' "$rel" > "$PLACE_A/wt-b/.git"
  [ "$(linked_id_of "$PLACE_A/wt-b")" = "$(repo_id_of "$PLACE_A/wt-b")" ]
  [ "$(linked_id_of "$PLACE_A/wt-b")" = "$A_ID" ]
}

@test "deleted-cwd: the children of a location are identified without starting git for each of them" {  # 子が 2 つでも 6 つでも git の起動回数は同じ
  place_a
  mkdir -p "$BATS_TEST_TMPDIR/gitbin"
  local real; real="$(command -v git)"
  printf '#!/bin/sh\necho x >> "%s"\nexec "%s" "$@"\n' "$BATS_TEST_TMPDIR/git.log" "$real" > "$BATS_TEST_TMPDIR/gitbin/git"
  chmod +x "$BATS_TEST_TMPDIR/gitbin/git"
  add_worktree "$MAIN_A" "$PLACE_A/wt-b"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone1" 1000000 | cl_write_log a
  : > "$BATS_TEST_TMPDIR/git.log"
  PATH="$BATS_TEST_TMPDIR/gitbin:$PATH" facts
  local two; two=$(wc -l < "$BATS_TEST_TMPDIR/git.log" | tr -d ' ')
  check_rows 'by["r1"]["repo_id"] == argv[0]' "$A_ID"
  local n; for n in c d e f; do add_worktree "$MAIN_A" "$PLACE_A/wt-$n"; done
  : > "$BATS_TEST_TMPDIR/git.log"
  PATH="$BATS_TEST_TMPDIR/gitbin:$PATH" facts
  check_rows 'by["r1"]["repo_id"] == argv[0]' "$A_ID"
  [ "$(wc -l < "$BATS_TEST_TMPDIR/git.log" | tr -d ' ')" = "$two" ]
}

@test "deleted-cwd: a child whose .git file cannot be resolved is left out and the rest decide" {  # gitdir の指す先が無い子・gitdir の行が無い子は数えず、残りが A だけなら A。残りが 0 件なら不明
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone1" 1000000 | cl_write_log a
  mkdir -p "$PLACE_A/stale"
  printf 'gitdir: %s\n' "$BATS_TEST_TMPDIR/no-such/.git/worktrees/stale" > "$PLACE_A/stale/.git"
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and by["r1"]["repo_inferred"] is True' "$A_ID"
  printf 'not a gitdir line\n' > "$PLACE_A/stale/.git"
  facts
  check_rows 'by["r1"]["repo_id"] == argv[0] and by["r1"]["repo_inferred"] is True' "$A_ID"
  mkdir -p "$BATS_TEST_TMPDIR/ws-stale/ra/stale"
  printf 'gitdir: %s\n' "$BATS_TEST_TMPDIR/no-such/.git/worktrees/stale" > "$BATS_TEST_TMPDIR/ws-stale/ra/stale/.git"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/ws-stale/ra/gone1" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

@test "deleted-cwd: with an unresolvable child left out, the rest in two repositories stay unknown" {  # 残骸の子 1 つと、A と B の作業ツリーが 1 つずつ → 不明
  place_a
  add_worktree "$MAIN_B" "$PLACE_A/wt-b"
  mkdir -p "$PLACE_A/stale"
  printf 'gitdir: %s\n' "$BATS_TEST_TMPDIR/no-such/.git/worktrees/stale" > "$PLACE_A/stale/.git"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone1" 1000000 | cl_write_log a
  facts
  check_rows 'by["r1"]["repo_id"] == "不明" and "repo_inferred" not in by["r1"]'
}

# ---- cost-ledger-cost-command: issue の合計と「推定で数えた行」 --------------

@test "deleted-cwd: acceptance: a row whose cwd was gone before the ledger saw it is counted for the issue" {  # 直す対象。合計 $1.00 に入り、推定で数えた行が 1 件 $1.00、リポジトリ不明は出ない
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  run issue_a 42
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == 'コスト: $1.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"$INFERRED_ONE"* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"リポジトリ不明"* ]]
  issue_a 42 --json | check 'near(d["total_usd"], 1.0) and d["inferred_repo_messages"] == 1 and near(d["inferred_repo_usd"], 1.0) and d["unknown_repo_messages"] == 0'
  # 台帳に書かれた行も印を持つ
  grep -q '"repo_inferred": true' "$LEDGER"
}

@test "deleted-cwd: the same row is counted when the logs are read directly" {  # 台帳が未設定でも同じ値
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42" | cl_write_log a
  run issue_a 42
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $1.00 '* ]]
  [[ "$output" == *"$INFERRED_ONE"* ]]
  issue_a 42 --json | check 'd["inferred_repo_messages"] == 1 and near(d["inferred_repo_usd"], 1.0)'
}

@test "deleted-cwd: the inferred line follows the unknown line and counts only inferred rows" {  # 確定 1 行・推定 1 行・不明 1 行 → 合計 $2.00、不明 1 件、推定 1 件。不明の行の次に推定の行
  place_a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/wt1" 1000000 "gh issue view 42" | cl_write_log a
  cl_row S2 r2 2026-09-01T00:00:02.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42" | cl_write_log b
  cl_row S3 r3 2026-09-01T00:00:03.000Z feat/x "/nonexistent-750/x" 1000000 "gh issue view 42" | cl_write_log c
  export COST_LEDGER_PATH="$LEDGER"
  run issue_a 42
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $2.00 '* ]] || { echo "$output"; return 1; }
  local at=-1 n
  for n in "${!lines[@]}"; do [[ "${lines[$n]}" == "  リポジトリ不明: 1 件 \$1.00"* ]] && at=$n; done
  [ "$at" -ge 0 ]
  [ "${lines[$((at + 1))]}" = "$INFERRED_ONE" ]
  issue_a 42 --json | check 'near(d["total_usd"], 2.0) and d["inferred_repo_messages"] == 1 and near(d["inferred_repo_usd"], 1.0) and d["unknown_repo_messages"] == 1'
}

@test "deleted-cwd: acceptance: a row appended before its cwd was deleted is still counted, with no inferred line" {  # issue の受け入れ条件 1 件目（回帰）。追記 → cwd を消す → 合計は同じ $1.00 で、推定の行は出ない
  place_a
  add_worktree "$MAIN_A" "$BATS_TEST_TMPDIR/elsewhere/wt9"
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$BATS_TEST_TMPDIR/elsewhere/wt9" 1000000 "gh issue view 42" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  sync
  local before; before="$(issue_a 42 --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["total_usd"])')"
  rm -rf "$BATS_TEST_TMPDIR/elsewhere"
  run issue_a 42
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $1.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"推定で数えた行"* ]]
  [[ "$output" != *"リポジトリ不明"* ]]
  issue_a 42 --json | check "near(d['total_usd'], $before) and near(d['total_usd'], 1.0) and d['inferred_repo_messages'] == 0 and d['inferred_repo_usd'] == 0"
}

@test "deleted-cwd: acceptance: a row inferred to another repository is neither counted nor reported as unknown" {  # B の置き場の削除済み cwd で #42 を触った行は、A の合計にも不明にも推定にも入らない
  place_a
  place_b
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_A/gone" 1000000 "gh issue view 42" | cl_write_log a
  cl_row S2 r2 2026-09-01T00:00:02.000Z feat/x "$PLACE_B/gone" 1000000 "gh issue view 42" | cl_write_log b
  export COST_LEDGER_PATH="$LEDGER"
  issue_a 42 --json | check 'near(d["total_usd"], 1.0) and d["messages"] == 1 and d["unknown_repo_messages"] == 0 and d["inferred_repo_messages"] == 1'
  run python3 "$CL" issue 42 --repo "$MAIN_B"
  [[ "${lines[0]}" == 'コスト: $1.00 '* ]]
  # A の行が無ければ、A から見た合計は 0 で、不明も推定も出ない
  rm -rf "$CONFIG_DIR/projects/a" "$LEDGER" "$LEDGER.state.sqlite"
  run issue_a 42
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $0.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"リポジトリ不明"* ]]
  [[ "$output" != *"推定で数えた行"* ]]
}

# ---- cost-ledger-persistence: 補正行の追記（ledger-sync --rescan） -----------

# 置き場がまだ無いうちに取り込んで「不明」の行を台帳に書く。S1 が 2 行、S2 が 1 行（どれも #42 の区間）
unknown_ledger() {
  {
    cl_row S1 r1 2026-09-01T00:00:05.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42"
    cl_row S1 r2 2026-09-01T00:00:03.000Z feat/x "$PLACE_A/wt3" 1000000
  } | cl_write_log a
  cl_row S2 r3 2026-09-01T00:00:07.000Z feat/y "$PLACE_A/wt2" 1000000 "gh issue view 42" | cl_write_log b
  export COST_LEDGER_PATH="$LEDGER"
  sync
  [ "$(ledger_lines)" = "3" ]
  [ "$(grep -c '"repo_id": "不明"' "$LEDGER")" = "3" ]
}

@test "deleted-cwd: --rescan appends one fix row per session and branch and leaves old rows alone" {  # 既存の 3 行は 1 バイトも変わらず、補正行が組ごとに 1 行（計 2 行）。欄は spec のとおり
  unknown_ledger
  place_a
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
  local size; size=$(wc -c < "$LEDGER" | tr -d ' ')
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(head -c "$size" "$LEDGER" | cmp - "$BATS_TEST_TMPDIR/before.jsonl"; echo $?)" = "0" ]
  [ "$(ledger_lines)" = "5" ]
  tail -n 2 "$LEDGER" > "$OUT"
  check_rows 'sorted(by) == sorted("repo-fix#%s#%s#%s" % (s, b, argv[0]) for s, b in (("S1", "feat/x"), ("S2", "feat/y")))' "$A_ID"
  check_rows 'all(r["repo_fix"] is True and r["continuation"] is True and r["repo_id"] == argv[0] and r["issues"] == [] and not r["post_marker"] and r["model"] == "" and r["is_sidechain"] is False and "uuid" not in r and "source_offset" not in r and "repo_inferred" not in r and [r[k] for k in ("input_tokens", "output_tokens", "cache_write_5m_tokens", "cache_write_1h_tokens", "cache_read_tokens")] == [0] * 5 for r in rows)' "$A_ID"
  # timestamp は、その組の不明の行のうち最も早い値
  check_rows '{(r["session_id"], r["branch"]): r["timestamp"] for r in rows} == {("S1", "feat/x"): "2026-09-01T00:00:03.000Z", ("S2", "feat/y"): "2026-09-01T00:00:07.000Z"}'
}

@test "deleted-cwd: a second --rescan and a --rescan after the state file is removed append nothing" {  # 補正行は 2 回目に増えない
  unknown_ledger
  place_a
  sync --rescan
  [ "$(ledger_lines)" = "5" ]
  sync --rescan
  [ "$(ledger_lines)" = "5" ]
  rm -f "$LEDGER.state.sqlite"*
  sync --rescan
  [ "$(ledger_lines)" = "5" ]
}

@test "deleted-cwd: no fix row for a group that also has a cwd that cannot be inferred" {  # S1 に推定できない cwd が混ざる → S1 には書かず、S2 にだけ書く
  {
    cl_row S1 r1 2026-09-01T00:00:05.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42"
    cl_row S1 r2 2026-09-01T00:00:06.000Z feat/x "/nonexistent-750/x" 1000000
  } | cl_write_log a
  cl_row S2 r3 2026-09-01T00:00:07.000Z feat/y "$PLACE_A/wt2" 1000000 | cl_write_log b
  export COST_LEDGER_PATH="$LEDGER"
  sync
  place_a
  sync --rescan
  [ "$(fix_rows)" = "1" ]
  grep -q '"request_id": "repo-fix#S2#feat/y#' "$LEDGER"
}

@test "deleted-cwd: no fix row for a group whose cwds resolve to two repositories" {  # 同じ組に A の置き場の cwd と B の置き場の cwd → 書かない
  {
    cl_row S1 r1 2026-09-01T00:00:05.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42"
    cl_row S1 r2 2026-09-01T00:00:06.000Z feat/x "$PLACE_B/wt2" 1000000
  } | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  sync
  place_a
  place_b
  sync --rescan
  [ "$(fix_rows)" = "0" ]
}

@test "deleted-cwd: no fix row for a group that has an assistant row without cwd" {  # cwd の欄が無い応答の行（と空の cwd の行）が同じ組にある → 書かない
  {
    cl_row S1 r1 2026-09-01T00:00:05.000Z feat/x "$PLACE_A/wt2" 1000000 "gh issue view 42"
    cl_row S1 r2 2026-09-01T00:00:06.000Z feat/x "$PLACE_A/wt2" 1000000 \
      | python3 -c 'import json, sys; d = json.load(sys.stdin); del d["cwd"]; print(json.dumps(d))'
  } | cl_write_log a
  {
    cl_row S2 r3 2026-09-01T00:00:05.000Z feat/y "$PLACE_A/wt2" 1000000 "gh issue view 42"
    cl_row S2 r4 2026-09-01T00:00:06.000Z feat/y "" 1000000
  } | cl_write_log b
  export COST_LEDGER_PATH="$LEDGER"
  sync
  place_a
  sync --rescan
  [ "$(fix_rows)" = "0" ]
}

@test "deleted-cwd: a group whose conversation log is gone gets no fix row" {  # 会話ログが消えた組は cwd が分からない → 書かない（終了コード 0）
  unknown_ledger
  place_a
  rm -rf "$CONFIG_DIR/projects/b"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ]
  [ "$(fix_rows)" = "1" ]
  grep -q '"request_id": "repo-fix#S1#feat/x#' "$LEDGER"
}

@test "deleted-cwd: a plain ledger-sync and the Stop hook never write fix rows" {  # --rescan なしと hook は補正行を書かない
  unknown_ledger
  place_a
  sync
  echo '{}' | sh "$HOOK"
  # 差分があるときも同じ
  cl_row S1 r9 2026-09-01T00:00:09.000Z feat/x "/nonexistent-750/x" 1000000 | cl_write_log c
  sync
  cl_row S1 r10 2026-09-01T00:00:10.000Z feat/x "/nonexistent-750/x" 1000000 | cl_write_log d
  echo '{}' | sh "$HOOK"
  [ "$(ledger_lines)" = "5" ]
  [ "$(fix_rows)" = "0" ]
}

# ---- cost-ledger-persistence: 台帳を読むときに補正行を当てる -----------------

@test "deleted-cwd: after the fix rows the unknown rows are counted for the issue" {  # 補正前は不明 3 件 $3.00・合計 $0.00、補正後は合計 $3.00 で不明なし、推定 3 件
  unknown_ledger
  place_a
  run issue_a 42
  [[ "${lines[0]}" == 'コスト: $0.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" == *'リポジトリ不明: 3 件 $3.00'* ]]
  sync --rescan
  run issue_a 42
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $3.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"リポジトリ不明"* ]]
  [[ "$output" == *'  推定で数えた行: 3 件 $3.00（'* ]]
  issue_a 42 --json | check 'near(d["total_usd"], 3.0) and d["messages"] == 3 and d["unknown_repo_messages"] == 0 and d["inferred_repo_messages"] == 3 and near(d["inferred_repo_usd"], 3.0)'
}

@test "deleted-cwd: rows fixed to another repository are neither counted nor unknown" {  # 補正が A を指す台帳を B から読む → 合計 $0.00 で不明も出ない
  unknown_ledger
  place_a
  sync --rescan
  run python3 "$CL" issue 42 --repo "$MAIN_B"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $0.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"リポジトリ不明"* ]]
  [[ "$output" != *"推定で数えた行"* ]]
}

# 補正行を手で 1 行足す（取り消しの手順と同じ形）。$1=session_id $2=branch $3=repo_id
append_fix() {
  python3 - "$LEDGER" "$@" <<'PY'
import json, sys
ledger, session, branch, repo = sys.argv[1:5]
row = {"request_id": "repo-fix#%s#%s#%s" % (session, branch, repo), "timestamp": "2026-09-01T00:00:00.000Z",
       "session_id": session, "is_sidechain": False, "repo_id": repo, "branch": branch, "model": "",
       "input_tokens": 0, "output_tokens": 0, "cache_write_5m_tokens": 0, "cache_write_1h_tokens": 0,
       "cache_read_tokens": 0, "issues": [], "post_marker": None, "continuation": True, "repo_fix": True}
with open(ledger, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(row, ensure_ascii=False) + "\n")
PY
}

@test "deleted-cwd: two fix rows naming different repositories leave the group unknown" {  # S1 に B の補正行を足す → S1 の 2 行は不明に戻り、S2 の 1 行だけ合計に入る
  unknown_ledger
  place_a
  sync --rescan
  append_fix S1 feat/x "$B_ID"
  run issue_a 42
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $1.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" == *'リポジトリ不明: 2 件 $2.00'* ]] || { echo "$output"; return 1; }
  issue_a 42 --json | check 'near(d["total_usd"], 1.0) and d["unknown_repo_messages"] == 2 and near(d["unknown_repo_usd"], 2.0) and d["inferred_repo_messages"] == 1'
  # B から見ても S1 は B の行にならない
  python3 "$CL" issue 42 --repo "$MAIN_B" --json | check 'near(d["total_usd"], 0.0) and d["unknown_repo_messages"] == 2'
}

@test "deleted-cwd: fix rows never show up in facts, and fixed rows are marked inferred" {  # facts に repo_fix の行は無く、補正された 3 行は A で repo_inferred が true
  unknown_ledger
  place_a
  sync --rescan
  python3 "$CL" facts > "$OUT"
  check_rows 'len(rows) == 3 and not any("repo_fix" in r for r in rows) and all(r["repo_id"] == argv[0] and r["repo_inferred"] is True for r in rows)' "$A_ID"
  # 台帳のファイルは読むだけで変わらない（不明のまま残っている）
  [ "$(grep -c '"repo_id": "不明"' "$LEDGER")" = "3" ]
}

@test "deleted-cwd: a fix row does not change a row whose repository is known" {  # 識別子の決まっている行は、同じ組に補正行があっても変わらない
  place_b
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$PLACE_B/wt1" 1000000 "gh issue view 42" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  sync
  append_fix S1 feat/x "$A_ID"
  python3 "$CL" facts > "$OUT"
  check_rows 'len(rows) == 1 and by["r1"]["repo_id"] == argv[0] and "repo_inferred" not in by["r1"]' "$B_ID"
  issue_a 42 --json | check 'near(d["total_usd"], 0.0) and d["unknown_repo_messages"] == 0'
}

@test "deleted-cwd: fix rows do not change the branch total, the message count or the report" {  # ブランチの集計（PR の経路と同じ引き方）の金額とメッセージ数は補正の前後で同じ
  unknown_ledger
  place_a
  python3 "$CL" branch feat/x > "$BATS_TEST_TMPDIR/branch-before"
  sync --rescan
  python3 "$CL" branch feat/x > "$BATS_TEST_TMPDIR/branch-after"
  grep -q '対象: ブランチ feat/x（2 メッセージ）' "$BATS_TEST_TMPDIR/branch-after"
  [[ "$(head -n 1 "$BATS_TEST_TMPDIR/branch-after")" == 'コスト: $2.00 '* ]]
  diff <(sed -n 2,4p "$BATS_TEST_TMPDIR/branch-before") <(sed -n 2,4p "$BATS_TEST_TMPDIR/branch-after")
}

@test "deleted-cwd: a fix row on a closing PR's head branch leaves closing_prs and the combined total unchanged" {  # load_branches_facts は補正行を取り除かないが、closing_prs[].usd と combined_total_usd は補正行の無い台帳と同じ
  unknown_ledger
  place_a
  issue_a 42 --closing-pr 300:feat/x --json > "$BATS_TEST_TMPDIR/before.json"
  sync --rescan
  [ "$(grep -c '"request_id": "repo-fix#S1#feat/x#' "$LEDGER")" = "1" ]
  issue_a 42 --closing-pr 300:feat/x --json > "$BATS_TEST_TMPDIR/after.json"
  python3 - "$BATS_TEST_TMPDIR/before.json" "$BATS_TEST_TMPDIR/after.json" <<'PY'
import json, sys
before, after = (json.load(open(p)) for p in sys.argv[1:3])
assert before["closing_prs"] == after["closing_prs"] == [{"number": 300, "branch": "feat/x", "usd": 2.0}], (before, after)
# 補正の前は S2（feat/y）の 1 行が不明で PR の外に数えられず、補正の後は PR の外に $1.00 が入る
assert before["combined_total_usd"] == 2.0 and after["combined_total_usd"] == 3.0, (before, after)
PY
  # 同じ台帳から補正行だけを除いた写しでも、PR の分は同じ値（補正行は金額にも件数にも出ない）
  grep -v '"repo_fix": true' "$LEDGER" > "$BATS_TEST_TMPDIR/ledger-home/without.jsonl"
  COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/without.jsonl" issue_a 42 --closing-pr 300:feat/x --json \
    | check 'd["closing_prs"] == [{"number": 300, "branch": "feat/x", "usd": 2.0}]'
}

@test "deleted-cwd: with only the head branch's rows, the combined total equals the ledger without the fix row" {  # spec の Scenario そのまま: 補正行を 1 行含む台帳と、補正行の無い同じ台帳で closing_prs[].usd と combined_total_usd が同じ
  place_b
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "$MAIN_A" 1000000 "gh issue view 42" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  sync
  issue_a 42 --closing-pr 300:feat/x --json > "$BATS_TEST_TMPDIR/before.json"
  append_fix S1 feat/x "$B_ID"
  issue_a 42 --closing-pr 300:feat/x --json > "$BATS_TEST_TMPDIR/after.json"
  python3 - "$BATS_TEST_TMPDIR/before.json" "$BATS_TEST_TMPDIR/after.json" <<'PY'
import json, sys
before, after = (json.load(open(p)) for p in sys.argv[1:3])
assert before["closing_prs"] == after["closing_prs"] == [{"number": 300, "branch": "feat/x", "usd": 1.0}], (before, after)
assert before["combined_total_usd"] == after["combined_total_usd"] == 1.0, (before, after)
assert before["messages"] == after["messages"] == 1, (before, after)
PY
}

# ---- cost-ledger-cost-command: エピックと番号なし ---------------------------

# 呼び出しを控える gh（epic.bats と同じ形）。#10 の子が #11（closed）。$1=#11 を閉じた PR のヘッドブランチ（空可）
epic_gh() {
  export EPIC_GQL_DIR="$BATS_TEST_TMPDIR/gql"
  mkdir -p "$EPIC_GQL_DIR"
  local prs='{"nodes": [], "pageInfo": {"hasNextPage": false}}' child_prs
  child_prs="$prs"
  if [ -n "${1:-}" ]; then
    child_prs='{"nodes": [{"number": 300, "headRefName": "'"$1"'", "isCrossRepository": false, "baseRepository": {"nameWithOwner": "acme/ra"}}], "pageInfo": {"hasNextPage": false}}'
  fi
  printf '{"data": {"repository": {"nameWithOwner": "acme/ra", "issue": {"number": 10, "title": "epic", "state": "OPEN", "closedByPullRequestsReferences": %s, "subIssues": {"nodes": [{"number": 11, "title": "child a", "state": "CLOSED", "repository": {"nameWithOwner": "acme/ra"}, "subIssuesSummary": {"total": 0}, "closedByPullRequestsReferences": %s}], "pageInfo": {"hasNextPage": false}}}}}}\n' \
    "$prs" "$child_prs" > "$EPIC_GQL_DIR/10.json"
  cl_fake_gh <<'EOF'
if [ "$1" = api ] && [ "$2" = graphql ]; then
  n=""
  for arg in "$@"; do case "$arg" in number=*) n="${arg#number=}" ;; esac; done
  [ -f "$EPIC_GQL_DIR/$n.json" ] || exit 1
  cat "$EPIC_GQL_DIR/$n.json"
  exit 0
fi
for arg in "$@"; do
  case "$arg" in
    */pulls/*) exit 1 ;;
    */issues/*)
      n="${arg##*/}"
      if [ "$n" = 10 ]; then echo "10 1"; else echo "$n 0"; fi
      exit 0 ;;
  esac
done
exit 1
EOF
}

epic() { python3 "$CL" cost 10 --repo "$MAIN_A" --no-drift-check "$@"; }

@test "deleted-cwd: epic: an inferred row of a child issue is counted and reported" {  # 子 #11 を触った削除済み cwd の行 → #11 の own_usd と total_usd に入り、inferred_repo_* に出る。不明は 0
  place_a
  epic_gh
  cl_row S1 r1 2026-09-01T00:00:01.000Z main "$PLACE_A/gone" 1000000 "gh issue view 11" | cl_write_log a
  cl_row S2 r2 2026-09-01T00:00:02.000Z main "$MAIN_A" 1000000 "gh issue view 11" | cl_write_log b
  export COST_LEDGER_PATH="$LEDGER"
  epic --json | check 'near(d["total_usd"], 2.0) and near(i[11]["own_usd"], 2.0) and d["unknown_repo_messages"] == 0 and d["inferred_repo_messages"] == 1 and near(d["inferred_repo_usd"], 1.0)'
  run epic
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $2.00 '* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"$INFERRED_ONE"* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"リポジトリ不明"* ]]
}

@test "deleted-cwd: epic: the inferred line follows the unknown line, and is absent without inferred rows" {  # 不明 1 件と推定 1 件 → 不明の行の次に推定の行。推定が無ければ行は無く --json は 0
  place_a
  epic_gh
  cl_row S2 r2 2026-09-01T00:00:02.000Z main "$MAIN_A" 1000000 "gh issue view 11" | cl_write_log b
  cl_row S3 r3 2026-09-01T00:00:03.000Z main "/nonexistent-750/x" 1000000 "gh issue view 11" | cl_write_log c
  export COST_LEDGER_PATH="$LEDGER"
  run epic
  [[ "$output" != *"推定で数えた行"* ]]
  epic --json | check 'd["inferred_repo_messages"] == 0 and d["inferred_repo_usd"] == 0 and d["unknown_repo_messages"] == 1'
  cl_row S1 r1 2026-09-01T00:00:01.000Z main "$PLACE_A/gone" 1000000 "gh issue view 11" | cl_write_log a
  run epic
  [ "$status" -eq 0 ]
  local at=-1 n
  for n in "${!lines[@]}"; do [[ "${lines[$n]}" == "  リポジトリ不明: 1 件 \$1.00"* ]] && at=$n; done
  [ "$at" -ge 0 ] || { echo "$output"; return 1; }
  [ "${lines[$((at + 1))]}" = "$INFERRED_ONE" ]
}

@test "deleted-cwd: epic: a row inferred to another repository is not counted anywhere" {  # B の置き場の削除済み cwd で #11 を触った行 → total にも unknown にも inferred にも入らない
  place_a
  place_b
  epic_gh
  cl_row S1 r1 2026-09-01T00:00:01.000Z main "$PLACE_B/gone" 1000000 "gh issue view 11" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  epic --json | check 'd["total_usd"] == 0 and d["unknown_repo_usd"] == 0 and d["unknown_repo_messages"] == 0 and d["inferred_repo_usd"] == 0 and d["inferred_repo_messages"] == 0'
}

@test "deleted-cwd: epic: inferred rows assigned through a head branch are not reported as inferred" {  # ヘッドブランチ feat/a の行はブランチ名で数えるので、推定の行に数えない
  place_a
  epic_gh feat/a
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/a "$PLACE_A/gone" 1000000 "gh issue view 11" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  epic --json | check 'near(d["total_usd"], 1.0) and near(i[11]["own_usd"], 1.0) and d["inferred_repo_messages"] == 0 and d["inferred_repo_usd"] == 0'
  run epic
  [[ "$output" != *"推定で数えた行"* ]]
}

@test "deleted-cwd: epic: rows fixed by a fix row are counted and reported" {  # 補正行で直った不明の行も、エピックの合計と推定の行に入る
  epic_gh
  cl_row S1 r1 2026-09-01T00:00:01.000Z main "$PLACE_A/gone" 1000000 "gh issue view 11" | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  sync
  place_a
  epic --json | check 'd["total_usd"] == 0 and d["unknown_repo_messages"] == 1'
  sync --rescan
  epic --json | check 'near(d["total_usd"], 1.0) and d["unknown_repo_messages"] == 0 and d["inferred_repo_messages"] == 1 and near(d["inferred_repo_usd"], 1.0)'
}

@test "deleted-cwd: cost without a number shows the inferred line" {  # 現在のブランチと同名の、削除済み cwd の行が合計に入り、推定で数えた行が出る
  place_a
  local branch; branch="$(git -C "$PLACE_A/wt1" rev-parse --abbrev-ref HEAD)"
  {
    cl_row S1 r1 2026-09-01T00:00:01.000Z "$branch" "$PLACE_A/wt1" 1000000
    cl_row S1 r2 2026-09-01T00:00:02.000Z "$branch" "$PLACE_A/gone" 1000000
    cl_row S1 r3 2026-09-01T00:00:03.000Z "$branch" "/nonexistent-750/x" 1000000
  } | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" cost --repo "$PLACE_A/wt1" --no-drift-check
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == 'コスト: $2.00 '* ]] || { echo "$output"; return 1; }
  local at=-1 n
  for n in "${!lines[@]}"; do [[ "${lines[$n]}" == "  リポジトリ不明: 1 件 \$1.00"* ]] && at=$n; done
  [ "$at" -ge 0 ]
  [ "${lines[$((at + 1))]}" = "$INFERRED_ONE" ]
}

@test "deleted-cwd: cost without a number shows no inferred line when nothing was inferred" {  # 推定の行が無ければ出さない
  place_a
  local branch; branch="$(git -C "$PLACE_A/wt1" rev-parse --abbrev-ref HEAD)"
  cl_row S1 r1 2026-09-01T00:00:01.000Z "$branch" "$PLACE_A/wt1" 1000000 | cl_write_log a
  run python3 "$CL" cost --repo "$PLACE_A/wt1" --no-drift-check
  [ "$status" -eq 0 ]
  [[ "$output" != *"推定で数えた行"* ]]
}
