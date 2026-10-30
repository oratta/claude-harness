#!/usr/bin/env bash
#
# synced-skills-name-only.sh — claude.ai から同期されたスキルを settings.json の
# skillOverrides で name-only にする（毎セッションの最初のリクエストから説明を外す）。
#
# 同期スキルの名前: <config>/skills/synced/<バケット>/<名>/SKILL.md の <名> に
# 固定の接頭辞を付けた anthropic-skills:<名> が skillOverrides のキー（Claude Code 2.1.314 の
# init イベントの skills 配列と本体の実装で確認。根拠は openspec の design.md）。
#
# 使い方:
#   synced-skills-name-only.sh              足すキーだけを足す（既存の値は変えない）
#   synced-skills-name-only.sh --dry-run    足すキーを表示するだけ（書き込まない）
#
# 環境変数: CLAUDE_CONFIG_DIR（既定 ~/.claude）

set -uo pipefail

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

DRY_RUN=0
case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=1 ;;
  *) fail "不明な引数: $1（使えるのは --dry-run だけ）" ;;
esac
[ "$#" -le 1 ] || fail "引数が多すぎる（使えるのは --dry-run だけ）"
command -v jq >/dev/null 2>&1 || fail "jq が必要"

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CONFIG_DIR/settings.json"

# 同期スキルの列挙（バケットが複数なら和集合）
names=()
if [ -d "$CONFIG_DIR/skills/synced" ]; then
  for bucket in "$CONFIG_DIR"/skills/synced/*/; do
    [ -d "$bucket" ] || continue
    for skill in "$bucket"*/; do
      [ -f "${skill}SKILL.md" ] || continue
      names+=("anthropic-skills:$(basename "$skill")")
    done
  done
fi
if [ "${#names[@]}" -eq 0 ]; then
  echo "同期スキルが無い（$CONFIG_DIR/skills/synced に SKILL.md を持つスキルが無い）ので、何も書かない"
  exit 0
fi
all="$(printf '%s\n' "${names[@]}" | sort -u | jq -R . | jq -s -c .)"

# 実体（symlink なら指す先）
target="$SETTINGS"
while [ -L "$target" ]; do
  link="$(readlink "$target")"
  case "$link" in /*) target="$link" ;; *) target="$(dirname "$target")/$link" ;; esac
done

if [ -e "$target" ]; then
  jq -e 'type == "object"' "$target" >/dev/null 2>&1 \
    || fail "settings.json が壊れている（JSON として読めない、または最上位がオブジェクトでない）: $SETTINGS"
  jq -e '(.skillOverrides // {}) | type == "object"' "$target" >/dev/null \
    || fail "skillOverrides がオブジェクトでない: $SETTINGS"
  current="$(cat "$target")"
else
  current='{}'
fi

# まだ無いキーだけ
add="$(printf '%s' "$current" | jq -r --argjson all "$all" '(.skillOverrides // {}) as $o | $all[] | select($o[.] == null)')"
kept="$(printf '%s' "$current" | jq -r --argjson all "$all" '(.skillOverrides // {}) as $o | $all[] | select($o[.] != null)')"

if [ -n "$kept" ]; then
  printf '既にあるので変えない:\n'; printf '  %s\n' $kept
fi
if [ -z "$add" ]; then
  echo "足すキーは無い。settings.json は変更しない"
  exit 0
fi
if [ "$DRY_RUN" -eq 1 ]; then
  printf '足す予定（name-only）:\n'; printf '  %s\n' $add
  echo "(--dry-run のため書き込まない)"
  exit 0
fi

dir="$(dirname "$target")"
mkdir -p "$dir"
if [ -e "$target" ]; then
  bak="$target.bak-$(date +%Y%m%d%H%M%S)"
  cp -p "$target" "$bak" || fail "バックアップを作れない: $bak"
fi
tmp="$(mktemp "$dir/.settings.json.XXXXXX")" || fail "一時ファイルを作れない"
if [ -e "$target" ]; then cp -p "$target" "$tmp" || { rm -f "$tmp"; fail "権限を写せない"; }; fi
if printf '%s' "$current" | jq --argjson all "$all" '.skillOverrides = ((.skillOverrides // {}) as $o | $o + ([$all[] | select($o[.] == null) | {(.): "name-only"}] | add // {}))' > "$tmp"; then
  mv -f "$tmp" "$target" || { rm -f "$tmp"; fail "置き換えに失敗した"; }
else
  rm -f "$tmp"; fail "jq の書き換えに失敗した"
fi
printf '足した（name-only）:\n'; printf '  %s\n' $add
[ -n "${bak:-}" ] && printf 'バックアップ: %s\n' "$bak"
exit 0
