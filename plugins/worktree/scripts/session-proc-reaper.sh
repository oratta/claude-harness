#!/usr/bin/env bash
# session-proc-reaper.sh — Claude のセッションが起動したプロセスを止める本体（issue #470）
#
#   session-proc-reaper.sh --session-end <mark>   持ち主の終了を待ってから、その目印のプロセスを止める
#   session-proc-reaper.sh --sweep                持ち主がもういない目印のプロセスを全部止める
#
# 目印: 環境変数 CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>。SessionStart フック
# （session-proc-mark.sh）が CLAUDE_ENV_FILE に書き、Bash ツールから起動したプロセスが引き継ぐ。
#
# 止める対象（守備範囲）: 入力は `ps -U <自分の uid>` の一覧だけ。拾うのは目印を持つプロセスと、
# そこから環境変数が読めないプロセスだけを経由して届く子孫。環境変数が読めて目印を持たない
# プロセス（無い・空・別の値）に当たったら、そのプロセスも配下も見ない。止め漏れは wt-clean の
# kill_devserver_under が最後に拾うので、報告のたびに判定規則を足していかない。
#
# このファイルは session-proc-mark.sh / session-proc-end.sh からも source される。
# source されたときは関数の定義だけを行い、main は走らせない。
#
# テスト用の環境変数（本番で設定する想定はない）:
#   SESSION_REAPER_OWNER_WAIT_SECS      持ち主の終了を待つ上限（既定 30）
#   SESSION_REAPER_TERM_GRACE_SECS      TERM から生存確認までの待ち（既定 3）
#   SESSION_REAPER_SWEEP_INTERVAL_SECS  掃除の最小間隔（既定 600。session-proc-mark.sh が読む）
#   SESSION_REAPER_PS_FIXTURE_DIR       ps を実行せずこのディレクトリの固定出力を読む。このときは
#                                       信号を送らず DRY 行をログに書くだけにする
#                                       （ps-env.txt: pid ppid command+env / ps-comm.txt: pid comm /
#                                        lstart.txt: pid lstart）
#   SESSION_REAPER_LOG_DIR              ログとスタンプファイルの置き場所
#   SESSION_REAPER_HOOK_PID             持ち主を探し始める PID（既定はフック自身の $$）
#
# bash 3.2（macOS 標準）で動くように書く。zsh の落とし穴（`for pid in $pids`・ループ内の
# `local` の再宣言・`(` をパターンに使う）も避ける（wt-clean の kill_devserver_under と同じ注意）。

SRP_MARK_VAR=CLAUDE_SESSION_PROC_MARK
SRP_LOG_NAME=session-devserver-cleanup.log
# shellcheck disable=SC2034  # session-proc-mark.sh が使う
SRP_STAMP_NAME=session-devserver-cleanup.sweep-stamp
SRP_LOG_MAX_BYTES=1048576

# --- ps の出どころ（固定出力か実際の ps か） ---

# pid ppid command（argv と環境変数が空白でつながったもの）
srp_ps_env_list() {
  if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
    cat "$SESSION_REAPER_PS_FIXTURE_DIR/ps-env.txt" 2>/dev/null
  else
    # macOS の ps は BSD 形式の eww と -U を同時に使えないので -E を使う
    LC_ALL=C ps -U "$(id -u)" -ww -E -o pid=,ppid=,command= 2>/dev/null
  fi
}

# pid comm
srp_ps_comm_list() {
  if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
    cat "$SESSION_REAPER_PS_FIXTURE_DIR/ps-comm.txt" 2>/dev/null
  else
    LC_ALL=C ps -U "$(id -u)" -o pid=,comm= 2>/dev/null
  fi
}

# 固定出力のファイル $1 から pid $2 の行の 2 列目以降を返す
srp_fixture_field() { # <file> <pid>
  awk -v p="$2" '$1 == p { sub(/^[ \t]*[0-9]+[ \t]+/, ""); print; exit }' \
    "$SESSION_REAPER_PS_FIXTURE_DIR/$1" 2>/dev/null
}

srp_proc_ppid() { # <pid>
  if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
    srp_fixture_field ps-env.txt "$1" | awk '{print $1}'
  else
    ps -o ppid= -p "$1" 2>/dev/null | tr -d ' '
  fi
}

srp_proc_comm() { # <pid>
  if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
    srp_fixture_field ps-comm.txt "$1"
  else
    ps -o comm= -p "$1" 2>/dev/null
  fi
}

srp_proc_args() { # <pid>
  if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
    srp_fixture_field ps-env.txt "$1" | sed -E 's/^[0-9]+[[:space:]]+//'
  else
    ps -ww -o command= -p "$1" 2>/dev/null
  fi
}

# comm の basename（ログインシェルの先頭の `-` を落とす）
srp_basename() {
  local c=$1
  c=${c#-}
  c=${c##*/}
  printf '%s' "$c"
}

# --- 持ち主と目印 ---

# 開始時刻から英数字以外を除いたもの。LC_ALL=C を付けないと macOS の lstart はロケールで
# 書式が変わり、目印付けと生存判定が別ロケールで走ると生きている持ち主を死んだと誤判定する。
# lstart は TZ の現地時刻で出るので、TZ=UTC も固定する（TZ の違う環境で走っても同じ値になる）。
# プロセスが無ければ空。
srp_start_token() { # <pid>
  if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
    srp_fixture_field lstart.txt "$1" | LC_ALL=C tr -cd 'A-Za-z0-9'
  else
    LC_ALL=C TZ=UTC ps -o lstart= -p "$1" 2>/dev/null | LC_ALL=C tr -cd 'A-Za-z0-9'
  fi
}

# $1 から親をたどり（上限 8 段）、最初に見つかった Claude Code の PID を返す。
# comm の basename が claude（ネイティブ版）か、node で引数に @anthropic-ai/claude-code を含む（npm 版）。
srp_find_owner() { # <start_pid>
  local pid=$1 i=0 comm
  while [ "$i" -lt 8 ]; do
    case "$pid" in ''|0|1|*[!0-9]*) return 1 ;; esac
    comm=$(srp_basename "$(srp_proc_comm "$pid")")
    case "$comm" in
      claude) printf '%s' "$pid"; return 0 ;;
      node)
        case "$(srp_proc_args "$pid")" in
          *@anthropic-ai/claude-code*) printf '%s' "$pid"; return 0 ;;
        esac ;;
    esac
    pid=$(srp_proc_ppid "$pid")
    i=$((i + 1))
  done
  return 1
}

srp_mark_for() { # <owner_pid>
  local tok
  tok=$(srp_start_token "$1")
  [ -n "$tok" ] || return 1
  printf '%s.%s' "$1" "$tok"
}

srp_valid_mark() { # <mark>
  printf '%s' "$1" | grep -Eq '^[0-9]+\.[A-Za-z0-9]+$'
}

# 目印の持ち主（PID と開始時刻の組）が生きているか
srp_owner_alive() { # <mark>
  local pid=${1%%.*} tok=${1#*.}
  [ "$(srp_start_token "$pid")" = "$tok" ]
}

# --- 止める対象の決定 ---

# 「環境変数が読めない」= `[A-Za-z_][A-Za-z0-9_]*=` の形の語が 1 つも無い。読めるなら真。
srp_env_readable() { # <command+env>
  printf '%s\n' "$1" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { f = 1; exit } } END { exit(f ? 0 : 1) }'
}

# 目印 $1 の対象を「pid kind ppid comm」で 1 行ずつ出す（kind は mark か desc）。子を親より先の順に出す。
# $2 は除く PID の空白区切り（自分自身とその祖先）。除いた PID の配下にも降りない。
srp_select_targets() { # <mark> <exclude_pids>
  local commf envf
  commf=$(mktemp "${TMPDIR:-/tmp}/srp-comm.XXXXXX") || return 1
  envf=$(mktemp "${TMPDIR:-/tmp}/srp-env.XXXXXX") || { rm -f "$commf"; return 1; }
  srp_ps_comm_list >"$commf"
  srp_ps_env_list >"$envf"
  awk -v want="${SRP_MARK_VAR}=$1" -v excl=" $2 " '
    FNR == NR {
      p = $1; sub(/^[ \t]*[0-9]+[ \t]+/, ""); comm[p] = $0; next
    }
    {
      p = $1; pp = $2
      if (p !~ /^[0-9]+$/) next
      parent[p] = pp; seen[p] = 1; order[n++] = p
      kids[pp] = kids[pp] " " p
      readable[p] = 0; marked[p] = 0
      for (i = 3; i <= NF; i++) {
        if ($i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) readable[p] = 1
        if ($i == want) marked[p] = 1
      }
    }
    END {
      qh = 0; qt = 0
      for (k = 0; k < n; k++) {
        p = order[k]
        if (!marked[p] || index(excl, " " p " ")) continue
        add[p] = "mark"; q[qt++] = p
      }
      while (qh < qt) {
        x = q[qh++]
        m = split(kids[x], ch, " ")
        for (j = 1; j <= m; j++) {
          c = ch[j]
          if (c == "" || (c in add) || index(excl, " " c " ")) continue
          if (marked[c]) continue          # 目印ありはそれ自体が根として拾われている
          if (readable[c]) continue        # 読めて目印が無い・空・別の値 -> 打ち切り
          add[c] = "desc"; q[qt++] = c
        }
      }
      # 子を親より先に出す（q の逆順）。親を先に止めると読めない子は PPID が 1 に変わり、
      # 送る直前の読み直し（同じ PPID か）で外れて止まらずに残る
      for (k = qt - 1; k >= 0; k--) {
        p = q[k]
        print p, add[p], parent[p], comm[p]
      }
    }
  ' "$commf" "$envf"
  rm -f "$commf" "$envf"
}

# 自分自身とその祖先の PID（空白区切り）
srp_self_and_ancestors() {
  local pid=$$ out="" i=0
  while [ "$i" -lt 64 ]; do
    case "$pid" in ''|0|*[!0-9]*) break ;; esac
    out="$out $pid"
    [ "$pid" = 1 ] && break
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    i=$((i + 1))
  done
  printf '%s' "${out# }"
}

# --- ログ ---

srp_log_dir() {
  if [ -n "${SESSION_REAPER_LOG_DIR:-}" ]; then
    printf '%s' "$SESSION_REAPER_LOG_DIR"
  elif [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    printf '%s' "$CLAUDE_PLUGIN_DATA"
  else
    printf '%s' "$HOME/.claude/logs"
  fi
}

srp_log() { # <message>
  local dir f size
  dir=$(srp_log_dir)
  mkdir -p "$dir" 2>/dev/null || return 0
  f="$dir/$SRP_LOG_NAME"
  if [ -f "$f" ]; then
    size=$(wc -c <"$f" 2>/dev/null | tr -d ' ')
    if [ "${size:-0}" -gt "$SRP_LOG_MAX_BYTES" ] 2>/dev/null; then
      mv -f "$f" "$f.1" 2>/dev/null || true
    fi
  fi
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$f" 2>/dev/null || true
}

# --- 停止 ---

# 信号を送る直前の読み直し（PID の使い回し対策）。目印ありは同じ目印を、子孫は同じ comm・PPID を持つか。
srp_still_same() { # <pid> <kind> <ppid> <comm> <mark>
  if [ "$2" = mark ]; then
    ps -ww -E -o command= -p "$1" 2>/dev/null |
      awk -v want="${SRP_MARK_VAR}=$5" '{ for (i = 1; i <= NF; i++) if ($i == want) { f = 1; exit } } END { exit(f ? 0 : 1) }'
  else
    [ "$(ps -o ppid= -p "$1" 2>/dev/null | tr -d ' ')" = "$3" ] || return 1
    [ "$(ps -o comm= -p "$1" 2>/dev/null)" = "$4" ]
  fi
}

# 対象一覧（srp_select_targets の出力）に TERM → 待ち → 生存確認 → KILL を行い、ログに残す。
# 止めた件数を標準出力に返す。
srp_stop_targets() { # <targets> <mark> <trigger>
  local targets=$1 mark=$2 trig=$3 pid kind ppid comm name sent="" count=0
  [ -n "$targets" ] || { printf '0'; return 0; }
  while IFS=' ' read -r pid kind ppid comm; do
    [ -n "$pid" ] || continue
    name=$(srp_basename "$comm")
    if [ -n "${SESSION_REAPER_PS_FIXTURE_DIR:-}" ]; then
      srp_log "DRY pid=$pid comm=$name mark=$mark trigger=$trig"
      count=$((count + 1))
      continue
    fi
    if srp_still_same "$pid" "$kind" "$ppid" "$comm" "$mark" && kill -TERM "$pid" 2>/dev/null; then
      srp_log "TERM pid=$pid comm=$name mark=$mark trigger=$trig"
      sent="$sent$pid $kind $ppid $comm
"
      count=$((count + 1))
    else
      srp_log "GONE pid=$pid comm=$name mark=$mark trigger=$trig"
    fi
  done <<EOF
$targets
EOF
  if [ -n "$sent" ]; then
    sleep "${SESSION_REAPER_TERM_GRACE_SECS:-3}"
    while IFS=' ' read -r pid kind ppid comm; do
      [ -n "$pid" ] || continue
      kill -0 "$pid" 2>/dev/null || continue
      srp_still_same "$pid" "$kind" "$ppid" "$comm" "$mark" || continue
      kill -KILL "$pid" 2>/dev/null &&
        srp_log "KILL pid=$pid comm=$(srp_basename "$comm") mark=$mark trigger=$trig"
    done <<EOF
$sent
EOF
  fi
  printf '%s' "$count"
}

# --- 切り離し起動 ---

# 新しいセッション（プロセスグループも新しくなる）で起動し、呼び出し元はすぐ戻る。
# fork してから setsid するので、呼び出し元がプロセスグループリーダーでも失敗しない。
# 3 以上の fd は閉じる（フックの呼び出し元のパイプを握ったまま残らないため）。
srp_detach() { # <cmd> [args...]
  perl -MPOSIX -e '
    my $p = fork;
    exit 1 unless defined $p;
    exit 0 if $p;
    POSIX::setsid();
    POSIX::close($_) for 3 .. 255;
    exec @ARGV or exit 127;
  ' -- "$@" </dev/null >/dev/null 2>&1
}

# --- モード ---

srp_run_session_end() { # <mark>
  local mark=$1 waited=0 limit targets n
  limit=${SESSION_REAPER_OWNER_WAIT_SECS:-30}
  while srp_owner_alive "$mark"; do
    if [ "$waited" -ge "$limit" ]; then
      srp_log "none mark=$mark trigger=session-end reason=owner-alive"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  targets=$(srp_select_targets "$mark" "$(srp_self_and_ancestors)")
  n=$(srp_stop_targets "$targets" "$mark" session-end)
  [ "$n" -gt 0 ] || srp_log "none mark=$mark trigger=session-end"
  return 0
}

srp_run_sweep() {
  local marks mark excl targets total=0 n
  marks=$(srp_ps_env_list | awk -v pre="${SRP_MARK_VAR}=" '
    { for (i = 3; i <= NF; i++) if (index($i, pre) == 1) { v = substr($i, length(pre) + 1); if (v != "") print v } }
  ' | sort -u)
  excl=$(srp_self_and_ancestors)
  while IFS= read -r mark; do
    [ -n "$mark" ] || continue
    srp_valid_mark "$mark" || continue
    srp_owner_alive "$mark" && continue
    targets=$(srp_select_targets "$mark" "$excl")
    n=$(srp_stop_targets "$targets" "$mark" sweep)
    total=$((total + n))
  done <<EOF
$marks
EOF
  [ "$total" -gt 0 ] || srp_log "none mark=- trigger=sweep"
  return 0
}

srp_main() {
  case "${1:-}" in
    --session-end)
      if ! srp_valid_mark "${2:-}"; then
        echo "session-proc-reaper: invalid mark: '${2:-}'" >&2
        return 2
      fi
      srp_run_session_end "$2" ;;
    --sweep)
      srp_run_sweep ;;
    *)
      echo "usage: session-proc-reaper.sh --session-end <mark> | --sweep" >&2
      return 2 ;;
  esac
}

# source されたときは関数の定義だけ（mark.sh / end.sh から読み込まれる）
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -u
  srp_main "$@"
  exit $?
fi
