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

# 相対パス表示のため repo ルートで実行。
# SUITES は空白区切りの意図的な単語分割（各要素は空白を含まない git パス）。
# shellcheck disable=SC2086  # $SUITES を意図的に単語分割してファイル列として渡す
( cd "$ROOT" && bats $SUITES )
rc=$?

echo "========================================"
if [ "$rc" -eq 0 ]; then
  echo "bats: 全スイート pass（excluded: $SKIPPED）"
else
  echo "bats: 失敗あり（上記 TAP 出力の not ok を参照。excluded: $SKIPPED）"
fi
exit "$rc"
