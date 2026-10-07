#!/usr/bin/env python3
"""PostToolUse（matcher Bash）hook の本体。`gate-report.sh` から起動される。

PR / issue へのコメント・状態の変更・ゲート通過（agent-review:passed の付与）を Bash の
コマンド文字列から見つけ、その PR / issue の 1 本のコメントに「ここまでのコスト」を 1 行積む。
規範の正本は openspec の spec `cost-ledger-timeline` と `cost-ledger-gate-report`。

- 同期部分（引数なし）: 標準入力の hook JSON からきっかけを取り出すだけ。gh も台帳も会話ログも
  触らない。対象があれば自分自身を `--work <JSON>` で切り離して起こし、すぐ終わる
- 裏の処理（`--work`）: 対象の確認 → ロック → 既存コメントの取得 →（PR でない issue の
  `issue クローズ` だけ）閉じた PR の問い合わせ → `cost_ledger.py timeline` → 書き込み。gh は
  対象 1 件あたり 3 回、閉じた PR を問い合わせるときだけ 4 回。数字と書式は `cost_ledger.py`
  だけが持ち、ここは gh の読み書きだけを持つ
- `COST_LEDGER_HOOK_FOREGROUND=1` のときは切り離さず、その場で最後まで実行する（テストと実測）
- 書くのは許可の一覧に載っているリポジトリだけ（spec `cost-ledger-write-allowlist`）。裏の処理は
  `write_allow.allowed()` を、最初の gh の前（cwd の origin と、コマンドが名指ししたリポジトリ）と、
  対象の確認のあと（GitHub が返した名前）に通す。一覧に無ければ、そこから先の gh は呼ばない

どの経路でも stdout・stderr に何も出さず終了コード 0。コマンドは評価も再実行もしない。
"""
import fcntl, json, os, re, stat, subprocess, sys, time

import write_allow

LABEL = "agent-review:passed"
MARKER = "<!-- cost-ledger:timeline"  # この文字列で始まる行を持つコメントが積み先
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

GATE = "ゲート通過"
# (gh の第 1 語, 第 2 語) -> (行の「きっかけ」, 値を取るフラグ, 番号を省けるか)
REPO_FLAGS = {"-R", "--repo"}
BODY_FLAGS = REPO_FLAGS | {"-b", "--body", "-F", "--body-file"}
CLOSE_FLAGS = REPO_FLAGS | {"-c", "--comment"}
TRIGGERS = {
    ("pr", "comment"): ("PR コメント", BODY_FLAGS, True),
    ("pr", "ready"): ("Ready", REPO_FLAGS, True),
    ("pr", "close"): ("PR クローズ", CLOSE_FLAGS, False),
    # gh pr merge の -m / -r / -s / -d は値を取らない（--merge / --rebase / --squash / --delete-branch）
    ("pr", "merge"): ("マージ", BODY_FLAGS | {"-t", "--subject", "-A", "--author-email",
                                             "--match-head-commit"}, True),
    ("issue", "comment"): ("issue コメント", BODY_FLAGS, False),
    ("issue", "close"): ("issue クローズ", CLOSE_FLAGS | {"-r", "--reason", "--duplicate-of"}, False),
    ("issue", "reopen"): ("issue 再オープン", CLOSE_FLAGS, False),
}
# issue 向けのコマンドに渡された番号が PR だったときの読み替え。無いものは積まない
AS_PR = {"issue コメント": "PR コメント", "issue クローズ": "PR クローズ"}
URL_RE = re.compile(r"https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/(?:pull|issues)/([0-9]+)")


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
    return [(r, num) for r in repo_values(repo_word, gh_repo, env) for num in numbers]


def repo_values(repo_word, gh_repo, env):
    """リポジトリの指定を gh と同じ順で決める: -R / --repo、無ければ前置きの GH_REPO、
    どちらも無ければ [None]（cwd のリポジトリ）。解決できない値は []（cwd に倒さない）。"""
    if repo_word is None:
        repo_word = gh_repo
    if repo_word is None:
        return [None]
    repos = []
    for v in expand(repo_word, env) or []:
        parts = v.rstrip("/").split("/")
        if len(parts) >= 3 and parts[-3].lower() != "github.com":
            continue  # HOST/OWNER/REPO の HOST が github.com 以外。行を積む対象は github.com だけ
        if len(parts) >= 2 and all(PART_RE.fullmatch(p) for p in parts[-2:]):
            repos.append(parts[-2] + "/" + parts[-1])
    return repos


def trigger_targets(args, env, gh_repo=None):
    """gh pr comment|ready|close|merge と gh issue comment|close|reopen から
    (種別, owner/repo か None, 番号か None, きっかけ) を取り出す。番号 None は省略
    （cwd のブランチの PR）。位置引数は最初の 1 つだけを見て、数字と github.com の URL
    以外（ブランチ名・解決できない変数）は飛ばす。"""
    spec = TRIGGERS.get((args[0], args[1])) if len(args) >= 2 else None
    if spec is None:
        return []
    name, value_flags, may_omit = spec
    repo_word, positional = None, None
    k = 2
    while k < len(args):
        a = args[k]
        if a.startswith("--") and "=" in a:
            flag, _, val = a.partition("=")
            k += 1
        elif a in value_flags and k + 1 < len(args):
            flag, val = a, args[k + 1]
            k += 2
        else:
            if a == "--undo":  # gh pr ready --undo は Draft へ戻す操作で、きっかけではない
                return []
            if not a.startswith("-") and positional is None:
                positional = a
            k += 1
            continue
        if flag in REPO_FLAGS:
            repo_word = val
        elif flag == "--undo" and val != "false":
            return []
    repos = repo_values(repo_word, gh_repo, env)
    if positional is None:
        return [(args[0], r, None, name) for r in repos] if may_omit else []
    out = []
    for v in expand(positional, env) or []:
        m = URL_RE.fullmatch(v)
        if m:
            out.append((args[0], m.group(1) + "/" + m.group(2), int(m.group(3)), name))
        elif NUMBER_RE.fullmatch(v):
            out.extend((args[0], r, int(v), name) for r in repos)
    return out


def github_com(args, gh_host=None):
    """gh の書き込み先が github.com と言えるか。--hostname か前置きの GH_HOST があればその値を
    書き込み先として見て、リテラルの github.com のときだけ True。行を積む対象は github.com だけ。"""
    hosts = [] if gh_host is None else [gh_host]
    for k, a in enumerate(args):
        if a == "--hostname":
            hosts.append(args[k + 1] if k + 1 < len(args) else "")
        elif a.startswith("--hostname="):
            hosts.append(a[len("--hostname="):])
    return all(h.lower() == "github.com" for h in hosts)


def find_triggers(command):
    """コマンド文字列から (種別, owner/repo か None, 番号か None, きっかけ) を実行順に取り出す。"""
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
        prefix = dict(assigns)  # 前置きの代入は gh の環境変数になる（同名は最後が効く）
        if not github_com(args, prefix.get("GH_HOST")):
            continue
        if args[0] == "api":
            out.extend(("pr", r, num, GATE) for r, num in api_targets(args, env))
        elif args[0] in ("pr", "issue") and len(args) >= 2 and args[1] == "edit":
            # ゲート通過の対象は PR だけ。issue の番号なら対象の確認（pulls/<番号>）で落ちる
            out.extend(("pr", r, num, GATE)
                       for r, num in edit_targets(args, env, prefix.get("GH_REPO")))
        else:
            out.extend(trigger_targets(args, env, prefix.get("GH_REPO")))
    return out


# --------------------------------------------------------------------------
# 同期部分: 判定だけをして、残りを裏のプロセスへ渡す
# --------------------------------------------------------------------------

def add_name(names, name):
    if name not in names:
        names.append(name)


def build_job(payload):
    """hook の JSON から裏の処理へ渡す仕事を作る。対象が無ければ None。"""
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return None
    if os.environ.get("GH_HOST", "").lower() not in ("", "github.com"):
        return None  # 引き継いだ GH_HOST で gh の書き込み先が github.com 以外。積む対象は github.com だけ
    at = "%.3f" % time.time()  # 行の時刻・累計を切る時刻・並び順は、コマンドを実行したこの時刻で決める
    targets = {}                # (種別, リポジトリの指定, 番号) -> きっかけ（実行順）
    for kind, repo, number, name in find_triggers(command):
        add_name(targets.setdefault((kind, repo, number), []), name)
    if not targets:
        return None
    cwd = payload.get("cwd") if isinstance(payload.get("cwd"), str) else ""
    return {"cwd": cwd, "at": at,
            "targets": [{"kind": k, "repo": r, "number": n, "triggers": names}
                        for (k, r, n), names in targets.items()]}


def main():
    job = build_job(json.loads(sys.stdin.read()))
    if job is None:
        return
    if os.environ.get("COST_LEDGER_HOOK_FOREGROUND") == "1":
        work(job)
        return
    subprocess.Popen([sys.executable, os.path.abspath(__file__), "--work", json.dumps(job)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)


# --------------------------------------------------------------------------
# 裏の処理: 対象の確認 → ロック → 既存コメントの取得 → timeline → 書き込み
# --------------------------------------------------------------------------

GH_TIMEOUT = 60        # gh 1 回の上限（秒）。裏のプロセスを残し続けないため
TIMELINE_TIMEOUT = 300 # 台帳が未設定で会話ログを直接読む場合を見込む
COMMENTS_JQ = ('.[] | select((.body // "") | split("\\n") | any(startswith("%s"))) '
               '| {id: .id, body: .body} | tojson' % MARKER)


def run(cmd, stdin_text=None, timeout=GH_TIMEOUT, **kw):
    try:
        if stdin_text is None:
            kw["stdin"] = subprocess.DEVNULL
        else:
            kw["input"] = stdin_text
        return subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace",
                              timeout=timeout, **kw)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


# gh の既定ホストや環境変数で github.com 以外へ向かないよう、裏の処理の gh から外す変数
GH_HOST_VARS = ("GH_HOST", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN")


def gh_api(args, stdin_text=None, cwd=None):
    """gh api を 1 回呼ぶ。問い合わせ先と書き込み先は常に github.com（--hostname で固定し、
    GH_HOST と Enterprise 用のトークンは環境から外す）。--hostname は既存の語順を崩さない末尾に置く。"""
    env = {k: v for k, v in os.environ.items() if k not in GH_HOST_VARS}
    kw = {"env": env}
    if cwd and os.path.isdir(cwd):
        kw.update(cwd=cwd)
        env["PWD"] = cwd
    return run(["gh", "api", *args, "--hostname", "github.com"], stdin_text=stdin_text, **kw)


def gh_json(path, cwd):
    """gh api の GET を 1 回呼んで JSON を返す（失敗は None）。パスの {owner}/{repo}/{branch}
    は gh 自身が cwd のリポジトリで埋めるので、cwd で実行する。"""
    p = gh_api([path], cwd=cwd)
    if p is None or p.returncode != 0:
        return None
    try:
        return json.loads(p.stdout)
    except ValueError:
        return None


def full_name(text):
    parts = text.rstrip("/").split("/") if isinstance(text, str) else []
    if len(parts) >= 2 and all(PART_RE.fullmatch(x) for x in parts[-2:]):
        return parts[-2] + "/" + parts[-1]
    return None


def label_names(data):
    return [x.get("name") for x in data.get("labels") or [] if isinstance(x, dict)]


def pr_checks(data):
    return {
        "PR コメント": True,
        "Ready": data.get("draft") is False,
        "PR クローズ": data.get("state") == "closed",
        "マージ": data.get("merged") is True or bool(data.get("merged_at")),
        GATE: LABEL in label_names(data),
    }


def issue_checks(data):
    return {
        "issue コメント": True,
        "issue クローズ": data.get("state") == "closed",
        "issue 再オープン": data.get("state") == "open",
    }


def resolve(target, cwd):
    """対象を GitHub に確かめ、(種別, owner/repo, 番号, ヘッドブランチ, 残ったきっかけ) を返す。
    存在しない・状態が合わない・解決できないときは None。"""
    kind, spec, number, names = (target["kind"], target["repo"], target["number"],
                                 list(target["triggers"]))
    where = spec or "{owner}/{repo}"
    if kind == "issue":
        data = gh_json("repos/%s/issues/%d" % (where, number), cwd)
        if not isinstance(data, dict):
            return None
        repo = full_name(data.get("repository_url"))
        if repo is None:
            return None
        if "pull_request" not in data:
            checks = issue_checks(data)
            names = [n for n in names if checks.get(n)]
            return ("issue", repo, number, None, names) if names else None
        # 番号が PR だった。PR として扱い、ヘッドブランチと状態は pulls/<番号> から取り直す
        names = [AS_PR[n] for n in names if n in AS_PR]
        if not names:
            return None
        data = gh_json("repos/%s/pulls/%d" % (repo, number), cwd)
    elif number is None:
        owner = spec.split("/")[0] if spec else "{owner}"
        data = gh_json("repos/%s/pulls?head=%s:{branch}&state=all" % (where, owner), cwd)
        data = data[0] if isinstance(data, list) and data else None
    else:
        data = gh_json("repos/%s/pulls/%d" % (where, number), cwd)
    if not isinstance(data, dict):
        return None
    repo = full_name(((data.get("base") or {}).get("repo") or {}).get("full_name"))
    branch = (data.get("head") or {}).get("ref")
    number = data.get("number") if number is None else number
    if repo is None or not isinstance(branch, str) or not branch or not isinstance(number, int):
        return None
    checks = pr_checks(data)
    names = [n for n in names if checks.get(n)]
    return ("pr", repo, number, branch, names) if names else None


def lock(repo, number):
    """対象ごとの排他ロックを取る。取れなければ None（読んでから書くまでを直列にできないので書かない）。"""
    try:
        folder = os.path.join(os.environ.get("TMPDIR") or "/tmp", "cost-ledger-timeline")
        os.makedirs(folder, mode=0o700, exist_ok=True)
        # 共有の /tmp に他人が先に作った場所（シンボリックリンク・他人の持ち物・他人が書ける）は使わない
        st = os.lstat(folder)
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & 0o022:
            return None
        path = os.path.join(folder, "%s__%d.lock" % (repo.replace("/", "__"), number))
        fd = os.open(path, os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        return fd
    except OSError:
        return None


def existing_comment(repo, number):
    """目印の行を持つコメントの (id, 本文)。無ければ (None, "")。分からなければ None。"""
    # --paginate の出力は複数ページだと配列が連結されるので、ページごとに jq で 1 件 1 行にする
    p = gh_api(["--paginate", "repos/%s/issues/%d/comments?per_page=100" % (repo, number),
                "--jq", COMMENTS_JQ])
    if p is None or p.returncode != 0:
        return None
    for line in p.stdout.splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except ValueError:
            return None
        if isinstance(item, dict) and isinstance(item.get("id"), int) and isinstance(item.get("body"), str):
            return item["id"], item["body"]
        return None
    return None, ""


# issue を閉じた PR（既定の引数なのでクローズ済みで未マージの PR は含まれない）。owner・name・number
# は変数で渡し、問い合わせの文字列に埋め込まない
CLOSING_QUERY = (
    "query($owner: String!, $name: String!, $number: Int!) {"
    " repository(owner: $owner, name: $name) { issue(number: $number) {"
    " closedByPullRequestsReferences(first: 100) {"
    " nodes { number headRefName isCrossRepository baseRepository { nameWithOwner } }"
    " pageInfo { hasNextPage } } } } }"
)


def closing_prs(repo, number):
    """issue を閉じた PR のうち数えるものの [(番号, ヘッドブランチ)]。gh api graphql を 1 回呼ぶ。

    ベースが対象のリポジトリ（大文字と小文字は区別しない）で、ヘッドブランチも同じリポジトリに
    ある PR だけを残す。失敗・JSON でない・100 件を超える・1 件でも形が崩れているときは空
    （一部しか読めていない結果で合計を作らない）。"""
    owner, _, name = repo.partition("/")
    p = gh_api(["graphql", "-f", "query=" + CLOSING_QUERY, "-f", "owner=" + owner,
                "-f", "name=" + name, "-F", "number=%d" % number])
    if p is None or p.returncode != 0:
        return []
    try:
        refs = json.loads(p.stdout)["data"]["repository"]["issue"]["closedByPullRequestsReferences"]
        nodes, more = refs["nodes"], refs["pageInfo"]["hasNextPage"]
    except (ValueError, KeyError, TypeError):
        return []
    if more is not False or not isinstance(nodes, list):
        return []
    found = []
    for node in nodes:
        if not isinstance(node, dict):
            return []
        pr, head, cross = node.get("number"), node.get("headRefName"), node.get("isCrossRepository")
        base = (node.get("baseRepository") or {}).get("nameWithOwner") \
            if isinstance(node.get("baseRepository"), dict) else None
        if (type(pr) is not int or pr < 1 or not isinstance(head, str) or not head
                or not isinstance(cross, bool) or not isinstance(base, str)):
            return []
        if not cross and base.lower() == repo.lower():
            found.append((pr, head))
    return found


def stack(kind, repo, number, branch, names, at, cwd, scripts_dir):
    """1 行積む。ロックを持ったまま、読み取り・（issue のクローズなら閉じた PR の問い合わせ）・
    timeline・書き込みを行う。"""
    found = existing_comment(repo, number)
    if found is None:  # 既存コメントの有無が分からないので書かない
        return
    comment_id, before = found
    cmd = [sys.executable, os.path.join(scripts_dir, "cost_ledger.py"), "timeline"]
    cmd += ["--pr", str(number), "--branch", branch] if kind == "pr" else ["--issue", str(number)]
    cmd += ["--trigger", "+".join(names), "--at", at]
    if kind == "issue" and "issue クローズ" in names:
        # 問い合わせが失敗・0 件なら --closing-pr を付けず、issue クローズの行だけを積む
        for pr, head in closing_prs(repo, number):
            cmd += ["--closing-pr", "%d:%s" % (pr, head)]
    if cwd:
        cmd += ["--repo", cwd]
    cmd += ["--target-repo", repo]
    p = run(cmd, stdin_text=before, timeout=TIMELINE_TIMEOUT,
            env=dict(os.environ, PYTHONIOENCODING="utf-8"),
            cwd=cwd if cwd and os.path.isdir(cwd) else None)
    if p is None or p.returncode != 0 or not p.stdout.startswith("コスト: "):
        return
    body = p.stdout.rstrip("\n")
    if body == before.rstrip("\n"):  # 同じ節目の二重実行。書き換えるものが無い
        return
    data = json.dumps({"body": body})
    if comment_id is None:
        gh_api(["-X", "POST", "repos/%s/issues/%d/comments" % (repo, number), "--input", "-"],
               stdin_text=data)
    else:
        # PATCH が失敗しても新規作成に切り替えない（コメントを増やさないことを優先する）
        gh_api(["-X", "PATCH", "repos/%s/issues/comments/%d" % (repo, comment_id), "--input", "-"],
               stdin_text=data)


def work(job):
    cwd, at = job.get("cwd") or "", job["at"]
    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    # 書くのは cwd の origin のリポジトリのものだけなので、origin が許可の一覧に無ければ、どの対象にも
    # 書かないことが決まっている。gh を 1 回も呼ばずに終わる
    if not write_allow.allowed(write_allow.origin_repo(cwd), cwd):
        return
    resolved = {}  # (owner/repo, 番号) -> [種別, ヘッドブランチ, きっかけ]。別の書き方で同じ対象を指した分をまとめる
    for target in job["targets"]:
        if target["repo"] is not None and not write_allow.allowed(target["repo"], cwd):
            continue  # コマンドが名指ししたリポジトリが一覧に無い。対象の確認の gh も呼ばない
        try:
            found = resolve(target, cwd)
        except Exception:
            found = None
        if found is None:
            continue
        kind, repo, number, branch, names = found
        if not write_allow.allowed(repo, cwd):
            continue  # GitHub が返した名前が一覧に無い（改名・移管で別の名前へ転送された）。ここから先の gh は呼ばない
        entry = resolved.setdefault((repo, number), [kind, branch, []])
        for name in names:
            add_name(entry[2], name)
    for (repo, number), (kind, branch, names) in resolved.items():
        fd = lock(repo, number)
        if fd is None:
            continue
        try:
            stack(kind, repo, number, branch, names, at, cwd, scripts_dir)
        except Exception:
            pass
        finally:
            os.close(fd)  # 閉じるとロックも外れる


if __name__ == "__main__":
    try:
        if len(sys.argv) >= 3 and sys.argv[1] == "--work":
            work(json.loads(sys.argv[2]))
        else:
            main()
    except BaseException:
        pass
    sys.exit(0)
