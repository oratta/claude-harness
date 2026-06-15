#!/usr/bin/env bash
#
# openspec-preflight.sh — exec Step 0 の OpenSpec 前提条件チェック
# （change-1: openspec-degradation）
#
# 役割: longrun 自律実行を始める前に、(a) OpenSpec CLI が解決可能か、
#       (b) 対象 repo が openspec init 済み（openspec/ 存在）か を判定し、
#       判定値を標準出力で返す。**判定のみ**を行い、対話（縮退モード提案の
#       AskUserQuestion）や副作用（マーカー作成・openspec/ への書き込み）は
#       一切行わない。対話は exec.md 側が標準出力の値を見て行う。
#
# 判定値（標準出力 / exit code は常に 0 = 「判定自体は成功」）:
#   OK       CLI 解決可能 かつ openspec/ 存在        （通常モード可）
#   NO_CLI   CLI が解決できない（init 判定より優先）  （縮退提案 or セットアップ案内）
#   NO_INIT  CLI は解決可能だが openspec/ が無い      （init or 縮退 or 中断）
#
# 検出契約（plugins/longrun/docs/openspec-cli-verification.md §5 を一次ソース）:
#   CLI 解決 = `command -v openspec` OR `npx --no-install openspec --version`
#             （いずれかが成功すれば解決可能とみなす OR 条件）
#   init     = git root 直下の openspec/ ディレクトリ存在
#
# 使い方:
#   openspec-preflight.sh [repo_dir]
#     repo_dir 省略時は git rev-parse --show-toplevel（無ければ cwd）にフォールバック。
#
# テスト用フック:
#   OPENSPEC_PREFLIGHT_NPX_CMD  npx の代替コマンド（bats で stub 注入する）。
#                               未設定なら実 `npx --no-install openspec --version`。
#
set -u

repo_dir="${1:-}"

# --- repo dir の解決 ---
if [ -z "$repo_dir" ]; then
  if repo_dir="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    :
  else
    repo_dir="$(pwd)"
  fi
fi

# --- (a) CLI 解決チェック（OR 条件） ---
# 1) PATH 上の openspec（volta グローバル等）
cli_ok=0
if command -v openspec >/dev/null 2>&1; then
  cli_ok=1
fi

# 2) npx 解決（repo node_modules / npx キャッシュ）。--no-install で
#    ネットワーク/インストール待ちを避け、純粋な解決可否だけを見る。
if [ "$cli_ok" -eq 0 ]; then
  if [ -n "${OPENSPEC_PREFLIGHT_NPX_CMD:-}" ]; then
    # テスト時は stub コマンドを実行（exit 0 = 解決可能）
    if "$OPENSPEC_PREFLIGHT_NPX_CMD" >/dev/null 2>&1; then
      cli_ok=1
    fi
  else
    if npx --no-install openspec --version >/dev/null 2>&1; then
      cli_ok=1
    fi
  fi
fi

# CLI が解決できなければ NO_CLI（init 判定より優先）
if [ "$cli_ok" -eq 0 ]; then
  echo "NO_CLI"
  exit 0
fi

# --- (b) init 済みチェック ---
if [ -d "${repo_dir}/openspec" ]; then
  echo "OK"
else
  echo "NO_INIT"
fi
exit 0
