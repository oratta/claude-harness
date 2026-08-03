#!/usr/bin/env bash
#
# install.sh — statusline.sh を Claude Code の設定ディレクトリに導入する。
#
#   1. plugins/statusline/scripts/statusline.sh を <config>/statusline.sh にコピー
#   2. <config>/settings.json の .statusLine をそのパスに向ける
#
# プラグイン本体ではなくコピーを配る理由:
#   - marketplace dir はプラグイン自動更新で再 clone される。そこを settings.json から
#     直接指すと、更新のたびにユーザーの色・幅の調整が消える
#   - cache dir はバージョンごとに path が変わるので settings.json から指せない
#   → 安定した <config>/statusline.sh に置く。更新時は再実行する
#
# 使い方:
#   install.sh              導入・更新する
#   install.sh --dry-run    何が変わるかだけ表示する（書き込まない）
#
# 環境変数:
#   CLAUDE_CONFIG_DIR   Claude Code の設定ディレクトリ（既定 ~/.claude）

set -uo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$PLUGIN_ROOT/scripts/statusline.sh"
DEST="$CONFIG_DIR/statusline.sh"
SETTINGS="$CONFIG_DIR/settings.json"
DESIRED_CMD="bash $DEST"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

[ -f "$SRC" ] || fail "スクリプト本体が見つからない: $SRC"
command -v jq >/dev/null 2>&1 || fail "jq が必要（statusline.sh 自体も jq に依存する）"
[ -d "$CONFIG_DIR" ] || fail "設定ディレクトリが無い: $CONFIG_DIR"

# ---- 1. スクリプトのコピー ----
script_action="up-to-date"
if [ ! -f "$DEST" ]; then
    script_action="install"
elif ! cmp -s "$SRC" "$DEST"; then
    script_action="update"
fi

# ---- 2. settings.json の statusLine ----
current_cmd=""
if [ -f "$SETTINGS" ]; then
    jq -e . "$SETTINGS" >/dev/null 2>&1 || fail "settings.json が壊れている（JSON として読めない）: $SETTINGS"
    current_cmd="$(jq -r '.statusLine.command // ""' "$SETTINGS")"
fi

settings_action="up-to-date"
if [ "$current_cmd" != "$DESIRED_CMD" ]; then
    if [ -z "$current_cmd" ]; then
        settings_action="set"
    else
        settings_action="replace"
    fi
fi

printf 'config dir : %s\n' "$CONFIG_DIR"
printf 'script     : %s (%s)\n' "$DEST" "$script_action"
printf 'statusLine : %s\n' "$settings_action"
[ -n "$current_cmd" ] && printf '  現在      : %s\n' "$current_cmd"
printf '  適用後    : %s\n' "$DESIRED_CMD"

if [ "$DRY_RUN" = "1" ]; then
    printf '\n(--dry-run のため何も書き込んでいない)\n'
    exit 0
fi

ts="$(date +%Y%m%d%H%M%S)"

if [ "$script_action" != "up-to-date" ]; then
    [ -f "$DEST" ] && cp "$DEST" "$DEST.bak-$ts"
    cp "$SRC" "$DEST" || fail "コピーに失敗: $DEST"
    chmod +x "$DEST"
fi

if [ "$settings_action" != "up-to-date" ]; then
    if [ -f "$SETTINGS" ]; then
        cp "$SETTINGS" "$SETTINGS.bak-$ts"
    else
        echo '{}' > "$SETTINGS"
    fi
    tmp="$(mktemp "${SETTINGS}.XXXXXX")" || fail "一時ファイルを作れない"
    if jq --arg cmd "$DESIRED_CMD" \
          '.statusLine = {type: "command", command: $cmd}' \
          "$SETTINGS" > "$tmp"; then
        mv -f "$tmp" "$SETTINGS"
    else
        rm -f "$tmp"
        fail "settings.json の更新に失敗（バックアップ: $SETTINGS.bak-$ts）"
    fi
fi

printf '\n完了。次のステータスライン再描画から反映される。\n'
if [ "$script_action" != "up-to-date" ] || [ "$settings_action" != "up-to-date" ]; then
    printf 'バックアップ接尾辞: .bak-%s\n' "$ts"
fi
