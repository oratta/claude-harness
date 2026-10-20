#!/usr/bin/env bats
#
# develop の 3 つ目の実行モード channel（issue #1126）
#
#   skills/develop/SKILL.md                     実行モードの節・引き継ぎ・再開・エピックの回し方・G の起動指示
#   commands/develop.md                         モードの決め方・引数の分岐 ②⑤ と issueify フォールバックの聞き方
#   skills/pr-review-gate/stages/hold.md        手順 6-3 の依頼文を実行モードで分ける
#
# 文面の確かめ。節ごとに切り出してから grep し、他の節の既存の文で偽合格しないようにする。
#
# spec: dev-workflow-develop, dev-workflow-pr-review-gate

setup() {
  # 正規表現の [^。] などは UTF-8 ロケールが前提（#662）
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  CMD="${PLUGIN_DIR}/commands/develop.md"
  HOLD="${PLUGIN_DIR}/skills/pr-review-gate/stages/hold.md"
}

# 「## <見出し>」から次の「## 」までを切り出す
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$SKILL"; }
# 「### <見出し>」から次の「## 」か「### 」までを切り出す
subsection() { awk -v h="### $1" 'index($0, h)==1{f=1; print; next} /^##+ /{f=0} f' "$SKILL"; }
# 1 ループの (4) を切り出す（列 0 の "(4) " から次の列 0 の工程ラベルか ``` まで）
step4() { awk '/^\(4\)[[:space:]]/{f=1; print; next} f && (/^\([0-9]+\)[[:space:]]/ || /^```/){f=0} f' "$SKILL"; }
# hold.md 手順 6 の 3 番目の項目
hold_6_3() { awk '/^### 6\. 保留処理/{f=1; next} /^### /{f=0} f && /^3\. /{print}' "$HOLD"; }

refute() {
  local body="$1"; shift
  if printf '%s\n' "$body" | grep -q "$@"; then
    echo "一致してはならないパターンに一致した: $*" >&2
    return 1
  fi
}

# --- 実行モードの表と決め方 ---

@test "mode table: channel row runs (0)-(4) and asks in the channel without AskUserQuestion" {
  local s; s="$(section '実行モード')"
  local row; row="$(printf '%s\n' "$s" | grep -F '| **channel**')"
  [ -n "$row" ]
  printf '%s\n' "$row" | grep -qF '(0)〜(4)'
  printf '%s\n' "$row" | grep -qF 'チャンネルで聞く（AskUserQuestion は使わない）'
}

@test "mode decision: order, marker reading, start comment line, no change midway" {
  local s; s="$(subsection 'モードの決め方')"
  [ -n "$s" ]
  printf '%s\n' "$s" | grep -qF -- '`--unmanned`'
  printf '%s\n' "$s" | grep -qF 'DEV_WORKFLOW_UNATTENDED'
  printf '%s\n' "$s" | grep -qF '<channel source='
  printf '%s\n' "$s" | grep -qF '未設定・空・`0` は印なし'
  printf '%s\n' "$s" | grep -qF '実行モード: <モード>（<理由>）'
  printf '%s\n' "$s" | grep -qF '途中でモードを変えない'
  printf '%s\n' "$s" | grep -qF '引き継ぎの `実行モード` の値を使'
}

@test "start comment: Role profile section lists the mode line and the channel reply check line" {
  local s; s="$(section 'Role profile の選択')"
  printf '%s\n' "$s" | grep -qF '`実行モード:`'
  printf '%s\n' "$s" | grep -qF '`チャンネルの返事の確認:`'
}

# --- 聞き方と読み替え ---

@test "channel asking: reply tool to the chat_id, end the turn, URL of the recorded question" {
  local s; s="$(subsection 'channel の聞き方')"
  [ -n "$s" ]
  printf '%s\n' "$s" | grep -qF 'chat_id'
  printf '%s\n' "$s" | grep -qF 'ターンを終える'
  printf '%s\n' "$s" | grep -qF 'needs-approval'
  printf '%s\n' "$s" | grep -qF 'フル URL'
  printf '%s\n' "$s" | grep -qF 'channel ではこの聞き方に読む'
}

@test "reading rule: every file mentioning AskUserQuestion is listed by its plugin-relative path" {
  local s; s="$(subsection 'channel の聞き方')"
  local files f rel n=0
  files="$(cd "$PLUGIN_DIR" && grep -rl --exclude-dir=tests --exclude-dir=changes 'AskUserQuestion' . | sed 's|^\./||' | sort)"
  [ -n "$files" ]
  while IFS= read -r rel; do
    [ "$rel" = "skills/develop/SKILL.md" ] && continue
    n=$((n + 1))
    if ! printf '%s\n' "$s" | grep -qF "\`$rel\`"; then
      echo "読み替えの列挙に無い: $rel" >&2
      return 1
    fi
  done <<< "$files"
  [ "$n" -ge 8 ]
}

@test "AskUserQuestion lines in SKILL.md are interactive-only or in the Orca child section" {
  local line
  # 実行モードの節の読み替えの規則があること
  section '実行モード' | grep -qF 'channel ではこの聞き方に読む'
  # 各行が interactive の文脈か、channel を明示して除いているか、Orca 経路の子の節の行であること
  local child; child="$(section 'エピックの子が主の返事を待って止まるとき')"
  while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -qE 'interactive|channel'; then continue; fi
    if printf '%s\n' "$child" | grep -qF -- "$line"; then continue; fi
    echo "interactive の文脈と読めない行: $line" >&2
    return 1
  done < <(grep -F 'AskUserQuestion' "$SKILL")
}

# --- リスク許容と主への発言 ---

@test "channel risk acceptance: check OWNER_REPLY_CHANNEL_SENDERS without printing, PR comment when not possible" {
  local s; s="$(section '実行モード')"
  printf '%s\n' "$s" | grep -qF 'チャンネルの返事の確認: 可'
  printf '%s\n' "$s" | grep -qF 'チャンネルの返事の確認: 不可（OWNER_REPLY_CHANNEL_SENDERS が無い）'
  printf '%s\n' "$s" | grep -qF '値を出さず'
  printf '%s\n' "$s" | grep -qF 'PR #<N> にコメントで `許容する`'
}

@test "channel statements: all go to the channel with one of three first lines, no screen or tab" {
  local s; s="$(subsection 'channel の主への発言')"
  [ -n "$s" ]
  printf '%s\n' "$s" | grep -qF '主へのすべての発言'
  printf '%s\n' "$s" | grep -qF '端末に出すだけで済ませない'
  printf '%s\n' "$s" | grep -qF '`主がすること: なし`'
  printf '%s\n' "$s" | grep -qF '`主がすること: このチャンネルで <何を返す>`'
  printf '%s\n' "$s" | grep -qF '`主がすること: PR #<N> に <何を書く>`'
  printf '%s\n' "$s" | grep -qF '画面・タブ・入力欄'
}

@test "G start instruction: channel writes the channel reply check line" {
  step4 | grep -qF '`チャンネルの返事の確認:`'
}

# --- 保留・再開 ---

@test "handover: mode values include channel and the channel guidance has no new session" {
  local s; s="$(section '保留で止まるときの引き継ぎ')"
  printf '%s\n' "$s" | grep -qF '| 実行モード | interactive / channel / unmanned |'
  printf '%s\n' "$s" | grep -qF 'このチャンネルで記録先の番号を添えて返事'
  printf '%s\n' "$s" | grep -qF '番号の無い返事'
  # interactive の案内は残る
  printf '%s\n' "$s" | grep -qF '返事は新しいセッションで `/develop <記録先>` と一緒に渡す'
}

@test "resume: channel reply launches develop and passes the log line's text and timestamp" {
  local s; s="$(subsection '新しいセッションでの再開')"
  printf '%s\n' "$s" | grep -qF 'develop を記録先 `<番号>` で起動'
  printf '%s\n' "$s" | grep -qF '`<channel source=` で始まる'
  printf '%s\n' "$s" | grep -qF 'チャンネルの返事'
}

# --- エピック ---

@test "epic: channel does not call route and does not start another session" {
  local s; s="$(subsection '回し方')"
  printf '%s\n' "$s" | grep -qF '`回し方: サブエージェント（channel モード）`'
  printf '%s\n' "$s" | grep -qF '別の Claude Code セッション'
}

# --- commands/develop.md ---

@test "command: mode follows SKILL.md, channel asks branches 2 and 5 and issueify approval in the channel" {
  grep -qF 'SKILL.md「実行モード」の決め方' "$CMD"
  [ "$(grep -c 'channel ではチャンネルに送ってターンを終え' "$CMD")" -ge 3 ]
}

# --- hold.md ---

@test "hold.md 6-3: interactive keeps the new-session guidance, channel guides a channel reply" {
  local s; s="$(hold_6_3)"
  [ -n "$s" ]
  printf '%s\n' "$s" | grep -qF '/develop <記録先>'
  printf '%s\n' "$s" | grep -qF 'このチャンネルで記録先の番号を添えて返事'
  printf '%s\n' "$s" | grep -qF '`チャンネルの返事の確認:`'
  printf '%s\n' "$s" | grep -qF 'PR #<N> にコメントで `許容する`'
  refute "$s" -F '前任 W'
}
