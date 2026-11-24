#!/usr/bin/env bats
# 本体用の一回限りのタイマーを、実時間を待たずに正本から実行する。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REF="$PLUGIN_DIR/skills/develop/references/child-background-wait.md"
  KEEPALIVE="$PLUGIN_DIR/skills/develop/references/epic-keepalive.md"
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

@test "maintenance stops re-arming 12 hours after the first timer without dropping work" {
  local first="$BATS_TEST_TMPDIR/first" rearm="$BATS_TEST_TMPDIR/rearm"
  sed -n '/^## 2\./,/^## 3\./p' "$REF" > "$first"
  sed -n '/^## 3\./,/^## 既存契約/p' "$REF" > "$rearm"
  local term
  # 初回のタイマーを置いた時刻を基点として保持し、再設置で更新しない。
  for term in '最初のタイマーを置いた時刻' '基点' '再設置で基点を更新しない'; do
    grep -qF "$term" "$first" || { echo "missing in 2: $term"; return 1; }
  done
  # 再設置は初回から 12 時間未満に限り、到達・超過では置かず元作業を保持する。
  for term in '最初のタイマーを置いた時刻から 12 時間未満' '12 時間に達した通知' \
    '12 時間を超えた通知' '次のタイマーを置かない' '元作業と実行 ID を保持' \
    '完了通知を待ち続ける' '一度の書き直しを受け入れる' \
    '上限到達を理由に元作業を止めたり捨てたりしない' '維持タイマーも再開しない'; do
    grep -qF "$term" "$rearm" || { echo "missing in 3: $term"; return 1; }
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
    'https://github.com/oratta/claude-harness/issues/1743#issuecomment-7089486648' \
    '外部依存' '45 分' '5m / unknown' '二回の cache-read' '24 時間' '12 時間' \
    '約 $1.32' '$1.60' '約 $2.52' '旧方針' '上限後' \
    '新規入力・出力' '未実施' '60 分超' 'cache_read_input_tokens'; do
    grep -qF "$term" "$record" || { echo "missing: $term"; return 1; }
  done
}

@test "reference cost note links the 12 hour comparison and keeps the old figure separate" {
  local term
  for term in 'https://github.com/oratta/claude-harness/issues/1743#issuecomment-7089486648' \
    '12 時間' '約 $1.32' '$1.60' '約 $2.52' '旧方針' '上限後' '総費用の保証ではない'; do
    grep -qF "$term" "$REF" || { echo "missing: $term"; return 1; }
  done
}

@test "keepalive canonical source selects both definitions and preserves stopped reception" {
  local term
  for term in '停止前' '作業待ちの開始前・延長前' 'トップレベル' '`background`' \
    '`separator`' '`reply_prefix`' '`fields`' '`request_template`' \
    '固定文と完全一致する入力' '通常の主の返事や親の判断より先に' \
    '受信ターンではツールを呼ばない' '定義の読み直しも含む' \
    '会話だけから各欄の短い値' '一行だけ返す' '値に改行や区切り文字を入れない' \
    '元の質問・停止状態・停止記録を保って' 'epic-child-stop.md' \
    'child-background-wait.md' '送信元の識別はしない' '型どおり'; do
    grep -qF "$term" "$KEEPALIVE" || { echo "missing canonical contract: $term"; return 1; }
  done
  # 生成規則と固定文の本文は作業待ち側へ複製しない。
  run grep -qE 'request_template|reply_prefix|キャッシュ維持のための声かけです' "$REF"
  [ "$status" -eq 1 ]
}

@test "background wait preloads reception and classifies reserved input before cancellation" {
  python3 - "$REF" <<'PYTEST'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
preload = s.split('## 入力判定の守備範囲')[0]
assert '開始前または延長前' in preload
assert '[epic-keepalive.md](epic-keepalive.md)' in preload
assert 'child-cache-keepalive.json' in preload and '`background`' in preload
assert 'Read' in preload
branch = s.split('## 3. 通知を照合して待ち直す・取り消す')[1]
reserved = branch.index('固定文と完全一致する入力')
cancel = branch.index('入力により待ち直す場合も既存タイマーを止めて')
assert reserved < cancel
assert '通常入力の取消・再判定より先に' in branch
assert '完全一致しない入力' in branch and '既存手順' in branch
PYTEST
}

@test "background keepalive ends the turn without changing work or the timer" {
  local doc term
  for doc in "$KEEPALIVE" "$REF"; do
    for term in '一行だけ返してターンを終え' '元作業 ID・実行 ID・自己タイマーとその ID・初回設置時刻' \
      '取消・再設置' '12 時間' '作業完了や自己通知成功と扱わない'; do
      grep -qF "$term" "$doc" || { echo "missing in $doc: $term"; return 1; }
    done
  done
  grep -qF 'ツール（定義の再読・タイマーの取消・再設置を含む）' "$KEEPALIVE" || return 1
  grep -qF '調査・新しい作業・印や停止記録の変更・投稿を行わない' "$KEEPALIVE" || return 1
  grep -qF '受信ターンでツールを呼ばず' "$REF" || return 1
}

@test "orca external wake is chosen from the own record and has no self timer" {
  local ext="$BATS_TEST_TMPDIR/ext" term
  sed -n '/^## 外部起こしを選べるかを確かめる/,/^## 2\./p' "$REF" > "$ext"
  [ -s "$ext" ]
  # 経路は準備ターンごとに記録で選び、nested だけで Orca としない。受信ターンでは切り替えない。
  for term in '待ちを準備する通常ターン' '予約文の受信ターンでは経路を切り替えない' \
    'nested であることだけで Orca と判定しない' '`launcher` が `orca`' '`launch_failed` が空' '`status` が `running`' '`stop` が `stopped` / `stopped-seen` でない' \
    '`turn_input.sender`' '`parent` または `startup`' '送り手を確かめられないときは外部起こしを選ばない' \
    '自己タイマーは 0 個' '自分のものだけを取り消し' '取消が失敗・不明なら作業待ちの行を出さず' \
    '維持専用のタイマーや監視を重ねず' 'キャッシュ維持を保証したと報告しない'; do
    grep -qF "$term" "$ext" || { echo "missing: $term"; return 1; }
  done
  # 作業待ちの行は状態行の直前に置く形で示し、Stop フックの書式と合う。
  python3 - "$ext" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
block = s.split('```text\n')[1].split('```')[0].splitlines()
assert block[0].startswith('作業待ち: <待ち ID> '), block
assert block[1].startswith('状態: 作業報告 — '), block
assert '[A-Za-z0-9][A-Za-z0-9._:-]*' in s
PY
  # 2 のタイマーは外部起こしでは置かない。
  sed -n '/^## 2\./,/^## 3\./p' "$REF" | grep -qF '外部起こしを選んだ待ちには、この節のタイマーを置かない'
}

@test "owner input returns to self notification without moving the 12 hour base" {
  local ext="$BATS_TEST_TMPDIR/ext" term
  sed -n '/^## 外部起こしを選べるかを確かめる/,/^## 2\./p' "$REF" > "$ext"
  for term in '送り手が `owner`' '外部起こしを選ばず、作業待ちの行を出さない' \
    '自己タイマー 0 個を引きずらず' 'TTL 1h・最後の成功リクエストから 3600 秒未満・45 分以内の返りが無い' \
    '自己通知を一つ置く' '待ちの組と初回開始は捨てず' '切替時刻からやり直さない' \
    '次に `parent` か `startup` の通常入力' '待ちの組と初回開始を保ったまま' \
    '最も早く始めた未回収の作業を待ち続けるあいだは同じ待ちの組' \
    '待ち ID と初回開始を取り直さない' '全結果を回収したあとの別の作業だけ' \
    '上限到達で元作業を止めない'; do
    grep -qF "$term" "$ext" || { echo "missing: $term"; return 1; }
  done
}

@test "tmux and workers keep the existing wait contract without the external marker" {
  local ext="$BATS_TEST_TMPDIR/ext" term
  sed -n '/^## 外部起こしを選べるかを確かめる/,/^## 2\./p' "$REF" > "$ext"
  for term in 'tmux・登録を確かめられない本体・送り手が owner' '自己通知の契約を保ち、作業待ちの行を出さない' \
    'tmux の初回タイマーの基点も変えない' '委譲 worker は本体用タイマーを起動せず'; do
    grep -qF "$term" "$ext" || { echo "missing: $term"; return 1; }
  done
}
