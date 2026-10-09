#!/usr/bin/env bats
#
# statusline-prompt-cache:
#   statusline.sh の 2 行目に出すプロンプトキャッシュの区画（Cache <N>% と miss:<原因>）の契約。
#   仕様: openspec/changes/statusline-prompt-cache-segment/specs/

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home" FLATMATE_RATE_SHARE_CONF="$WORK/no-share-conf"
  unset FLATMATE_RATE_SHARE_DIR
  mkdir -p "$HOME"
  export CLAUDE_CONFIG_DIR="$WORK"
  export STATUSLINE_API_PACE=0
  export STATUSLINE_CODEX=0
  unset CLAUDE_ACCOUNTS_FILE
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR
  unset STATUSLINE_PROMPT_CACHE
}

teardown() {
  rm -rf "$WORK"
}

strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

# $1=prompt_cache の JSON 値（空なら prompt_cache を入れない） $2=context を入れるか（既定 1）
# session_id と rate_limits は入れない（描画ごとに変わる値を避ける）
mk() {
  local pc="$1" ctx="${2:-1}" j
  j="{\"workspace\":{\"current_dir\":\"$WORK\"},\"model\":{\"display_name\":\"Opus 5\"}"
  if [ "$ctx" = 1 ]; then
    j="$j,\"context_window\":{\"remaining_percentage\":91}"
  fi
  if [ -n "$pc" ]; then
    j="$j,\"prompt_cache\":$pc"
  fi
  printf '%s}' "$j"
}

# $1=prompt_cache の JSON 値 → ANSI を除いた 2 行目
line2() {
  mk "$1" | bash "$SL" | strip_ansi | sed -n 2p
}

# $1=prompt_cache の JSON 値 → 標準出力（色つきのまま）
out() {
  mk "$1" | bash "$SL"
}

# ヒット率 0.82 + 与えた last_miss_cause
withcause() {
  line2 "{\"hit_ratio\":0.82,\"last_miss_cause\":$1}"
}

@test "cache: hit_ratio 0.82 shows Cache 82%" {  # 0.82 は 82% と出る
  [[ "$(line2 '{"hit_ratio":0.82}')" == *"Cache 82%"* ]] || return 1
}

@test "cache: rounds to an integer" {  # 四捨五入して整数で出す
  [[ "$(line2 '{"hit_ratio":0.826}')" == *"Cache 83%"* ]] || return 1
  [[ "$(line2 '{"hit_ratio":0.824}')" == *"Cache 82%"* ]] || return 1
  [[ "$(line2 '{"hit_ratio":0.996}')" == *"Cache 100%"* ]] || return 1
  [[ "$(line2 '{"hit_ratio":0.004}')" == *"Cache 0%"* ]] || return 1
}

@test "cache: 0 and 1 are shown" {  # 0 と 1 も出す
  [[ "$(line2 '{"hit_ratio":0}')" == *"Cache 0%"* ]] || return 1
  [[ "$(line2 '{"hit_ratio":1}')" == *"Cache 100%"* ]] || return 1
}

@test "cache: sits between Context and Session" {  # Context と Session のあいだに並ぶ
  l="$(printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"cost":{"total_cost_usd":1.5},"prompt_cache":{"hit_ratio":0.82}}' "$WORK" \
    | STATUSLINE_CURRENCY=USD STATUSLINE_API_PACE=0 STATUSLINE_SESSION_COST=1 bash "$SL" | strip_ansi | sed -n 2p)"
  [ "$l" = 'Context 91%  │  Cache 82%  │  Session $1.50' ]
}

@test "cache: sits before the API segment" {  # API の区画より前に並ぶ
  echo 'API ¥180,000/mo' > "$WORK/.statusline-api-pace"
  l="$(mk '{"hit_ratio":0.82}' | STATUSLINE_API_PACE=1 bash "$SL" | strip_ansi | sed -n 2p)"
  [ "$l" = 'Context 91%  │  Cache 82%  │  API ¥180,000/mo' ]
}

@test "cache: comes first when Context is absent" {  # Context が無ければ先頭に出る
  l="$(mk '{"hit_ratio":0.82}' 0 | bash "$SL" | strip_ansi | sed -n 2p)"
  [[ "$l" == "Cache 82%"* ]] || return 1
}

@test "cache: color does not depend on the value" {  # 値が違っても色は同じ
  a="$(out '{"hit_ratio":0.05}' | sed -n 2p | sed 's/Cache 5%/Cache N%/')"
  b="$(out '{"hit_ratio":0.95}' | sed -n 2p | sed 's/Cache 95%/Cache N%/')"
  [[ "$a" == *"Cache N%"* ]] || return 1
  [ "$a" = "$b" ]
}

@test "cache: no prompt_cache means no segment" {  # prompt_cache が無ければ区画が出ない
  mk '' | STATUSLINE_API_PACE=0 bash "$SL" | strip_ansi > "$WORK/o.txt"
  [ "$(sed 1d "$WORK/o.txt")" = 'Context 91%' ]
  [ "$(wc -l < "$WORK/o.txt" | tr -d ' ')" = 2 ]
  ! mk '' | bash "$SL" | tail -n +2 | grep -q 'Cache' || return 1
}

@test "cache: null hit_ratio gives byte-identical output to no prompt_cache" {  # hit_ratio が null なら従来と完全一致
  out '' > "$WORK/a.bin"
  out '{"hit_ratio":null,"last_miss_cause":{"causes":["tools_changed"]}}' > "$WORK/b.bin"
  cmp "$WORK/a.bin" "$WORK/b.bin"
}

@test "cache: malformed prompt_cache gives byte-identical output, empty stderr, exit 0" {  # 壊れた形でも従来と完全一致
  out '' > "$WORK/base.bin"
  for pc in '"str"' '{"hit_ratio":"0.82"}' '{"hit_ratio":1.5}' '{"hit_ratio":-0.1}' '{"last_miss_cause":{"causes":["tools_changed"]}}' '[1]' '{"hit_ratio":true}'; do
    status=0
    mk "$pc" | bash "$SL" > "$WORK/o.txt" 2> "$WORK/e.txt" || status=$?
    [ "$status" -eq 0 ]
    [ ! -s "$WORK/e.txt" ]
    cmp "$WORK/o.txt" "$WORK/base.bin"
  done
}

@test "cause: mapped names are shortened" {  # 対応表の原因は短い名前で出る
  [[ "$(withcause '{"causes":["tools_changed"]}')" == *"Cache 82% miss:tools"* ]] || return 1
  [[ "$(withcause '{"causes":["system_prompt_changed"]}')" == *"Cache 82% miss:system"* ]] || return 1
  [[ "$(withcause '{"causes":["ttl_expired_5m"]}')" == *"Cache 82% miss:ttl5m"* ]] || return 1
  [[ "$(withcause '{"causes":["likely_server_side"]}')" == *"Cache 82% miss:server"* ]] || return 1
}

@test "cause: several causes show the first and the remaining count" {  # 複数なら先頭と残りの件数
  l="$(withcause '{"causes":["tools_changed","system_prompt_changed"]}')"
  [[ "$l" == *"miss:tools+1"* ]] || return 1
  [[ "$l" != *"system"* ]] || return 1
  l="$(withcause '{"causes":["a","b","c","d","e","f","g","h","i","j","k","l","m"]}')"
  [[ "$l" == *"miss:a+12"* ]] || return 1
  [[ "$(withcause '{"causes":["tools_changed",3]}')" == *"miss:tools+1"* ]] || return 1
}

@test "cause: unmapped names pass through and are cut at 16 chars" {  # 対応表に無い原因は 16 文字で切る
  l="$(withcause '{"causes":["model_changed"]}')"
  [[ "$l" == *"miss:model_changed"* ]] || return 1
  l="$(withcause '{"causes":["some_future_cause_name_x"]}')"
  [[ "$l" == *"miss:some_future_caus"* ]] || return 1
  [[ "$l" != *"some_future_cause"* ]] || return 1
}

@test "cause: null and a missing key are identical and show no cause" {  # null もキー無しも原因を出さず同じ出力
  a="$(mk '{"hit_ratio":0.82,"last_miss_cause":null}' | bash "$SL")"
  b="$(mk '{"hit_ratio":0.82}' | bash "$SL")"
  [ "$a" = "$b" ]
  l="$(printf '%s\n' "$a" | strip_ansi | sed -n 2p)"
  [[ "$l" == *"Cache 82%"* ]] || return 1
  [[ "$l" != *"miss:"* ]] || return 1
}

@test "cause: broken shapes keep the hit ratio and drop the cause" {  # 原因の形が壊れていればヒット率だけ
  for lmc in '"str"' '{"causes":[]}' '{"causes":"tools_changed"}' '{"causes":7}' '{"causes":[3]}' \
             '{"causes":["a\u001bb"]}' '{"causes":["a b"]}' '{"causes":[""]}' '{"causes":null}' \
             '{"causes":["a\n"]}' '{"causes":["tools_changed\n","x"]}' '[1]'; do
    status=0
    mk "{\"hit_ratio\":0.82,\"last_miss_cause\":$lmc}" | bash "$SL" > "$WORK/o.txt" 2> "$WORK/e.txt" || status=$?
    [ "$status" -eq 0 ]
    [ ! -s "$WORK/e.txt" ]
    l="$(strip_ansi < "$WORK/o.txt" | sed -n 2p)"
    [[ "$l" == *"Cache 82%"* ]] || return 1
    [[ "$l" != *"miss:"* ]] || return 1
  done
}

@test "cause: accompanying numbers are not shown" {  # 付随する数値は出さない
  l="$(withcause '{"causes":["tools_changed"],"tools_added":7,"tools_removed":9}')"
  seg="$(printf '%s' "$l" | awk -F'│' '{for (i = 1; i <= NF; i++) if ($i ~ /Cache/) { gsub(/^[ \t]+|[ \t]+$/, "", $i); print $i } }')"
  [ "$seg" = "Cache 82% miss:tools" ]
}

@test "config: STATUSLINE_PROMPT_CACHE=0 hides the segment" {  # =0 で区画が消える
  out '' > "$WORK/a.bin"
  mk '{"hit_ratio":0.82,"last_miss_cause":{"causes":["tools_changed"]}}' | STATUSLINE_PROMPT_CACHE=0 bash "$SL" > "$WORK/b.bin"
  cmp "$WORK/a.bin" "$WORK/b.bin"
}

@test "config: unset STATUSLINE_PROMPT_CACHE shows the segment" {  # 未設定なら区画が出る
  [[ "$(line2 '{"hit_ratio":0.82}')" == *"Cache 82%"* ]] || return 1
}

@test "config: values other than 0 show the segment" {  # 0 以外の値なら区画が出る
  for v in 1 2 off; do
    l="$(mk '{"hit_ratio":0.82}' | STATUSLINE_PROMPT_CACHE="$v" bash "$SL" | strip_ansi | sed -n 2p)"
    [[ "$l" == *"Cache 82%"* ]] || return 1
  done
}

@test "config: the variable is documented in README and the script header" {  # README と冒頭コメントに載っている
  grep -q '^| `STATUSLINE_PROMPT_CACHE` |' "${PLUGIN_DIR}/README.md"
  head -n 40 "$SL" | grep -q 'STATUSLINE_PROMPT_CACHE'
}

@test "cache: rendering the segment does not create extra files" {  # 書かれるファイルが増えない
  mkdir -p "$WORK/a/home" "$WORK/b/home"
  mk '' | HOME="$WORK/a/home" CLAUDE_CONFIG_DIR="$WORK/a" bash "$SL" > /dev/null
  mk '{"hit_ratio":0.82,"last_miss_cause":{"causes":["tools_changed"]}}' | HOME="$WORK/b/home" CLAUDE_CONFIG_DIR="$WORK/b" bash "$SL" > /dev/null
  fa="$(cd "$WORK/a" && find . -type f | sort)"
  fb="$(cd "$WORK/b" && find . -type f | sort)"
  [ "$fa" = "$fb" ]
}
