#!/usr/bin/env python3
"""report-calls.py — シェルスクリプトから `report` の実呼び出しを1行1件で列挙する。

spec: openspec/specs/casting-project-files/spec.md
  Requirement: 検出項目数の表記と実装の一致

casting-structure.bats が「実装が報告する検出カテゴリ数」を機械的に取るための下請け。
grep だけで数えていた頃は、行頭コメント行しか落とせず、次の「コードではない report」を
呼び出しとして数えていた（#163）:

  - ヒアドキュメント本文     usage() { cat <<'EOF' … report "x" … EOF }
  - 行末コメント             true  # report "x" と書き換える
  - 文字列リテラルの中       echo 'usage: report "x" msg'

そこでシェルの引用・コメント・ヒアドキュメントだけを見る軽量スキャナを置き、
「コード領域にある report」に限って数える。完全なシェルパーサではない（`$(…)` の
中身は素通しで、算術展開やプロセス置換も特別扱いしない）。それで足りるのは、
用途が casting-check.sh の自己申告カテゴリの数え上げに限られるためで、判定に迷う形は
すべて**多めに数える側**（偽陽性）に倒してある。数え落とし（偽陰性）は
casting-check.sh の検出カテゴリが黙って減る事故になるので、そちらには倒さない。

出力（1呼び出し1行・空白区切り）:

    <行番号> literal <カテゴリ名>      第1引数が "小文字とハイフン" のリテラル
    <行番号> nonliteral <行の抜粋>     それ以外（report "$var" / 行継続 など）

呼び出しの判定は grep 時代の正規表現をそのまま踏襲する（コード領域に限る点だけが違う）:

  - `report` の直前は行頭か `[;&|(){}` か空白（`x=report` のような語中一致を弾く）
  - `report` の直後は空白 1 個以上＋非空白（`report()` の定義行を弾く。行末の
    `report \` は「非空白 = \」があるので呼び出しとして数え、第1引数は
    見つからないので nonliteral になる ＝ 行継続はサポート外だと検査に出る）

usage: report-calls.py <script-path>
"""

import re
import sys

# 呼び出しの直前に許す文字（行頭は別途）。grep 時代の [;&|(){}[:space:]] と同じ。
_BEFORE = set(";&|(){}") | set(" \t")
# コメントの `#` を語中の `#`（${v#pat} 等）と区別するための直前文字。
_COMMENT_BEFORE = set(";&|()`") | set(" \t")
# 第1引数がリテラルのカテゴリ名か。grep 時代の "[a-z][a-z-]*" と同じ。
_LITERAL_ARG = re.compile(r'^"([a-z][a-z-]*)"')
# ヒアドキュメント演算子の直後（`<<-` の `-`・区切り語）を読むための走査用。
_DELIM_STOP = set(" \t;&|<>()\n")


class _Scanner:
    """引用・コメント・ヒアドキュメントの状態を行またぎで持つ走査器。"""

    def __init__(self):
        self.quote = None          # None / "'" / '"'（行またぎの文字列を追う）
        self.heredocs = []         # 未終端のヒアドキュメント [(区切り語, タブ除去)]

    def scan(self, line):
        """1行を走査して (コード領域マスク, 本文行か) を返す。

        マスクは各文字が「コード領域か」の真偽値リスト。引用の中・コメント・
        ヒアドキュメント本文は False になる。ヒアドキュメント本文の行は
        本文行 False で返し、呼び出し探索の対象から丸ごと外す。
        """
        if self.heredocs:
            delim, strip_tabs = self.heredocs[0]
            body = line.lstrip("\t") if strip_tabs else line
            if body.rstrip() == delim:
                self.heredocs.pop(0)
            return [False] * len(line), False

        mask = [False] * len(line)
        i, n = 0, len(line)
        while i < n:
            ch = line[i]

            if self.quote == "'":
                if ch == "'":
                    self.quote = None
                i += 1
                continue

            if self.quote == '"':
                if ch == "\\" and i + 1 < n:
                    i += 2
                    continue
                if ch == '"':
                    self.quote = None
                i += 1
                continue

            # --- 引用の外 ---
            if ch == "\\":
                i += 2  # エスケープされた文字はコードとして扱わない
                continue

            if ch in "'\"":
                self.quote = ch
                i += 1
                continue

            if ch == "#" and (i == 0 or line[i - 1] in _COMMENT_BEFORE):
                break  # 以降は行末までコメント（マスクは False のまま）

            if ch == "<" and line.startswith("<<", i):
                if line.startswith("<<<", i):
                    mask[i] = mask[i + 1] = mask[i + 2] = True
                    i += 3
                    continue
                i = self._read_heredoc_delim(line, i, mask)
                continue

            mask[i] = True
            i += 1

        return mask, True

    def _read_heredoc_delim(self, line, i, mask):
        """`<<` / `<<-` の区切り語を読み、未終端リストへ積む。次の走査位置を返す。"""
        n = len(line)
        mask[i] = mask[i + 1] = True
        i += 2
        strip_tabs = False
        if i < n and line[i] == "-":
            strip_tabs = True
            i += 1
        while i < n and line[i] in " \t":
            i += 1

        delim = ""
        if i < n and line[i] in "'\"":
            quote = line[i]
            i += 1
            while i < n and line[i] != quote:
                delim += line[i]
                i += 1
            i += 1  # 閉じ引用符
        else:
            while i < n and line[i] not in _DELIM_STOP:
                if line[i] == "\\":       # <<\EOF は展開なしの引用形
                    i += 1
                    continue
                delim += line[i]
                i += 1

        if delim:
            self.heredocs.append((delim, strip_tabs))
        return i


def report_calls(text):
    """`report` の実呼び出しを (行番号, "literal"/"nonliteral", 詳細) で列挙する。"""
    scanner = _Scanner()
    for lineno, raw in enumerate(text.splitlines(), start=1):
        mask, is_source = scanner.scan(raw)
        if not is_source:
            continue

        start = 0
        while True:
            idx = raw.find("report", start)
            if idx < 0:
                break
            start = idx + 1
            end = idx + len("report")
            if not all(mask[idx:end]):
                continue                      # 引用の中・コメント
            if idx > 0 and raw[idx - 1] not in _BEFORE:
                continue                      # 語中の一致（x=report 等）

            rest = raw[end:]
            stripped = rest.lstrip(" \t")
            if len(stripped) == len(rest) or not stripped:
                continue                      # report( / 行末の裸 report は呼び出しでない

            m = _LITERAL_ARG.match(stripped)
            if m:
                yield lineno, "literal", m.group(1)
            else:
                yield lineno, "nonliteral", stripped[:60]


def main(argv):
    if len(argv) != 2:
        print("usage: report-calls.py <script-path>", file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as fh:
        text = fh.read()
    for lineno, kind, detail in report_calls(text):
        print(f"{lineno} {kind} {detail}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
