#!/usr/bin/env bash
# wt-create-hook.sh — WorktreeCreate hook
#
# Claude Code が worktree を作るタイミング（`--worktree` / Agent の isolation:"worktree"
# / background session）で発火し、**git の既定動作を置き換える**。
# worktree を自分で作り、そのまま wt-setup.sh まで済ませてから、作った絶対パスを stdout に返す。
#
# 契約（実測で確認済み・2026-07-28）:
#   stdin JSON:  {session_id, transcript_path, cwd, hook_event_name:"WorktreeCreate", name}
#                サブエージェント経由の場合は prompt_id が追加される。パスとブランチは渡ってこない。
#   cwd:         メインリポジトリ（worktree の親）
#   stdout:      作成した worktree の絶対パス（これが採用される）
#   exit code:   非ゼロ = worktree 作成そのものを失敗させる
#
# 既定動作の踏襲（フック無しの実測値）:
#   path=<repo>/.claude/worktrees/<name> / branch=worktree-<name> / locked
#   ここを変えると Claude Code 側の後片付け（worktree の探索・削除）と食い違うため踏襲する。
#
# 設計上の禁則: wt-setup.sh の失敗で worktree 作成を巻き添えにしないこと。
# セットアップは「あとから /wt-setup でやり直せる」が、worktree 作成失敗は作業自体を止めるため。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(cat)

# --- 入力の取り出し（python3 が無い環境でも死なないよう素の sed にフォールバック） ---
parse_field() {
  local key="$1"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
v = d.get('$key')
if isinstance(v, str):
    print(v)
" 2>/dev/null
  else
    printf '%s' "$INPUT" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}

NAME=$(parse_field name)
REPO=$(parse_field cwd)

[ -n "$REPO" ] || REPO="$PWD"

# name が取れない場合は worktree を一意にできないので、既定動作に戻す意味で失敗させる。
if [ -z "$NAME" ]; then
  echo "wt-create-hook: 'name' が入力に無いため worktree を作成できません" >&2
  exit 1
fi

# パス要素として危険な name は弾く（../ でリポジトリ外に出るのを防ぐ）
case "$NAME" in
  */*|*..*|"") echo "wt-create-hook: 不正な name: $NAME" >&2; exit 1 ;;
esac

cd "$REPO" 2>/dev/null || { echo "wt-create-hook: cd 失敗: $REPO" >&2; exit 1; }

WT_PATH="$REPO/.claude/worktrees/$NAME"
BRANCH="worktree-$NAME"

# --- worktree 作成（既存なら再利用） ---
if [ -d "$WT_PATH" ]; then
  # 既に存在する場合はそのまま使う（作り直すと作業中の内容を壊す）
  :
elif git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  # ブランチだけ先にある場合はそれをチェックアウトする
  git worktree add --lock "$WT_PATH" "$BRANCH" >&2 || {
    echo "wt-create-hook: 既存ブランチ $BRANCH の worktree 作成に失敗" >&2
    exit 1
  }
else
  git worktree add --lock -b "$BRANCH" "$WT_PATH" HEAD >&2 || {
    echo "wt-create-hook: worktree 作成に失敗: $WT_PATH" >&2
    exit 1
  }
fi

# パスが実在しないまま返すと Claude Code 側が壊れた worktree を掴むので、ここで検証する。
if [ ! -d "$WT_PATH" ]; then
  echo "wt-create-hook: 作成後も $WT_PATH が存在しません" >&2
  exit 1
fi

# --- wt-setup（ここから先の失敗は worktree 作成を巻き添えにしない） ---
if [ -x "$SCRIPT_DIR/wt-setup.sh" ] || [ -f "$SCRIPT_DIR/wt-setup.sh" ]; then
  ( cd "$WT_PATH" && bash "$SCRIPT_DIR/wt-setup.sh" ) >&2 2>&1 || \
    echo "wt-create-hook: wt-setup.sh が失敗しました（worktree 自体は作成済み。/wt-setup で再実行できます）" >&2
fi

# SessionStart 側の guard と二重実行しないための印。
GIT_DIR=$(git -C "$WT_PATH" rev-parse --git-dir 2>/dev/null || true)
[ -n "$GIT_DIR" ] && touch "$GIT_DIR/wt-setup-done" 2>/dev/null || true

echo "$WT_PATH"
