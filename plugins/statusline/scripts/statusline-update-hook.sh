#!/usr/bin/env bash
#
# statusline-update-hook.sh — SessionStart フック（issue #1113）。
#
# /statusline:setup（install.sh）が <config>/ に置いたステータスラインのコピーを、
# プラグインの本体（$CLAUDE_PLUGIN_ROOT/scripts/）と比べる。<config> は ${CLAUDE_CONFIG_DIR:-~/.claude}。
#
#   コピーが無い                               → 何もしない
#   コピーが本体と同じ                         → 記録のその行を本体のハッシュにする
#   コピーが本体と違い、記録のハッシュと同じ   → 手を入れていないので本体で置き換える
#   コピーが本体と違い、記録と違う／記録が無い → 手を入れたので上書きしない。さらに本体が記録から
#                                                変わっている（記録が無いときを含む）なら
#                                                <config>/.statusline-update-available に名前を書く
#
# 記録は install.sh が書く <config>/.statusline-installed（`<sha256>  <ファイル名>` を 1 行 1 件）。
# statusline.sh は印があれば 1 行目の末尾に「更新あり /statusline:setup」を出す。印を読めない古い
# コピーのときだけ、ここから systemMessage で同じ案内を出す。
#
# 動くのは、インストール済みのプラグイン（実体のパスが <config>/plugins/ の下）から起動されたとき
# だけ。claude --plugin-dir で読み込んだ開発中の版で、利用者のコピーを置き換えないため。
# さらに、その場所が <config>/plugins/installed_plugins.json に statusline の installPath として
# 載っている（いまインストールされている版）ときだけ動く。プラグイン更新より前から開いている
# セッションの CLAUDE_PLUGIN_ROOT は古い版のディレクトリを指したままなので、そこから走ったフックが
# 新しい版に揃えたコピーを古い版に巻き戻さないため。installed_plugins.json が読めない・jq が無い
# ときも何もしない。
#
# どの失敗でも exit 0 で終わり、標準エラーには何も出さない（SessionStart の 0 以外の終了は画面に出る）。
# 標準出力は、案内を出すときの JSON 1 行だけ（JSON 以外はモデルの文脈に入る）。python3 は起動しない。

exec 2>/dev/null

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$ROOT" ] || exit 0

root_real="$(cd -P "$ROOT" && pwd -P)" || exit 0
plugins_real="$(cd -P "$CONFIG_DIR/plugins" && pwd -P)" || exit 0
[ -n "$root_real" ] && [ -n "$plugins_real" ] || exit 0
case "$root_real/" in
    "$plugins_real/"*) ;;
    *) exit 0 ;;
esac

# いまインストールされている版か（installPath の実体のパスと比べる）
command -v jq >/dev/null 2>&1 || exit 0
current=""
while IFS= read -r p; do
    [ -n "$p" ] || continue
    p_real="$(cd -P "$p" && pwd -P)" || continue
    if [ "$p_real" = "$root_real" ]; then
        current=1
        break
    fi
done <<EOF2
$(jq -r '.plugins // {} | to_entries[] | select(.key | startswith("statusline@")) | .value[]? | .installPath // empty' "$CONFIG_DIR/plugins/installed_plugins.json")
EOF2
[ -n "$current" ] || exit 0

RECORD="$CONFIG_DIR/.statusline-installed"
MARK="$CONFIG_DIR/.statusline-update-available"

sha256_of() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    fi
}
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || exit 0

# 記録のうち、ファイル名 $1 の行のハッシュ（無ければ空）
recorded_hash() {
    [ -f "$RECORD" ] || return 0
    awk -v f="$1" '$2 == f && $1 ~ /^[0-9a-f]+$/ && length($1) == 64 { print $1; exit }' "$RECORD"
}

# $1=本体 $2=コピー $3=権限。同じディレクトリの一時ファイルから置き換える。
replace_copy() {
    local tmp
    tmp="$(mktemp "$2.XXXXXX")" || return 1
    if cp "$1" "$tmp" && chmod "$3" "$tmp" && mv -f "$tmp" "$2"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

flagged=""
new_script_hash=""
new_helper_hash=""

for entry in "statusline.sh:755" "statusline-codex.py:644"; do
    name="${entry%%:*}"
    mode="${entry##*:}"
    copy="$CONFIG_DIR/$name"
    src="$root_real/scripts/$name"
    rec="$(recorded_hash "$name")"
    new="$rec"
    if [ -f "$copy" ] && [ -f "$src" ]; then
        copy_hash="$(sha256_of "$copy")"
        src_hash="$(sha256_of "$src")"
        if [ -z "$copy_hash" ] || [ -z "$src_hash" ]; then
            :
        elif [ "$copy_hash" = "$src_hash" ]; then
            new="$src_hash"
        elif [ -n "$rec" ] && [ "$copy_hash" = "$rec" ]; then
            if replace_copy "$src" "$copy" "$mode"; then
                new="$src_hash"
            fi
        elif [ -z "$rec" ] || [ "$src_hash" != "$rec" ]; then
            flagged="${flagged}${name}"$'\n'
        fi
    fi
    if [ "$name" = "statusline.sh" ]; then
        new_script_hash="$new"
    else
        new_helper_hash="$new"
    fi
done

# 記録を書き直す（変わったときだけ）
body=""
[ -n "$new_script_hash" ] && body="${body}${new_script_hash}  statusline.sh"$'\n'
[ -n "$new_helper_hash" ] && body="${body}${new_helper_hash}  statusline-codex.py"$'\n'
if [ -n "$body" ] && [ "${body%$'\n'}" != "$(cat "$RECORD" 2>/dev/null)" ]; then
    tmp="$(mktemp "$RECORD.XXXXXX")" \
        && { printf '%s' "$body" > "$tmp" && mv -f "$tmp" "$RECORD" || rm -f "$tmp"; }
fi

# 印を置くか消す
if [ -n "$flagged" ]; then
    tmp="$(mktemp "$MARK.XXXXXX")" \
        && { printf '%s' "$flagged" > "$tmp" && mv -f "$tmp" "$MARK" || rm -f "$tmp"; }
    if ! grep -qF '.statusline-update-available' "$CONFIG_DIR/statusline.sh"; then
        printf '%s\n' '{"systemMessage":"ステータスラインのコピーに更新があります（手を入れたコピーなので自動では上書きしません）。/statusline:setup で更新できます"}'
    fi
else
    rm -f "$MARK"
fi

exit 0
