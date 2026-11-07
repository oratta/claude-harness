#!/usr/bin/env bats
# #1584: 本体が通す軽い修正の契約と、文書中の照合コマンドの実測。
setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CRITERIA="$PLUGIN_DIR/skills/develop/references/decision-criteria.md"
  REVIEWER="$PLUGIN_DIR/skills/develop/references/roles/spec-reviewer.md"
  SKILL="$PLUGIN_DIR/skills/develop/SKILL.md"
  GATE="$PLUGIN_DIR/skills/develop/references/roles/gate-runner.md"
  PREPARE="$PLUGIN_DIR/skills/pr-review-gate/stages/prepare.md"
  PASS="$PLUGIN_DIR/skills/pr-review-gate/stages/pass.md"
}
light_section() {
  LC_ALL=C awk '/^### /{f=0} index($0,"### 仕様化しないが軽く通す（軽い通し方）")==1{f=1} f' "$CRITERIA"
}
@test "criteria: six kinds distinguish unchanged behavior from an unambiguous bug fix" {
  light_section | grep -q '既存のテストかチェック'
  light_section | grep -q 'どれか 1 つ'
  for kind in typo lint コメント フォーマット 設定値; do
    light_section | grep "$kind" | grep -q '挙動を変えない'
  done
  light_section | grep 'ワンライナー fix' | grep -q '直し方に選択肢がない'
  light_section | grep 'ワンライナー fix' | grep -q '挙動が変わることを条件外の理由にしない'
}
@test "criteria: main agent preserves the record and gate in seven steps" {
  [ "$(light_section | grep -cE '^[1-7]\. ')" -eq 7 ]
  light_section | grep -q '新しいテストと W の起動'
  light_section | grep -q '記録先・判断の記録・pr-review-gate'
  light_section | grep -q '整理 → 判定 → Draft PR → 判断の記録'
  light_section | grep -q '当てないなら Draft PR を作らず'
  light_section | grep -q 'unmanned.*agent-review:pending'
  light_section | grep -q '迷ったら当てず.*主に聞かない'
}
@test "criteria: fallbacks start a new spec worker and recheck gate prerequisites" {
  light_section | grep -q '途中.*commit.*段: spec'
  light_section | grep -q '原因: 軽い通し方の条件外'
  light_section | grep -q '通常のレビュー.*failed'
  light_section | grep -q '通し方:.*投稿し直さない'
  light_section | grep -q '前提確認と重さ判定'
  grep 'テスト作成は全経路で必須' "$CRITERIA" | grep -q '軽い通し方だけ'
  grep 'テスト作成は全経路で必須' "$CRITERIA" | grep -q 'W が起こされる経路'
}
@test "decision contract: main posts the three exact lines and prepare reads the latest decision" {
  row="$(grep '^| 軽い通し方の行' "$REVIEWER")"
  printf '%s\n' "$row" | grep -qF '^通し方: 軽い$'
  printf '%s\n' "$row" | grep -qF '^種類: (typo|lint|コメント|フォーマット|ワンライナー fix|設定値)$'
  printf '%s\n' "$row" | grep -qF '^確かめ方: .+'
  for phrase in 本体 最新の仕様化判断 前提確認 'R1 は起こされない'; do
    printf '%s\n' "$row" | grep -q "$phrase"
  done
}
@test "loop: only light path permits main edits and bypasses workers" {
  grep 'Edit でコードを書かない' "$SKILL" | grep -q '例外は軽い通し方だけ'
  line="$(grep '^     軽い通し方なら' "$SKILL")"
  printf '%s\n' "$line" | grep -q 'W を起こさず本体が直して G の工程'
  printf '%s\n' "$line" | grep -q 'decision-criteria.md'
  grep '入口 0 の例外' "$SKILL" | grep -q '整理 → 判定 → Draft PR → 判断の記録'
}
@test "loop: light failures dispatch a fresh spec worker before gate prepare" {
  grep '軽い通し方の failed' "$SKILL" | grep -q '段: spec'
  grep '軽い通し方の failed' "$SKILL" | grep -q 'decision-criteria.md'
  # 条件外／通常の failed の詳細は正本に一本化し、SKILL から辿れること。
  light_section | grep '原因: 軽い通し方の条件外' | grep -q 'モデルを上げず'
  light_section | grep '通常のレビュー' | grep -q 'Gate Result.*仕分けコメントの URL'
  grep '^| 前提確認と重さ判定 |' "$GATE" | grep -q 'failed.*次の段: 前提確認と重さ判定'
}
# #1589: passed 後の CI 修正は、最新判断に応じて W の入口を選ぶ。
ci_reentry() {
  light_section | sed -n '/^\*\*CI 見張りの fix からの戻し方\*\*/,/^\*\*守備範囲/p'
}
@test "ci fix: ci-fail and conflict on the light path dispatch a fresh spec worker" {
  section="$(ci_reentry)"
  [ -n "$section" ]
  for state in ci-fail conflict; do
    printf '%s\n' "$section" | grep "$state" | grep -q '同じ分岐'
  done
  light="$(printf '%s\n' "$section" | grep '^- 最新の仕様化判断に')"
  ! printf '%s\n' "$light" | grep -qF '段: implement' || return 1
  for phrase in '最新の仕様化判断' '通し方: 軽い' '同じ worktree' '新しい W' '段: spec' 'PR・記録先' '失敗したチェック・run' '本体は直接直さず' '存在しない W を再開しない'; do
    printf '%s\n' "$light" | grep -qF "$phrase"
  done
}
@test "ci fix: new worker records a normal decision before implementation and always writes tests" {
  section="$(ci_reentry)"
  for phrase in '実装前に同じ記録先' '通し方:` の行の無い仕様化判断' 'する」か「しない」かは W' 'artifact 一式' 'R1 の APPROVE' 'どちらの判断でもテスト' '同じ PR' '以後は通常の通し方' '通し方: 軽い` を投稿し直さない'; do
    printf '%s\n' "$section" | grep -qF "$phrase"
  done
}
@test "ci fix: normal and returned paths resume implement without a new spec decision" {
  section="$(ci_reentry | grep '^- 通常経路の既存 W')"
  for phrase in '通常経路の既存 W' '段: implement' 'コンテキスト上限（サブエージェントの手渡し）' '許可条件' 'fix` だけを理由に' '仕様化判断を投稿し直さない' '通常へ戻った後の再 fix もこの分岐'; do
    printf '%s\n' "$section" | grep -qF "$phrase"
  done
}

@test "ci fix: develop entry points share dispatch rules and preserve the watch continuation" {
  for file in "$SKILL" "$PLUGIN_DIR/references/ci-watch.md"; do
    grep 'fix\|develop では W' "$file" | grep 'decision-criteria.md' | grep -q 'CI 見張りの fix からの戻し方'
  done
  grep 'CI 見張りの fix からの戻し方' "$SKILL" | grep -q '軽いなら同じ worktree の新しい W を `段: spec`.*既存 W は `段: implement`'
  section="$(ci_reentry)"
  for phrase in '同じ PR・同じ状態ファイル' 'wait` → `next' 'ready` 後に前提確認と重さ判定の G を新しく' '開始記録や修正回数はリセットしない'; do
    printf '%s\n' "$section" | grep -qF "$phrase"
  done
  grep 'W が push したら' "$SKILL" | grep -q 'passed を外したまま同じ状態ファイル'
  grep 'ready.*になってから前提確認と重さ判定の G を新しく' "$SKILL"
  watch="$PLUGIN_DIR/references/ci-watch.md"
  for phrase in 'メインセッションが実装者のサブエージェント' 'next --unrelated <チェック名> --after-fix' 'gh pr ready --undo' 'agent-review:pending' '合格するまで `agent-review:passed` を付け直さない'; do
    grep -qF "$phrase" "$watch"
  done
}

@test "ci fix: fresh worker receives push safeguards and watch waits for finish return" {
  light="$(ci_reentry | grep '^- 最新の仕様化判断に')"
  printf '%s\n' "$light" | grep -q '起動指示.*ci-watch.md.*7.*最初の push.*3'
  for file in "$CRITERIA" "$SKILL"; do
    grep -q '仕様化途中の push.*見張りに戻らず.*(3b).*return.*wait` → `next' "$file"
  done
}
@test "ci fix: published and archived specs require safeguards before push and finish before watch" {
  local root="$PLUGIN_DIR/../../openspec" prefix
  for prefix in "$root/specs" "$root/changes/archive/2026-11-07-develop-light-ci-fix-reentry/specs"; do
    spec="$prefix/dev-workflow-develop/spec.md"
    grep -q '起動指示.*ci-watch.md.*7.*最初の push.*3' "$spec"
    grep -q '仕様化途中の push.*見張りに戻らず.*(3b).*return.*wait` → `next' "$spec"
  done
}

@test "startup: skill remains within its unchanged byte budget" {
  budget="$(awk '$1=="skills/develop/SKILL.md"{print $2}' "$PLUGIN_DIR/../../tests/develop-startup-budget.txt")"
  [ "$(wc -c < "$SKILL")" -le "$budget" ]
}

# prepare の手順 1 にあるコードブロックをそのまま実行する。
measure_commands() {
  LC_ALL=C awk '/^[[:space:]]*DEC=/{f=1} f && /^[[:space:]]*```/{exit} f{sub(/^   /, ""); print}' "$PREPARE"
}
measure() {
  local dec="$1" files="$2" cmds
  cmds="$(measure_commands)"
  [ -n "$cmds" ]
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  jq -n --arg dec "$dec" '[[{author_association:"OWNER",body:"仕様化判断: しない\n通し方: 軽い\n種類: typo\n確かめ方: true"},{author_association:"OWNER",body:"雑談\n通し方: 軽い"}],[{author_association:"OWNER",body:$dec}]]' > "$BATS_TEST_TMPDIR/pages.json"
  printf '%s\n' "$files" > "$BATS_TEST_TMPDIR/files.txt"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  *comments*) cat "$BATS_TEST_TMPDIR/pages.json" ;;
  *files*) cat "$BATS_TEST_TMPDIR/files.txt" ;;
  *) exit 99 ;;
esac
GH
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" R=o/r REC=7 N=8 bash -c "$cmds
printf 'LIGHT=%s\n' \"\$LIGHT\""
  [ "$status" -eq 0 ]
}
DEC_FIX=$'仕様化判断: しない\n通し方: 軽い\n種類: ワンライナー fix\n確かめ方: bash check.sh'
@test "prepare: checks after HEAD freeze, records verdict, rejects before reviewers" {
  check="$(grep -n '6\. \*\*軽い通し方' "$PREPARE" | cut -d: -f1)"
  head="$(grep -n '^   HEAD_SHA=' "$PREPARE" | cut -d: -f1)"
  [ -n "$check" ] && [ "$check" -gt "$head" ]
  for phrase in '^軽い通し方の確認: (条件内|条件外)$' '対象 HEAD: <40 桁フル SHA>' '原因: 軽い通し方の条件外' 'agent-review:failed' 'コメントも投稿しない'; do
    grep -qF "$phrase" "$PREPARE"
  done
  grep 'ワンライナー fix は' "$PREPARE" | grep -q '挙動が変わることを条件外の理由にしない'
  grep -q 'gh pr diff' "$PREPARE"
  grep -q '穴を塞ぎ切ることは完了条件にしない' "$PREPARE"
}
@test "prepare commands: indented list block can be extracted and executed" {
  local original="$PREPARE"
  PREPARE="$BATS_TEST_TMPDIR/indented-prepare.md"
  # 元の字下げに関係なく、リスト内のコードを 3 字下げにする。
  LC_ALL=C awk '
    /^[[:space:]]*DEC=/{f=1}
    f && /^[[:space:]]*```/{f=0}
    f {sub(/^   /, ""); $0="   " $0}
    {print}
  ' "$original" > "$PREPARE"
  local cmds
  cmds="$(measure_commands)"
  [[ "$cmds" == DEC=* ]] || return 1
  [[ "$cmds" == *$'\nfi' ]] || return 1
  measure "$DEC_FIX" '1 1 a.sh'
  printf '%s\n' "$output" | grep -qx 'MACHINE_RESULT=条件内'
}
@test "prepare commands: two files exceed the one-liner limit" {
  measure "$DEC_FIX" $'1 1 a.sh\n1 1 b.sh'
  printf '%s\n' "$output" | grep -qx '2 2 2'
  printf '%s\n' "$output" | grep -qx 'LIGHT=1'
}
@test "prepare commands: openspec changes are counted" {
  measure "$DEC_FIX" '1 1 openspec/specs/demo/spec.md'
  [ "$(printf '%s\n' "$output" | sed -n '4p')" = 1 ]
}
@test "prepare commands: missing check is zero" {
  measure $'仕様化判断: しない\n通し方: 軽い\n種類: typo' '1 1 a.md'
  [ "$(printf '%s\n' "$output" | sed -n '3p')" = 0 ]
}
@test "prepare commands: latest decision without light line ignores older decisions and chatter" {
  measure $'仕様化判断: しない\n理由: 通常' '1 1 a.md'
  printf '%s\n' "$output" | grep -qx 'LIGHT=0'
}
@test "prepare commands: one-line bug fix excludes only numeric change records" {
  measure "$DEC_FIX" $'1 1 a.sh\n50 0 plugins/x/changes/1.md\n20 0 changes/1584.md'
  printf '%s\n' "$output" | grep -qx '1 1 1'
  [ "$(printf '%s\n' "$output" | sed -n '4p')" = 0 ]
  measure "$DEC_FIX" $'1 1 a.sh\n1 1 plugins/x/changes/name.md'
  printf '%s\n' "$output" | grep -qx '2 2 2'
}
@test "pass: gate executes recorded checks at PR HEAD and delegates whole suites to CI" {
  section="$(LC_ALL=C awk '/^### 4\./{f=1} /^### 5\./{f=0} f' "$PASS")"
  printf '%s\n' "$section" | grep '軽い通し方' | grep -q '確かめ方:'
  printf '%s\n' "$section" | grep '軽い通し方' | grep -q 'G が PR の HEAD の作業ツリーで'
  printf '%s\n' "$section" | grep '軽い通し方' | grep -q '表の 1 行'
  printf '%s\n' "$section" | grep '軽い通し方' | grep -q '終了コードと出力の要点'
  printf '%s\n' "$section" | grep '軽い通し方' | grep -q '全体のテスト.*CI の結果'
}

@test "prepare commands: NONE cannot replace a trusted decision" {
  measure "$DEC_FIX" '1 1 a.sh'
  jq '.[1] += [{author_association:"NONE",body:"仕様化判断: しない\n理由: untrusted"}]' "$BATS_TEST_TMPDIR/pages.json" > "$BATS_TEST_TMPDIR/untrusted.json"
  cp "$BATS_TEST_TMPDIR/untrusted.json" "$BATS_TEST_TMPDIR/pages.json"
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" R=o/r REC=7 N=8 bash -c "$(measure_commands)
printf 'SELECTED=%s\n' \"\$DEC\""
  [ "$status" -eq 0 ]
  [[ "$output" == *'ワンライナー fix'* ]] || return 1
  [[ "$output" != *untrusted* ]] || return 1
  grep '軽い通し方の PR' "$PASS" | grep -q '手順 1 の 6 と同じ.*絞り込み'
}

@test "criteria: main and fallback workers share the dedicated worktree" {
  light_section | grep -q '直す前に対象専用の worktree'
  light_section | grep -q '戻り経路.*同じ worktree'
  grep -qx -- '- 挙動を変えない設定値の変更' "$CRITERIA"
}
@test "criteria: unmanned ends without starting gate" {
  light_section | grep '^5\.' | grep -q 'unmanned.*agent-review:pending'
  light_section | grep '^7\.' | grep -q 'unmanned.*G を起こさず'
}
@test "fallback: pre-review rejection restarts a first whole review" {
  for file in "$CRITERIA" "$PREPARE" "$GATE"; do
    grep -q '前の Gate Result を.*ゲートの開始' "$file"
    grep -q '周回: 1.*全体レビュー' "$file"
  done
}
@test "pass: nonzero recorded check rejects and restarts spec worker" {
  grep '終了コードが 0 でなければ' "$PASS" | grep -q 'passed を付けず.*failed.*次の段: 前提確認と重さ判定.*段: spec'
}
@test "prepare commands: duplicate kinds return failed" {
  measure "$DEC_FIX"$'\n種類: typo' '1 1 a.sh'
  printf '%s\n' "$output" | grep -qx '軽い通し方の確認: 条件外'
  printf '%s\n' "$output" | grep -qx 'Status: failed'
}
@test "prepare commands: duplicate or empty checks return failed" {
  for extra in '確かめ方: true' '確かめ方: '; do
    measure "$DEC_FIX"$'\n'"$extra" '1 1 a.sh'
    printf '%s\n' "$output" | grep -qx '軽い通し方の確認: 条件外'
    printf '%s\n' "$output" | grep -qx 'Status: failed'
  done
}
@test "prepare commands: two-file one-liner returns failed before review (AC6)" {
  measure "$DEC_FIX" $'1 1 a.sh\n1 1 b.sh'
  printf '%s\n' "$output" | grep -qx '軽い通し方の確認: 条件外'
  printf '%s\n' "$output" | grep -qx 'Status: failed'
  printf '%s\n' "$output" | grep -qx '次の段: 前提確認と重さ判定'
  printf '%s\n' "$output" | grep -qx '原因: 軽い通し方の条件外'
}
@test "prepare commands: valid one-liner passes mechanical checks" {
  measure "$DEC_FIX" '1 1 a.sh'
  printf '%s\n' "$output" | grep -qx 'MACHINE_RESULT=条件内'
  ! printf '%s\n' "$output" | grep -q 'Status: failed' || return 1
}
@test "specs: published and archived requirements keep the repaired contracts" {
  local root="$PLUGIN_DIR/../../openspec" prefix
  for prefix in "$root/specs" "$root/changes/archive/2026-11-07-develop-trivial-light-path/specs"; do
    grep -q '周回: 1.*全体レビュー' "$prefix/dev-workflow-develop/spec.md"
    grep -q '同じ worktree' "$prefix/dev-workflow-develop/spec.md"
    grep -q 'unmanned では G を起こさず' "$prefix/dev-workflow-spec-review/spec.md"
    grep -q '終了コードが 0 でなければ.*passed を付けず.*failed' "$prefix/dev-workflow-pr-review-gate/spec.md"
    grep -q '種類:.*1 行ちょうど' "$prefix/dev-workflow-pr-review-gate/spec.md"
    ! grep -q '1 行以上あること' "$prefix/dev-workflow-pr-review-gate/spec.md" || return 1
  done
}
