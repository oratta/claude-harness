#!/usr/bin/env bats
#
# 仕様の文言合わせの軽い通し方（issue #986。エピック #973 の子）
# 既存の仕様の文言を実装に合わせて直すだけの変更を、仕様の差分 1 ファイルだけで通し、
# R1 の仕様レビューを省く通し方が、指示書（develop）とゲート（pr-review-gate）に揃って書かれていること、
# ゲートの照合コマンドが fixture で期待どおりに振る舞うことを確かめる。
# spec: dev-workflow-spec-review / dev-workflow-develop / dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  REVIEWER="${PLUGIN_DIR}/skills/develop/references/roles/spec-reviewer.md"
  W_SPEC="${PLUGIN_DIR}/skills/develop/references/roles/worker/spec.md"
  W_COMMON="${PLUGIN_DIR}/skills/develop/references/roles/worker/common.md"
  W_IMPL="${PLUGIN_DIR}/skills/develop/references/roles/worker/implement.md"
  W_FINISH="${PLUGIN_DIR}/skills/develop/references/roles/worker/finish.md"
  DECLARATIONS="${PLUGIN_DIR}/skills/pr-review-gate/declarations.md"
  PASS_STAGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/pass.md"
}

# 「## <見出し>」で始まる節を、次の「## 」の手前まで切り出す（多バイトの見出しは index で比べる）
section() { LC_ALL=C awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }
step_b() { LC_ALL=C awk '/^## Step B/{f=1} /^## Step C/{f=0} f' "$CRITERIA"; }
# Step B の中の、文言合わせの通し方の小節だけ
light_sec() { step_b | LC_ALL=C awk '/^### /{f=0} index($0, "### 仕様化するが軽く通す")==1{f=1} f'; }
loop_sec() { section "$SKILL" '1 ループ'; }
mode_sec() { section "$SKILL" '実行モード'; }
contract_sec() { section "$REVIEWER" '判断記録の契約'; }
spawn_sec() { section "$REVIEWER" 'R1 の spawn'; }
before_impl_sec() { section "$W_COMMON" '実装に入る前の確認'; }
step3() { LC_ALL=C awk '/^### 3\. /{f=1} /^## 出口/{f=0} f' "$DECLARATIONS"; }
step3b() { LC_ALL=C awk '/^#### 3-b\. /{f=1} /^## 出口/{f=0} f' "$DECLARATIONS"; }
step5() { LC_ALL=C awk '/^### 5\. /{f=1} /^## (G として動くとき|出口)/{f=0} f' "$PASS_STAGE"; }

# --- Requirement: 仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く ---

@test "criteria: Step B has the wording-sync subsection between 'no spec' and 'record'" {
  step_b | grep -q '^### 仕様化するが軽く通す（仕様の文言合わせ）$'
  no="$(step_b | grep -n '^### 仕様化しない' | head -1 | cut -d: -f1)"
  light="$(step_b | grep -n '^### 仕様化するが軽く通す' | head -1 | cut -d: -f1)"
  rec="$(step_b | grep -n '^### 判定したら必ず記録する' | head -1 | cut -d: -f1)"
  [ -n "$no" ] && [ -n "$light" ] && [ -n "$rec" ]
  [ "$no" -lt "$light" ] && [ "$light" -lt "$rec" ]
}

@test "criteria: subsection states the single delta file and that R1's review is skipped" {
  light_sec | grep -q '仕様の差分 1 ファイル'
  light_sec | grep -qE 'R1 の仕様レビュー.*省'
  light_sec | grep -qE '実装後レビュー.*省かない'
}

@test "criteria: subsection states the four target conditions" {
  light_sec | grep -q '## MODIFIED Requirements'
  light_sec | grep -q '設計の選択が無い'
  light_sec | grep -q '1 つの capability'
}

@test "criteria: subsection states the apply condition and the fallback to full artifacts and R1" {
  light_sec | grep -q 'どの仕様のどの文をどう直すか'
  light_sec | grep -q '受け入れ条件'
  light_sec | grep -qE '書けていない.*artifact 一式.*R1'
  light_sec | grep -q '主に聞かない'
  light_sec | grep -q 'unmanned'
}

@test "criteria: subsection states the record line and forbids switching after R1 ran" {
  light_sec | grep -q '通し方: 文言合わせ'
  light_sec | grep -q '直す文:'
  light_sec | grep -qE 'R1 を一度起こした change.*切り替えない'
  light_sec | grep -qE '通し方:` の行の無い仕様化判断を投稿し直'
}

@test "criteria: record subsection and 'when unsure' subsection mention the wording-sync path" {
  step_b | LC_ALL=C awk '/^### /{f=0} index($0, "### 判定したら必ず記録する")==1{f=1} f' | grep -q '通し方: 文言合わせ'
  step_b | LC_ALL=C awk '/^### /{f=0} index($0, "### 判定に迷ったら")==1{f=1} f' | grep -qE '文言合わせ.*当てない'
}

@test "worker/spec: decision section writes the wording-sync and fix lines" {
  section "$W_SPEC" '仕様化判断' | grep -q '通し方: 文言合わせ'
  section "$W_SPEC" '仕様化判断' | grep -q '直す文:'
  section "$W_SPEC" '仕様化判断' | grep -qE 'gh (issue|pr) comment.*通し方: 文言合わせ.*直す文: '
  section "$W_SPEC" '仕様化判断' | grep -qE '文言合わせ.*decision-criteria.md'
  section "$W_SPEC" '仕様化判断' | grep -qE '迷ったら当てない'
}

@test "worker/spec: spec section writes only the delta file and no proposal/design/tasks" {
  section "$W_SPEC" '仕様化する場合' | grep -q 'specs/<capability>/spec.md'
  section "$W_SPEC" '仕様化する場合' | grep -q 'proposal・design・tasks を作らない'
  section "$W_SPEC" '仕様化する場合' | grep -q 'openspec validate <change-name> --type change --strict'
}

@test "worker/spec: work items go into the return and W waits for the main agent without R1" {
  section "$W_SPEC" '仕様化する場合' | grep '文言合わせ' | grep -q '触る範囲:'
  section "$W_SPEC" '仕様化する場合' | grep '文言合わせ' | grep -q 'return'
  section "$W_SPEC" '仕様化する場合' | grep -qE 'R1 のレビューは受けず.*本体の再開'
}

@test "worker/spec: leaving the target re-posts the decision, and no switching after R1 ran" {
  section "$W_SPEC" '仕様化する場合' | grep -qE '通し方:` の行の無い仕様化判断を投稿し直'
  section "$W_SPEC" '仕様化する場合' | grep -qE 'R1 を一度起こした change.*切り替えない'
}

@test "spec-reviewer: contract table has the wording-sync line and the fix-line form" {
  contract_sec | grep '^|' | grep -qF '^通し方: 文言合わせ$'
  contract_sec | grep '^|' | grep -qF '直す文: <spec のパス>「<要件名>」— <どう直すか>'
  contract_sec | grep '^|' | grep -F '^通し方: 文言合わせ$' | grep -q 'R1 を起こさ'
  contract_sec | grep '^|' | grep -F '^通し方: 文言合わせ$' | grep -q '仕様レビュー:` のコメントは無い'
  # 既存の 2 つの 1 行目の契約は変えない
  contract_sec | grep -qF '^仕様化判断: (する|しない)$'
  contract_sec | grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$'
}

@test "spec-reviewer: R1 is not spawned when the wording-sync line is present" {
  spawn_sec | grep -qE '通し方: 文言合わせ.*spawn しない'
}

@test "worker/common: keeps the APPROVE rule and adds the wording-sync exception" {
  before_impl_sec | grep -q 'R1 の APPROVE が記録先に記録されるまで実装に進まない'
  before_impl_sec | grep -qE '通し方: 文言合わせ.*APPROVE を求めない'
  before_impl_sec | grep '通し方: 文言合わせ' | grep -q '記録先のコメント'
}

# --- Requirement: 1 ループは W→R1→W→G の順で回る / 実行モード / W の仕様化経路 ---

@test "loop: wording-sync path skips (2) after the main agent checks the recorded line" {
  # (1) に足した行には「(2)」「(3)」「apply」「仕様レビュー」を書かない（既存の bats が 1 ループの節でこれらの語の最初の行の順を見ている）
  ! loop_sec | grep '文言合わせ' | grep 'return の文面ではなく\|仕様の差分 1 ファイルだけを書いて' | grep -q '(2)\|(3)\|apply\|仕様レビュー' || return 1
  loop_sec | grep '文言合わせ' | grep -q '仕様の差分 1 ファイル'
  loop_sec | grep -q '通し方: 文言合わせ'
  loop_sec | grep -qE '通し方: 文言合わせ.*R1 の工程を飛ばし.*段: implement'
  loop_sec | grep -qE 'return の文面ではなく'
  loop_sec | grep -qE '行が無ければ.*段: spec.*R1 の工程を通す'
  loop_sec | grep -q 'references/decision-criteria.md` Step B'
}

@test "loop: (2) names the wording-sync path as the only exception, (3a) uses --type change" {
  loop_sec | grep 'APPROVE が記録先に記録されるまで W を apply に進めない' | grep -q '文言合わせ'
  loop_sec | grep '(3a)' | grep -q '文言合わせ'
  loop_sec | grep -q 'openspec validate <change-name> --type change --strict'
}

@test "loop: before spawning G the main agent matches the fix lines against the archived delta" {
  line="$(loop_sec | grep 'G を起こす前' | grep '文言合わせ')"
  [ -n "$line" ]
  echo "$line" | grep -q '直す文:'
  echo "$line" | grep -q 'archive 済みの差分の要件名'
  # (3b) より後ろ・(4) の節の中に置く
  g="$(loop_sec | grep -n '^(4) G を' | head -1 | cut -d: -f1)"
  l="$(loop_sec | grep -n 'G を起こす前' | grep '文言合わせ' | head -1 | cut -d: -f1)"
  [ -n "$g" ] && [ "$g" -lt "$l" ]
}

@test "mode: unmanned keeps the no-exemption sentence and applies the same condition" {
  mode_sec | grep -q '仕様化判断の記録と仕様レビューは unmanned でも免除しない'
  mode_sec | grep '文言合わせ' | grep -q 'interactive と同じ'
  mode_sec | grep '文言合わせ' | grep -q '免除ではなく'
}

@test "worker/implement: wording-sync path validates with --type change and has no checkbox step" {
  grep -q 'openspec validate <change-name> --type change --strict' "$W_IMPL"
  grep '文言合わせ' "$W_IMPL" | grep -q 'Unknown item'
  grep '文言合わせ' "$W_IMPL" | grep -q -- '--changes'
  grep '文言合わせ' "$W_IMPL" | grep -q 'チェックボックスの確認は行わない'
}

@test "worker/finish: archive is confirmed by the directory, and the skipped-review form is named" {
  grep 'openspec archive <change-name>' "$W_FINISH" | grep -q 'openspec/changes/archive/'
  grep 'openspec archive <change-name>' "$W_FINISH" | grep -qE 'ディレクトリがあることを確かめる'
  grep 'openspec archive <change-name>' "$W_FINISH" | grep -q '終了コード 0'
  grep -q '仕様レビュー: 省いた（文言合わせ。' "$W_FINISH"
}

# --- Requirement: 仕様宣言を通過の必須点に加える ---

@test "step 3-b: three forms are templated (APPROVE / skipped for wording-sync / no change)" {
  step3b | grep -q '3 形のどれかちょうど'
  ! step3b | grep -q '2 形のどちらか' || return 1
  [ "$(step3b | grep -c '^仕様: 更新した — change <change-name>（archive 済み）')" -eq 2 ]
  step3b | grep -q '^仕様: 更新した — change <change-name>（archive 済み）／仕様レビュー: APPROVE（<issue コメントの URL>）$'
  step3b | grep -q '^仕様: 更新した — change <change-name>（archive 済み）／仕様レビュー: 省いた（文言合わせ。<仕様化判断のコメントの URL>）$'
  [ "$(step3b | grep -c '^仕様: 変更なし — 理由: ')" -eq 1 ]
  [ "$(step3b | grep -c '^## 仕様宣言$')" -eq 3 ]
}

@test "step 3-b: the skipped form is allowed only with the exact wording-sync line" {
  step3b | grep -F '^通し方: 文言合わせ$' | grep -q '最新の仕様化判断のコメント'
}

# --- Requirement: 合格処理は仕様宣言の実在と issue 記録との整合を実測する ---

table5() { step5 | grep '^| '; }

@test "step 5: consistency table has four rows" {
  [ "$(table5 | grep -c '^| `仕様化判断: する`（`通し方: 文言合わせ` の行なし） |')" -eq 1 ]
  [ "$(table5 | grep -c '^| `仕様化判断: する`＋`通し方: 文言合わせ` の行あり |')" -eq 1 ]
  [ "$(table5 | grep -c '^| `仕様化判断: しない` |')" -eq 1 ]
  [ "$(table5 | grep -c '^| 記録なし |')" -eq 1 ]
}

@test "step 5: wording-sync row skips the review comment and measures four points" {
  row="$(table5 | grep '^| `仕様化判断: する`＋`通し方: 文言合わせ` の行あり |')"
  echo "$row" | grep -qE '仕様レビュー:` のコメントは照合しない'
  echo "$row" | grep -q '仕様レビュー: 省いた（文言合わせ。'
  echo "$row" | grep -q 'openspec/changes/archive/\*-<change-name>/specs/\*/spec.md'
  echo "$row" | grep -q 'ちょうど 1 つ'
  echo "$row" | grep -q 'ADDED'
  echo "$row" | grep -q 'REMOVED'
  echo "$row" | grep -q 'RENAMED'
  echo "$row" | grep -q '直す文:'
  echo "$row" | grep -q '「<要件名>」'
  echo "$row" | grep -qE '1 つでも満たさなければ合格しない'
  echo "$row" | grep -qE '通し方:` の行の無い仕様化判断を投稿し直'
}

@test "step 5: plain 'yes' row still demands the APPROVE review" {
  table5 | grep '^| `仕様化判断: する`（`通し方: 文言合わせ` の行なし） |' | grep -q 'APPROVE'
}

@test "step 5: a PR without the wording-sync line cannot pass with the skipped form" {
  step5 | grep -v '^| ' | grep '仕様レビュー: 省いた' | grep -qE '行が無い PR.*仕様レビュー: APPROVE'
}

@test "step 5: the latest decision comment is read beyond its first line" {
  step5 | grep '仕様宣言は記録先の記録と突き合わせる' | grep -q '通し方:'
  step5 | grep '仕様宣言は記録先の記録と突き合わせる' | grep -q '直す文:'
}

@test "step 5: the body-returning jq sits after the two first-line jq commands" {
  first="$(step5 | grep -n -- '| jq -r' | grep '仕様化判断' | head -1 | cut -d: -f1)"
  rev="$(step5 | grep -n -- '| jq -r' | grep '仕様レビュー' | head -1 | cut -d: -f1)"
  dec="$(step5 | grep -n '^DEC=' | head -1 | cut -d: -f1)"
  [ -n "$first" ] && [ -n "$rev" ] && [ -n "$dec" ]
  [ "$first" -lt "$dec" ] && [ "$rev" -lt "$dec" ]
}

# 手順 5 に書かれた照合のコマンド（DEC= の行から、要件名の突き合わせの行まで）を抜き出して fixture で実行する。
# gh は fixture を返す偽物に差し替え、archive 済みの差分は一時ディレクトリに置く。
light_cmds() {
  step5 | LC_ALL=C awk '/^DEC=/{f=1} f{print} f && /^grep -h .*Requirement: /{exit}'
}

install_fake_gh() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
cat "$FIXTURE_PAGES"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
}

# $1 = 最新の仕様化判断のコメントの本文（JSON 文字列の中身。改行は \n）
write_pages() {
  FIXTURE_PAGES="$BATS_TEST_TMPDIR/pages.json"
  # --paginate --slurp の出力形（ページの配列）。1 ページ目に古い判断（通し方の行つき）を置く
  printf '[[{"body":"仕様化判断: する\\n理由: 古い判断\\n通し方: 文言合わせ\\n直す文: openspec/specs/demo/spec.md「古い要件」— 古い直し"},{"body":"雑談\\n通し方: 文言合わせ"}],[{"body":"%s"}]]' "$1" > "$FIXTURE_PAGES"
  export FIXTURE_PAGES
}

# $1 = 差分ファイルの本文
write_delta() {
  mkdir -p "$BATS_TEST_TMPDIR/work/openspec/changes/archive/2026-10-12-demo-change/specs/demo"
  printf '%s\n' "$1" > "$BATS_TEST_TMPDIR/work/openspec/changes/archive/2026-10-12-demo-change/specs/demo/spec.md"
}

run_light() {
  install_fake_gh
  cmds="$(light_cmds)"
  [ -n "$cmds" ]
  # set -e は付けない（0 件のとき grep が非 0 を返すのは正常経路。実行環境の Bash も -e ではない）
  cd "$BATS_TEST_TMPDIR/work"
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" R=o/r REC=1 CHANGE=demo-change bash -c "$cmds
echo \"WAY=\$WAY\""
}

DEC_LIGHT='仕様化判断: する\n理由: 文言を実装に合わせるだけ\n通し方: 文言合わせ\n直す文: openspec/specs/demo/spec.md「要件 A」— 既定値を 3 に直す\n直す文: openspec/specs/demo/spec.md「要件 B」— 語を揃える'
DELTA_OK='## MODIFIED Requirements

### Requirement: 要件 A
本文（MUST）。

#### Scenario: s
- **WHEN** x
- **THEN** y

### Requirement: 要件 B
本文（MUST）。

#### Scenario: s
- **WHEN** x
- **THEN** y'

@test "step 5 commands: extracted block has the count, the fix lines and the three measurements" {
  light_cmds | grep -q "grep -cx '通し方: 文言合わせ'"
  light_cmds | grep -q "grep '^直す文: '"
  light_cmds | grep -q 'ls openspec/changes/archive/\*-"\$CHANGE"/specs/\*/spec.md'
  light_cmds | grep -qF "grep -cE '^## (ADDED|REMOVED|RENAMED) Requirements'"
  light_cmds | grep -qF "grep -h '^### Requirement: '"
  # 0 件のとき grep -c は終了コード 1 を返すので、出力の値で判定すると書いてある
  step5 | grep -qE '終了コードではなく出力'
}

@test "step 5 commands: wording-sync PR with no review comment satisfies all measured points" {
  write_pages "$DEC_LIGHT"
  write_delta "$DELTA_OK"
  run_light
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'WAY=1'
  # 差分はちょうど 1 ファイル・ADDED / REMOVED / RENAMED の見出しは 0 件・直す文に無い要件は出力されない
  # 出力の並び: 1 行目 通し方の行の件数、2〜3 行目 直す文の行（fixture は 2 行）、4 行目 差分ファイルの数、5 行目 見出しの件数
  [ "$(echo "$output" | sed -n 1p)" = "1" ]
  [ "$(echo "$output" | sed -n 2,3p | grep -c '^直す文: ')" -eq 2 ]
  [ "$(echo "$output" | sed -n 4p | tr -d ' ')" = "1" ]
  [ "$(echo "$output" | sed -n 5p | tr -d ' ')" = "0" ]
  ! echo "$output" | grep -q '直す文に無い要件' || return 1
  # 記録先に仕様レビューのコメントは 1 件も無い（fixture にも無い）
  ! grep -q '仕様レビュー:' "$FIXTURE_PAGES" || return 1
}

@test "step 5 commands: a delta that adds a requirement is caught" {
  write_pages "$DEC_LIGHT"
  write_delta "## ADDED Requirements

### Requirement: 要件 A
本文（MUST）。

#### Scenario: s
- **WHEN** x
- **THEN** y"
  run_light
  echo "$output" | grep -qx 'WAY=1'
  [ "$(echo "$output" | sed -n 5p | tr -d ' ')" = "1" ]
}

@test "step 5 commands: a requirement missing from the fix lines is caught" {
  write_pages "$DEC_LIGHT"
  write_delta "${DELTA_OK}

### Requirement: 要件 C
本文（MUST）。

#### Scenario: s
- **WHEN** x
- **THEN** y"
  run_light
  echo "$output" | grep -qx 'WAY=1'
  [ "$(echo "$output" | grep -c '直す文に無い要件')" -eq 1 ]
  echo "$output" | grep '直す文に無い要件' | grep -q '要件 C'
}

@test "step 5 commands: two delta files are counted as two" {
  write_pages "$DEC_LIGHT"
  write_delta "$DELTA_OK"
  mkdir -p "$BATS_TEST_TMPDIR/work/openspec/changes/archive/2026-10-12-demo-change/specs/other"
  printf '%s\n' "$DELTA_OK" > "$BATS_TEST_TMPDIR/work/openspec/changes/archive/2026-10-12-demo-change/specs/other/spec.md"
  run_light
  [ "$(echo "$output" | sed -n 4p | tr -d ' ')" = "2" ]
}

@test "step 5 commands: latest decision without the line counts zero (falls back to the plain 'yes' row)" {
  # 古いコメントと雑談には通し方の行があるが、最新の仕様化判断には無い
  write_pages '仕様化判断: する\n理由: 設計判断を含む'
  write_delta "$DELTA_OK"
  run_light
  echo "$output" | grep -qx 'WAY=0'
  # 従来の「する」の行は仕様レビューの APPROVE を求める
  table5 | grep '^| `仕様化判断: する`（`通し方: 文言合わせ` の行なし） |' | grep -q '仕様レビュー:` コメントが `APPROVE`'
}

# --- Requirement: W の仕様化経路は openspec CLI だけで進める（design.md D4 の実測） ---

@test "openspec CLI: a change with only a delta spec needs --type change to validate" {
  command -v npx >/dev/null 2>&1 || skip "npx が無い"
  osp="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)/scripts/openspec.sh"
  root="$BATS_TEST_TMPDIR/osp"
  mkdir -p "$root/openspec/specs/demo" "$root/openspec/changes/wording-demo/specs/demo"
  cat > "$root/openspec/specs/demo/spec.md" <<'EOF'
# demo Specification

## Purpose
文言合わせの通し方の実測に使う仮の仕様。

## Requirements

### Requirement: 既定値を持つ
システムは既定値 2 を持たなければならない（MUST）。

#### Scenario: 既定値を読む
- **WHEN** 設定が無い
- **THEN** 既定値 2 が使われる
EOF
  printf 'schema: spec-driven\ncreated: 2026-10-12\n' > "$root/openspec/changes/wording-demo/.openspec.yaml"
  cat > "$root/openspec/changes/wording-demo/specs/demo/spec.md" <<'EOF'
## MODIFIED Requirements

### Requirement: 既定値を持つ
システムは既定値 3 を持たなければならない（MUST）。

#### Scenario: 既定値を読む
- **WHEN** 設定が無い
- **THEN** 既定値 3 が使われる
EOF
  cd "$root"
  run "$osp" validate wording-demo --strict
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'Unknown item'
  run "$osp" validate wording-demo --type change --strict
  [ "$status" -eq 0 ]
}
