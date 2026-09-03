#!/usr/bin/env bats
#
# pr-review-gate の仕様宣言（issue #191）
# 手順 3 の第 3 のコメント（仕様宣言）、手順 5 の 3 見出し実測と issue 記録との整合照合、
# spec-touch-check の参照、auto-merge 範囲外の明記を SKILL.md の記述として検証する。
# issue #211（issue 無し PR のフォールバック）と issue #220（空本文の fail-closed）は手順 1 / 5 のコマンド例を偽 gh で実行して検証する。
# spec: dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

head_sec() { awk '/^## 前提と理由/{f=1} /^## 手順/{f=0} f' "$SKILL"; }
step3() { awk '/^### 3\. /{f=1} /^### 4\. /{f=0} f' "$SKILL"; }
step5() { awk '/^### 5\. /{f=1} /^### 6\. /{f=0} f' "$SKILL"; }

# --- Requirement: 仕様宣言を通過の必須点に加える ---

@test "intro: required points list includes the spec declaration" {
  sed -n 1,20p "$SKILL" | grep -q '通過の必須' 
  sed -n 1,20p "$SKILL" | grep '通過の必須' | grep -q '仕様宣言'
}

@test "step 3: spec declaration heading with target-HEAD first line" {
  step3 | grep -q '^## 仕様宣言$'
  step3 | awk '/^## 仕様宣言$/{getline; print}' | grep -q '^対象 HEAD:'
}

@test "step 3: both forms (updated / no-change with reason) are templated" {
  step3 | grep -q '仕様: 更新した'
  step3 | grep -q '仕様: 変更なし'
  step3 | grep -q 'archive 済み'
  step3 | grep -q '仕様レビュー: APPROVE'
  step3 | grep -qE '変更なし.*理由'
}

@test "step 3: declaration is mandatory (not writing is not an option)" {
  step3 | grep -qE '仕様宣言.*(書かない.*選べない|必ず)'
}

# --- Requirement: 合格処理は仕様宣言の実在と issue 記録との整合を実測する ---

@test "step 5: SHA-bound listing must show all three headings" {
  step5 | grep -q '仕様宣言'
  step5 | grep -qE '3 ?(見出し|つ).*(すべて|全部|揃)'
  ! step5 | grep -q '見出しが両方'
}

@test "step 5: consistency table has yes / no / no-record rows" {
  step5 | grep -q '仕様化判断: する'
  step5 | grep -q '仕様化判断: しない'
  step5 | grep -q '記録なし'
  step5 | grep -qE 'archive.*実測|実測.*archive'
  step5 | grep -qE 'しない.*openspec.*(差分|矛盾)|差分.*しない.*矛盾'
  step5 | grep -q '仕様レビュー: APPROVE'
}

@test "step 5: issue is resolved from Closes/Fixes/Refs and issue side wins" {
  step5 | grep -qE 'Closes.*Fixes.*Refs'
  step5 | grep -qE 'issue 参照が無い場合に限|issue 側が正'
}

@test "step 5: no record -> no pass, record first" {
  step5 | grep -qE '記録なし.*(合格しない|合格処理をしない|不可)'
}

# 手順 5 に書かれた jq 式を SKILL.md から抜き出し、fixture で実行する（式が実際に「最新 1 件」を選ぶこと）
jq_prog() { step5 | grep -- "| jq -r" | grep "$1" | head -1 | sed -E "s/.*jq -r '([^']*)'.*/\\1/"; }
fixture_pages() {
  # --paginate --slurp の出力形（ページの配列）を模す
  printf '[[{"body":"仕様レビュー: APPROVE\\n1 周目"},{"body":"雑談"}],[{"body":"仕様レビュー: REQUEST_CHANGES\\n2 周目"},{"body":"仕様化判断: **する**"},{"body":"仕様化判断: しない\\n理由: x"}]]'
}

@test "step 5 jq: latest review result wins (stale APPROVE does not pass)" {
  prog="$(jq_prog '仕様レビュー')"
  [ -n "$prog" ]
  out="$(fixture_pages | jq -r "$prog")"
  [ "$out" = "仕様レビュー: REQUEST_CHANGES" ]
}

@test "step 5 jq: decision picks the latest exact-format comment across pages" {
  prog="$(jq_prog '仕様化判断')"
  [ -n "$prog" ]
  out="$(fixture_pages | jq -r "$prog")"
  [ "$out" = "仕様化判断: しない" ]
}

@test "step 5: comments are fetched with --paginate --slurp piped to jq (slurp is incompatible with --jq)" {
  step5 | grep '仕様' | grep -- '--paginate --slurp' | grep -q -- '| jq -r'
  ! step5 | grep '^gh api' | grep -- '--slurp' | grep -q -- '--jq'
}

# --- Requirement: spec-touch-check スクリプトが規範パス接触と openspec 差分を報告する ---

@test "step 5: runs spec-touch-check.sh and demands a reason on exit 2" {
  step5 | grep -q 'spec-touch-check.sh'
  step5 | grep -qE '(終了コード|exit) ?2'
  step5 | grep -qE '規範.*(言及|理由)'
}

# --- Requirement: auto-merge への組み込みは範囲外と明記する ---

@test "intro: auto-merge integration is explicitly out of scope (separate issue)" {
  head_sec | grep '仕様宣言' | grep -q 'auto-merge'
  head_sec | grep '仕様宣言' | grep -qE '別 issue|範囲外'
}

@test "intro: HEAD SHA paragraph names the spec declaration too" {
  head_sec | grep 'HEAD SHA' | grep -q '仕様宣言'
}

# --- Requirement（issue #211）: issue 参照の無い PR では受け入れ条件・仕様化判断の取得先が PR 自身にフォールバックする ---
#
# 散文（「PR コメントへの記録が許されるのは PR 本文に issue 参照が無い場合に限る」）だけでなく、
# 手順 1 と手順 5 のコマンド例そのものが分岐を実装していることを、偽の gh で実行して確かめる。
# 偽の gh は呼び出しを $GH_LOG に記録し、path に応じて fixture を返す。

step1() { awk '/^### 1\. /{f=1} /^### 2\. /{f=0} f' "$SKILL"; }

# 指定した手順の fenced bash ブロックのうち ISSUE= を含むものから、実行対象の行だけを抜く
# （説明コメント行と <plugin> プレースホルダを含む spec-touch-check 行は除く）
issue_block_cmds() {
  "$1" | awk '/^ *```bash/{f=1; b=""; next} /^ *```/{ if (f && b ~ /ISSUE=/) printf "%s", b; f=0; next } f{ b = b $0 "\n" }' \
    | grep -E '^ *(ISSUE=|REC=|BODY=|gh api|if \[)'
}

install_fake_gh() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
ARGS="$*"
path=""
for a in "$@"; do case "$a" in repos/*) path="$a" ;; esac; done
# .body の値を --jq 式に応じて印字する（jq の挙動を模す）: 本文が JSON の null のとき、
# '.body' は文字列 null を印字し、'.body // ""' は空を印字する。それ以外はそのまま
jq_body() {
  if [ "$1" = null ] && [[ "$ARGS" == *'.body // ""'* ]]; then echo ""; else printf '%s\n' "$1"; fi
}
case "$path" in
  repos/*/issues/*/comments) printf '%s' "$MOCK_PAGES" ;;          # --paginate --slurp のページ配列
  repos/*/pulls/*)           jq_body "$MOCK_PR_BODY" ;;            # PR 本文（--jq .body）
  repos/*/issues/*)          jq_body "${MOCK_ISSUE_BODY-ISSUE BODY ${path##*/}}" ;;   # issue 本文（未設定なら固定文字列）
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  : > "$GH_LOG"
  export MOCK_PAGES="$(fixture_pages)"
  export R="o/r" N="42"
}

run_step_cmds() {  # $1 = step 関数名, $2 = PR 本文, $3 = issue 本文（省略時は固定文字列 ISSUE BODY N）
  cmds="$(issue_block_cmds "$1")"
  [ -n "$cmds" ]
  # set -e は付けない（issue 参照が無いとき grep が非 0 を返すのは正常経路。実行環境の Bash も -e ではない）
  if [ $# -ge 3 ]; then
    MOCK_PR_BODY="$2" MOCK_ISSUE_BODY="$3" PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash -c "$cmds"
  else
    MOCK_PR_BODY="$2" PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash -c "$cmds"
  fi
}

@test "step 1: acceptance criteria come from the issue when the PR body references one" {
  install_fake_gh
  out="$(run_step_cmds step1 'fix it. Closes #7')"
  [ "$out" = "ISSUE BODY 7" ]
  grep -q 'repos/o/r/issues/7 ' "$GH_LOG"
}

@test "step 1: acceptance criteria fall back to the PR body when there is no issue reference" {
  install_fake_gh
  out="$(run_step_cmds step1 'Draft PR 記録先。受け入れ条件はこの本文')"
  [ "$out" = "Draft PR 記録先。受け入れ条件はこの本文" ]
  ! grep -q 'issues/ ' "$GH_LOG"
  ! grep -q 'issues//' "$GH_LOG"
  grep -qE 'repos/o/r/pulls/42 .*\.body' "$GH_LOG"
}

# --- Requirement（issue #220）: 記録先の本文が空・null・空白のみなら受け入れ条件なしとして機械的に不合格へ倒す ---
#
# 手順 1-3 のコマンド例を偽の gh で実行し、非 0 終了かつ stderr に agent-review:failed を含む失敗メッセージが
# 出ることを、issue 本文経路・PR 本文経路の両方で確かめる（G が空出力を見て止まる、という運用頼みにしない）。

# run_step_cmds を run で包む。stdout / stderr を分けて取る（失敗メッセージは stderr、受け入れ条件は stdout）
run_step1_rejecting() {  # $1 = PR 本文, [$2 = issue 本文]
  install_fake_gh
  run --separate-stderr run_step_cmds step1 "$@"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  printf '%s\n' "$stderr" | grep -q 'agent-review:failed'
}

@test "step 1 (#220): empty PR body without an issue reference is rejected (non-zero + agent-review:failed)" {
  run_step1_rejecting ''
  grep -qE 'repos/o/r/pulls/42 .*\.body // ""' "$GH_LOG"
  ! grep -q 'issues//' "$GH_LOG"
}

@test "step 1 (#220): whitespace-only PR body without an issue reference is rejected" {
  run_step1_rejecting $'  \n\t \n'
}

@test "step 1 (#220): null issue body (Closes #N) is rejected — the command must use .body // \"\" so null does not pass as text" {
  run_step1_rejecting 'fix it. Closes #7' null
  grep -qE 'repos/o/r/issues/7 .*\.body // ""' "$GH_LOG"
}

@test "step 1 (#220): empty issue body (Closes #N) is rejected" {
  run_step1_rejecting 'fix it. Closes #7' ''
}

@test "step 1 (#220): whitespace-only issue body (Closes #N) is rejected" {
  run_step1_rejecting 'fix it. Closes #7' $'\n   \n'
}

@test "step 1 (#220): prose says an empty body cannot proceed to the pass path" {
  step1 | grep -vE '^\s*(```|gh |if |ISSUE=|fi)' | grep -qE '本文が空.*(合格|不合格|failed)'
}

@test "step 5: decision / review comments are read from the referenced issue" {
  install_fake_gh
  out="$(run_step_cmds step5 'Refs #7 の続き')"
  [ "$(printf '%s\n' "$out" | sed -n 1p)" = "仕様化判断: しない" ]
  [ "$(printf '%s\n' "$out" | sed -n 2p)" = "仕様レビュー: REQUEST_CHANGES" ]
  grep -q 'repos/o/r/issues/7/comments' "$GH_LOG"
  ! grep -q 'repos/o/r/issues/42/comments' "$GH_LOG"
}

@test "step 5: without an issue reference the PR's own comments (issues/<PR number>/comments) are read" {
  install_fake_gh
  out="$(run_step_cmds step5 'issue 参照なしの Draft PR 記録先')"
  [ "$(printf '%s\n' "$out" | sed -n 1p)" = "仕様化判断: しない" ]
  grep -q 'repos/o/r/issues/42/comments' "$GH_LOG"
  ! grep -q 'issues//comments' "$GH_LOG"
}

@test "step 1 and 5: prose names the fallback target (PR itself) next to the commands" {
  step1 | grep -qE 'issue 参照が無|issue が無'
  step1 | grep -q 'pulls/\$N'
  step5 | grep -q 'REC='
  step5 | grep -qE 'issue 参照が無.*PR 自身|PR 自身.*issue 参照が無'
}

# --- 既存件数固定アサーションを壊さない ---

@test "keeps single occurrence of the cross-layer-contract and sanctuary/merge-permission phrases" {
  [ "$(grep -cF '層間契約' "$SKILL")" -eq 1 ]
  [ "$(grep -cF '聖域パス・マージ権限' "$SKILL")" -eq 1 ]
}

# --- 配布 ---

@test "manifest: version above 1.12.0, marketplace in sync, description mentions the spec declaration" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$(printf '1.12.0\n%s\n' "$v" | sort -V | tail -1)" = "$v" ] && [ "$v" != "1.12.0" ]
  [ "$(jq -r '.plugins[] | select(.name=="dev-workflow") | .version' "$MARKETPLACE")" = "$v" ]
  jq -r '.description' "$MANIFEST" | grep -q '仕様宣言'
}

@test "skill frontmatter: version above 1.3.0" {
  v="$(awk '/^version:/{print $2; exit}' "$SKILL")"
  [ "$(printf '1.3.0\n%s\n' "$v" | sort -V | tail -1)" = "$v" ] && [ "$v" != "1.3.0" ]
}
