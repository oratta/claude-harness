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
