#!/usr/bin/env bats
#
# 保留で止まるときの引き継ぎと、新しいセッションでの再開（issue #515）
#
#   skills/develop/references/handover.md      引き継ぎの書式・投稿順・手渡し可否・再開手順・守備範囲（#1220 で SKILL.md から移した）
#   skills/develop/SKILL.md                     移設先を Read する案内と、他の節から移設先への参照
#   commands/develop.md                         引き継ぎのある記録先の入口
#   skills/pr-review-gate/stages/hold.md        手順 6 の依頼文の案内（項目一覧は持たない）
#
# spec: dev-workflow-develop, dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  HANDOVER="${PLUGIN_DIR}/skills/develop/references/handover.md"
  COMMAND="${PLUGIN_DIR}/commands/develop.md"
  HOLD="${PLUGIN_DIR}/skills/pr-review-gate/stages/hold.md"
}

# 引き継ぎの節（見出し「## 保留で止まるときの引き継ぎ」から次の ## まで）
handover_section() { awk 'index($0,"## 保留で止まるときの引き継ぎ")==1{f=1; print; next} /^## /{f=0} f' "$HANDOVER"; }

@test "handover: handover.md has the handover section with the one-line header regex" {
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

@test "handover: one format for the four hold scenes" {
  s="$(handover_section)"
  for k in 'pr-review-gate の保留' 'exit 2' '2 周キャップ超え' '仕様レビューの条件の問い'; do
    printf '%s' "$s" | grep -qF "$k"
  done
  printf '%s' "$s" | grep -qF '場面ごとに別の書式を作らない'
  printf '%s' "$s" | grep -qF '`条件の問い`'
  printf '%s' "$s" | grep -qF 'の 4 つで'
  # 条件の問いの引き継ぎはモードによらない（#1121）
  printf '%s' "$s" | grep -qF '仕様レビューの条件の問い（`条件の問い:` を主に聞くとき）'
  # 読むときの文（冒頭）と SKILL.md の案内も同じ 4 場面を数える（#1121）
  head -3 "$HANDOVER" | grep -qF '引き継ぎを書く 4 つの場面'
  head -3 "$HANDOVER" | grep -qF '仕様レビューの条件の問い'
  grep -F '引き継ぎを書く 4 つの場面' "$SKILL" | grep -qF '仕様レビューの条件の問い'
}

@test "handover (#1121): the condition question is posted by the main agent before the handover" {
  handover_section | grep -F '投稿の順序' | grep -qF 'exit 2 と 2 周キャップ超えと条件の問いは本体が問いを書く'
}

@test "resume (#1121): a rerun of R1 comes before W" {
  line="$(handover_section | grep -E '^4\. ')"
  printf '%s' "$line" | grep -qF '次に起こす役割が R1（当て直し）なら'
  printf '%s' "$line" | grep -qF '先に R1 を起こし、W はその結果に従って起こす'
  # R1 の文が W の起こし方より先にある
  printf '%s' "$line" | grep -qE '^4\. 次に起こす役割が R1（当て直し）なら'
}

@test "resume (#1121): a condition answer to a re-selection question also goes to R1 first" {
  line="$(handover_section | grep -E '^4\. ')"
  printf '%s' "$line" | grep -qF '待ち理由が `2 周キャップ超え` で手順 2 の答えが条件についての答えのときも'
  printf '%s' "$line" | grep -qF 'ラベルの付け先から `needs-approval` を外し'
}

@test "resume (#1121): the stage of the W after R1 follows the R1 result" {
  line="$(handover_section | grep -E '^4\. ')"
  printf '%s' "$line" | grep -qF '`APPROVE` なら `段: implement`'
  printf '%s' "$line" | grep -qF '「判定に回す指摘」どおり'
  printf '%s' "$line" | grep -qF '`段: spec`'
}

@test "handover (#1121): next role names the result comment for a rerun of R1" {
  handover_section | grep -F '| 次に起こす役割 |' | grep -qF 'R1（当て直し）なら残った BLOCKER を載せた結果コメントの URL'
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
  grep -n '保留 → needs-approval' "$SKILL" | grep -qF 'references/handover.md'
  awk '/\*\*exit 2（上限超）\*\*/{print}' "$SKILL" | grep -qF 'references/handover.md'
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

# 保留の依頼の出し直し（issue #724）
@test "resend: with no new information a repeated notice does not rewrite the request" {
  handover_section | grep -qF '**依頼の出し直し**'
  handover_section | grep -qF '新しい情報が無ければ'
  handover_section | grep -qF '書き直さない'
  handover_section | grep -qF '「変化なし」の 1 行'
  # 具体例（何を新しい情報とみなすか）
  handover_section | grep -qF '新しい情報とみなす例'
  handover_section | grep -qF '新しい情報とみなさない例'
}

@test "resend: with new information the full request is rewritten and the earlier message is not pointed at" {
  handover_section | grep -qF '依頼の全文'
  handover_section | grep -qF '`~/.claude/output-styles/readable.md` の節 3 の型の全文とリンク'
  handover_section | grep -qF '前のメッセージを指さない'
}

@test "resend: the gate hold line in the loop points at the resend rule" {
  grep -F '保留 → needs-approval のまま' "$SKILL" | grep -qF '依頼の出し直し'
}
