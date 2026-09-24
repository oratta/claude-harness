#!/usr/bin/env bash
# UserPromptSubmit hook: dev-workflow プラグインが「このセッションに最後に注入した
# 時点」から更新されたとき（CLAUDE_PLUGIN_ROOT が変わったとき）だけ、昇格
# トリップワイヤー＋残量モードを再注入する（issue #34 の縮小版）。
#
# なぜプラグインの更新だけを見るのか:
#   - compact 後の風化は SessionStart hook の matcher `startup|clear|compact` が
#     手動 /compact・自動 compact の両方で発火するため既に塞がっている
#   - 残る穴は「セッション生存中に /plugin marketplace update <name> や
#     /reload-plugins でプラグインを更新しても、SessionStart が再発火しないため
#     新ルールが届かない」だけ
#   したがって毎ターンの間引き再注入は過剰で、プラグインの更新を唯一のトリガにする。
#
# なぜ CLAUDE_PLUGIN_ROOT を比較するのか（issue #447）:
#   - plugin.json は version を持たない。版は Claude Code が commit SHA から決め、
#     キャッシュのパス（.../<plugin>/<版>/）に入る。パスの変化は旧方式の版の変化と
#     同じ事象を見ている
#   - CLAUDE_PLUGIN_ROOT が同じまま中身が変わる経路（--plugin-dir での開発中など）は
#     検知しない。旧方式でも版を変えない限り同じだった
#   - 旧方式の版番号が状態に残っていても一致しないので、1 回だけ再注入して移行する
#
# 契約:
#   - 状態はセッション単位で分離する（${TRIPWIRE_STATE_DIR}/<session_id>）。
#     worktree 並行セッションが互いの注入タイミングに引っ張られないため。
#     状態ディレクトリは CLAUDE_PLUGIN_ROOT の外なので、パスが変わっても引き継がれる。
#   - 状態ファイルが無い = そのセッションの初回プロンプト。SessionStart が直前に
#     注入済みなので記録だけして注入しない（二重注入の回避）。
#   - 記録済みの CLAUDE_PLUGIN_ROOT と一致 → 無出力で即 exit（毎プロンプト走るので
#     軽さ優先。この経路では python3 を起動せず、find による掃除も行わない）。
#   - 不一致 → session-tripwires.sh を呼んで本文を作り（本文の single source of
#     truth は templates/escalation-tripwires.md、生成ロジックは複製しない）、
#     hookSpecificOutput.additionalContext として出力する。
#   - 全経路 fail-soft（無出力・exit 0）。プロンプト送信は絶対にブロックしない。
set -uo pipefail

# hook 入力（JSON）を読む。読めなくても詰まらせない。
INPUT="$(cat 2>/dev/null || true)"

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$ROOT" ] || exit 0

# session_id は fast path で python3 を起動しないよう sed で抜く。壊れた JSON なら空になり、そのまま無出力で終わる。
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
  [ "$PREV" = "$ROOT" ] && exit 0
fi

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# 古い state の掃除。書き込み経路（セッション初回・プラグイン更新時）でだけ走らせ、
# 毎プロンプトの fast path には find を持ち込まない。
find "$STATE_DIR" -maxdepth 1 -type f -mtime +30 -delete 2>/dev/null || true

# 状態ファイルは先に更新する。本文生成に失敗したときも次プロンプトで再試行しない
# （usage-probe の呼び出しが毎プロンプト走るのを避ける。fail-soft 側に倒す）。
printf '%s\n' "$ROOT" > "$STATE_FILE" 2>/dev/null || exit 0

# セッション初回（記録なし）は SessionStart が注入済み。記録だけで注入しない。
[ -n "$PREV" ] || exit 0

# --- プラグインが更新された → 再注入 ---
SESSION_HOOK="${ROOT}/scripts/session-tripwires.sh"
[ -x "$SESSION_HOOK" ] || exit 0
BODY="$("$SESSION_HOOK" 2>/dev/null || true)"
[ -n "$BODY" ] || exit 0

BODY="$BODY" PREV="$PREV" ROOT="$ROOT" python3 <<'PY'
import json, os

# パスは長いので末尾のディレクトリ名（キャッシュの版名）だけ見せる。旧方式の版番号はそのまま出る。
def label(p):
    return os.path.basename(p.rstrip("/")) or p

try:
    ctx = (json.loads(os.environ["BODY"]) or {}).get("additionalContext") or ""
except Exception:
    ctx = ""
if not ctx:
    raise SystemExit(0)

note = (
    "dev-workflow プラグインがこのセッションの途中で更新された"
    f"（{label(os.environ['PREV'])} → {label(os.environ['ROOT'])}）。"
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
