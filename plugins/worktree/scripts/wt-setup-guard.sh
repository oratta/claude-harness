#!/usr/bin/env bash
# wt-setup-guard.sh — SessionStart hook（保険）
#
# `git worktree add` を人が直接叩いた worktree や、外部ツールが用意した worktree は
# WorktreeCreate hook を通らない。その取りこぼしをセッション開始時に拾う。
#
# 発火は毎セッションだが、**出力するのは未セットアップの worktree の初回だけ**。
# それ以外（メインリポ、git 外、セットアップ済み）は無出力で即終了し、会話に何も出さない。
#
# fail-soft 厳守: 何が起きても exit 0。セッション開始をブロックしない。
# （dev-workflow/scripts/session-tripwires.sh と同じ方針）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# stdin は読み捨てる（詰まり防止）
cat >/dev/null 2>&1 || true

# --- worktree 判定 ---
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || exit 0
case "$GIT_DIR" in
  */worktrees/*) ;;
  *) exit 0 ;;   # メインリポジトリ or git 外 → 無出力
esac

# git-dir は worktree 内では相対パスで返りうるので絶対化する
GIT_DIR=$(cd "$GIT_DIR" 2>/dev/null && pwd) || exit 0

MARKER="$GIT_DIR/wt-setup-done"
[ -f "$MARKER" ] && exit 0   # 済み → 無出力

# --- ここから初回のみ ---
SETUP_OUT=""
if [ -f "$SCRIPT_DIR/wt-setup.sh" ]; then
  SETUP_OUT=$(bash "$SCRIPT_DIR/wt-setup.sh" 2>&1) || true
fi

# 一度処理したら以降は黙る（ユーザーが .worktreeinclude を作らない方針でも鳴り続けないため）
touch "$MARKER" 2>/dev/null || true

# --- Claude に渡す残タスクを組み立てる ---
NOTES=""
if [ ! -f .worktreeinclude ]; then
  NOTES="${NOTES}
- \`.worktreeinclude\` が無いため gitignore 対象ファイル（.env 等）はコピーされていない。必要なら wt-setup スキルの Step 2 の手順で生成すること。"
fi
if printf '%s' "$SETUP_OUT" | grep -q 'NEEDS_NPM_INSTALL=true'; then
  NOTES="${NOTES}
- \`node_modules\` が無い。\`npm install\` の要否をユーザーに確認すること。"
fi

CONTEXT="[wt-setup] この worktree は未セットアップだったため、セッション開始時に wt-setup.sh を自動実行した（.claude/ の symlink と .worktreeinclude 対象ファイルのコピー）。

実行結果:
${SETUP_OUT}"

if [ -n "$NOTES" ]; then
  CONTEXT="${CONTEXT}

残っている判断:${NOTES}"
else
  CONTEXT="${CONTEXT}

残タスクなし。この件をユーザーに報告する必要はない。"
fi

# --- JSON で additionalContext を返す ---
if command -v python3 >/dev/null 2>&1; then
  CONTEXT="$CONTEXT" python3 -c '
import json, os
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": os.environ["CONTEXT"],
    }
}))
' 2>/dev/null || true
fi

exit 0
