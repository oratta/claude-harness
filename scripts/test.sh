#!/bin/sh
# ─────────────────────────────────────────────────────────────
# test.sh — claude-harness 統一テストランナー（bats）
#
# git 追跡下の全 *.bats を発見して bats に渡す。`_longruns/` 配下は過去の
# 自律実行の成果物アーカイブ（当時のブランチ固有の断定を含む）なので除外する。
#
#   scripts/test.sh                全スイートを実行
#   scripts/test.sh worktree       パスに "worktree" を含むスイートだけ実行
#   scripts/test.sh worktree loops 複数フィルタ（OR。いずれかに部分一致で実行）
#
#   TEST_EXCLUDE="statusline infra" scripts/test.sh
#       空白区切りの除外フィルタ（パス部分一致・OR）。一致したスイートを SKIP する。
#       用途は CI（Linux ランナー）でのプラットフォーム依存スイート除外。除外は
#       無言で減らさず "skipped (excluded): N" として明示する。
#       ※ 現時点で除外が必要なスイートは無い（全スイートが Linux で動く）。
#
# 設計:
#   - 発見はハードコードせず `git ls-files '*.bats'`。新規スイートを自動で拾う。
#   - 実行前に走らせるスイート名を stdout に出す（何を回したかを黙らせない）。
#   - bats を 1 回だけ呼び、TAP のサマリと exit code をそのまま成否とする。
#   - テストが起動した背景プロセスが bats の出力パイプを握って残ると失敗にする
#     （下の「残留プロセス検査」。TEST_RESIDUAL_GRACE で猶予秒を変えられる）。
#   - cwd 非依存: $0 の所在から repo ルートを解決する。
#   - POSIX sh 互換（bashism を使わない）。
# ─────────────────────────────────────────────────────────────
set -u

# 未導入なら即エラー（bats が無いのに無言で成功扱いにしない）。
if ! command -v bats >/dev/null 2>&1; then
  echo "bats が見つかりません。次のコマンドで導入してください:" >&2
  echo "  macOS:  brew install bats-core" >&2
  echo "  Ubuntu: sudo apt-get install -y bats" >&2
  exit 1
fi

# $0 の所在から repo ルートを解決（cwd に依存しない）。scripts/ の親がルート。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST_EXCLUDE="${TEST_EXCLUDE:-}"

# 対象を動的に列挙。_longruns/ のアーカイブスイートは除外する。
# 代入コンテキストなので単語分割は起きない（改行区切りで受ける）。
ALL_SUITES=$(git -C "$ROOT" ls-files -- '*.bats' ':(exclude)_longruns/')

SUITES=""
SKIPPED=0
for f in $ALL_SUITES; do
  # 引数（フィルタ）があれば、パス部分一致するものだけに絞る（OR 判定）。
  if [ "$#" -gt 0 ]; then
    match=0
    for pat in "$@"; do
      case "$f" in
        *"$pat"*) match=1; break ;;
      esac
    done
    [ "$match" -eq 1 ] || continue
  fi

  # TEST_EXCLUDE（空白区切り・部分一致・OR）に一致したら明示 SKIP。
  if [ -n "$TEST_EXCLUDE" ]; then
    excluded=0
    for pat in $TEST_EXCLUDE; do
      case "$f" in
        *"$pat"*) excluded=1; break ;;
      esac
    done
    if [ "$excluded" -eq 1 ]; then
      SKIPPED=$((SKIPPED + 1))
      echo "⏭ skipping $f (TEST_EXCLUDE)"
      continue
    fi
  fi

  SUITES="$SUITES $f"
done

# 対象が空 = フィルタ指定ミス、または全件が除外された。非0で知らせる。
if [ -z "$SUITES" ]; then
  if [ "$#" -gt 0 ]; then
    echo "no test suites matched filter: $*" >&2
  else
    echo "no test suites found under $ROOT" >&2
  fi
  exit 1
fi

echo "▶ bats suites:"
for f in $SUITES; do
  echo "  $f"
done
echo "  (skipped by TEST_EXCLUDE: $SKIPPED)"
echo "----------------------------------------"

# ─────────────────────────────────────────────────────────────
# 残留プロセス検査（issue #215）
#
# bats は TAP 出力パイプを fd 3 に複製して子に渡す。テストが起動した背景プロセスが
# それを握ったまま生き残ると、bats の formatter はパイプの EOF を待ち続け、
# 「TAP は最後まで出るのに bats が終了しない → exit code が取れない」形で止まる。
#
# 対策:
#   1. bats を専用のプロセスグループで起動する（perl の setpgrp。macOS に setsid は無い）。
#      孤児（PPID=1）になった残留でも `pgrep -g` でグループから列挙・回収できる。
#   2. TAP を出す bats-exec-suite が終わったのに bats 本体が RESIDUAL_GRACE 秒以内に
#      終了しなければ「残留プロセスがパイプを握っている」と判定し、残留を表示して
#      グループごと SIGKILL、非 0 で終える。
#   3. bats が正常終了したあともグループに生き残りがあれば同様に失敗にする
#      （fd を閉じていても teardown で回収し忘れた背景プロセスは欠陥）。
#
#   TEST_RESIDUAL_GRACE=<秒>   判定の猶予（既定 15。テストからの短縮用）
# ─────────────────────────────────────────────────────────────
RESIDUAL_GRACE="${TEST_RESIDUAL_GRACE:-15}"

# グループ内の bats 以外のプロセス（＝テストが起動して残った背景プロセス）の pid を列挙する。
residual_pids() { # <pgid>
  for p in $(pgrep -g "$1" 2>/dev/null); do
    cmd=$(ps -o command= -p "$p" 2>/dev/null)
    case "$cmd" in
      ""|*bats-core*|*bats-exec*|*bats-format*) continue ;;
      cat)
        # bats-format-cat の子 cat は bats 自身の一部
        pp=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        case "$(ps -o command= -p "$pp" 2>/dev/null)" in *bats-format*) continue ;; esac ;;
    esac
    echo "$p"
  done
}

# residual_pids を「pid ppid 経過時間 コマンド」で表示する。
print_residuals() { # <pgid>
  for p in $(residual_pids "$1"); do
    ps -o pid=,ppid=,etime=,command= -p "$p" 2>/dev/null | cut -c1-160
  done
}

# 残留を SIGKILL する。bats 本体は殺さない（残留が消えればパイプが閉じて自然に終わる）。
kill_residuals() { # <pgid>
  for p in $(residual_pids "$1"); do
    kill -KILL "$p" 2>/dev/null
  done
}

# status_file が書かれるまで最大 $1 秒待つ。
wait_status() { # <seconds>
  i=0
  while [ "$i" -lt "$1" ] && [ ! -s "$status_file" ]; do sleep 1; i=$((i + 1)); done
}

# shellcheck disable=SC2329  # trap から間接的に呼ばれる
guard_interrupt() {
  pg=$(cat "$pgid_file" 2>/dev/null)
  [ -n "$pg" ] && kill -KILL "-$pg" 2>/dev/null
  rm -rf "$guard_dir"
  exit 130
}

run_bats_guarded() {
  if ! command -v perl >/dev/null 2>&1; then
    echo "⚠ perl が無いので残留プロセス検査なしで bats を実行します" >&2
    # shellcheck disable=SC2086
    ( cd "$ROOT" && bats $SUITES )
    return $?
  fi

  guard_dir=$(mktemp -d) || return 1
  pgid_file="$guard_dir/pgid"
  status_file="$guard_dir/status"

  # perl が自分を新グループの先頭にしてから bats に exec する。pgid = perl の pid。
  # shellcheck disable=SC2086
  ( cd "$ROOT" && TEST_SH_PGID_FILE="$pgid_file" \
      perl -e 'setpgrp(0, 0); open(my $f, ">", $ENV{TEST_SH_PGID_FILE}) or die; print $f $$; close $f; exec @ARGV or die "exec: $!"' \
      -- bats $SUITES
    echo "$?" >"$status_file" ) &
  job=$!

  # Ctrl-C / TERM は専用グループの bats には届かない（バックグラウンド起動）ので転送する
  trap 'guard_interrupt' INT TERM

  # pgid が書かれるまで待つ（perl の起動失敗で status が先に来たらそれで終わる）
  while [ ! -s "$pgid_file" ] && [ ! -s "$status_file" ]; do sleep 0.2; done
  pgid=$(cat "$pgid_file" 2>/dev/null)

  hang=0
  suite_gone_since=""
  while [ ! -s "$status_file" ]; do
    sleep 1
    if [ -z "$pgid" ] || pgrep -g "$pgid" -f bats-exec-suite >/dev/null 2>&1; then
      suite_gone_since=""
      continue
    fi
    now=$(date +%s)
    [ -n "$suite_gone_since" ] || suite_gone_since=$now
    if [ $((now - suite_gone_since)) -ge "$RESIDUAL_GRACE" ]; then
      hang=1
      break
    fi
  done

  if [ "$hang" -eq 1 ]; then
    echo "========================================"
    echo "✖ bats の TAP 出力は終わったのに bats が ${RESIDUAL_GRACE} 秒以内に終了しません。"
    echo "  テストが起動した背景プロセスが bats の出力パイプ（fd 3）を握ったまま残っています:"
    print_residuals "$pgid"
    echo "  背景プロセスは fd 3 以上を閉じて起動し、teardown で回収してください"
    echo "  （plugins/worktree/tests/helper.bash の wt_close_inherited_fds / wt_track_pid を参照）。"
    # 残留を消せばパイプが閉じて bats は自分で終わる。それでも終わらなければグループごと殺す
    kill_residuals "$pgid"
    wait_status "$RESIDUAL_GRACE"
    [ -s "$status_file" ] || kill -KILL "-$pgid" 2>/dev/null
  fi
  wait "$job" 2>/dev/null
  rc=$(cat "$status_file" 2>/dev/null)
  [ -n "$rc" ] || rc=1
  trap - INT TERM

  # 正常終了後の生き残り（fd は閉じているが teardown で回収されなかった背景プロセス）。
  # 直前のテストの子が終了処理中のことがあるので少しだけ待つ。
  if [ "$hang" -eq 0 ] && [ -n "$pgid" ]; then
    i=0
    while [ "$i" -lt 3 ] && pgrep -g "$pgid" >/dev/null 2>&1; do sleep 1; i=$((i + 1)); done
    survivors=$(print_residuals "$pgid")
    if [ -n "$survivors" ]; then
      echo "========================================"
      echo "✖ bats は終了しましたが、テストが起動した背景プロセスが回収されずに残っています:"
      echo "$survivors"
      echo "  背景プロセスは teardown で必ず kill してください（wt_track_pid / wt_kill_tracked_pids）。"
      kill_residuals "$pgid"
      rc=1
    fi
  fi
  rm -rf "$guard_dir"
  [ "$hang" -eq 0 ] || rc=1
  return "$rc"
}

# 相対パス表示のため repo ルートで実行。
# SUITES は空白区切りの意図的な単語分割（各要素は空白を含まない git パス）。
run_bats_guarded
rc=$?

echo "========================================"
if [ "$rc" -eq 0 ]; then
  echo "bats: 全スイート pass（excluded: ${SKIPPED}）"
else
  echo "bats: 失敗あり（上記 TAP 出力の not ok か残留プロセス報告を参照。excluded: ${SKIPPED}）"
fi
exit "$rc"
