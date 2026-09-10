#!/usr/bin/env bats
#
# Tests for issue #98 — 居残り（孤児）プロセスの誤検出。
#
# 稼働シグナル（絶対禁則 3）が、親セッションの終了で init に引き取られた孤児プロセスを
# 「作業中」と読み、マージ済み・clean な worktree の自動処理を無期限に止めていた。
# 2026-08-10 の flatmate 実走では 11 件中 Pass 1 で処理できたのが 0 件（うち 5 件は
# squash マージ済み・clean）。ガードが効いているのではなく自動化が死んでいる状態だった。
#
# 修正の要は「2 条件 AND を崩さないこと」:
#   1. プロセスツリーの最上位が PPID=1（親セッション消滅）かつその最上位も配下で検出されている
#   2. worktree の更新もセッションログの更新も 24 時間以上前
# 片方だけで居残り判定すると issue #77（壁打ちセッションの誤削除）のガードが壊れる。

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

teardown() {
  # 取りこぼした背景プロセスを確実に始末する（孤児は teardown まで生き残る）
  if [ -n "${WT_SPAWNED_PIDS:-}" ]; then
    local p
    for p in $WT_SPAWNED_PIDS; do
      kill -9 "$p" 2>/dev/null || true
    done
  fi
}

# SKILL.md から稼働シグナル検出ヘルパ一式を抽出する（実行時と同じ「まとめて定義」の状態）
wt_load_orphan_helpers() {
  local snippet="${BATS_TEST_TMPDIR}/orphan-helpers.sh"
  awk '/^abs_path\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  awk '/^proc_comm\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^proc_tree_top\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^worktree_has_recent_activity\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_active_procs_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_recent_session_log\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  grep -q '^proc_tree_top() {' "$snippet"
  grep -q '^worktree_has_recent_activity() {' "$snippet"
  echo "$snippet"
}

# $dir を「24 時間以上どこも触られていない worktree」にする
wt_make_stale_dir() {
  local dir="$1"
  mkdir -p "$dir"
  echo x >"$dir/file.txt"
  touch -t 202401010000 "$dir/file.txt" "$dir"
}

# $dir を cwd に持つ孤児プロセス（PPID=1）を 1 個立てて PID を返す。
# 中間シェルを即終了させる二重フォークで init に引き取らせる。
wt_spawn_orphan() {
  local dir="$1" pid
  pid=$( cd "$dir" && bash -c 'sleep 300 >/dev/null 2>&1 & echo $!' )
  WT_SPAWNED_PIDS="${WT_SPAWNED_PIDS:-} $pid"
  sleep 1
  echo "$pid"
}

wt_ppid_of() {
  ps -o ppid= -p "$1" 2>/dev/null | tr -d '[:space:]'
}

# --- SKILL.md の記述（誤検出の扱いと AND 条件） ---

@test "skill: the orphan exclusion is documented as an exception to prohibition 3" {
  grep -q '居残り（孤児）プロセスは稼働シグナルに数えない' "$WT_CLEAN_SKILL"
  # 2 条件が両方書かれていること
  grep -q 'プロセスツリーの最上位が `PPID=1`' "$WT_CLEAN_SKILL"
  grep -q '24 時間以上前' "$WT_CLEAN_SKILL"
}

@test "skill: the two orphan conditions are joined by AND and must not be loosened" {
  grep -q 'この AND を崩してはならない' "$WT_CLEAN_SKILL"
  # 片方だけで判定した場合に何が壊れるかは reference 側に置く（S50: 本文は短く保つ）
  grep -q '条件 1 で引き続き守られる' "$WT_CLEAN_ORPHAN_REF"
  grep -q 'AND を崩さないことが安全側の担保' "$WT_CLEAN_ORPHAN_REF"
}

@test "skill: the detail is split out to references and linked from the skill body" {
  # S50（500 行超のスキルは詳細を references に出す）を壊さないための構造テスト
  [ -f "$WT_CLEAN_ORPHAN_REF" ]
  grep -q 'references/wt-clean-orphan-detection\.md' "$WT_CLEAN_SKILL"
}

@test "skill: the self-verification section stays within the S50 budget (<=15 lines)" {
  # 本 issue の修正で 1 行足したところ S50（<=15 行）を割り、CI が落ちた。
  # 追加の確認項目は references/wt-clean-verification.md 側に置く。
  local n
  n=$(awk '/^## 自己検証[[:space:]]*$/{f=1} f&&/^## /&&!/^## 自己検証[[:space:]]*$/{f=0} f{print}' \
        "$WT_CLEAN_SKILL" | wc -l | tr -d ' ')
  [ "$n" -le 15 ]
  # 節から詳細手順ファイルへの導線が残っていること
  grep -q 'references/wt-clean-verification\.md' "$WT_CLEAN_SKILL"
}

@test "skill: undecidable orphan checks fall back to the active signal (fail-closed)" {
  grep -q '居残りと断定せず稼働シグナルとして扱う' "$WT_CLEAN_SKILL"
  grep -q 'fail-closed' "$WT_CLEAN_SKILL"
}

@test "skill: the false-positive cost estimate is revised for permanent signals" {
  # 「Pass 2 で 1 問聞かれるだけ」が成り立つのは一過性のシグナルに限る
  grep -q '永久に自動処理されない' "$WT_CLEAN_SKILL"
  grep -q '一過性の誤検出（false positive）は許容する' "$WT_CLEAN_SKILL"
  # 見積もり改訂の背景（実測値）は reference 側
  grep -q '誤検出コストの見積もりの改訂' "$WT_CLEAN_ORPHAN_REF"
}

@test "skill: helpers proc_tree_top and worktree_has_recent_activity are defined" {
  grep -q '^proc_tree_top() {' "$WT_CLEAN_SKILL"
  grep -q '^worktree_has_recent_activity() {' "$WT_CLEAN_SKILL"
}

@test "skill: recent-activity scan excludes .git so our own git calls do not mask staleness" {
  awk '/^worktree_has_recent_activity\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" | grep -q '\-name \.git'
  grep -q 'index の' "$WT_CLEAN_SKILL"
  grep -q '痕跡スキャンから `\.git` を除外する' "$WT_CLEAN_ORPHAN_REF"
}

# --- 除外根拠の可視化（Pass 1 / Pass 2 / Step C） ---

@test "skill: Pass 1 diagnosis captures and prints the orphan-exclusion note" {
  grep -q 'STALE_ORPHANS=\$(grep .居残りプロセス' "$WT_CLEAN_SKILL"
  grep -q '\[ -n "\$STALE_ORPHANS" \] && echo' "$WT_CLEAN_SKILL"
}

@test "skill: Pass 2 presentation shows the excluded orphan processes" {
  awk '/^#### Step B Pass 2/,/^### Step C/' "$WT_CLEAN_SKILL" \
    | grep -q 'ℹ️ 居残りプロセスとして稼働シグナルから除外'
}

@test "skill: Step C report keeps a line for excluded orphan processes" {
  awk '/^### Step C/,/^## 無人モード/' "$WT_CLEAN_SKILL" \
    | grep -q '居残りプロセスとして稼働シグナルから除外'
}

@test "verification: the orphan exclusion evidence is checked in the detailed procedure" {
  # 自己検証セクションは S50 の 15 行枠に収める必要があるため、追加の確認項目は
  # 詳細手順ファイル側に置く（SKILL.md の節からリンク済み）
  grep -q '除外根拠（PID・コマンド名・親セッション消滅・痕跡なし）' "$WT_CLEAN_VERIFICATION"
}

@test "reference: wt-clean-verification.md checks the AND of the two orphan conditions" {
  grep -q '居残り（孤児）プロセスの除外が 2 条件 AND' "$WT_CLEAN_VERIFICATION"
  grep -q 'issue #98' "$WT_CLEAN_VERIFICATION"
}

# --- shell syntax ---

@test "skill: orphan helpers are syntactically valid under bash and zsh" {
  local snippet
  snippet="$(wt_load_orphan_helpers)"
  bash -n "$snippet"
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$snippet"
  fi
}

# --- worktree_has_recent_activity ---

@test "worktree_has_recent_activity: true for a freshly touched worktree" {
  local snippet dir
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/fresh"
  mkdir -p "$dir"
  echo x >"$dir/file.txt"

  bash -c ". '$snippet'; worktree_has_recent_activity '$dir'"
}

@test "worktree_has_recent_activity: false when everything is older than 24h" {
  local snippet dir
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/stale"
  wt_make_stale_dir "$dir"

  run bash -c ". '$snippet'; worktree_has_recent_activity '$dir'"
  [ "$status" -ne 0 ]
}

@test "worktree_has_recent_activity: a freshly touched .git does not count as work" {
  # 診断中に自分で撃つ git status が index を触るため、.git を数えると全 worktree が
  # 「最近更新あり」になり居残り判定が永久に効かなくなる
  local snippet dir
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/gitonly"
  wt_make_stale_dir "$dir"
  mkdir -p "$dir/.git"
  echo idx >"$dir/.git/index"
  # .git の作成でディレクトリ自体の mtime が動くので巻き戻す（見たいのは .git 配下の扱い）
  touch -t 202401010000 "$dir"

  run bash -c ". '$snippet'; worktree_has_recent_activity '$dir'"
  [ "$status" -ne 0 ]
}

@test "worktree_has_recent_activity: behaves identically under bash and zsh" {
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  local snippet dir sb sz
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/parity-activity"
  wt_make_stale_dir "$dir"

  bash -c ". '$snippet'; worktree_has_recent_activity '$dir'" && sb=0 || sb=$?
  zsh -c ". '$snippet'; worktree_has_recent_activity '$dir'" && sz=0 || sz=$?
  [ "$sb" = "$sz" ]
}

# --- proc_tree_top ---

@test "proc_tree_top: an orphan is its own tree top" {
  local snippet dir pid out
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/toporphan"
  wt_make_stale_dir "$dir"
  pid="$(wt_spawn_orphan "$dir")"
  [ "$(wt_ppid_of "$pid")" = "1" ] || skip "orphan was reparented to a subreaper, not init"

  out=$(bash -c ". '$snippet'; proc_tree_top '$pid'")
  [ "$out" = "$pid" ]
}

@test "proc_tree_top: a process with a live parent resolves above itself" {
  local snippet dir pid out
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/toplive"
  mkdir -p "$dir"
  ( cd "$dir" && exec sleep 30 ) &
  pid=$!
  WT_SPAWNED_PIDS="${WT_SPAWNED_PIDS:-} $pid"
  sleep 1

  out=$(bash -c ". '$snippet'; proc_tree_top '$pid'")
  [ -n "$out" ]
  [ "$out" != "$pid" ]
}

# --- 誤検出の再現ケース: 孤児 + 痕跡なし → 稼働シグナルから外れる ---

@test "detect_active_procs_under: an orphan under a stale worktree is not an active signal" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir home pid out err
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/orphan-stale"
  home="${BATS_TEST_TMPDIR}/home-empty"
  mkdir -p "$home"
  wt_make_stale_dir "$dir"
  pid="$(wt_spawn_orphan "$dir")"
  [ "$(wt_ppid_of "$pid")" = "1" ] || skip "orphan was reparented to a subreaper, not init"
  # 孤児が cwd を握ったあとに mtime を巻き戻す（プロセス生成が dir に触ることがあるため）
  touch -t 202401010000 "$dir/file.txt" "$dir"

  err="${BATS_TEST_TMPDIR}/orphan-stale.err"
  out=$(HOME="$home" bash -c ". '$snippet'; detect_active_procs_under '$dir'" 2>"$err")

  # 誤検出が解消され、マージ済み worktree が自動処理対象に戻ること
  [ -z "$out" ]
  # 黙って捨てず、除外根拠が読めること
  grep -q '居残りプロセスとして稼働シグナルから除外' "$err"
  grep -q "$pid" "$err"
}

@test "detect_active_procs_under: the orphan exclusion is identical under bash and zsh" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  local snippet dir home pid out_bash out_zsh
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/orphan-parity"
  home="${BATS_TEST_TMPDIR}/home-parity"
  mkdir -p "$home"
  wt_make_stale_dir "$dir"
  pid="$(wt_spawn_orphan "$dir")"
  [ "$(wt_ppid_of "$pid")" = "1" ] || skip "orphan was reparented to a subreaper, not init"
  touch -t 202401010000 "$dir/file.txt" "$dir"

  out_bash=$(HOME="$home" bash -c ". '$snippet'; detect_active_procs_under '$dir'" 2>/dev/null)
  out_zsh=$(HOME="$home" zsh -c ". '$snippet'; detect_active_procs_under '$dir'" 2>/dev/null)
  [ "$out_bash" = "$out_zsh" ]
  [ -z "$out_bash" ]
}

# --- 正当な稼働プロセスは引き続き検出される（issue #77 の回帰防止） ---

@test "detect_active_procs_under: a live process keeps its active signal even when the worktree is stale" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir home pid out
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/live-stale"
  home="${BATS_TEST_TMPDIR}/home-live"
  mkdir -p "$home"
  wt_make_stale_dir "$dir"

  # 親（この bats プロセス）が生きているプロセス = 起動元セッションが存在する
  ( cd "$dir" && exec sleep 30 ) &
  pid=$!
  WT_SPAWNED_PIDS="${WT_SPAWNED_PIDS:-} $pid"
  sleep 1
  touch -t 202401010000 "$dir/file.txt" "$dir"

  out=$(HOME="$home" bash -c ". '$snippet'; detect_active_procs_under '$dir'" 2>/dev/null)
  kill "$pid" 2>/dev/null || true

  [[ "$out" == *"$pid"* ]]
  [[ "$out" == *"(sleep)"* ]]
}

@test "detect_active_procs_under: an orphan still counts while its session log is fresh" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir home slug pid out
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/orphan-freshlog/wt"
  home="${BATS_TEST_TMPDIR}/home-freshlog"
  wt_make_stale_dir "$dir"
  pid="$(wt_spawn_orphan "$dir")"
  [ "$(wt_ppid_of "$pid")" = "1" ] || skip "orphan was reparented to a subreaper, not init"
  touch -t 202401010000 "$dir/file.txt" "$dir"

  # 24 時間以内に更新されたセッションログを置く（launchd 常駐セッションの想定）
  slug=$(printf '%s' "$(cd "$dir" && pwd -P)" | sed 's/[/ ]/-/g' | sed 's/\./-/g')
  mkdir -p "$home/.claude/projects/$slug"
  echo '{}' >"$home/.claude/projects/$slug/session.jsonl"

  out=$(HOME="$home" bash -c ". '$snippet'; detect_active_procs_under '$dir'" 2>/dev/null)
  [[ "$out" == *"$pid"* ]]
}

@test "detect_active_procs_under: an orphan still counts while the worktree was touched within 24h" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  local snippet dir home pid out
  snippet="$(wt_load_orphan_helpers)"
  dir="${BATS_TEST_TMPDIR}/orphan-freshfile"
  home="${BATS_TEST_TMPDIR}/home-freshfile"
  mkdir -p "$home"
  wt_make_stale_dir "$dir"
  pid="$(wt_spawn_orphan "$dir")"
  [ "$(wt_ppid_of "$pid")" = "1" ] || skip "orphan was reparented to a subreaper, not init"
  # 人の作業痕跡（24 時間以内のファイル更新）
  echo work >"$dir/edited.md"

  out=$(HOME="$home" bash -c ". '$snippet'; detect_active_procs_under '$dir'" 2>/dev/null)
  [[ "$out" == *"$pid"* ]]
}

@test "detect_active_procs_under: missing helpers keep the orphan as an active signal (fail-closed)" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  # 旧来の抽出（proc_tree_top / worktree_has_recent_activity を持たない）でも、
  # 居残り除外が黙って作動して削除許可に倒れないこと
  local snippet dir home pid out
  snippet="${BATS_TEST_TMPDIR}/partial-helpers.sh"
  awk '/^abs_path\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  awk '/^proc_comm\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_active_procs_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  awk '/^detect_recent_session_log\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  dir="${BATS_TEST_TMPDIR}/failclosed"
  home="${BATS_TEST_TMPDIR}/home-failclosed"
  mkdir -p "$home"
  wt_make_stale_dir "$dir"
  pid="$(wt_spawn_orphan "$dir")"
  [ "$(wt_ppid_of "$pid")" = "1" ] || skip "orphan was reparented to a subreaper, not init"
  touch -t 202401010000 "$dir/file.txt" "$dir"

  out=$(HOME="$home" bash -c ". '$snippet'; detect_active_procs_under '$dir'" 2>/dev/null)
  [[ "$out" == *"$pid"* ]]
}

# --- version bump (cache invalidation) ---

@test "version: worktree plugin.json is bumped to at least 2.12.0" {
  local v
  v=$(jq -r .version "$PLUGIN_JSON")
  printf '%s\n2.12.0\n' "$v" | sort -V | head -1 | grep -qx '2.12.0'
}

@test "version: wt-clean SKILL.md version is bumped to at least 3.7.0" {
  local v
  v=$(wt_frontmatter "$WT_CLEAN_SKILL" | awk -F': *' '/^version:/{print $2}')
  printf '%s\n3.7.0\n' "$v" | sort -V | head -1 | grep -qx '3.7.0'
}
