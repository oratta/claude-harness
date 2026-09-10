#!/usr/bin/env bats
#
# statusline-multi-account:
#   statusline.sh のアカウント別レートリミット描画（label 列 / active 判定 /
#   6h 鮮度ゲートの active 限定 / 非 active の経過時間と分母）
#
# spec: statusline-multi-account-usage
#       usage-account-registry（active スロットの判定規則）
#
# 既存の statusline.bats は 1 スロット時の退行ガードとして無改変で残す。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export CLAUDE_CONFIG_DIR="$WORK"
  export STATUSLINE_API_PACE=0
  ACCOUNTS="${WORK}/accounts.json"
  SNAP="${WORK}/.usage-snapshot"
  SECURE_B="${WORK}/claude-b"
  NOW="$(date +%s)"
}

teardown() {
  rm -rf "$WORK"
}

# $1=5h消化率 $2=7d消化率 $3=5h残り秒 $4=7d残り秒 → stdin JSON
mk_input() {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$WORK" "$1" "$((NOW + $3))" "$2" "$((NOW + $4))"
}

strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

write_two_slot_registry() {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
}

# 既定スロット（securestorage が null）を持たないレジストリ。
# 両アカウントとも explicit な securestorage なので、env 未設定では優先順位 1 が空振りし、
# snapshot の active へのフォールバック（優先順位 2）が観測できる。
write_no_default_registry() {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": "${WORK}/claude-a" },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
}

# $1=a の fetched_at $2=b の fetched_at $3=b の 7d リセット epoch
write_two_slot_snapshot() {
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "a", "fetched_at": $1,
  "fable_weekly_pct": 94, "fable_active": true,
  "weekly_all_pct": 82, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
  "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": $1,
           "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
           "weekly_all_pct": 82, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
           "fable_weekly_pct": 94, "fable_active": true },
    "b": { "label": "B", "securestorage": "${SECURE_B}", "fetched_at": $2,
           "five_hour_pct": 3, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 1, "weekly_resets_at": "iso", "weekly_resets_epoch": $3,
           "fable_weekly_pct": 0, "fable_active": false }
  } }
JSON
}

# ---------- 複数スロットの描画 ----------

@test "multi: two slots render four rate limit lines with labels" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [ "$(grep -c '5h' "$WORK/out.txt")" = "2" ]
  [ "$(grep -c '7d All' "$WORK/out.txt")" = "2" ]
  grep -qE '^(▸ |  )A +5h' "$WORK/out.txt"
  grep -qE '^(▸ |  )A +7d All' "$WORK/out.txt"
  grep -qE '^(▸ |  )B +5h' "$WORK/out.txt"
  grep -qE '^(▸ |  )B +7d All' "$WORK/out.txt"
}

@test "multi: a null-filled slot renders no line" {
  write_two_slot_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "a", "fetched_at": $NOW,
  "fable_weekly_pct": 94, "fable_active": true, "weekly_all_pct": 82,
  "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
  "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
  "accounts": {
    "a": { "label": "A", "securestorage": null, "fetched_at": $NOW,
           "five_hour_pct": 55, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
           "weekly_all_pct": 82, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
           "fable_weekly_pct": 94, "fable_active": true },
    "b": { "label": "B", "securestorage": "${SECURE_B}", "fetched_at": null,
           "five_hour_pct": null, "five_hour_resets_at": null, "five_hour_resets_epoch": null,
           "weekly_all_pct": null, "weekly_resets_at": null, "weekly_resets_epoch": null,
           "fable_weekly_pct": null, "fable_active": null }
  } }
JSON
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [ "$(grep -c '5h' "$WORK/out.txt")" = "1" ]
  ! grep -qE '^(▸ |  )B ' "$WORK/out.txt"
}

@test "multi: a slot with 5h but no 7d renders only the 5h line" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["accounts"]["b"]["weekly_all_pct"] = None
json.dump(d, open(p, "w"))
PY
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -qE '^(▸ |  )B +5h' "$WORK/out.txt"
  ! grep -qE '^(▸ |  )B +7d All' "$WORK/out.txt"
}

@test "multi: the active slot uses live stdin values" {
  write_two_slot_registry
  # snapshot の a は 55%、stdin のライブ値は 40%
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^(▸ |  )A +5h' "$WORK/out.txt")"
  [[ "$line" =~ 40% ]]
}

@test "multi: a non-active slot shows the age of its snapshot values" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^(▸ |  )B +7d All' "$WORK/out.txt")"
  [[ "$line" =~ 2h前 ]]
  # active 側には経過時間を出さない
  ! grep -E '^(▸ |  )A ' "$WORK/out.txt" | grep -q '前'
}

# ---------- 6h 鮮度ゲート ----------

@test "gate: a stale active slot still hides the Fable segment" {
  write_two_slot_registry
  write_two_slot_snapshot "$((NOW - 25000))" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -E '^(▸ |  )A ' "$WORK/out.txt" | grep -q 'Fable'
}

@test "gate: a stale non-active slot keeps its Fable segment" {
  write_two_slot_registry
  # b は 2 日前（6h ゲートより遥かに古い）
  write_two_slot_snapshot "$NOW" "$((NOW - 172800))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -E '^(▸ |  )B ' "$WORK/out.txt" | grep -q 'Fable'
  grep -E '^(▸ |  )B +7d All' "$WORK/out.txt" | grep -q '2d前'
}

# ---------- リセット時刻が過去のとき ----------

@test "stale window: a past resets_at drops the denominator and the remaining time" {
  write_two_slot_registry
  # b の 7d リセットは 1 日前
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW - 86400))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^(▸ |  )B +7d All' "$WORK/out.txt")"
  [[ "$line" =~ 1% ]]
  # 分母（%/%）も残り時間（~Nd Nh）も出ない
  ! [[ "$line" =~ %/ ]]
  ! [[ "$line" =~ ~ ]]
}

# ---------- active スロットの判定 ----------

@test "active: CLAUDE_SECURESTORAGE_CONFIG_DIR wins over the snapshot" {
  write_two_slot_registry
  # snapshot の active は a、env は b を指す
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$SECURE_B" bash "$SL" \
    | strip_ansi > "$WORK/out.txt"
  # b がライブ値 40% を使い、a が snapshot 値 + 経過時間になる
  [[ "$(grep -E '^(▸ |  )B +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^(▸ |  )A +5h' "$WORK/out.txt")" =~ 55% ]]
}

@test "active: an unset env still matches the default slot by service name" {
  # 優先順位 1 は env 未設定でも効く（空文字 → 既定サービス名 → 既定スロット a に一致）。
  # snapshot が別スロットを active と記録していても、こちらが勝つ。
  write_two_slot_registry
  write_two_slot_snapshot "$((NOW - 7200))" "$NOW" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["active"] = "b"
json.dump(d, open(p, "w"))
PY
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [[ "$(grep -E '^(▸ |  )A +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^(▸ |  )B +5h' "$WORK/out.txt")" =~ 3% ]]
}

@test "active: falls back to the snapshot active when the env is unset" {
  # 既定スロットが無いレジストリなら優先順位 1 が空振りし、snapshot の active が使われる
  write_no_default_registry
  write_two_slot_snapshot "$((NOW - 7200))" "$NOW" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["active"] = "b"
json.dump(d, open(p, "w"))
PY
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  [[ "$(grep -E '^(▸ |  )B +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^(▸ |  )A +5h' "$WORK/out.txt")" =~ 55% ]]
}

@test "active: an env matching no slot falls back to the snapshot active" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["active"] = "b"
json.dump(d, open(p, "w"))
PY
  mk_input 40 82 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/unknown" bash "$SL" \
    | strip_ansi > "$WORK/out.txt"
  [[ "$(grep -E '^(▸ |  )B +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^(▸ |  )A +5h' "$WORK/out.txt")" =~ 55% ]]
}

@test "active: an env matching no slot and no snapshot active uses the first slot" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.pop("active", None)
json.dump(d, open(p, "w"))
PY
  mk_input 40 82 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/unknown" bash "$SL" \
    | strip_ansi > "$WORK/out.txt"
  [[ "$(grep -E '^(▸ |  )A +5h' "$WORK/out.txt")" =~ 40% ]]
  [[ "$(grep -E '^(▸ |  )B +5h' "$WORK/out.txt")" =~ 3% ]]
}

@test "ago: a future fetched_at never renders a negative age" {
  write_two_slot_registry
  # b の fetched_at を未来にする（時計ずれの模擬）
  write_two_slot_snapshot "$NOW" "$((NOW + 600))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep -E '^(▸ |  )B +7d All' "$WORK/out.txt")"
  ! [[ "$line" =~ -[0-9]+[mhd]前 ]]
  [[ "$line" =~ 0m前 ]]
}

# ---------- 1 スロット時の退行ガード ----------

# 残り時間の表示は分単位なので、2 回の実行が分の境界を跨ぐと差が出る。
# 残り秒を 60 で割った余りが 30 になるオフセットを使い、約 30 秒の余裕を作って決定論にする。
@test "single: no registry keeps the output byte-identical to the previous version" {
  old="${WORK}/statusline-old.sh"
  git -C "$REPO_ROOT" show origin/main:plugins/statusline/scripts/statusline.sh > "$old" 2>/dev/null \
    || skip "origin/main is not available"
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14010 172830 | bash "$SL"  > "$WORK/new.txt"
  mk_input 3 25 14010 172830 | bash "$old" > "$WORK/old.txt"
  diff "$WORK/old.txt" "$WORK/new.txt"
}

@test "single: a schema 2 snapshot without a registry renders like the old one" {
  old="${WORK}/statusline-old.sh"
  git -C "$REPO_ROOT" show origin/main:plugins/statusline/scripts/statusline.sh > "$old" 2>/dev/null \
    || skip "origin/main is not available"
  cat > "$WORK/old-snap.json" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  cat > "$SNAP" <<JSON
{ "schema": 2, "active": "default", "fetched_at": $NOW,
  "fable_weekly_pct": 7, "fable_active": true,
  "accounts": { "default": { "label": "default", "securestorage": null, "fetched_at": $NOW,
    "five_hour_pct": 3, "five_hour_resets_at": "iso", "five_hour_resets_epoch": $((NOW + 14000)),
    "weekly_all_pct": 25, "weekly_resets_at": "iso", "weekly_resets_epoch": $((NOW + 172800)),
    "fable_weekly_pct": 7, "fable_active": true } } }
JSON
  mk_input 3 25 14010 172830 | bash "$SL" > "$WORK/new.txt"
  cp "$WORK/old-snap.json" "$SNAP"
  mk_input 3 25 14010 172830 | bash "$old" > "$WORK/old.txt"
  diff "$WORK/old.txt" "$WORK/new.txt"
}

@test "single: a one-slot registry renders no label column" {
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}]}' > "$ACCOUNTS"
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -qE '^5h' "$WORK/out.txt"
  ! grep -qE '^(▸ |  )A ' "$WORK/out.txt"
}

@test "single: a schema 1 snapshot still renders the Fable segment" {
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -q 'Fable' "$WORK/out.txt"
}

@test "single: no rate_limits and no snapshot renders no rate limit line" {
  write_two_slot_registry
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}}' "$WORK" \
    | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -q '5h' "$WORK/out.txt"
  ! grep -q '7d All' "$WORK/out.txt"
}

# ---------- レジストリの制御文字 ----------

@test "registry: a slot with control characters never becomes a ghost row" {
  python3 - "$ACCOUNTS" "$SECURE_B" <<'PY'
import json, sys
json.dump({"schema": 1, "accounts": [
    {"id": "a", "label": "A\n../../../../tmp/pwned", "securestorage": None},
    {"id": "b", "label": "B", "securestorage": sys.argv[2]},
]}, open(sys.argv[1], "w"))
PY
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -q 'pwned' "$WORK/out.txt"
  # 生き残った b だけの 1 スロット構成になるので label 列は出ない
  ! grep -qE '^(▸ |  )B ' "$WORK/out.txt"
  grep -qE '^5h' "$WORK/out.txt"
}

# ---------- schema 2 を書く前の snapshot（NIT） ----------

@test "multi: the active slot falls back to top-level keys on a schema 1 snapshot" {
  # probe がまだ schema 2 を書いていない間（最大 TTL 5 分）でも
  # active スロットの Fable バーが消えない
  write_two_slot_registry
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -E '^(▸ |  )A ' "$WORK/out.txt" | grep -q 'Fable'
  # 非 active スロットはトップレベルを流用しない（b の行は出ない）
  ! grep -qE '^(▸ |  )B ' "$WORK/out.txt"
}

# ---------- snapshot の読み取りが原子的であること ----------

@test "snapshot: the whole snapshot is read in a single jq call" {
  # フィールドごとに jq を起動すると、呼び出しの合間に probe が snapshot を差し替えたとき
  # 1 行の中に新旧 2 バージョンの値が混ざる。snapshot を読む jq は 1 回だけにする。
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  cat > "$WORK/jq" <<SH
#!/usr/bin/env bash
for a in "\$@"; do
  case "\$a" in *.usage-snapshot) echo x >> "$WORK/jq-snap-calls" ;; esac
done
exec "$(command -v jq)" "\$@"
SH
  chmod +x "$WORK/jq"
  : > "$WORK/jq-snap-calls"
  mk_input 40 82 14000 172800 | PATH="$WORK:$PATH" bash "$SL" > /dev/null
  count="$(wc -l < "$WORK/jq-snap-calls" | tr -d ' ')"
  [ "$count" -eq 1 ]
}

# ---------- label の表示幅（全角ラベル） ----------

@test "label: full-width labels keep the columns aligned" {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "仕事", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  # 各行の "5h" / "7d All" の開始位置（表示幅）が全スロットで揃っている
  widths="$(python3 - "$WORK/out.txt" <<'PY'
import re, sys, unicodedata
def w(s):
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in s)
cols = set()
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.search(r"(5h|7d All)", line)
    if m and not line.startswith(("5h", "7d")):
        cols.add(w(line[:m.start()]))
print(",".join(str(c) for c in sorted(cols)))
PY
)"
  [ "$(printf '%s' "$widths" | tr -cd ',' | wc -c | tr -d ' ')" = "0" ]
  [ -n "$widths" ]
}

@test "label: an over-long label is clipped instead of pushing every row out" {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "0123456789abcdefghij0123456789abcdefghij", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  line="$(grep '5h' "$WORK/out.txt" | head -1)"
  # label 列は表示幅 8 までに収まる（40 桁のパディングにならない）。
  # 先頭の 2 桁は active の目印列なので、その分を足した上限で見る。
  col="$(python3 -c "
import re,sys
line = sys.argv[1]
print(re.search(r'5h', line).start())
" "$line")"
  [ "$col" -le 12 ]
}

# ---------- 2 つのレジストリ実装のドリフト検出 ----------

@test "registry: statusline and usage-probe parse the same registry identically" {
  # 規則は spec が正本で実装は 2 本ある。片側だけがドリフトするのを止めるためのガード。
  PROBE="${REPO_ROOT}/plugins/dev-workflow/scripts/usage-probe.sh"
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "label": "NoId" },
  { "id": "bad id!", "label": "Bad" },
  { "id": "a", "label": "First", "securestorage": null },
  { "id": "a", "label": "Second", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" },
  { "id": "c", "label": "C\nghost", "securestorage": null },
  { "id": "d", "label": "D", "securestorage": "/tmp/d\tghost" },
  { "id": "e1", "label": "E1", "securestorage": "/tmp/e1" },
  { "id": "e2", "label": "E2", "securestorage": "/tmp/e2" },
  { "id": "e3", "label": "E3", "securestorage": "/tmp/e3" },
  { "id": "e4", "label": "E4", "securestorage": "/tmp/e4" },
  { "id": "e5", "label": "E5", "securestorage": "/tmp/e5" },
  { "id": "e6", "label": "E6", "securestorage": "/tmp/e6" },
  { "id": "e7", "label": "E7", "securestorage": "/tmp/e7" },
  { "id": "e8", "label": "E8", "securestorage": "/tmp/e8" }
] }
JSON
  # statusline に埋め込まれた reader を取り出して単体で走らせる
  python3 - "$SL" "$WORK/sl-reader.py" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
start = src.index("ACCOUNTS_FILE=\"$accounts_file\" python3 -c '")
body = src[src.index("\n", start) + 1:]
body = body[:body.index("\n' 2>/dev/null)")]
open(sys.argv[2], "w", encoding="utf-8").write(body)
PY
  ACCOUNTS_FILE="$ACCOUNTS" python3 "$WORK/sl-reader.py" | cut -f1,4 > "$WORK/sl.tsv"
  env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots | cut -f1,4 > "$WORK/probe.tsv"
  diff "$WORK/probe.tsv" "$WORK/sl.tsv"
  # 実際に規則が効いていることも確かめる（id 不正・重複・制御文字・8 個上限）
  [ "$(wc -l < "$WORK/sl.tsv" | tr -d ' ')" = "8" ]
  ! grep -q 'ghost' "$WORK/sl.tsv"
}

# ---------- snapshot 読み取りが stdin に依存しないこと ----------
# 実装中の実バグの回帰ガード: jq の `--args` をファイル名の前に置くと snapshot の
# パスまで positional に食われ、jq が stdin から JSON を読もうとする。statusline は
# 既に stdin を消費済みなので固まらず、代わりに snapshot 由来の値が**黙って全部空**になり、
# Fable バーと非 active スロットの行が消えていた。値が実際に届いていることを見る。

@test "snapshot: values reach the render even though stdin is already consumed" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 40 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  # active スロット: Fable は snapshot 由来（accounts.a）。読めていなければ消える
  grep -E '^(▸ |  )A ' "$WORK/out.txt" | grep -q 'Fable'
  [[ "$(grep -E '^(▸ |  )A +7d All' "$WORK/out.txt")" =~ 94% ]]
  # 非 active スロット: 5h / 7d / Fable / 経過時間のすべてが snapshot 由来
  [[ "$(grep -E '^(▸ |  )B +5h' "$WORK/out.txt")" =~ 3% ]]
  [[ "$(grep -E '^(▸ |  )B +7d All' "$WORK/out.txt")" =~ 1% ]]
  [[ "$(grep -E '^(▸ |  )B +7d All' "$WORK/out.txt")" =~ 2h前 ]]
}

@test "label: a hand-written over-long label is clipped by the statusline reader too" {
  # accounts-init.sh を通さず accounts.json を直接編集する経路のガード
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "0123456789abcdefghij0123456789abcdefghij", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  grep -qE '^(▸ |  )01234567 +5h' "$WORK/out.txt"
  ! grep -q '0123456789abcdefghij' "$WORK/out.txt"
}

# ---------- active スロットの目印 ----------
# spec: statusline-multi-account-usage「active スロットの行を視覚的に示す」

@test "marker: the active slot's rows start with the marker and the others with two spaces" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  # active = a（env 未設定 → 既定スロットにサービス名で一致）
  [ "$(grep -cE '^▸ A ' "$WORK/out.txt")" = "2" ]
  [ "$(grep -cE '^  B ' "$WORK/out.txt")" = "2" ]
}

@test "marker: survives stripping every ANSI escape" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  # 色が落ちても記号だけで active / 非 active が分かる
  grep -qE '^▸ ' "$WORK/out.txt"
  grep -qE '^  [A-Z]' "$WORK/out.txt"
}

@test "marker: the marker and the active label are not dimmed" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" > "$WORK/raw.txt"
  python3 - "$WORK/raw.txt" <<'PY'
import re, sys
DIM = "\033[2m"
lines = [l for l in open(sys.argv[1], encoding="utf-8") if "5h" in l or "7d All" in l]
plain = {re.sub(r"\033\[[0-9;]*m", "", l): l for l in lines}
active = [raw for p, raw in plain.items() if p.startswith("▸ ")]
other = [raw for p, raw in plain.items() if p.startswith("  ")]
assert active, "no active row found"
assert other, "no non-active row found"
def head_of(raw):
    """行頭から bar_seg のラベルフィールド直前までを取る。
    bar_seg は "5h" / "7d All" の直前に必ず DIM を出すので、それは剥がしてから見る。"""
    idx = raw.index("5h") if "5h" in raw else raw.index("7d All")
    head = raw[:idx]
    return head[: -len(DIM)] if head.endswith(DIM) else head

for raw in active:
    head = head_of(raw)
    assert DIM not in head, "active row head is dimmed: %r" % head
for raw in other:
    head = head_of(raw)
    assert DIM in head, "non-active row head is not dimmed: %r" % head
PY
}

@test "marker: whatever glyph is used has Neutral east asian width" {
  # リテラル照合にしない。記号を差し替えてもこの制約自体は守られる必要がある。
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  python3 - "$WORK/out.txt" <<'PY'
import sys, unicodedata
rows = [l for l in open(sys.argv[1], encoding="utf-8") if ("5h" in l or "7d All" in l)]
marked = [l for l in rows if not l.startswith("  ")]
assert marked, "no marked row found"
glyph = marked[0][0]
eaw = unicodedata.east_asian_width(glyph)
assert eaw == "N", "marker %r U+%04X has EAW=%s (must be N)" % (glyph, ord(glyph), eaw)
assert marked[0][1] == " ", "marker must be followed by a single space"
PY
}

@test "marker: follows the active slot when the env points at the other one" {
  write_two_slot_registry
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$SECURE_B" bash "$SL" \
    | strip_ansi > "$WORK/out.txt"
  [ "$(grep -cE '^▸ B ' "$WORK/out.txt")" = "2" ]
  [ "$(grep -cE '^  A ' "$WORK/out.txt")" = "2" ]
}

@test "marker: no marked row when the active slot has no values" {
  write_two_slot_registry
  # a（active）を欠測にし、b にだけ値を持たせる
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  python3 - "$SNAP" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for k in ("fetched_at", "five_hour_pct", "five_hour_resets_at", "five_hour_resets_epoch",
          "weekly_all_pct", "weekly_resets_at", "weekly_resets_epoch",
          "fable_weekly_pct", "fable_active"):
    d["accounts"]["a"][k] = None
json.dump(d, open(p, "w"))
PY
  # stdin のライブ値も渡さない（active スロットの値が無い状態）
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}}' "$WORK" \
    | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -qE '^▸ ' "$WORK/out.txt"
  [ "$(grep -cE '^  B ' "$WORK/out.txt")" = "2" ]
}

@test "marker: columns stay aligned across marked and unmarked rows" {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "仕事", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
  write_two_slot_snapshot "$NOW" "$((NOW - 7200))" "$((NOW + 172800))"
  mk_input 55 82 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  widths="$(python3 - "$WORK/out.txt" <<'PY'
import re, sys, unicodedata
def w(s):
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in s)
cols = set()
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.search(r"(5h|7d All)", line)
    if m and m.start() > 0:
        cols.add(w(line[: m.start()]))
print(",".join(str(c) for c in sorted(cols)))
PY
)"
  [ "$(printf '%s' "$widths" | tr -cd ',' | wc -c | tr -d ' ')" = "0" ]
  [ -n "$widths" ]
}

@test "marker: a single-slot registry renders no marker" {
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}]}' > "$ACCOUNTS"
  cat > "$SNAP" <<JSON
{"schema":1,"fetched_at":$NOW,"fable_weekly_pct":7,"fable_active":true}
JSON
  mk_input 3 25 14000 172800 | bash "$SL" | strip_ansi > "$WORK/out.txt"
  ! grep -qE '^▸' "$WORK/out.txt"
  grep -qE '^5h' "$WORK/out.txt"
}
