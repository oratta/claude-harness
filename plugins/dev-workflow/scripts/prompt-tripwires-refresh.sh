#!/usr/bin/env bash
# UserPromptSubmit hook: dev-workflow プラグインのバージョンが「このセッションに
# 最後に注入した時点」から変わったときだけ、昇格トリップワイヤー＋残量モードを
# 再注入する（issue #34 の縮小版）。
#
# なぜバージョン変化だけを見るのか:
#   - compact 後の風化は SessionStart hook の matcher `startup|clear|compact` が
#     手動 /compact・自動 compact の両方で発火するため既に塞がっている
#   - 残る穴は「セッション生存中に /plugin update や /reload-plugins でプラグインを
#     更新しても、SessionStart が再発火しないため新ルールが届かない」だけ
#   したがって毎ターンの間引き再注入は過剰で、バージョン変化を唯一のトリガにする。
#
# 契約:
#   - 状態はセッション単位で分離する（${TRIPWIRE_STATE_DIR}/<session_id>）。
#     worktree 並行セッションが互いの注入タイミングに引っ張られないため。
#   - 状態ファイルが無い = そのセッションの初回プロンプト。SessionStart が直前に
#     注入済みなので記録だけして注入しない（二重注入の回避）。
#   - 記録済みバージョンと一致 → 無出力で即 exit（毎プロンプト走るので軽さ優先。
#     この経路では python3 を起動せず、find による掃除も行わない）。
#   - 不一致 → session-tripwires.sh を呼んで本文を作り（本文の single source of
#     truth は templates/escalation-tripwires.md、生成ロジックは複製しない）、
#     hookSpecificOutput.additionalContext として出力する。
#   - 全経路 fail-soft（無出力・exit 0）。プロンプト送信は絶対にブロックしない。
set -uo pipefail

# hook 入力（JSON）を読む。読めなくても詰まらせない。
INPUT="$(cat 2>/dev/null || true)"

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$ROOT" ] || exit 0
PLUGIN_JSON="${ROOT}/.claude-plugin/plugin.json"
[ -f "$PLUGIN_JSON" ] || exit 0

# 現在のプラグインバージョン。fast path で python3 を起動しないよう sed で抜く
# （改行を潰してから引くので pretty-print された JSON でも当たる）。
VERSION="$(tr -d '\n' < "$PLUGIN_JSON" 2>/dev/null \
  | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$VERSION" ] || exit 0

# session_id も同じ理由で sed で抜く。壊れた JSON なら空になり、そのまま無出力で終わる。
SESSION_ID="$(printf '%s' "$INPUT" | tr -d '\n' \
  | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
# ファイル名に使うため英数と - _ . 以外を落とし、`.`/`..` 相当は弾く。
SESSION_ID="$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9._-')"
[ -n "$SESSION_ID" ] || exit 0
case "$SESSION_ID" in
  .*) exit 0 ;;
esac

STATE_DIR="${TRIPWIRE_STATE_DIR:-$HOME/.claude/.tripwire-versions}"
STATE_FILE="${STATE_DIR}/${SESSION_ID}"

PREV=""
if [ -f "$STATE_FILE" ]; then
  PREV="$(tr -d '\n' < "$STATE_FILE" 2>/dev/null || true)"
  # 変化なし = 何もしない（最頻経路をここで打ち切る）
  [ "$PREV" = "$VERSION" ] && exit 0
fi

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# 古い state の掃除。書き込み経路（セッション初回・バージョン変化時）でだけ走らせ、
# 毎プロンプトの fast path には find を持ち込まない。
find "$STATE_DIR" -maxdepth 1 -type f -mtime +30 -delete 2>/dev/null || true

# 状態ファイルは先に更新する。本文生成に失敗したときも次プロンプトで再試行しない
# （usage-probe の呼び出しが毎プロンプト走るのを避ける。fail-soft 側に倒す）。
printf '%s\n' "$VERSION" > "$STATE_FILE" 2>/dev/null || exit 0

# セッション初回（記録なし）は SessionStart が注入済み。記録だけで注入しない。
[ -n "$PREV" ] || exit 0

# --- バージョンが変わった → 再注入 ---
SESSION_HOOK="${ROOT}/scripts/session-tripwires.sh"
[ -x "$SESSION_HOOK" ] || exit 0
BODY="$("$SESSION_HOOK" 2>/dev/null || true)"
[ -n "$BODY" ] || exit 0

BODY="$BODY" PREV="$PREV" VERSION="$VERSION" python3 <<'PY'
import json, os

try:
    ctx = (json.loads(os.environ["BODY"]) or {}).get("additionalContext") or ""
except Exception:
    ctx = ""
if not ctx:
    raise SystemExit(0)

note = (
    "dev-workflow プラグインがこのセッションの途中で更新された"
    f"（{os.environ['PREV']} → {os.environ['VERSION']}）。"
    "以下は更新後の常駐ルールで、セッション開始時に読んだ内容より優先する。"
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": note + "\n\n" + ctx,
    }
}, ensure_ascii=False))
PY
exit 0
