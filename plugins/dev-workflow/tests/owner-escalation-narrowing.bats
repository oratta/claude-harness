#!/usr/bin/env bats
# owner-escalation-narrowing.bats — 主に上げる止まりを、主に聞く理由を根拠つきで示せたものに絞る（issue #1653）。
#
# 親が通す基準（parent-pass-criteria.md）、Orca 経路の手順 8（epic.md）、マージに回す基準
# （parent-merge-criteria.md）、子の止まりの手順（epic-child-stop.md）の文を確かめる。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REF="$PLUGIN_DIR/skills/develop/references"
  PASS="$REF/parent-pass-criteria.md"
  MERGE="$REF/parent-merge-criteria.md"
  EPIC="$REF/epic.md"
  CHILD="$REF/epic-child-stop.md"
}

# 見出し（`**<名前>**:` で始まる段落）を 1 段落だけ出す
para() { grep -F -- "**$1**" "$2"; }

# Orca 経路の手順 8 の段落
step8() { grep -E '^8\. `stopped <N>\.\.\.` で起こされたら' "$EPIC"; }

# --- グループ 3: 親が通す基準と子の止まり ---

@test "pass criteria (#1653): no lean-to-escalate wording remains" {
  run grep -n '成り立つ側に倒す' "$PASS"
  [ "$status" -eq 1 ]
  run grep -nE '迷うときは主に上げる|迷えば主に上げる|迷ったら主に上げる' "$PASS"
  [ "$status" -eq 1 ]
  run grep -F '通してよい止まりを判断のモデルが主に上げること' "$PASS"
  [ "$status" -eq 1 ]
  run grep -F '**迷ったとき**' "$PASS"
  [ "$status" -eq 1 ]
}

@test "pass criteria (#1653): escalating needs one of the three reasons with evidence in the reason line" {
  p="$(para '主に上げるとき' "$PASS")"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -F '`判断: 主に上げる`' | grep -F '3 つのどれに当たるか' | grep -F '根拠' | grep -qF '`理由:` に示せたときだけ'
  printf '%s\n' "$p" | grep -qF '示せなければ通す'
  printf '%s\n' "$p" | grep -qF '判断できないことだけを理由に主に上げない'
  # 出力の形の `理由:` の説明が根拠を求める
  grep -E '^理由: ' "$PASS" | grep -qF '根拠'
}

@test "pass criteria (#1653): sessions without a delegation keep the three safety conditions on the unsafe side" {
  p="$(para '主に上げるとき' "$PASS")"
  printf '%s\n' "$p" | grep -F '委任の無いセッション' | grep -F '「聖域でない」「戻せる」「実機操作でない」' | grep -qF '満たさない側に読む'
  printf '%s\n' "$p" | grep -qF '主に聞く理由の有無の判定とは別'
}

@test "pass criteria (#1653): delegation runs first and sessions without it never pass sanctuary, destructive git or merge" {
  p="$(para '委任との関係' "$PASS")"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -F '有効な委任が効く止まり' | grep -qF '委任の手順が先に効く'
  printf '%s\n' "$p" | grep -F '「聖域でない」' | grep -qF '委任で送らなかった止まりに当てる'
  printf '%s\n' "$p" | grep -F '委任の無いセッション' | grep -F '聖域の変更・破壊的な git 操作・マージ' | grep -qF '通さない'
}

@test "pass criteria (#1653): a doubtful question is read as a question and judged by the pass conditions" {
  grep -F '問いかどうか迷うときは' "$PASS" | grep -F '問いとして読み' | grep -qF '通す条件で判断する'
}

@test "pass criteria and child stop (#1653): both carry the three checks before 'only the owner has the answer'" {
  for f in "$PASS" "$CHILD"; do
    grep -F '(a)' "$f" | grep -F '調べれば分かる事実' >/dev/null || { echo "no (a) in $f"; return 1; }
    grep -F '(b)' "$f" | grep -F '主の手が要る操作' | grep -F '手順書' >/dev/null || { echo "no (b) in $f"; return 1; }
    grep -F '(c)' "$f" | grep -F '推奨と根拠' >/dev/null || { echo "no (c) in $f"; return 1; }
  done
}

@test "pass criteria and child stop (#1653): both list the 11/16, 11/12 and 11/13 cases as not passing" {
  for f in "$PASS" "$CHILD"; do
    grep -F '2026-11-16' "$f" | grep -F 'ログ' >/dev/null || { echo "no 11/16 in $f"; return 1; }
    grep -F '2026-11-12' "$f" | grep -F '手順書' | grep -F '主の作業' >/dev/null || { echo "no 11/12 in $f"; return 1; }
    grep -F '2026-11-13' "$f" | grep -F '推奨' | grep -F '順' >/dev/null || { echo "no 11/13 in $f"; return 1; }
  done
}

@test "epic step 8 (#1653): no lean-to-escalate wording and escalation needs a reason with evidence" {
  s="$(step8)"
  [ -n "$s" ]
  run grep -E '迷うときは主に上げる|迷えば主に上げる' <<<"$s"
  [ "$status" -eq 1 ]
  printf '%s\n' "$s" | grep -F '主に上げるのは' | grep -F '根拠' | grep -qF '示せなければ通す'
  # 照らし直しより先に委任で送るかを確かめる
  printf '%s\n' "$s" | grep -F '主に上げる前に、まず下の **主の委任** の段落の「委任で送る」に当たるかを確かめ' >/dev/null
}

@test "merge criteria (#1653): owner-info condition accepts the no-point check only with a delegation" {
  row="$(grep -F '| 主の側の情報が要らない |' "$MERGE")"
  printf '%s\n' "$row" | grep -F '`主の委任: 論点なしの止まり`' | grep -F '`論点なし — `' | grep -qF '`論点なしの確認: 通す`'
  printf '%s\n' "$row" | grep -F '委任が無いとき' | grep -qF '論点なしの確認の記録だけでは'
}

@test "merge criteria (#1653): marking by delegation checks the delegation and the timing, links the record and leaves merging to the workflow" {
  p="$(para '委任で印を付ける' "$MERGE")"
  [ -n "$p" ]
  for token in '委任が有効か' '子の最後の発言の時刻' '委任の確認' '`論点なしの確認: 通す`' '可の条件' '`主の委任: <委任の記録の URL>`' '`parent-merge-approved`' '`needs-approval` が無くても' '承認もマージもさせず' 'マージの完了を待たせる'; do
    printf '%s\n' "$p" | grep -qF -- "$token" || { echo "missing: $token"; return 1; }
  done
}

@test "merge criteria (#1653): keeps escalate-when-unsure but no longer claims to match the pass criteria" {
  grep -qF '**迷ったとき**' "$MERGE"
  run grep -F '「迷ったら主に上げる」は、止まった子を通す基準 `parent-pass-criteria.md` とそろえてある' "$MERGE"
  [ "$status" -eq 1 ]
  grep -F '迷ったら主に上げる' "$MERGE" | grep -qF 'この基準にだけ置く'
}

# --- グループ 4: 委任の範囲・判例・報告 ---

# 「主の委任」の箇条（`- **<名前>**` で始まる行）を 1 行だけ出す
item() { grep -F -- "- **$1**" "$2"; }

@test "epic delegation (#1653): the no-point delegation record has five fixed lines and a basis line" {
  grep -qxF '  主の委任: 論点なしの止まり' "$EPIC"
  grep -qF '  範囲: このエピックの子の止まりのうち、子の停止の記録の `主に聞く理由:` が論点なしと書き、推奨と根拠があるリスク許容・聖域の変更・破壊的な git 操作と、同じ HEAD の論点なしの確認で通ったマージ待ち。論点ありの止まり・不許容・実機操作は含まない' "$EPIC"
  grep -E '^  根拠: 主の決定' "$EPIC" | grep -qF 'https://github.com/genetta-inc/flatmate/issues/1796#issuecomment-6551902839'
  item '委任の受け方' "$EPIC" | grep -F '`主の委任: 論点なしの止まり` は 1〜5 行目' >/dev/null
  item '委任の受け方' "$EPIC" | grep -F '読めないときは' | grep -qF '狭い側の `主の委任: リスク許容`'
  item '委任が有効か' "$EPIC" | grep -qF '`主の委任: 論点なしの止まり` なら 1〜5 行目が定型の文ちょうど'
}

@test "epic delegation (#1653): an interleaved owner message alone does not force re-asking" {
  r="$(item '委任の受け方' "$EPIC")"
  printf '%s\n' "$r" | grep -qF '任せる意思が読める最初の発言を委任の確認とし'
  printf '%s\n' "$r" | grep -qF '挟まっただけでは問い直さない'
  printf '%s\n' "$r" | grep -F '取り消すか範囲を変える内容なら' | grep -qF '出し直す'
  run grep -F '挟まずに打つ' <<<"$r"; [ "$status" -eq 1 ]
}

@test "epic delegation (#1653): which delegation applies to which stop" {
  r="$(item '委任が効く止まり' "$EPIC")"
  printf '%s\n' "$r" | grep -qF '**リスク許容の止まり**（委任の種類が `リスク許容` でも `論点なしの止まり` でも効く）'
  printf '%s\n' "$r" | grep -qF '⑤②の宣言が `論点なし — ` の行を持ち'
  printf '%s\n' "$r" | grep -qF '**聖域の変更・破壊的な git 操作の止まり**（委任の種類が `論点なしの止まり` のときだけ効く）'
  printf '%s\n' "$r" | grep -qF '**マージ待ち**（委任の種類が `論点なしの止まり` のときだけ効く）'
  printf '%s\n' "$r" | grep -F '**マージ待ち**' | grep -F '`論点なしの確認: 通す`' | grep -qF '**委任で印を付ける**'
  printf '%s\n' "$r" | grep -qF '**実機操作の止まり**: どの種類の委任も効かない'
  printf '%s\n' "$r" | grep -F '論点ありの止まり' | grep -qF 'どちらの種類の委任も効かない'
  printf '%s\n' "$r" | grep -qF '`needs-approval` か必要な宣言の無いリスク許容の止まり'
}

@test "epic delegation (#1653): sending by delegation has a proceed reply and records the delegation URL" {
  r="$(item '委任で送る' "$EPIC")"
  printf '%s\n' "$r" | grep -F '`進める（主の委任による。停止の記録: <URL>）: <変更するファイルかコマンドの全文>。実行の時機: <いつ>' | grep -qF 'タイミングと方法まで'
  printf '%s\n' "$r" | grep -qF '`委任で送った: 子 #<N> <停止の記録の URL> 委任の記録: <委任の記録の URL>`'
  item '委任が効く止まり' "$EPIC" | grep -qF '`委任で送った: 子 #<N> <最後の発言の uuid> 委任の記録: <委任の記録の URL>`'
}

@test "gate pass (#1653): the delegation checks match epic.md word for word" {
  PASSMD="$PLUGIN_DIR/skills/pr-review-gate/stages/pass.md"
  risk="$(item '委任が効く止まり' "$EPIC" | grep -oE '\*\*リスク許容の止まり\*\*.*論点なしと書く。\*\*聖域' | sed 's/。\*\*聖域$//')"
  [ -n "$risk" ]
  grep -qF -- "$risk" "$PASSMD"
  grep -qF -- "$risk" "$CHILD"
  grep -qF '`主の委任: 論点なしの止まり` なら 1〜5 行目が定型の文ちょうど' "$PASSMD"
}

@test "child stop (#1653): sanctuary and destructive git approvals leave a stop record with fixed heads" {
  r="$(item '記録を残す止まり' "$CHILD")"
  printf '%s\n' "$r" | grep -qF '聖域の変更の承認・破壊的な git 操作の承認を待って止まるとき'
  printf '%s\n' "$r" | grep -qF '`止まった理由:` を `聖域の変更の承認: <変更するファイルと中身>` で'
  printf '%s\n' "$r" | grep -qF '`止まった理由:` を `破壊的な git 操作の承認: <コマンドの全文>` で始め'
  printf '%s\n' "$r" | grep -qF '`推奨:` を `進める` で始める'
}

@test "child stop (#1653): a delegated proceed reply runs only the recorded operation and leaves a record" {
  r="$(item '親から届いた返事' "$CHILD")"
  printf '%s\n' "$r" | grep -qF '停止の記録に書いた操作（変更するファイルかコマンドの全文）だけを返事の `実行の時機:` に自分で行い'
  printf '%s\n' "$r" | grep -qF '`委任で進めた: <操作> 委任の記録: <URL> 停止の記録: <URL> 親セッション <ID> / 委任の確認 uuid <uuid>`'
  printf '%s\n' "$r" | grep -qF 'hook が確認画面か拒否で止めたら、打ち直さず'
  printf '%s\n' "$r" | grep -F 'マージ待ちの子は' | grep -qF '承認もマージもせず'
}

@test "merge criteria (#1653): marking by delegation does not apply to points or risk-tolerance delegations" {
  p="$(para '委任で印を付ける' "$MERGE")"
  printf '%s\n' "$p" | grep -F '論点ありの宣言' | grep -qF '`リスク許容` の委任には、この手順は効かない'
}

@test "pass criteria (#1653): sessions without a delegation still never pass sanctuary, destructive git or merge" {
  p="$(para '委任との関係' "$PASS")"
  printf '%s\n' "$p" | grep -F '委任の無いセッション' | grep -F '聖域の変更・破壊的な git 操作・マージ' | grep -qF '通さない'
}

@test "epic (#1653): precedent trigger in step 8 and the passed-by-parent report section" {
  step8 | grep -F '主の聞き返し' | grep -F '`.claude/casting/precedents.md` に 1 判例を追記' | grep -qF '判例の書き方'
  p="$(para '親の判断で通した PR・止まり' "$EPIC")"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -F '`親の判断: 子 #N 通した`' | grep -F '`委任で送った:`' | grep -qF '1 件 1 行'
  printf '%s\n' "$p" | grep -F '設計の分かれ目' | grep -qF '他の案'
  printf '%s\n' "$p" | grep -qF '`論点なしの確認: 通す` の記録はこの節に載せない'
  printf '%s\n' "$p" | grep -qF '0 件なら節ごと書かない'
}

@test "merge criteria (#1653): the no-point check record counts only when posted by OWNER, MEMBER or COLLABORATOR" {
  row="$(grep -F '| 主の側の情報が要らない |' "$MERGE")"
  printf '%s\n' "$row" | grep -F '`論点なしの確認: 通す`' | grep -F '`author_association`' | grep -qF '`OWNER`・`MEMBER`・`COLLABORATOR`'
}
