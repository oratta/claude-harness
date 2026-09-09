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
#   2. 手渡しの許可条件を自分の言葉で述べた本文が、正本以外に無いこと
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

# ③return の 1 行目の宣言書式と、どちらを選ぶかの義務
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
    "plugins/dev-workflow/references/pr-body-format.md	「引き継ぎ」は PR 本文を読む別セッションの LLM の話で、手渡しの規則ではない" \
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
  ! echo "$output" | grep -qF "${THIS_CHANGE}specs/dev-workflow-execution-strategy/spec.md"
}

# ---------------------------------------------------------------------------
# 2. 手渡しの許可条件を述べた本文が正本以外に無いこと
#
# ホワイトリストは「参照があるか」しか見ないので、参照を書いたうえで条件を言い換えた面は
# 素通りする。正本以外の面が許可条件を絶対文の形で述べていないことを、文単位で固定する
# （検出する形の定義は tests/lib/handoff-scan.py の PERMISSION_SENTENCE）。
# ---------------------------------------------------------------------------

@test "single source: no surface other than the source states the handoff permission condition" {
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode permission-sentences --source "$CRITERIA_REL"
  echo "$output"
  [ "$status" -eq 0 ]
}
