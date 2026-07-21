#!/usr/bin/env bash
# SessionStart hook: 昇格トリップワイヤーの常駐ルール + Fable 残量モード（自動導出）を
# セッション文脈に注入する。
# 本文の single source of truth は templates/escalation-tripwires.md（複製を持たない）。
# テンプレート欠損・節の抽出失敗時は無出力・exit 0（セッション開始をブロックしない）。
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
TEMPLATE="${ROOT}/templates/escalation-tripwires.md"
# テンプレートが無ければ従来どおり fail-soft（残量ブロックも出さない）。
[ -f "$TEMPLATE" ] || exit 0

# usage-probe を best-effort 実行（失敗しても snapshot は壊れず、導出は conserve 既定に倒れる）。
PROBE="${ROOT}/scripts/usage-probe.sh"
[ -x "$PROBE" ] && "$PROBE" >/dev/null 2>&1 || true

SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"

TEMPLATE="$TEMPLATE" SNAPSHOT="$SNAPSHOT" python3 <<'PY'
import json, os, re, time

# --- トリップワイヤー節の抽出（single source of truth） ---
try:
    text = open(os.environ["TEMPLATE"], encoding="utf-8").read()
    m = re.search(r"^## 昇格トリップワイヤー.*", text, flags=re.S | re.M)
    tripwire = m.group(0).strip() if m else ""
except Exception:
    tripwire = ""
if not tripwire:
    raise SystemExit(0)  # 節が抽出できなければ fail-soft（無出力）

# --- snapshot 読み取り（fail-open） ---
snap = None
try:
    with open(os.environ["SNAPSHOT"], encoding="utf-8") as f:
        snap = json.load(f)
    if not isinstance(snap, dict):
        snap = None
except Exception:
    snap = None

pct = snap.get("fable_weekly_pct") if snap else None
resets_epoch = snap.get("weekly_resets_epoch") if snap else None
try:
    pct = float(pct) if pct is not None else None
except Exception:
    pct = None

now = os.environ.get("USAGE_PROBE_NOW")
now = int(now) if (now and now.lstrip("-").isdigit()) else int(time.time())

WEEK = 7 * 86400
elapsed_pct = None
if resets_epoch:
    try:
        remaining = int(resets_epoch) - now
        elapsed_pct = max(0.0, min(100.0, (WEEK - remaining) / WEEK * 100.0))
    except Exception:
        elapsed_pct = None

# --- 残量モード導出（明示 env > snapshot 無し > exhausted > バーンレート比較） ---
explicit = (os.environ.get("FABLE_BUDGET_MODE") or "").strip()
if explicit:
    mode, source = explicit, "明示 env"
elif pct is None:
    mode, source = "conserve", "既定（usage データなし）"
elif pct > 90:
    mode, source = "exhausted", "自動導出"
elif elapsed_pct is not None and pct <= elapsed_pct:
    mode, source = "abundant", "自動導出"
else:
    mode, source = "conserve", "自動導出"

EFFECT = {
    "abundant": "solo の推奨モデルを Fable に倒す。委譲は結果が変わらない機械的な大量仕事かつ self-contained なタスクに限定。",
    "conserve": "solo=Opus。Fable は verify / checkpoint のみ。",
    "reserve":  "conserve に加え、自動実行（unmanned/cron/loop）では Fable を一切使わない。昇格上限 Opus。interactive は conserve と同一。",
    "exhausted":"Fable 週次枠を実質使い切った。interactive/unmanned を問わず Fable を一切使わず、昇格上限 Opus。rate-limit 実エラーは reactive に Opus へ降格。",
}
effect = EFFECT.get(mode, "未知のモード指定。conserve 相当（安全側）で扱う。")

lines = ["## Fable 残量モード（自動導出）",
         f"- 現在の FABLE_BUDGET_MODE: {mode}（{source}）"]
if pct is not None:
    rem = round(100 - pct)
    ep = f"{round(elapsed_pct)}" if elapsed_pct is not None else "不明"
    lines.append(f"- Fable 週次: 使用 {round(pct)}% / 残 {rem}%（週経過 {ep}%）")
else:
    lines.append("- Fable 週次: usage データなし（snapshot 未取得）→ conserve 既定")
lines.append(f"- {mode} の効果: {effect}")
budget = "\n".join(lines)

print(json.dumps({"additionalContext": budget + "\n\n" + tripwire}, ensure_ascii=False))
PY
