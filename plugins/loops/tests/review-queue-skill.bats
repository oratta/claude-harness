#!/usr/bin/env bats
#
# Tests for capability: loops-review-queue の stale-wip（孤児 agent-wip）検出
# issue: oratta/claude-harness#155
#
# 何を守るテストか:
#   `agent-wip` は同一サイクル内の一時ラベル（plugins/loops/templates/agent-loop-template.md）で、
#   サイクル終了時に必ず外れる想定。しかしサイクル完了前にセッションが落ちると外れないまま残り、
#   templates/select-target.sh の実装モード選定（agent-ready ∧ ¬agent-wip）から永久に外れ、
#   review-queue の Step 3 フォールバック検索（agent-proposed / agent-blocked / needs-approval）
#   にも出てこない。この「見えない停止」を検出する記述が SKILL.md から消えないことを検査する。

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  SKILL="${PLUGIN_DIR}/skills/loops-review-queue/SKILL.md"
}

# Step 3（フォールバック検索）の本文だけを切り出す。
_step3_body() {
  awk '/^## Step 3:/{f=1;next} f&&/^## /{f=0} f{print}' "$SKILL"
}

# Step 4（優先順位付けと表示）の本文だけを切り出す。
_step4_body() {
  awk '/^## Step 4:/{f=1;next} f&&/^## /{f=0} f{print}' "$SKILL"
}

# 「してはならないこと」の本文だけを切り出す。
_forbidden_body() {
  awk '/^## してはならないこと/{f=1;next} f&&/^## /{f=0} f{print}' "$SKILL"
}

# ── ここから下は「書いてあるか」ではなく「書いてあるコマンドが実際にそう動くか」の検査 ──
#
# grep だけの検査では、SKILL.md のコマンド例が gh 障害時に fail-open する・owner が
# 空のまま全 GitHub を検索する、といった実挙動の欠陥を一切captureできない。
# そこで SKILL.md から stale-wip ブロックをそのまま抜き出し、gh をスタブして実行する。
# これにより「ドキュメントに書いてあるコマンド」自体が回帰検査の対象になる。

# SKILL.md の stale-wip 節にある bash フェンスの中身をそのまま取り出す。
_extract_stale_wip_snippet() {
  awk '
    /^### stale-wip/      { in_sec = 1; next }
    in_sec && /^## /      { in_sec = 0 }
    in_sec && /^```bash$/ { in_fence = 1; next }
    in_fence && /^```$/   { in_fence = 0; next }
    in_fence              { print }
  ' "$SKILL"
}

# gh のスタブを PATH の先頭に置く。挙動は環境変数で切り替える:
#   STUB_ISSUES_TSV  : gh search issues が返す TSV（既定は空）
#   STUB_LINKED      : gh pr list が返す件数（既定 0）
#   STUB_FAIL_SEARCH : 非空なら gh search issues を失敗させる
#   STUB_FAIL_PRLIST : 非空なら gh pr list を失敗させる
#   STUB_FAIL_USER   : 非空なら gh api user（本人）だけを失敗させる
#   STUB_FAIL_ORGS   : 非空なら gh api user/orgs だけを失敗させる
# 受け取った引数は $STUB_LOG に追記し、owner が空でないことなどを後から検査できるようにする。
_install_gh_stub() {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  STUB_LOG="${BATS_TEST_TMPDIR}/gh-args.log"
  : > "$STUB_LOG"
  cat > "${BATS_TEST_TMPDIR}/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1 $2" in
  "api user")
    [ -n "${STUB_FAIL_USER:-}" ] && exit 1
    case "$2" in
      user) echo "testuser" ;;
    esac
    ;;
  "api user/orgs")
    [ -n "${STUB_FAIL_ORGS:-}" ] && exit 1
    echo "testorg"
    ;;
  "search issues")
    [ -n "${STUB_FAIL_SEARCH:-}" ] && { echo "gh: API error" >&2; exit 1; }
    printf '%b' "${STUB_ISSUES_TSV:-}"
    ;;
  "pr list")
    [ -n "${STUB_FAIL_PRLIST:-}" ] && { echo "gh: API error" >&2; exit 1; }
    echo "${STUB_LINKED:-0}"
    ;;
  *) echo "unexpected gh invocation: $*" >&2; exit 99 ;;
esac
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"
  export STUB_LOG
  PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

# SKILL.md から抜き出したスニペットをスタブ環境で実行する。
_run_snippet() {
  _extract_stale_wip_snippet > "${BATS_TEST_TMPDIR}/snippet.sh"
  run bash "${BATS_TEST_TMPDIR}/snippet.sh"
}

# TSV 1 行を組み立てる（repo / 番号 / updatedAt / URL / title）。
_row() {
  printf '%s\t%s\t%s\t%s\t%s\\n' "$1" "$2" "$3" "https://example.test/$2" "title $2"
}

# 現在から $1 時間前の ISO8601 UTC を返す（BSD / GNU date 両対応）。
_hours_ago() {
  date -u -v "-$1H" +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || date -u -d "$1 hours ago" +'%Y-%m-%dT%H:%M:%SZ'
}

@test "S155-1: step 3 searches open issues labeled agent-wip" {
  _step3_body | grep -q 'agent-wip'
}

@test "S155-2: step 3 decides linked open PR via gh pr list in:body search" {
  body="$(_step3_body)"
  echo "$body" | grep -q 'gh pr list'
  echo "$body" | grep -q 'in:body'
  echo "$body" | grep -q -- '--state open'
}

@test "S155-3: step 3 computes staleness by comparing updatedAt against the threshold" {
  # 既存 Step 3 にも --json ...,updatedAt はあるので「updatedAt がある」だけでは何も守れない。
  # 閾値と突き合わせて経過時間を出している箇所があることまで見る。
  body="$(_step3_body)"
  echo "$body" | grep -q 'iso_to_epoch "$UPDATED"'
  echo "$body" | grep -qE 'AGE_H.*-ge.*STALE_WIP_HOURS|-ge "\$STALE_WIP_HOURS"'
}

@test "S155-4: staleness threshold is an env var with a default, not a hardcoded literal" {
  # レートガード（RATE_5H_MAX 等）と同じく環境変数 + 既定値の形にする
  _step3_body | grep -qE 'STALE_WIP_HOURS:-[0-9]+'
}

@test "S155-5: step 3 states the rationale for the threshold" {
  # 1 サイクル = 1h（loop-dev-agent の既定実行間隔）に対して十分長いこと、が根拠
  _step3_body | grep -q 'サイクル'
}

@test "S155-6: step 3 maps stale-wip into the label-to-State inference list" {
  _step3_body | grep -q 'stale-wip'
}

@test "S155-7: step 4 ranks stale-wip as an intervention-class row" {
  body="$(_step4_body)"
  echo "$body" | grep -q 'stale-wip'
  echo "$body" | grep -q '要介入'
}

@test "S155-8: skill stays read-only and forbids clearing agent-wip automatically" {
  _forbidden_body | grep -q 'agent-wip'
  grep -q '読み取り専用' "$SKILL"
}

@test "S155-9: issue #155 verification grep yields at least one hit" {
  run grep -c 'stale-wip\|agent-wip' "$SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── 実行検査（SKILL.md のコマンド例をそのまま動かす） ──

@test "S155-10: the documented snippet is extractable and syntactically valid bash" {
  _extract_stale_wip_snippet > "${BATS_TEST_TMPDIR}/snippet.sh"
  [ -s "${BATS_TEST_TMPDIR}/snippet.sh" ]
  run bash -n "${BATS_TEST_TMPDIR}/snippet.sh"
  [ "$status" -eq 0 ]
}

@test "S155-11: an orphan (no linked PR, past the threshold) is reported" {
  _install_gh_stub
  export STUB_ISSUES_TSV="$(_row 'o/r' 7 "$(_hours_ago 100)")"
  export STUB_LINKED=0
  _run_snippet
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^stale-wip	o/r#7	'
}

@test "S155-12: an issue with a linked open PR is excluded" {
  _install_gh_stub
  export STUB_ISSUES_TSV="$(_row 'o/r' 7 "$(_hours_ago 100)")"
  export STUB_LINKED=1
  _run_snippet
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q 'stale-wip	o/r#7'
}

@test "S155-13: an issue younger than the threshold is excluded" {
  _install_gh_stub
  export STUB_ISSUES_TSV="$(_row 'o/r' 7 "$(_hours_ago 2)")"
  export STUB_LINKED=0
  _run_snippet
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q 'stale-wip	o/r#7'
}

@test "S155-14: fail-closed — a failing gh pr list must not be read as 'no linked PR'" {
  # ここが fail-open だと、認証切れ・rate limit のたびに進行中の issue が
  # 「要介入」として誤報される。判定不能として出すのが正。
  _install_gh_stub
  export STUB_ISSUES_TSV="$(_row 'o/r' 7 "$(_hours_ago 100)")"
  export STUB_FAIL_PRLIST=1
  _run_snippet
  echo "$output" | grep -q 'stale-wip?	o/r#7'
  echo "$output" | grep -q '判定不能'
  ! echo "$output" | grep -qE '^stale-wip	o/r#7'
}

@test "S155-15: fail-closed — a failing gh search issues is not silently read as zero orphans" {
  _install_gh_stub
  export STUB_FAIL_SEARCH=1
  _run_snippet
  # stderr の警告だけでは読み落とされる。表に載る構造化行を stdout に出し、
  # 終了ステータスでも失敗を伝えること（「孤児ゼロ」と見分けが付くように）
  echo "$output" | grep -q '^stale-wip?	(全体)	判定不能'
  [ "$status" -ne 0 ]
}

@test "S155-21: fail-closed — a partial owner failure must not silently narrow the search scope" {
  # 本人と組織をまとめて取ると、片方だけ失敗しても OWNERS が非空になり、
  # 個人 repo が丸ごと検索対象から落ちたまま正常終了してしまう
  _install_gh_stub
  export STUB_FAIL_USER=1
  _run_snippet
  [ "$status" -ne 0 ]
  ! grep -q 'search issues' "$STUB_LOG"
}

@test "S155-22: fail-closed — an org lookup failure also aborts" {
  _install_gh_stub
  export STUB_FAIL_ORGS=1
  _run_snippet
  [ "$status" -ne 0 ]
  ! grep -q 'search issues' "$STUB_LOG"
}

@test "S155-23: fail-closed — a successful gh pr list returning a non-number is not read as zero" {
  # 終了 0 でも中身が数値でないことがある。0 に潰すと進行中の issue を孤児と誤報する
  _install_gh_stub
  export STUB_ISSUES_TSV="$(_row 'o/r' 7 "$(_hours_ago 100)")"
  export STUB_LINKED='not-a-number'
  _run_snippet
  echo "$output" | grep -q '^stale-wip?	o/r#7	判定不能'
  ! echo "$output" | grep -qE '^stale-wip	o/r#7'
}

@test "S155-16: the snippet derives OWNERS itself instead of searching all of GitHub" {
  # --owner が空だと gh はエラーにせず GitHub 全体を検索する（スコープが黙って変わる）
  _install_gh_stub
  export STUB_ISSUES_TSV=''
  _run_snippet
  grep -q 'search issues --owner testuser,testorg ' "$STUB_LOG"
  ! grep -q 'search issues --owner  ' "$STUB_LOG"
}

@test "S155-17: the snippet aborts when owner resolution fails entirely" {
  _install_gh_stub
  export STUB_FAIL_USER=1 STUB_FAIL_ORGS=1
  _run_snippet
  [ "$status" -ne 0 ]
  # owner を解決できないまま検索に進まないこと
  ! grep -q 'search issues' "$STUB_LOG"
}

@test "S155-18: candidates are fetched oldest-first so the limit does not hide old orphans" {
  _install_gh_stub
  export STUB_ISSUES_TSV=''
  _run_snippet
  grep -q -- '--sort updated --order asc' "$STUB_LOG"
}

@test "S155-19: exit status stays 0 when the last candidate is below the threshold" {
  # `[ ... ] && printf` を最終文にすると pipeline が 1 で終わり、
  # 呼び出し側が「検索が失敗した」と誤読する。
  _install_gh_stub
  export STUB_ISSUES_TSV="$(_row 'o/r' 7 "$(_hours_ago 2)")"
  export STUB_LINKED=0
  _run_snippet
  [ "$status" -eq 0 ]
}

@test "S155-20: step 3 warns that in:body is a text search, not a GitHub link relation" {
  body="$(_step3_body)"
  echo "$body" | grep -q 'in:body'
  echo "$body" | grep -q 'テキスト検索'
}
