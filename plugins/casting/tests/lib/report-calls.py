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
「コード領域にある report」に限って数える。完全なシェルパーサではない（プロセス置換や
パラメータ展開の中の入れ子は特別扱いしない）。それで足りるのは、用途が casting-check.sh の
自己申告カテゴリの数え上げに限られるためで、判定に迷う形はすべて**多めに数える側**
（偽陽性）に倒してある。数え落とし（偽陰性）は casting-check.sh の検出カテゴリが黙って
減る事故になるので、そちらには倒さない。

その「数え落とさない」側の取りこぼしを塞いだのが #175 で、次の4形を追加で追う:

  - 算術式の中の左シフト     (( v = 1 << 2 )) / $(( 1 << 2 ))
                             `<<` をヒアドキュメント開始と誤認するとファイル末尾まで
                             本文扱いになり、以降の呼び出しが全消滅していた
  - ANSI-C クオート          msg=$'don\\'t'
                             `\\'` を終端と誤認して引用状態が解除できず、以降が全消滅していた
  - 二重引用の中の $()       out="$(report "x" "m")"
  - 未引用ヒアドキュメント本文の $()  cat <<EOS … $(report "x" "m") … EOS
                             どちらもコマンド置換の中は実行されるのでコード領域

走査は「文脈フレームのスタック」で行う。フレームの種類とコード領域の扱いは次のとおり:

  code / subst / backtick / arith   コード領域（arith だけは `<<` `>>` を演算子として読む）
  dquote / heredoc                  非コード。ただし中の `$(…)` `` `…` `` はコード領域として再走査する
  squote / ansic / heredoc-literal  すべて非コード（引用ヒアドキュメント本文は展開されない）

出力（1呼び出し1行・空白区切り）:

    <行番号> literal <カテゴリ名>      第1引数が "小文字とハイフン" のリテラル
    <行番号> nonliteral <行の抜粋>     それ以外（report "$var" / 行継続 など）

呼び出しの判定は grep 時代の正規表現をそのまま踏襲する（コード領域に限る点だけが違う）:

  - `report` の直前は行頭か `[;&|(){}` か空白（`x=report` のような語中一致を弾く）
  - `report` の直後は空白 1 個以上＋非空白（`report()` の定義行を弾く。行末の
    `report \\` は「非空白 = \\」があるので呼び出しとして数え、第1引数は
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

# コード領域として扱うフレーム。この中の `report` だけを呼び出しとして数える。
_CODE_KINDS = ("code", "subst", "backtick", "arith")
# 中身は非コードだが `$(…)` `` `…` `` だけはコードとして再走査するフレーム。
_EXPANDING_KINDS = ("dquote", "heredoc")


class _Frame:
    """走査中の文脈（引用・コマンド置換・算術式・ヒアドキュメント本文）1つ分。"""

    __slots__ = ("kind", "depth", "delim", "strip_tabs")

    def __init__(self, kind, delim="", strip_tabs=False):
        self.kind = kind
        self.depth = 0          # コード領域フレーム内の丸括弧の入れ子（`$(…)` の終端判定用）
        self.delim = delim      # ヒアドキュメントの区切り語
        self.strip_tabs = strip_tabs  # `<<-` の先頭タブ除去


class _Scanner:
    """引用・コメント・ヒアドキュメントの状態を行またぎで持つ走査器。"""

    def __init__(self):
        self.stack = [_Frame("code")]
        self.pending_heredocs = []  # この行で開いたヒアドキュメント（本文は次の行から）

    def scan(self, line):
        """1行を走査してコード領域マスク（各文字がコード領域かの真偽値リスト）を返す。

        引用の中・コメント・ヒアドキュメント本文は False になる。ただし二重引用と
        未引用ヒアドキュメント本文の中の `$(…)` `` `…` `` はコード領域として走査する。
        """
        mask = [False] * len(line)

        top = self.stack[-1]
        if top.kind in ("heredoc", "heredoc-literal"):
            body = line.lstrip("\t") if top.strip_tabs else line
            if body.rstrip() == top.delim:
                self.stack.pop()
                return mask
            if top.kind == "heredoc-literal":
                return mask  # 引用ヒアドキュメントの本文は展開されないので丸ごと非コード

        self._scan_chars(line, mask)

        # 本文は次の行から始まる。1行に複数あるときは先に書いた方が先に閉じる＝上に積む。
        for delim, strip_tabs, expand in reversed(self.pending_heredocs):
            kind = "heredoc" if expand else "heredoc-literal"
            self.stack.append(_Frame(kind, delim=delim, strip_tabs=strip_tabs))
        self.pending_heredocs = []

        return mask

    def _scan_chars(self, line, mask):
        i, n = 0, len(line)
        while i < n:
            frame = self.stack[-1]
            kind = frame.kind
            ch = line[i]

            if kind == "squote":
                if ch == "'":
                    self.stack.pop()
                i += 1
                continue

            if kind == "ansic":
                # $'…' の中はバックスラッシュが効く（\' は終端ではない）。
                if ch == "\\" and i + 1 < n:
                    i += 2
                    continue
                if ch == "'":
                    self.stack.pop()
                i += 1
                continue

            if kind in _EXPANDING_KINDS:
                if ch == "\\" and i + 1 < n:
                    i += 2
                    continue
                if ch == "$" and line.startswith("$(", i):
                    i = self._open_substitution(line, i, mask)
                    continue
                if ch == "`":
                    self.stack.append(_Frame("backtick"))
                    mask[i] = True
                    i += 1
                    continue
                if kind == "dquote" and ch == '"':
                    self.stack.pop()
                i += 1
                continue

            # --- コード領域（code / subst / backtick / arith）---
            if ch == "\\" and i + 1 < n:
                i += 2  # エスケープされた文字はコードとして扱わない
                continue

            if ch == "$" and line.startswith("$'", i):
                self.stack.append(_Frame("ansic"))
                i += 2
                continue

            if ch == "$" and line.startswith("$(", i):
                i = self._open_substitution(line, i, mask)
                continue

            if ch in "'\"":
                self.stack.append(_Frame("squote" if ch == "'" else "dquote"))
                i += 1
                continue

            if ch == "`":
                if kind == "backtick":
                    self.stack.pop()
                else:
                    self.stack.append(_Frame("backtick"))
                mask[i] = True
                i += 1
                continue

            if ch == "#" and (i == 0 or line[i - 1] in _COMMENT_BEFORE):
                break  # 以降は行末までコメント（マスクは False のまま）

            if kind == "arith" and line.startswith("))", i):
                self.stack.pop()
                mask[i] = mask[i + 1] = True
                i += 2
                continue

            if line.startswith("((", i):
                # `((` / `$((` の中では `<<` は左シフト演算子。ヒアドキュメントと誤認しない。
                self.stack.append(_Frame("arith"))
                mask[i] = mask[i + 1] = True
                i += 2
                continue

            if ch == "(":
                frame.depth += 1
                mask[i] = True
                i += 1
                continue

            if ch == ")":
                if frame.depth > 0:
                    frame.depth -= 1
                elif kind in ("subst", "arith"):
                    self.stack.pop()
                mask[i] = True
                i += 1
                continue

            if kind == "arith" and (line.startswith("<<", i) or line.startswith(">>", i)):
                mask[i] = mask[i + 1] = True
                i += 2
                continue

            if ch == "<" and line.startswith("<<", i):
                if line.startswith("<<<", i):
                    mask[i] = mask[i + 1] = mask[i + 2] = True
                    i += 3
                    continue
                i = self._read_heredoc_delim(line, i, mask)
                continue

            mask[i] = True
            i += 1

    def _open_substitution(self, line, i, mask):
        """`$(` / `$((` を開く。次の走査位置を返す。"""
        if line.startswith("$((", i):
            self.stack.append(_Frame("arith"))
            mask[i] = mask[i + 1] = mask[i + 2] = True
            return i + 3
        self.stack.append(_Frame("subst"))
        mask[i] = mask[i + 1] = True
        return i + 2

    def _read_heredoc_delim(self, line, i, mask):
        """`<<` / `<<-` の区切り語を読み、この行の未開始リストへ積む。次の走査位置を返す。"""
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
        expand = True  # 区切り語を引用・エスケープすると本文は展開されない
        if i < n and line[i] in "'\"":
            quote = line[i]
            expand = False
            i += 1
            while i < n and line[i] != quote:
                delim += line[i]
                i += 1
            i += 1  # 閉じ引用符
        else:
            while i < n and line[i] not in _DELIM_STOP:
                if line[i] == "\\":       # <<\EOF は展開なしの引用形
                    expand = False
                    i += 1
                    continue
                delim += line[i]
                i += 1

        if delim:
            self.pending_heredocs.append((delim, strip_tabs, expand))
        return i


def report_calls(text):
    """`report` の実呼び出しを (行番号, "literal"/"nonliteral", 詳細) で列挙する。"""
    scanner = _Scanner()
    for lineno, raw in enumerate(text.splitlines(), start=1):
        mask = scanner.scan(raw)
        if not any(mask):
            continue

        start = 0
        while True:
            idx = raw.find("report", start)
            if idx < 0:
                break
            start = idx + 1
            end = idx + len("report")
            if not all(mask[idx:end]):
                continue                      # 引用の中・コメント・ヒアドキュメント本文
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
