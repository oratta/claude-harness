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
  SPEC_REL='openspec/specs/dev-workflow-execution-strategy/spec.md'
  # 走査の語彙は spec が列挙する。テスト内に写しを持たず、live spec の一覧から読み取る
  # （spec の MUST。写しを持つと、spec を残したまま実装とテストの両方から同じ語を消しても
  #  全テストが緑になる。実測: 36/36 緑だった。PR #253 のレビュー B4）。
  # 出力は 1 行 3 列: <規則番号＋グループ名> <TAB> <語> <TAB> <照合用の正規表現>。
  VOCAB_TSV="${BATS_TEST_TMPDIR}/spec-vocab.tsv"
  python3 - "${ROOT}/${SPEC_REL}" > "$VOCAB_TSV" <<'PY'
import re, sys

LABELS = ('状況', '指示', '行為', '状態', '話題', '文脈', '停止', '確認', '述語')
META = '.[]{}()*+?^$|\\'


def to_regex(term):
    out = []
    for ch in term:
        if ch == '…':
            out.append('.{0,6}')
        elif ch in META:
            out.append('\\' + ch)
        else:
            out.append(ch)
    return ''.join(out)


rule = None
for line in open(sys.argv[1], encoding='utf-8'):
    head = re.match(r'^- \*\*([\u2460-\u2463])', line)
    if head:
        rule = head.group(1)
        continue
    item = re.match(r'^  - ([^（(:]+)[（(:]', line)
    if rule is None:
        continue
    if not item:
        rule = None          # 一覧が途切れたら読み取りを閉じる
        continue
    label = item.group(1).strip()
    if label not in LABELS:
        continue
    body = line.split(':', 1)[1] if ':' in line else ''
    for term in re.findall(r'`([^`]+)`', body):
        print('%s%s\t%s\t%s' % (rule, label, term, to_regex(term)))
PY
}

# 「## <見出し>」から次の見出し（`## ` または `### `）までを切り出す。
# `## ` だけで止めると、節のあとに続く `### ` 小節まで巻き込む（正本の節では残量モードの 2 小節が
# 入り、正本の本文がその小節へ移動しても `criteria:` 系が緑のままになる。PR #253 のレビュー指摘）。
section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^#{2,3} /{f=0} f' "$1"; }
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

# ③どちらの書式にも当てはまらない return の扱い（この書式を知らない W / G は展開直後に必ず現れる）
@test "criteria(3): a return matching neither literal is handled like the suspended declaration" {
  cap_sec | grep -qF 'どちらの書式にも'
  cap_sec | grep -qE '一致しない.*工程中断|工程中断.*一致しない'
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

# ④の待ちが①②と矛盾しないこと（前任が先に工程完了を返したら通常の手渡しに戻る）
@test "criteria(4): a process-complete return arriving first falls back to the ordinary handoff" {
  cap_sec | grep -qF '停止の手順は要らなくなり'
  cap_sec | grep -qF '通常の手渡しとして扱う'
}

# 書式リテラル（別エピックの子 issue がこの 2 つを前提にしている。spec が固定している）
@test "criteria: the two declaration literals are fixed and use the same format family as the spec decision" {
  cap_sec | grep -qF '工程完了: <工程名>'
  cap_sec | grep -qF '工程中断: <理由>'
  cap_sec | grep -qF '仕様化判断: する|しない'
}

# 節の切り出しが次の見出しで止まること。止まらないと、正本の本文が後続の小節へ移動しても
# 上の `criteria:` 系が緑のまま通る（PR #253 のレビュー指摘）。
@test "criteria: the source section stops at the next heading, not at the next level-2 heading" {
  cap_sec | grep -qF 'コンテキスト上限（サブエージェントの手渡し）'
  local leaked
  for leaked in 'の自動導出（usage snapshot 契約）' 'モード不変ルール'; do
    if cap_sec | grep -qF "$leaked"; then
      echo "正本の節に後続の小節が混ざっている: $leaked"; return 1
    fi
  done
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

# spec が名指しした参照面と正本。`excluded()` を広げれば任意の面を検査から外せて全テストが緑のまま
# 通るので（実測: この 7 面 ＋ 2 つの live spec を `excluded()` に足しても 25/25 緑だった。
# PR #253 のレビュー指摘）、この一覧が現に検査対象に入っていることを固定する。
# これは「検査する面の一覧」ではなく（面の列挙は `git ls-files` からの機械的な列挙が正）、
# 除外が spec の定める 3 種を超えて広がっていないことの下限チェックである。
reference_surfaces() {
  printf '%s\n' \
    'plugins/dev-workflow/README.md' \
    'plugins/dev-workflow/skills/develop/SKILL.md' \
    'plugins/dev-workflow/skills/develop/references/roles/worker.md' \
    'plugins/dev-workflow/skills/develop/references/roles/gate-runner.md' \
    'plugins/dev-workflow/templates/escalation-tripwires.md' \
    'plugins/dev-workflow/scripts/session-tripwires.sh' \
    'plugins/dev-workflow/scripts/subagent-context.sh' \
    'openspec/specs/dev-workflow-execution-strategy/spec.md' \
    'openspec/specs/dev-workflow-develop/spec.md'
}

@test "whitelist: every surface the spec names is inspected (widening the exclusions is caught)" {
  run run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode list-inspected
  [ "$status" -eq 0 ]
  local path
  while IFS= read -r path; do
    echo "$output" | grep -qxF "$path" || {
      echo "spec が名指しした面が検査対象から外れている: $path"; return 1; }
  done < <(reference_surfaces)
  echo "$output" | grep -qxF "$CRITERIA_REL" || {
    echo "正本が検査対象から外れている: $CRITERIA_REL"; return 1; }
}

# 参照が正本に辿り着けること。`has_reference()` は文字列を含むかしか見ないので、パスが壊れていても
# 参照として合格する。参照だけになった面はポインタが壊れると機構ごと失効する（事故の直接原因
# 「規則を知らないまま即興する」に戻る）ので、書かれたパスが実在することを別に検査する。
# 解決の基準は、リポジトリルート・その面自身のディレクトリ・プラグインルートの 3 つ
# （`${CLAUDE_PLUGIN_ROOT}` はプラグインルートに置き換えてから見る）。
resolves_reference_path() { # $1=面のリポジトリ相対パス $2=書かれたパス
  local written="${2//\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_DIR}" base
  written="${written//\$\{PLUGIN_DIR\}/$PLUGIN_DIR}"
  case "$written" in
    /*) [ -f "$written" ] && return 0; return 1 ;;
  esac
  # 4 番目は正本が置かれたスキルのディレクトリ（スキルの文書は自分のスキルルートからの相対で書く）
  for base in "$ROOT" "$(dirname "${ROOT}/$1")" "$PLUGIN_DIR" "$(dirname "${ROOT}/${CRITERIA_REL}")/.."; do
    [ -f "${base}/${written}" ] && return 0
  done
  return 1
}

# 対象は名指しした 9 面ではなく、トリガー語で発火して参照を持つ面すべて（spec の MUST）。ホワイトリストはトリガー語に
# 掛かった任意の面に参照 1 行を求めるので、名指しの面だけを見ると、新しく参照を足した面の
# ポインタが壊れても素通りする（PR #253 のレビュー SHOULD_FIX 1）。
@test "whitelist: every path written toward the source resolves to a real file" {
  local path written inspected checked=0
  inspected="$(run_scan --root "$ROOT" --this-change "$THIS_CHANGE" --mode list-referrers)"
  [ -n "$inspected" ] || { echo "参照を持つ面が空"; return 1; }
  while IFS= read -r path; do
    [ -f "${ROOT}/${path}" ] || continue
    while IFS= read -r written; do
      [ -n "$written" ] || continue
      case "$written" in */*) ;; *) continue ;; esac
      checked=$((checked + 1))
      resolves_reference_path "$path" "$written" || {
        echo "正本へのパスが解決しない: ${path} — ${written}"; return 1; }
    done < <(grep -oa '[A-Za-z0-9_${}/.-]*decision-criteria\.md' "${ROOT}/${path}" | sort -u)
  done <<< "$inspected"
  # 名指しの 9 面と正本が現にパスを書いているので、これを下回るなら走査が空回りしている
  [ "$checked" -ge 9 ] || { echo "正本へのパスを検査した件数が少なすぎる: $checked"; return 1; }
  # 名指しの 9 面より広い集合を見ていること（狭まったら「名指しだけ」に戻っている）
  local surfaces
  surfaces="$(printf '%s\n' "$inspected" | grep -c .)"
  [ "$surfaces" -gt 10 ] || { echo "参照を持つ面が名指しの範囲に狭まっている: $surfaces"; return 1; }
}

# ---------------------------------------------------------------------------
# ホワイトリスト走査の負のコントロール
#
# 実リポで 0 件を期待するテストしか無いと、「緑＝違反が無い」のか「緑＝何も見ていない」のかを
# 区別できない（実測: `has_reference()` を `return True` に、`VOCAB_A` を絶対マッチしない正規表現に
# 変えても 25/25 緑だった。PR #253 のレビュー指摘）。使い捨てのリポジトリに違反を置いて、
# 走査が実際に報告することを固定する。
# ---------------------------------------------------------------------------

@test "whitelist: offenders reports a surface that carries a trigger term without a reference" {
  local sandbox="${BATS_TEST_TMPDIR}/wl-offenders"
  mkdir -p "${sandbox}/docs" "${sandbox}/plugins/dev-workflow"
  printf '%s\n' 'この面は DEV_WORKFLOW_CONTEXT_CAP に触れるが、どこにも正本を指していない。' \
    > "${sandbox}/docs/no-ref.md"
  printf '%s\n' '手渡しの規則は decision-criteria.md が正本。' > "${sandbox}/docs/with-ref.md"
  printf '%s\n' '成果は次の担当に引き継ぐ。' > "${sandbox}/plugins/dev-workflow/vocab-b.md"
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A

  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode offenders
  echo "$output"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF '[語彙A] 正本への参照が無い: docs/no-ref.md'
  echo "$output" | grep -qF '[語彙B] 正本への参照も除外表の登録も無い: plugins/dev-workflow/vocab-b.md'
  if echo "$output" | grep -qF 'with-ref.md'; then
    echo "正本への参照を持つ面が報告された"; return 1
  fi

  # 語彙 B の面は除外表で消える（語彙 A の面は消えない）
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode offenders \
    "plugins/dev-workflow/vocab-b.md	手渡しではなく担当替えの話"
  echo "$output"
  [ "$status" -eq 1 ]
  if echo "$output" | grep -qF 'vocab-b.md'; then
    echo "除外表に載せた語彙 B の面が報告された"; return 1
  fi
  echo "$output" | grep -qF 'docs/no-ref.md'
}

@test "whitelist: an exemption for a surface that no longer trips the general vocabulary is stale" {
  local sandbox="${BATS_TEST_TMPDIR}/wl-stale"
  mkdir -p "${sandbox}/plugins/dev-workflow"
  printf '%s\n' 'この面はトリガー語をひとつも含まない。' > "${sandbox}/plugins/dev-workflow/clean.md"
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode stale \
    "plugins/dev-workflow/clean.md	かつては引き継ぎの話をしていた"
  echo "$output"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF 'stale'
  echo "$output" | grep -qF 'plugins/dev-workflow/clean.md'
}

@test "whitelist: a surface firing on handoff-specific vocabulary cannot be put on the exemption list" {
  local sandbox="${BATS_TEST_TMPDIR}/wl-vocab-a"
  mkdir -p "${sandbox}/docs"
  printf '%s\n' 'この面は手渡しに触れる。' > "${sandbox}/docs/a.md"
  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode vocab-a-exempt \
    "docs/a.md	載せてはならない面"
  echo "$output"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF 'docs/a.md'
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
# 「正本の語をひとつも使わない言い換え」は spec の MUST。実測で 4 本とも正本の語（`前任` /
# `工程の終わり` / `DEV_WORKFLOW_CONTEXT_CAP` など）を含んでいたため、走査の語彙からその語を
# 消してもサンプルが別の語で拾われ、全テストが緑のまま通っていた（PR #253 のレビュー指摘）。
# 言い換えには、正本に現れない語彙（`over_cap` / `後任` / `完了宣言` / `冒頭行` / `中止` など）を使う。
# 前処理（`【…】` の除去・書式リテラルの除去）が効いていないと検出できない形も 1 本ずつ持つ
# （どちらも、無効化しても全テストが緑だった）。
#
# 書式: <規則名><TAB><サンプル文><TAB><種別: 正本の語 / 言い換え / 前処理>
restatement_samples() {
  printf '%s\n' \
    "①再開の禁止	上限超（exit 2）を検知したら、前任の状態にかかわらず作業継続の SendMessage を送らない（再開しない）。 handoff-scan: fixture	正本の語" \
    "①再開の禁止	over_cap が立った担当には、作業を続けさせるのを避ける。 handoff-scan: fixture	言い換え" \
    "①再開の禁止	上限超（exit 2）を検知したら、前任に作業継続の SendMessage を送らない【この注記は走査の前に取り除かれる】。 handoff-scan: fixture	前処理" \
    "②手渡しの許可条件	手渡しを行ってよいのは、前任が工程完了を宣言したときだけである。 handoff-scan: fixture	正本の語" \
    "②手渡しの許可条件	後任を立てられるのは、完了宣言があった場合のみである。 handoff-scan: fixture	言い換え" \
    "③宣言の書式と選び方	return の 1 行目は \`工程完了: <工程名>\` か \`工程中断: <理由>\` に完全一致させること。 handoff-scan: fixture	正本の語" \
    "③宣言の書式と選び方	後任へ渡す文書の冒頭行は、定められた型に一致させること。 handoff-scan: fixture	言い換え" \
    "③宣言の書式と選び方	return の 1 行目はどちらかにする（\`工程完了: <工程名>\` / \`工程中断: <理由>\`）。 handoff-scan: fixture	前処理" \
    "③宣言の書式と選び方	W は return の先頭で \`工程完了: <工程名>\` か \`工程中断: <理由>\` のどちらかを宣言する。 handoff-scan: fixture	前処理" \
    "④停止指示と停止確認	本体は先に前任へ停止を指示し、停止確認を受け取ってから手渡し先を spawn する。 handoff-scan: fixture	正本の語" \
    "④停止指示と停止確認	動いている担当には中止を伝え、その返事を得てから後任を立てる。 handoff-scan: fixture	言い換え" \
    "①再開の禁止	正本のとおり、\`DEV_WORKFLOW_CONTEXT_CAP\` を超えたら前任に続きを依頼してはならない。 handoff-scan: fixture	正本の語" \
    "④停止指示と停止確認	本体は先に前任へ停止を指示し、停止確認を受け取ってから手渡し先を spawn する（正本は \`skills/develop/references/decision-criteria.md\`）。 handoff-scan: fixture	正本の語"
}

ALL_RULES='①再開の禁止 ②手渡しの許可条件 ③宣言の書式と選び方 ④停止指示と停止確認'

@test "single source: each rule is detected on its own, without being confused for another rule" {
  local i=0 rule sample kind sandbox other
  while IFS=$'\t' read -r rule sample kind; do
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
  [ "$i" -eq 13 ] || { echo "サンプル数が想定と違う: $i"; return 1; }
}

# spec が列挙する語彙。setup() が live spec から読み取った一覧（$VOCAB_TSV）を引く。
# テスト内に写しを持たないのは spec の MUST NOT で、写しを持つと spec の一覧を残したまま
# 実装とテストの両方から同じ語を消しても全テストが緑になる（PR #253 のレビュー B4）。
# 下の 3 つのテストが使う: ①読み取りが壊れていないこと、②言い換えサンプルが正本の語を
# 使っていないこと、③列挙した各要素が現に走査を発火させること。
ALL_VOCAB_GROUPS='①状況 ①指示 ①述語 ②行為 ②状態 ②述語 ③話題 ③述語 ③文脈 ④停止 ④確認 ④文脈 ④述語'

vocab_group() { # $1=グループ名（①状況 等）→ 1 行 1 語
  local out
  out="$(grep -F -- "$1$(printf '\t')" "$VOCAB_TSV" | cut -f2)"
  [ -n "$out" ] || { echo "spec から語彙グループを読み取れない: $1" >&2; return 1; }
  printf '%s\n' "$out"
}

# 読み取りが黙って空を返すと語彙の検査がまとめて消えるので、形だけを先に固定する（spec の MUST）。
@test "single source: the scan vocabulary is read from the spec, not copied into the tests" {
  local groups g count
  groups="$(cut -f1 "$VOCAB_TSV" | LC_ALL=C sort -u | grep -c .)"  # macOS の sort は多バイトの比較を壊すので C ロケールで引く
  [ "$groups" -eq 13 ] || { echo "spec から読み取れたグループが 13 個でない: $groups"; return 1; }
  for g in $ALL_VOCAB_GROUPS; do
    count="$(vocab_group "$g" | grep -c .)" || return 1
    [ "$count" -ge 3 ] || { echo "語彙グループが小さすぎる: $g（$count 語）"; return 1; }
  done
}

read_vocab() { # $1=グループ名 → 呼び出し側の配列名 $2 に読み込む
  local t n=0
  while IFS= read -r t; do eval "$2+=(\"\$t\")"; n=$((n + 1)); done < <(vocab_group "$1")
  # 読み取れないまま空の配列で進むと、語彙を使うテストがまとめて素通りする（spec の MUST）
  [ "$n" -ge 3 ] || { echo "spec の語彙グループが読み取れない: $1（$n 語）"; return 1; }
}

# spec の MUST:「サンプルは各規則につき、正本の語をそのまま使った文と、正本の語をひとつも
# 使わない言い換えの 2 本を含めなければならない」。言い換えが正本の語を含むと、実装が正本の語を
# そのまま照合しているだけでも緑になる（実測: 4 本とも正本の語を含んでいた。PR #253 のレビュー指摘）。
@test "single source: each paraphrase sample uses none of the source's vocabulary" {
  local rule sample kind token found=0
  while IFS=$'\t' read -r rule sample kind; do
    [ "$kind" = '言い換え' ] || continue
    found=$((found + 1))
    while IFS=$'\t' read -r token regex; do
      printf '%s' "$sample" | grep -qE -- "$regex" || continue
      if cap_sec | grep -qE -- "$regex"; then
        echo "言い換えサンプル（$rule）が正本の語「$token」を使っている: $sample"
        return 1
      fi
    done < <(cut -f2,3 "$VOCAB_TSV")
  done < <(restatement_samples)
  [ "$found" -eq 4 ] || { echo "言い換えサンプルが 4 本ない: $found"; return 1; }
}

# 列挙した語彙の各要素が現に走査を発火させること。1 つ消してもサンプルが別の語で拾われて
# 全テストが緑のまま通る穴を塞ぐ（実測: `工程の終わり` を消しても 25/25 緑だった。PR #253 のレビュー指摘）。
# 自然文にすると 1 文が複数の規則に掛かりやすいので、語彙をそのまま並べた合成文を使う。
@test "single source: every listed vocabulary alternative on its own trips its rule" {
  local -a T1=() T2=() P1=() ACT=() COND=() ONLY=() CTX3=() TOPIC=() PRED3=() STOP=() CONF=() PRED4=() CTX4=()
  read_vocab ①状況 T1; read_vocab ①指示 T2; read_vocab ①述語 P1
  read_vocab ②行為 ACT; read_vocab ②状態 COND; read_vocab ②述語 ONLY
  read_vocab ③文脈 CTX3; read_vocab ③話題 TOPIC; read_vocab ③述語 PRED3
  read_vocab ④停止 STOP; read_vocab ④確認 CONF; read_vocab ④述語 PRED4; read_vocab ④文脈 CTX4

  local sandbox="${BATS_TEST_TMPDIR}/vocab-coverage"
  mkdir -p "$sandbox"
  local -a expect=()
  local i
  for ((i = 0; i < ${#P1[@]}; i++)); do
    printf '%s %s%s\n' "${T1[i % ${#T1[@]}]}" "${T2[i % ${#T2[@]}]}" "${P1[i]}" >> "${sandbox}/restated.md"
    expect+=('①再開の禁止')
  done
  for ((i = 0; i < ${#ONLY[@]}; i++)); do
    printf '%s %s %s\n' "${ACT[i % ${#ACT[@]}]}" "${COND[i % ${#COND[@]}]}" "${ONLY[i]}" >> "${sandbox}/restated.md"
    expect+=('②手渡しの許可条件')
  done
  for ((i = 0; i < ${#PRED3[@]}; i++)); do
    printf '%s %s %s\n' "${CTX3[i % ${#CTX3[@]}]}" "${TOPIC[i % ${#TOPIC[@]}]}" "${PRED3[i]}" >> "${sandbox}/restated.md"
    expect+=('③宣言の書式と選び方')
  done
  for ((i = 0; i < ${#CTX4[@]}; i++)); do
    printf '%s %s %s %s\n' "${STOP[i % ${#STOP[@]}]}" "${CONF[i % ${#CONF[@]}]}" \
      "${PRED4[i % ${#PRED4[@]}]}" "${CTX4[i]}" >> "${sandbox}/restated.md"
    expect+=('④停止指示と停止確認')
  done

  git -C "$sandbox" init -q
  git -C "$sandbox" add -A
  # 合成文が組めていないまま（語彙が空のまま）緑になるのを防ぐ
  [ "${#expect[@]}" -ge 40 ] || { echo "合成文が少なすぎる: ${#expect[@]} 本"; return 1; }

  run run_scan --root "$sandbox" --this-change "$THIS_CHANGE" --mode restatement-sentences --source "$CRITERIA_REL"
  echo "$output"
  [ "$status" -eq 1 ]

  local num reported hits other
  for ((i = 0; i < ${#expect[@]}; i++)); do
    num=$((i + 1))
    reported="$(echo "$output" | grep -F "restated.md:${num}: " || true)"
    hits="$(printf '%s' "$reported" | grep -c . || true)"
    [ "$hits" = '1' ] || {
      echo "合成文 ${num}（期待: ${expect[i]}）の報告が 1 件でない: ${hits} 件"
      echo "$reported"; return 1; }
    case "$reported" in
      *"${expect[i]}"*) ;;
      *) echo "合成文 ${num} が ${expect[i]} として報告されなかった: $reported"; return 1 ;;
    esac
  done
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
