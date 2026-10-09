#!/usr/bin/env python3
"""scan-multibyte-expansion.py — 波括弧なし変数展開の直後に非 ASCII が続く箇所を列挙する。

shell-multibyte-expansion.bats の下請け。検出ロジックを bats のヒアドキュメントから
切り出したのは、ガード自身をフィクスチャで検証できるようにするため（#171）。

引数に渡されたファイルを走査対象の種別ごとに読み分ける:

  *.sh / *.bash / *.bats          ファイル全体（コメント行も含む。コピペ元になるため）
  *.yml / *.yaml                  `run:` の値（＝ workflow YAML に埋め込まれたシェル）だけ

YAML を全文走査しない理由は、GitHub Actions の式やジョブ名など**シェルではない**行まで
巻き込んで偽陽性を出すため。逆に `run:` だけに絞れば、`# >>> … <<< …` マーカーで囲まれた
埋め込みスクリプトは必ず `run:` の内側にあるので自動的に対象に入る。

出力は 1 件 1 行の `path:lineno: $NAME -> 行の抜粋`。検出が 1 件でもあれば exit 1。
"""

import pathlib
import re
import sys

# 波括弧なしの $NAME の直後が非 ASCII のものだけを拾う。
# ${NAME} 形式と GitHub の ${{ … }} 式は $ の次が { なので、この正規表現には一致しない。
PATTERN = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*(?=[^\x00-\x7f])")

SHELL_SUFFIXES = (".sh", ".bash", ".bats")
YAML_SUFFIXES = (".yml", ".yaml")

# `run:` キーの行。`- run: |` のようにリスト要素を兼ねる形も拾う。
RUN_KEY = re.compile(r"^(?P<lead>\s*(?:-\s+)*)run:(?P<rest>.*)$")


def embedded_shell_lines(text):
    """workflow YAML から `run:` の値を (行番号, 行) で返す。

    ブロックスカラー（`run: |`）は、キーより深くインデントされた行と空行が本文。
    1 行形式（`run: echo x`）は値そのものが本文。完全な YAML パーサではないが、
    用途が「埋め込みシェルの行を漏れなく拾う」ことなので、判断に迷う形は
    **対象に含める側**（偽陽性）に倒してある。
    """
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        m = RUN_KEY.match(lines[i])
        if not m:
            i += 1
            continue
        key_col = len(m.group("lead"))
        rest = m.group("rest").strip()
        if rest.startswith("|") or rest.startswith(">"):
            i += 1
            while i < len(lines):
                line = lines[i]
                # 空行はブロックの一部。非空行はキーより深いインデントの間だけ本文。
                if line.strip() and (len(line) - len(line.lstrip())) <= key_col:
                    break
                out.append((i + 1, line))
                i += 1
        else:
            if rest:
                out.append((i + 1, rest))
            i += 1
    return out


def scan(path):
    """1 ファイルを走査してヒット行の文字列リストを返す。"""
    p = pathlib.Path(path)
    text = p.read_text(errors="replace")
    suffix = p.suffix

    if suffix in YAML_SUFFIXES:
        numbered = embedded_shell_lines(text)
    elif suffix in SHELL_SUFFIXES:
        numbered = list(enumerate(text.splitlines(), 1))
    else:
        return []

    hits = []
    for lineno, line in numbered:
        for m in PATTERN.finditer(line):
            hits.append(f"{path}:{lineno}: {m.group(0)} -> {line.strip()[:100]}")
    return hits


def main(argv):
    hits = []
    for path in argv:
        hits.extend(scan(path))
    for h in hits:
        print(h)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
