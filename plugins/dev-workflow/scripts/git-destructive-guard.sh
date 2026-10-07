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
# 返す値: permission_mode が default / acceptEdits / plan なら ask（確認画面が出る）、それ以外
#   （bypassPermissions・dontAsk・auto・未知・欠落）は deny。DEV_WORKFLOW_GIT_GUARD_FORCE=ask|deny は
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
import json, os, re, shlex, sys

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
OP_CHARS = set("();<>|&")
WRAPPERS = {"command", "env", "sudo", "nohup", "time", "exec", "builtin"}
SHELLS = {"bash", "sh", "zsh"}
GIT_OPTS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                     "--super-prefix", "--config-env", "--exec-path"}
MAIN_REFS = {"main", "master", "refs/heads/main", "refs/heads/master"}
HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def substitutions(s):
    """$(...) とバッククォートの中身を取り出す（単一引用符の中は展開されないので見ない）。"""
    out, i, n, quote = [], 0, len(s), None
    while i < n:
        ch = s[i]
        if quote == "'":
            if ch == "'":
                quote = None
            i += 1
            continue
        if ch == "\\":
            i += 2
            continue
        if ch == "'" and quote is None:
            quote = "'"
            i += 1
            continue
        if ch == '"':
            quote = None if quote == '"' else '"'
            i += 1
            continue
        if ch == "$" and i + 1 < n and s[i + 1] == "(":
            depth, j = 1, i + 2
            while j < n and depth:
                if s[j] == "(":
                    depth += 1
                elif s[j] == ")":
                    depth -= 1
                j += 1
            out.append(s[i + 2:j - 1] if depth == 0 else s[i + 2:])
            i = j
            continue
        if ch == "`":
            j = s.find("`", i + 1)
            out.append(s[i + 1:] if j < 0 else s[i + 1:j])
            i = n if j < 0 else j + 1
            continue
        i += 1
    return out


def normalize(s):
    """引用符の外の改行を ; に置き換え、ヒアドキュメントの本文（commit メッセージ等）を取り除く。
    引用符の中の改行（複数行の -m "..."）はそのまま残すので、メッセージの行をコマンドと誤読しない。"""
    out, i, n, quote, pending = [], 0, len(s), None, []
    while i < n:
        ch = s[i]
        if quote == "'":
            out.append(ch)
            if ch == "'":
                quote = None
            i += 1
            continue
        if ch == "\\" and i + 1 < n:
            out.append(s[i:i + 2])
            i += 2
            continue
        if ch in "'\"" and quote is None:
            quote = ch
        elif ch == '"' and quote == '"':
            quote = None
        elif quote is None and s.startswith("<<", i):
            m = HEREDOC.match(s, i)
            if m:
                pending.append(m.group(2))
        if ch == "\n" and quote is None:
            out.append(" ; ")
            i += 1
            while pending:
                end = pending.pop(0)
                while i < n:
                    j = s.find("\n", i)
                    line = s[i:] if j < 0 else s[i:j]
                    i = n if j < 0 else j + 1
                    if line.strip() == end:
                        break
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def tokenize(s):
    try:
        lex = shlex.shlex(s, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        return list(lex), True
    except ValueError:
        # 引用符が閉じていない: 判定を諦めず、空白と改行で割った字句に同じ判定をかける
        return [t for t in re.split(r"\s+", s) if t], False


def simple_commands(tokens):
    cmds, cur, skip_next = [], [], False
    for t in tokens:
        if skip_next:
            skip_next = False
            continue
        if t and set(t) <= OP_CHARS:
            if set(t) & set("<>") and not (set(t) & set("|;")):
                skip_next = True  # リダイレクトの直後はファイル名
                if t.endswith("&"):
                    skip_next = True
            if cur:
                cmds.append(cur)
            cur = []
            continue
        if "\n" in t:
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
    for inner in substitutions(s):
        kinds |= judge(inner, depth + 1)
    toks, _ = tokenize(normalize(s))
    tokens = toks
    for cmd in simple_commands(tokens):
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


def judge_git(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_OPTS_WITH_ARG else 1
    if i >= len(args):
        return set()
    sub, rest = args[i], args[i + 1:]
    kinds = set()
    if "--no-verify" in rest:
        kinds.add("no-verify")
    if "--no-gpg-sign" in rest:
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
        force = "--force" in rest or has_short(rest, "f")
        dry = "--dry-run" in rest or has_short(rest, "n")
        if force and not dry:
            kinds.add("clean")
    elif sub == "push":
        kinds |= judge_push(rest)
    elif sub == "branch":
        delete = "--delete" in rest or has_short(rest, "d")
        force = "--force" in rest or has_short(rest, "f")
        if has_short(rest, "D") or (delete and force):
            kinds.add("branch")
    elif sub == "commit":
        if commit_short_n(rest):
            kinds.add("no-verify")
    return kinds


def judge_push(rest):
    dry = "--dry-run" in rest or has_short(rest, "n")
    if dry:
        return set()
    kinds = set()
    positional, k, after_dd = [], 0, False
    while k < len(rest):
        a = rest[k]
        if after_dd:
            positional.append(a)
        elif a == "--":
            after_dd = True
        elif a in ("--force",) or a.startswith("--force-with-lease"):
            kinds.add("push-force")
        elif a in ("-o", "--push-option", "--repo", "--receive-pack", "--exec"):
            k += 1
        elif SHORT.match(a):
            if "f" in a[1:]:
                kinds.add("push-force")
            if a[1:].endswith("o"):
                k += 1
        elif a.startswith("-"):
            pass
        else:
            positional.append(a)
        k += 1
    for ref in positional[1:]:
        if ref.startswith("+"):
            kinds.add("push-force")
            ref = ref[1:]
        dst = ref.rsplit(":", 1)[-1] if ":" in ref else ref
        if dst in MAIN_REFS:
            kinds.add("push-main")
    return kinds


COMMIT_ARG_SHORT = set("mFcCt")
COMMIT_ARG_LONG = {"--message", "--file", "--reuse-message", "--reedit-message", "--template",
                   "--author", "--date", "--fixup", "--squash", "--cleanup", "--trailer"}


def commit_short_n(rest):
    k = 0
    while k < len(rest):
        a = rest[k]
        if a == "--":
            return False
        if a in COMMIT_ARG_LONG:
            k += 2
            continue
        if SHORT.match(a):
            body = a[1:]
            for j, ch in enumerate(body):
                if ch in COMMIT_ARG_SHORT:
                    if j == len(body) - 1:
                        k += 1  # 次の字句がこのオプションの引数
                    break
                if ch == "n":
                    return True
        k += 1
    return False


kinds = judge(command)
if not kinds:
    sys.exit(0)

forced = (os.environ.get("DEV_WORKFLOW_GIT_GUARD_FORCE") or "").strip()
if forced in ("ask", "deny"):
    decision = forced
else:
    decision = "ask" if payload.get("permission_mode") in ("default", "acceptEdits", "plan") else "deny"

found = "、".join(LABELS[k] for k in ORDER if k in kinds)
head = ("[dev-workflow git-destructive-guard] 破壊的 git 操作を検出した: " + found + "。"
        "規範の正本は rules/destructive-git-guard.md（破壊的操作は例外なく事前承認）。")
if decision == "deny":
    body = ("このコマンドは実行していない。何を・なぜ・いつ実行するかを示して主に承認を求め、承認されたら"
            "主が自分で実行する（Claude Code の入力欄で ! を付けて打つか、自分の端末で）。")
else:
    body = ("主の確認画面を出している。承認されなければ実行せず、何を・なぜ実行するかを示して主に承認を求めること。")
tail = "言い換えたコマンドや別の書き方で再実行して、この確認を避けてはならない。"
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                          "permissionDecision": decision,
                                          "permissionDecisionReason": head + body + tail}},
                 ensure_ascii=False))
PY
exit 0
