#!/usr/bin/env bash
# PostToolUse（matcher Bash）hook: ゲート通過（agent-review:passed の付与）の直後に、
# その PR へ `/cost <PR番号>` の 1 行目と同じ行をコメントで貼る。LLM のトークンは使わない。
# 規範の正本は openspec の spec `cost-ledger-gate-report`。
#
#   緊急停止 COST_LEDGER_GATE_REPORT=off
#
# この hook は全 Bash 呼び出しで起動するので、stdin に文字列 agent-review:passed が
# 無ければ JSON のパースも jq・python3 の起動もせずに抜ける（fast path）。判定対象が
# payload 全体なのは tool_response（コマンドの出力）も入るためで、ラベル名を表示しただけの
# 呼び出しも通るが、その先の厳密な判定で落ちて無音で終わるだけになる。
#
# どの経路でも stdout・stderr に何も出さず終了コード 0。hook の失敗でゲートを止めず、
# 文脈にも何も入れないため。
set -u

[ "${COST_LEDGER_GATE_REPORT:-on}" = "off" ] && exit 0
payload="$(cat)" || exit 0
case "$payload" in
  *agent-review:passed*) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0
command -v gh >/dev/null 2>&1 || exit 0
# cost_ledger.py は CLAUDE_PLUGIN_ROOT ではなくこのスクリプトの隣から引く。python3 から見た
# 自分のパスは /dev/fd/3 になるので、ディレクトリは bash 側で解決して環境変数で渡す。
scripts_dir="$(cd "$(dirname "$0")" && pwd)" || exit 0

# Python 本体は fd 3 のヒアドキュメントで渡し、payload は stdin から読ませる。
# payload を環境変数や引数に載せると長い出力で ARG_MAX を超えて hook が落ちる。
printf '%s' "$payload" 2>/dev/null | COST_LEDGER_SCRIPTS_DIR="$scripts_dir" python3 /dev/fd/3 3<<'PY' >/dev/null 2>&1
import json, os, re, subprocess, sys, time

LABEL = "agent-review:passed"
MARKER = "<!-- cost-ledger:gate-report -->"
UNRESOLVED = "\x00"     # $(...) とバッククォートの跡。値が分からない印
LITERAL_DOLLAR = "\x01" # シングルクォート内・\$ の $。展開の対象から外し、最後に $ へ戻す
SUBSHELL_OPEN = "\x02"  # ( ) のサブシェルの出入りを断片の列に残す印
SUBSHELL_CLOSE = "\x03"

NAME = r"[A-Za-z_][A-Za-z0-9_]*"
ASSIGN_RE = re.compile(r"(" + NAME + r")=(.*)", re.S)
VAR_RE = re.compile(r"\$(?:\{(" + NAME + r")\}|(" + NAME + r"))")
LABELS_PATH_RE = re.compile(r"/?repos/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/issues/([0-9]+)/labels")
PART_RE = re.compile(r"[A-Za-z0-9_.-]+")
NUMBER_RE = re.compile(r"[0-9]+")
# gh pr edit / gh issue edit で値を取るフラグ（最初の位置引数を見分けるために飛ばす）
VALUE_FLAGS = {
    "-R", "--repo", "--add-label", "--remove-label", "--add-assignee", "--remove-assignee",
    "--add-reviewer", "--remove-reviewer", "--add-project", "--remove-project",
    "-B", "--base", "-b", "--body", "-F", "--body-file", "-m", "--milestone", "-t", "--title",
}


class Lexer:
    """コマンド文字列を断片（語のリスト）の列にする。評価も実行もしない。

    区切りは ; && || | 改行 & ( ) で、引用符・$(...)・バッククォートの中は区切らない。
    ( と ) はサブシェルの出入りとして、それだけの断片 [SUBSHELL_OPEN] / [SUBSHELL_CLOSE] も残す。
    リダイレクトとその行き先は語から除き、heredoc の本文は読み飛ばす。行の途中の # から
    行末はコメントとして捨てる。"""

    def __init__(self, s):
        self.s = s
        self.n = len(s)
        self.heredocs = []  # 次の改行のあとに本文が来る heredoc の (終端語, 先頭のタブを除くか)

    def segments(self):
        segs, _ = self.scan(0, nested=False)
        return segs

    def scan(self, i, nested):
        """nested なら $( の直後から対応する ) まで読んで、その次の位置を返す。"""
        s, n = self.s, self.n
        segs, words, word = [], [], []
        state = {"have": False, "redirect": None, "depth": 0}

        def end_word():
            if state["have"]:
                w = "".join(word)
                r = state["redirect"]
                if r is None:
                    words.append(w)
                elif r != "file":
                    self.heredocs.append((w.replace(LITERAL_DOLLAR, "$"), r == "heredoc-"))
                state["redirect"] = None
            del word[:]
            state["have"] = False

        def end_seg():
            end_word()
            state["redirect"] = None
            if words:
                segs.append(list(words))
            del words[:]

        while i < n:
            c = s[i]
            if c == "\\":
                nxt = s[i + 1] if i + 1 < n else ""
                if nxt != "\n":  # \改行 は行の継続
                    word.append(LITERAL_DOLLAR if nxt == "$" else nxt)
                    state["have"] = True
                i += 2
            elif c == "'":
                j = s.find("'", i + 1)
                j = n if j < 0 else j
                word.append(s[i + 1:j].replace("$", LITERAL_DOLLAR))
                state["have"] = True
                i = j + 1
            elif c == '"':
                i = self.dquote(i + 1, word)
                state["have"] = True
            elif c == "`":
                i = self.backtick(i + 1)
                word.append(UNRESOLVED)
                state["have"] = True
            elif c == "$" and s.startswith("$(", i):
                _, i = self.scan(i + 2, nested=True)
                word.append(UNRESOLVED)
                state["have"] = True
            elif c == "#" and not state["have"]:
                j = s.find("\n", i)
                i = n if j < 0 else j
            elif c in " \t":
                end_word()
                i += 1
            elif c == "\n":
                end_seg()
                i = self.skip_heredocs(i + 1)
            elif c == ";":
                end_seg()
                i += 1
            elif c == "&":
                if s.startswith("&>", i):
                    end_word()
                    state["redirect"] = "file"
                    i += 3 if s.startswith("&>>", i) else 2
                else:
                    end_seg()
                    i += 2 if s.startswith("&&", i) else 1
            elif c == "|":
                end_seg()
                i += 2 if s[i + 1:i + 2] in ("|", "&") else 1
            elif c in "<>":
                if state["have"] and "".join(word).isdigit():  # 2>&1 の 2 はファイル記述子
                    del word[:]
                    state["have"] = False
                else:
                    end_word()
                if s.startswith("<<<", i):
                    state["redirect"] = "file"
                    i += 3
                elif s.startswith("<<-", i):
                    state["redirect"] = "heredoc-"
                    i += 3
                elif s.startswith("<<", i):
                    state["redirect"] = "heredoc"
                    i += 2
                else:
                    state["redirect"] = "file"
                    i += 2 if s[i + 1:i + 2] in (">", "&", "|") else 1
            elif c == "(":
                end_seg()
                if nested:
                    state["depth"] += 1
                else:
                    segs.append([SUBSHELL_OPEN])
                i += 1
            elif c == ")":
                end_seg()
                i += 1
                if not nested:
                    segs.append([SUBSHELL_CLOSE])
                else:
                    if state["depth"] == 0:
                        return segs, i
                    state["depth"] -= 1
            else:
                word.append(c)
                state["have"] = True
                i += 1
        end_seg()
        return segs, n

    def dquote(self, i, word):
        s, n = self.s, self.n
        while i < n:
            c = s[i]
            if c == '"':
                return i + 1
            if c == "\\" and s[i + 1:i + 2] in ("$", "`", '"', "\\", "\n"):
                nxt = s[i + 1]
                if nxt != "\n":
                    word.append(LITERAL_DOLLAR if nxt == "$" else nxt)
                i += 2
            elif c == "`":
                i = self.backtick(i + 1)
                word.append(UNRESOLVED)
            elif c == "$" and s.startswith("$(", i):
                _, i = self.scan(i + 2, nested=True)
                word.append(UNRESOLVED)
            else:
                word.append(c)
                i += 1
        return n

    def backtick(self, i):
        s, n = self.s, self.n
        while i < n:
            if s[i] == "\\":
                i += 2
            elif s[i] == "`":
                return i + 1
            else:
                i += 1
        return n

    def skip_heredocs(self, i):
        s, n = self.s, self.n
        for delim, strip_tabs in self.heredocs:
            while i < n:
                j = s.find("\n", i)
                line = s[i:] if j < 0 else s[i:j]
                i = n if j < 0 else j + 1
                if (line.lstrip("\t") if strip_tabs else line) == delim:
                    break
        self.heredocs = []
        return i


def is_literal(value):
    return not any(ch in value for ch in ("$", UNRESOLVED, "*", "?", "["))


def expand(word, env):
    """$NAME / ${NAME} を展開した値のリスト。解決できなければ None。"""
    if UNRESOLVED in word:
        return None
    results, pos = [""], 0
    for m in VAR_RE.finditer(word):
        values = env.get(m.group(1) or m.group(2))
        if values is None:
            return None
        lit = word[pos:m.start()]
        results = [r + lit + v for r in results for v in values]
        pos = m.end()
    results = [r + word[pos:] for r in results]
    if any("$" in r for r in results):  # ${N:-1} や $1 のような、扱わない展開が残った
        return None
    return [r.replace(LITERAL_DOLLAR, "$") for r in results]


def api_targets(args, env):
    """gh api の付与から (owner/repo, 番号) を取り出す。"""
    method, granted, candidates = "", False, []
    k = 0
    while k < len(args):
        a = args[k]
        if a in ("-X", "--method") and k + 1 < len(args):
            method = args[k + 1]
            k += 2
            continue
        if a.startswith("--method="):
            method = a[len("--method="):]
        elif a.startswith("-X"):
            method = a[2:]
        if a.replace(LITERAL_DOLLAR, "$").endswith("labels[]=" + LABEL):
            granted = True
        candidates.append(a)
        k += 1
    # -f があるのでメソッド省略時は POST。PUT はラベルの置き換えで、これも付与になる
    if not granted or method.upper() not in ("", "POST", "PUT"):
        return []
    out = []
    for a in candidates:
        for v in expand(a, env) or []:
            m = LABELS_PATH_RE.fullmatch(v)
            if m:
                out.append((m.group(1) + "/" + m.group(2), int(m.group(3))))
    return out


def edit_targets(args, env, gh_repo=None):
    """gh pr edit / gh issue edit の付与から (owner/repo か None, 番号) を取り出す。
    リポジトリは gh と同じく -R / --repo、無ければ前置きの GH_REPO（gh_repo）、どちらも
    無ければ None（cwd のリポジトリ）。番号は最初の位置引数が数字のときだけ使う。"""
    repo_word, labels, positional = None, [], None
    k = 2
    while k < len(args):
        a = args[k]
        if a.startswith("--") and "=" in a:
            flag, _, val = a.partition("=")
            k += 1
        elif a in VALUE_FLAGS and k + 1 < len(args):
            flag, val = a, args[k + 1]
            k += 2
        else:
            if not a.startswith("-") and positional is None:
                positional = a
            k += 1
            continue
        if flag in ("-R", "--repo"):
            repo_word = val
        elif flag == "--add-label":
            labels.append(val.replace(LITERAL_DOLLAR, "$"))
    if not any(LABEL in [p.strip() for p in v.split(",")] for v in labels):
        return []
    if positional is None:
        return []
    numbers = [int(v) for v in (expand(positional, env) or []) if NUMBER_RE.fullmatch(v)]
    if repo_word is None:
        repo_word = gh_repo  # 解決できない値なら下で飛ばす（cwd に倒さない）
    if repo_word is None:
        return [(None, num) for num in numbers]
    repos = []
    for v in expand(repo_word, env) or []:
        parts = v.rstrip("/").split("/")
        if len(parts) >= 2 and all(PART_RE.fullmatch(p) for p in parts[-2:]):
            repos.append(parts[-2] + "/" + parts[-1])
    return [(r, num) for r in repos for num in numbers]


def grant_targets(command):
    env = {}      # 変数名 -> 値のリスト（解決できないときは None）
    loops = []    # 開いている for の変数名（while / until は None）
    saved = []    # ( に入ったときの env の控え。サブシェルの中の代入は ) を出たら捨てる
    out = []
    for words in Lexer(command).segments():
        if words == [SUBSHELL_OPEN]:
            saved.append(dict(env))
            continue
        if words == [SUBSHELL_CLOSE]:
            if saved:
                env = saved.pop()
            continue
        while words and words[0] in ("do", "then"):
            words = words[1:]
        if not words:
            continue
        head = words[0]
        if head == "for" and len(words) >= 3 and re.fullmatch(NAME, words[1]) and words[2] == "in":
            values = words[3:]
            env[words[1]] = values if values and all(is_literal(v) for v in values) else None
            loops.append(words[1])
            continue
        if head in ("while", "until"):
            loops.append(None)
            continue
        if head == "done":
            name = loops.pop() if loops else None
            if name and env.get(name):  # ループのあとの変数は最後の値
                env[name] = env[name][-1:]
            continue
        assigns = []
        while words and ASSIGN_RE.fullmatch(words[0]):
            assigns.append(ASSIGN_RE.fullmatch(words[0]).groups())
            words = words[1:]
        if not words:  # 代入だけの断片がシェル変数を作る（コマンドの前置きは環境変数）
            for name, value in assigns:
                env[name] = [value] if is_literal(value) else None
            continue
        if words[0] != "gh" or len(words) < 2:
            continue
        args = words[1:]
        if args[0] == "api":
            out.extend(api_targets(args, env))
        elif args[0] in ("pr", "issue") and len(args) >= 2 and args[1] == "edit":
            prefix = dict(assigns)  # 前置きの代入は gh の環境変数になる（同名は最後が効く）
            out.extend(edit_targets(args, env, prefix.get("GH_REPO")))
    return out


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True,
                               encoding="utf-8", errors="replace", **kw)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def cwd_repo(cwd):
    """gh pr edit が -R 無しで使うのと同じリポジトリを、cwd で gh 自身に答えさせる。"""
    if not cwd or not os.path.isdir(cwd):
        return None
    p = run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
            cwd=cwd, env=dict(os.environ, PWD=cwd))
    if p is None or p.returncode != 0:
        return None
    v = p.stdout.strip()
    parts = v.split("/")
    return v if len(parts) == 2 and all(PART_RE.fullmatch(x) for x in parts) else None


def report(repo, number, cwd, scripts_dir):
    # ラベルが実際に付いたか。複合コマンドの中の付与が成功したかは PostToolUse では分からない
    p = run(["gh", "api", "repos/%s/issues/%d" % (repo, number), "--jq", ".labels[].name"])
    if p is None or p.returncode != 0 or LABEL not in p.stdout.splitlines():
        return
    cost = [sys.executable, os.path.join(scripts_dir, "cost_ledger.py"), "cost", str(number)]
    if cwd:
        cost += ["--repo", cwd]
    p = run(cost, env=dict(os.environ, GH_REPO=repo, PYTHONIOENCODING="utf-8"),
            cwd=cwd if cwd and os.path.isdir(cwd) else None)
    if p is None or p.returncode != 0:
        return
    line = p.stdout.split("\n", 1)[0]
    if not line.startswith("コスト: "):
        return
    body = "%s\n%s 時点・ゲート通過時に自動投稿\n%s" % (line, time.strftime("%Y-%m-%d %H:%M"), MARKER)
    # --paginate の出力は複数ページだと配列が連結されるので、ページごとに jq で id だけ出させる
    p = run(["gh", "api", "--paginate", "repos/%s/issues/%d/comments" % (repo, number),
             "--jq", '.[] | select(.body | contains("%s")) | .id' % MARKER])
    if p is None or p.returncode != 0:  # 既存コメントの有無が分からないので貼らない
        return
    ids = [x.strip() for x in p.stdout.splitlines() if x.strip()]
    if ids and NUMBER_RE.fullmatch(ids[0]):
        # PATCH が失敗しても新規作成に切り替えない（コメントを増やさないことを優先する）
        run(["gh", "api", "-X", "PATCH", "repos/%s/issues/comments/%s" % (repo, ids[0]),
             "-f", "body=" + body])
    elif not ids:
        run(["gh", "api", "-X", "POST", "repos/%s/issues/%d/comments" % (repo, number),
             "-f", "body=" + body])


def main():
    payload = json.loads(sys.stdin.read())
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return
    cwd = payload.get("cwd") if isinstance(payload.get("cwd"), str) else ""
    scripts_dir = os.environ.get("COST_LEDGER_SCRIPTS_DIR", "")
    targets, seen, here = [], set(), []
    for repo, number in grant_targets(command):
        if repo is None:
            if not here:
                here.append(cwd_repo(cwd))  # 必要になったときに 1 回だけ
            repo = here[0]
            if repo is None:
                continue
        if (repo, number) not in seen:
            seen.add((repo, number))
            targets.append((repo, number))
    for repo, number in targets:  # for で複数付与したときは順に処理する
        report(repo, number, cwd, scripts_dir)


try:
    main()
except BaseException:
    pass
PY
exit 0
