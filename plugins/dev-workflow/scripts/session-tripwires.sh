#!/usr/bin/env bash
# SessionStart hook: 昇格トリップワイヤーの常駐ルール + Fable 残量モード（自動導出）を
# セッション文脈に注入する。メモリ索引が閾値を超えていれば memory-tripwire.sh の 1 行を先頭に足す。
# 本文の single source of truth は templates/escalation-tripwires.md（複製を持たない）。
# テンプレート欠損・節の抽出失敗時は無出力・exit 0（セッション開始をブロックしない）。
#
# TRIPWIRES_SCOPE=subagent-budget（subagent-start-context.sh が使う）のときは、残量モードの
# ブロック（「## Fable 残量モード（自動導出）」から共有枠モードの効果の行まで）だけを JSON でなく
# 本文テキストで出す。この範囲では usage-probe・メモリ索引の検知・トリップワイヤー節の抽出を
# 行わず、親向けの「W を再開する前に測る」行も出さない。テンプレートが無くても出す。
# 未設定・それ以外の値のときは従来どおり。
#
# 残量モードの式（明示 env の優先・閾値の比較）は usage_view.py の budget_mode_details の 1 か所に
# あり、ここでは結果を表示するだけで写しを持たない。usage_view.py は CLAUDE_PLUGIN_ROOT ではなく
# このスクリプト自身のディレクトリから読む（空の CLAUDE_PLUGIN_ROOT でも明示 env が効き、
# カレントディレクトリも指さない。#847）。読み込めなければ明示 env も読まず conserve / ok を出す。
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SELF_DIR=""

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
TEMPLATE="${ROOT:+${ROOT}/templates/escalation-tripwires.md}"
SCOPE="${TRIPWIRES_SCOPE:-}"
[ "$SCOPE" = "subagent-budget" ] || SCOPE="session"

SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"
MEMORY_NOTICE=""

if [ "$SCOPE" = "session" ]; then
  # CLAUDE_PLUGIN_ROOT が空のときは、テンプレートが無いときと同じく何も出さない。空のまま進むと
  # "${ROOT}/templates/…" と "${ROOT}/scripts/…" がファイルシステムのルート直下を指す（#847）。
  [ -n "$ROOT" ] || exit 0
  # テンプレートが無ければ従来どおり fail-soft（残量ブロックも出さない）。
  [ -f "$TEMPLATE" ] || exit 0

  # usage-probe を best-effort 実行（失敗しても snapshot は壊れず、導出は conserve 既定に倒れる）。
  PROBE="${ROOT}/scripts/usage-probe.sh"
  [ -x "$PROBE" ] && "$PROBE" >/dev/null 2>&1 || true

  # メモリ索引の検知（閾値超のときだけ 1 行。失敗しても無出力で先へ進む）。
  MEMORY_NOTICE="$("${ROOT}/scripts/memory-tripwire.sh" 2>/dev/null)" || MEMORY_NOTICE=""
fi

# 導出は active スロットの実効値（セッション記録と snapshot を突き合わせた値）から行う。
# 実効値の規則（正本: openspec/specs/usage-session-records）も残量モードの式も usage_view.py にある。
TEMPLATE="$TEMPLATE" SNAPSHOT="$SNAPSHOT" MEMORY_NOTICE="$MEMORY_NOTICE" SCOPE="$SCOPE" \
  USAGE_VIEW_DIR="$SELF_DIR" python3 -I <<'PY'
import json, os, re, sys, time

SCOPE = os.environ.get("SCOPE", "session")

# --- トリップワイヤー節の抽出（single source of truth） ---
tripwire = ""
if SCOPE == "session":
    try:
        text = open(os.environ["TEMPLATE"], encoding="utf-8").read()
        m = re.search(r"^## 昇格トリップワイヤー.*", text, flags=re.S | re.M)
        tripwire = m.group(0).strip() if m else ""
    except Exception:
        tripwire = ""
    if not tripwire:
        raise SystemExit(0)  # 節が抽出できなければ fail-soft（無出力）

now = os.environ.get("USAGE_PROBE_NOW")
now = int(now) if (now and now.lstrip("-").isdigit()) else int(time.time())

# --- active スロットの実効値と残量モード（式は usage_view.budget_mode_details の 1 か所） ---
UNREADABLE = "既定（usage_view.py を読めない）"
slot = {}
try:
    if not os.environ["USAGE_VIEW_DIR"]:
        # 自分の場所が求まらない。空文字列を検索パスに入れるとカレントディレクトリを指すので読まない（#847）
        raise RuntimeError("no script dir")
    sys.path.insert(0, os.environ["USAGE_VIEW_DIR"])
    import usage_view
    details = usage_view.budget_mode_details  # 読めなければ明示 env も読まない（優先の判定も式の一部）
    elapsed_of = usage_view.elapsed_pct
except Exception:
    usage_view = None
try:
    if usage_view is None:
        raise RuntimeError("usage_view.py unavailable")
    view = usage_view.build_view(snapshot_path=os.environ["SNAPSHOT"], now=now)
    slot = view["accounts"].get(view["active"]) or {}
except Exception:
    slot = {}

DEFAULTS = {"fable": {"mode": "conserve", "shown": "conserve", "source": UNREADABLE},
            "shared": {"mode": "ok", "shown": "ok", "source": UNREADABLE}}
try:
    if usage_view is None:
        raise RuntimeError("usage_view.py unavailable")
    modes = details(slot, now)
except Exception:
    modes, slot = DEFAULTS, {}
    elapsed_of = lambda resets_epoch, now: None

pct = slot.get("fable_weekly_pct")
all_pct = slot.get("weekly_all_pct")
# 表示だけに使う（Fable の週経過は Fable の窓のリセット時刻から求める）
try:
    elapsed_pct = elapsed_of(slot.get("fable_resets_epoch"), now)
except Exception:
    elapsed_pct = None

mode, source = modes["fable"]["shown"], modes["fable"]["source"]
shared, shared_source = modes["shared"]["shown"], modes["shared"]["source"]

EFFECT = {
    "abundant": "どの役割の既定も上げない（Fable が使われる経路は決める役 subagent_type: dev-workflow:decider だけ）。余った Fable 枠は人間の対話と verify に回す。",
    "conserve": "役割表の既定どおり（W=sonnet、R1=opus、G=sonnet）。Fable は決める役（subagent_type: dev-workflow:decider）だけで、実行役 W はどの事前分類でも opus 止まり。",
    "reserve":  "conserve に加え、自動実行（unmanned/cron/loop）では Fable を一切使わない。昇格上限 Opus。interactive は conserve と同一。",
    "exhausted":"Fable 週次枠を実質使い切った。interactive/unmanned を問わず Fable を一切使わず、昇格上限 Opus。rate-limit 実エラーは reactive に Opus へ降格。",
}
effect = EFFECT.get(mode, "未知のモード指定。conserve 相当（安全側）で扱う。")

SHARED_EFFECT = {
    "ok":        "制約なし。役割の既定は decision-criteria の役割表どおり（W=sonnet、R1=opus、G=sonnet）。",
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
if SCOPE == "subagent-budget":
    # サブエージェント向け: 残量ブロックだけを本文テキストで出す（包む JSON は呼び出し側が作る）
    print("\n".join(lines))
    raise SystemExit(0)
lines.append("- サブエージェントのコンテキスト上限: W を SendMessage で再開する前に "
             "`${CLAUDE_PLUGIN_ROOT}/scripts/subagent-context.sh <name>` で測る"
             f"（上限 {os.environ.get('DEV_WORKFLOW_CONTEXT_CAP', '150000')} tokens。exit 2 が上限超）。"
             "上限超のあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・"
             "return の 1 行目の宣言・前任が動作中のまま交代させる手順）の正本は "
             "`${CLAUDE_PLUGIN_ROOT}/skills/develop/references/decision-criteria.md`"
             "「コンテキスト上限（サブエージェントの手渡し）」。"
             "**正本を読むまで手渡さない**（条件をここに再掲しないのは、同じ規則の言い換えが"
             "複数の面に散らばっていたことが書き換え漏れの原因だったため）")
budget = "\n".join(lines)

notice = (os.environ.get("MEMORY_NOTICE") or "").strip()
head = notice + "\n\n" if notice else ""

print(json.dumps({"additionalContext": head + budget + "\n\n" + tripwire}, ensure_ascii=False))
PY
