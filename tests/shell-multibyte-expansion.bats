#!/usr/bin/env bats
#
# 変数展開の直後に非 ASCII 文字が続く書き方を禁止するガード。
#
# 背景:
#   bash 3.2（macOS の /bin/sh・/bin/bash はこれ）は UTF-8 ロケール下で、
#   波括弧を付けない変数展開の直後に多バイト文字が続くと、その多バイト列の
#   バイトを変数名の一部として読み込む。結果 "SKIPPED<0xef>: unbound variable"
#   のような形で set -u に引っかかって即死する。
#
#   実害の出方が意地悪で、Linux の dash / 新しい bash は正しく解釈するため
#   CI（ubuntu）では緑のまま、macOS のローカル実行だけが落ちる。実際
#   scripts/test.sh は bats 768 件すべて ok を出したあと、最後のサマリ行で
#   この地雷を踏んで exit 1 していた（テストは全部通っているのにランナーが失敗する）。
#
#   同種の地雷は書くたびに再発する（別リポで 3 ファイル連続で踏んだ実績がある）。
#   人間のレビューで毎回見つけるのは非現実的なので、機械で掃引して落とす。
#
# 直し方:
#   波括弧で変数名の終わりを明示する。日本語混じりの文言では常にこの形にする。
#     NG: 波括弧なしの $COUNT を書き、その直後に全角文字（全角の閉じ括弧など）を続ける
#     OK: echo "済み: ${COUNT}（件）"
#   NG 例をそのままの字面でここに書くとこのガード自身が検出してしまうため、
#   NG 側は文章で説明している（実際にそうなることは確認済み）。
#
# 対象:
#   git 追跡下の *.sh / *.bash / *.bats（ファイル全体）と *.yml / *.yaml
#   （`run:` の値＝ workflow YAML に埋め込まれたシェルだけ）。#171 まで YAML が
#   対象外で、auto-merge.yml の `run:` ブロックだけがガードを素通りしていた。
#   `.github/workflows/` に限らず全 YAML を見るのは、配布用の workflow
#   テンプレートが `plugins/agent-owner/templates/*.yml` のように別の場所にも
#   置かれており、パスで絞ると取りこぼすため。
#   _longruns/ は過去実行のアーカイブなので除外。コメント行も対象に含める
#   （コピペ元になるため）。
#
#   検出ロジックの本体は tests/lib/scan-multibyte-expansion.py。bats から
#   切り出してあるのは、ガード自身をフィクスチャで検証できるようにするため。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCANNER="${REPO_ROOT}/tests/lib/scan-multibyte-expansion.py"
}

@test "no bare variable expansion is directly followed by a non-ASCII character" {
  cd "$REPO_ROOT"
  files="$(git ls-files -- '*.sh' '*.bash' '*.bats' '*.yml' '*.yaml' ':(exclude)_longruns/')"
  [ -n "$files" ]

  # shellcheck disable=SC2086  # 改行区切りのパス列を意図的に単語分割して渡す
  run python3 "$SCANNER" $files
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- ガード自身の検証（フィクスチャ） ---

@test "guard: detects a bare expansion inside a workflow run: block" {
  fixture="${BATS_TEST_TMPDIR}/bad.yml"
  # 全角の閉じ括弧の直前に波括弧なしの展開を置く（このファイル自身が検出されないよう
  # printf でバイト列を組み立てる）。
  {
    echo 'jobs:'
    echo '  build:'
    echo '    steps:'
    echo '      - run: |'
    printf '          echo "完了（sha=%sHEAD_SHA）"\n' '$'
  } > "$fixture"

  run python3 "$SCANNER" "$fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HEAD_SHA"* ]]
  [[ "$output" == *":5:"* ]]
}

@test "guard: accepts the braced form inside a workflow run: block" {
  fixture="${BATS_TEST_TMPDIR}/good.yml"
  {
    echo 'jobs:'
    echo '  build:'
    echo '    steps:'
    echo '      - run: |'
    printf '          echo "完了（sha=%s{HEAD_SHA}）"\n' '$'
  } > "$fixture"

  run python3 "$SCANNER" "$fixture"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard: ignores non-shell YAML outside run: (no false positive on job names)" {
  fixture="${BATS_TEST_TMPDIR}/outside.yml"
  {
    echo 'jobs:'
    echo '  build:'
    printf '    name: "ビルド %sSTAGE（本番）"\n' '$'
    echo '    steps:'
    echo '      - run: echo ok'
  } > "$fixture"

  run python3 "$SCANNER" "$fixture"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard: still scans plain shell files in full (comments included)" {
  fixture="${BATS_TEST_TMPDIR}/bad.sh"
  {
    echo '#!/bin/sh'
    printf '# 件数: %sCOUNT（件）\n' '$'
  } > "$fixture"

  run python3 "$SCANNER" "$fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"COUNT"* ]]
}
