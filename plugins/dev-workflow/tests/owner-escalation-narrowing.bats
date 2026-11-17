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
