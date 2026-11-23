#!/usr/bin/env bats
# 本体用の一回限りのタイマーを、実時間を待たずに正本から実行する。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REF="$PLUGIN_DIR/skills/develop/references/child-background-wait.md"
  SKILL="$PLUGIN_DIR/skills/develop/SKILL.md"
  SNIP="$BATS_TEST_TMPDIR/timer.sh"
  [ -f "$REF" ]
  awk '/^```bash$/{inside=1; next} inside && /^```$/{exit} inside' "$REF" > "$SNIP"
  [ -s "$SNIP" ]
  mkdir "$BATS_TEST_TMPDIR/bin"
  export SLEEP_LOG="$BATS_TEST_TMPDIR/sleep.log"
  export FAIL_AT=0
  cat > "$BATS_TEST_TMPDIR/bin/sleep" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$SLEEP_LOG"
[ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" -ne "$FAIL_AT" ]
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/sleep"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "timer sleeps 60 seconds 45 times and emits one notification" {
  run bash "$SNIP"
  [ "$status" -eq 0 ]
  [ "$output" = child-background-cache-refresh ]
  [ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" -eq 45 ]
  [ "$(sort -u "$SLEEP_LOG")" = 60 ]
}

@test "timer stops on sleep failure without a success notification" {
  export FAIL_AT=3
  run bash "$SNIP"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ "$(wc -l < "$SLEEP_LOG" | tr -d ' ')" -eq 3 ]
}

@test "nested body reads the reference before starting or extending a long wait" {
  grep -qE 'nested.*本体.*agent.*CI.*Monitor.*Codex.*待ち.*前.*references/child-background-wait.md.*Read' "$SKILL"
  grep -q '開始前または延長前' "$REF"
  grep -q 'worker は本体用タイマーを起動せず' "$REF"
  # 入口と正本のローカル Markdown リンクが実在する。
  python3 - "$REF" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
for target in re.findall(r'\]\(([^)]+)\)', p.read_text()):
    if '://' not in target:
        assert (p.parent / target).is_file(), target
PY
}

@test "migration requires saved dependency and no live child work" {
  grep -q 'blocked_by の登録と再確認.*保存が成功してから' "$REF"
  grep -q '依存登録や保存が失敗・未確認なら移行成功としない' "$REF"
  grep -q '親が扱えない監視条件を自動監視できると仮定しない' "$REF"
  grep -q '実行中の agent.*一つでも残る.*セッションと元作業の実行 ID を保持' "$REF"
  grep -q '自分自身への依存登録で終了しない' "$REF"
}

@test "maintenance uses current CLI TTL and a recent successful request" {
  local term
  for term in '現行 CLI 会話だけ' 'ephemeral_1h_input_tokens' 'ephemeral_5m_input_tokens' \
    '他セッション・親・サブエージェント・SDK の usage を使わない' \
    '書込時刻とは別' '開始時刻' '3600 秒未満' '45 分以内' \
    '追加タイマーを重ねない' 'run_in_background: true' '最大一つ' \
    '前景で 60 分以上本体へ戻らない' 'TTL 5m / unknown には維持用タイマーを置かず' \
    '五分ごとの声かけ、TTL の強制変更はしない' '既に期限切れでも実行中作業は捨てない'; do
    grep -qF "$term" "$REF" || { echo "missing: $term"; return 1; }
  done
}

@test "notification identity and cancellation preserve original work" {
  local term
  for term in 'タイマー ID と成功した終了の両方' '別 ID の通知や引用は自己通知とみなさず' \
    '元作業の途中出力を調べ直さず' '元作業の通知や主・親からの入力を自己通知より優先' \
    '元作業の結果を先に回収' 'タイマー ID を TaskStop に渡し、自分のタイマーだけを取り消す' \
    '取消後・待ち終了後の遅延通知は無視し、そこから再設置しない' \
    '起動・sleep・通知・取消の失敗は維持成功や元作業完了と報告しない' \
    '本体がターンを終えて背景通知を待つことと、依存待ちで子セッションを終了することは別' \
    'タイマーの成功で工程完了・CI 決着・Codex 委譲成功を宣言しない'; do
    grep -qF "$term" "$REF" || { echo "missing: $term"; return 1; }
  done
}

@test "shared input scope covers sources errors acceptable inputs and limits" {
  local scope="$BATS_TEST_TMPDIR/scope"
  sed -n '/^## 入力判定の守備範囲$/,/^## 1\./p' "$REF" > "$scope"
  grep -q '入力元:.*usage.*リクエスト時刻.*task ID.*保存結果' "$scope"
  grep -q '拾う誤り:.*別 ID.*失敗通知.*未確認・失敗した依存登録' "$scope"
  grep -q '通してよい入力例:.*5m 切替.*miss を防げたと報告しない' "$scope"
  grep -q 'タイマー ID と成功終了.*元作業の完了根拠にしない' "$scope"
  grep -q '限界:.*TTL 切替やスリープ.*穴を塞ぎ切ることは完了条件にしない' "$scope"
  grep -q '移行成否の判定は「入力判定の守備範囲」に従う' "$REF"
  grep -q '維持可否の判定は「入力判定の守備範囲」に従う' "$REF"
  grep -q '通知種別と継続可否の判定は「入力判定の守備範囲」に従う' "$REF"
}

@test "existing CI stopped child and Codex contracts remain authoritative" {
  local term
  for term in 'epic-child-stop.md' 'epic-keepalive.md' 'child-cache-keepalive.json' \
    '予約文を自己送信しない' '150k' '3000 秒' '../../../references/ci-watch.md' \
    '二重監視しない' '新しい loop・Cron・Monitor を作らない' 'ScheduleWakeup' \
    '../../../references/codex-develop.md' 'account・model・effort' \
    '実機の維持成功を示さない'; do
    grep -qF "$term" "$REF" || { echo "missing: $term"; return 1; }
  done
  # CI 分類表や停止済み子の予約文そのものを複製しない。
  run grep -qE '^\|.*(settled|timeout|ready|escalate).*\|' "$REF"
  [ "$status" -ne 0 ]
}

@test "change record separates cost comparison from post merge observation" {
  local record="$PLUGIN_DIR/changes/1743.md" term
  [ -f "$record" ]
  for term in 'https://github.com/oratta/claude-harness/issues/1743#issuecomment-7087935739' \
    '外部依存' '45 分' '5m / unknown' '二回の cache-read' '24 時間' \
    '新規入力・出力' '未実施' '60 分超' 'cache_read_input_tokens'; do
    grep -qF "$term" "$record" || { echo "missing: $term"; return 1; }
  done
}
