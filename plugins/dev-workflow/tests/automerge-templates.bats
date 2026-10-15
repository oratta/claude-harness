#!/usr/bin/env bats
#
# auto-merge テンプレート一式の検証（issue #82）
#
# flatmate PR #234 の実物（アドバーサリアルレビュー3周を通過した auto-merge.yml /
# revert-pr.yml / 攻撃再現テスト）をテンプレートとして配布する。ここでは
# (a) 展開先ツリーを鏡写しにしたファイル群と差し替えマーカーが揃っていること
# (b) flatmate で実証済みの安全不変条件がテンプレート改変で退行していないこと
# (c) 同梱の攻撃再現テストがテンプレート自身に対して pass すること（自己検証）
# を固定する。
#
# spec: dev-workflow-automerge-templates

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TPL="${PLUGIN_DIR}/templates/auto-merge"
  WF="${TPL}/.github/workflows/auto-merge.yml"
  RV="${TPL}/.github/workflows/revert-pr.yml"
  DOC="${TPL}/docs/auto-merge.md"
  TST="${TPL}/scripts/test-auto-merge-workflow.sh"
  README="${TPL}/README.md"
  SMOKE="${TPL}/.github/workflows/staging-smoke.yml"
  DENY="${TPL}/.claude/settings.json"
}

# staging-smoke.yml の smoke ステップ本体（# >>> smoke-script マーカーの間）を、YAML の
# インデントを剥がした bash スクリプトとして取り出す。curl をスタブに差し替えて実行し、
# 誤検知ガードの判定を実際に動かして固定する
extract_smoke_script() {
  sed -n '/# >>> smoke-script/,/# <<< smoke-script/p' "$SMOKE" | sed 's/^          //'
}

# $1=スタブ curl が返す HTTP コード、$2=本文。fixture dir を作って PATH 先頭に置く
make_curl_stub() {
  local dir="$BATS_TEST_TMPDIR/stub-$1"
  mkdir -p "$dir"
  cat > "$dir/curl" <<EOF
#!/bin/sh
# 実物と同じく "本文\n<code>" を返す（-w '\n%{http_code}' 相当）
printf '%s\n%s' '$2' '$1'
EOF
  chmod +x "$dir/curl"
  printf '%s' "$dir"
}

run_smoke_with_code() { # $1=HTTP code $2=body
  local stub script out
  stub="$(make_curl_stub "$1" "$2")"
  script="$BATS_TEST_TMPDIR/smoke-$1.sh"
  extract_smoke_script > "$script"
  out="$BATS_TEST_TMPDIR/output-$1.txt"
  : > "$out"
  run env PATH="$stub:$PATH" STAGING_DOMAIN=staging.example.test VERCEL_BYPASS= GITHUB_OUTPUT="$out" bash "$script"
  SMOKE_OUTPUT_FILE="$out"
}

# --- Requirement: auto-merge workflow 一式がテンプレートとして配布される ---

@test "files: deployment-tree mirror and README all exist" {
  [ -f "$WF" ]
  [ -f "$RV" ]
  [ -f "$DOC" ]
  [ -f "$TST" ]
  [ -f "$README" ]
  [ -f "$SMOKE" ]
  [ -f "$DENY" ]
}

@test "markers: auto-merge.yml has all replacement/extraction marker pairs" {
  for m in sacred-paths sacred-paths-jq merge-condition-paths parent-merge-judgment required-checks labeled-target passed-head-binding pre-merge-recheck automerge-script; do
    grep -qF "# >>> $m" "$WF"
    grep -qF "# <<< $m" "$WF"
  done
}

@test "markers: revert-pr.yml has revert-script marker pair" {
  grep -qF '# >>> revert-script' "$RV"
  grep -qF '# <<< revert-script' "$RV"
}

@test "readme: documents the three mandatory replacements and operations" {
  grep -q '聖域' "$README"
  grep -qF 'REQUIRED_CHECKS' "$README"
  grep -qF 'AUTOMERGE_PAT' "$README"
  grep -qF 'AUTOMERGE_PAUSED' "$README"
  grep -qF 'revert-pr.yml' "$README"
  grep -qF 'docs/auto-merge.md' "$README"
  grep -qF 'merge-condition-paths' "$README"
}

# --- Requirement: テンプレートは flatmate で実証済みの安全不変条件を維持する ---

@test "invariant: no bare pull_request trigger (head-side definition must never run)" {
  on_block="$(awk '/^on:/{f=1;next} /^[^ #]/{f=0} f' "$WF")"
  ! printf '%s\n' "$on_block" | grep -qE '^ *pull_request:' || return 1
}

@test "invariant: pull_request_target restricted to labeled events" {
  types="$(awk '/^on:/{f=1;next} /^[^ #]/{f=0} f' "$WF" \
    | awk '/^  pull_request_target:/{f=1;next} /^  [a-z_]/{f=0} f' \
    | grep -E '^ *types:' | sed 's/^ *//')"
  [ "$types" = "types: [labeled]" ]
}

@test "invariant: auto-merge.yml never checks out or clones PR head" {
  ! grep -vE '^ *#' "$WF" | grep -qE 'actions/checkout|git +clone|gh pr checkout' || return 1
}

@test "invariant: merge is SHA-pinned REST, not gh pr merge" {
  # コメントを除いた実行コードに gh pr merge が無いこと
  ! sed -n '/# >>> automerge-script/,/# <<< automerge-script/p' "$WF" | sed 's/#.*//' | grep -qF 'gh pr merge' || return 1
  grep -qF -- '-f sha="$HEAD_SHA"' "$WF"
  grep -qF -- '-f merge_method=squash' "$WF"
}

@test "invariant: passed label is bound to current HEAD (stale passed never merges)" {
  block="$(sed -n '/# >>> passed-head-binding/,/# <<< passed-head-binding/p' "$WF")"
  [ -n "$block" ]
  # 判定ループ内で PR コメントを取得し、判定時の ${HEAD_SHA}（マージの SHA ピンと同一変数）と照合する
  printf '%s\n' "$block" | grep -qF 'issues/$N/comments'
  printf '%s\n' "$block" | grep -qF '対象 HEAD: $HEAD_SHA'
  # 不一致は continue（マージ側へ落ちない fail-closed）。取得失敗も || true で同じ側に倒れる
  printf '%s\n' "$block" | grep -qF 'continue'
  printf '%s\n' "$block" | grep -qF '|| true'
}

@test "invariant: fail-closed on AUTOMERGE_PAUSED and missing PAT" {
  grep -qF 'if [ -n "$AUTOMERGE_PAUSED" ]' "$WF"
  grep -qF 'if [ -z "$MERGE_TOKEN" ]' "$WF"
}

@test "invariant: all four blocking labels are honored" {
  block="$(sed -n "/BLOCKING_LABELS='/,/'\$/p" "$WF" | sed "s/^ *//; s/^BLOCKING_LABELS='//; s/'\$//")"
  for L in human-merge needs-human-merge human-only needs-approval; do
    printf '%s\n' "$block" | grep -qxF "$L"
  done
}

@test "invariant: revert workflow creates a PR but never merges" {
  grep -qF 'workflow_dispatch' "$RV"
  grep -qF 'git revert' "$RV"
  grep -qF 'gh pr create' "$RV"
  ! grep -qF 'gh pr merge' "$RV" || return 1
  grep -qF 'labels[]=human-merge' "$RV"
  grep -qF -- '-m 1' "$RV"
}

# revert-script の実行コード（コメント除去済み）を取り出す。コメント内の言及に
# 惑わされず、実際に実行される行だけで検査するため
extract_revert_code() {
  sed -n '/# >>> revert-script/,/# <<< revert-script/p' "$RV" | sed 's/#.*//'
}

@test "invariant: revert validates base branch and merge-commit ancestry before side effects" {
  code="$BATS_TEST_TMPDIR/rv-code.txt"
  extract_revert_code > "$code"
  # base 検証: PR の base を取得し、$BASE_BRANCH 以外を拒否する（issue #121）
  grep -qF '.base.ref' "$code"
  grep -qF '"$PR_BASE" != "$BASE_BRANCH"' "$code"
  # ancestor 検証: merge_commit_sha が base の履歴に含まれることを push より前に確認する
  grep -qF 'merge-base --is-ancestor' "$code"
  ancestor_line="$(grep -nF 'merge-base --is-ancestor' "$code" | head -1 | cut -d: -f1)"
  push_line="$(grep -nF 'git push origin' "$code" | head -1 | cut -d: -f1)"
  [ "$ancestor_line" -lt "$push_line" ]
}

@test "invariant: revert re-run resumes from existing branch and PR (issue #121)" {
  code="$BATS_TEST_TMPDIR/rv-code.txt"
  extract_revert_code > "$code"
  # 失敗 run の re-run は RUN_ID が同じ（attempt だけ増える）。既存ブランチ・既存 PR を
  # 発見して残工程だけ続行しないと non-fast-forward / PR 重複で落ちる
  grep -qF 'ls-remote' "$code"
  grep -qF 'gh pr list' "$code"
  lsremote_line="$(grep -nF 'ls-remote' "$code" | head -1 | cut -d: -f1)"
  push_line="$(grep -nF 'git push origin' "$code" | head -1 | cut -d: -f1)"
  prlist_line="$(grep -nF 'gh pr list' "$code" | head -1 | cut -d: -f1)"
  prcreate_line="$(grep -nF 'gh pr create' "$code" | head -1 | cut -d: -f1)"
  [ "$lsremote_line" -lt "$push_line" ]
  [ "$prlist_line" -lt "$prcreate_line" ]
}

# --- Requirement: staging スモーク + auto-revert がテンプレートとして配布される（issue #213） ---

@test "smoke: staging-smoke.yml exists and subscribes to Deploy to Staging completion" {
  [ -f "$SMOKE" ]
  grep -qF 'workflow_run:' "$SMOKE"
  grep -qF 'workflows: ["Deploy to Staging"]' "$SMOKE"
  grep -qF 'types: [completed]' "$SMOKE"
}

@test "smoke: both revert-PR and incident-issue paths exist, gated on the blocked output" {
  code="$(sed -n '/# >>> smoke-revert-script/,/# <<< smoke-revert-script/p' "$SMOKE" | sed 's/#.*//')"
  printf '%s\n' "$code" | grep -qF 'git revert'
  printf '%s\n' "$code" | grep -qF 'gh pr create'
  printf '%s\n' "$code" | grep -qF 'gh issue create'
  # revert PR は人間レビュー待ち: incident ラベルのみ。passed の自己付与・対象 HEAD コメントの投稿はしない
  printf '%s\n' "$code" | grep -qF -- '--label "incident"'
  ! printf '%s\n' "$code" | grep -qF -- '--label "agent-review:passed"' || return 1
  ! printf '%s\n' "$code" | grep -qF '対象 HEAD' || return 1
  # revert ジョブは「検証不能」判定のときは走らない
  grep -qF "needs.smoke.outputs.blocked != 'true'" "$SMOKE"
  grep -qF "needs.smoke.outputs.blocked == 'true'" "$SMOKE"
  # デプロイ自体の失敗は incident issue の経路がある
  grep -qF "github.event.workflow_run.conclusion == 'failure'" "$SMOKE"
  # 自動 revert は絶対にマージしない
  ! printf '%s\n' "$code" | grep -qF 'gh pr merge' || return 1
}

@test "smoke: false-positive guard comment (suimei lesson) and marker pairs survive" {
  grep -qF 'genetta-inc/suimei の初回実戦で学習' "$SMOKE"
  grep -qF 'デプロイ保護で検証不能' "$SMOKE"
  for m in smoke-script smoke-checks smoke-revert-script; do
    grep -qF "# >>> $m" "$SMOKE"
    grep -qF "# <<< $m" "$SMOKE"
  done
}

@test "smoke guard: all checks 401 -> blocked=true (revert path is NOT taken)" {
  run_smoke_with_code 401 ""
  [ "$status" -eq 1 ]
  grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE"
  printf '%s\n' "$output" | grep -qF '検証不能'
}

@test "smoke guard: all checks 302/403 (auth-like) -> blocked=true" {
  run_smoke_with_code 302 ""
  [ "$status" -eq 1 ]
  grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE"
  run_smoke_with_code 403 ""
  [ "$status" -eq 1 ]
  grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE"
}

@test "smoke guard: 500 -> failure without blocked (revert path IS taken)" {
  run_smoke_with_code 500 ""
  [ "$status" -eq 1 ]
  ! grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE" || return 1
  grep -qF 'failures=' "$SMOKE_OUTPUT_FILE"
}

@test "smoke guard: mixed 401 and 500 -> not blocked (any non-auth failure is evidence of a defect)" {
  # 1 回目の curl は 401、2 回目以降は 500 を返すスタブ
  dir="$BATS_TEST_TMPDIR/stub-mixed"
  mkdir -p "$dir"
  cat > "$dir/curl" <<'EOF'
#!/bin/sh
n="$(cat "$MIXED_COUNTER" 2>/dev/null || echo 0)"
n=$((n + 1)); echo "$n" > "$MIXED_COUNTER"
if [ "$n" -eq 1 ]; then printf '%s\n%s' '' '401'; else printf '%s\n%s' '' '500'; fi
EOF
  chmod +x "$dir/curl"
  script="$BATS_TEST_TMPDIR/smoke-mixed.sh"
  extract_smoke_script > "$script"
  out="$BATS_TEST_TMPDIR/output-mixed.txt"
  : > "$out"
  run env PATH="$dir:$PATH" MIXED_COUNTER="$BATS_TEST_TMPDIR/mixed.n" STAGING_DOMAIN=staging.example.test VERCEL_BYPASS= GITHUB_OUTPUT="$out" bash "$script"
  [ "$status" -eq 1 ]
  ! grep -qF 'blocked=true' "$out" || return 1
  printf '%s\n' "$output" | grep -qF 'HTTP401:認証系'
  printf '%s\n' "$output" | grep -qF 'HTTP500'
}

@test "smoke guard: all 200 -> success, and unset STAGING_DOMAIN -> skipped" {
  run_smoke_with_code 200 "ok"
  [ "$status" -eq 0 ]
  ! grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE" || return 1
  script="$BATS_TEST_TMPDIR/smoke-skip.sh"
  extract_smoke_script > "$script"
  out="$BATS_TEST_TMPDIR/output-skip.txt"
  : > "$out"
  run env STAGING_DOMAIN= GITHUB_OUTPUT="$out" bash "$script"
  [ "$status" -eq 0 ]
  grep -qF 'skipped=true' "$out"
}

@test "smoke: README documents the deployment step" {
  grep -q 'staging' "$README"
  grep -qF 'staging-smoke.yml' "$README"
  grep -qF 'STAGING_DOMAIN' "$README"
  grep -qF 'smoke-checks' "$README"
  grep -q 'staging' "$DOC"
}

# --- Requirement: deny 設定が auto-merge 配線と同じ場所から配布される（issue #213） ---

@test "deny: settings.json fragment exists, parses, and denies merge / main push / force push" {
  command -v jq >/dev/null || skip "jq not installed"
  [ -f "$DENY" ]
  jq -e '.permissions.deny | type == "array"' "$DENY" >/dev/null
  for p in 'Bash(gh pr merge:*)' 'Bash(git push origin main:*)' 'Bash(git push origin master:*)' \
           'Bash(git push --force:*)' 'Bash(git push -f:*)' 'Bash(git push --force-with-lease:*)' \
           'Bash(git push --no-verify:*)'; do
    jq -e --arg p "$p" '.permissions.deny | index($p) != null' "$DENY" >/dev/null
  done
}

@test "deny: README and docs describe merging into an existing settings.json without dropping deny entries" {
  grep -qF '.claude/settings.json' "$README"
  grep -q 'deny' "$README"
  grep -q '既存の deny を消さずに' "$README"
  grep -q 'deny' "$DOC"
  grep -qF 'Bash(gh pr merge:*)' "$DOC"
}

@test "deny: README merge command preserves existing deny entries and other keys" {
  command -v jq >/dev/null || skip "jq not installed"
  cur="$BATS_TEST_TMPDIR/settings.json"
  cat > "$cur" <<'EOF'
{"permissions":{"allow":["Bash(ls:*)"],"deny":["Bash(rm -rf:*)","Bash(gh pr merge:*)"]},"env":{"FOO":"bar"}}
EOF
  # README の jq 式をそのまま実行する（手順書とテストのズレを作らない）
  expr="$(sed -n "/jq -s '/,/unique)'/p" "$README" | tr -d '\\' | sed "s/^ *//; s/[[:space:]]*\$//" | sed "s/^jq -s '//; s/'\$//" | tr '\n' ' ')"
  [ -n "$expr" ]
  jq -s "$expr" "$cur" "$DENY" > "$cur.merged"
  jq -e '.permissions.deny | index("Bash(rm -rf:*)") != null' "$cur.merged" >/dev/null
  jq -e '.permissions.deny | index("Bash(git push --force:*)") != null' "$cur.merged" >/dev/null
  jq -e '.permissions.allow == ["Bash(ls:*)"]' "$cur.merged" >/dev/null
  jq -e '.env.FOO == "bar"' "$cur.merged" >/dev/null
  # 重複しない（既存にあった gh pr merge は 1 件のまま）
  [ "$(jq '[.permissions.deny[] | select(. == "Bash(gh pr merge:*)")] | length' "$cur.merged")" -eq 1 ]
}

@test "deny: README step 7 works on a repo that has no .claude directory yet" {
  command -v jq >/dev/null || skip "jq not installed"
  repo="$BATS_TEST_TMPDIR/fresh-repo"
  mkdir -p "$repo/.github/workflows"
  # README 手順 7 のコードブロックを <repo> / $TPL だけ置換してそのまま実行する
  block="$(sed -n '/^   # 展開先に .claude\/ が無くても/,/&& mv /p' "$README" | sed 's/^   //' | sed "s#<repo>#$repo#g")"
  [ -n "$block" ]
  run env TPL="$TPL" bash -c "$block"
  [ "$status" -eq 0 ]
  jq -e '.permissions.deny | index("Bash(gh pr merge:*)") != null' "$repo/.claude/settings.json" >/dev/null
}

# staging-smoke.yml の revert ステップを、実 git（bare remote）と記録用 gh スタブで実行する。
# $1=シナリオ名、環境変数 MAIN_ADVANCED=1 で main を BAD_SHA から進める、FAIL_PR=1 で gh pr create を失敗させる
run_revert_script() {
  local d="$BATS_TEST_TMPDIR/rv-$1" bin
  bin="$d/bin"; mkdir -p "$bin" "$d/state"
  git init -q --bare "$d/remote.git"
  git init -q -b main "$d/work"
  git -C "$d/work" config user.email t@example.test; git -C "$d/work" config user.name t
  git -C "$d/work" remote add origin "$d/remote.git"
  printf 'a\n' > "$d/work/f.txt"; git -C "$d/work" add f.txt; git -C "$d/work" commit -qm base
  printf 'b\n' > "$d/work/f.txt"; git -C "$d/work" commit -qam bad
  BAD="$(git -C "$d/work" rev-parse HEAD)"
  if [ "${MAIN_ADVANCED:-0}" = 1 ]; then printf 'c\n' > "$d/work/f.txt"; git -C "$d/work" commit -qam later; fi
  git -C "$d/work" push -q origin main
  cat > "$bin/gh" <<EOF
#!/bin/bash
S="$d/state"
echo "\$*" >> "\$S/calls.log"
case "\$1 \$2" in
  "label create") exit 0 ;;
  "issue list") [ -f "\$S/issue" ] && echo "https://example.test/o/r/issues/1" ; exit 0 ;;
  "issue create") touch "\$S/issue"; echo "https://example.test/o/r/issues/1" ;;
  "issue view") exit 0 ;;
  "issue comment") exit 0 ;;
  "pr list") [ -f "\$S/pr" ] && echo "https://example.test/o/r/pull/7" ; exit 0 ;;
  "pr create") [ "\${FAIL_PR:-0}" = 1 ] && exit 1; touch "\$S/pr"; echo "https://example.test/o/r/pull/7" ;;
  "api "*) exit 0 ;;
esac
exit 0
EOF
  chmod +x "$bin/gh"
  sed -n '/# >>> smoke-revert-script/,/# <<< smoke-revert-script/p' "$SMOKE" | sed 's/^          //' > "$d/revert.sh"
  cd "$d/work"
  run env PATH="$bin:$PATH" GH_TOKEN=x MERGE_TOKEN=y REPO=o/r BAD_SHA="$BAD" RUN_URL=https://example.test/run bash "$d/revert.sh"
  CALLS="$d/state/calls.log"
  RV_DIR="$d"
}

@test "revert script: normal failure creates the incident issue first, then the revert PR" {
  command -v git >/dev/null || skip "git not installed"
  run_revert_script normal
  [ "$status" -eq 0 ]
  grep -q '^issue create' "$CALLS"
  grep -q '^pr create' "$CALLS"
  [ "$(grep -n '^issue create' "$CALLS" | head -1 | cut -d: -f1)" -lt "$(grep -n '^pr create' "$CALLS" | head -1 | cut -d: -f1)" ]
}

@test "revert script: the revert PR is created without agent-review:passed and gets no HEAD comment" {
  command -v git >/dev/null || skip "git not installed"
  run_revert_script nopassed
  [ "$status" -eq 0 ]
  grep -q '^pr create' "$CALLS"
  grep '^pr create' "$CALLS" | grep -q -- '--label incident'
  ! grep -q -- '--label agent-review:passed' "$CALLS" || return 1
  ! grep -q '対象 HEAD' "$CALLS" || return 1
  ! grep -q '^api .*-X POST' "$CALLS" || return 1
}

@test "revert script: main already moved past the deployed commit -> incident only, no revert PR" {
  command -v git >/dev/null || skip "git not installed"
  MAIN_ADVANCED=1 run_revert_script advanced
  [ "$status" -eq 0 ]
  grep -q '^issue create' "$CALLS"
  ! grep -q '^pr create' "$CALLS" || return 1
  ! git -C "$RV_DIR/remote.git" rev-parse --verify -q "refs/heads/revert-auto-${BAD:0:12}" >/dev/null || return 1
}

@test "revert script: incident exists even when the revert PR cannot be created, and a re-run recovers the PR" {
  command -v git >/dev/null || skip "git not installed"
  FAIL_PR=1 run_revert_script partial
  [ "$status" -ne 0 ]
  grep -q '^issue create' "$CALLS"
  git -C "$RV_DIR/remote.git" rev-parse --verify -q "refs/heads/revert-auto-${BAD:0:12}" >/dev/null
  # 再実行: ブランチは push 済み。PR が無ければ作り直し、incident は重複起票しない
  : > "$CALLS"
  cd "$RV_DIR/work"
  run env PATH="$RV_DIR/bin:$PATH" GH_TOKEN=x MERGE_TOKEN=y REPO=o/r BAD_SHA="$BAD" RUN_URL=https://example.test/run bash "$RV_DIR/revert.sh"
  [ "$status" -eq 0 ]
  grep -q '^pr create' "$CALLS"
  ! grep -q '^issue create' "$CALLS" || return 1
}

# --- Requirement: 自動マージの処理は親の判断の印を受け取り、聖域接触だけで付いた human-merge を見送りの理由から外す（issue #1030） ---

PJ_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
PJ_OLD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

# 印のコメント 1 件の JSON。$1=author_association $2=親が見た HEAD $3=改行（既定 \n）
pj_mark() {
  local nl="${3:-\\n}"
  printf '{"author_association":"%s","html_url":"https://example.test/o/r/pull/7#issuecomment-1","body":"親のマージ判断: 可%s親が見た HEAD: %s%s理由: テスト"}' "$1" "$nl" "$2" "$nl"
}
pj_passed() {
  printf '{"author_association":"OWNER","html_url":"https://example.test/o/r/pull/7#issuecomment-0","body":"対象 HEAD: %s\\n合格"}' "$PJ_HEAD"
}

# parent-merge-judgment の関数を、ワークフローの SACRED / MERGE_CONDITION / BLOCKING_LABELS と
# いっしょに取り出し、記録用 gh スタブで 1 回呼ぶ。
# $1=シナリオ名 $2=ラベル（改行区切り） $3=変更ファイル（改行区切り） $4=コメントの JSON 配列
# 環境変数 FAIL_COMMENTS=1 でコメント取得を失敗させる、PJ_HEAD_IN で判定時の HEAD を差し替える、PJ_WF で対象のワークフローを差し替える
run_parent_judgment() {
  local d="$BATS_TEST_TMPDIR/pj-$1" wf="${PJ_WF:-$WF}"
  mkdir -p "$d/bin"
  printf '%s' "$4" > "$d/comments.json"
  cat > "$d/bin/gh" <<EOF
#!/bin/bash
[ "\${FAIL_COMMENTS:-0}" = 1 ] && exit 1
case "\$*" in
  *--slurp*) printf '[%s]' "\$(cat "$d/comments.json")" ;;
  *) cat "$d/comments.json" ;;
esac
EOF
  chmod +x "$d/bin/gh"
  {
    sed -n '/# >>> sacred-paths$/,/# <<< sacred-paths$/p' "$wf" | sed 's/^          //'
    sed -n '/# >>> merge-condition-paths/,/# <<< merge-condition-paths/p' "$wf" | sed 's/^          //'
    sed -n "/BLOCKING_LABELS='/,/'\$/p" "$wf" | sed 's/^          //'
    sed -n '/# >>> parent-merge-judgment/,/# <<< parent-merge-judgment/p' "$wf" | sed 's/^          //'
    cat <<'EOF'
parent_merge_judgment "$PJ_N" "$PJ_HEAD_IN" "$PJ_LABELS" "$PJ_FILES"
echo "PARENT_OK=$PARENT_OK"
echo "URL=$PARENT_COMMENT_URL"
EOF
  } > "$d/driver.sh"
  run env PATH="$d/bin:$PATH" REPO=o/r PJ_N=7 PJ_HEAD_IN="${PJ_HEAD_IN:-$PJ_HEAD}" PJ_LABELS="$2" PJ_FILES="$3" bash -euo pipefail "$d/driver.sh"
}

LBL_OK='agent-review:passed
human-merge
parent-merge-approved'

@test "parent judgment: sacred-only PR with label and OWNER mark -> PARENT_OK true with the mark URL" {
  run_parent_judgment ok "$LBL_OK" "CLAUDE.md" "[$(pj_passed),$(pj_mark OWNER "$PJ_HEAD")]"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=true'
  printf '%s\n' "$output" | grep -qx 'URL=https://example.test/o/r/pull/7#issuecomment-1'
}

@test "parent judgment: MEMBER and COLLABORATOR marks are accepted" {
  for a in MEMBER COLLABORATOR; do
    run_parent_judgment "assoc-$a" "$LBL_OK" "CLAUDE.md" "[$(pj_mark "$a" "$PJ_HEAD")]"
    printf '%s\n' "$output" | grep -qx 'PARENT_OK=true'
  done
}

@test "parent judgment: a mark posted from the Web UI (CRLF line breaks) still counts" {
  run_parent_judgment crlf "$LBL_OK" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD" '\r\n')]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=true'
}

@test "parent judgment: touching the merge condition itself (incl. rename source) -> false" {
  run_parent_judgment mc1 "$LBL_OK" "$(printf 'CLAUDE.md\n.github/workflows/ci.yml')" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  # rename 元（previous_filename）も変更ファイルの一覧に入る
  run_parent_judgment mc2 "$LBL_OK" "$(printf 'docs/new.yml\n.github/workflows/old.yml')" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
}

@test "parent judgment: deployed workflow treats pr-review-gate as the merge condition" {
  local dep="$PLUGIN_DIR/../../.github/workflows/auto-merge.yml"
  [ -f "$dep" ] || skip "not in the claude-harness tree"
  PJ_WF="$dep" run_parent_judgment dep-ok "$LBL_OK" "rules/example.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=true'
  PJ_WF="$dep" run_parent_judgment dep-mc "$LBL_OK" "plugins/dev-workflow/skills/pr-review-gate/SKILL.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  PJ_WF="$dep" run_parent_judgment dep-ib "$LBL_OK" "tests/injection-budget.txt" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=true'
}

@test "parent judgment: mark for an older HEAD -> false" {
  run_parent_judgment stale "$LBL_OK" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_OLD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
}

@test "parent judgment: other blocking labels are never lifted" {
  for L in needs-approval needs-human-merge human-only; do
    run_parent_judgment "blk-$L" "$(printf '%s\n%s' "$LBL_OK" "$L")" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
    printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  done
}

@test "parent judgment: human-merge on a PR that touches no sacred path stays" {
  run_parent_judgment nosacred "$LBL_OK" "src/app.js" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
}

@test "parent judgment: label only / comment only / outside author -> false" {
  run_parent_judgment labelonly "$LBL_OK" "CLAUDE.md" "[$(pj_passed)]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  run_parent_judgment commentonly "$(printf 'agent-review:passed\nhuman-merge')" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  for a in NONE CONTRIBUTOR; do
    run_parent_judgment "outside-$a" "$LBL_OK" "CLAUDE.md" "[$(pj_mark "$a" "$PJ_HEAD")]"
    printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  done
}

@test "parent judgment: first line must be exactly the mark" {
  local c
  c='{"author_association":"OWNER","html_url":"u","body":"前置き\n親のマージ判断: 可\n親が見た HEAD: '"$PJ_HEAD"'"}'
  run_parent_judgment firstline "$LBL_OK" "CLAUDE.md" "[$c]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
}

@test "parent judgment: mark before human-merge -> false first, true once human-merge is on" {
  run_parent_judgment early1 "$(printf 'agent-review:passed\nparent-merge-approved')" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  run_parent_judgment early2 "$LBL_OK" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=true'
}

@test "parent judgment: comment fetch failure or malformed HEAD -> false (fail-closed)" {
  FAIL_COMMENTS=1 run_parent_judgment fetchfail "$LBL_OK" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
  PJ_HEAD_IN=abc123 run_parent_judgment badhead "$LBL_OK" "CLAUDE.md" "[$(pj_mark OWNER abc123)]"
  printf '%s\n' "$output" | grep -qx 'PARENT_OK=false'
}

@test "parent judgment: the mark never satisfies the passed-HEAD binding" {
  block="$(sed -n '/# >>> passed-head-binding/,/# <<< passed-head-binding/p' "$WF")"
  printf '%s\n' "$block" | grep -qF 'grep -qF "対象 HEAD: $HEAD_SHA"'
  ! pj_mark OWNER "$PJ_HEAD" | grep -qF "対象 HEAD: $PJ_HEAD" || return 1
}

# automerge-script 全体を、エンドポイントごとに fixture を返す gh スタブ（--jq は本物の jq で適用）で動かす。
# $1=シナリオ名 $2=1 回目のラベル $3=2 回目以降のラベル（マージ直前の取り直し） $4=変更ファイル $5=コメントの JSON 配列
run_automerge_e2e() {
  local d="$BATS_TEST_TMPDIR/e2e-$1" checks
  mkdir -p "$d/bin"
  printf '%s' "$5" > "$d/comments.json"
  printf '%s\n' "$2" | jq -R . | jq -s 'map(select(length>0)) | map({name:.})' > "$d/labels1.json"
  printf '%s\n' "$3" | jq -R . | jq -s 'map(select(length>0)) | map({name:.})' > "$d/labels2.json"
  printf '%s\n' "$4" | jq -R . | jq -s 'map(select(length>0)) | map({filename:.})' > "$d/files.json"
  printf '{"draft":false,"head":{"sha":"%s"},"base":{"ref":"main"},"merged":false}' "$PJ_HEAD" > "$d/pr.json"
  sed -n "/REQUIRED_CHECKS='/,/'\$/p" "$WF" | sed "s/^ *//; s/^REQUIRED_CHECKS='//; s/'\$//" | grep -v '^$' \
    | jq -R . | jq -s '{check_runs: map({name:., conclusion:"success", started_at:"2026-01-01T00:00:00Z"})}' > "$d/checks.json"
  cat > "$d/bin/gh" <<EOF
#!/bin/bash
F="$d"
echo "\$*" >> "\$F/calls.log"
[ "\$1" = label ] && exit 0
if [ "\$1" = pr ] && [ "\$2" = comment ]; then printf '%s\n' "\$*" >> "\$F/pr-comments.log"; exit 0; fi
[ "\$1" = api ] || exit 0
shift
method=GET; jqexpr=""; slurp=0; ep=""; hasf=0
while [ \$# -gt 0 ]; do
  case "\$1" in
    -X) method="\$2"; shift 2 ;;
    --jq) jqexpr="\$2"; shift 2 ;;
    --slurp) slurp=1; shift ;;
    --paginate) shift ;;
    -f|-F) hasf=1; shift 2 ;;
    *) ep="\$1"; shift ;;
  esac
done
[ "\$method" = GET ] && [ "\$hasf" = 1 ] && method=POST
case "\$method \$ep" in
  "PUT "*/merge) touch "\$F/merged"; exit 0 ;;
  "POST "*/labels) touch "\$F/human-merge-added"; exit 0 ;;
esac
case "\$ep" in
  */issues/*/comments*) body=\$(cat "\$F/comments.json") ;;
  */issues/*/labels) n=\$(cat "\$F/labels-count" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "\$F/labels-count"
    if [ "\$n" -ge 2 ]; then body=\$(cat "\$F/labels2.json"); else body=\$(cat "\$F/labels1.json"); fi ;;
  */pulls/*/files*) body=\$(cat "\$F/files.json") ;;
  */check-runs*) body=\$(cat "\$F/checks.json") ;;
  */pulls/*) body=\$(cat "\$F/pr.json") ;;
  *) body='[]' ;;
esac
[ "\$slurp" = 1 ] && body="[\$body]"
if [ -n "\$jqexpr" ]; then printf '%s' "\$body" | jq -r "\$jqexpr"; else printf '%s' "\$body"; fi
EOF
  chmod +x "$d/bin/gh"
  sed -n '/# >>> automerge-script/,/# <<< automerge-script/p' "$WF" | sed 's/^          //' > "$d/am.sh"
  run env PATH="$d/bin:$PATH" GH_TOKEN=x MERGE_TOKEN=y REPO=o/r BASE_BRANCH=main AUTOMERGE_PAUSED= DRY_RUN=false \
    ONLY_PR=7 EVENT_NAME=workflow_dispatch EVENT_PR= RUN_URL=https://example.test/run bash "$d/am.sh"
  E2E_DIR="$d"
}

@test "e2e: sacred-only PR with the parent mark merges, and the merge comment names the mark" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e merge "$LBL_OK" "$LBL_OK" "CLAUDE.md" "[$(pj_passed),$(pj_mark OWNER "$PJ_HEAD")]"
  echo "$output"
  [ "$status" -eq 0 ]
  [ -f "$E2E_DIR/merged" ]
  [ ! -f "$E2E_DIR/human-merge-added" ]
  grep -qF 'issuecomment-1' "$E2E_DIR/pr-comments.log"
  grep -qF 'human-merge' "$E2E_DIR/pr-comments.log"
  printf '%s\n' "$output" | grep -qF '親の判断'
}

@test "e2e: without the mark a sacred PR gets human-merge and does not merge" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e nomark "agent-review:passed" "agent-review:passed" "CLAUDE.md" "[$(pj_passed)]"
  [ "$status" -eq 0 ]
  [ ! -f "$E2E_DIR/merged" ]
  [ -f "$E2E_DIR/human-merge-added" ]
}

@test "e2e: merge-condition PR with the mark does not merge" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e mc "$LBL_OK" "$LBL_OK" "$(printf 'CLAUDE.md\n.github/workflows/ci.yml')" "[$(pj_passed),$(pj_mark OWNER "$PJ_HEAD")]"
  [ "$status" -eq 0 ]
  [ ! -f "$E2E_DIR/merged" ]
}

@test "e2e: the mark label removed before the pre-merge recheck -> no merge" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e recheck "$LBL_OK" "$(printf 'agent-review:passed\nhuman-merge')" "CLAUDE.md" "[$(pj_passed),$(pj_mark OWNER "$PJ_HEAD")]"
  echo "$output"
  [ "$status" -eq 0 ]
  [ ! -f "$E2E_DIR/merged" ]
}

@test "e2e: human-merge removed by hand before the recheck still blocks a sacred PR" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e recheck2 "$LBL_OK" "$(printf 'agent-review:passed\nparent-merge-approved')" "CLAUDE.md" "[$(pj_passed),$(pj_mark OWNER "$PJ_HEAD")]"
  [ "$status" -eq 0 ]
  [ ! -f "$E2E_DIR/merged" ]
}

@test "e2e: mark alone is not the passed-HEAD binding" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e nobinding "$LBL_OK" "$LBL_OK" "CLAUDE.md" "[$(pj_mark OWNER "$PJ_HEAD")]"
  [ "$status" -eq 0 ]
  [ ! -f "$E2E_DIR/merged" ]
  printf '%s\n' "$output" | grep -qF '対象 HEAD'
}

@test "e2e: plain non-sacred PR still merges exactly as before" {
  command -v jq >/dev/null || skip "jq not installed"
  run_automerge_e2e plain "agent-review:passed" "agent-review:passed" "src/app.js" "[$(pj_passed)]"
  [ "$status" -eq 0 ]
  [ -f "$E2E_DIR/merged" ]
  ! grep -qF '親の判断' "$E2E_DIR/pr-comments.log" || return 1
}

@test "invariant: job if: runs on parent-merge-approved, trigger stays labeled-only" {
  grep -qE "^ *if: .*github\.event\.label\.name == 'parent-merge-approved'" "$WF"
  grep -qE "^ *if: .*github\.event\.label\.name == 'agent-review:passed'" "$WF"
  [ "$(awk '/^  pull_request_target:/{f=1;next} /^  [a-z_]/{f=0} f' "$WF" | grep -E '^ *types:' | sed 's/^ *//')" = "types: [labeled]" ]
}

# --- Requirement: 運用ガイドはリポ非依存の記述で提供される ---

@test "portability: no hardcoded flatmate repo URL anywhere in the template" {
  ! grep -r 'genetta-inc/flatmate' "$TPL" || return 1
}

# --- 自己検証: 同梱の攻撃再現テストがテンプレート自身に対して pass する ---

@test "self-test: bundled test script supports ROOT override" {
  grep -qF 'AUTOMERGE_TEST_ROOT' "$TST"
}

@test "self-test: bundled attack-reproduction suite passes against the template tree" {
  command -v jq >/dev/null || skip "jq not installed"
  fix="$BATS_TEST_TMPDIR/deploy"
  mkdir -p "$fix/.github/workflows" "$fix/docs" "$fix/scripts"
  cp "$WF" "$RV" "$fix/.github/workflows/"
  cp "$DOC" "$fix/docs/"
  cp "$TST" "$fix/scripts/"

  # REQUIRED_CHECKS からジョブ名を抽出し、名前が一致する ci.yml を fixture に生成する
  # （テンプレート既定値と ci.yml の整合検査が「実際に通る」ことまで確かめる）
  {
    echo "name: CI"
    echo "on: [push]"
    echo "jobs:"
    i=0
    sed -n "/# >>> required-checks/,/# <<< required-checks/p" "$WF" \
      | grep -v '# >>>' | grep -v '# <<<' \
      | sed "s/^ *//; s/^REQUIRED_CHECKS='//; s/'\$//" | grep -v '^$' \
      | while IFS= read -r name; do
          i=$((i + 1))
          echo "  job${i}:"
          echo "    name: ${name}"
          echo "    runs-on: ubuntu-latest"
          echo "    steps:"
          echo "      - run: 'true'"
        done
  } > "$fix/.github/workflows/ci.yml"

  run env AUTOMERGE_TEST_ROOT="$fix" sh "$fix/scripts/test-auto-merge-workflow.sh"
  echo "$output"
  [ "$status" -eq 0 ]
  # 1 件も FAIL していないこと（サマリ行の目視相当を機械化）
  ! printf '%s\n' "$output" | grep -q '^FAIL' || return 1
}
