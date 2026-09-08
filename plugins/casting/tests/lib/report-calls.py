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
  - 配列添字の中の左シフト   a[1<<2]=3 / ${a[1<<2]}（#184）
                             配列添字も bash の算術コンテキスト。bash が添字として
                             読む位置の `[` から対応する `]` までを算術として読み、
                             ヒアドキュメントと誤認しない（判定規則は下の「配列添字の
                             判定」）
  - ANSI-C クオート          msg=$'don\\'t'
                             `\\'` を終端と誤認して引用状態が解除できず、以降が全消滅していた
  - 二重引用の中の $()       out="$(report "x" "m")"
  - 未引用ヒアドキュメント本文の $()  cat <<EOS … $(report "x" "m") … EOS
                             どちらもコマンド置換の中は実行されるのでコード領域

走査は「文脈フレームのスタック」で行う。フレームの種類とコード領域の扱いは次のとおり:

  code / subst / backtick / arith / subscript
                                    コード領域（arith と subscript は `<<` `>>` を
                                    演算子として読む。subscript は配列添字の `[` で
                                    開き対応する `]` で閉じる算術コンテキスト）
  dquote / heredoc                  非コード。ただし中の `$(…)` `` `…` `` はコード領域として再走査する
  squote / ansic / heredoc-literal  すべて非コード（引用ヒアドキュメント本文は展開されない）

ヒアドキュメントの終端は行単位で照合する。本文の中で開いたまま閉じ損ねたフレーム
（不均衡な `` ` `` や `'` など）がスタックに残っていても、区切り語の行でそれごと捨てる。
そうしないと本文が終わらず、以降の行が全部本文扱いになって呼び出しを数え落とす。

配列添字の判定（#184、PR #199 レビュー指摘で規則を bash に揃えた）:

  識別子直後の `[` を無条件に添字として開くと、`cat foo[bar <<EOF` のようなマッチしない
  glob でも添字フレームが開き、本物のヒアドキュメント開始 `<<` を演算子として読み飛ばす。
  本文が次の行からコードとして走査され、本文にアポストロフィが1つあるだけで引用フレームが
  開きっぱなしになり、以降のファイル全体の呼び出しが消える（数え落とし側の無言経路）。
  逆に本物の添字を開き損ねても `<<` がヒアドキュメント開始と誤認されて同じ壊れ方をする。
  どちらへ倒しても数え落とすので、この判定だけは「迷ったら多めに数える」で逃げられず、
  bash が添字として読む位置だけを添字として開く:

  - パラメータ展開の中       ${name[…]} / ${#name[…]} / ${!name[…]}
  - 代入語の添字             name[…]=v / name[…]+=v / 複合代入の中の [i]=v
                             `[` が単語の先頭（またはその直後の識別子の先頭が単語の
                             先頭）にあり、対応する `]` の直後が `=` か `+=` のもの

  どちらも、対応する `]` が論理行（行末 `\\` の行継続でつないだ物理行）の中に実在する
  ことを先読みで確かめてから開く。見つからなければ添字ではない（bash も添字を閉じ損ねる
  と構文エラーにする）。`[ -f x ]` の test コマンド・`[[ … ]]`・`echo file[a-z].txt` の
  glob は上のどれにも当たらないので開かない。添字フレームは論理行の終わりで捨てる
  （bash は代入語の添字の中に生の改行も許すが、この用途では追わない）。

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
# 単語の先頭とみなす直前文字（行頭は別途）。代入語 `name[…]=` の判定に使う。
_WORD_BEFORE = _BEFORE | set("`")
# コメントの `#` を語中の `#`（${v#pat} 等）と区別するための直前文字。
_COMMENT_BEFORE = set(";&|()`") | set(" \t")
# 第1引数がリテラルのカテゴリ名か。grep 時代の "[a-z][a-z-]*" と同じ。
_LITERAL_ARG = re.compile(r'^"([a-z][a-z-]*)"')
# ヒアドキュメント演算子の直後（`<<-` の `-`・区切り語）を読むための走査用。
_DELIM_STOP = set(" \t;&|<>()\n")

# コード領域として扱うフレーム。この中の `report` だけを呼び出しとして数える。
_CODE_KINDS = ("code", "subst", "backtick", "arith", "subscript")
# `<<` `>>` をヒアドキュメントでなく演算子として読む算術コンテキストのフレーム。
_ARITH_KINDS = ("arith", "subscript")
# 配列名になりうる識別子文字（bash の変数名）。
_IDENT_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
# パラメータ展開の中の添字 `${name[` `${#name[` `${!name[` の、識別子の直前に来る並び。
_PARAM_BEFORE = ("${", "${#", "${!")
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

    def __init__(self, lines):
        self.lines = lines          # 全物理行（配列添字の閉じ `]` を論理行の中で先読みする）
        self.stack = [_Frame("code")]
        self.pending_heredocs = []  # この行で開いたヒアドキュメント（本文は次の行から）
        self.continued = False      # 走査中の行がコード領域の行末 `\` で次の行へ続くか

    def scan(self, index):
        """物理行 index（0 始まり）を走査してコード領域マスク（各文字がコード領域かの
        真偽値リスト）を返す。

        引用の中・コメント・ヒアドキュメント本文は False になる。ただし二重引用と
        未引用ヒアドキュメント本文の中の `$(…)` `` `…` `` はコード領域として走査する。
        """
        line = self.lines[index]
        mask = [False] * len(line)

        hd = self._innermost_heredoc()
        if hd is not None:
            frame = self.stack[hd]
            body = line.lstrip("\t") if frame.strip_tabs else line
            if body.rstrip() == frame.delim:
                # 区切り語の照合は行単位で、本文の中で開いたまま閉じ損ねたフレーム
                # （不均衡な `` ` `` や `'` など）より優先する。上に残ったフレームごと
                # 捨てないとヒアドキュメントが終端せず、以降の行が全部本文扱いになって
                # 本物の呼び出しを数え落とす。
                del self.stack[hd:]
                return mask
            if frame.kind == "heredoc-literal" and hd == len(self.stack) - 1:
                return mask  # 引用ヒアドキュメントの本文は展開されないので丸ごと非コード

        self.continued = False
        self._scan_chars(index, line, mask)

        # 配列添字は論理行をまたがない。閉じ `]` を見ないまま論理行が終わったら添字
        # フレームを捨て、以降の行の `<<` を演算子扱いのままにしない（残すと本物の
        # ヒアドキュメント開始を取りこぼす側に漏れる）。行継続 `\` で続く行は同じ論理行
        # なので残す（`a[1 + \` の次の行の `2 << 1]=3` はまだ添字の中）。
        if not self.continued:
            while self.stack[-1].kind == "subscript":
                self.stack.pop()

        # 本文は次の行から始まる。1行に複数あるときは先に書いた方が先に閉じる＝上に積む。
        for delim, strip_tabs, expand in reversed(self.pending_heredocs):
            kind = "heredoc" if expand else "heredoc-literal"
            self.stack.append(_Frame(kind, delim=delim, strip_tabs=strip_tabs))
        self.pending_heredocs = []

        return mask

    def _innermost_heredoc(self):
        """スタック最上段から見て最初のヒアドキュメント本文フレームの位置を返す（無ければ None）。"""
        for idx in range(len(self.stack) - 1, -1, -1):
            if self.stack[idx].kind in ("heredoc", "heredoc-literal"):
                return idx
        return None

    def _scan_chars(self, index, line, mask):
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

            # --- コード領域（code / subst / backtick / arith / subscript）---
            if ch == "\\":
                if i + 1 < n:
                    i += 2  # エスケープされた文字はコードとして扱わない
                    continue
                self.continued = True  # 行末の `\` は行継続。次の物理行も同じ論理行
                mask[i] = True
                i += 1
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

            if kind == "subscript" and ch == "]":
                self.stack.pop()
                mask[i] = True
                i += 1
                continue

            if ch == "[" and self._opens_subscript(index, i):
                # 配列添字も bash の算術コンテキスト（a[1<<2]=3 / ${a[1<<2]}。#184）。
                # 対応する `]` までを算術として読み、中の `<<` をヒアドキュメント開始と
                # 誤認しない。開く条件は bash が添字として読む位置に限る（判定規則は
                # モジュール冒頭の「配列添字の判定」）。`cat foo[bar <<EOF` のような
                # マッチしない glob で開くと本物のヒアドキュメント開始を読み飛ばし、
                # 数え落とし側に倒れる（PR #199 レビュー指摘）。
                self.stack.append(_Frame("subscript"))
                mask[i] = True
                i += 1
                continue

            if kind in _ARITH_KINDS and (line.startswith("<<", i) or line.startswith(">>", i)):
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

    def _opens_subscript(self, index, i):
        """物理行 index の位置 i にある `[` が配列添字の開きか。

        パラメータ展開の中（`${name[`）か代入語（単語先頭の `name[…]=` / `[…]=`）で、
        対応する `]` が論理行の中に実在するものだけを添字とみなす。
        """
        line = self.lines[index]
        start = i
        while start > 0 and line[start - 1] in _IDENT_CHARS:
            start -= 1
        prefix = line[:start]

        if start < i and prefix.endswith(_PARAM_BEFORE):
            in_assignment = False
        elif start == 0 or line[start - 1] in _WORD_BEFORE:
            in_assignment = True
        else:
            return False

        end = self._find_subscript_end(index, i)
        if end is None:
            return False
        if not in_assignment:
            return True
        after = self.lines[end[0]][end[1] + 1:]
        return after.startswith("=") or after.startswith("+=")

    def _find_subscript_end(self, index, i):
        """物理行 index の位置 i の `[` に対応する `]` を論理行の中で探す。

        引用の中と `\\` エスケープは読み飛ばし、入れ子の `[` `]` は深さで追う。
        行末 `\\` の行継続は次の物理行へ続ける。見つかれば (物理行 index, 位置)、
        論理行の中に無ければ None。
        """
        depth = 1
        k = i + 1
        while index < len(self.lines):
            line = self.lines[index]
            n = len(line)
            while k < n:
                ch = line[k]
                if ch == "\\":
                    if k + 1 == n:
                        break  # 行継続。次の物理行へ
                    k += 2
                    continue
                if ch == "'":
                    k = line.find("'", k + 1)
                    if k < 0:
                        return None
                    k += 1
                    continue
                if ch == '"':
                    k = self._skip_dquote(line, k + 1)
                    if k < 0:
                        return None
                    continue
                if ch == "[":
                    depth += 1
                elif ch == "]":
                    depth -= 1
                    if depth == 0:
                        return index, k
                k += 1
            if k >= n:
                return None  # 行継続なしで物理行が終わった＝論理行の終わり
            index += 1
            k = 0
        return None

    @staticmethod
    def _skip_dquote(line, k):
        """位置 k から二重引用の閉じ `"` を探し、その次の位置を返す（無ければ -1）。"""
        n = len(line)
        while k < n:
            if line[k] == "\\" and k + 1 < n:
                k += 2
                continue
            if line[k] == '"':
                return k + 1
            k += 1
        return -1

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
    lines = text.splitlines()
    scanner = _Scanner(lines)
    for index, raw in enumerate(lines):
        lineno = index + 1
        mask = scanner.scan(index)
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
