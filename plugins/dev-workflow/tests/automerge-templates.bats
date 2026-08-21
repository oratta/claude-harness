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
}

# --- Requirement: auto-merge workflow 一式がテンプレートとして配布される ---

@test "files: deployment-tree mirror and README all exist" {
  [ -f "$WF" ]
  [ -f "$RV" ]
  [ -f "$DOC" ]
  [ -f "$TST" ]
  [ -f "$README" ]
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
