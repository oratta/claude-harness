#!/usr/bin/env bats
#
# 手渡し可否は前任の宣言（工程完了: / 工程中断:）が条件であることの構造検証
#
# 2026-09 の事故（バックグラウンドコマンド待ちで idle になっていた前任 W を「工程を終えた」と
# 誤認して手渡し、同じ worktree に新旧 2 人の W が並んだ）を受けて、判定材料を本体側の内容
# 判断から W / G 側の return 1 行目宣言に移した。「exit 2 なら再開しない」は無条件（作業継続の
# SendMessage が対象）で、「手渡してよい」は前任の直近 return が `工程完了:` のときだけという、
# 別々の規則であることを固定する。
#
# spec: dev-workflow-execution-strategy, dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  WORKER="${PLUGIN_DIR}/skills/develop/references/roles/worker.md"
  GATE="${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  TRIPWIRES="${PLUGIN_DIR}/templates/escalation-tripwires.md"
}

# 「## <見出し>」から次の「## 」までを切り出す
section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }
# decision-criteria.md のコンテキスト上限節
cap_sec() { section "$CRITERIA" 'コンテキスト上限（サブエージェントの手渡し）'; }
# SKILL.md の 1 ループ節 / 本体の役割節
loop_sec() { section "$SKILL" '1 ループ（W → R1 → W → G）'; }
role_sec() { section "$SKILL" '本体の役割'; }

@test "criteria: exit-2 non-resume is unconditional and scoped to continuation SendMessage only" {
  cap_sec | grep -qF '再開の禁止は無条件'
  cap_sec | grep -qF '作業の継続を指示する SendMessage'
}

@test "criteria: handoff is permitted only when the predecessor declared process-complete" {
  cap_sec | grep -qF '工程完了: <工程名>'
  cap_sec | grep -qF '手渡しの許可'
  cap_sec | grep -qE '工程完了.*とき.*だけ|とき.*だけ.*工程完了'
}

@test "criteria: process-suspended covers waiting on a self-started background command" {
  cap_sec | grep -qF '工程中断: <理由>'
  cap_sec | grep -qF 'バックグラウンドコマンド'
}

@test "criteria: appending an achievement list does not excuse declaring process-complete while the command is unfinished" {
  cap_sec | grep -qF '成果一覧を書いていても'
  cap_sec | grep -qF '完了していなければ'
  cap_sec | grep -qF '宣言してはならない'
}

@test "criteria: idle while waiting is distinguished from a completed return" {
  cap_sec | grep -qF 'idle'
  cap_sec | grep -qF '工程の終わりではない'
}

@test "criteria: predecessor still running requires a stop instruction before handoff" {
  cap_sec | grep -qF '停止を指示'
  cap_sec | grep -qF '停止確認'
  cap_sec | grep -qF '破壊的 git 操作'
}

@test "criteria: waiting for a stop confirmation is non-blocking, and unmanned ends the cycle instead of blocking" {
  cap_sec | grep -qF 'ブロックせず'
  cap_sec | grep -qE 'unmanned.*サイクルを終える|サイクルを終える.*unmanned'
}

@test "worker: return's first line must match process-complete/process-suspended exactly, same format family as the spec decision" {
  grep -qF '工程完了: <工程名>' "$WORKER"
  grep -qF '工程中断: <理由>' "$WORKER"
  grep -qF '仕様化判断: する|しない' "$WORKER"
}

@test "worker: forbids declaring process-complete while a self-started background command is still running" {
  grep -qF '完了していなければ' "$WORKER"
  grep -qF '宣言してはならない' "$WORKER"
}

@test "gate-runner: G's return also follows the same first-line declaration contract" {
  grep -qF '工程完了: <工程名>' "$GATE"
  grep -qF '工程中断: <理由>' "$GATE"
}

@test "skill: loop (3)/(4) points at process-complete as the handoff precondition" {
  loop_sec | grep -qF '工程完了:'
  loop_sec | grep -qF '工程中断:'
}

@test "skill: same-worktree same-role concurrency is capped at one" {
  role_sec | grep -qE '1 人|同時に動く同一役割'
  role_sec | grep -qF '別々の worktree'
}

@test "tripwire template: wire 4 points at the process-complete declaration precondition" {
  w4="$(awk '/^4\. /{f=1} /^5\. /{f=0} f' "$TRIPWIRES")"
  echo "$w4" | grep -qF '工程完了: <工程名>'
  echo "$w4" | grep -qF '工程中断:'
}

# --- 旧文言の残留検出（否定アサーション） ---
#
# 上の 13 件は「新しい文言が存在するか」しか見ないので、同じ規則を述べている別の箇所に
# 旧仕様（上限超なら無条件に新しい W / G を spawn）が残っていても全件 PASS する。実際に
# PR #253 の 1 周目で SKILL.md の 1 ループ・`openspec/specs/dev-workflow-develop`・README・
# `session-tripwires.sh`・`subagent-context.sh`・`plugin.json` の 6 か所が取り残された。
# 「手渡しの規則を述べている面」を列挙し、旧文言が 1 か所でも残っていたら落とす。
#
# 対象外: `CHANGELOG.md` と過去の change の archive（`openspec/changes/archive/` のうち
# この change 以外）。どちらも「そのリリース／その change の時点で何を決めたか」の歴史記録で、
# 現行仕様に合わせて書き換えると記録そのものが嘘になる。

# 手渡しの規則を述べる現行面（正本・live spec・この change の archive delta・配布物）
handoff_surfaces() {
  local root; root="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  local change="${root}/openspec/changes/archive/2026-09-08-handoff-requires-completed-return"
  printf '%s\n' \
    "${PLUGIN_DIR}/skills/develop/SKILL.md" \
    "${PLUGIN_DIR}/skills/develop/references/decision-criteria.md" \
    "${PLUGIN_DIR}/skills/develop/references/roles/worker.md" \
    "${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md" \
    "${PLUGIN_DIR}/templates/escalation-tripwires.md" \
    "${PLUGIN_DIR}/README.md" \
    "${PLUGIN_DIR}/scripts/session-tripwires.sh" \
    "${PLUGIN_DIR}/scripts/subagent-context.sh" \
    "${PLUGIN_DIR}/.claude-plugin/plugin.json" \
    "${root}/openspec/specs/dev-workflow-develop/spec.md" \
    "${root}/openspec/specs/dev-workflow-execution-strategy/spec.md" \
    "${change}/specs/dev-workflow-develop/spec.md" \
    "${change}/specs/dev-workflow-execution-strategy/spec.md"
}

# grep は locale 次第でマルチバイトの否定クラスが壊れるので python3 で走査する
scan_surfaces() {
  local pattern="$1"; shift
  python3 - "$pattern" "$@" <<'PY'
import re, sys
pattern, paths = sys.argv[1], sys.argv[2:]
pat = re.compile(pattern)
bad = 0
for path in paths:
    try:
        text = open(path, encoding='utf-8').read()
    except OSError:
        print(f'missing surface: {path}')
        bad = 1
        continue
    for i, line in enumerate(text.splitlines(), 1):
        if pat.search(line):
            print(f'{path}:{i}: {line.strip()[:200]}')
            bad = 1
sys.exit(1 if bad else 0)
PY
}

@test "no surface still states the handoff as an unconditional consequence of the context cap" {
  # 「再開せず／再開しない」と同じ文の中で手渡し・新しいエージェントの spawn に続ける形。
  # exit 2 の再開禁止は無条件のまま正しいので、禁止だけを述べる文（文末まで）は素通りさせる。
  local -a surfaces=()
  while IFS= read -r f; do surfaces+=("$f"); done < <(handoff_surfaces)
  run scan_surfaces '再開(せず|しない)[^。\n]{0,40}(手渡|新しい)' "${surfaces[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "every surface that mentions the handoff also carries the process-complete precondition" {
  fail=0
  while IFS= read -r f; do
    if [ ! -f "$f" ]; then
      echo "missing surface: $f"
      fail=1
      continue
    fi
    grep -qF '手渡' "$f" || continue
    if ! grep -qF '工程完了' "$f"; then
      echo "手渡しに触れているのに条件（工程完了:）が書かれていない: $f"
      fail=1
    fi
  done < <(handoff_surfaces)
  [ "$fail" -eq 0 ]
}

# --- 文単位の走査（行単位の否定アサーションが取りこぼした 2 種を固定する） ---
#
# 上の 2 件の否定アサーションは「再開せず／再開しない」で始まる形しか見ないので、
# PR #253 の 2 周目で SKILL.md の「コンテキスト上限（exit 2）は昇格ではなく手渡しで」という
# 言い回し（「再開」の語を含まない）を検出できず 15/15 PASS のまま素通りした。以下は文単位で
# 走査し、(a) 上限超過を手渡しの帰結として無条件に述べる文と、(b) 手渡しの許可条件を述べる
# 絶対文から停止確認の例外が落ちている状態、の 2 種を固定する。

# 文（。で区切る）ごとに python3 で走査する。マルチバイトの否定クラスは grep では壊れる。
# 見出し行と【…】のラベル（【コンテキスト上限 → 手渡し】＝トリップワイヤー 4 の名前）は対象外。
scan_sentences() {
  local require_all="$1" trigger="$2" exempt="$3"; shift 3
  python3 - "$require_all" "$trigger" "$exempt" "$@" <<'PY'
import re, sys
require_all, trigger, exempt, paths = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
req = [t for t in require_all.split(',') if t]
trig, exm = re.compile(trigger), (re.compile(exempt) if exempt else None)
bad = 0
for path in paths:
    try:
        text = open(path, encoding='utf-8').read()
    except OSError:
        print(f'missing surface: {path}')
        bad = 1
        continue
    for i, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith('#'):
            continue
        for s in re.split('。', re.sub('【[^】]*】', '', line)):
            if not trig.search(s):
                continue
            if exm and exm.search(s):
                continue
            # require_all が空なら純粋な否定走査（trigger に当たり exempt でない文は全部落とす）
            if req and all(t in s for t in req):
                continue
            print(f'{path}:{i}: {s.strip()[:200]}')
            bad = 1
sys.exit(1 if bad else 0)
PY
}

@test "no sentence states the handoff as the consequence of the context cap without naming its condition" {
  local -a surfaces=()
  while IFS= read -r f; do surfaces+=("$f"); done < <(handoff_surfaces)
  # 上限超過（exit 2 等）と手渡しを同じ文で述べるなら、条件（工程完了 / 停止確認 / 条件 / だけ /
  # 禁止）のいずれかを同じ文に持っていなければならない。
  run scan_sentences '' '手渡.*(exit ?2|コンテキスト上限|上限を超え|上限超)|(exit ?2|コンテキスト上限|上限を超え|上限超).*手渡' \
    '工程完了|停止確認|条件|だけ|禁止|MUST NOT' "${surfaces[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

# 手渡しの許可条件を絶対文で述べている面（同じ言い回しの再掲 3 箇所）
handoff_permission_surfaces() {
  local root; root="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  printf '%s\n' \
    "${PLUGIN_DIR}/skills/develop/references/decision-criteria.md" \
    "${root}/openspec/specs/dev-workflow-execution-strategy/spec.md" \
    "${root}/openspec/changes/archive/2026-09-08-handoff-requires-completed-return/specs/dev-workflow-execution-strategy/spec.md"
}

@test "handoff permission sentence keeps the stop-confirmation route as an exception, not only the process-complete return" {
  local -a surfaces=()
  while IFS= read -r f; do surfaces+=("$f"); done < <(handoff_permission_surfaces)
  # 「手渡しを行ってよいのは〜だけ」と述べる文は、工程完了の宣言と停止確認の両方を挙げること。
  # 停止確認の経路（前任へ停止を指示し、確認を受け取ってから spawn する）は同じ Requirement が
  # 意図的に許している経路なので、絶対文がそれを否定してはならない。
  run scan_sentences '工程完了,停止確認' '手渡.*行ってよいのは' '' "${surfaces[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}
