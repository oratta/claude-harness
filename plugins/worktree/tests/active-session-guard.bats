#!/usr/bin/env bats
#
# Tests for issue #77 — active-session guard.
#
# Guards that a worktree with a live session under it is never auto-deleted,
# even when git says it is perfectly clean (merged / no dirty / no LLM/).
# Regression source: 2026-08-01, flatmate repo — a design-discussion worktree
# was classified 🟢 Safe and auto-deleted, and kill_devserver_under stopped the
# claude session running under it. Such sessions leave no commits and no LLM/,
# so neither the git diagnosis nor prohibition 2 could catch it.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- the absolute prohibition itself ---

@test "skill: wt-clean SKILL.md declares the active-signal absolute prohibition" {
  grep -q '稼働シグナル' "$WT_CLEAN_SKILL"
  # 禁則 3 は「プロセス / セッションログ / worktree ロック」の 3 シグナルを覆う
  grep -Eq '^3\. \*\*配下にプロセスが稼働中／当日のセッションログがある／worktree がロックされている場合は自動処理しない' "$WT_CLEAN_SKILL"
}

@test "skill: worktree lock is one of the active signals" {
  grep -q 'detect_worktree_lock' "$WT_CLEAN_SKILL"
  # ロックは ACTIVE_SIGNAL に合流し、Pass 1 の自動処理を止める
  grep -q 'WT_LOCKED=$(detect_worktree_lock' "$WT_CLEAN_SKILL"
  grep -q 'worktree ロック: \$WT_LOCKED' "$WT_CLEAN_SKILL"
}

@test "skill: lock is never auto-unlocked in Pass 1" {
  # 解除は Pass 2 でユーザーが削除を選んだ対象のみ
  grep -q 'Pass 1 での自動 unlock は禁止' "$WT_CLEAN_SKILL"
  # 解除失敗・状態不明なら remove に進まない
  grep -q 'unlock_if_locked "$WT" || exit 1' "$WT_CLEAN_SKILL"
}

@test "skill: lock detection does not parse porcelain by whitespace" {
  # パスに空白がある worktree のロックを取りこぼす解析を禁じている
  grep -q '空白区切りで解析してはならない' "$WT_CLEAN_SKILL"
  # 検査不能を「ロックなし」に倒さない
  grep -q 'ロック状態不明' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps the later prohibitions renumbered (branch name, LLM escrow)" {
  grep -Eq '^4\. \*\*削除判定は必ず実ブランチ名で行う' "$WT_CLEAN_SKILL"
  grep -Eq '^5\. \*\*破壊操作の前に LLM 保全を済ませ' "$WT_CLEAN_SKILL"
  # 本文中の参照も 5 に揃っていること（絶対禁則 4 という古い参照が残っていない）
  run grep -q '絶対禁則 4' "$WT_CLEAN_SKILL"
  [ "$status" -ne 0 ]
}

# --- detection helpers ---

@test "skill: wt-clean SKILL.md defines detect_active_procs_under" {
  grep -q 'detect_active_procs_under' "$WT_CLEAN_SKILL"
}

@test "skill: process detection reuses the kill_devserver_under exclusion list" {
  # 除外リストが 2 箇所（kill 側と検出側）に同一で存在すること。
  # ずれると「kill されるのに 🟢 のまま自動削除される」穴が開く。
  local n
  n=$(grep -c 'bash|zsh|sh|fish|tmux|ssh|vim|nvim|code|Cursor|login' "$WT_CLEAN_SKILL")
  [ "$n" -ge 2 ]
}

@test "skill: wt-clean SKILL.md defines detect_recent_session_log over ~/.claude/projects" {
  grep -q 'detect_recent_session_log' "$WT_CLEAN_SKILL"
  grep -q '.claude/projects' "$WT_CLEAN_SKILL"
  grep -q 'mtime -1' "$WT_CLEAN_SKILL"
}

@test "skill: session-log slug tries both the dot-preserved and dot-replaced forms" {
  # Claude Code のバージョンで slug 規則が揺れる（`.claude` → `-claude` になる版とならない版）。
  # 片方しか見ないと壁打ちセッションを取りこぼす。
  grep -q 'slug_a' "$WT_CLEAN_SKILL"
  grep -q 'slug_b' "$WT_CLEAN_SKILL"
}

@test "skill: detection is documented as non-destructive (no kill during diagnosis)" {
  # 診断中はプロセス停止もロック解除もファイル変更もしない
  grep -q 'プロセスの停止・ロック解除・ファイルの変更は一切行わない' "$WT_CLEAN_SKILL"
}

# --- classification: active signal blocks 🟢 ---

@test "skill: classification table requires no active signal for 🟢 Safe" {
  grep -q '稼働シグナルなし（`ACTIVE_SIGNAL` が空）' "$WT_CLEAN_SKILL"
}

@test "skill: classification table routes an active signal to 🟡 Recoverable" {
  grep -Eq '^\| 🟡 Recoverable \|.*稼働シグナルあり' "$WT_CLEAN_SKILL"
}

@test "skill: an active signal never downgrades 🔴 to 🟡" {
  grep -q '削除しない方向にのみ働く' "$WT_CLEAN_SKILL"
}

# --- Pass 1: active signal must be DEFERRED, never auto-processed ---

@test "skill: Pass 1 defers worktrees with an active signal" {
  grep -q '🟡 で稼働シグナルあり' "$WT_CLEAN_SKILL"
}

@test "skill: --keep reuse is blocked by an active signal too" {
  # 再利用化も元ブランチを消すため、作業中セッションには等しく破壊的。
  grep -q '`--keep` 指定時も同様' "$WT_CLEAN_SKILL"
}

@test "skill: Step B-🟢 states that active-signal targets never reach it" {
  awk '/^#### Step B-🟢/,/^#### Step B-🟡/' "$WT_CLEAN_SKILL" \
    | grep -q 'ACTIVE_SIGNAL.*非空の対象はここに来ない'
}

@test "skill: Step B-🟡 auto-delete excludes active-signal targets" {
  awk '/^#### Step B-🟡/,/^#### Step B Pass 2/' "$WT_CLEAN_SKILL" \
    | grep -q 'ACTIVE_SIGNAL.*非空の 🟡 はここに来ない'
}

# --- Pass 2: the detection result must be shown to the user ---

@test "skill: Pass 2 presentation shows the running PIDs and command names" {
  awk '/^#### Step B Pass 2/,/^### Step C/' "$WT_CLEAN_SKILL" \
    | grep -q '⚠️ 稼働中プロセスあり: '
}

@test "skill: Pass 2 presentation shows the recent session-log timestamp" {
  awk '/^#### Step B Pass 2/,/^### Step C/' "$WT_CLEAN_SKILL" \
    | grep -q '⚠️ 直近セッションログ: '
}

@test "skill: Pass 2 offers skip as the recommended choice for an active signal" {
  awk '/^#### Step B Pass 2/,/^### Step C/' "$WT_CLEAN_SKILL" \
    | grep -q 'スキップ（推奨）'
}

@test "skill: deleting an active-signal worktree requires the Pass 2 answer" {
  # 稼働シグナルありの削除は Pass 2 の分岐にのみ存在し、承認後に kill する
  grep -q '🟡 稼働シグナルあり→ユーザー承認で削除' "$WT_CLEAN_SKILL"
}

# --- report + verification checklist ---

@test "skill: Step C report keeps a line for active-signal holds" {
  grep -q '⚠️ 稼働シグナルで自動処理を保留' "$WT_CLEAN_SKILL"
}

@test "skill: self-verification section checks the active-signal guard" {
  awk '/## 自己検証/,0' "$WT_CLEAN_SKILL" | grep -q '稼働シグナル'
}

@test "reference: wt-clean-verification.md adds an active-signal check" {
  grep -q '稼働シグナルのある worktree を自動処理していない' "$WT_CLEAN_VERIFICATION"
}

# --- PID iteration must survive zsh (the Bash tool's actual shell) ---

@test "skill: PID loops use while-read, never 'for pid in \$pids'" {
  # zsh は未クォート変数を単語分割しないため、複数行の $pids が 1 要素に潰れる。
  # detect 側は「1件も検出されない」、kill 側は「存在しない PID 1 個に空振り」になり、
  # どちらも黙って無効化される（issue #39 のガードごと形骸化する）。
  # コード行のみを見る（禁止理由を説明するコメント行に自分で引っかからないよう行頭で絞る）
  run grep -Eq '^[[:space:]]*for pid in \$pids' "$WT_CLEAN_SKILL"
  [ "$status" -ne 0 ]
  local n
  n=$(grep -c 'while IFS= read -r pid' "$WT_CLEAN_SKILL")
  [ "$n" -ge 2 ]
}

# --- shell syntax + behaviour of the embedded helpers ---

wt_load_detect_helpers() {
  local snippet="${BATS_TEST_TMPDIR}/detect.sh"
  # 検出ヘルパは abs_path（Step -1 で定義）に依存する。SKILL.md は「Pass 1 のループに
  # 入る前にまとめて定義しておくこと」と指示しており実行時は揃っているが、
  # ここで抽出しないと abs_path 未定義で全ヘルパが「検査不能」を返してしまう。
  awk '/^abs_path\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  awk '/^list_pids_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^has_live_parent_outside\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_recent_activity_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_active_procs_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^is_leftover_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_recent_session_log\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  grep -q '^abs_path() {' "$snippet"
  grep -q '^list_pids_under() {' "$snippet"
  grep -q '^has_live_parent_outside() {' "$snippet"
  grep -q '^detect_recent_activity_under() {' "$snippet"
  grep -q '^is_leftover_under() {' "$snippet"
  [ -s "$snippet" ]
  echo "$snippet"
}

@test "skill: embedded helpers are syntactically valid under bash and zsh" {
  local snippet
  snippet="$(wt_load_detect_helpers)"
  bash -n "$snippet"
  # `command -v zsh && zsh -n` と書くと、zsh が無い環境（CI の ubuntu）では
  # 最後の文が非0を返しテスト自体が落ちる。if で包んで「無ければ bash だけ検査」にする。
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$snippet"
  fi
}

@test "skill: embedded kill_devserver_under is syntactically valid under bash and zsh" {
  local snippet="${BATS_TEST_TMPDIR}/kill.sh"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  [ -s "$snippet" ]
  bash -n "$snippet"
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$snippet"
  fi
}

@test "detect_active_procs_under: finds a live non-shell process under the path" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir pid out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/live"
  mkdir -p "$dir"

  # cwd が $dir の非シェルプロセスを 1 個立てる（lsof +D は cwd も拾う）
  ( cd "$dir" && exec sleep 30 ) &
  pid=$!
  sleep 1

  out=$(bash -c ". '$snippet'; detect_active_procs_under '$dir'")
  kill "$pid" 2>/dev/null || true

  [[ "$out" == *"$pid"* ]]
  [[ "$out" == *"(sleep)"* ]]
}

@test "detect_active_procs_under: reports nothing for an idle path" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/idle"
  mkdir -p "$dir"

  out=$(bash -c ". '$snippet'; detect_active_procs_under '$dir'")
  [ -z "$out" ]
}

@test "detect_active_procs_under: behaves identically under bash and zsh" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  local snippet dir pid out_bash out_zsh
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/bothshells"
  mkdir -p "$dir"

  # 2 プロセス立てる。zsh の単語分割差が出ると片方しか（または 1 件も）検出されない
  ( cd "$dir" && exec sleep 30 ) &
  pid=$!
  ( cd "$dir" && exec sleep 30 ) &
  sleep 1

  out_bash=$(bash -c ". '$snippet'; detect_active_procs_under '$dir'")
  out_zsh=$(zsh -c ". '$snippet'; detect_active_procs_under '$dir'")
  kill "$pid" 2>/dev/null || true
  pkill -f "sleep 30" 2>/dev/null || true

  [ "$out_bash" = "$out_zsh" ]
  # 2 件とも拾えていること（zsh で 1 件に潰れていない）
  [ "$(printf '%s' "$out_bash" | grep -c '(sleep)')" -eq 1 ]
  [[ "$out_bash" == *","* ]]
}

@test "detect_recent_session_log: finds a jsonl updated within 24h under either slug form" {
  local snippet dir fake_home slug out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/repo.d/wt"
  mkdir -p "$dir"
  fake_home="${BATS_TEST_TMPDIR}/home"

  # 新形式（`.` も `-` に置換）の slug でログを置く
  slug=$(printf '%s' "$dir" | sed 's/[/ ]/-/g' | sed 's/\./-/g')
  mkdir -p "$fake_home/.claude/projects/$slug"
  echo '{}' >"$fake_home/.claude/projects/$slug/session.jsonl"

  out=$(HOME="$fake_home" bash -c ". '$snippet'; detect_recent_session_log '$dir'")
  [[ "$out" == *"session.jsonl"* ]]
}

@test "detect_recent_session_log: ignores logs older than 24h" {
  local snippet dir fake_home slug out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/stale.d/wt"
  mkdir -p "$dir"
  fake_home="${BATS_TEST_TMPDIR}/home2"

  slug=$(printf '%s' "$dir" | sed 's/[/ ]/-/g' | sed 's/\./-/g')
  mkdir -p "$fake_home/.claude/projects/$slug"
  echo '{}' >"$fake_home/.claude/projects/$slug/old.jsonl"
  touch -t 202001010000 "$fake_home/.claude/projects/$slug/old.jsonl"

  out=$(HOME="$fake_home" bash -c ". '$snippet'; detect_recent_session_log '$dir'")
  [ -z "$out" ]
}

@test "detect_recent_session_log: reports nothing when no projects dir exists" {
  local snippet dir out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/nolog"
  mkdir -p "$dir"

  out=$(HOME="${BATS_TEST_TMPDIR}/empty-home" bash -c ". '$snippet'; detect_recent_session_log '$dir'")
  [ -z "$out" ]
}

# --- issue #98: leftover (orphaned + no recent activity) is not an active signal ---

@test "skill: SKILL.md declares the leftover exception with all three conditions" {
  grep -q '居残り（leftover）は配下プロセスとして数えない' "$WT_CLEAN_SKILL"
  grep -q '集合の外に生きた親がいない' "$WT_CLEAN_SKILL"
  grep -q 'AND を崩してはならない' "$WT_CLEAN_SKILL"
}

@test "skill: SKILL.md defines the leftover helpers" {
  grep -q '^list_pids_under() {' "$WT_CLEAN_SKILL"
  grep -q '^has_live_parent_outside() {' "$WT_CLEAN_SKILL"
  grep -q '^detect_recent_activity_under() {' "$WT_CLEAN_SKILL"
  grep -q '^is_leftover_under() {' "$WT_CLEAN_SKILL"
}

@test "skill: detection range is shared, not duplicated (list_pids_under used by both)" {
  # 検出範囲がずれると detect と leftover 判定が食い違う。両者が同じヘルパを通ること。
  local n
  n=$(grep -c 'list_pids_under "$abs"' "$WT_CLEAN_SKILL")
  [ "$n" -ge 2 ]
}

@test "skill: recent-activity scan excludes .git so wt-clean's own git calls do not mask it" {
  grep -q "not -path '\*/\.git/\*'" "$WT_CLEAN_SKILL"
}

@test "skill: the leftover exclusion is reported, never silent" {
  grep -q 'LEFTOVER_NOTE="居残り除外' "$WT_CLEAN_SKILL"
  # 削除直前の 🟢 根拠表示に載ること
  grep -q 'LEFTOVER_NOTE:+ / \$LEFTOVER_NOTE' "$WT_CLEAN_SKILL"
}

@test "has_live_parent_outside: true when a process has a living parent outside the set" {
  local snippet dir pid
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/liveparent"
  mkdir -p "$dir"

  # 親はこの bats シェル（集合の外で生きている）
  ( cd "$dir" && exec sleep 45 ) &
  pid=$!
  sleep 2

  run bash -c ". '$snippet'; has_live_parent_outside '$pid'"
  kill "$pid" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "has_live_parent_outside: false for an orphan adopted by init" {
  local snippet dir pid
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/orphan"
  mkdir -p "$dir"

  # 二重 fork: 中間のサブシェルが即終了するので sleep は PPID=1 に引き取られる
  ( ( cd "$dir" && exec sleep 45 ) & echo $! >"${BATS_TEST_TMPDIR}/orphan.pid" )
  sleep 2
  pid=$(cat "${BATS_TEST_TMPDIR}/orphan.pid")
  [ "$(ps -o ppid= -p "$pid" | tr -d '[:space:]')" = "1" ] || skip "orphan setup did not reparent to init"

  run bash -c ". '$snippet'; has_live_parent_outside '$pid'"
  kill "$pid" 2>/dev/null || true
  [ "$status" -ne 0 ]
}

@test "detect_recent_activity_under: finds a file touched within 24h" {
  local snippet dir out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/fresh"
  mkdir -p "$dir"
  echo hi >"$dir/note.txt"

  out=$(bash -c ". '$snippet'; detect_recent_activity_under '$dir'")
  [[ "$out" == *"note.txt"* ]]
}

@test "detect_recent_activity_under: ignores .git so git calls do not count as activity" {
  local snippet dir out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/gitonly"
  mkdir -p "$dir/.git"
  echo ref >"$dir/.git/index"

  out=$(bash -c ". '$snippet'; detect_recent_activity_under '$dir'")
  [ -z "$out" ]
}

@test "is_leftover_under: an orphan with no activity trace is a leftover" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir pid
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/leftover"
  mkdir -p "$dir"          # ファイルは置かない = 24h 以内の更新なし

  ( ( cd "$dir" && exec sleep 45 ) & echo $! >"${BATS_TEST_TMPDIR}/leftover.pid" )
  sleep 2
  pid=$(cat "${BATS_TEST_TMPDIR}/leftover.pid")
  [ "$(ps -o ppid= -p "$pid" | tr -d '[:space:]')" = "1" ] || skip "orphan setup did not reparent to init"

  run env HOME="${BATS_TEST_TMPDIR}/nohome" bash -c ". '$snippet'; is_leftover_under '$dir'"
  kill "$pid" 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "is_leftover_under: an orphan WITH a fresh file is NOT a leftover (AND not broken)" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir pid
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/orphanbusy"
  mkdir -p "$dir"
  echo working >"$dir/wip.txt"      # 直近の活動痕跡あり

  ( ( cd "$dir" && exec sleep 45 ) & echo $! >"${BATS_TEST_TMPDIR}/orphanbusy.pid" )
  sleep 2
  pid=$(cat "${BATS_TEST_TMPDIR}/orphanbusy.pid")

  run env HOME="${BATS_TEST_TMPDIR}/nohome" bash -c ". '$snippet'; is_leftover_under '$dir'"
  kill "$pid" 2>/dev/null || true
  [ "$status" -ne 0 ]
}

@test "is_leftover_under: a live session is NOT a leftover (issue #77 regression)" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir pid out
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/livesession"
  mkdir -p "$dir"          # 痕跡が無くても、親が生きていれば居残りではない

  ( cd "$dir" && exec sleep 45 ) &
  pid=$!
  sleep 2

  run env HOME="${BATS_TEST_TMPDIR}/nohome" bash -c ". '$snippet'; is_leftover_under '$dir'"
  [ "$status" -ne 0 ]
  # 稼働シグナル自体は従来どおり立つ
  out=$(bash -c ". '$snippet'; detect_active_procs_under '$dir'")
  kill "$pid" 2>/dev/null || true
  [[ "$out" == *"$pid"* ]]
}

@test "is_leftover_under: reports not-leftover when no process is under the path" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/emptydir"
  mkdir -p "$dir"

  run env HOME="${BATS_TEST_TMPDIR}/nohome" bash -c ". '$snippet'; is_leftover_under '$dir'"
  [ "$status" -ne 0 ]
}

@test "is_leftover_under: behaves identically under bash and zsh" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  local snippet dir pid st_bash st_zsh
  snippet="$(wt_load_detect_helpers)"
  dir="${BATS_TEST_TMPDIR}/bothleftover"
  mkdir -p "$dir"

  ( ( cd "$dir" && exec sleep 45 ) & echo $! >"${BATS_TEST_TMPDIR}/bothleftover.pid" )
  sleep 2
  pid=$(cat "${BATS_TEST_TMPDIR}/bothleftover.pid")

  env HOME="${BATS_TEST_TMPDIR}/nohome" bash -c ". '$snippet'; is_leftover_under '$dir'"; st_bash=$?
  env HOME="${BATS_TEST_TMPDIR}/nohome" zsh  -c ". '$snippet'; is_leftover_under '$dir'"; st_zsh=$?
  kill "$pid" 2>/dev/null || true
  [ "$st_bash" -eq "$st_zsh" ]
}

@test "reference: wt-clean-verification.md covers the leftover exclusion" {
  grep -q '居残りを外すときは 3 条件をすべて確かめている' "$WT_CLEAN_VERIFICATION"
  grep -q 'PPID=1' "$WT_CLEAN_VERIFICATION"
}
