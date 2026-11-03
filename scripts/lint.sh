#!/bin/sh
# ─────────────────────────────────────────────────────────────
# lint.sh — claude-harness 統一 lint ランナー（shellcheck ＋ claude plugin validate）
#
# git 追跡下の全 *.sh に shellcheck をかける。`_longruns/` 配下は過去の自律実行の
# 成果物アーカイブ（配布されるコードではない）なので pathspec で除外する。
# 対象はハードコードせず `git ls-files` で動的に列挙する。
# 続けて、リポジトリ直下と各プラグイン（plugins/<name>）に Claude Code 本体の検証
# `claude plugin validate` を走らせる（予約名・宣言していない設定値・壊れたパスを PR の段階で拾う）。
#
#   scripts/lint.sh                全 *.sh を検査し、直下と全プラグインを検証
#   scripts/lint.sh worktree       パスに "worktree" を含む *.sh と、plugins/<name>/ に
#                                  "worktree" を含むプラグインだけ（直下は検証しない）
#   scripts/lint.sh worktree infra 複数フィルタ（OR。いずれかに部分一致で対象）
#
# 重大度に --severity=warning を選んだ理由:
#   既定の shellcheck は style/info まで報告するが、これらは多分に好みの問題
#   （例: SC2181「$? を直接見ろ」/ SC2012「ls より find」/ SC2086 info）で、
#   健全な既存コードを大量に赤くする。移植性・正確性に直結する warning 以上を
#   ゲートにするのが CI の現実的な線引き。error だけに絞ると構文レベルしか拾えず
#   quoting バグ等を見逃すため、その中間の warning を採用する。
#
# 設計:
#   - 発見はハードコードせず `git ls-files '*.sh'`。新規スクリプトを自動で拾う。
#   - cwd 非依存: $0 の所在から repo ルートを解決して git / shellcheck を叩く。
#   - shellcheck 未導入なら導入手順を出して非0終了（無言成功にしない）。
#   - このファイル自身も対象に含まれる（自己適用）。
#   - 検証は shellcheck が指摘を出しても走らせ、どちらかが失敗なら非0終了。
#   - 検証に --strict は付けない。version 未記載の警告は、版を commit SHA で決める
#     運用どおりなので、警告では落とさない（エラーだけで非0）。
#   - claude が無い環境（CI のランナー）では検証を飛ばし、理由を出して失敗にしない。
#   - 検証が通った対象は 1 行、落ちた対象は検証の出力をそのまま出す（警告を見たいときは
#     `claude plugin validate plugins/<name>` を直接走らせる）。
#   - POSIX sh 互換（bashism を使わない）。
# ─────────────────────────────────────────────────────────────
set -u

# 未導入なら即エラー（shellcheck が無いのに無言で成功扱いにしない）。
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck が見つかりません。次のコマンドで導入してください:" >&2
  echo "  macOS:  brew install shellcheck" >&2
  echo "  Ubuntu: sudo apt-get install -y shellcheck" >&2
  exit 1
fi

# $0 の所在から repo ルートを解決（cwd に依存しない）。scripts/ の親がルート。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 対象を動的に列挙。_longruns/ は過去実行のアーカイブなので除外する。
# 代入コンテキストなので単語分割は起きない（改行区切りで受ける）。
ALL_FILES=$(git -C "$ROOT" ls-files -- '*.sh' ':(exclude)_longruns/')

# フィルタ引数があればパス部分一致（OR）で絞る。
FILES=""
for f in $ALL_FILES; do
  if [ "$#" -gt 0 ]; then
    match=0
    for pat in "$@"; do
      case "$f" in
        *"$pat"*) match=1; break ;;
      esac
    done
    [ "$match" -eq 1 ] || continue
  fi
  FILES="$FILES $f"
done

# 対象が空 = フィルタ指定ミス、または .sh が 1 件も無い。非0で知らせる。
if [ -z "$FILES" ]; then
  if [ "$#" -gt 0 ]; then
    echo "no shell scripts matched filter: $*" >&2
  else
    echo "no shell scripts found under $ROOT" >&2
  fi
  exit 1
fi

echo "▶ shellcheck --severity=warning:"
for f in $FILES; do
  echo "  $f"
done
echo "----------------------------------------"

# 全ファイルへ一括適用し、最初の指摘で止めない。相対パス表示のため repo ルートで実行。
# FILES は空白区切りの意図的な単語分割（各要素は空白を含まない git パス）。
# shellcheck disable=SC2086  # $FILES を意図的に単語分割してファイル列として渡す
( cd "$ROOT" && shellcheck --severity=warning $FILES )
rc=$?

echo "========================================"
if [ "$rc" -eq 0 ]; then
  echo "shellcheck: 指摘なし"
else
  echo "shellcheck: 指摘あり（上記参照）"
fi

# ── 公式の検証（claude plugin validate）────────────────────────
# 検証は shellcheck が指摘を出しても走らせ、最後に両方の結果で終了コードを決める。
# 対象: フィルタ無しならリポジトリ直下（.）と、git 追跡下の plugins/<name>/.claude-plugin/plugin.json
# を持つ各プラグイン。フィルタがあれば plugins/<name>/ への部分一致（OR）で絞り、直下は検証しない。
VTARGETS=""
[ "$#" -gt 0 ] || VTARGETS="."
for pj in $(git -C "$ROOT" ls-files -- 'plugins/*/.claude-plugin/plugin.json'); do
  dir="${pj%/.claude-plugin/plugin.json}"
  if [ "$#" -gt 0 ]; then
    match=0
    for pat in "$@"; do
      case "$dir/" in
        *"$pat"*) match=1; break ;;
      esac
    done
    [ "$match" -eq 1 ] || continue
  fi
  VTARGETS="$VTARGETS $dir"
done

vrc=0
echo "----------------------------------------"
if ! command -v claude >/dev/null 2>&1; then
  # CI のランナーには claude が無い。失敗にすると CI が必ず落ちるので、飛ばして理由だけ出す。
  echo "claude plugin validate: 飛ばした（claude コマンドが見つからないため）" >&2
elif [ -z "$VTARGETS" ]; then
  echo "claude plugin validate: フィルタに一致するプラグインが無いので飛ばした"
else
  echo "▶ claude plugin validate:"
  for t in $VTARGETS; do
    # 警告（version 未記載など）では落とさないため --strict は付けない。
    out=$(cd "$ROOT" && claude plugin validate "$t" 2>&1)
    if [ "$?" -eq 0 ]; then
      echo "  ok: $t"
    else
      vrc=1
      echo "  NG: $t"
      printf '%s\n' "$out"
    fi
  done
  echo "========================================"
  if [ "$vrc" -eq 0 ]; then
    echo "claude plugin validate: エラーなし"
  else
    echo "claude plugin validate: エラーあり（上記参照）"
  fi
fi

[ "$rc" -eq 0 ] && [ "$vrc" -eq 0 ] || exit 1
exit 0
