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
#   git 追跡下の *.sh / *.bash / *.bats。_longruns/ は過去実行のアーカイブなので除外。
#   コメント行も対象に含める（コピペ元になるため）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "no bare variable expansion is directly followed by a non-ASCII character" {
  run python3 - "$REPO_ROOT" <<'PY'
import pathlib, re, subprocess, sys

root = pathlib.Path(sys.argv[1])
files = subprocess.run(
    ["git", "-C", str(root), "ls-files", "*.sh", "*.bash", "*.bats"],
    capture_output=True, text=True, check=True,
).stdout.split()

# 波括弧なしの $NAME の直後が非 ASCII のものだけを拾う。
# ${NAME} 形式は $ の次が { なので、この正規表現には一致しない。
pattern = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*(?=[^\x00-\x7f])")

hits = []
for rel in files:
    if rel.startswith("_longruns/"):
        continue
    text = (root / rel).read_text(errors="replace")
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in pattern.finditer(line):
            hits.append(f"{rel}:{lineno}: {m.group(0)} -> {line.strip()[:100]}")

for h in hits:
    print(h)
sys.exit(1 if hits else 0)
PY
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
