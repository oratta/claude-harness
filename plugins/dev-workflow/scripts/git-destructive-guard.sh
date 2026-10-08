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
# 対象（spec の 9 種）: git checkout -- <path> / git checkout . ・git restore（--staged だけのものを除く）・
#   git reset --hard ・git clean -f（dry-run を除く）・main / master への git push（dry-run を除く）・
#   git push --force 系（dry-run を除く）・git branch -D ・--no-verify / git commit -n ・--no-gpg-sign
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

printf '%s' "$payload" | python3 /dev/fd/3 3<<'PY'
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
SHELLS = {"bash", "sh", "zsh"}
GIT_OPTS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                     "--super-prefix", "--config-env", "--exec-path"}
MAIN_REFS = {"main", "master", "refs/heads/main", "refs/heads/master"}


class Unclosed(Exception):
    """引用符が閉じていない。呼び出し側は空白で割った字句に同じ判定をかける。"""


# 字句読み（spec destructive-git-hook「コマンド文字列をシェルと同じ単位で読む」）。
# 引用状態と「演算子か語か」を保ったまま 1 回で読み、単純コマンド（語の並び）の並びと、
# 中を判定すべき置換（$(...) とバッククォート）の中身の並びを返す。扱うのは演算子・行継続・
# コメント・リダイレクト・ヒアドキュメント（区切り語の全体、<<-、引用された区切り語）・here-string・
# 置換の中の引用。算術式・${...}・プロセス置換の中身・case の ) は扱わない（守備範囲の外）。
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


def subst(s, i, subs):
    """s[i:i+2] の $( を、対応する ) まで読む（中の引用・入れ子・コメント・ヒアドキュメントを追う）。
    中身を subs に足し、次の位置を返す。閉じていなければ末尾まで。"""
    _, _, end, closed = lex(s, i + 2, in_subst=True)
    subs.append(s[i + 2:end - 1] if closed else s[i + 2:end])
    return end


def double_quoted(s, i, subs, term='"'):
    """二重引用符の中（term=None ならヒアドキュメントの引用されていない本文）を読む。(文字列, 次の位置)。"""
    out, n = [], len(s)
    while i < n:
        ch = s[i]
        if term is not None and ch == term:
            return "".join(out), i + 1
        if ch == "\\" and i + 1 < n:
            nxt = s[i + 1]
            if nxt == "\n":  # 行継続
                i += 2
                continue
            if nxt in '$`"\\':
                out.append(nxt)
                i += 2
                continue
        if ch == "$" and s.startswith("$(", i):
            end = subst(s, i, subs)
            out.append(s[i:end])
            i = end
            continue
        if ch == "`":
            inner, end = backquote(s, i)
            subs.append(inner)
            out.append(s[i:end])
            i = end
            continue
        out.append(ch)
        i += 1
    if term is not None:
        raise Unclosed()
    return "".join(out), n


def read_heredocs(s, i, pending, subs, in_subst):
    """改行の次の位置 i から、読み残しのヒアドキュメントの本文を読み飛ばす。本文の後ろの位置を返す。"""
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
        if not quoted:
            double_quoted(s[start:body_end], 0, subs, term=None)
    pending.clear()
    return i


def lex(s, i=0, in_subst=False):
    """(単純コマンドの並び, 置換の中身の並び, 終わりの位置, 閉じたか)。
    in_subst は $( の中で、対応する ) で止まる（閉じたかは in_subst のときだけ意味を持つ）。"""
    cmds, cur, subs, pending = [], [], [], []
    word, st = [], {"has": False, "quoted": False, "redirect": False, "delim": None}
    paren, n = 0, len(s)

    def end_word():
        if not st["has"]:
            return
        w = "".join(word)
        word.clear()
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
            text, i = double_quoted(s, i + 1, subs)
            add(text, quoted=True)
            continue
        if ch == "$" and s.startswith("$(", i):
            end = subst(s, i, subs)
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
            i = read_heredocs(s, i + 1, pending, subs, in_subst) if pending else i + 1
            continue
        if ch in "<>" or (ch == "&" and s.startswith("&>", i)):
            # 直前に接した数字だけの語は fd（2>、2>&1）
            if st["has"] and not st["quoted"] and "".join(word).isdigit():
                word.clear()
                st["has"] = False
            else:
                end_word()
            if s.startswith("<<<", i):
                st["redirect"], i = True, i + 3
            elif s.startswith("<<", i):
                strip = s.startswith("<<-", i)
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


def split_fallback(s):
    """引用符が閉じていないとき: 空白と改行で割った字句を、演算子だけの字句で単純コマンドに分ける。"""
    cmds, cur = [], []
    for t in re.split(r"\s+", s):
        if not t:
            continue
        if set(t) <= set("();|&"):
            if cur:
                cmds.append(cur)
            cur = []
            continue
        cur.append(t)
    if cur:
        cmds.append(cur)
    return cmds


def shorts(args):
    return [a for a in args if SHORT.match(a)]


def has_short(args, letter):
    return any(letter in a[1:] for a in shorts(args))


def judge(s, depth=0):
    kinds = set()
    if depth > 8:
        return kinds
    try:
        cmds, subs, _, _ = lex(s)
    except Unclosed:
        cmds, subs = split_fallback(s), []
    for inner in subs:
        kinds |= judge(inner, depth + 1)
    for cmd in cmds:
        kinds |= judge_simple(cmd, depth)
    return kinds


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
        return judge(" ".join(rest), depth + 1)
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


def parse_opts(sub, rest):
    """サブコマンドの引数を構文解析し、(長いオプション名の集合, 短いオプションの文字の集合, 位置引数) を返す。
    オプションの値と `--` より後ろの字句は位置引数としてだけ扱い、オプションとして判定しない。"""
    short_arg, long_arg = ARG_OPTS.get(sub, (set(), set()))
    longs, short_set, positional = set(), set(), []
    k = 0
    while k < len(rest):
        a = rest[k]
        k += 1
        if a == "--":
            positional.extend(rest[k:])
            break
        if a.startswith("--"):
            name = a.split("=", 1)[0]
            longs.add(name)
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


kinds = judge(command)
if not kinds:
    sys.exit(0)

forced = (os.environ.get("DEV_WORKFLOW_GIT_GUARD_FORCE") or "").strip()
if forced in ("ask", "deny"):
    decision = forced
else:
    decision = "ask" if payload.get("permission_mode") in ("default", "acceptEdits", "plan", "bypassPermissions") else "deny"

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
exit 0
