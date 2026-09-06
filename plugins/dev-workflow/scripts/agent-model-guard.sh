#!/usr/bin/env bash
# PreToolUse hook（matcher: Agent）: model 未指定のサブエージェント spawn を拒否する。
#
# 理由: model を省いた Agent 呼び出しは親セッションのモデルを継承する。オーナーの対話セッションは
# Fable なので、書き忘れ 1 回で Fable のサブエージェントが無言で立ち、週次枠を消費する
# （2026-09 の監査: fork 1 本で 271 USD 換算・コンテキスト 49 万トークン）。
# 規範の正本は rules/subagent-model-selection.md（model は必ず明示。fork は最上位ティアの仕事だけ）。
#
# 判定:
#   - tool_name が Agent 以外 → 何もしない（exit 0・無出力）
#   - model あり → 許可
#   - subagent_type が定義に model を持つエージェント（plugin:agent 形式や casting-* 等）→ 許可
#     （Agent ツールは定義側の model を使うため、パラメータ省略が親継承にならない）
#   - subagent_type が fork → SHARED_BUDGET_MODE（明示 env、無ければ snapshot から導出）が ok のときだけ許可。
#     throttled / depleted では拒否（fork は常に親＝Fable で動く）
#   - それ以外（general-purpose / Explore / Plan / 未指定）で model 無し → 拒否
#   - DEV_WORKFLOW_MODEL_GUARD=off で全許可（緊急の逃げ道。恒久設定にしない）
#
# 出力（拒否時のみ）: {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
#                       "permissionDecisionReason":"..."}}
set -uo pipefail

[ "${DEV_WORKFLOW_MODEL_GUARD:-on}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0   # fail-open（判定できなければ止めない）

SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"

# Python 本体は fd 3 のヒアドキュメントで渡し、stdin（hook の payload）はそのまま Python に読ませる。
# payload を環境変数や引数に載せると、長い prompt で ARG_MAX を超えて hook が非 0 で落ち、
# Claude Code は非 0/非 2 の hook エラーを「続行」と扱うため、判定が素通りになる。
SNAPSHOT="$SNAPSHOT" python3 /dev/fd/3 3<<'PY'
import json, os, sys, time

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)  # 入力が読めなければ fail-open
if not isinstance(payload, dict) or payload.get("tool_name") != "Agent":
    sys.exit(0)
inp = payload.get("tool_input") or {}
if not isinstance(inp, dict):
    sys.exit(0)

model = (inp.get("model") or "").strip() if isinstance(inp.get("model"), str) else ""
stype = (inp.get("subagent_type") or "").strip() if isinstance(inp.get("subagent_type"), str) else ""

def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                              "permissionDecision": "deny",
                                              "permissionDecisionReason": reason}}, ensure_ascii=False))
    sys.exit(0)

# fork は model パラメータを無視して常に親モデルで動くので、model の有無より先に判定する
if stype == "fork":
    shared = (os.environ.get("SHARED_BUDGET_MODE") or "").strip()
    if not shared:
        shared = "ok"
        try:
            snap = json.load(open(os.environ["SNAPSHOT"], encoding="utf-8"))
            all_pct = float(snap.get("weekly_all_pct"))
            if all_pct > 90:
                shared = "depleted"            # リセット時刻が読めなくても 90% 超は depleted
            else:
                resets = int(snap.get("weekly_resets_epoch"))
                now_env = os.environ.get("USAGE_PROBE_NOW")
                now = int(now_env) if now_env and now_env.lstrip("-").isdigit() else int(time.time())
                WEEK = 7 * 86400
                elapsed = max(0.0, min(100.0, (WEEK - (resets - now)) / WEEK * 100.0))
                if all_pct > elapsed:
                    shared = "throttled"
        except Exception:
            if shared == "ok":
                pass  # 読めなければ ok（fail-open）
    if shared == "ok":
        sys.exit(0)
    deny(f"fork は親モデル（Fable）を継承して全履歴ごと動く（model パラメータは無視される）。共有枠モードが {shared} のあいだは fork を使わず、"
         "model を明示した general-purpose（sonnet / opus）で spawn する。規範: rules/subagent-model-selection.md")

if model:
    sys.exit(0)

# 定義側に model を持つエージェント種別（plugin:agent 形式・casting 系）は省略が親継承にならない
NEEDS_EXPLICIT = {"", "general-purpose", "Explore", "Plan", "claude", "claude-code-guide", "statusline-setup"}
if stype in NEEDS_EXPLICIT:
    deny("Agent の model が未指定。省略すると親セッションのモデル（多くは Fable）を継承して週次枠を無言で消費する。"
         "model: haiku（機械的）/ sonnet（通常実装・調査）/ opus（設計・レビュー）/ fable（最終 verify・マージ権限・層間契約・課金/法務）を明示して再実行。"
         "規範: rules/subagent-model-selection.md")
sys.exit(0)
PY
