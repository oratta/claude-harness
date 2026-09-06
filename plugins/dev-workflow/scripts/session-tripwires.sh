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
all_pct = snap.get("weekly_all_pct") if snap else None
resets_epoch = snap.get("weekly_resets_epoch") if snap else None
try:
    pct = float(pct) if pct is not None else None
except Exception:
    pct = None
try:
    all_pct = float(all_pct) if all_pct is not None else None
except Exception:
    all_pct = None

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

# --- 共有枠モード導出（全モデル共通の週次枠。Fable が尽きても Opus/Sonnet はこの枠で止まる） ---
# 明示 env > データ無し(ok) > 90% 超(depleted) > 週経過ペースより速い(throttled) > ok
shared_explicit = (os.environ.get("SHARED_BUDGET_MODE") or "").strip()
if shared_explicit:
    shared, shared_source = shared_explicit, "明示 env"
elif all_pct is None:
    shared, shared_source = "ok", "既定（usage データなし）"
elif all_pct > 90:
    shared, shared_source = "depleted", "自動導出"
elif elapsed_pct is not None and all_pct > elapsed_pct:
    shared, shared_source = "throttled", "自動導出"
else:
    shared, shared_source = "ok", "自動導出"

EFFECT = {
    "abundant": "R1 / G（判断役）の既定を Fable に倒してよい。W は abundant でも上げない（事前分類だけ）。委譲は結果が変わらない機械的な大量仕事に限定。",
    "conserve": "solo=Opus。Fable は verify / checkpoint のみ。",
    "reserve":  "conserve に加え、自動実行（unmanned/cron/loop）では Fable を一切使わない。昇格上限 Opus。interactive は conserve と同一。",
    "exhausted":"Fable 週次枠を実質使い切った。interactive/unmanned を問わず Fable を一切使わず、昇格上限 Opus。rate-limit 実エラーは reactive に Opus へ降格。",
}
effect = EFFECT.get(mode, "未知のモード指定。conserve 相当（安全側）で扱う。")

SHARED_EFFECT = {
    "ok":        "制約なし。役割の既定は decision-criteria の役割表どおり（W=sonnet、R1/G=opus）。",
    "throttled": "全モデル枠の消費が週の経過ペースより速い。W/R1/G の既定を sonnet に落とし、昇格上限 opus。abundant の押し上げは無効。",
    "depleted":  "全モデル枠を実質使い切った。全役割 sonnet 固定・昇格なし。Fable/Opus は事前分類に当たっても使わない。",
}
shared_effect = SHARED_EFFECT.get(shared, "未知のモード指定。throttled 相当（安全側）で扱う。")

lines = ["## Fable 残量モード（自動導出）",
         f"- 現在の FABLE_BUDGET_MODE: {mode}（{source}）"]
if pct is not None:
    rem = round(100 - pct)
    ep = f"{round(elapsed_pct)}" if elapsed_pct is not None else "不明"
    lines.append(f"- Fable 週次: 使用 {round(pct)}% / 残 {rem}%（週経過 {ep}%）")
else:
    lines.append("- Fable 週次: usage データなし（snapshot 未取得）→ conserve 既定")
lines.append(f"- {mode} の効果: {effect}")
lines.append(f"- 共有枠モード SHARED_BUDGET_MODE: {shared}（{shared_source}）")
if all_pct is not None:
    lines.append(f"- 全モデル週次: 使用 {round(all_pct)}% / 残 {round(100 - all_pct)}%")
lines.append(f"- {shared} の効果: {shared_effect}")
lines.append("- サブエージェントのコンテキスト上限: W / G を SendMessage で再開する前に "
             "`${CLAUDE_PLUGIN_ROOT}/scripts/subagent-context.sh <name>` で測り、"
             f"{os.environ.get('DEV_WORKFLOW_CONTEXT_CAP', '150000')} tokens 超なら再開せず手渡し（新しい W）に切り替える")
budget = "\n".join(lines)

print(json.dumps({"additionalContext": budget + "\n\n" + tripwire}, ensure_ascii=False))
PY
