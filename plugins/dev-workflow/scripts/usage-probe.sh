#!/usr/bin/env bash
# usage-probe.sh: Anthropic OAuth usage API から各アカウントの残量を取得し snapshot に書く。
#
# 契約（正本: openspec/specs/dev-workflow-escalation-tripwires「usage-probe と snapshot 契約」
#       と openspec/specs/usage-account-registry）:
#   - 出力先 snapshot: ${USAGE_SNAPSHOT}（既定 ~/.claude/.usage-snapshot）
#   - アカウントレジストリ: ${CLAUDE_ACCOUNTS_FILE}
#       （既定 ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json）。
#     不在・不正なら既定スロット 1 つに縮退し、挙動は従来と変わらない
#   - 使用量の主な出どころはステータスラインのセッション記録で、probe は補助。スロットごとに、
#     記録が無いか $USAGE_PROBE_STALE 秒（既定 10800）より古い、または snapshot の同スロットの
#     fetched_at が同じく古い（無い場合を含む）ときだけ叩く。前回の試行から $USAGE_PROBE_INTERVAL 秒
#     （既定 10800）経っていなければ叩かず、429 が続くスロットは間隔×2^(連続回数-1)（上限 1 日）待つ。
#     試行は結果にかかわらず ${USAGE_PROBE_STATE}（既定 ~/.claude/.usage-probe-state）に記録する。
#     snapshot の mtime による TTL は使わない（全スロット失敗で mtime が進まず、叩き直し続けるため）
#   - マシン全体で 1 本: ${USAGE_PROBE_LOCK}（既定 ~/.claude/.usage-probe.lock）を mkdir で取れなければ
#     何もしない。120 秒より古いロックは前の probe の異常終了とみなして取り直す
#   - schema 2: accounts にスロットごとの値、active に現在のスロット id。
#     トップレベルの従来キーは active スロットの同名フィールドのミラー（既存の読み手用）
#   - fail-open はスロット単位。あるスロットが失敗しても前回値（fetched_at 込み）を引き継ぐ。
#     全スロットが失敗したとき、および組み立て・書き込みが失敗したときは snapshot を書かない
#
# refresh_token を使ったアクセストークンの更新は意図的に実装しない。
# リフレッシュはトークンをローテートするため、Claude Code 本体が同じ refresh_token で
# リフレッシュしたときに無効化され、そのアカウントがログアウトしうる。使用量表示のために
# 認証を壊すのは割に合わないので、非 active アカウントは前回値＋取得時刻の併記で扱う。
#
# テスト用オーバーライド（本番は未設定）:
#   - USAGE_PROBE_RESPONSE_FILE:      全スロット共通で生 API JSON をこのファイルから読む
#   - USAGE_PROBE_RESPONSE_FILE_<ID>: スロット別（id を大文字化し `-` を `_` に変換）。優先
#   - USAGE_PROBE_STATUS[_<ID>]:      テスト経路の HTTP ステータス（既定は応答ファイルがあれば 200）
#   - USAGE_PROBE_NOW:                現在 epoch を固定する（実行条件と試行時刻もこの時刻で測る）
#   いずれかが設定されていれば全スロットがテスト経路になり、Keychain / curl は使わない。
#   - USAGE_PROBE_USER_AGENT:         本番経路で送る User-Agent を固定する（テスト経路には切り替えない。
#                                     既定は claude-code/<claude --version の版>）
#
# サブコマンド:
#   --print-slots  レジストリを解決して `id<TAB>label<TAB>securestorage<TAB>service` を出力する
#
# fail-open のため set -e は使わない（フェッチ失敗で誤って落とさない）。
set -uo pipefail

SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"
STALE="${USAGE_PROBE_STALE:-10800}"
INTERVAL="${USAGE_PROBE_INTERVAL:-10800}"
STATE="${USAGE_PROBE_STATE:-$HOME/.claude/.usage-probe-state}"
LOCK="${USAGE_PROBE_LOCK:-$HOME/.claude/.usage-probe.lock}"
LOCK_STALE=120
NOW="${USAGE_PROBE_NOW:-$(date +%s 2>/dev/null || echo 0)}"
ENDPOINT="${USAGE_PROBE_ENDPOINT:-https://api.anthropic.com/api/oauth/usage}"
ACCOUNTS_FILE="${CLAUDE_ACCOUNTS_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json}"

# ---- レジストリを解決してスロット一覧（TSV）を得る ----
# 出力: id<TAB>label<TAB>securestorage<TAB>service（1 行 1 スロット）
read_slots() {
  ACCOUNTS_FILE="$ACCOUNTS_FILE" python3 <<'PY' 2>/dev/null
import hashlib, json, os, re, sys, unicodedata

MAX_SLOTS = 8
MAX_LABEL_WIDTH = 8   # statusline の左端に出す列幅の上限（全角なら 4 文字ぶん）
ID_RE = re.compile(r"[A-Za-z0-9-]{1,32}\Z")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")

def disp_width(text):
    """端末上の表示幅。全角（East Asian Width が W / F）は 2 桁として数える。"""
    return sum(2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1 for ch in text)

def clip_label(text, maxw):
    """表示幅が maxw を超える label を切り詰める（長い label で全行が押し出されるのを防ぐ）。"""
    out, w = [], 0
    for ch in text:
        cw = 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
        if w + cw > maxw:
            break
        out.append(ch)
        w += cw
    return "".join(out) or text[:1]

def service(sec):
    # Claude Code 本体と同じ導出: 空なら既定、そうでなければ NFC 正規化して sha256 先頭 8 桁
    if not sec:
        return "Claude Code-credentials"
    return "Claude Code-credentials-" + hashlib.sha256(
        unicodedata.normalize("NFC", sec).encode("utf-8")).hexdigest()[:8]

slots = []
try:
    with open(os.environ["ACCOUNTS_FILE"], encoding="utf-8") as fh:
        doc = json.load(fh)
    # トップレベルはオブジェクト固定（裸の配列は不正）
    entries = doc.get("accounts") if isinstance(doc, dict) else None
    if isinstance(entries, list):
        seen = set()
        for entry in entries:
            if len(slots) >= MAX_SLOTS:
                break
            if not isinstance(entry, dict):
                continue
            sid = entry.get("id")
            if not isinstance(sid, str) or not ID_RE.match(sid) or sid in seen:
                continue
            seen.add(sid)
            label = entry.get("label")
            if not isinstance(label, str) or not label:
                label = sid
            sec = entry.get("securestorage")
            if not isinstance(sec, str):
                sec = ""
            # label / securestorage は TSV で bash に渡すので、区切りを壊す制御文字を
            # 含むスロットは id 不正と同じく捨てる（列がずれて幽霊スロットが生まれ、
            # 空の securestorage で既定サービス名に一致して active を乗っ取る事故を防ぐ）。
            if CTRL_RE.search(label) or CTRL_RE.search(sec):
                continue
            label = clip_label(label, MAX_LABEL_WIDTH)
            slots.append((sid, label, sec, service(sec)))
except Exception:
    slots = []

if not slots:
    slots = [("default", "default", "", service(""))]

for row in slots:
    sys.stdout.write("\t".join(row) + "\n")
PY
}

slots_tsv="$(read_slots)"
# python3 が無い等でレジストリ解決自体が落ちたら既定スロット 1 つに縮退する
[ -n "$slots_tsv" ] || slots_tsv=$'default\tdefault\t\tClaude Code-credentials'

# TSV を配列へ展開する。`IFS=$'\t' read` は使えない: タブは IFS 空白なので連続タブが
# 1 つの区切りに畳まれ、securestorage が空の既定スロットで service 列が消える
# （空のサービス名で Keychain を引いて全件検索になり固まる事故があった）。
# 区切りを IFS 空白ではない US(0x1f) に置換してから read する。
slot_ids=(); slot_labels=(); slot_secures=(); slot_services=()
while IFS='' read -r line; do
  [ -n "$line" ] || continue
  IFS=$'\x1f' read -r _id _label _secure _service <<< "${line//$'\t'/$'\x1f'}"
  [ -n "$_id" ] || continue
  slot_ids+=("$_id"); slot_labels+=("$_label")
  slot_secures+=("$_secure"); slot_services+=("$_service")
done <<< "$slots_tsv"
if [ "${#slot_ids[@]}" -eq 0 ]; then
  slot_ids=("default"); slot_labels=("default")
  slot_secures=(""); slot_services=("Claude Code-credentials")
fi

if [ "${1:-}" = "--print-slots" ]; then
  # 解決済みの配列から出力する（フェッチ経路と同じ値を見せ、パース事故をテストで捕らえる）
  for i in $(seq 0 $(( ${#slot_ids[@]} - 1 ))); do
    printf '%s\t%s\t%s\t%s\n' "${slot_ids[$i]}" "${slot_labels[$i]}" \
           "${slot_secures[$i]}" "${slot_services[$i]}"
  done
  exit 0
fi

# ---- マシン全体で 1 本: ロックを取れなければ何もしない ----
# ロックの古さは実時刻と mtime で測る（USAGE_PROBE_NOW は導出の決定論化用で、mtime は実時刻のため混ぜない）。
# GNU の stat（-c）を先に試す。逆順にすると Linux で `stat -f` がファイルシステム情報の表示として
# 成功してしまい、mtime ではない値が返る。macOS の stat は -c を不正オプションとして非 0 で終わる。
# 親（既定は ~/.claude）が無い環境でも取れるよう先に作る。試行状態ファイルの既定の置き場所も同じ親
mkdir -p "$(dirname "$LOCK")" 2>/dev/null
if ! mkdir "$LOCK" 2>/dev/null; then
  real_now="$(date +%s 2>/dev/null || echo 0)"
  lock_mtime="$(stat -c %Y "$LOCK" 2>/dev/null || stat -f %m "$LOCK" 2>/dev/null || echo "$real_now")"
  [ $(( real_now - lock_mtime )) -gt "$LOCK_STALE" ] 2>/dev/null || exit 0
  rm -rf "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
raw_dir=""
cleanup() {
  [ -n "$raw_dir" ] && rm -rf "$raw_dir"
  rmdir "$LOCK" 2>/dev/null
}
trap cleanup EXIT

# ---- 実行条件: 叩くスロットを選ぶ（ロックを取ってから判定する） ----
# 出力は叩くスロット id（1 行 1 つ）。判定自体が落ちたら何も叩かない（fail-open）
slot_pairs=""
for i in $(seq 0 $(( ${#slot_ids[@]} - 1 ))); do
  slot_pairs+="${slot_ids[$i]}"$'\t'"${slot_secures[$i]}"$'\n'
done
due="$(SLOT_PAIRS="$slot_pairs" USAGE_NOW="$NOW" STALE="$STALE" INTERVAL="$INTERVAL" \
  STATE="$STATE" SNAPSHOT="$SNAPSHOT" USAGE_VIEW_DIR="$(dirname "$0")" python3 - <<'PY' 2>/dev/null
import json, os, sys
sys.path.insert(0, os.environ["USAGE_VIEW_DIR"])
import usage_view  # 記録の鍵と置き場所は読み手と同じ規則で求める

now = int(os.environ["USAGE_NOW"])
stale, interval = int(os.environ["STALE"]), int(os.environ["INTERVAL"])

def load(path):
    try:
        with open(path, encoding="utf-8") as handle:
            document = json.load(handle)
        return document if isinstance(document, dict) else {}
    except Exception:
        return {}

def count(value):
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else 0

def old(stamp):
    return not usage_view.finite_number(stamp) or now - stamp > stale

state = load(os.environ["STATE"]).get("slots")
state = state if isinstance(state, dict) else {}
entries = usage_view.read_snapshot(os.environ["SNAPSHOT"]).get("accounts")
entries = entries if isinstance(entries, dict) else {}
sessions = usage_view.default_paths()["sessions_dir"]
for line in os.environ["SLOT_PAIRS"].splitlines():
    slot_id, _, secure = line.partition("\t")
    record = load(os.path.join(sessions, usage_view.session_key(secure) + ".json"))
    entry = entries.get(slot_id) if isinstance(entries.get(slot_id), dict) else {}
    if not (old(record.get("observed_at")) or old(entry.get("fetched_at"))):
        continue
    tried = state.get(slot_id) if isinstance(state.get(slot_id), dict) else {}
    last, streak = tried.get("last_attempt"), min(count(tried.get("consecutive_429")), 32)
    wait = interval if streak == 0 else min(interval * 2 ** (streak - 1), 86400)
    if usage_view.finite_number(last) and now - last < wait:
        continue
    print(slot_id)
PY
)"
[ -n "$due" ] || exit 0

# ---- スロットごとに生レスポンスを取得する（fail-open: 取れなければそのスロットを飛ばす） ----
raw_dir="$(mktemp -d 2>/dev/null || true)"
[ -n "$raw_dir" ] || exit 0

# $1=スロット id → 対応する USAGE_PROBE_RESPONSE_FILE_<ID> の env 変数名
slot_response_var() {
  printf 'USAGE_PROBE_RESPONSE_FILE_%s' "$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"
}

# $1=スロット id → 対応するレスポンスファイルのパス（無ければ共通の値）
slot_response_file() {
  local key val
  key="$(slot_response_var "$1")"
  val="${!key:-}"
  [ -n "$val" ] || val="${USAGE_PROBE_RESPONSE_FILE:-}"
  printf '%s' "$val"
}

# テスト経路の判定: 共通キーかスロット別キーのいずれかが非空ならテスト経路。
# `env | grep` は使わない（改行を含む無関係な変数の継続行に誤マッチするうえ、
# 空文字で設定されたときに本番経路へ落ちる main の挙動と食い違うため）。
test_mode=0
if [ -n "${USAGE_PROBE_RESPONSE_FILE:-}" ]; then
  test_mode=1
else
  for _sid in "${slot_ids[@]}"; do
    _key="$(slot_response_var "$_sid")"
    if [ -n "${!_key:-}" ]; then test_mode=1; break; fi
  done
fi

# $1=Keychain サービス名 $2=securestorage パス → OAuth アクセストークン（取れなければ空）
slot_token() {
  local service="$1" secure="$2" token="" cred
  # Linux 等の平文 credentials.json を先に試す（既定スロットは従来どおり ~/.claude を見る）
  if [ -n "$secure" ]; then
    cred="${secure}/.credentials.json"
  else
    cred="$HOME/.claude/.credentials.json"
  fi
  if [ -f "$cred" ]; then
    token="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('claudeAiOauth',{}).get('accessToken',''))" "$cred" 2>/dev/null || true)"
  fi
  # サービス名が空のまま Keychain を引くと全件検索になり固まる。念のための番人。
  if [ -z "$token" ] && [ -n "$service" ] && command -v security >/dev/null 2>&1; then
    token="$(security find-generic-password -s "$service" -w 2>/dev/null \
      | python3 -c "import json,sys;print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null || true)"
  fi
  printf '%s' "$token"
}

# 使用量 API は User-Agent が claude-code/<版> でないリクエストを厳しい別枠で数え、
# 間隔を空けても 429 を返し続ける（2026-09 実測: 同じトークンで付けないと 429、付けると 200）。
# 版は照合されないとの報告があるが、実際に入っている版を名乗る。取れなければ固定値に落とす。
user_agent="${USAGE_PROBE_USER_AGENT:-}"
if [ -z "$user_agent" ]; then
  cc_version="$(claude --version 2>/dev/null | awk 'NR==1{print $1}' || true)"
  # 数字とドットだけの版（例: 2.1.280）以外は、出力の形が変わったとみなして固定値に落とす
  [[ "$cc_version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || cc_version="2.1.0"
  user_agent="claude-code/${cc_version}"
fi

any_new=0
for idx in $(seq 0 $(( ${#slot_ids[@]} - 1 ))); do
  sid="${slot_ids[$idx]}"; ssecure="${slot_secures[$idx]}"; sservice="${slot_services[$idx]}"
  # id をファイル名に使う前に bash 側でも書式を検証する（TSV の列ずれ等で
  # 想定外の値が入っても raw_dir の外に書き込まないための番人）
  case "$sid" in
    *[!A-Za-z0-9-]*|"") continue ;;
  esac
  [ "${#sid}" -le 32 ] || continue
  case $'\n'"$due"$'\n' in
    *$'\n'"$sid"$'\n'*) ;;
    *) continue ;;
  esac
  raw=""
  http_code=0
  if [ "$test_mode" -eq 1 ]; then
    rf="$(slot_response_file "$sid")"
    if [ -n "$rf" ] && [ -s "$rf" ]; then
      raw="$(cat "$rf" 2>/dev/null || true)"
      http_code=200
    fi
    status_key="USAGE_PROBE_STATUS_$(printf '%s' "$sid" | tr 'a-z-' 'A-Z_')"
    status_val="${!status_key:-${USAGE_PROBE_STATUS:-}}"
    if [ -n "$status_val" ]; then
      http_code="$status_val"
      [ "$http_code" = "200" ] || raw=""
    fi
  else
    token="$(slot_token "$sservice" "$ssecure")"
    if [ -n "$token" ] && command -v curl >/dev/null 2>&1; then
      # Authorization ヘッダは --config - で stdin から渡す。コマンドライン引数に載せると
      # 同一ユーザーの任意プロセスと root から ps auxww でトークンが読める。
      # curl の config ファイル書式に合わせて \ と " をエスケープする。
      esc_token="$(printf '%s' "$token" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
      # 末尾に HTTP ステータスを付けて取得する。401 / 429 / 5xx でも API は
      # 正しい JSON のエラーボディを返すため、ステータスを見ないと成功と区別できない。
      resp="$(printf 'header = "Authorization: Bearer %s"\n' "$esc_token" \
        | curl -sS --max-time 10 --config - \
          -H 'anthropic-beta: oauth-2025-04-20' \
          -H "User-Agent: ${user_agent}" \
          -w '\n%{http_code}' \
          "$ENDPOINT" 2>/dev/null || true)"
      unset esc_token
      if [ -n "$resp" ]; then
        http_code="${resp##*$'\n'}"
        if [ "$http_code" = "200" ]; then
          raw="${resp%$'\n'*}"
        fi
      fi
    fi
  fi
  printf '%s' "$http_code" > "${raw_dir}/${sid}.status" 2>/dev/null
  if [ -n "$raw" ]; then
    printf '%s' "$raw" > "${raw_dir}/${sid}.json" 2>/dev/null && any_new=1
  fi
done

# ---- 試行状態を記録する（結果にかかわらず。一時ファイルからの置き換えで書く） ----
DUE="$due" RAW_DIR="$raw_dir" STATE="$STATE" USAGE_NOW="$NOW" python3 - <<'PY' 2>/dev/null
import json, os, tempfile

now = int(os.environ["USAGE_NOW"])
path = os.environ["STATE"]
try:
    with open(path, encoding="utf-8") as handle:
        slots = json.load(handle).get("slots")
except Exception:
    slots = None
slots = slots if isinstance(slots, dict) else {}
for slot_id in os.environ["DUE"].split():
    try:
        with open(os.path.join(os.environ["RAW_DIR"], slot_id + ".status")) as handle:
            code = handle.read().strip()
    except OSError:
        continue  # 書式検証で飛ばしたスロットは試していない
    previous = slots.get(slot_id) if isinstance(slots.get(slot_id), dict) else {}
    streak = previous.get("consecutive_429")
    streak = streak if isinstance(streak, int) and not isinstance(streak, bool) and streak > 0 else 0
    if code == "200":
        streak = 0
    elif code == "429":
        streak += 1
    slots[slot_id] = {"last_attempt": now, "consecutive_429": streak}
fd, tmp = tempfile.mkstemp(prefix=".usage-probe-state.", dir=os.path.dirname(path) or ".")
with os.fdopen(fd, "w") as handle:
    json.dump({"slots": slots}, handle)
os.replace(tmp, path)
PY

# どのスロットからも新しい生レスポンスが取れなかった → fail-open（snapshot を書かない）
[ "$any_new" -eq 1 ] || exit 0

# ---- パースして snapshot を組み立てる（fail-open） ----
out="$(SLOTS_TSV="$slots_tsv" RAW_DIR="$raw_dir" PREV_SNAPSHOT="$SNAPSHOT" USAGE_NOW="$NOW" \
       ACTIVE_SECURE="${CLAUDE_SECURESTORAGE_CONFIG_DIR-}" python3 <<'PY' 2>/dev/null || true
import hashlib, json, os, unicodedata

now = int(os.environ.get("USAGE_NOW") or 0)
raw_dir = os.environ["RAW_DIR"]

FIELDS = ("fetched_at",
          "five_hour_pct", "five_hour_resets_at", "five_hour_resets_epoch",
          "weekly_all_pct", "weekly_resets_at", "weekly_resets_epoch",
          "fable_weekly_pct", "fable_active")

def service(sec):
    if not sec:
        return "Claude Code-credentials"
    return "Claude Code-credentials-" + hashlib.sha256(
        unicodedata.normalize("NFC", sec).encode("utf-8")).hexdigest()[:8]

def iso_to_epoch(s):
    if not s:
        return None
    try:
        from datetime import datetime
        return int(datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp())
    except Exception:
        return None

def window(d, key):
    """five_hour / seven_day の共通形。utilization を主とし used_percentage も許容する。"""
    w = d.get(key) or {}
    if not isinstance(w, dict):
        return None, None
    pct = w.get("utilization")
    if pct is None:
        pct = w.get("used_percentage")
    return pct, w.get("resets_at")

def parse(raw):
    """生 API JSON → 値フィールドの dict。パースできなければ None（= このスロットは失敗扱い）。"""
    try:
        d = json.loads(raw)
    except Exception:
        return None
    if not isinstance(d, dict):
        return None

    fable_pct = None
    fable_active = False
    fable_resets_iso = None
    for lim in (d.get("limits") or []):
        if not isinstance(lim, dict) or lim.get("group") != "weekly":
            continue
        scope = lim.get("scope") or {}
        model = (scope.get("model") or {}) if isinstance(scope, dict) else {}
        if (model.get("display_name") or "").lower() == "fable":
            fable_pct = lim.get("percent")
            fable_active = bool(lim.get("is_active"))
            fable_resets_iso = lim.get("resets_at")
            break

    five_pct, five_iso = window(d, "five_hour")
    seven_pct, seven_iso = window(d, "seven_day")
    weekly_iso = fable_resets_iso or seven_iso

    # HTTP 401 / 429 / 5xx でも API は {"type":"error","error":{...}} という
    # 正しい JSON の dict を返す。使える数字が 1 つも無いレスポンスは失敗として扱う
    # （成功扱いにすると、そのスロットの前回値を全 null で上書きしてしまう）。
    # 非 active アカウントはトークン期限切れでこの経路に入るのが常態なので、
    # ここを塞がないとスロット単位 fail-open が機能しない。
    if five_pct is None and seven_pct is None and fable_pct is None:
        return None

    return {
        "fetched_at": now,
        "five_hour_pct": five_pct,
        "five_hour_resets_at": five_iso,
        "five_hour_resets_epoch": iso_to_epoch(five_iso),
        "weekly_all_pct": seven_pct,
        "weekly_resets_at": weekly_iso,
        "weekly_resets_epoch": iso_to_epoch(weekly_iso),
        "fable_weekly_pct": fable_pct,
        "fable_active": fable_active,
    }

slots = []
for line in os.environ["SLOTS_TSV"].splitlines():
    if not line.strip():
        continue
    parts = line.split("\t")
    while len(parts) < 4:
        parts.append("")
    slots.append(parts[:4])

prev = {}
try:
    with open(os.environ["PREV_SNAPSHOT"], encoding="utf-8") as fh:
        prev = json.load(fh) or {}
except Exception:
    prev = {}
prev_accounts = prev.get("accounts") if isinstance(prev.get("accounts"), dict) else {}

accounts = {}
fresh = set()
for sid, label, sec, _svc in slots:
    values = None
    path = os.path.join(raw_dir, sid + ".json")
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as fh:
                values = parse(fh.read())
        except Exception:
            values = None
    if values is not None:
        fresh.add(sid)
    else:
        # スロット単位 fail-open: 前回値（fetched_at 込み）をそのまま引き継ぐ
        old = prev_accounts.get(sid)
        if isinstance(old, dict):
            values = {k: old.get(k) for k in FIELDS}
        else:
            values = {k: None for k in FIELDS}
    entry = {"label": label, "securestorage": sec or None}
    entry.update(values)
    accounts[sid] = entry

if not fresh:
    raise SystemExit(1)  # 新しい値が 1 つも無い → fail-open（呼び出し側が空を検知）

# active スロットの判定（正本: usage-account-registry「active スロットの判定規則」）
# 環境変数から導出したサービス名で突き合わせる。probe は Claude Code 本体と同じ
# プロセス環境で走るため、未設定は「既定アカウントで動いている」ことを意味する。
active = None
want = service(os.environ.get("ACTIVE_SECURE", ""))
for sid, _label, sec, _svc in slots:
    if service(sec) == want:
        active = sid
        break
if active is None:
    cand = prev.get("active")
    if isinstance(cand, str) and cand in accounts:
        active = cand
if active is None and slots:
    active = slots[0][0]

snap = {"schema": 2, "active": active}
# トップレベルは active スロットの同名フィールドを機械的に写す（独立に計算しない）
mirror = accounts.get(active, {})
for key in FIELDS:
    snap[key] = mirror.get(key)
snap["accounts"] = accounts

print(json.dumps(snap, ensure_ascii=False))
PY
)"

# パース失敗（空）→ fail-open
[ -n "$out" ] || exit 0

# ---- 原子的書き込み（既存 snapshot を壊さない） ----
dir="$(dirname "$SNAPSHOT")"
mkdir -p "$dir" 2>/dev/null || exit 0
tmp="$(mktemp "${dir}/.usage-snapshot.XXXXXX" 2>/dev/null || true)"
[ -n "$tmp" ] || exit 0
if printf '%s\n' "$out" > "$tmp" 2>/dev/null; then
  mv -f "$tmp" "$SNAPSHOT" 2>/dev/null || rm -f "$tmp" 2>/dev/null
else
  rm -f "$tmp" 2>/dev/null
fi
exit 0
