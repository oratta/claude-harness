#!/usr/bin/env bash
# usage-probe.sh: Anthropic OAuth usage API から Fable 週次残量を取得し snapshot に書く。
#
# 契約:
#   - 出力先 snapshot: ${USAGE_SNAPSHOT}（既定 ~/.claude/.usage-snapshot）
#   - snapshot が TTL（$USAGE_PROBE_TTL 秒、既定 300）以内に更新済みなら再フェッチしない
#   - 認証取得・通信・パースのいずれが失敗しても exit 0 で snapshot を書かない（fail-open）
#   - snapshot JSON は少なくとも fable_weekly_pct / fable_active を含む
#
# テスト用オーバーライド（本番は未設定）:
#   - USAGE_PROBE_RESPONSE_FILE: 生 API JSON をこのファイルから読む（curl/keychain を経ない）
#   - USAGE_PROBE_NOW: 現在 epoch を固定する
#
# fail-open のため set -e は使わない（フェッチ失敗で誤って落とさない）。
set -uo pipefail

SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"
TTL="${USAGE_PROBE_TTL:-300}"
NOW="${USAGE_PROBE_NOW:-$(date +%s 2>/dev/null || echo 0)}"
ENDPOINT="${USAGE_PROBE_ENDPOINT:-https://api.anthropic.com/api/oauth/usage}"

# ---- 5 分キャッシュ: snapshot が TTL 以内なら何もしない ----
# age は実時刻で計算する（USAGE_PROBE_NOW は導出の決定論化用であり、mtime は実時刻のため混ぜない）。
if [ -f "$SNAPSHOT" ]; then
  real_now="$(date +%s 2>/dev/null || echo 0)"
  # GNU（-c）を先に試す。逆順にすると Linux で `stat -f` が「ファイルシステム情報の
  # 表示」として成功してしまい（BSD の -f=フォーマット指定とは別物）、mtime ではない
  # 値が返って || のフォールバックに落ちない。macOS の stat は -c を不正オプションとして
  # 非0終了するため、この順序なら両プラットフォームで正しく mtime が取れる。
  mtime="$(stat -c %Y "$SNAPSHOT" 2>/dev/null || stat -f %m "$SNAPSHOT" 2>/dev/null || echo 0)"
  age=$(( real_now - mtime ))
  if [ "$age" -ge 0 ] && [ "$age" -lt "$TTL" ] 2>/dev/null; then
    exit 0
  fi
fi

# ---- 生レスポンスの取得（fail-open） ----
raw=""
if [ -n "${USAGE_PROBE_RESPONSE_FILE:-}" ]; then
  # テスト経路: ファイルが在れば読む。無ければフェッチ失敗扱い。
  if [ -s "$USAGE_PROBE_RESPONSE_FILE" ]; then
    raw="$(cat "$USAGE_PROBE_RESPONSE_FILE" 2>/dev/null || true)"
  fi
else
  # 本番経路: OAuth token を取得（Linux 等の credentials.json → macOS Keychain の順）。
  token=""
  cred="$HOME/.claude/.credentials.json"
  if [ -f "$cred" ]; then
    token="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('claudeAiOauth',{}).get('accessToken',''))" "$cred" 2>/dev/null || true)"
  fi
  if [ -z "$token" ] && command -v security >/dev/null 2>&1; then
    token="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null \
      | python3 -c "import json,sys;print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null || true)"
  fi
  if [ -n "$token" ] && command -v curl >/dev/null 2>&1; then
    raw="$(curl -sS --max-time 10 \
      -H "Authorization: Bearer $token" \
      -H 'anthropic-beta: oauth-2025-04-20' \
      "$ENDPOINT" 2>/dev/null || true)"
  fi
fi

# フェッチ空 → fail-open（snapshot を書かない）
[ -n "$raw" ] || exit 0

# ---- パースして snapshot を組み立てる（fail-open） ----
# 生 JSON は env で渡す（heredoc が stdin を占有するため）。
out="$(USAGE_RAW="$raw" USAGE_NOW="$NOW" python3 <<'PY' 2>/dev/null || true
import json, os
now = int(os.environ.get("USAGE_NOW") or 0)
try:
    d = json.loads(os.environ["USAGE_RAW"])
except Exception:
    raise SystemExit(1)  # 不正 JSON → fail-open（呼び出し側が空を検知）
if not isinstance(d, dict):
    raise SystemExit(1)

def iso_to_epoch(s):
    if not s:
        return None
    try:
        from datetime import datetime
        s2 = s.replace("Z", "+00:00")
        return int(datetime.fromisoformat(s2).timestamp())
    except Exception:
        return None

fable_pct = None
fable_active = False
fable_resets_iso = None

for lim in (d.get("limits") or []):
    if not isinstance(lim, dict):
        continue
    if lim.get("group") != "weekly":
        continue
    scope = lim.get("scope") or {}
    model = (scope.get("model") or {}) if isinstance(scope, dict) else {}
    if (model.get("display_name") or "").lower() == "fable":
        fable_pct = lim.get("percent")
        fable_active = bool(lim.get("is_active"))
        fable_resets_iso = lim.get("resets_at")
        break

seven = d.get("seven_day") or {}
weekly_all_pct = seven.get("utilization")
resets_iso = fable_resets_iso or seven.get("resets_at")
resets_epoch = iso_to_epoch(resets_iso)

snap = {
    "schema": 1,
    "fetched_at": now,
    "fable_weekly_pct": fable_pct,
    "fable_active": fable_active,
    "weekly_all_pct": weekly_all_pct,
    "weekly_resets_at": resets_iso,
    "weekly_resets_epoch": resets_epoch,
}
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
