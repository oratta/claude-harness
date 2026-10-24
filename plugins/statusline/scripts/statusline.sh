#!/usr/bin/env bash
#
# statusline.sh — Claude Code の使用量ステータスライン
#
#   1行目: カレントディレクトリ / モデル / git ブランチ
#          （<config>/.statusline-update-available があれば末尾に「更新あり /statusline:setup」。
#           印は statusline プラグインの SessionStart フックが置く）
#   2行目: コンテキスト残量 / プロンプトキャッシュのヒット率（直近のミスの原因つき） /
#          API 換算の月額ペース / このセッションの API 換算コスト
#   3行目: 5h ウィンドウのレートリミット
#   4行目: 7d ウィンドウ（全体 + Fable）のレートリミット
#
# プログレスバーの読み方:
#   セルの背景色 = クォータの消化率（バー本体）
#   セル下端 1/8 の細線（前景色） = その窓の日程消化率（今どこまで来たか）
#   数値は「クォータ消化率/日程消化率」。分母＝細線の位置。
#
# 線の先までバーが伸びていなければ日程が先行 = 使いたい時に余裕がある。
# 線を追い越していたらリセット前に枯れるペース。
#
# <config>/.headroom.json（dev-workflow の headroom.py が書く schema 1）があれば読み、値を使える
# アカウントの行では、リセット権で増えた使える量（ロケットモード 🚀）とリセット権の数（🚀×N）を描く。
# 値を数え直さず、無い・使えないときは今の描き方のまま。正本は openspec の
# statusline-multi-account-usage「`.headroom.json` の値を使えるアカウントを決める」から始まる要件。
#
# 環境変数（すべて任意）:
#   STATUSLINE_CODEX       0 で Codex アカウント行を無効化（既定 1）
#   STATUSLINE_CODEX_BIN   Codex CLI のパス（既定 codex）
#   STATUSLINE_BAR_WIDTH   バーのセル数（既定 16）
#   STATUSLINE_BAR_GLYPH   日程線の太さ。細い順に ▁ ▂ ▃ ▄（既定 ▂）
#   STATUSLINE_PROMPT_CACHE 0 でプロンプトキャッシュのヒット率表示を無効化（既定 1）
#   STATUSLINE_API_PACE    0 で API 換算コスト表示を無効化（既定 1）
#   STATUSLINE_SESSION_COST 0 でセッションコスト表示を無効化（既定 1）
#   STATUSLINE_CURRENCY    API 換算コストの通貨。USD なら為替変換なし（既定 JPY）
#   CLAUDE_CONFIG_DIR      Claude Code の設定ディレクトリ（既定 ~/.claude）

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
session_id=$(printf '%s' "$input" | jq -c '.session_id | select(type == "string" and length > 0)' 2>/dev/null)
session_cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# ---------------------------------------------------------------------------
# 可搬性ヘルパー（macOS の BSD 系と Linux の GNU 系の両方で動かす）
# ---------------------------------------------------------------------------

# $1=パス → mtime(epoch)。取れなければ 0
file_mtime() {
    # GNU（-c）を先に試す。逆順だと Linux で `stat -f` がファイルシステム情報の表示として
    # 成功し、mtime ではない値を返す（usage-probe.sh と同じ理由）。
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# $1=日数 → N日前の YYYYMMDD
days_ago() {
    date -v-"$1"d +%Y%m%d 2>/dev/null || date -d "$1 days ago" +%Y%m%d 2>/dev/null
}

# ccusage を叩けるランナー（bunx → npx）を探す。無ければ空
pkg_runner() {
    local c
    for c in bunx "$HOME/.bun/bin/bunx" npx; do
        command -v "$c" >/dev/null 2>&1 && { printf '%s' "$c"; return; }
    done
}

# Rate snapshot writer contract: openspec/specs/rate-snapshot.
# A separate file per host lets the shared copy coexist with other PCs.
resolve_rate_share_dir() {
    local dir conf tilde='~' have_dir=""
    # Order: CLAUDE_RATE_SHARE_DIR, FLATMATE_RATE_SHARE_DIR, CLAUDE_RATE_SHARE_CONF, FLATMATE_RATE_SHARE_CONF.
    # The FLATMATE_* names are the old names, still read for compatibility; the CLAUDE_* names are primary.
    if [ "${CLAUDE_RATE_SHARE_DIR+x}" ]; then
        dir="$CLAUDE_RATE_SHARE_DIR"; have_dir=1
    elif [ "${FLATMATE_RATE_SHARE_DIR+x}" ]; then
        dir="$FLATMATE_RATE_SHARE_DIR"; have_dir=1  # old name, compatibility; the primary name is CLAUDE_RATE_SHARE_DIR
    fi
    if [ -n "$have_dir" ]; then
        # Trim the whole string (sed works per line and would keep a leading LF); no python3 here.
        dir="${dir#"${dir%%[![:space:]]*}"}"
        dir="${dir%"${dir##*[![:space:]]}"}"
    else
        dir=""
        # The old-name conf (compatibility) is read only when the primary one yields no line.
        for conf in "${CLAUDE_RATE_SHARE_CONF:-$HOME/.claude/rate-share}" \
                    "${FLATMATE_RATE_SHARE_CONF:-$HOME/.claude/flatmate-rate-share}"; do
            if [ -f "$conf" ]; then
                dir=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$conf" 2>/dev/null \
                    | grep -v -e '^$' -e '^#' | head -1)
            fi
            [ -n "$dir" ] && break
        done
    fi
    case "$dir" in
        "$tilde") dir="$HOME" ;;
        "$tilde"/*) dir="$HOME/${dir#??}" ;;
    esac
    printf '%s' "$dir"
}

write_rate_snapshot_atomic() {
    local dest="$1" body="$2" tmp
    tmp=$(mktemp "$(dirname "$dest")/.rate-snapshot.XXXXXX" 2>/dev/null) || return 1
    # mktemp makes the file 0600; restore the 0644 a plain redirect gets under the usual umask.
    # chmod runs before mv so a reader never sees the 0600 file at the destination.
    if ! printf '%s\n' "$body" > "$tmp" 2>/dev/null \
        || ! { chmod 0644 "$tmp" 2>/dev/null || true; } \
        || ! mv -f "$tmp" "$dest" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
}

# The default account alone owns the local and shared rate snapshot.
if [ -n "$five_h_pct" ] && [ -n "$session_id" ] && [ -z "${CLAUDE_SECURESTORAGE_CONFIG_DIR:-}" ]; then
    snap_local="$CONFIG_DIR/.rate-limit-snapshot"
    now_epoch=$(date +%s)
    snap_5r="${five_h_resets:-null}"
    snap_7p="${seven_d_pct:-null}"
    snap_7r="${seven_d_resets:-null}"
    storage_binding="storage-v1:default"
    obs_sig="${five_h_pct}|${snap_5r}|${snap_7p}|${snap_7r}"
    observed_at="$now_epoch"
    if [ -f "$snap_local" ]; then
        prev_obs=$(jq -r --arg sig "$obs_sig" --arg binding "$storage_binding" \
            --argjson session "$session_id" \
            'select(.obs_sig == $sig and .storage_binding == $binding and .session_id == $session) |
             .observed_at | select(type == "number")' "$snap_local" 2>/dev/null)
        [ -z "$prev_obs" ] || observed_at="$prev_obs"
    fi

    snap_host=$(hostname -s 2>/dev/null) || snap_host=""
    snap_host_key=$(printf '%s' "$snap_host" | jq -Rr 'gsub("[^A-Za-z0-9._-]"; "_")' 2>/dev/null)
    [ -n "$snap_host_key" ] || snap_host_key="unknown"

    # Only the account UUID field is read; invalid or unavailable IDs are omitted.
    account_id=""
    if [ -f "$HOME/.claude.json" ]; then
        account_id=$(jq -r '
            .oauthAccount.accountUuid | select(type == "string") |
            gsub("^[[:space:]]+|[[:space:]]+$"; "") |
            select(length > 0 and length <= 256 and (test("[\r\n]") | not))
        ' "$HOME/.claude.json" 2>/dev/null)
    fi
    snap_body=$(jq -cn --arg account "$account_id" \
        --argjson observed "$observed_at" --argjson written "$now_epoch" \
        --arg sig "$obs_sig" --arg host "$snap_host_key" \
        --arg binding "$storage_binding" --argjson session "$session_id" \
        --argjson five_pct "$five_h_pct" --argjson five_resets "$snap_5r" \
        --argjson seven_pct "$snap_7p" --argjson seven_resets "$snap_7r" \
        '{ts:$observed,observed_at:$observed,written_at:$written,obs_sig:$sig,
          host:$host,storage_binding:$binding,session_id:$session,
          five_hour_pct:$five_pct,five_hour_resets_at:$five_resets,
          seven_day_pct:$seven_pct,seven_day_resets_at:$seven_resets}
         + (if $account == "" then {} else {account_id:$account} end)' 2>/dev/null)

    if [ -n "$snap_body" ]; then
        mkdir -p "$(dirname "$snap_local")" 2>/dev/null
        write_rate_snapshot_atomic "$snap_local" "$snap_body" || true
        share_dir=$(resolve_rate_share_dir)
        if [ -n "$share_dir" ] && mkdir -p "$share_dir" 2>/dev/null; then
            write_rate_snapshot_atomic "$share_dir/$snap_host_key.json" "$snap_body" || true
        fi
    fi
fi

# 起動アカウント別のセッション記録（正本: openspec/specs/usage-session-records）。
# 鍵は起動環境の CLAUDE_SECURESTORAGE_CONFIG_DIR だけから決める（レジストリや snapshot の
# active から決めると別アカウントの値を別スロットとして書きうる。flatmate#605 と同じ誤り）。
# 空なら default、非空なら Keychain サービス名の末尾と同じ sha256 先頭 8 桁。
# python3 を起動するのは非空のときだけ（既定アカウントの 1 スロット構成で起動を増やさない）。
session_key="default"
if [ -n "${CLAUDE_SECURESTORAGE_CONFIG_DIR:-}" ]; then
    session_key="$(SECURE="$CLAUDE_SECURESTORAGE_CONFIG_DIR" python3 -c '
import hashlib, os, unicodedata
print(hashlib.sha256(unicodedata.normalize("NFC", os.environ["SECURE"]).encode("utf-8")).hexdigest()[:8])
' 2>/dev/null)"
fi
sessions_dir="${USAGE_SESSIONS_DIR:-$CONFIG_DIR/.usage-sessions}"
# observed_at は「そのセッションが値を新しく受け取った時刻」（#643）。Claude Code は API 応答以外
# （モード切り替え・キャッシュ期限切れ等）でも描き直し、そのときの rate_limits は前に受け取った値の
# ままなので、セッションごとに前回書いた値の署名を .sessions/<session_id を JSON 文字列として引用符付きのまま sha256 した先頭 16 桁> に
# 覚え、同じなら書かない。記録ファイルの中身とは比べない（他セッションが上書きした新しい値を、
# 止まっていたセッションの古い値で潰さないため。.rate-limit-snapshot の obs_sig と同じ考え方）。
# session_id が無い・ハッシュが取れないときは覚える先が無いので毎回書く。
# rate_limits の無い描画は記録を書かないので、ハッシュも取らない（使わない shasum と cut を起動しない。#648）。
_rec_sig="${five_h_pct}|${five_h_resets:-null}|${seven_d_pct:-null}|${seven_d_resets:-null}"
_rec_memo=""
if [ -n "$five_h_pct" ] && [ -n "$session_id" ]; then
    # ハッシュ対象は jq -c の引用符付き JSON 文字列のまま。python3 を起動しない
    _rec_sid_hash="$( { printf '%s' "$session_id" | shasum -a 256 2>/dev/null \
        || printf '%s' "$session_id" | sha256sum 2>/dev/null; } | cut -c1-16)"
    [[ "$_rec_sid_hash" =~ ^[0-9a-f]{16}$ ]] && _rec_memo="$sessions_dir/.sessions/$_rec_sid_hash"
fi
_rec_unchanged=""
if [ -n "$_rec_memo" ] && [ -f "$_rec_memo" ] && [ "$(cat "$_rec_memo" 2>/dev/null)" = "$_rec_sig" ]; then
    _rec_unchanged=1
fi
if [ -n "$five_h_pct" ] && [ -n "$session_key" ] && [ -z "$_rec_unchanged" ] && mkdir -p "$sessions_dir" 2>/dev/null; then
    # 一時ファイルに書いてから mv で置き換える（読み手に書きかけを見せない）。失敗は無視する
    _rec_tmp="$(mktemp "$sessions_dir/.${session_key}.XXXXXX" 2>/dev/null)"
    _rec_written=""
    if [ -n "$_rec_tmp" ]; then
        if printf '{"schema":1,"key":"%s","observed_at":%s,"five_hour_pct":%s,"five_hour_resets_epoch":%s,"weekly_all_pct":%s,"weekly_resets_epoch":%s}\n' \
            "$session_key" "$(date +%s)" "$five_h_pct" "${five_h_resets:-null}" \
            "${seven_d_pct:-null}" "${seven_d_resets:-null}" > "$_rec_tmp" 2>/dev/null \
            && mv -f "$_rec_tmp" "$sessions_dir/${session_key}.json" 2>/dev/null; then
            _rec_written=1
        else
            rm -f "$_rec_tmp" 2>/dev/null
        fi
    fi
    # 書けたら署名を覚え直す。覚える側の失敗は無視する（出力を変えない）。7 日より古い覚えは消す
    if [ -n "$_rec_written" ] && [ -n "$_rec_memo" ] && mkdir -p "${_rec_memo%/*}" 2>/dev/null; then
        _memo_tmp="$(mktemp "${_rec_memo%/*}/.tmp.XXXXXX" 2>/dev/null)"
        if [ -n "$_memo_tmp" ]; then
            { printf '%s\n' "$_rec_sig" > "$_memo_tmp" && mv -f "$_memo_tmp" "$_rec_memo"; } 2>/dev/null \
                || rm -f "$_memo_tmp" 2>/dev/null
        fi
        find "${_rec_memo%/*}" -type f -mtime +7 -delete 2>/dev/null
    fi
fi

# ANSI color codes (dimmed for status line)
BLUE=$(printf '\033[34m')
GREEN=$(printf '\033[32m')
CYAN=$(printf '\033[36m')
YELLOW=$(printf '\033[33m')
RED=$(printf '\033[31m')
DIM=$(printf '\033[2m')
RESET=$(printf '\033[0m')
# ロケットモード（.headroom.json）の色。214 と 203 は usage_color_num の黄と赤と同じ番号
ROCKET_NAME=$(printf '\033[1;38;5;16;48;5;214m')   # 名前の地: 太字・黒字・オレンジの地
ROCKET_FG=$(printf '\033[38;5;214m')
ROCKET_RED=$(printf '\033[38;5;203m')

# Shorten directory path (similar to Prezto's prompt-pwd)
if [[ "$cwd" == "$HOME"* ]]; then
    short_pwd="~${cwd#$HOME}"
else
    short_pwd="$cwd"
fi

# Shorten if path is too long (keep last 3 segments)
IFS='/' read -ra ADDR <<< "$short_pwd"
len=${#ADDR[@]}
if [ $len -gt 4 ]; then
    short_pwd=".../${ADDR[$((len-3))]}/${ADDR[$((len-2))]}/${ADDR[$((len-1))]}"
fi

# Get git branch if in git repo (skip locks for performance)
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check for modifications
        if ! git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null; then
            git_status="${BLUE}✱${RESET}"
        else
            git_status=""
        fi
        git_info=" ${GREEN}${branch}${RESET}${git_status}"
    fi
fi

# Context window indicator
context_info=""
if [ -n "$remaining_pct" ]; then
    remaining_int=$(printf "%.0f" "$remaining_pct")
    if [ "$remaining_int" -lt 20 ]; then
        context_color="$RED"
    elif [ "$remaining_int" -lt 50 ]; then
        context_color="$YELLOW"
    else
        context_color="$GREEN"
    fi
    context_info="${context_color}Context ${remaining_int}%${RESET}"
fi

# プロンプトキャッシュのヒット率（stdin の prompt_cache だけを見る。ファイル・ネットワークには触らない）。
# hit_ratio が 0〜1 の数値のときだけ出す。直近のミスの原因は causes の先頭を短くして添える。
# 入力の型が想定外でも式全体は落とさず、jq 自体が失敗したら何も出さない。
cache_info=""
if [ "${STATUSLINE_PROMPT_CACHE:-1}" != "0" ]; then
    cache_raw=$(printf '%s' "$input" | jq -r '
        (.prompt_cache // null) as $p
        | if ($p | type) == "object" and ($p.hit_ratio | type) == "number"
             and $p.hit_ratio >= 0 and $p.hit_ratio <= 1
          then
            (($p.last_miss_cause // null) as $m
             | if ($m | type) == "object" and ($m.causes | type) == "array"
                  and ($m.causes | length) > 0 and ($m.causes[0] | type) == "string"
                  and ($m.causes[0] | test("^[A-Za-z0-9_]+\\z"))
               then
                 ($m.causes[0]) as $c
                 | ({"tools_changed": "tools", "system_prompt_changed": "system",
                     "ttl_expired_5m": "ttl5m", "likely_server_side": "server"}[$c] // $c[0:16]) as $n
                 | "miss:" + $n + (if ($m.causes | length) > 1 then "+" + (($m.causes | length) - 1 | tostring) else "" end)
               else "" end) as $cause
            | (($p.hit_ratio * 100 | round | tostring) + (if $cause != "" then " " + $cause else "" end))
          else empty end' 2>/dev/null) || cache_raw=""
    if [ -n "$cache_raw" ]; then
        cache_info="${CYAN}Cache ${cache_raw%% *}%${RESET}"
        case "$cache_raw" in
            *" "*) cache_info="${cache_info} ${YELLOW}${cache_raw#* }${RESET}" ;;
        esac
    fi
fi

# ---------------------------------------------------------------------------
# プログレスバー
# ---------------------------------------------------------------------------
BAR_WIDTH="${STATUSLINE_BAR_WIDTH:-16}"
BAR_GLYPH="${STATUSLINE_BAR_GLYPH:-▂}"
# active アカウントの行に付ける目印。East Asian Width が Neutral の記号でなければならない
# （正本: openspec/specs/statusline-multi-account-usage「active スロットの行を視覚的に示す」）。
# 見た目の似た ▶ U+25B6 / ● U+25CF / ◆ U+25C6 / · U+00B7 はいずれも Ambiguous で、
# 曖昧幅を全角にする端末では active 行の行頭だけが 1 桁広がり、その差が label 以降の
# すべての列に伝播する。差し替えるなら N の記号（▹ U+25B9 / › U+203A 等）にすること。
# 環境変数で変えられるようにしていないのは、この制約を破る値を選べてしまうため。
ACTIVE_MARK="▸"
C_EMPTY_N=238      # バー本体の未消化部分
C_TRACK_N=252      # 日程の線
C_SPARE_N=24       # 使える量が 100% を超えたとき、足した分の空き（ロケットモード）

# バーの色番号。日程消化率が分かる窓（7d）は「日程に対して先行しているか」で判定する。
# バー先端が日程線を追い越すと警告色になり、見た目と色の意味が一致する。
# 日程が取れない窓（5h はセッション頭で一気に使うのが普通）は残量の絶対値で判定。
# $1=消化率(整数) $2=日程消化率(整数, 空可)
usage_color_num() {
    local pct=$1 elapsed=$2 p
    if [ -n "$elapsed" ] && [ "$elapsed" -gt 0 ]; then
        p=$(( pct * 100 / elapsed ))
        if [ "$p" -ge 100 ]; then printf '203'
        elif [ "$p" -ge 85 ]; then printf '214'
        else printf '78'; fi
    else
        if [ "$pct" -ge 80 ]; then printf '203'
        elif [ "$pct" -ge 50 ]; then printf '214'
        else printf '78'; fi
    fi
}

# $1=消化率(整数) $2=日程消化率(整数, 空可) $3=バー色番号
# $4=使える量(%。省略時 100) → バー文字列
# 使える量が 100 を超えるときは、その 100% に当たるセル（BAR_WIDTH × 100 ÷ 使える量 を切り捨て）以降の
# 塗られていないセルの背景を C_SPARE_N にする（足した分の空き）。100 のときは今と 1 バイトも変わらない。
bar2() {
    local pct=$1 elapsed=$2 un=$3 cap=${4:-100}
    local spare=$BAR_WIDTH
    [ "$cap" -gt 100 ] && spare=$(( BAR_WIDTH * 100 / cap ))
    local fill=$(( pct * BAR_WIDTH / 100 ))
    # 1% でも存在が見えるように最低1セル
    [ "$pct" -gt 0 ] && [ "$fill" -eq 0 ] && fill=1
    [ "$fill" -gt "$BAR_WIDTH" ] && fill=$BAR_WIDTH
    local mark=0
    if [ -n "$elapsed" ]; then
        mark=$(( elapsed * BAR_WIDTH / 100 ))
        # 窓の頭（7d なら最初の約10時間）でも線が消えないように最低1セル
        [ "$elapsed" -gt 0 ] && [ "$mark" -eq 0 ] && mark=1
        [ "$mark" -gt "$BAR_WIDTH" ] && mark=$BAR_WIDTH
    fi
    local out="" i bgn fgn
    for (( i = 0; i < BAR_WIDTH; i++ )); do
        if [ "$i" -lt "$fill" ]; then bgn=$un
        elif [ "$i" -ge "$spare" ]; then bgn=$C_SPARE_N
        else bgn=$C_EMPTY_N; fi
        # 日程が未到達のセルは線色を背景と同色にして線を消す
        if [ "$i" -lt "$mark" ]; then fgn=$C_TRACK_N; else fgn=$bgn; fi
        out+=$'\033[38;5;'"${fgn}"$'m\033[48;5;'"${bgn}"'m'"$BAR_GLYPH"
    done
    printf '%s%s' "$out" "$RESET"
}

# $1=残り秒 → "~4h 46m" / 1日以上なら "~2d 14h"
fmt_left() {
    local s=$1
    if [ "$s" -ge 86400 ]; then
        printf '~%dd %dh' $(( s / 86400 )) $(( (s % 86400) / 3600 ))
    else
        printf '~%dh %dm' $(( s / 3600 )) $(( (s % 3600) / 60 ))
    fi
}

# $1=ラベル $2=ラベル幅 $3=消化率 $4=日程消化率(空可) $5=分母表示(1で "◯◯%/△△%")
# $6=ロケットモードのための列を空けるなら 1（空なら今のまま）
# $7=🚀 の列の中身（表示幅 4。空なら半角スペース 4 つ） $8=使える量の列（空なら列なし、
#   "-" なら半角スペース 9 つ、それ以外はその文字列をバーの色で右寄せ 9 桁） $9=使える量(%。省略時 100)
#   → "ラベル バー ◯◯%/△△%"
# 分母は日程消化率。バー下端の線と同じ色にして、線の位置＝分母だと目で繋がるようにする。
# 列を空けるときはラベルの欄を 7 桁にして 🚀 の列を置き、使える量の列がある行は割合を %5d で描く
# （正本: statusline-multi-account-usage「ロケットモードのための列を空ける」）。
bar_seg() {
    local un
    un=$(usage_color_num "$3" "$4")
    if [ "$6" = "1" ]; then
        printf '%s%-*s%s%s%s' "$DIM" 7 "$1" "$RESET" "${7:-    }" "$(bar2 "$3" "$4" "$un" "${9:-100}")"
        if [ -z "$8" ]; then
            printf ' \033[38;5;%sm%3d%%%s' "$un" "$3" "$RESET"
        else
            if [ "$8" = "-" ]; then
                printf '%9s' ''
            else
                printf '%*s\033[38;5;%sm%s%s' "$(( 9 - ${#8} ))" '' "$un" "$8" "$RESET"
            fi
            printf '\033[38;5;%sm%5d%%%s' "$un" "$3" "$RESET"
        fi
    else
        printf '%s%-*s%s%s \033[38;5;%sm%3d%%%s' \
            "$DIM" "$2" "$1" "$RESET" \
            "$(bar2 "$3" "$4" "$un")" \
            "$un" "$3" "$RESET"
    fi
    if [ "$5" = "1" ] && [ -n "$4" ]; then
        printf '%s/%s\033[38;5;%sm%d%%%s' "$DIM" "$RESET" "$C_TRACK_N" "$4" "$RESET"
    fi
}

# $1=経過秒 → "45m前" / "2h前" / "3d前"
fmt_ago() {
    local s=$1
    # 時計ずれや未来の fetched_at で負になることがある（"-2m前" を描かせない）
    [ "$s" -lt 0 ] && s=0
    if [ "$s" -lt 3600 ]; then
        printf '%dm前' $(( s / 60 ))
    elif [ "$s" -lt 86400 ]; then
        printf '%dh前' $(( s / 3600 ))
    else
        printf '%dd前' $(( s / 86400 ))
    fi
}

# $1=残数 $2=最短期限 epoch（無ければ 0）→ 色付きの "リセットN回・最短あとXdYh"（Codex と Claude の行で共用）
# 期限まで 24 時間以内は赤、3 日以内は黄。残数 0 のときは期限を付けない。
fmt_reset_credits() {
    local count="$1" exp="$2" color="$DIM" text left
    text="リセット${count}回"
    if [ "$count" -gt 0 ]; then
        if [ "$exp" -eq 0 ]; then
            text+="・期限不明"
        else
            left=$(( exp - now ))
            if [ "$left" -le 86400 ]; then color="$RED"
            elif [ "$left" -le 259200 ]; then color="$YELLOW"; fi
            if [ "$left" -le 0 ]; then
                text+="・期限経過（更新待ち）"
            elif [ "$left" -ge 86400 ]; then
                text+="・最短あと$((left / 86400))日$((left % 86400 / 3600))h"
            else
                text+="・最短あと$((left / 3600))h$((left % 3600 / 60))m"
            fi
        fi
    fi
    printf '%s%s%s' "$color" "$text" "$RESET"
}

# $1=tickets.count（空可） $2=tickets.earliest_expiry epoch（空可） $3=claude-rocket / codex-rocket / plain
#   → 区切りに続けた "🚀×N ~1d 20h"（.headroom.json の値を使えるアカウントの右端の区画）。
# 色はロケットモードの Claude が 214（失効まで 24 時間以内は 203）、ロケットモードの Codex が 214、
# ロケットモードでないアカウントは DIM。Codex のロケットモードは左の残り時間と重なるので時間を付けない。
# 残数が無い・0 なら何も出さない（正本: statusline-multi-account-usage「リセット権の区画を 🚀 と数で描く」）。
fmt_rocket_tickets() {
    local n="$1" exp="$2" kind="$3" color="$DIM" text left
    [ -n "$n" ] && [ "$n" -gt 0 ] || return 0
    text="🚀×${n}"
    [ "$kind" = "plain" ] || color="$ROCKET_FG"
    [ "$kind" = "codex-rocket" ] && exp=""
    if [ -n "$exp" ]; then
        left=$(( exp - now ))
        text+=" $(fmt_left "$left")"
        [ "$kind" = "claude-rocket" ] && [ "$left" -le 86400 ] && color="$ROCKET_RED"
    fi
    printf '  %s│%s  %s%s%s' "$DIM" "$RESET" "$color" "$text" "$RESET"
}

# $1=rocket.count → 🚀 の列の中身（表示幅 4。1 なら "🚀  "、2 以上なら "🚀2 " のように数を付ける）
rocket_cell() {
    local n="$1" cell="🚀" w=2
    if [ "$n" -gt 1 ]; then cell+="$n"; w=$(( 2 + ${#n} )); fi
    [ "$w" -lt 4 ] && cell+="$(printf '%*s' $(( 4 - w )) '')"
    printf '%s' "$cell"
}

# Usage (rate limit) indicator — Pro/Max only; fields absent otherwise
now=$(date +%s)
usage_lines=()
usnap="$CONFIG_DIR/.usage-snapshot"

# ---- アカウントレジストリ（不在なら既定スロット 1 つ = 現行と同じ挙動） ----
# 読み取り規則の正本は openspec/specs/usage-account-registry。トップレベルはオブジェクト、
# id は英数字とハイフン 1〜32 文字で一意、先頭 8 スロットまで、不正なら既定スロットへ縮退。
# dev-workflow の usage-probe.sh と同じ規則だが、プラグインを跨ぐ依存を作らないため
# 実装は各スクリプトに置く（規則の正本は spec 側）。
# enabled が JSON の false のスロットは「オフ」（slot_enabled が 0）。オフのスロットも一覧に残し、
# 上限と active の判定に数える（表示と label 列の幅には、非 active のオフは数えない）。false 以外（省略・true・"false"・0・null）はオン。
accounts_file="${CLAUDE_ACCOUNTS_FILE:-$CONFIG_DIR/accounts.json}"
codex_name="Codex A"; codex_name_w=7   # 登録簿に codex.label が無いときの既定
slot_ids=(); slot_labels=(); slot_secures=(); slot_services=(); slot_widths=(); slot_enabled=()
if [ -f "$accounts_file" ]; then
    # `IFS=$'\t' read` は使えない: タブは IFS 空白なので連続タブが 1 つの区切りに畳まれ、
    # securestorage が空の既定スロットで service 列が消える。IFS 空白でない US(0x1f) に
    # 置換してから read する（usage-probe.sh と同じ理由・同じ対処）。
    while IFS='' read -r _line; do
        [ -n "$_line" ] || continue
        IFS=$'\x1f' read -r _sid _slabel _ssecure _sservice _swidth _senabled <<< "${_line//$'\t'/$'\x1f'}"
        [ -n "$_sid" ] || continue
        # `@codex` の行はスロットではなく Codex の行の名前（id の形式に @ は一致しないので衝突しない）。
        # 2 列目が名前、3 列目がその表示幅。
        if [ "$_sid" = "@codex" ]; then codex_name="$_slabel"; codex_name_w="$_ssecure"; continue; fi
        slot_ids+=("$_sid"); slot_labels+=("$_slabel")
        slot_secures+=("$_ssecure"); slot_services+=("$_sservice")
        slot_widths+=("${_swidth:-0}")
        if [ "$_senabled" = "0" ]; then slot_enabled+=(0); else slot_enabled+=(1); fi
    done < <(ACCOUNTS_FILE="$accounts_file" python3 -c '
import hashlib, json, os, re, sys, unicodedata
MAX_SLOTS = 8
MAX_LABEL_WIDTH = 8   # 左端の label 列の表示幅の上限（全角なら 4 文字ぶん）
ID_RE = re.compile(r"[A-Za-z0-9-]{1,32}\Z")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")
def _cw(ch):
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
def disp_width(text):
    return sum(_cw(ch) for ch in text)
def clip_label(text, maxw):
    out, w = [], 0
    for ch in text:
        if w + _cw(ch) > maxw:
            break
        out.append(ch); w += _cw(ch)
    return "".join(out) or text[:1]
def service(sec):
    if not sec:
        return "Claude Code-credentials"
    return "Claude Code-credentials-" + hashlib.sha256(
        unicodedata.normalize("NFC", sec).encode("utf-8")).hexdigest()[:8]
slots = []
try:
    with open(os.environ["ACCOUNTS_FILE"], encoding="utf-8") as fh:
        doc = json.load(fh)
    entries = doc.get("accounts") if isinstance(doc, dict) else None
    if isinstance(entries, list):
        seen = set()
        for e in entries:
            if len(slots) >= MAX_SLOTS:
                break
            if not isinstance(e, dict):
                continue
            sid = e.get("id")
            if not isinstance(sid, str) or not ID_RE.match(sid) or sid in seen:
                continue
            seen.add(sid)
            lab = e.get("label")
            if not isinstance(lab, str) or not lab:
                lab = sid
            sec = e.get("securestorage")
            if not isinstance(sec, str):
                sec = ""
            # TSV の区切りを壊す制御文字を含むスロットは捨てる（usage-probe.sh と同じ規則）
            if CTRL_RE.search(lab) or CTRL_RE.search(sec):
                continue
            lab = "Claude " + clip_label(lab, MAX_LABEL_WIDTH)
            slots.append((sid, lab, sec, service(sec), e.get("enabled") is not False))
except Exception:
    slots = []
# Codex の行の名前。codex.label が空でない文字列で制御文字を含まないときだけ読む（それ以外は bash 側の既定 A）。
codex_row = None
try:
    codex_doc = doc.get("codex") if isinstance(doc, dict) else None
    clab = codex_doc.get("label") if isinstance(codex_doc, dict) else None
    if isinstance(clab, str) and clab and not CTRL_RE.search(clab):
        cname = "Codex " + clip_label(clab, MAX_LABEL_WIDTH)
        codex_row = "@codex\t" + cname + "\t" + str(disp_width(cname)) + "\n"
except Exception:
    codex_row = None
for row in slots:
    # 5 列目は label の表示幅。bash の ${#var} は文字数なので、全角ラベルでは
    # printf の %-*s（バイト幅パディング）と食い違って列がずれる。
    # 6 列目はオンなら 1、オフ（enabled が JSON の false）なら 0。
    sys.stdout.write("\t".join(row[:4]) + "\t" + str(disp_width(row[1])) + "\t"
                     + ("1" if row[4] else "0") + "\n")
if codex_row:
    sys.stdout.write(codex_row)
' 2>/dev/null)
fi
if [ "${#slot_ids[@]}" -eq 0 ]; then
    # レジストリ不在・不正 → 既定スロット 1 つ。label は空にして列を出さない
    slot_ids=("default"); slot_labels=(""); slot_secures=(""); slot_services=("Claude Code-credentials")
    slot_widths=(0); slot_enabled=(1)
fi

n_slots="${#slot_ids[@]}"
# active の判定はオフを含む登録簿の全スロットで行う（下の active_idx）。
# 表示するかどうかと複数スロット表示の判定は、active の確定後に決める（下の slot_show / multi）。
multi=0
[ "$n_slots" -gt 1 ] && multi=1

# ---- active スロットの判定（正本: usage-account-registry「active スロットの判定規則」） ----
# 1 スロットのときは常にそのスロットが active（現行と同じ挙動を 1 バイトも変えないため、
# env の突き合わせも python3 の起動も行わない）。
active_idx=0
if [ "$multi" -eq 1 ]; then
    active_idx=-1
    # 優先順位 1: env から導出した Keychain サービス名と一致するスロット。
    # 素の文字列比較ではなく導出後のサービス名で突き合わせる（本体と同じ同値関係になる）。
    # env 未設定は空文字からの導出＝既定サービス名なので、既定スロットがあればここで一致する。
    # 導出はセッション記録の鍵と同じなので、上で求めた session_key を使う（python3 を再起動しない）。
    if [ -n "${CLAUDE_SECURESTORAGE_CONFIG_DIR:-}" ]; then
        want_service=""
        [ -n "$session_key" ] && want_service="Claude Code-credentials-${session_key}"
    else
        want_service="Claude Code-credentials"
    fi
    if [ -n "$want_service" ]; then
        for i in $(seq 0 $(( n_slots - 1 ))); do
            if [ "${slot_services[$i]}" = "$want_service" ]; then active_idx=$i; break; fi
        done
    fi
    # 優先順位 2: snapshot の active が実在するスロットを指していればそれ
    if [ "$active_idx" -lt 0 ]; then
        snap_active="$(jq -r '.active // empty' "$usnap" 2>/dev/null)"
        if [ -n "$snap_active" ]; then
            for i in $(seq 0 $(( n_slots - 1 ))); do
                if [ "${slot_ids[$i]}" = "$snap_active" ]; then active_idx=$i; break; fi
            done
        fi
    fi
    # 優先順位 3: 最初のスロット
    [ "$active_idx" -lt 0 ] && active_idx=0
fi

# ---- 表示対象のスロット（正本: statusline-multi-account-usage「オフのスロットは表示しない」） ----
# active のスロットはオフでも表示する（ライブ値）。非 active のオフスロットは行を出さず、
# 複数スロット表示の判定にも名前列の幅にも数えない。表示対象が 1 つなら 1 スロット表示に戻る
# （1 つだけ残るのは必ず active なので、名前列と active の目印は出ない）。
slot_show=()
n_show=0
for i in $(seq 0 $(( n_slots - 1 ))); do
    if [ "$i" -eq "$active_idx" ] || [ "${slot_enabled[$i]}" = "1" ]; then
        slot_show+=(1); n_show=$(( n_show + 1 ))
    else
        slot_show+=(0)
    fi
done
multi=0
[ "$n_show" -gt 1 ] && multi=1

# Cache reads are local; refresh is detached by the helper.
codex_rows=""
if [ "${STATUSLINE_CODEX:-1}" != "0" ]; then
    codex_helper="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/statusline-codex.py"
    if [ -f "$codex_helper" ]; then
        codex_rows="$(python3 "$codex_helper" --read 2>/dev/null)"
        # helper の内部センチネル off（Codex オフ）は行にも列幅にも出さない
        [ "$codex_rows" = "off" ] && codex_rows=""
    fi
fi

# label 列の幅（複数スロットのときだけ使う）
# 幅は文字数ではなく表示幅（python 側が 5 列目で渡す）。全角ラベルでも列が揃う。
label_w=0
if [ "$multi" -eq 1 ]; then
    for i in $(seq 0 $(( n_slots - 1 ))); do
        [ "${slot_show[$i]}" = "1" ] || continue
        w="${slot_widths[$i]}"
        [ "$w" -gt "$label_w" ] && label_w="$w"
    done
fi

# 1 スロットで Codex の行が出るときは、Claude の行にも名前の列を出して Codex の行とバーの左端を揃える
# （正本: statusline-multi-account-usage「Codex の行の名前は Codex とアカウント名にする」）。
# 名前は登録簿の Claude <label>、登録簿が無い既定スロットは Claude。Codex の行が出ないときは今のまま。
single_name=""; single_name_w=0
if [ "$multi" -eq 0 ] && [ -n "$codex_rows" ]; then
    single_name="${slot_labels[$active_idx]}"; single_name_w="${slot_widths[$active_idx]}"
    if [ -z "$single_name" ]; then single_name="Claude"; single_name_w=6; fi
    label_w="$single_name_w"
fi

# Codex shares the label column, without changing output when its row is absent.
if [ -n "$codex_rows" ] && [ "$label_w" -lt "$codex_name_w" ]; then
    label_w="$codex_name_w"
fi

# ---- snapshot を jq 1 回で読む ----
# 1 フィールドごとに jq を起動すると 1 描画あたり 10 プロセス近くになるうえ、
# 呼び出しの合間に probe が mv -f で snapshot を差し替えると 1 行の中に新旧 2 バージョンの
# 値が混ざる（書き込みが原子的でも読み取りが原子的でないため）。全スロット分を 1 回で読む。
#
# 取り出すのは数値フィールドだけなので、TSV に載せても区切りは壊れない
# （label は snapshot 側にもあるがレジストリの値を使うのでここでは読まない）。
# active スロットに限り、`accounts` がまだ無い snapshot（probe が schema 2 を書く前の
# 旧形式）ではトップレベルへフォールバックする。
snap_fetched=(); snap_five_pct=(); snap_five_res=()
snap_seven_pct=(); snap_seven_res=(); snap_fable_pct=()
snap_rg_count=(); snap_rg_exp=()
snap_rows=""
if [ -f "$usnap" ] && [ "$n_slots" -gt 0 ]; then
    # `--args` はそれ以降のすべてを positional 扱いにするので、必ずファイル名の**後**に置く。
    # 前に置くと snapshot のパスまで positional に食われ、jq が stdin を待って固まる。
    # stdin は既に消費済みなので明示的に /dev/null を与える。
    # reset_grants: 数えられる束は dict で resets_left が 0 より大きい整数、paused が真偽値の true でないもの。
    # 欄が無い・配列でない・数えられる束が 1 つも無い（読めない束・paused の束・残数 0 の束だけ）ときは
    # 2 列とも空（区画を出さない）。元から空の配列だけは残数 0・期限空。
    # ends_at は ISO 8601 の Z か ±HH:MM の時差付きを読み（小数秒は落とす）、読めなければ期限に含めない。
    snap_rows="$(jq -r --arg active "${slot_ids[$active_idx]}" '
      def rg_good: type == "object" and (.resets_left | type) == "number" and .resets_left > 0 and .resets_left == (.resets_left | floor) and .paused != true;
      def rg_ok: type == "array" and (length == 0 or any(.[]; rg_good));
      def rg_live: [ .[] | select(rg_good) ];
      def iso_epoch: capture("^(?<b>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<z>Z|[+-][0-9]{2}:[0-9]{2})$")
        | ((.b + "Z") | fromdateiso8601)
          - (if .z == "Z" then 0 else (if .z[0:1] == "+" then 1 else -1 end) * ((.z[1:3] | tonumber) * 3600 + (.z[4:6] | tonumber) * 60) end);
      def rg_count(g): if (g | rg_ok) then ([ g | rg_live | .[] | .resets_left ] | add // 0) else "" end;
      def rg_exp(g): if (g | rg_ok) then ([ g | rg_live | .[] | .ends_at | select(type == "string") | (try iso_epoch catch empty) ] | min // "") else "" end;
      . as $d
      | $ARGS.positional[] as $id
      | (($d.accounts // {})[$id]) as $a
      | (if $a == null and $id == $active then $d else ($a // {}) end) as $src
      | [ ($src.fetched_at // ""), ($src.five_hour_pct // ""), ($src.five_hour_resets_epoch // ""),
          ($src.weekly_all_pct // ""), ($src.weekly_resets_epoch // ""), ($src.fable_weekly_pct // ""),
          rg_count($src.reset_grants), rg_exp($src.reset_grants) ]
      | @tsv
    ' "$usnap" --args "${slot_ids[@]}" < /dev/null 2>/dev/null)"
fi
_row_i=0
while IFS='' read -r _row; do
    [ "$_row_i" -lt "$n_slots" ] || break
    # タブ畳み込みで空フィールドが消えるのを避けるため US(0x1f) に置換してから読む
    IFS=$'\x1f' read -r _f _fp _fr _sp _sr _fb _rgc _rge <<< "${_row//$'\t'/$'\x1f'}"
    snap_fetched+=("$_f"); snap_five_pct+=("$_fp"); snap_five_res+=("$_fr")
    snap_seven_pct+=("$_sp"); snap_seven_res+=("$_sr"); snap_fable_pct+=("$_fb")
    snap_rg_count+=("$_rgc"); snap_rg_exp+=("$_rge")
    _row_i=$(( _row_i + 1 ))
done <<< "$snap_rows"
# jq が失敗した / 行が足りない場合は空で埋める（欠測として扱う）
while [ "${#snap_fetched[@]}" -lt "$n_slots" ]; do
    snap_fetched+=(""); snap_five_pct+=(""); snap_five_res+=("")
    snap_seven_pct+=(""); snap_seven_res+=(""); snap_fable_pct+=("")
    snap_rg_count+=(""); snap_rg_exp+=("")
done

# ---- 非 active スロットはセッション記録と突き合わせる（正本: usage-session-records の
# 「記録と snapshot から実効値を求める」。statusline が使うのは規則 1 と 4 だけで、規則 2 の
# リセット後の読み替えは表示に行わない）。dev-workflow の usage_view.py と同じ規則だが、
# プラグインを跨ぐ依存を作らないためここに置く。snapshot は上の jq の値を引数で渡して
# 再読しない（1 行の中に新旧の snapshot が混ざらないように）。python3 は複数スロットで
# 記録ディレクトリがあるときだけ起動する（1 スロット構成の出力と起動数を変えない）。
# 出力は「index, 取得時刻, 5h%, 5h リセット, 週次%, 週次リセット」。取得時刻は週次を採った
# 側の時刻（週次が無ければ 5 時間枠を採った側）で、行末の経過時間になる。Fable は snapshot のまま。
if [ "$multi" -eq 1 ] && [ -d "$sessions_dir" ]; then
    _rec_args=()
    for i in $(seq 0 $(( n_slots - 1 ))); do
        [ "$i" -eq "$active_idx" ] && continue
        # 非表示（非 active のオフ）のスロットは値を描かないので、記録との突き合わせにも載せない
        [ "${slot_show[$i]}" = "1" ] || continue
        _rec_args+=("$i" "${slot_secures[$i]}" "${snap_fetched[$i]}" "${snap_five_pct[$i]}"
                    "${snap_five_res[$i]}" "${snap_seven_pct[$i]}" "${snap_seven_res[$i]}")
    done
    # 突き合わせる相手が無ければ（非 active がすべてオフ）python3 を起動しない
    [ "${#_rec_args[@]}" -gt 0 ] &&
    while IFS='' read -r _row; do
        IFS=$'\x1f' read -r _ri _f _fp _fr _sp _sr <<< "${_row//$'\t'/$'\x1f'}"
        [[ "$_ri" =~ ^[0-9]+$ ]] && [ "$_ri" -lt "$n_slots" ] || continue
        snap_fetched[$_ri]="$_f"; snap_five_pct[$_ri]="$_fp"; snap_five_res[$_ri]="$_fr"
        snap_seven_pct[$_ri]="$_sp"; snap_seven_res[$_ri]="$_sr"
    done < <(python3 -c '
import hashlib, json, math, os, sys, unicodedata
SAME_WINDOW = 3600
sessions_dir, now, rest = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
def num(v):
    if isinstance(v, bool):
        return None
    if isinstance(v, str):
        try:
            v = float(v)
        except ValueError:
            return None
    if isinstance(v, (int, float)) and math.isfinite(v):
        return v
    return None
def text(v):
    return v if isinstance(v, str) else json.dumps(v)
def source(pct, res, stamp, five):
    # 規則 1: 使用率が 0..100 の数値でなければ無い扱い。リセット時刻は 5 時間枠の使用率 0 だけ null を許す
    p = num(pct)
    if p is None or not 0 <= p <= 100:
        return None
    r = num(res)
    if r is None and not (five and p == 0 and res in (None, "")):
        return None
    return {"pct": p, "raw": text(pct), "res": r, "at": num(stamp)}
def newer(a, b):
    return b if (b["at"] if b["at"] is not None else -math.inf) > (a["at"] if a["at"] is not None else -math.inf) else a
def larger(a, b):
    if a["pct"] != b["pct"]:
        return a if a["pct"] > b["pct"] else b
    return newer(a, b)
def combine(rec, snap, weekly):
    # 規則 4。窓の突き合わせは読み替える前のリセット時刻どうしで行う
    if rec is None or snap is None:
        return rec or snap
    if rec["res"] is None or snap["res"] is None:
        if rec["res"] is None and snap["res"] is None:
            return larger(rec, snap)
        return rec if rec["res"] is not None else snap
    if abs(rec["res"] - snap["res"]) <= SAME_WINDOW:
        # 同じ窓は取得時刻の新しい方（手動リセットで使用率は下がりうる）。等しい・片方無しなら大きい方
        if rec["at"] is not None and snap["at"] is not None and rec["at"] != snap["at"]:
            return newer(rec, snap)
        return larger(rec, snap)
    if weekly and now < rec["res"]:
        return rec
    return rec if rec["res"] > snap["res"] else snap
def key(sec):
    if not sec:
        return "default"
    return hashlib.sha256(unicodedata.normalize("NFC", sec).encode("utf-8")).hexdigest()[:8]
def cell(v, field):
    if v is None or v[field] is None:
        return ""
    return v["raw"] if field == "raw" else str(int(v[field]))
for n in range(0, len(rest) - 6, 7):
    idx, sec, fetched, fp, fr, sp, sr = rest[n:n + 7]
    try:
        with open(os.path.join(sessions_dir, key(sec) + ".json"), encoding="utf-8") as fh:
            rec = json.load(fh)
    except Exception:
        rec = None
    if not isinstance(rec, dict):
        rec = {}
    seen = rec.get("observed_at")
    five = combine(source(rec.get("five_hour_pct"), rec.get("five_hour_resets_epoch"), seen, True)
                   if rec else None, source(fp, fr, fetched, True), False)
    week = combine(source(rec.get("weekly_all_pct"), rec.get("weekly_resets_epoch"), seen, False)
                   if rec else None, source(sp, sr, fetched, False), True)
    taken = week or five
    sys.stdout.write("\t".join([idx, cell(taken, "at"), cell(five, "raw"), cell(five, "res"),
                                cell(week, "raw"), cell(week, "res")]) + "\n")
' "$sessions_dir" "$now" "${_rec_args[@]}" 2>/dev/null)
fi

# ---- .headroom.json を jq 1 回で読む（正本: statusline-multi-account-usage
# 「`.headroom.json` の値を使えるアカウントを決める」） ----
# ファイルが無ければ jq を起動しない（今の出力と起動数を変えない）。全アカウント分を 1 回で読むので、
# 途中で headroom.py が書き換えても 1 回の描画の中で新旧が混ざらない。jq の中で条件 1〜3・5〜7 を判定し、
# 通った要素だけを「キー（Claude はスロットの id、Codex は @codex）、weekly_reset_at、rocket.count、
# rocket.earliest_expiry、tickets.count、tickets.earliest_expiry、capacity_pct の整数」の TSV で出す。
# 条件 4（描く週次のリセット時刻との照合）は描く値が決まってから下の bash で行う。
# 時刻は epoch 秒の数と、snapshot の reset_grants と同じ読み方の ISO 8601 の両方を読む。
hr_file="$CONFIG_DIR/.headroom.json"
hr_rows=""
if [ -f "$hr_file" ]; then
    # `--args` はファイル名の後に置く（snapshot の jq と同じ理由）。stdin は /dev/null
    hr_rows="$(jq -r --argjson now "$now" '
      def iso_epoch: capture("^(?<b>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.[0-9]+)?(?<z>Z|[+-][0-9]{2}:[0-9]{2})$")
        | ((.b + "Z") | fromdateiso8601)
          - (if .z == "Z" then 0 else (if .z[0:1] == "+" then 1 else -1 end) * ((.z[1:3] | tonumber) * 3600 + (.z[4:6] | tonumber) * 60) end);
      def tepoch: if type == "number" then floor elif type == "string" then (try iso_epoch catch empty) else empty end;
      def epoch_or_null: (tepoch // null);
      def isint: type == "number" and . == floor;
      def future: (epoch_or_null) as $t | $t != null and $t > $now;
      def rocket_ok: . == null or (try (type == "object" and (.count | isint) and .count >= 1 and (.earliest_expiry | future)) catch false);
      def tickets_ok: . == null or (try (type == "object" and (.count | isint) and .count >= 0
                        and (.earliest_expiry == null or (.earliest_expiry | future))) catch false);
      select(type == "object" and (.schema | type) == "number" and .schema == 1)
      | (.computed_at | epoch_or_null) as $c
      | select($c != null and ($now - $c) < 21600)
      | select((.accounts | type) == "array")
      | .accounts as $acc
      | (($ARGS.positional | map(["claude", .])) + [["codex", "current"]])[] as [$p, $id]
      | [ $acc[] | select(type == "object" and .provider == $p and .account == $id) ] as $m
      | select(($m | length) == 1)
      | $m[0] as $e
      | select($e.status == "ok")
      | ($e.weekly_reset_at | epoch_or_null) as $wr
      | select($wr != null)
      | select(($e.rocket | rocket_ok) and ($e.tickets | tickets_ok))
      | select($p != "claude" or $e.rocket == null or (($e.capacity_pct | type) == "number" and $e.capacity_pct > 100))
      | [ (if $p == "codex" then "@codex" else $id end), $wr,
          (if $e.rocket == null then "" else $e.rocket.count end),
          (if $e.rocket == null then "" else ($e.rocket.earliest_expiry | tepoch) end),
          (if $e.tickets == null then "" else $e.tickets.count end),
          (if $e.tickets == null or $e.tickets.earliest_expiry == null then "" else ($e.tickets.earliest_expiry | tepoch) end),
          (if ($e.capacity_pct | type) == "number" then ($e.capacity_pct | round) else "" end) ]
      | @tsv
    ' "$hr_file" --args "${slot_ids[@]}" < /dev/null 2>/dev/null)"
fi
hr_found=(); hr_wr=(); hr_rc=(); hr_re=(); hr_tc=(); hr_te=(); hr_cap=()
for i in $(seq 0 $(( n_slots - 1 ))); do
    hr_found+=(""); hr_wr+=(""); hr_rc+=(""); hr_re+=(""); hr_tc+=(""); hr_te+=(""); hr_cap+=("")
done
cx_found=""; cx_wr=""; cx_rc=""; cx_re=""; cx_tc=""; cx_te=""
_is_int() { [[ "$1" =~ ^-?[0-9]+$ ]]; }
while IFS='' read -r _row; do
    [ -n "$_row" ] || continue
    IFS=$'\x1f' read -r _k _wr _rc _re _tc _te _cap <<< "${_row//$'\t'/$'\x1f'}"
    # bash の算術に渡す値は整数だけ（jq が整数を出すが、念のため形を確かめる）
    _is_int "$_wr" || continue
    { [ -z "$_rc" ] || { _is_int "$_rc" && _is_int "$_re"; }; } || continue
    { [ -z "$_tc" ] || _is_int "$_tc"; } && { [ -z "$_te" ] || _is_int "$_te"; } || continue
    if [ "$_k" = "@codex" ]; then
        cx_found=1; cx_wr="$_wr"; cx_rc="$_rc"; cx_re="$_re"; cx_tc="$_tc"; cx_te="$_te"
        continue
    fi
    for i in $(seq 0 $(( n_slots - 1 ))); do
        [ "${slot_ids[$i]}" = "$_k" ] || continue
        if [ -n "$_rc" ] && ! _is_int "$_cap"; then break; fi
        hr_found[$i]=1; hr_wr[$i]="$_wr"; hr_rc[$i]="$_rc"; hr_re[$i]="$_re"
        hr_tc[$i]="$_tc"; hr_te[$i]="$_te"; hr_cap[$i]="$_cap"
        break
    done
done <<< "$hr_rows"

# 条件 4: 要素の weekly_reset_at と、その行に描く週次のリセット時刻の差が 3600 秒以内。
# Claude は描く 7d のリセット時刻（active は stdin、非 active はセッション記録と突き合わせた後の値）、
# Codex は 10080 分の窓のリセット時刻。描く行が無い・週次のリセット時刻が無ければ使わない。
_same_week() { _is_int "$1" && _is_int "$2" && [ $(( $1 > $2 ? $1 - $2 : $2 - $1 )) -le 3600 ]; }
hr_use=(); hr_gap=""
for i in $(seq 0 $(( n_slots - 1 ))); do
    hr_use+=("")
    [ -n "${hr_found[$i]}" ] && [ "${slot_show[$i]}" = "1" ] || continue
    if [ "$i" -eq "$active_idx" ]; then
        _fp="$five_h_pct"; _sp="$seven_d_pct"; _sr="$seven_d_resets"
    else
        _fp="${snap_five_pct[$i]}"; _sp="${snap_seven_pct[$i]}"; _sr="${snap_seven_res[$i]}"
    fi
    [ -n "$_fp" ] && [ -n "$_sp" ] || continue
    _same_week "${hr_wr[$i]}" "$_sr" || continue
    hr_use[$i]=1; hr_gap=1
done
cx_use=""
if [ -n "$codex_rows" ] && [ -n "$cx_found" ]; then
    while IFS=$'\t' read -r c_pct c_minutes c_reset c_fetched; do
        [ "$c_minutes" = "10080" ] || continue
        case "$c_pct" in resets|pending) continue ;; esac
        _same_week "$cx_wr" "$c_reset" && cx_use=1
    done <<< "$codex_rows"
    [ -n "$cx_use" ] && hr_gap=1
fi

# $1=行頭 label 列 $2=5h消化率 $3=5hリセットepoch $4=7d消化率 $5=7dリセットepoch
# $6=Fable週次消化率 $7=行末サフィックス（経過時間。空可）
# $8=リセット権の残数（空なら区画なし） $9=リセット権の最短期限 epoch（空なら期限なし）
# .headroom.json の値はグローバル変数で受け取る: rs_use（値を使えるなら 1）、rs_rc（rocket の
# count。ロケットモードでなければ空）、rs_tc / rs_te（tickets）、rs_cap（capacity_pct）、
# rs_prefix7（ロケットモードの 7d の行の行頭。名前をオレンジの地で描いたもの）。列を空けるかは hr_gap。
render_slot() {
    local prefix="$1" f_pct="$2" f_res="$3" s_pct="$4" s_res="$5" fb_pct="$6" ago="$7" rg_n="$8" rg_e="$9"
    local rg_seg="" rocket=""
    [ -n "$rs_use" ] && [ -n "$rs_rc" ] && rocket=1
    if [ -n "$rs_use" ]; then
        # 値を使えるアカウントは今のリセット権の区画の代わりに 🚀×N を出す
        if [ -n "$rocket" ]; then
            rg_seg="$(fmt_rocket_tickets "$rs_tc" "$rs_te" claude-rocket)"
        else
            rg_seg="$(fmt_rocket_tickets "$rs_tc" "$rs_te" plain)"
        fi
    elif [ -n "$rg_n" ]; then
        rg_seg="  ${DIM}│${RESET}  $(fmt_reset_credits "$rg_n" "${rg_e:-0}")"
    fi
    [ -n "$f_pct" ] || return 0

    local five_h_int five_h_elapsed="" five_h_left="" secs_left_5h
    five_h_int=$(printf "%.0f" "$f_pct")
    if [ -n "$f_res" ]; then
        secs_left_5h=$(( f_res - now ))
        if [ "$secs_left_5h" -gt 0 ] && [ "$secs_left_5h" -lt 18000 ]; then
            five_h_left=$(fmt_left "$secs_left_5h")
            five_h_elapsed=$(( (18000 - secs_left_5h) * 100 / 18000 ))
        fi
    fi
    local line_5h
    line_5h="${prefix}$(bar_seg "5h" 9 "$five_h_int" "$five_h_elapsed" "" "$hr_gap")"
    [ -n "$five_h_left" ] && line_5h+="  ${DIM}${five_h_left}${RESET}"

    if [ -z "$s_pct" ]; then
        # 7d が無いスロットは 5h 行だけ。経過時間はそのスロットの最後の行に付ける
        [ -n "$ago" ] && line_5h+="  ${DIM}${ago}${RESET}"
        line_5h+="$rg_seg"
        usage_lines+=("$line_5h")
        return 0
    fi
    usage_lines+=("$line_5h")

    local seven_d_int elapsed_pct="" seven_d_left="" secs_left_7d
    seven_d_int=$(printf "%.0f" "$s_pct")
    if [ -n "$s_res" ]; then
        secs_left_7d=$(( s_res - now ))
        if [ "$secs_left_7d" -gt 0 ] && [ "$secs_left_7d" -lt 604800 ]; then
            seven_d_left=$(fmt_left "$secs_left_7d")
            elapsed_pct=$(( (604800 - secs_left_7d) * 100 / 604800 ))
            [ "$elapsed_pct" -le 0 ] && elapsed_pct=""
        fi
    fi
    local line_7d
    if [ -n "$rocket" ]; then
        # 使える量に対する割合（四捨五入。使った量が 0 より大きければ最低 1）でバーと数字を描く
        local share
        share=$(( (seven_d_int * 200 + rs_cap) / (2 * rs_cap) ))
        [ "$seven_d_int" -gt 0 ] && [ "$share" -eq 0 ] && share=1
        line_7d="${rs_prefix7}$(bar_seg "7d All" 9 "$share" "$elapsed_pct" 1 1 \
            "$(rocket_cell "$rs_rc")" "${seven_d_int}/${rs_cap}%" "$rs_cap")"
    elif [ -n "$hr_gap" ]; then
        line_7d="${prefix}$(bar_seg "7d All" 9 "$seven_d_int" "$elapsed_pct" 1 1 "" "-")"
    else
        line_7d="${prefix}$(bar_seg "7d All" 9 "$seven_d_int" "$elapsed_pct" 1)"
    fi
    if [ -n "$fb_pct" ]; then
        local fable_int
        fable_int=$(printf "%.0f" "$fb_pct")
        line_7d+="   $(bar_seg "Fable" 6 "$fable_int" "$elapsed_pct" 1)"
    fi
    [ -n "$seven_d_left" ] && line_7d+="  ${DIM}${seven_d_left}${RESET}"
    [ -n "$ago" ] && line_7d+="  ${DIM}${ago}${RESET}"
    line_7d+="$rg_seg"
    usage_lines+=("$line_7d")
}

for i in $(seq 0 $(( n_slots - 1 ))); do
    # 非 active のオフのスロットは行を出さない（値が残っていても、無くても）。
    # active のスロットはオフでも下のライブ値の経路で描く。
    [ "${slot_show[$i]}" = "1" ] || continue
    prefix=""
    # ロケットモードの 7d の行の行頭。名前（うしろの空白と目印を除く）だけをオレンジの地にする
    rs_prefix7=""
    if [ "$multi" -eq 1 ]; then
        # printf の %-*s はバイト幅で詰めるので使えない。表示幅の差だけ手で空白を足す。
        pad="$(printf '%*s' "$(( label_w - ${slot_widths[$i]} ))" '')"
        if [ "$i" -eq "$active_idx" ]; then
            # active 行: 記号 + 通常の明るさの label。記号が主・明るさが補助なので
            # 記号にも DIM を掛けない（色が落ちても記号が残り、記号が出なくても明るさが残る）
            prefix="${ACTIVE_MARK} ${slot_labels[$i]}${pad}  "
            rs_prefix7="${ACTIVE_MARK} ${ROCKET_NAME}${slot_labels[$i]}${RESET}${pad}  "
        else
            # 非 active 行: 記号と同じ表示幅 2 を半角スペースで埋め、label は DIM のまま。
            # 全行が等しく 2 桁を占めるので、バーの左端は揃ったまま
            prefix="  ${DIM}${slot_labels[$i]}${pad}${RESET}  "
            rs_prefix7="  ${ROCKET_NAME}${slot_labels[$i]}${RESET}${pad}  "
        fi
    elif [ -n "$single_name" ]; then
        # 1 スロットで Codex の行が出るとき: 目印の列は空白、名前に DIM を掛けない
        pad="$(printf '%*s' "$(( label_w - single_name_w ))" '')"
        prefix="  ${single_name}${pad}  "
        rs_prefix7="  ${ROCKET_NAME}${single_name}${RESET}${pad}  "
    fi
    rs_use="${hr_use[$i]}"; rs_rc="${hr_rc[$i]}"
    rs_tc="${hr_tc[$i]}"; rs_te="${hr_te[$i]}"; rs_cap="${hr_cap[$i]}"
    # 名前の列が無い 1 スロットでは、ロケットモードの 7d の行の行頭も空のまま
    [ -n "$rs_prefix7" ] || rs_prefix7="$prefix"
    fetched_at="${snap_fetched[$i]}"
    fable_pct="${snap_fable_pct[$i]}"

    if [ "$i" -eq "$active_idx" ]; then
        # active スロットは stdin のライブ値。Fable だけ snapshot 由来で、
        # 6h の鮮度ゲートは現行どおりここにだけ適用する
        if [ -n "$fable_pct" ]; then
            if [ -z "$fetched_at" ] || [ $(( now - fetched_at )) -ge 21600 ]; then
                fable_pct=""
            fi
        fi
        if [ "$multi" -eq 1 ] && [ -z "$five_h_pct" ]; then
            usage_lines+=("${prefix}${DIM}取得待ち${RESET}")
        fi
        render_slot "$prefix" "$five_h_pct" "$five_h_resets" "$seven_d_pct" "$seven_d_resets" \
                    "$fable_pct" "" "${snap_rg_count[$i]}" "${snap_rg_exp[$i]}"
    else
        # 非 active スロットは snapshot の値。鮮度ゲートは適用せず、経過時間を併記する
        ago=""
        [ -n "$fetched_at" ] && ago="$(fmt_ago $(( now - fetched_at )))"
        render_slot "$prefix" \
                    "${snap_five_pct[$i]}" "${snap_five_res[$i]}" \
                    "${snap_seven_pct[$i]}" "${snap_seven_res[$i]}" \
                    "$fable_pct" "$ago" "${snap_rg_count[$i]}" "${snap_rg_exp[$i]}"
    fi
done

# Codex is a separate account; keep all returned windows on one additional row.
# Only the helper talks to app-server, detached from rendering (180s cache).
if [ -n "$codex_rows" ]; then
    codex_pad="$(printf '%*s' "$(( label_w - codex_name_w ))" '')"
    # Codex のロケットモード（値を使えて rocket が null でない）は名前をオレンジの地で描く
    cx_rocket=""
    [ -n "$cx_use" ] && [ -n "$cx_rc" ] && cx_rocket=1
    if [ -n "$cx_rocket" ]; then
        codex_line="  ${ROCKET_NAME}${codex_name}${RESET}${codex_pad}  "
    else
        codex_line="  ${DIM}${codex_name}${codex_pad}${RESET}  "
    fi
    codex_sep=""
    codex_fetched=""
    codex_resets=""
    while IFS=$'\t' read -r c_pct c_minutes c_reset c_fetched; do
        if [ "$c_pct" = "resets" ]; then
            codex_fetched="$c_fetched"
            codex_resets="  ${DIM}│${RESET}  $(fmt_reset_credits "$c_minutes" "$c_reset")"
            continue
        fi
        if [ "$c_pct" = "pending" ]; then
            codex_line+="${DIM}取得待ち${RESET}"
            continue
        fi
        codex_fetched="$c_fetched"
        c_seconds=$(( c_minutes * 60 ))
        c_left=$(( c_reset - now ))
        c_elapsed=""
        if [ "$c_left" -ge 0 ] && [ "$c_left" -le "$c_seconds" ]; then
            c_elapsed=$(( (c_seconds - c_left) * 100 / c_seconds ))
        fi
        if [ $(( c_minutes % 1440 )) -eq 0 ]; then
            c_label="$(( c_minutes / 1440 ))d All"
        elif [ $(( c_minutes % 60 )) -eq 0 ]; then
            c_label="$(( c_minutes / 60 ))h"
        else
            c_label="${c_minutes}m"
        fi
        if [ -n "$cx_rocket" ] && [ "$c_minutes" = "10080" ]; then
            # 経過は窓の始まり（リセット − 604800）から rocket.earliest_expiry までに対する今の位置。
            # 残り時間は失効まで（24 時間以内は赤）＋かっこの週次のリセットまで
            c_start=$(( c_reset - 604800 ))
            c_elapsed=""
            if [ "$now" -ge "$c_start" ] && [ "$cx_re" -gt "$c_start" ]; then
                c_elapsed=$(( (now - c_start) * 100 / (cx_re - c_start) ))
                [ "$c_elapsed" -gt 100 ] && c_elapsed=100
            fi
            codex_line+="${codex_sep}$(bar_seg "$c_label" 9 "$c_pct" "$c_elapsed" 1 1 "🚀  " "-")"
            c_exp_left=$(( cx_re - now ))
            c_exp_color="$ROCKET_FG"
            [ "$c_exp_left" -le 86400 ] && c_exp_color="$ROCKET_RED"
            codex_line+="  ${c_exp_color}$(fmt_left "$c_exp_left")${RESET}"
            [ "$c_left" -gt 0 ] && codex_line+=" ${DIM}($(fmt_left "$c_left"))${RESET}"
        else
            c_use_col=""
            [ -n "$hr_gap" ] && [ "$c_minutes" = "10080" ] && c_use_col="-"
            codex_line+="${codex_sep}$(bar_seg "$c_label" 9 "$c_pct" "$c_elapsed" 1 "$hr_gap" "" "$c_use_col")"
            [ "$c_left" -gt 0 ] && codex_line+="  ${DIM}$(fmt_left "$c_left")${RESET}"
        fi
        codex_sep="   "
    done <<< "$codex_rows"
    [ -n "$codex_fetched" ] && codex_line+="  ${DIM}$(fmt_ago $(( now - codex_fetched )))${RESET}"
    if [ -n "$cx_use" ]; then
        # 値を使えるときは今のリセット権の区画の代わりに .headroom.json の 🚀×N を出す
        if [ -n "$cx_rocket" ]; then
            codex_resets="$(fmt_rocket_tickets "$cx_tc" "$cx_te" codex-rocket)"
        else
            codex_resets="$(fmt_rocket_tickets "$cx_tc" "$cx_te" plain)"
        fi
    fi
    codex_line+="$codex_resets"
    usage_lines+=("$codex_line")
fi

# $1=USD $2=為替レート $3=通貨 → "¥1,240" / "€12"（通貨単位の整数、3 桁区切り）
fmt_money() {
    local sym amount digits grouped="" sign=""
    case "$3" in
        JPY) sym='¥' ;;
        EUR) sym='€' ;;
        GBP) sym='£' ;;
        *)   sym="$3 " ;;
    esac
    # 小数点がカンマのロケール（de_DE 等）では awk が "1.23" を 1 と読むので C 固定
    amount=$(echo "$1 $2" | LC_ALL=C awk '{printf "%d", $1 * $2}')
    # Bash 3.2 builtin printf does not reliably adopt a temporary LC_ALL assignment.
    # Group the integer explicitly: this also works without en_US.UTF-8 installed.
    digits="$amount"
    if [[ "$digits" == -* ]]; then sign="-"; digits="${digits#-}"; fi
    while [ "${#digits}" -gt 3 ]; do
        grouped=",${digits: -3}${grouped}"
        digits="${digits:0:${#digits}-3}"
    done
    printf '%s%s%s%s' "$sym" "$sign" "$digits" "$grouped"
}

# API-equivalent monthly cost pace (last 30 days via ccusage; cached, refreshed in background)
api_pace_info=""
if [ "${STATUSLINE_API_PACE:-1}" != "0" ]; then
    cost_cache="$CONFIG_DIR/.statusline-api-pace"
    if [ -f "$cost_cache" ]; then
        api_pace=$(cat "$cost_cache")
        [ -n "$api_pace" ] && api_pace_info="${CYAN}${api_pace}${RESET}"
    fi
    cache_age=999999
    if [ -f "$cost_cache" ]; then
        cache_age=$(( now - $(file_mtime "$cost_cache") ))
    fi
    # Clear a stale lock left by a crashed refresh
    if [ -d "$cost_cache.lock" ] && [ $(( now - $(file_mtime "$cost_cache.lock") )) -gt 300 ]; then
        rmdir "$cost_cache.lock" 2>/dev/null
    fi
    runner=$(pkg_runner)
    if [ -n "$runner" ] && [ "$cache_age" -gt 600 ] && mkdir "$cost_cache.lock" 2>/dev/null; then
        (
            since=$(days_ago 30)
            total=$("$runner" ccusage daily --json --since "$since" 2>/dev/null | jq -r '.totals.totalCost // empty')
            if [ -n "$total" ]; then
                currency="${STATUSLINE_CURRENCY:-JPY}"
                if [ "$currency" = "USD" ]; then
                    printf 'API $%s/mo' "$(echo "$total" | LC_ALL=C awk '{printf "%d", $1}')" > "$cost_cache"
                else
                    # 為替レートは24hキャッシュ。取得失敗時は前回値 → 既定値の順にフォールバック
                    rate_cache="$CONFIG_DIR/.statusline-fxrate-$currency"
                    rate=""
                    if [ -f "$rate_cache" ] && [ $(( $(date +%s) - $(file_mtime "$rate_cache") )) -lt 86400 ]; then
                        rate=$(cat "$rate_cache")
                    fi
                    if [ -z "$rate" ]; then
                        rate=$(curl -s --max-time 5 https://open.er-api.com/v6/latest/USD | jq -r ".rates.${currency} // empty")
                        if [ -n "$rate" ]; then
                            echo "$rate" > "$rate_cache"
                        elif [ -f "$rate_cache" ]; then
                            rate=$(cat "$rate_cache")
                        fi
                    fi
                    if [ -n "$rate" ]; then
                        printf 'API %s/mo' "$(fmt_money "$total" "$rate" "$currency")" > "$cost_cache"
                    fi
                fi
            fi
            rmdir "$cost_cache.lock" 2>/dev/null
        ) >/dev/null 2>&1 &
    fi
fi

# 本体のセッションコストをセッションごとに書き残す（正本: openspec/specs/session-cost-record）。
# 読み手は cost-ledger で、自前の単価表で計算した額と比べて単価表のずれを見つける。
# 記録は <設定ディレクトリ>/.session-cost/<session_id> に 1 行 `1 <t0> <v0> <t1> <v1>`
# （区間の最初の観測時刻と値、最後に値が変わった観測時刻と値）。値が下がったら区間を始め直す。
# 値が前回と同じ描画は組み込みの read 1 回だけで終える（外部コマンドを起動しない）。
# 表示の設定（STATUSLINE_SESSION_COST）には左右されない。どの失敗でも出力を変えない。
_sc_sid="${session_id#\"}"
_sc_sid="${_sc_sid%\"}"
if [[ "$_sc_sid" =~ ^[A-Za-z0-9_-]{1,128}$ ]] \
    && [[ "$session_cost_usd" =~ ^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
    _sc_dir="$CONFIG_DIR/.session-cost"
    _sc_file="$_sc_dir/$_sc_sid"
    _sc_ver="" _sc_t0="" _sc_v0="" _sc_t1="" _sc_v1="" _sc_rest=""
    _sc_new=""
    if [ -f "$_sc_file" ]; then
        { read -r _sc_ver _sc_t0 _sc_v0 _sc_t1 _sc_v1 _sc_rest < "$_sc_file"; } 2>/dev/null
    else
        _sc_new=1
    fi
    _sc_line=""
    if [ "$_sc_ver" = "1" ] && [ -z "$_sc_rest" ] \
        && [[ "$_sc_t0" =~ ^[0-9]+$ ]] && [[ "$_sc_t1" =~ ^[0-9]+$ ]] \
        && [[ "$_sc_v0" =~ ^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] \
        && [[ "$_sc_v1" =~ ^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        # 文字列の一致は速い経路。一致しないときだけ awk を 1 回起動して数として比べる
        if [ "$_sc_v1" != "$session_cost_usd" ]; then
            case "$(LC_ALL=C awk -v a="$session_cost_usd" -v b="$_sc_v1" \
                'BEGIN { if (a + 0 == b + 0) print "eq"; else if (a + 0 < b + 0) print "lt"; else print "gt" }' 2>/dev/null)" in
                gt) _sc_line="1 $_sc_t0 $_sc_v0 $now $session_cost_usd" ;;
                lt) _sc_line="1 $now $session_cost_usd $now $session_cost_usd" ;;
            esac
        fi
    else
        _sc_line="1 $now $session_cost_usd $now $session_cost_usd"
    fi
    if [ -n "$_sc_line" ] && mkdir -p "$_sc_dir" 2>/dev/null; then
        # 一時ファイルに書いてから mv で置き換える（読み手に書きかけを見せない）。失敗は無視する
        _sc_tmp="$(mktemp "$_sc_dir/.tmp.XXXXXX" 2>/dev/null)"
        if [ -n "$_sc_tmp" ]; then
            { printf '%s\n' "$_sc_line" > "$_sc_tmp" && mv -f "$_sc_tmp" "$_sc_file"; } 2>/dev/null \
                || rm -f "$_sc_tmp" 2>/dev/null
        fi
        # 400 日より古い記録は、新しい記録ファイルを作る描画でだけ消す（1 セッションに 1 回）
        [ -n "$_sc_new" ] && find "$_sc_dir" -type f -mtime +400 -delete 2>/dev/null
    fi
fi

# このセッションの API 換算コスト（メイン + このセッションが立ち上げたサブエージェントの合算）。
# Claude Code が stdin に渡す cost.total_cost_usd をそのまま使う（ドキュメント上「セッション内の
# すべての API 呼び出し」の推定値で、定価ベース。/clear で 0 に戻る）。30 日コストは ccusage が
# ログから計算するので、料金表の違いで多少ずれうる。
# 為替は 30 日コストの背景更新が書くキャッシュを読むだけにし、描画中にネットワークへ出ない。
# キャッシュが無ければ USD のまま出す。
session_cost_info=""
if [ "${STATUSLINE_SESSION_COST:-1}" != "0" ] && [ -n "$session_cost_usd" ]; then
    currency="${STATUSLINE_CURRENCY:-JPY}"
    rate=""
    [ "$currency" != "USD" ] && rate=$(cat "$CONFIG_DIR/.statusline-fxrate-$currency" 2>/dev/null)
    # 壊れたキャッシュ（空白・非数値）を awk に渡すと 0 扱いで ¥0 になるので、正の数値だけを使う
    if [[ "$rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$rate" =~ [1-9] ]]; then
        session_cost_info="${CYAN}Session $(fmt_money "$session_cost_usd" "$rate" "$currency")${RESET}"
    else
        session_cost_info="${CYAN}Session \$$(echo "$session_cost_usd" | LC_ALL=C awk '{printf "%.2f", $1}')${RESET}"
    fi
fi

# Build status line
# Line 1: directory, model, git
# Line 2: context window, prompt cache, API cost, session cost
# Line 3: 5h bar / Line 4: 7d All + Fable bars
update_info=""
if [ -f "$CONFIG_DIR/.statusline-update-available" ]; then
    update_info="  ${YELLOW}更新あり /statusline:setup${RESET}"
fi
printf "${BLUE}%s${RESET} ${CYAN}%s${RESET}%s%s\n" \
    "$short_pwd" \
    "$model_name" \
    "$git_info" \
    "$update_info"

line2=""
if [ -n "$context_info" ]; then
    line2="$context_info"
fi
for seg in "$cache_info" "$api_pace_info" "$session_cost_info"; do
    [ -n "$seg" ] || continue
    if [ -n "$line2" ]; then
        line2="${line2}  ${DIM}│${RESET}  ${seg}"
    else
        line2="$seg"
    fi
done
if [ -n "$line2" ]; then
    printf "%s\n" "$line2"
fi

for l in "${usage_lines[@]}"; do
    printf "%s\n" "$l"
done
