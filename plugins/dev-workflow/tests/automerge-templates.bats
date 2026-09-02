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
  for m in sacred-paths sacred-paths-jq required-checks labeled-target passed-head-binding pre-merge-recheck automerge-script; do
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
}

# --- Requirement: テンプレートは flatmate で実証済みの安全不変条件を維持する ---

@test "invariant: no bare pull_request trigger (head-side definition must never run)" {
  on_block="$(awk '/^on:/{f=1;next} /^[^ #]/{f=0} f' "$WF")"
  ! printf '%s\n' "$on_block" | grep -qE '^ *pull_request:'
}

@test "invariant: pull_request_target restricted to labeled events" {
  types="$(awk '/^on:/{f=1;next} /^[^ #]/{f=0} f' "$WF" \
    | awk '/^  pull_request_target:/{f=1;next} /^  [a-z_]/{f=0} f' \
    | grep -E '^ *types:' | sed 's/^ *//')"
  [ "$types" = "types: [labeled]" ]
}

@test "invariant: auto-merge.yml never checks out or clones PR head" {
  ! grep -vE '^ *#' "$WF" | grep -qE 'actions/checkout|git +clone|gh pr checkout'
}

@test "invariant: merge is SHA-pinned REST, not gh pr merge" {
  # コメントを除いた実行コードに gh pr merge が無いこと
  ! sed -n '/# >>> automerge-script/,/# <<< automerge-script/p' "$WF" | sed 's/#.*//' | grep -qF 'gh pr merge'
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
  ! grep -qF 'gh pr merge' "$RV"
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
  # revert PR は auto-merge の合格条件（passed ラベル + 対象 HEAD コメント）を機械的に満たす
  printf '%s\n' "$code" | grep -qF -- '--label "agent-review:passed"'
  printf '%s\n' "$code" | grep -qF '対象 HEAD: $REVERT_SHA'
  # revert ジョブは「検証不能」判定のときは走らない
  grep -qF "needs.smoke.outputs.blocked != 'true'" "$SMOKE"
  grep -qF "needs.smoke.outputs.blocked == 'true'" "$SMOKE"
  # デプロイ自体の失敗は incident issue の経路がある
  grep -qF "github.event.workflow_run.conclusion == 'failure'" "$SMOKE"
  # 自動 revert は絶対にマージしない
  ! printf '%s\n' "$code" | grep -qF 'gh pr merge'
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
  ! grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE"
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
  ! grep -qF 'blocked=true' "$out"
  printf '%s\n' "$output" | grep -qF 'HTTP401:認証系'
  printf '%s\n' "$output" | grep -qF 'HTTP500'
}

@test "smoke guard: all 200 -> success, and unset STAGING_DOMAIN -> skipped" {
  run_smoke_with_code 200 "ok"
  [ "$status" -eq 0 ]
  ! grep -qF 'blocked=true' "$SMOKE_OUTPUT_FILE"
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

# --- Requirement: 運用ガイドはリポ非依存の記述で提供される ---

@test "portability: no hardcoded flatmate repo URL anywhere in the template" {
  ! grep -r 'genetta-inc/flatmate' "$TPL"
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
  ! printf '%s\n' "$output" | grep -q '^FAIL'
}
