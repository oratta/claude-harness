#!/usr/bin/env bash
# PreToolUse hook（matcher: Bash）: 破壊的 git 操作を実行の直前に止め、主に確認を回す。
#
# 規範の正本は rules/destructive-git-guard.md（破壊的操作は例外なく事前承認）。このルールは常時注入の
# 文章だけで止める仕組みが無かったので、ルールを読み飛ばした Claude が一覧の操作をそのまま打ったときに
# ここで止める。セキュリティ境界ではない。変数で組み立てたコマンド・git の alias・スクリプトファイル
# 経由の git などは通る（通すことを許す入力の正本は spec destructive-git-hook の「守備範囲:」）。
#
# 判定はこのスクリプトに一本化し、hooks.json の `if` では絞らない。`if` は Claude Code の中で評価されるので
# bats から検査できず、一覧が 2 か所に分かれ、`git -C x reset --hard` のように大域オプションが前に来る形を
# 前方一致で拾えないため。
#
# コマンド文字列は引用状態を保ったまま 1 回で読む（spec の要件「コマンド文字列をシェルと同じ単位で読む」）。
# 扱う構文: 演算子と改行での区切り・行継続・コメント・リダイレクト・ヒアドキュメント・here-string・
# $(...) とバッククォート。扱わない構文: 算術式 $((...)) の中身・${...} の中の置換・プロセス置換の中身・
# case の ) ・予約語や記号が先頭に来る形（do / then / { / !）。扱わない形は通ることがある。
#
# 対象（spec の 9 種）: git checkout -- <path> / git checkout . ・git restore（--staged だけのものを除く）・
#   git reset --hard ・git clean -f（dry-run を除く）・main / master への git push（dry-run を除く）・
#   git push --force 系（dry-run を除く）・git branch -D ・--no-verify / git commit -n ・--no-gpg-sign
#   dry-run は、後ろの --no-dry-run で打ち消されていないものだけを指す。
#
# 返す値: permission_mode が default / acceptEdits / plan / bypassPermissions なら ask（対話セッションでは
#   確認画面が出て主が承認できる。claude -p では確認できず実行されない。どちらも実機で確認済み）、それ以外
#   （dontAsk・auto・未知・欠落）は deny。DEV_WORKFLOW_GIT_GUARD_FORCE=ask|deny は
#   実機確認と bats のための上書き（恒久設定にしない）。
# DEV_WORKFLOW_GIT_GUARD=off で全許可（セッションの起動時の環境に入れる。コマンドの前置きでは効かない）。
#
# fail-open: python3 が無い・payload が読めない・Bash 以外・command が文字列でないときは何も出さず exit 0。
set -uo pipefail

[ "${DEV_WORKFLOW_GIT_GUARD:-on}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Bash 呼び出しの大多数は git を含まないので、python3 の起動コストを課さない。payload 全体の文字列で
# 必要条件だけを見る（context-tripwire.sh と同じ形）。git を生の文字以外で書く手段は \uXXXX だけで、
# g / i / t は U+0067〜U+0074 なので上位 2 桁は必ず 00。誤りは余計に python3 を起動する向きにしか起きない。
payload="$(cat)" || exit 0
case "$payload" in
  *git*) ;;
  *'\u00'*) ;;
  *) exit 0 ;;
esac

# Python 本体はヒアドキュメントで変数に読み、-c の引数で渡す。payload は stdin のまま読ませる
# （payload を環境変数や引数に載せると、長い入力で ARG_MAX を超えて hook が落ちる。本体は固定長で数十 KB）。
# 本体を fd 3 のヒアドキュメントに付けて /dev/fd/3 として python3 に読ませる形は使わない: Python 3.9（macOS 標準の
# /usr/bin/python3 など）は複数行の本体を実行せず rc=0・無出力で終わり、hook が何もしないまま通す（#869）。
# -I（隔離モード）で起動し、PYTHON* の環境変数・ユーザー site・カレントディレクトリを検索パスに使わない。
PY_SRC=""
IFS= read -r -d '' PY_SRC <<'PY' || true
import json, os, re, sys

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
    sys.exit(0)
inp = payload.get("tool_input")
if not isinstance(inp, dict) or not isinstance(inp.get("command"), str):
    sys.exit(0)
command = inp["command"]

LABELS = {
    "checkout": "`git checkout -- <path>` / `git checkout .`（作業の破棄）",
    "restore": "`git restore <path>`（作業の破棄）",
    "reset": "`git reset --hard`",
    "clean": "`git clean -f`",
    "push-main": "main / master への `git push`",
    "push-force": "`git push --force`（force push）",
    "branch": "`git branch -D`",
    "no-verify": "`--no-verify`（hook の迂回）",
    "no-gpg": "`--no-gpg-sign`",
}
ORDER = list(LABELS)

ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
SHORT = re.compile(r"^-[A-Za-z]+$")
WRAPPERS = {"command", "env", "sudo", "nohup", "time", "exec", "builtin"}
# env の値を取るオプション（GNU と BSD の和集合）。-S / --split-string は入れない: 後ろの字句が
# コマンドとして実行されるので、値として読み飛ばすと `env -S git reset --hard` が素通りになる。
ENV_SHORT_ARG = set("uCPa")
ENV_LONG_ARG = {"--unset", "--chdir", "--argv0"}
SHELLS = {"bash", "sh", "zsh"}
GIT_OPTS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                     "--super-prefix", "--config-env", "--exec-path"}
MAIN_REFS = {"main", "master", "refs/heads/main", "refs/heads/master"}


class Unclosed(Exception):
    """引用符が閉じていない。呼び出し側は空白で割った字句に同じ判定をかける。"""


class TooMuch(Exception):
    """判定の仕事量が上限を超えた。判定を打ち切り、止める側（ask / deny）に倒す。"""


# 読み済みの置換の控え。字句読みは $(...) を中の単純コマンドまで読んだうえで、その文字列を語にそのまま
# 写す。bash -c / eval の引数になった語を judge が読み直すとき、写した範囲の中の単純コマンドは外側の読みが
# もう判定に回しているので、読み直さずに終わりの位置まで飛ばす（bash -c "$(bash -c "$(...)")" を重ねた形で、
# 重ねた数だけ内側を読み直すと、1000 重で 30 秒を超えて hook の時間切れ＝素通しになる）。
# 飛ばしてよい根拠: (1) $( の中の読みは $( の位置から先の文字だけで決まる。語には同じ文字がそのまま
# 写っているので、読み直しが同じ位置を $( として読むなら、結果は外側の読みと同じになる。ただし
# ヒアドキュメントを含む置換は、本文の終わりを行の単位で探して置換の外の文字まで見るので、控えに入れない。
# (2) 外側の読みは、読み直しより浅い深さ（judge の depth）で同じ単純コマンドを判定している。判定は深さが
# 浅いほど多くを拾い、結果は和集合でしか上に渡らないので、読み直しで拾えるものは外側がすべて拾っている。
# 外側の読みが引用符の不一致で捨てられるときは、その中で呼ばれた読み直しの結果も一緒に捨てられる。
class Word(str):
    """読み済みの置換の範囲（始まりの位置 → 終わりの位置）を持つ語。閉じずに終わった置換は語の末尾まで。"""
    spans = None


def join_words(words):
    """語を空白でつなぐ（eval の引数）。読み済みの置換の範囲を、つないだ後の位置に直して引き継ぐ。"""
    spans, pos = {}, 0
    for w in words:
        for a, b in (getattr(w, "spans", None) or {}).items():
            spans[pos + a] = pos + b
        pos += len(w) + 1
    out = " ".join(words)
    if spans:
        out = Word(out)
        out.spans = spans
    return out


# 判定の仕事量（字句読みにかけた文字数の合計）と上限。読み済みの置換を飛ばしても、ヒアドキュメントを含む
# 置換を bash -c / eval の引数に何重にも重ねた形などは読み直しが残る。hook の時間切れは何も止めないのと
# 同じ結果になるので、上限を超えたら判定を打ち切って止める側に倒す（TooMuch）。素通しの側には倒さない。
# 上限の根拠: 読み直しは bash -c / eval の引数とバッククォートの中身にしか起きず、judge の深さは 0〜8 の
# 9 段。読み直しが重ならないコマンドでは 1 段あたりの合計がコマンドの長さを超えないので、仕事量は長さの
# 9 倍（バッククォートを引数の中に書いた分を二重に数えても 18 倍）に収まる。ヒアドキュメントの本文の
# 終わりを探す分は、本文の $(...) の中に入れ子にしない限り、合計でコマンドの長さを超えない。上限は
# その上の 32 倍に置き、短いコマンドには 200 万文字の下限を置く（字句読みは 1 秒に約 300 万文字。
# 200 万文字は 1 秒弱）。
WORK = [0]
WORK_LIMIT = max(2000000, 32 * len(command))
HEREDOCS = [0]  # 読んだヒアドキュメントの数（置換の中にヒアドキュメントがあったかを前後の差で見る）


def charge(count):
    if WORK[0] > WORK_LIMIT:
        raise TooMuch()
    WORK[0] += count


# 字句読み（spec destructive-git-hook「コマンド文字列をシェルと同じ単位で読む」）。
# 引用状態と「演算子か語か」を保ったまま 1 回で読み、単純コマンド（語の並び）の並び（$(...) の中の
# ものを含む）と、読み直して判定するバッククォートの中身の並びを返す。扱うのは演算子・行継続・
# コメント・リダイレクト・ヒアドキュメント（区切り語の全体、<<-、引用された区切り語）・here-string・
# 置換の中の引用。算術式・${...}・プロセス置換の中身・case の ) は扱わない（守備範囲の外）。
#
# 入れ子（$(...) の中、二重引用符の中の $(...)、ヒアドキュメントの本文の $(...)）を読む関数は
# ジェネレータで書き、内側の読みを `yield` で頼む。run がそれを明示的なスタックで順に進めるので、
# 入れ子の深さが Python の再帰の深さにならない（再帰で読むと数百〜数千重で再帰が尽き、上限を上げると
# 古い Python が異常終了して無出力＝素通しになる）。字句読みは run(lex(...)) で呼ぶ。
#
# 読み終えた単純コマンドは cmds.append で渡す。judge はここに Judged を渡して、渡されたその場で判定し、
# 単純コマンドをためない（$(...) を含む語は中身の文字列を丸ごと持つので、入れ子の全段の単純コマンドを
# 並びにためると、深さの 2 乗のメモリを使う。20000 重の二重引用符つきの入れ子で 2GB を超えた）。
def run(gen):
    """ジェネレータ gen を最後まで進めて戻り値を返す。gen が yield したジェネレータは、その戻り値を
    yield の値として返す。中で上がった例外は、呼び出した側のジェネレータへ順に伝える。"""
    stack, value, error = [gen], None, None
    while True:
        try:
            if error is not None:
                pending_error, error = error, None
                child = stack[-1].throw(pending_error)
            else:
                child = stack[-1].send(value)
        except StopIteration as stop:
            stack.pop()
            if not stack:
                return stop.value
            value = stop.value
            continue
        except Exception as e:
            stack.pop()
            if not stack:
                raise
            error = e
            continue
        stack.append(child)
        value = None


def backquote(s, i):
    """s[i] の ` から、エスケープされていない次の ` までを読む。(中身, 次の位置)。閉じていなければ末尾まで。"""
    out, j, n = [], i + 1, len(s)
    while j < n:
        if s[j] == "\\" and j + 1 < n:
            out.append(s[j + 1] if s[j + 1] in "`\\$" else s[j:j + 2])
            j += 2
            continue
        if s[j] == "`":
            return "".join(out), j + 1
        out.append(s[j])
        j += 1
    return "".join(out), n


def subst(s, i, subs, cmds, memo=None):
    """s[i:i+2] の $( を、対応する ) まで読む（中の引用・入れ子・コメント・ヒアドキュメントを追う）。
    中で読んだ単純コマンドを cmds に、バッククォートの中身を subs に足し、次の位置を返す。閉じていなければ
    末尾まで。中身を文字列で返して読み直させないのは、入れ子の深さが judge の再帰の上限に数えられて、
    深い入れ子の中の git を見失うため。返すのは (次の位置, 読み済みの置換の控えに入れてよいか)。
    s が読み済みの置換の範囲を持ち、i がその始まりなら、読まずに終わりの位置を返す。
    ジェネレータ（run で進める）。"""
    known = getattr(s, "spans", None)
    if known and i in known:
        WORK[0] -= known[i] - i  # 読まなかった分は仕事量に数えない
        return known[i], True
    before = HEREDOCS[0]
    _, _, end, _ = yield lex(s, i + 2, True, cmds, subs, memo)
    return end, HEREDOCS[0] == before


def double_quoted(s, i, subs, cmds, term='"', memo=None):
    """二重引用符の中（term=None ならヒアドキュメントの引用されていない本文）を読む。
    (文字列, 次の位置, 文字列の中の読み済みの置換の範囲の並び)。ジェネレータ（run で進める）。"""
    out, n, pos, spans = [], len(s), 0, []
    while i < n:
        ch = s[i]
        if term is not None and ch == term:
            return "".join(out), i + 1, spans
        if ch == "\\" and i + 1 < n:
            nxt = s[i + 1]
            if nxt == "\n":  # 行継続
                i += 2
                continue
            if nxt in '$`"\\':
                out.append(nxt)
                pos += 1
                i += 2
                continue
        if ch == "$" and s.startswith("$(", i):
            end, plain = yield subst(s, i, subs, cmds, memo)
            if plain:
                spans.append((pos, pos + end - i))
            out.append(s[i:end])
            pos += end - i
            i = end
            continue
        if ch == "`":
            inner, end = backquote(s, i)
            subs.append(inner)
            out.append(s[i:end])
            pos += end - i
            i = end
            continue
        out.append(ch)
        pos += 1
        i += 1
    if term is not None:
        raise Unclosed()
    return "".join(out), n, spans


def read_heredocs(s, i, pending, subs, cmds, in_subst):
    """改行の次の位置 i から、読み残しのヒアドキュメントの本文を読み飛ばす。本文の後ろの位置を返す。
    ジェネレータ（run で進める）。"""
    n = len(s)
    for delim, strip_tabs, quoted in pending:
        start, body_end = i, n
        while i < n:
            j = s.find("\n", i)
            line = s[i:] if j < 0 else s[i:j]
            nxt = n if j < 0 else j + 1
            cmp = line.lstrip("\t") if strip_tabs else line
            if cmp == delim:
                body_end, i = i, nxt
                break
            # $(cat <<'EOF' ... EOF) のように、置換の中で区切り語の直後に ) が来る形
            if in_subst and cmp.startswith(delim) and cmp[len(delim):].lstrip().startswith(")"):
                body_end, i = i, i + (len(line) - len(cmp)) + len(delim)
                break
            i = nxt
        else:
            i = n
        # 本文の終わりを探した分も仕事量に数える（本文の $(...) の中にヒアドキュメントを何重にも入れると、
        # 内側の本文を重ねた数だけ探し直す）
        charge(i - start)
        if not quoted:
            yield double_quoted(s[start:body_end], 0, subs, cmds, term=None)
    pending.clear()
    return i


def lex(s, i=0, in_subst=False, cmds=None, subs=None, memo=None):
    """(単純コマンドの並び, バッククォートの中身の並び, 終わりの位置, 閉じたか)。
    $(...) の中の単純コマンドは、同じ並びに足して返す（バッククォートの中身だけ、呼び出し側が読み直す）。
    cmds / subs を渡すと、その並びに足す（入れ子の読みは外側の並びをそのまま使う。cmds は append を持つ
    ものなら並びでなくてよい）。
    in_subst は $( の中で、対応する ) で止まる（閉じたかは in_subst のときだけ意味を持つ）。
    memo（辞書）を渡すと、閉じずに終わった $( の読みを「始まりの位置 → 末尾まで読めたか」で記録する
    （引用符が閉じていなくて読めなかったものは False）。split_fallback が同じ位置を読み直さないために使う。
    ジェネレータなので run(lex(...)) で呼ぶ。"""
    start = i
    try:
        result = yield lex_body(s, i, in_subst, [] if cmds is None else cmds,
                                [] if subs is None else subs, memo)
    except Unclosed:
        if memo is not None:
            memo[start] = False
        raise
    if memo is not None and not result[3]:
        memo[start] = True
    return result


def lex_body(s, i, in_subst, cmds, subs, memo):
    cur, pending = [], []
    word, st = [], {"has": False, "quoted": False, "redirect": False, "delim": None, "len": 0}
    spans = []  # 読んでいる語の中の、読み済みの置換の範囲
    paren, n = 0, len(s)

    def end_word():
        if not st["has"]:
            return
        w = "".join(word)
        word.clear()
        if spans:
            w = Word(w)
            w.spans = dict(spans)
            spans.clear()
        st["len"] = 0
        if st["delim"] is not None:
            pending.append((w, st["delim"], st["quoted"]))
            st["delim"] = None
        elif st["redirect"]:
            st["redirect"] = False  # リダイレクトの対象は引数にしない
        else:
            cur.append(w)
        st["has"] = st["quoted"] = False

    def end_cmd():
        end_word()
        if cur:
            cmds.append(list(cur))
        cur.clear()
        st["redirect"] = False

    def add(text, quoted=False):
        word.append(text)
        st["len"] += len(text)
        st["has"] = True
        st["quoted"] = st["quoted"] or quoted

    while i < n:
        ch = s[i]
        if ch == "\\":
            if i + 1 < n and s[i + 1] == "\n":  # 行継続
                i += 2
                continue
            add(s[i + 1] if i + 1 < n else "\\", quoted=True)
            i += 2
            continue
        if ch == "'" or (ch == "$" and s.startswith("$'", i)):
            j = i + 1 if ch == "'" else i + 2
            k = s.find("'", j)
            if k < 0:
                raise Unclosed()
            add(s[j:k], quoted=True)
            i = k + 1
            continue
        if ch == '"':
            text, i, inner = yield double_quoted(s, i + 1, subs, cmds, memo=memo)
            spans.extend((st["len"] + a, st["len"] + b) for a, b in inner)
            add(text, quoted=True)
            continue
        if ch == "$" and s.startswith("$(", i):
            end, plain = yield subst(s, i, subs, cmds, memo)
            if plain:
                spans.append((st["len"], st["len"] + end - i))
            add(s[i:end])
            i = end
            continue
        if ch == "`":
            inner, end = backquote(s, i)
            subs.append(inner)
            add(s[i:end])
            i = end
            continue
        if ch == "#" and not st["has"]:  # コメント（改行は残す）
            j = s.find("\n", i)
            i = n if j < 0 else j
            continue
        if ch in " \t":
            end_word()
            i += 1
            continue
        if ch == "\n":
            end_cmd()
            i = (yield read_heredocs(s, i + 1, pending, subs, cmds, in_subst)) if pending else i + 1
            continue
        if ch in "<>" or (ch == "&" and s.startswith("&>", i)):
            # 直前に接した数字だけの語は fd（2>、2>&1）
            if st["has"] and not st["quoted"] and "".join(word).isdigit():
                word.clear()
                st["has"], st["len"] = False, 0
            else:
                end_word()
            if s.startswith("<<<", i):
                st["redirect"], i = True, i + 3
            elif s.startswith("<<", i):
                strip = s.startswith("<<-", i)
                HEREDOCS[0] += 1
                st["delim"], i = strip, i + (3 if strip else 2)
            else:
                m = re.match(r"&>>|&>|>>|>\||>&|<&|<>|<|>", s[i:])
                st["redirect"], i = True, i + len(m.group(0))
            continue
        if ch in ";&|":
            end_cmd()
            i += 2 if s[i:i + 2] in ("&&", "||", ";;", "|&") else 1
            continue
        if ch == "(":
            end_cmd()
            paren += 1
            i += 1
            continue
        if ch == ")":
            end_cmd()
            i += 1
            if in_subst and paren == 0:
                return cmds, subs, i, True
            paren = max(0, paren - 1)
            continue
        add(ch)
        i += 1
    end_cmd()
    return cmds, subs, n, False


def split_fallback(s, depth):
    """字句読みで読めないとき（引用符が閉じていない）: (当たった種類の集合, 置換の中身の並び)。
    空白で割った字句を、演算子だけの字句と引用符の外の改行で単純コマンドに分ける。引用符は開閉を数えるだけで、
    閉じていない引用符の中の改行より後ろは読まない。置換は単一引用符の外のものを読む。閉じた $(...) は
    字句読みで読み、閉じていない $( はその位置で単純コマンドを区切る。閉じていない $( でも、中の引用符が
    閉じていて末尾まで字句読みで読めたら、読めた単純コマンドも判定に足す（bash -c / eval に渡した
    引用つきの引数を、空白で割って失わないため）。一度読んで閉じなかった $( の入れ子は読み直さない
    （seen。読み直すと、入れ子の数の 2 乗の時間がかかる）。"""
    s = str(s)  # 読み済みの置換の控えは使わない（粗い読みは、置換を自分で読んだ結果だけを使う）
    out, subs, kinds, quote, i, n = [], [], set(), None, 0, len(s)
    seen = set()
    while i < n:
        ch = s[i]
        if quote == "'":
            if ch == "'":
                quote = None
        elif ch == "\\" and i + 1 < n:
            out.append(s[i:i + 2])
            i += 2
            continue
        elif ch == "$" and s.startswith("$(", i):
            if i + 2 not in seen:
                memo, inner = {}, Judged(depth)
                try:
                    _, inner_subs, end, closed = run(lex(s, i + 2, True, inner, memo=memo))
                except Unclosed:
                    charge(n - i)
                    seen.update(p for p, read in memo.items() if not read)
                else:
                    charge(end - i)
                    kinds |= inner.kinds
                    subs.extend(inner_subs)
                    if closed:
                        out.append(s[i:end])
                        i = end
                        continue
                    seen.update(memo)
            out.append(" ; ")
            i += 2
            continue
        elif ch == "`":
            inner, end = backquote(s, i)
            subs.append(inner)
            out.append(s[i:end])
            i = end
            continue
        elif ch in "'\"" and quote is None:
            quote = ch
        elif ch == '"' and quote == '"':
            quote = None
        elif ch == "\n" and quote is None:
            ch = " ; "
        out.append(ch)
        i += 1
    cur = []
    for t in re.split(r"\s+", "".join(out)):
        if not t:
            continue
        if set(t) <= set("();|&"):
            if cur:
                kinds |= judge_simple(cur, depth)
            cur = []
            continue
        cur.append(t)
    if cur:
        kinds |= judge_simple(cur, depth)
    return kinds, subs


def shorts(args):
    return [a for a in args if SHORT.match(a)]


def has_short(args, letter):
    return any(letter in a[1:] for a in shorts(args))


class Judged:
    """字句読みが読み終えた単純コマンドを、ためずにその場で判定して、当たった種類だけを持つ。"""

    def __init__(self, depth):
        self.kinds, self.depth = set(), depth

    def append(self, cmd):
        self.kinds |= judge_simple(cmd, self.depth)


# judge の結果の控え（(深さ, 文字列) → 当たった種類の集合）。字句読みは bash -c / eval の引数の中の
# $(...) も同じ深さで読むので、bash -c "$(bash -c "$(...)")" のように重ねると、内側の引数ほど何度も
# 判定に回る（控えが無いと、重ねた数の 8 乗に比例する回数になり、24 重で 20 秒かかった）。
JUDGE_MEMO = {}


def judge(s, depth=0):
    if depth > 8:
        return set()
    spans = getattr(s, "spans", None) or {}
    if spans.get(0) == len(s):
        # 全体が読み済みの置換 1 つ（bash -c "$(...)" の引数）。中の単純コマンドは外側の読みが判定済みで、
        # 語そのものは $( で始まるので git でも bash -c でも eval でもない。
        return set()
    # 控えの鍵に範囲を入れる（同じ文字列でも、範囲が付いていない呼び出しは置換の中を自分で読む）
    key = (depth, s, tuple(sorted(spans.items())))
    if key not in JUDGE_MEMO:
        JUDGE_MEMO[key] = judge_uncached(s, depth)
    return JUDGE_MEMO[key]


def judge_uncached(s, depth):
    charge(len(s))
    read = Judged(depth)
    try:
        _, subs, _, _ = run(lex(s, cmds=read))
        kinds = read.kinds
    except Unclosed:  # 途中まで読めた分の判定は使わず、粗い読みの結果だけを使う
        kinds, subs = split_fallback(s, depth)
    for inner in subs:
        kinds |= judge(inner, depth + 1)
    return kinds


def env_opt_takes_next(opt):
    """env のオプションの字句が、次の字句を値として取るか。`--unset=FOO` と `-uFOO` は 1 字句で完結する。"""
    if opt.startswith("--"):
        return opt in ENV_LONG_ARG
    body = opt[1:]
    for j, ch in enumerate(body):
        if ch in ENV_SHORT_ARG:
            return j == len(body) - 1  # 途中なら同じ字句の残りが値
    return False


def judge_simple(cmd, depth):
    i = 0
    while i < len(cmd):
        t = cmd[i]
        if ASSIGN.match(t):
            i += 1
            continue
        if t in WRAPPERS:
            i += 1
            while i < len(cmd) and cmd[i].startswith("-"):
                if t == "env" and env_opt_takes_next(cmd[i]):
                    i += 1  # 次の字句はこのオプションの値で、コマンド名ではない
                i += 1
            continue
        break
    if i >= len(cmd):
        return set()
    head, rest = cmd[i], cmd[i + 1:]
    base = os.path.basename(head)
    if base in SHELLS:
        for k, a in enumerate(rest):
            if a.startswith("-") and not a.startswith("--") and "c" in a[1:]:
                if k + 1 < len(rest):
                    return judge(rest[k + 1], depth + 1)
        return set()
    if head == "eval":
        return judge(join_words(rest), depth + 1)
    if base == "git":
        return judge_git(rest)
    return set()


# 引数を取るオプション（サブコマンドごと）。ここに無いオプションは値を取らないものとして読む。
# 値を取るオプションの次の字句（短いオプションは同じ字句の残り）はその値として読み飛ばし、判定に使わない。
ARG_OPTS = {
    "commit": (set("mFcCt"),
               {"--message", "--file", "--reuse-message", "--reedit-message", "--template",
                "--author", "--date", "--fixup", "--squash", "--cleanup", "--trailer"}),
    "push": (set("o"), {"--push-option", "--repo", "--receive-pack", "--exec"}),
    "clean": (set("e"), {"--exclude"}),
}
# 短い -n が --dry-run を意味するサブコマンド。--no-dry-run はここに限って -n も打ち消す
# （commit の -n は --no-verify なので打ち消さない）。
DRY_RUN_SHORT_N = {"push", "clean"}


def parse_opts(sub, rest):
    """サブコマンドの引数を構文解析し、(長いオプション名の集合, 短いオプションの文字の集合, 位置引数) を返す。
    オプションの値と `--` / `--end-of-options` より後ろの字句は位置引数としてだけ扱い、オプションとして判定しない。
    dry-run は左から読んだ最後の状態で残す: `--no-dry-run`（とその省略形）は、それまでの `--dry-run` と
    push / clean の `-n` を集合から外す。"""
    short_arg, long_arg = ARG_OPTS.get(sub, (set(), set()))
    longs, short_set, positional = set(), set(), []
    k = 0
    while k < len(rest):
        a = rest[k]
        k += 1
        if a in ("--", "--end-of-options"):
            positional.extend(rest[k:])
            break
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            if "=" not in a and name not in long_arg:
                # git は一意な省略形を受け付ける（--push-opt は --push-option）。一覧の中で一意なら同じに読む
                full = [o for o in long_arg if o.startswith(name)]
                if len(full) == 1:
                    name = full[0]
            longs.add(name)
            if len(name) >= len("--no-d") and "--no-dry-run".startswith(name):
                longs.discard("--dry-run")
                if sub in DRY_RUN_SHORT_N:
                    short_set.discard("n")
            if name in long_arg and "=" not in a:
                k += 1  # 次の字句がこのオプションの値
            continue
        if a.startswith("-") and len(a) > 1:
            body = a[1:]
            for j, ch in enumerate(body):
                short_set.add(ch)
                if ch in short_arg:
                    if j == len(body) - 1:
                        k += 1  # 次の字句がこのオプションの値
                    break  # 同じ字句の残りはこのオプションの値
            continue
        positional.append(a)
    return longs, short_set, positional


def judge_git(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_OPTS_WITH_ARG else 1
    if i >= len(args):
        return set()
    sub, rest = args[i], args[i + 1:]
    longs, short_set, positional = parse_opts(sub, rest)
    kinds = set()
    if "--no-verify" in longs:
        kinds.add("no-verify")
    if "--no-gpg-sign" in longs:
        kinds.add("no-gpg")

    if sub == "checkout":
        if "--" in rest and rest.index("--") < len(rest) - 1:
            kinds.add("checkout")
        elif rest == ["."]:
            kinds.add("checkout")
    elif sub == "restore":
        staged = "--staged" in rest or has_short(rest, "S")
        worktree = "--worktree" in rest or has_short(rest, "W")
        if not (staged and not worktree):
            kinds.add("restore")
    elif sub == "reset":
        if "--hard" in rest:
            kinds.add("reset")
    elif sub == "clean":
        force = "--force" in longs or "f" in short_set
        dry = "--dry-run" in longs or "n" in short_set
        if force and not dry:
            kinds.add("clean")
    elif sub == "push":
        kinds |= judge_push(longs, short_set, positional)
    elif sub == "branch":
        delete = "--delete" in rest or has_short(rest, "d")
        force = "--force" in rest or has_short(rest, "f")
        if has_short(rest, "D") or (delete and force):
            kinds.add("branch")
    elif sub == "commit":
        if "n" in short_set:
            kinds.add("no-verify")
    return kinds


def judge_push(longs, short_set, positional):
    if "--dry-run" in longs or "n" in short_set:
        return set()
    kinds = set()
    if "--force" in longs or "--force-with-lease" in longs or "f" in short_set:
        kinds.add("push-force")
    for ref in positional[1:]:
        if ref.startswith("+"):
            kinds.add("push-force")
            ref = ref[1:]
        dst = ref.rsplit(":", 1)[-1] if ":" in ref else ref
        if dst in MAIN_REFS:
            kinds.add("push-main")
    return kinds


try:
    kinds = judge(command)
except TooMuch:
    kinds = None  # 判定しきれなかった。破壊的操作を含むものとして止める
if kinds is not None and not kinds:
    sys.exit(0)

forced = (os.environ.get("DEV_WORKFLOW_GIT_GUARD_FORCE") or "").strip()
if forced in ("ask", "deny"):
    decision = forced
else:
    decision = "ask" if payload.get("permission_mode") in ("default", "acceptEdits", "plan", "bypassPermissions") else "deny"

if kinds is None:
    head = ("[dev-workflow git-destructive-guard] git を含むコマンドの入れ子（bash -c / eval / $(...) の重なり）が"
            "深すぎて、破壊的 git 操作を含むかどうかを判定しきれなかった。含むものとして扱う。"
            "規範の正本は rules/destructive-git-guard.md（破壊的操作は例外なく事前承認）。")
else:
    found = "、".join(LABELS[k] for k in ORDER if k in kinds)
    head = ("[dev-workflow git-destructive-guard] 破壊的 git 操作を検出した: " + found + "。"
            "規範の正本は rules/destructive-git-guard.md（破壊的操作は例外なく事前承認）。")
if decision == "deny":
    body = ("このコマンドは実行していない。何を・なぜ・いつ実行するかを示して主に承認を求め、承認されたら"
            "主が自分で実行する（Claude Code の入力欄で ! を付けて打つか、自分の端末で）。")
else:
    body = ("主の確認画面を出している。承認されなければ実行せず、何を・なぜ実行するかを示して主に承認を求めること。"
            "確認画面が出ないセッション（claude -p など）ではこのコマンドは実行されないので、主に承認を求め、"
            "承認されたら主が自分で実行する（Claude Code の入力欄で ! を付けて打つか、自分の端末で）。")
tail = "言い換えたコマンドや別の書き方で再実行して、この確認を避けてはならない。"
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                          "permissionDecision": decision,
                                          "permissionDecisionReason": head + body + tail}},
                 ensure_ascii=False))
PY
if [ -z "$PY_SRC" ]; then
  # 本体を読めなかった（ヒアドキュメントの一時ファイルを作れない等）。空の本体を python3 に渡すと
  # rc=0・無出力で終わって黙って通すので、渡さずに stderr で知らせる。
  echo "git-destructive-guard: 判定の本体を読めなかったため、判定していない" >&2
  exit 1
fi
printf '%s' "$payload" | python3 -I -c "$PY_SRC"
exit 0
