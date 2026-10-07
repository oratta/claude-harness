#!/usr/bin/env bats
#
# 保留で止まるときの引き継ぎと、新しいセッションでの再開（issue #515）
#
#   skills/develop/SKILL.md                     引き継ぎの書式・投稿順・手渡し可否・再開手順・守備範囲
#   commands/develop.md                         引き継ぎのある記録先の入口
#   skills/pr-review-gate/stages/hold.md        手順 6 の依頼文の案内（項目一覧は持たない）
#
# spec: dev-workflow-develop, dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  COMMAND="${PLUGIN_DIR}/commands/develop.md"
  HOLD="${PLUGIN_DIR}/skills/pr-review-gate/stages/hold.md"
}

# 引き継ぎの節（見出し「## 保留で止まるときの引き継ぎ」から次の ## まで）
handover_section() { awk 'index($0,"## 保留で止まるときの引き継ぎ")==1{f=1; print; next} /^## /{f=0} f' "$SKILL"; }

@test "handover: SKILL.md has the handover section with the one-line header regex" {
  [ -n "$(handover_section)" ]
  handover_section | grep -qF '^引き継ぎ: 主の返事待ち$'
  [ "$(grep -c '引き継ぎ' "$SKILL")" -ge 1 ]
}

@test "handover: all 11 item names are listed" {
  for k in '待ち理由' '主への依頼' '対象' 'ラベルの付け先' '実行モード' '実行先' '次に起こす役割' '周回' '前任 W' 'PR トークン上限' '回し方'; do
    handover_section | grep -qF "| ${k} |"
  done
}

@test "handover: does not record the W name" {
  handover_section | grep -qF 'W の名前は書かない'
}

@test "handover: one format for the three hold scenes" {
  s="$(handover_section)"
  for k in 'pr-review-gate の保留' 'exit 2' '2 周キャップ超え'; do
    printf '%s' "$s" | grep -qF "$k"
  done
  printf '%s' "$s" | grep -qF '場面ごとに別の書式を作らない'
}

@test "handover: posting order is request, handover, guidance and the request may be a PR comment" {
  s="$(handover_section)"
  printf '%s' "$s" | grep -qF '依頼のコメントを投稿'
  printf '%s' "$s" | grep -qF 'PR のコメントの URL でよい'
  printf '%s' "$s" | grep -qF '依頼より前に引き継ぎを投稿しない'
}

@test "handover: guidance to the owner mentions a new session" {
  handover_section | grep -qF '/develop <記録先>'
  handover_section | grep -qF '1 時間以内'
}

@test "handover: previous W handover-ability is decided before writing" {
  s="$(handover_section)"
  for k in '手渡し: 可' '手渡し: 不可' '手渡し: 不要' '停止確認' 'decision-criteria.md'; do
    printf '%s' "$s" | grep -qF "$k"
  done
}

@test "resume: six steps with label target and W start conditions" {
  s="$(handover_section)"
  printf '%s' "$s" | grep -qF '新しいセッションでの再開'
  printf '%s' "$s" | grep -qF 'ラベルの付け先'
  printf '%s' "$s" | grep -qF '初回の W'
  printf '%s' "$s" | grep -qF 'develop 開始コメント'
  printf '%s' "$s" | grep -qF 'dispatch 記録'
  printf '%s' "$s" | grep -qF '最新の `PR トークン上限:`'
  printf '%s' "$s" | grep -qF 'SendMessage しない'
}

@test "resume: scope paragraph has the four elements" {
  s="$(handover_section)"
  printf '%s' "$s" | grep -qF '守備範囲'
  printf '%s' "$s" | grep -qF '出どころ'
  printf '%s' "$s" | grep -qF '拾いたい誤り'
  printf '%s' "$s" | grep -qF '通してよい入力'
  printf '%s' "$s" | grep -qF '完了条件にしない'
}

@test "loop: the hold row and the token-cap exit 2 point to the handover section" {
  grep -n '保留 → needs-approval' "$SKILL" | grep -qF '保留で止まるときの引き継ぎ'
  awk '/\*\*exit 2（上限超）\*\*/{print}' "$SKILL" | grep -qF '保留で止まるときの引き継ぎ'
}

@test "command: an existing handover comment routes to the resume steps regardless of the label" {
  grep -qF '引き継ぎ: 主の返事待ち' "$COMMAND"
  grep -qF '再開' "$COMMAND"
  grep -qF 'ラベルの有無によらず' "$COMMAND"
  grep -qF '引数の記録先より後ろ' "$COMMAND"
}

@test "hold.md step 6 guides the owner to a new session and lists no handover items" {
  grep -qF '/develop <記録先>' "$HOLD"
  ! grep -qF '前任 W' "$HOLD" || return 1
  ! grep -qF 'ラベルの付け先' "$HOLD" || return 1
}

@test "loop: the token-cap exit 2 puts the label where the handover's label target says (PR if any, else the record)" {
  awk '/\*\*exit 2（上限超）\*\*/{print}' "$SKILL" | grep -qF 'PR があれば PR、無ければ記録先に `needs-approval` を付け'
}

@test "handover (#721): guidance accepts a conversation reply or /develop args without a PR comment" {
  s="$(handover_section)"
  printf '%s' "$s" | grep -qF '/develop <記録先> 許容する'
  printf '%s' "$s" | grep -qF 'PR へのコメントは要らない'
}

@test "handover (#721): resume step 2 passes session id, timestamp and text to the G" {
  handover_section | grep '^2\. ' | grep -qF 'CLAUDE_CODE_SESSION_ID'
}
