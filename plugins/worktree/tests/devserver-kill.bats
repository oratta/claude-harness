#!/usr/bin/env bats
#
# Tests for change wt-clean-devserver-kill.
# spec: wt-clean-devserver-cleanup.
#
# Guards that `git worktree remove` is never called without first stopping
# any dev-server process left running under the worktree path (issue #39:
# a `next dev` process tree survived 2+ days after `wt-clean` removed its
# worktree, causing a rebuild loop that exhausted CPU/RAM).

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- detection ---

@test "skill: wt-clean SKILL.md defines the kill_devserver_under helper" {
  grep -q 'kill_devserver_under' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md detects processes via lsof +D" {
  grep -q 'lsof +D' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md falls back to pgrep -f when lsof is unavailable" {
  grep -q 'pgrep -f' "$WT_CLEAN_SKILL"
  grep -q 'command -v lsof' "$WT_CLEAN_SKILL"
}

# --- signal escalation ---

@test "skill: wt-clean SKILL.md sends SIGTERM before SIGKILL" {
  grep -q 'kill -TERM' "$WT_CLEAN_SKILL"
  grep -q 'kill -KILL' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md re-checks liveness before escalating to SIGKILL" {
  grep -q 'kill -0' "$WT_CLEAN_SKILL"
}

# --- silent-kill prohibition ---

@test "skill: wt-clean SKILL.md logs stopped PIDs (no silent kill)" {
  grep -q '🔪' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md logs when no process is found" {
  grep -q 'プロセス残留チェック' "$WT_CLEAN_SKILL"
}

# --- scope guard: don't kill shells/editors or other worktrees ---

@test "skill: wt-clean SKILL.md excludes interactive shells/editors from kill" {
  grep -q 'bash|zsh|sh|fish' "$WT_CLEAN_SKILL"
  grep -q 'シェル/エディタと判定してスキップ' "$WT_CLEAN_SKILL"
}

# --- applied at every git worktree remove call site ---

@test "skill: kill_devserver_under is called at least once per git worktree remove site" {
  local removes calls
  removes=$(grep -c 'git worktree remove' "$WT_CLEAN_SKILL")
  calls=$(grep -c 'kill_devserver_under "\$WT"' "$WT_CLEAN_SKILL")
  # 1 definition site + 1 call per removal call site (5 removal call sites)
  [ "$calls" -ge 5 ]
  [ "$removes" -ge 5 ]
}

@test "skill: 🔴 forced-remove section documents the process-stop step" {
  awk '/## 🔴 Active worktree の強制破棄/,0' "$WT_CLEAN_SKILL" | grep -q 'kill_devserver_under\|プロセス'
}

# --- zsh compatibility (issue #66) ---
#
# The Bash tool runs zsh on macOS, and this skill is executed by reading SKILL.md
# and running its snippets inline. `pid="${entry%%(*}"` was a zsh parse error
# (`bad pattern: (*`) that killed the whole shell *after* SIGTERM was sent and
# *before* the SIGKILL fallback and `git worktree remove` — i.e. the #39 guard
# died in exactly the situation it exists for.

@test "skill: kill_devserver_under never uses a pattern metachar as a field separator" {
  # `(` `)` `[` `]` `#` `~` inside ${var%%...} / ${var##...} are patterns in zsh.
  # Comment lines are stripped first: the fix deliberately quotes the broken form
  # in a warning comment, and that must not satisfy (or trip) this assertion.
  local snippet="${BATS_TEST_TMPDIR}/kill-sep.sh"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" \
    | grep -v '^[[:space:]]*#' >"$snippet"
  [ -s "$snippet" ]
  run grep -Eq '\$\{entry(%%|##)[^}]*[][()~]' "$snippet"
  [ "$status" -ne 0 ]
  grep -q 'killed+=("$pid|$comm")' "$snippet"
  grep -q 'pid="${entry%%|\*}"' "$snippet"
  grep -q 'comm="${entry##\*|}"' "$snippet"
}

@test "skill: kill_devserver_under declares comm once, not inside the loop" {
  # zsh prints `comm=<previous value>` on every re-declaration of an existing
  # local, injecting garbage lines into the stop report. bash stays silent.
  local snippet="${BATS_TEST_TMPDIR}/kill-local.sh"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  run grep -Eq '^[[:space:]]+local comm$' "$snippet"
  [ "$status" -ne 0 ]
  grep -q 'local killed=() skipped=() comm' "$snippet"
}

@test "skill: documents that the embedded snippets must also run under zsh" {
  grep -q 'zsh' "$WT_CLEAN_SKILL"
  grep -Eq 'bad pattern|zsh 前提|zsh も含む' "$WT_CLEAN_SKILL"
}

wt_run_kill_snippet() {
  # $1 = shell, $2 = work dir. Echoes the combined output of a run of
  # kill_devserver_under over a directory holding two live processes:
  # one ordinary (dies on SIGTERM) and one that ignores SIGTERM.
  local shell="$1" dir="$2"
  local snippet="${BATS_TEST_TMPDIR}/kill-run.sh" driver="${BATS_TEST_TMPDIR}/kill-driver.sh"
  # kill_devserver_under depends on abs_path and proc_comm (both defined in Step -1).
  awk '/^abs_path\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  awk '/^proc_comm\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  mkdir -p "$dir"
  cat >"$driver" <<'DRIVER'
. "$1"
DIR="$2"
( cd "$DIR" && exec sleep 300 ) &
PID_NORMAL=$!
# perl, not a shell: shells are on kill_devserver_under's exclusion list.
( cd "$DIR" && exec perl -e '$SIG{TERM}="IGNORE"; sleep 300' ) &
PID_STUBBORN=$!
sleep 1
kill_devserver_under "$DIR"
echo "REACHED_END"
sleep 1
kill -0 "$PID_NORMAL"   2>/dev/null && echo "ALIVE_NORMAL"   || echo "DEAD_NORMAL"
kill -0 "$PID_STUBBORN" 2>/dev/null && echo "ALIVE_STUBBORN" || echo "DEAD_STUBBORN"
kill -KILL "$PID_NORMAL" "$PID_STUBBORN" 2>/dev/null
exit 0
DRIVER
  "$shell" "$driver" "$snippet" "$dir" 2>&1
}

@test "kill_devserver_under: runs to completion under zsh when processes are killed" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh  >/dev/null 2>&1 || skip "zsh unavailable"
  command -v perl >/dev/null 2>&1 || skip "perl unavailable"
  local out
  out="$(wt_run_kill_snippet zsh "${BATS_TEST_TMPDIR}/zsh-kill")"
  # 1. the function returned instead of aborting the shell (issue #66)
  [[ "$out" == *"REACHED_END"* ]]
  [[ "$out" != *"bad pattern"* ]]
  # 2. the SIGKILL fallback was reached for the SIGTERM-ignoring process
  [[ "$out" == *"SIGKILL で停止しました"* ]]
  # 3. both processes are actually gone
  [[ "$out" == *"DEAD_NORMAL"* ]]
  [[ "$out" == *"DEAD_STUBBORN"* ]]
  # 4. no stray `comm=...` line from a zsh local re-declaration
  run grep -Eq '^comm=' <<<"$out"
  [ "$status" -ne 0 ]
}

@test "kill_devserver_under: bash and zsh report the same PIDs and commands" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh  >/dev/null 2>&1 || skip "zsh unavailable"
  command -v perl >/dev/null 2>&1 || skip "perl unavailable"
  local out_bash out_zsh norm_bash norm_zsh
  out_bash="$(wt_run_kill_snippet bash "${BATS_TEST_TMPDIR}/b-kill")"
  out_zsh="$(wt_run_kill_snippet zsh  "${BATS_TEST_TMPDIR}/z-kill")"
  # Keep only the 🔪 lines and blank out the PIDs (they differ per run).
  norm_bash="$(grep '🔪' <<<"$out_bash" | sed -E 's/[0-9]+//g')"
  norm_zsh="$(grep  '🔪' <<<"$out_zsh"  | sed -E 's/[0-9]+//g')"
  [ -n "$norm_bash" ]
  [ "$norm_bash" = "$norm_zsh" ]
}

# --- verification checklist ---

@test "reference: wt-clean-verification.md adds a process-residue check" {
  grep -q 'プロセス残留' "$WT_CLEAN_VERIFICATION"
}

@test "skill: self-verification section references the process-residue check" {
  awk '/## 自己検証/,0' "$WT_CLEAN_SKILL" | grep -q 'プロセス'
}

# --- login shells must survive (2026-08-27) ---
#
# macOS の `ps -o comm=` は argv[0] を返すため、ターミナルのタブは `-/bin/zsh` になる。
# 旧実装の `basename -/bin/zsh` はハイフンをオプションと解釈して失敗し、comm が空文字に
# 潰れて除外リスト（bash|zsh|sh|...）に一致せず、削除対象 worktree に cd しているだけの
# タブを SIGKILL していた。除外リストのテストは文字列 grep しか無く、実際にシェルを
# 立てて除外が効くか一度も検証されていなかったため 3 度目を防げなかった。

wt_skill_fn() {
  # $1 = 関数名。SKILL.md からその関数の定義（`name() {` 〜 行頭 `}`）を丸ごと返す。
  awk -v fn="$1() {" 'index($0, fn)==1,/^}$/' "$WT_CLEAN_SKILL"
}

wt_comm_window() {
  # $1 = 関数名。その関数の中で、comm を取り出す行（`comm=$(proc_comm "$pid")`）から
  # 除外リストの `case "$comm" in` までの**非コメント行**を返す。この窓の中で comm を
  # 書き換える行があれば、それは片側だけの正規化（= 2 側が食い違う芽）である。
  # ⚠️ 「連続する comm= 代入」のような**形状**で切ってはならない（issue #190）。空行を挟んだ
  #    代入や `case ... comm=...;; esac` の形は形状マッチをすり抜ける。窓の境界を取り出し行と
  #    使用行に置けば、その間に何が書かれていても検査対象に入る。
  wt_skill_fn "$1" \
    | awk '/^[[:space:]]+comm=\$\(proc_comm "\$pid"\)$/{on=1; next}
           on && /^[[:space:]]+case "\$comm" in$/{exit}
           on && !/^[[:space:]]*(#|$)/{print}'
}

@test "skill: comm extraction does not shell out to basename" {
  # basename は (a) 先頭ハイフンをオプション扱いし (b) 最小 PATH で command not found になる。
  run grep -q 'xargs -I{} basename' "$WT_CLEAN_SKILL"
  [ "$status" -ne 0 ]
}

@test "skill: comm extraction strips a leading dash before taking the basename" {
  local lines
  lines=$(wt_skill_fn proc_comm)
  [[ "$lines" == *'comm=${comm#-}'* ]]
  [[ "$lines" == *'comm=${comm##*/}'* ]]
}

@test "skill: ps -o comm= is called only inside proc_comm" {
  # 正規化の定義を 1 箇所（Step -1 の proc_comm）に閉じる。他所で ps -o comm= を撃つ行が
  # 増えた時点で「独自の取り出し」が始まっているので、コメント行を除いた実コードで数える。
  local total inside
  total=$(grep -v '^[[:space:]]*#' "$WT_CLEAN_SKILL" | grep -c 'ps -o comm=')
  inside=$(wt_skill_fn proc_comm | grep -v '^[[:space:]]*#' | grep -c 'ps -o comm=')
  [ "$inside" = "1" ]
  [ "$total" = "1" ]
}

@test "skill: kill and detect sides extract comm identically" {
  # SKILL.md は「検出範囲と除外リストは kill_devserver_under と完全に同一に保つこと」と
  # 定めている。取り出しが片側だけ直ると、また片側だけがシェルを殺す。
  # 両側が同じ関数 proc_comm を 1 回だけ呼び、その結果を除外 case まで**一切加工しない**ことを
  # 固定する。加工の形（空行を挟む・case 文で書く・comm+= 等）に依存しない（issue #190）。
  local side body window
  for side in detect_active_procs_under kill_devserver_under; do
    body=$(wt_skill_fn "$side" | grep -v '^[[:space:]]*#')
    [ -n "$body" ]
    [ "$(printf '%s\n' "$body" | grep -c 'comm=$(proc_comm "$pid")')" = "1" ]
    # 窓が空なら、取り出し行か case 行のどちらかが見つからなかった = 検査できていない。
    # detect 側は `[ -n "$comm" ] || continue` が必ず窓に入るので、空は取り出し失敗を意味する。
    window=$(wt_comm_window "$side")
    if [ "$side" = "detect_active_procs_under" ]; then
      [ -n "$window" ]
    fi
    # 窓の中で comm へ書き込む行（comm= / comm+= / read comm / printf -v comm / declare comm=）
    run grep -Eq '(^|[^[:alnum:]_])comm(\+|\[[^]]*\])?=|(^|[[:space:];&|])read([[:space:]]+-[[:alnum:]]+)*[[:space:]]+comm([[:space:]]|$)|-v[[:space:]]+comm([[:space:]]|$)' <<<"$window"
    [ "$status" -ne 0 ]
    # 窓の中で ps を呼ぶ行（独自の取り出し）
    run grep -q 'ps -o comm=' <<<"$window"
    [ "$status" -ne 0 ]
  done
}

@test "skill: kill and detect sides refuse to run without proc_comm (fail-closed)" {
  # proc_comm 未定義で comm が常に空になると、detect 側は全プロセスを「既に死んでいる」と
  # 見なして削除許可側に倒れ、kill 側は除外リストに何も一致せずシェルまで停止する。
  # どちらも「未定義なら何もせず、そう表示する」ことを固定する。
  local side body
  for side in detect_active_procs_under kill_devserver_under; do
    body=$(wt_skill_fn "$side" | grep -v '^[[:space:]]*#')
    grep -q 'command -v proc_comm' <<<"$body"
  done
}

wt_build_comm_normaliser() {
  # SKILL.md 自身の proc_comm から関数を組み立てる（`ps` 呼び出しだけをテスト入力に
  # 差し替える）。ロジックを書き写さないので、SKILL.md が変われば必ずこのテストが追随する。
  local out="${BATS_TEST_TMPDIR}/comm-norm.sh"
  wt_skill_fn proc_comm \
    | sed 's|\$(ps -o comm= -p "\$pid" 2>/dev/null)|"$pid"|' >"$out"
  grep -q '^proc_comm() {' "$out"
  # 置換が効いたことを確認する。空振りすると proc_comm が本物の `ps -p '-/bin/zsh'` を呼び、
  # bash も zsh も空文字を返して「一致」になり、テストが常に通ってしまう。
  grep -q 'comm="$pid"' "$out"
  run grep -q 'ps -o comm=' "$out"
  [ "$status" -ne 0 ]
  echo "$out"
}

@test "comm extraction: login-shell argv[0] normalises onto the exclusion list" {
  local snippet
  snippet="$(wt_build_comm_normaliser)"
  # bats は `x="$(f)"` の f 失敗を代入経由では捕まえないため、本体側でも実測する。
  # これが無いと旧実装で snippet="" になり、空文字同士の比較でテストが常に通る。
  [ -s "$snippet" ]
  grep -q 'comm="$pid"' "$snippet"
  [ "$(bash -c ". '$snippet'; proc_comm '-/bin/zsh'")" = "zsh" ]
  [ "$(bash -c ". '$snippet'; proc_comm '-zsh'")"      = "zsh" ]
  [ "$(bash -c ". '$snippet'; proc_comm '/bin/zsh'")"  = "zsh" ]
  [ "$(bash -c ". '$snippet'; proc_comm '-/bin/bash'")" = "bash" ]
  # 非シェルは名前が変わらない（停止対象のまま）
  [ "$(bash -c ". '$snippet'; proc_comm '/usr/bin/perl'")" = "perl" ]
  [ "$(bash -c ". '$snippet'; proc_comm '/opt/homebrew/bin/node'")" = "node" ]
  # 取得できなかったケースは空のまま（診断側の「既に死んでいる」判定を壊さない）
  [ -z "$(bash -c ". '$snippet'; proc_comm ''")" ]
}

@test "comm extraction: normaliser agrees under bash and zsh" {
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  local snippet v
  snippet="$(wt_build_comm_normaliser)"
  # bats は `x="$(f)"` の f 失敗を代入経由では捕まえないため、本体側でも実測する。
  # これが無いと旧実装で snippet="" になり、空文字同士の比較でテストが常に通る。
  [ -s "$snippet" ]
  grep -q 'comm="$pid"' "$snippet"
  for v in '-/bin/zsh' '-zsh' '/bin/zsh' '/usr/bin/perl' ''; do
    [ "$(bash -c ". '$snippet'; proc_comm '$v'")" = "$(zsh -c ". '$snippet'; proc_comm '$v'")" ]
  done
}

@test "kill_devserver_under: does not kill a login shell under the worktree" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  # ⚠️ CI（ubuntu-latest）では必ず skip される。Linux の ps -o comm= は argv[0] ではなく
  #    実行ファイル名を返すため、偽タブの comm が `sleep` になりテストが意味を成さない。
  #    実プロセスでの検証は macOS 上でのみ行われる。
  [ "$(uname)" = "Darwin" ] || skip "ps -o comm= returns argv[0] only on BSD/macOS"
  local snippet="${BATS_TEST_TMPDIR}/kill-login.sh"
  local dir="${BATS_TEST_TMPDIR}/login-shell"
  awk '/^abs_path\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  awk '/^proc_comm\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  mkdir -p "$dir"

  # argv[0] をログインシェルの形にした偽タブ。実体は sleep なので rc も読まず終了する。
  ( cd "$dir" && exec -a "-/bin/zsh" sleep 30 ) &
  local shell_pid=$!
  # 比較用の停止対象（除外リストに無い名前）
  ( cd "$dir" && exec perl -e 'sleep 30' ) &
  local victim_pid=$!
  sleep 1

  local out
  out=$(bash -c ". '$snippet'; kill_devserver_under '$dir'" 2>&1)
  sleep 1

  local shell_alive victim_alive
  kill -0 "$shell_pid"  2>/dev/null && shell_alive=1  || shell_alive=0
  kill -0 "$victim_pid" 2>/dev/null && victim_alive=1 || victim_alive=0
  # `|| true` 必須。両方すでに死んでいるときだけ非ゼロになり、それは「ログインシェルが
  # 殺された = 退行が再発した」ケースそのもの。ここで打ち切ると肝心の assertion が出ない。
  kill -KILL "$shell_pid" "$victim_pid" 2>/dev/null || true

  # ログインシェルは生存し、スキップとして報告される
  [ "$shell_alive" = "1" ]
  [[ "$out" == *"シェル/エディタと判定してスキップ"* ]]
  [[ "$out" == *"${shell_pid}(zsh)"* ]]
  # 非シェルは従来どおり停止される（issue #39 のガードを緩めていない）
  [ "$victim_alive" = "0" ]
  [[ "$out" == *"${victim_pid}(perl)"* ]]
}
