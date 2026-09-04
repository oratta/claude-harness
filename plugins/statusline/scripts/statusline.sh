#!/usr/bin/env bash
#
# statusline.sh — Claude Code の使用量ステータスライン
#
#   1行目: カレントディレクトリ / モデル / git ブランチ
#   2行目: コンテキスト残量 / API 換算の月額ペース
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
# 環境変数（すべて任意）:
#   STATUSLINE_BAR_WIDTH   バーのセル数（既定 16）
#   STATUSLINE_BAR_GLYPH   日程線の太さ。細い順に ▁ ▂ ▃ ▄（既定 ▂）
#   STATUSLINE_API_PACE    0 で API 換算コスト表示を無効化（既定 1）
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

# Snapshot rate limits to a file so external consumers (loop guards etc.) can read them
if [ -n "$five_h_pct" ]; then
    printf '{"ts":%s,"five_hour_pct":%s,"five_hour_resets_at":%s,"seven_day_pct":%s,"seven_day_resets_at":%s}\n' \
        "$(date +%s)" "$five_h_pct" "${five_h_resets:-null}" "${seven_d_pct:-null}" "${seven_d_resets:-null}" \
        > "$CONFIG_DIR/.rate-limit-snapshot" 2>/dev/null
fi

# ANSI color codes (dimmed for status line)
BLUE=$(printf '\033[34m')
GREEN=$(printf '\033[32m')
CYAN=$(printf '\033[36m')
YELLOW=$(printf '\033[33m')
RED=$(printf '\033[31m')
DIM=$(printf '\033[2m')
RESET=$(printf '\033[0m')

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

# ---------------------------------------------------------------------------
# プログレスバー
# ---------------------------------------------------------------------------
BAR_WIDTH="${STATUSLINE_BAR_WIDTH:-16}"
BAR_GLYPH="${STATUSLINE_BAR_GLYPH:-▂}"
C_EMPTY_N=238      # バー本体の未消化部分
C_TRACK_N=252      # 日程の線

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

# $1=消化率(整数) $2=日程消化率(整数, 空可) $3=バー色番号 → バー文字列
bar2() {
    local pct=$1 elapsed=$2 un=$3
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
        if [ "$i" -lt "$fill" ]; then bgn=$un; else bgn=$C_EMPTY_N; fi
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
#   → "ラベル バー ◯◯%/△△%"
# 分母は日程消化率。バー下端の線と同じ色にして、線の位置＝分母だと目で繋がるようにする。
bar_seg() {
    local un
    un=$(usage_color_num "$3" "$4")
    printf '%s%-*s%s%s \033[38;5;%sm%3d%%%s' \
        "$DIM" "$2" "$1" "$RESET" \
        "$(bar2 "$3" "$4" "$un")" \
        "$un" "$3" "$RESET"
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

# Usage (rate limit) indicator — Pro/Max only; fields absent otherwise
now=$(date +%s)
usage_lines=()
usnap="$CONFIG_DIR/.usage-snapshot"

# ---- アカウントレジストリ（不在なら既定スロット 1 つ = 現行と同じ挙動） ----
# 読み取り規則の正本は openspec/specs/usage-account-registry。トップレベルはオブジェクト、
# id は英数字とハイフン 1〜32 文字で一意、先頭 8 スロットまで、不正なら既定スロットへ縮退。
# dev-workflow の usage-probe.sh と同じ規則だが、プラグインを跨ぐ依存を作らないため
# 実装は各スクリプトに置く（規則の正本は spec 側）。
accounts_file="${CLAUDE_ACCOUNTS_FILE:-$CONFIG_DIR/accounts.json}"
slot_ids=(); slot_labels=(); slot_secures=(); slot_services=()
if [ -f "$accounts_file" ]; then
    # `IFS=$'\t' read` は使えない: タブは IFS 空白なので連続タブが 1 つの区切りに畳まれ、
    # securestorage が空の既定スロットで service 列が消える。IFS 空白でない US(0x1f) に
    # 置換してから read する（usage-probe.sh と同じ理由・同じ対処）。
    while IFS='' read -r _line; do
        [ -n "$_line" ] || continue
        IFS=$'\x1f' read -r _sid _slabel _ssecure _sservice <<< "${_line//$'\t'/$'\x1f'}"
        [ -n "$_sid" ] || continue
        slot_ids+=("$_sid"); slot_labels+=("$_slabel")
        slot_secures+=("$_ssecure"); slot_services+=("$_sservice")
    done < <(ACCOUNTS_FILE="$accounts_file" python3 -c '
import hashlib, json, os, re, sys, unicodedata
ID_RE = re.compile(r"[A-Za-z0-9-]{1,32}\Z")
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
            if len(slots) >= 8:
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
            slots.append((sid, lab, sec, service(sec)))
except Exception:
    slots = []
for row in slots:
    sys.stdout.write("\t".join(row) + "\n")
' 2>/dev/null)
fi
if [ "${#slot_ids[@]}" -eq 0 ]; then
    # レジストリ不在・不正 → 既定スロット 1 つ。label は空にして列を出さない
    slot_ids=("default"); slot_labels=(""); slot_secures=(""); slot_services=("Claude Code-credentials")
fi

n_slots="${#slot_ids[@]}"
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
    if [ -n "${CLAUDE_SECURESTORAGE_CONFIG_DIR:-}" ]; then
        want_service="$(SECURE="$CLAUDE_SECURESTORAGE_CONFIG_DIR" python3 -c '
import hashlib, os, unicodedata
sec = os.environ["SECURE"]
print("Claude Code-credentials-" + hashlib.sha256(
    unicodedata.normalize("NFC", sec).encode("utf-8")).hexdigest()[:8])
' 2>/dev/null)"
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

# label 列の幅（複数スロットのときだけ使う）
label_w=0
if [ "$multi" -eq 1 ]; then
    for l in "${slot_labels[@]}"; do
        [ "${#l}" -gt "$label_w" ] && label_w="${#l}"
    done
fi

# $1=スロット id $2=キー → snapshot の値（1 スロット時はトップレベルにフォールバック）
snap_get() {
    local expr='.accounts[$id][$k] // empty'
    [ "$multi" -eq 1 ] || expr='(.accounts[$id][$k] // .[$k]) // empty'
    jq -r --arg id "$1" --arg k "$2" "$expr" "$usnap" 2>/dev/null
}

# $1=行頭 label 列 $2=5h消化率 $3=5hリセットepoch $4=7d消化率 $5=7dリセットepoch
# $6=Fable週次消化率 $7=行末サフィックス（経過時間。空可）
render_slot() {
    local prefix="$1" f_pct="$2" f_res="$3" s_pct="$4" s_res="$5" fb_pct="$6" ago="$7"
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
    line_5h="${prefix}$(bar_seg "5h" 9 "$five_h_int" "$five_h_elapsed")"
    [ -n "$five_h_left" ] && line_5h+="  ${DIM}${five_h_left}${RESET}"

    if [ -z "$s_pct" ]; then
        # 7d が無いスロットは 5h 行だけ。経過時間はそのスロットの最後の行に付ける
        [ -n "$ago" ] && line_5h+="  ${DIM}${ago}${RESET}"
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
    line_7d="${prefix}$(bar_seg "7d All" 9 "$seven_d_int" "$elapsed_pct" 1)"
    if [ -n "$fb_pct" ]; then
        local fable_int
        fable_int=$(printf "%.0f" "$fb_pct")
        line_7d+="   $(bar_seg "Fable" 6 "$fable_int" "$elapsed_pct" 1)"
    fi
    [ -n "$seven_d_left" ] && line_7d+="  ${DIM}${seven_d_left}${RESET}"
    [ -n "$ago" ] && line_7d+="  ${DIM}${ago}${RESET}"
    usage_lines+=("$line_7d")
}

for i in $(seq 0 $(( n_slots - 1 ))); do
    sid="${slot_ids[$i]}"
    prefix=""
    if [ "$multi" -eq 1 ]; then
        prefix="${DIM}$(printf '%-*s' "$label_w" "${slot_labels[$i]}")${RESET}  "
    fi
    fetched_at="$(snap_get "$sid" fetched_at)"
    fable_pct="$(snap_get "$sid" fable_weekly_pct)"

    if [ "$i" -eq "$active_idx" ]; then
        # active スロットは stdin のライブ値。Fable だけ snapshot 由来で、
        # 6h の鮮度ゲートは現行どおりここにだけ適用する
        if [ -n "$fable_pct" ]; then
            if [ -z "$fetched_at" ] || [ $(( now - fetched_at )) -ge 21600 ]; then
                fable_pct=""
            fi
        fi
        render_slot "$prefix" "$five_h_pct" "$five_h_resets" "$seven_d_pct" "$seven_d_resets" \
                    "$fable_pct" ""
    else
        # 非 active スロットは snapshot の値。鮮度ゲートは適用せず、経過時間を併記する
        ago=""
        [ -n "$fetched_at" ] && ago="$(fmt_ago $(( now - fetched_at )))"
        render_slot "$prefix" \
                    "$(snap_get "$sid" five_hour_pct)" "$(snap_get "$sid" five_hour_resets_epoch)" \
                    "$(snap_get "$sid" weekly_all_pct)" "$(snap_get "$sid" weekly_resets_epoch)" \
                    "$fable_pct" "$ago"
    fi
done

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
                    printf 'API $%s/mo' "$(echo "$total" | awk '{printf "%d", $1}')" > "$cost_cache"
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
                        case "$currency" in
                            JPY) sym='¥' ;;
                            EUR) sym='€' ;;
                            GBP) sym='£' ;;
                            *)   sym="$currency " ;;
                        esac
                        amount=$(echo "$total $rate" | awk '{printf "%d", $1 * $2}')
                        amount_fmt=$(LC_ALL=en_US.UTF-8 printf "%'d" "$amount" 2>/dev/null || printf '%d' "$amount")
                        printf 'API %s%s/mo' "$sym" "$amount_fmt" > "$cost_cache"
                    fi
                fi
            fi
            rmdir "$cost_cache.lock" 2>/dev/null
        ) >/dev/null 2>&1 &
    fi
fi

# Build status line
# Line 1: directory, model, git
# Line 2: context window, API cost
# Line 3: 5h bar / Line 4: 7d All + Fable bars
printf "${BLUE}%s${RESET} ${CYAN}%s${RESET}%s\n" \
    "$short_pwd" \
    "$model_name" \
    "$git_info"

line2=""
if [ -n "$context_info" ]; then
    line2="$context_info"
fi
if [ -n "$api_pace_info" ]; then
    if [ -n "$line2" ]; then
        line2="${line2}  ${DIM}│${RESET}  ${api_pace_info}"
    else
        line2="$api_pace_info"
    fi
fi
if [ -n "$line2" ]; then
    printf "%s\n" "$line2"
fi

for l in "${usage_lines[@]}"; do
    printf "%s\n" "$l"
done
