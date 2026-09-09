#!/usr/bin/env bats
#
# 手渡し規則が正本 1 箇所にだけあり、他の面は正本への参照だけを持つことの構造検証
#
# 2026-09 の事故（バックグラウンドコマンド待ちで idle になっていた前任 W を「工程を終えた」と
# 誤認して手渡し、同じ worktree に新旧 2 人の W が並んだ）を受けて、判定材料を本体側の内容
# 判断から W / G 側の return 1 行目宣言に移した。その規則を 10 前後の面に言い換えて配ったことが
# 3 周続けての書き換え漏れを生んだので、本文を
# `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」
# （以下 正本）1 箇所に畳み、他の面は参照だけを書く設計に変えた。
#
# このファイルが担う検査は 3 つ:
#   1. 正本が①〜④を実際に規定していること（`criteria:` 系）。spec は①〜④の答えを再掲しないので、
#      正本の答えが逆に書き換わったときに落ちるのはこのテストだけになる
#   2. 正本が規定する①〜④のどれかを自分の言葉で述べた本文が、正本以外に無いこと
#   3. トリガー語に掛かった面が、正本への参照を持つこと（ホワイトリスト）
#
# spec: dev-workflow-execution-strategy, dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  CRITERIA_REL="plugins/dev-workflow/skills/develop/references/decision-criteria.md"
}

# 「## <見出し>」から次の「## 」までを切り出す
section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }
# decision-criteria.md のコンテキスト上限節（＝正本）
cap_sec() { section "$CRITERIA" 'コンテキスト上限（サブエージェントの手渡し）'; }
role_sec() { section "$SKILL" '本体の役割'; }

# ---------------------------------------------------------------------------
# 1. 正本が①〜④を規定していることの検査
#
# spec（dev-workflow-execution-strategy）は①〜④の答えを再掲しない（MUST NOT）ので、
# 正本が「上限超過なら即座に手渡してよい」に書き換わっても `openspec validate` は通る。
# 規範の中身を担保するのはこの節の検査だけなので、ホワイトリスト化に伴って落としてはならない。
# `grep` の引数として正本の断片を引用することは、spec が禁じる「言い換え」に当たらない
# （テストは読ませる面ではなく、正本の本文が壊れていないことを機械的に検査する面であるため）。
# ---------------------------------------------------------------------------

# ①送ってよい SendMessage と送ってはならない SendMessage
@test "criteria(1): exit-2 non-resume is unconditional and scoped to continuation SendMessage only" {
  cap_sec | grep -qF '再開の禁止は無条件'
  cap_sec | grep -qF '作業の継続を指示する SendMessage'
  cap_sec | grep -qF '停止を指示する SendMessage は禁止の対象外'
}

# ②手渡しを行ってよい条件
@test "criteria(2): handoff is permitted only when the predecessor declared process-complete" {
  cap_sec | grep -qF '工程完了: <工程名>'
  cap_sec | grep -qF '手渡しの許可'
  cap_sec | grep -qE '工程完了.*とき.*だけ|とき.*だけ.*工程完了'
}

@test "criteria(2): the cap alone is not a reason to swap the predecessor out right now" {
  cap_sec | grep -qF '「今すぐ交代させる」条件ではない'
}

# ③return の 1 行目の宣言（正本の③が規定する）
@test "criteria(3): process-suspended covers waiting on a self-started background command" {
  cap_sec | grep -qF '工程中断: <理由>'
  cap_sec | grep -qF 'バックグラウンドコマンド'
}

@test "criteria(3): appending an achievement list does not excuse declaring process-complete while the command is unfinished" {
  cap_sec | grep -qF '成果一覧を書いていても'
  cap_sec | grep -qF '完了していなければ'
  cap_sec | grep -qF '宣言してはならない'
}

@test "criteria(3): idle while waiting is distinguished from a completed return" {
  cap_sec | grep -qF 'idle'
  cap_sec | grep -qF '工程の終わりではない'
}

# ④前任が動作中のまま交代させる手順と、その待ち方
@test "criteria(4): predecessor still running requires a stop instruction before handoff" {
  cap_sec | grep -qF '停止を指示'
  cap_sec | grep -qF '停止確認'
  cap_sec | grep -qF '破壊的 git 操作'
}

@test "criteria(4): waiting for a stop confirmation is non-blocking, and unmanned ends the cycle instead of blocking" {
  cap_sec | grep -qF 'ブロックせず'
  cap_sec | grep -qE 'unmanned.*サイクルを終える|サイクルを終える.*unmanned'
}

# 書式リテラル（別エピックの子 issue がこの 2 つを前提にしている。spec が固定している）
@test "criteria: the two declaration literals are fixed and use the same format family as the spec decision" {
  cap_sec | grep -qF '工程完了: <工程名>'
  cap_sec | grep -qF '工程中断: <理由>'
  cap_sec | grep -qF '仕様化判断: する|しない'
}

# 同一 worktree の同一役割は 1 人（dev-workflow-develop の別要件）
@test "skill: same-worktree same-role concurrency is capped at one" {
  role_sec | grep -qE '1 人|同時に動く同一役割'
  role_sec | grep -qF '別々の worktree'
}

# ---------------------------------------------------------------------------
# 検査対象の機械的な列挙
#
# 面の一覧を手で列挙すると「まだ直していない面が検査対象から外れる」形になり、取り残しを
# 見逃す（PR #253 で 3 周続けて起きた）。`git ls-files` から機械的に拾い、除外は spec が
# 定める 3 種だけとする:
#   ①歴史記録（CHANGELOG.md 全体・この change 以外の過去 change の archive・_longruns/）
#   ②change の proposal.md と tasks.md
#   ③.claude-plugin/plugin.json（正本とのズレを許容した配布メタデータ）
# ---------------------------------------------------------------------------

THIS_CHANGE='openspec/changes/archive/2026-09-08-handoff-requires-completed-return/'

# 語彙 B だけで発火する面のうち、トリガー語を手渡しと無関係の文脈で使っているもの。
# spec の要求により 1 面 1 行の理由コメントを必須とし、語彙 A で発火する面は載せられない
# （載せられるようにすると、実装者が検査範囲を暗黙に狭める経路が復活する）。
# 書式: <リポジトリ相対パス><TAB><理由>
vocab_b_exemptions() {
  printf '%s\n' \
    "openspec/specs/dev-workflow-escalation-tripwires/spec.md	「乗り換え」「成果の引き継ぎ」はトリップワイヤー発火時のモデル / Workflow 乗り換えの話で、W / G の手渡しではない" \
    "openspec/specs/dev-workflow-subagent-waiting/spec.md	「引き継がれない」はシェル変数が Bash 呼び出しをまたがない話で、エージェントの手渡しではない" \
    "plugins/dev-workflow/references/pr-body-format.md	「引き継ぎ」は PR 本文を読む別セッションの LLM の話で、手渡しの規則ではない" \
    "plugins/dev-workflow/references/subagent-waiting.md	「引き継がれない」はシェル変数が Bash 呼び出しをまたがない話で、エージェントの手渡しではない" \
    "plugins/dev-workflow/tests/pr-body-format.bats	「引き継ぐ」は spec 名の一部（旧 loops-pr-body-format の reference 要件を引き継ぐ）" \
    "plugins/dev-workflow/scripts/agent-model-guard.sh	「世代交代」はモデル ID の世代交代で、エージェントの交代ではない" \
    "plugins/dev-workflow/scripts/usage-probe.sh	「引き継ぐ」は fail-open で前回の snapshot 値を保持する話"
}

# 走査本体。マルチバイトの否定文字クラスは locale 次第で壊れて偽陰性になるので python3 で走らせる。
run_scan() {
  python3 "${BATS_TEST_DIRNAME}/../tests/lib/handoff-scan.py" "$@"
}

@test "whitelist: every surface caught by a trigger term carries a reference to the single source" {
  local -a exemptions=()
  while IFS= read -r line; do exemptions+=("$line"); done < <(vocab_b_exemptions)
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode offenders "${exemptions[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "whitelist: no exemption is stale (each still matches a general-vocabulary trigger)" {
  local -a exemptions=()
  while IFS= read -r line; do exemptions+=("$line"); done < <(vocab_b_exemptions)
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode stale "${exemptions[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "whitelist: no handoff-specific surface hides behind an exemption" {
  local -a exemptions=()
  while IFS= read -r line; do exemptions+=("$line"); done < <(vocab_b_exemptions)
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode vocab-a-exempt "${exemptions[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "whitelist: every exemption carries a one-line reason" {
  while IFS= read -r line; do
    [[ "$line" == *$'\t'* ]] || { echo "理由コメントが無い除外行: $line"; return 1; }
    reason="${line#*$'\t'}"
    [ -n "$reason" ] || { echo "理由が空の除外行: $line"; return 1; }
  done < <(vocab_b_exemptions)
}

@test "whitelist: the tests directory itself is inside the inspected set" {
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode list-inspected
  echo "$output"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF 'plugins/dev-workflow/tests/handoff-declaration.bats'
  echo "$output" | grep -qF 'plugins/dev-workflow/tests/subagent-context.bats'
}

@test "whitelist: the three exclusions are the only ones (history, change proposal/tasks, plugin.json)" {
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode list-excluded
  echo "$output"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF 'plugins/dev-workflow/CHANGELOG.md'
  echo "$output" | grep -qF 'plugins/dev-workflow/.claude-plugin/plugin.json'
  # この change の archive delta は歴史記録ではないので検査対象に残る
  if echo "$output" | grep -qF "${THIS_CHANGE}specs/dev-workflow-execution-strategy/spec.md"; then
    echo "この change の archive delta が検査対象から外れている"; return 1
  fi
}

# spec が歴史記録として除外したのは dev-workflow の CHANGELOG だけ。`*/CHANGELOG.md` で
# 引っ掛けると他プラグインの CHANGELOG まで暗黙に検査から外れる（PR #253 のゲート指摘）。
@test "whitelist: only the dev-workflow changelog is excluded as a history record" {
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode list-excluded
  echo "$output"
  [ "$status" -eq 0 ]
  while IFS= read -r path; do
    case "$path" in
      */CHANGELOG.md|CHANGELOG.md)
        [ "$path" = 'plugins/dev-workflow/CHANGELOG.md' ] || {
          echo "spec が定めていない CHANGELOG.md を除外している: $path"; return 1; }
        ;;
    esac
  done <<< "$output"
}

# ---------------------------------------------------------------------------
# 2. 正本が規定する①〜④を述べた本文が正本以外に無いこと
#
# ホワイトリストは「そのファイルが参照を持つか」しか見ないので、参照を書いたうえで規則を
# 言い換えた面は素通りする。判定がファイル単位なのは spec の意図（箇所ごとに参照を書かせると
# 再掲の圧力が戻る）なので、再掲そのものはこの文単位の走査が受け持つ。
#
# ①〜④のうち一部しか見ていないと、同じ欠陥が別の規則で再発する（許可条件（②）だけを見ていた
# ため、SKILL.md の失敗フローに残った再開の禁止（①）の再掲を PR #253 のゲートまで見逃した）。
# 検出する形の定義は tests/lib/handoff-scan.py の RESTATEMENT_SENTENCES で、語彙は spec が列挙する。
#
# この走査は spec が列挙した言い回しに対する検査であって、任意の言い換えを検出するものではない。
# 本文が 1 箇所にあることの保証は上のホワイトリストとレビューが担い、この走査は補助の網である。
# ---------------------------------------------------------------------------

# ①〜④の答えを述べていないのに走査の語彙に掛かる文。参照への書き換えでは解消できないので、
# spec の要求により〈面のパス・その文に現れる断片・理由コメント 1 行〉の 3 つ組で文単位に外す
# （面単位で外すと、その面に規則を書き足しても検出されない穴になる）。
# 書式: <リポジトリ相対パス><TAB><断片><TAB><理由>
restatement_exemptions() {
  printf '%s\n' \
    "openspec/specs/dev-workflow-execution-strategy/spec.md	節にだけ置かなければならない	①〜④の答えではなく、正本の置き場所を定めるこの要件本文そのもの（話題を名詞句で列挙し、正本にだけ置くと述べている文）" \
    "openspec/changes/archive/2026-09-08-handoff-requires-completed-return/specs/dev-workflow-execution-strategy/spec.md	節にだけ置かなければならない	上と同じ要件本文の archive delta 側（MODIFIED は要件本文を全文再掲する運用のため同じ文が 2 箇所に出る）"
}

@test "single source: no surface other than the source states any of the four rules" {
  local -a exemptions=()
  while IFS= read -r line; do exemptions+=("$line"); done < <(restatement_exemptions)
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode restatement-sentences --source "$CRITERIA_REL" "${exemptions[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "single source: no restatement exemption is stale (each fragment still trips the scan)" {
  local -a exemptions=()
  while IFS= read -r line; do exemptions+=("$line"); done < <(restatement_exemptions)
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode restatement-stale --source "$CRITERIA_REL" "${exemptions[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "single source: every restatement exemption carries a fragment and a one-line reason" {
  while IFS= read -r line; do
    local path fragment reason
    path="${line%%$'\t'*}"
    fragment="${line#*$'\t'}"; fragment="${fragment%%$'\t'*}"
    reason="${line##*$'\t'}"
    [ -n "$path" ] && [ -n "$fragment" ] && [ -n "$reason" ] || {
      echo "断片か理由が無い除外行: $line"; return 1; }
    [ "$fragment" != "$path" ] && [ "$reason" != "$fragment" ] || {
      echo "3 つ組になっていない除外行: $line"; return 1; }
  done < <(restatement_exemptions)
}

# 除外は文単位。同じ面の別の文に規則を書けば、除外表があっても検出される
# （面単位で外せると、除外表が「その面には何でも書ける」逃げ道になる）。
@test "single source: a restatement exemption only silences the sentence carrying its fragment" {
  local sandbox="${BATS_TEST_TMPDIR}/exempt"
  mkdir -p "${sandbox}/openspec/specs"
  {
    printf '%s\n' 'レート上限を超過したら、リトライを継続しない。'  # handoff-scan: fixture
    printf '%s\n' '上限超（exit 2）を検知したら、前任に作業継続の SendMessage を送らない。'  # handoff-scan: fixture
  } > "${sandbox}/openspec/specs/sample.md"
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode restatement-sentences --source "$CRITERIA_REL" \
    "openspec/specs/sample.md	リトライを継続しない	手渡しではなくレート上限の話"
  echo "$output"
  [ "$status" -eq 1 ]
  if echo "$output" | grep -qF 'sample.md:1'; then
    echo "除外表に載せた文が報告された"; return 1
  fi
  echo "$output" | grep -qF 'sample.md:2'
}

# 走査に掛からなくなった除外行は落とす（stale な除外を残さない）
@test "single source: a restatement exemption whose fragment no longer trips is reported as stale" {
  local sandbox="${BATS_TEST_TMPDIR}/exempt-stale"
  mkdir -p "${sandbox}/openspec/specs"
  printf '%s\n' 'この面は手渡し規則について正本を参照するだけである。' > "${sandbox}/openspec/specs/sample.md"
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode restatement-stale --source "$CRITERIA_REL" \
    "openspec/specs/sample.md	リトライを継続しない	手渡しではなくレート上限の話"
  echo "$output"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF 'リトライを継続しない'
}

# 上の検査が緑なのは「再掲が無いから」であって「何も見ていないから」ではないことを固定する。
# 実際に、注入文のガード検査が対象を取り違えて緑のまま素通りしていた例がある（PR #253）。
#
# ①〜④のサンプルを 1 回のスキャンにまとめて投入し「4 つの規則名が出力に全部含まれるか」だけを
# 見ると、②のサンプルが②と③の両方に掛かるといった取り違えを検出できない（PR #253 のゲート指摘）。
# 1 規則につき 1 回スキャンし、そのサンプルが **その規則だけ** で報告されることを確かめる。
# サンプルは各規則 2 本ずつ: 正本の旧版から写した文と、正本の語をひとつも使わない言い換え
# （後者が無いと、実装が正本の語をそのまま照合しているだけでも緑になる）。
# 末尾の 2 本は、正本への参照を同じ文に含む再掲。参照を含む文を検査から外していた頃は
# どちらも無検出で、うち 1 本は PR #253 修正前の SKILL.md にあった②の再掲そのものの形
# （文末に「（正本は …）」を添えた文）である。
# サンプルはこのファイル自身ではなく使い捨てのリポジトリに置く（この bats も走査対象の面であるため。
# 行末の印で走査から外している ＝ 印の無い行に規則を書けばこのファイルでも検出される）。
#
# 書式: <規則名><TAB><サンプル文>
restatement_samples() {
  printf '%s\n' \
    "①再開の禁止	上限超（exit 2）を検知したら、前任の状態にかかわらず作業継続の SendMessage を送らない（再開しない）。 handoff-scan: fixture" \
    "①再開の禁止	\`DEV_WORKFLOW_CONTEXT_CAP\` を超えたら、前任に続きを依頼してはならない。 handoff-scan: fixture" \
    "②手渡しの許可条件	手渡しを行ってよいのは、前任が工程完了を宣言したときだけである。 handoff-scan: fixture" \
    "②手渡しの許可条件	後任を spawn してよいのは、前任が工程の終わりを宣言した場合のみである。 handoff-scan: fixture" \
    "③宣言の書式と選び方	return の 1 行目は \`工程完了: <工程名>\` か \`工程中断: <理由>\` に完全一致させること。 handoff-scan: fixture" \
    "③宣言の書式と選び方	return の先頭行は、決められた 2 つの書式のどちらかにすること。 handoff-scan: fixture" \
    "④停止指示と停止確認	本体は先に前任へ停止を指示し、停止確認を受け取ってから手渡し先を spawn する。 handoff-scan: fixture" \
    "④停止指示と停止確認	前任がまだ動いているときは、止めるよう伝えて、その報告を受け取ってから新しい実行役を立てる。 handoff-scan: fixture" \
    "①再開の禁止	正本のとおり、\`DEV_WORKFLOW_CONTEXT_CAP\` を超えたら前任に続きを依頼してはならない。 handoff-scan: fixture" \
    "④停止指示と停止確認	本体は先に前任へ停止を指示し、停止確認を受け取ってから手渡し先を spawn する（正本は \`references/decision-criteria.md\`）。 handoff-scan: fixture"
}

ALL_RULES='①再開の禁止 ②手渡しの許可条件 ③宣言の書式と選び方 ④停止指示と停止確認'

@test "single source: each rule is detected on its own, without being confused for another rule" {
  local i=0 rule sample sandbox other
  while IFS=$'\t' read -r rule sample; do
    i=$((i + 1))
    sandbox="${BATS_TEST_TMPDIR}/rule-${i}"
    mkdir -p "$sandbox"
    printf '%s\n' "$sample" > "${sandbox}/restated.md"
    git -C "$sandbox" init -q
    git -C "$sandbox" add -A
    run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode restatement-sentences --source "$CRITERIA_REL"
    echo "サンプル（$rule）: $sample"
    echo "$output"
    [ "$status" -eq 1 ] || { echo "このサンプルが検出されなかった"; return 1; }
    echo "$output" | grep -qF "$rule" || { echo "$rule として報告されなかった"; return 1; }
    for other in $ALL_RULES; do
      if [ "$other" != "$rule" ]; then
        if echo "$output" | grep -qF "$other"; then
          echo "取り違え: $rule のサンプルが $other としても報告された"
          return 1
        fi
      fi
    done
  done < <(restatement_samples)
  [ "$i" -eq 10 ] || { echo "サンプル数が想定と違う: $i"; return 1; }
}

# 検出器の 2 ファイル（この bats と handoff-scan.py）はファイル単位では外れない。
# 印を持たない行に規則を書けば検出される（ファイル全体を外すと、この 2 ファイルが
# 何でも書ける穴になる。PR #253 のゲート指摘）。
@test "single source: the detector files are exempt line by line, not as whole files" {
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode list-inspected
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF 'plugins/dev-workflow/tests/lib/handoff-scan.py'
  echo "$output" | grep -qF 'plugins/dev-workflow/tests/handoff-declaration.bats'

  # 同じ①の再掲を 2 行書き、印のある 1 行目は外れ、印の無い 2 行目は検出されることを確かめる
  local sandbox="${BATS_TEST_TMPDIR}/detector"
  mkdir -p "${sandbox}/plugins/dev-workflow/tests"
  {
    printf '%s\n' '上限超（exit 2）を検知したら、前任に作業継続の SendMessage を送らない。 handoff-scan: fixture'
    printf '%s\n' '上限超（exit 2）を検知したら、前任に作業継続の SendMessage を送らない。'  # handoff-scan: fixture
  } > "${sandbox}/plugins/dev-workflow/tests/handoff-declaration.bats"
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode restatement-sentences --source "$CRITERIA_REL"
  echo "$output"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF 'handoff-declaration.bats:2'
  if echo "$output" | grep -qF 'handoff-declaration.bats:1'; then
    echo "印を持つ行が検出された"; return 1
  fi
}

# 書式リテラルは spec が固定していて再掲に当たらないので、引用しただけの面は落とさない
# （落とすと「リテラルを書くな」という、spec と食い違う圧力が掛かる）。
@test "single source: quoting the two fixed declaration literals alone is not a restatement" {
  local sandbox="${BATS_TEST_TMPDIR}/literals"
  mkdir -p "$sandbox"
  cat > "${sandbox}/quote.md" <<'SAMPLE'
W / G の return の 1 行目の書式リテラルは `工程完了: <工程名>` と `工程中断: <理由>` の 2 つである（規則の本文は正本にある）。
SAMPLE
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode restatement-sentences --source "$CRITERIA_REL"
  echo "$output"
  [ "$status" -eq 0 ]
}
