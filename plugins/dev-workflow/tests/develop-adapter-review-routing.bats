#!/usr/bin/env bats
#
# adapter 経路の PR レビュー投げ先を本体が選び直す（issue #385）
#
#   gate-runner.md          G: `レビュー経路:` の 1 行で経路を判別し、adapter 経路では needs-reviewer を返す
#   develop SKILL.md        本体: G の起動指示に常に `レビュー経路: adapter` を書き、phase review を選び直して記録する
#   codex-develop.md        G の規則が `レビュー経路: adapter` の明示に触れる
#   pr-review-gate SKILL.md 「レビュー実行者:」の adapter 経路の形
#
# spec: dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  GATE="${PLUGIN_DIR}/skills/develop/references/roles/gate-runner.md"
  DEVELOP="${PLUGIN_DIR}/skills/develop/SKILL.md"
  CODEX_DEVELOP="${PLUGIN_DIR}/references/codex-develop.md"
  PRGATE="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
}

section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }

# develop SKILL.md の (4) ブロック（「(4) G を」からコードブロックの終わりまで）
step4() { awk '/^\(4\) G を/{f=1} f && /^```/{exit} f' "$DEVELOP"; }

# ===== gate-runner.md: 経路の判別（1.1） =====

@test "gate-runner (#390): input contract includes the route and adapter resume dispatch details" {
  intro="$(sed -n '1,3p' "$GATE")"
  echo "$intro" | grep -qF '`レビュー経路:` の 1 行'
  echo "$intro" | grep -qF '選ばれた executor / model'
  echo "$intro" | grep -qF 'dispatch 記録のコメント URL'
}

@test "gate-runner (#385): has a route-detection section that names both values and treats a missing line as the legacy route" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  [ -n "$s" ] || { echo "no レビュー経路の判別 section"; return 1; }
  echo "$s" | grep -qF '`レビュー経路: adapter`'
  echo "$s" | grep -qF '`レビュー経路: 従来`'
  echo "$s" | grep -qF 'この行だけで'
  echo "$s" | grep -qF '環境変数・記録先のコメント・自分の起動方法から推測しない'
  echo "$s" | grep -qE '行が無い.*従来経路'
}

@test "gate-runner (#391): an adapter-started G keeps the adapter route when the same G resumes without a route line" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  echo "$s" | grep -qF '`レビュー経路: adapter` で起動済みの同一 G'
  echo "$s" | grep -qF '再開指示に `レビュー経路:` 行が無くても adapter 経路を保持する'
}

@test "gate-runner (#391): a missing route selects legacy only when starting a new G, including a handoff successor" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  echo "$s" | grep -qF '新しい G の起動指示（手渡しで起こされた後任 G を含む）'
  echo "$s" | grep -qF '行が無い場合だけ従来経路'
}

@test "gate-runner (#385): route-detection section comes before the reviewer table" {
  a="$(grep -n '^## レビュー経路の判別' "$GATE" | cut -d: -f1)"
  b="$(grep -n '^## レビューの実行者' "$GATE" | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]
}

@test "gate-runner (#385): adapter route covers every adapter configuration and the legacy table applies only to the legacy value or no line" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  echo "$s" | grep -qF '新 Codex モードを含む adapter 解決の全構成'
  echo "$s" | grep -qF '`claude-default`'
  echo "$s" | grep -qE '従来モードのレビュー実行者の表は.*`レビュー経路: 従来`.*行が無い.*ときだけ'
}

@test "gate-runner (#385): adapter route never calls Codex/companion/reviewer itself, even for full, and returns needs-reviewer" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  echo "$s" | grep -qF 'full でも'
  echo "$s" | grep -qF '`codex exec`'
  echo "$s" | grep -qF '`codex-companion.mjs`'
  echo "$s" | grep -qF 'レビュアーを自分で呼ばず'
  echo "$s" | grep -qF '`needs-reviewer`'
  echo "$s" | grep -qF 'Codex 不可の実測'
}

@test "gate-runner (#396): adapter route checks for another G on the same PR and HEAD before needs-reviewer" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  line="$(echo "$s" | grep -F '| `レビュー経路: adapter` |')"
  echo "$line" | grep -qF '手順 1 と手順 2-0 まで済ませ'
  echo "$line" | grep -qF '同一 PR/HEAD で他の G が着手済みでないことを確認してから'
  echo "$line" | grep -qF '`needs-reviewer`'
}

@test "gate-runner (#385): the adapter rule is limited to G and excluded for the phase review reviewer" {
  s="$(section "$GATE" 'レビュー経路の判別')"
  echo "$s" | grep -qF 'phase `gate`'
  echo "$s" | grep -qE 'phase `review` のレビュアー.*適用しない'
}

@test "gate-runner (#385): needs-reviewer payload has the adapter full verdict and the adapter not-run value for every evidence field" {
  n="$(section "$GATE" 'needs-reviewer')"
  echo "$n" | grep -qF -- '- 判定: light | full（Codex 不可） | full（adapter 経路）'
  for field in '選んだ経路:' '実行コマンド:' '終了コード:' '出力の要点:' '実待ち時間:'; do
    echo "$n" | grep -F -- "- ${field}" | grep -qF '未実行（adapter 経路）' || { echo "missing adapter value in ${field}"; return 1; }
  done
}

# ===== gate-runner.md: 従来経路の full を保つ（1.2） =====

@test "gate-runner (#385): legacy full row still calls Codex directly from G's Bash" {
  row="$(grep -F '| **full**（既定） | Codex CLI |' "$GATE")"
  [ -n "$row" ] || { echo "legacy full row missing"; return 1; }
  echo "$row" | grep -qF 'G の **Bash から直接**呼ぶ'
}

# ===== develop SKILL.md（1.3） =====

@test "develop (#392): reviewer model source differs between legacy and adapter routes" {
  row="$(grep -F '| G が要求するレビュアー（読んで判断する役） |' "$DEVELOP")"
  [ -n "$row" ] || { echo "reviewer model row missing"; return 1; }
  echo "$row" | grep -qF '従来経路では G の `needs-reviewer` の推奨モデルに従う'
  echo "$row" | grep -qF 'adapter 経路では adapter が返した model に残量上限を適用した値を使い'
  echo "$row" | grep -qF '推奨モデルは参考値'
}

@test "develop (#395): defect discovery names the adapter reviewer and legacy Codex" {
  s="$(step4)"
  echo "$s" | grep -qF '欠陥探索は needs-reviewer で本体が起こすレビュアー（従来経路では Codex）が担う'
}

@test "develop (#385): Role profile section always writes the adapter route line and never writes the legacy value" {
  s="$(section "$DEVELOP" 'Role profile の選択')"
  echo "$s" | grep -qF '起動形を問わず常に `レビュー経路: adapter`'
  echo "$s" | grep -qF 'request の instructions'
  echo "$s" | grep -qF '`レビュー経路: 従来` を書かない'
}

@test "develop (#391): Role profile section distinguishes a same-G resume from starting a new G when the route line is missing" {
  s="$(section "$DEVELOP" 'Role profile の選択')"
  echo "$s" | grep -qF 'adapter で起動済みの同一 G'
  echo "$s" | grep -qF '行の無い再開でも adapter 経路を保持する'
  echo "$s" | grep -qF '新しい G の起動指示（手渡しで起こされた後任 G を含む）に行が無い場合だけ従来経路'
  echo "$s" | grep -qF '行の省略を許可する規則ではない'
}

@test "develop (#385): step (4) always writes the adapter route line and never writes the legacy value" {
  s="$(step4)"
  [ -n "$s" ] || { echo "no (4) block"; return 1; }
  echo "$s" | grep -qF '常に `レビュー経路: adapter`'
  echo "$s" | grep -qF '`レビュー経路: 従来` は書かない'
}

@test "develop (#385): step (4) re-selects phase review, records dispatch before starting the reviewer, and hands results to G" {
  s="$(step4)"
  echo "$s" | grep -qF 'codex-develop.py request --phase review'
  echo "$s" | grep -qF '構成・reason・両 provider の margin・各 fetched_at'
  echo "$s" | grep -qF 'dispatch 記録'
  echo "$s" | grep -qF '投稿に成功するまでレビュアーを起動しない'
  echo "$s" | grep -qF 'executor / model・dispatch 記録のコメント URL を G に渡す'
  echo "$s" | grep -qF 'Claude の G は SendMessage で再開'
  echo "$s" | grep -qF 'Codex の G は新しい phase gate'
  # 順序: 選び直し → 記録 → 起動 → G に渡す
  a="$(echo "$s" | grep -nF 'request --phase review' | head -1 | cut -d: -f1)"
  b="$(echo "$s" | grep -nF '投稿に成功するまで' | head -1 | cut -d: -f1)"
  c="$(echo "$s" | grep -nF 'G に渡す' | head -1 | cut -d: -f1)"
  [ "$a" -le "$b" ] && [ "$b" -le "$c" ]
}

# ===== codex-develop.md（1.4） =====

@test "codex-develop (#385): the G rule mentions the explicit adapter route line" {
  s="$(section "$CODEX_DEVELOP" '品質と transport 差分')"
  line="$(echo "$s" | grep -F 'needs-reviewer')"
  echo "$line" | grep -qF '`レビュー経路: adapter`'
}

@test "codex-develop (#391): the G rule keeps adapter on same-G resume and defaults only a fresh G without a route line to legacy" {
  s="$(section "$CODEX_DEVELOP" '品質と transport 差分')"
  line="$(echo "$s" | grep -F 'needs-reviewer')"
  echo "$line" | grep -qF 'adapter で起動済みの同一 G'
  echo "$line" | grep -qF '行の無い再開でも adapter 経路を保持する'
  echo "$line" | grep -qF 'fresh G の起動指示に行が無い場合だけ従来経路'
}

@test "codex-develop (#394): missing-route legacy behavior distinguishes Claude G from Codex G" {
  s="$(section "$CODEX_DEVELOP" '品質と transport 差分')"
  line="$(echo "$s" | grep -F 'fresh G の起動指示に行が無い場合だけ従来経路')"
  echo "$line" | grep -qF 'Claude の G は Codex を直接呼ぶ'
  echo "$line" | grep -qF 'Codex の G は prompt の禁止により呼ばない'
  ! echo "$line" | grep -qF '行が無ければ従来経路として Codex を直接呼ぶ'
}

# ===== レビュー実行者: の adapter 経路の形（1.5） =====

@test "gate-runner and pr-review-gate (#385): both carry the adapter form of the reviewer line" {
  form='（adapter 経路・<light|full>・dispatch 記録:'
  grep -qF "$form" "$GATE"
  grep -qF "$form" "$PRGATE"
  # pr-review-gate は書き分けの段落と PR コメント雛形の両方に持つ
  [ "$(grep -cF "$form" "$PRGATE")" -ge 2 ]
}

@test "pr-review-gate (#393): all five evidence fields allow the adapter not-run value" {
  block="$(awk '/^対象 HEAD: <40 桁フル SHA>/{f=1} f{print} f && /^```$/{exit}' "$PRGATE")"
  [ -n "$block" ] || { echo "review evidence template missing"; return 1; }
  for field in '選んだ経路:' '実行コマンド:' '終了コード:' '出力の要点:' '実待ち時間:'; do
    echo "$block" | grep -F -- "$field" | grep -qF '未実行（adapter 経路）' || { echo "missing adapter value in ${field}"; return 1; }
  done
  [ "$(echo "$block" | grep -cF '未実行（adapter 経路）')" -eq 5 ]
}

@test "develop (#385): prerequisites table Codex CLI row separates the adapter route from the legacy route" {
  row="$(grep -F '| **Codex CLI** |' "$DEVELOP")"
  [ -n "$row" ] || { echo "Codex CLI row missing"; return 1; }
  echo "$row" | grep -qE 'adapter 経路.*`needs-reviewer`.*phase `review` で投げ先を選び直す'
  echo "$row" | grep -qE '従来経路.*G が full レビューを Bash から'
}
