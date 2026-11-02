#!/usr/bin/env python3
"""GitHub にコストの行を書いてよいリポジトリかを判定する。規範の正本は openspec の spec
`cost-ledger-write-allowlist`。

GitHub に書き込む経路（`gate_report.py` の裏の処理と、後から足される後追いのスクリプト）は、
`gh` を呼ぶ前に必ず `allowed()` を通す。一覧の読み方と照合はこのファイルだけが持つ。

- 一覧は、利用者がリポジトリの外に置くテキストファイル。場所は環境変数
  `COST_LEDGER_WRITE_REPOS_FILE`（空でなければその絶対パス）、無ければ
  `$HOME/.config/cost-ledger/write-repos`。1 行に `owner/repo` を 1 つ。空行と `#` で始まる行は
  読み飛ばし、書式に合わない行（ホスト付き・ワイルドカード・URL・末尾コメント付き）はその行だけを
  無視する。照合は大文字と小文字を区別しない
- 環境変数の値そのものは一覧にしない。作業中のリポジトリの `.claude/settings.json` の `env` から
  設定できるため
- 一覧のファイルの実体（シンボリックリンクを解決したもの）が、`cwd` か `CLAUDE_PROJECT_DIR` の
  リポジトリの中にあれば、一覧は空。clone しただけのリポジトリが自分を許可できないようにする。
  「リポジトリの中」は、そこから根までの親のうち `.git` を持つディレクトリのすべてと、`.git` が
  ファイル（worktree・submodule）のときにそれが指すリポジトリ本体。たどれないときも一覧は空
- 実体が通常のファイルでない・持ち主が自分でない・自分以外が書ける・読めないときも、一覧は空

既定（一覧が無い）は「書いてはいけない」。何も出力せず、確かめられないことは「書いてはいけない」に
倒す。標準ライブラリだけを使う。`gh` は起動しない。
"""
import os, re, stat, subprocess

DEFAULT_LIST = os.path.join(".config", "cost-ledger", "write-repos")
REPO_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
MAX_BYTES = 1 << 20  # 一覧のファイルとして読む上限。これを超えるものは一覧として扱わない
GIT_TIMEOUT = 15
GIT_FILE_BYTES = 4096  # .git のファイルと commondir として読む上限

# origin の URL の読み方は cost_ledger.py の RepoResolver.origin() と同じ 3 つの形
# （write-allow.bats が両者の答えの一致を固定している）
ORIGIN_RES = (
    re.compile(r"(?:https?|ssh)://(?:[^@/]+@)?([^/:]+)(?::[0-9]+)?/([^/]+)/([^/]+?)(?:\.git)?/?"),
    re.compile(r"[^@/:]+@([^/:]+):/?([^/]+)/([^/]+?)(?:\.git)?/?"),
)


def list_path():
    """一覧のファイルの場所。決められなければ None。相対パスは使わない（何を基準にするかが
    実行した場所で変わり、作業中のリポジトリの中を指せるため）。"""
    path = os.environ.get("COST_LEDGER_WRITE_REPOS_FILE") or ""
    if not path:
        home = os.environ.get("HOME") or ""
        path = os.path.join(home, DEFAULT_LIST) if home else ""
    return path if os.path.isabs(path) else None


def _git_file_dirs(repo_dir):
    """.git がファイル（worktree・submodule・git ディレクトリを別の場所に置いたリポジトリ）の
    repo_dir について、その先にあるリポジトリ本体のディレクトリを返す。`gitdir:` の先と、そこに
    `commondir` があればその先（worktree の親の git ディレクトリ）を範囲に入れ、名前が `.git` なら
    その親（リポジトリ本体の作業ツリー）も入れる。git は起動せずファイルを読むだけ。
    読めない・解釈できないときは None（呼び出し側は「確かめられない」として一覧を空にする）。"""
    try:
        with open(os.path.join(repo_dir, ".git"), "rb") as f:
            head = f.read(GIT_FILE_BYTES + 1)
        if len(head) > GIT_FILE_BYTES:
            return None
        line = head.decode("utf-8").split("\n", 1)[0].rstrip("\r")
        if not line.startswith("gitdir:") or not line[len("gitdir:"):].strip():
            return None
        gitdir = os.path.realpath(os.path.join(repo_dir, line[len("gitdir:"):].strip()))
        if not os.path.isdir(gitdir):
            return None
        found = [gitdir]
        common_file = os.path.join(gitdir, "commondir")
        if os.path.lexists(common_file):
            with open(common_file, "rb") as f:
                text = f.read(GIT_FILE_BYTES + 1)
            if len(text) > GIT_FILE_BYTES or not text.strip():
                return None
            common = os.path.realpath(os.path.join(gitdir, text.decode("utf-8").strip()))
            if not os.path.isdir(common):
                return None
            found.append(common)
        return found + [os.path.dirname(d) for d in found if _is_dot_git(d)]
    except (OSError, ValueError):
        return None


def _is_dot_git(folder):
    """folder がその親の `.git` か。`.GIT` のような別の綴りで参照されていても当てる。名前を大文字と
    小文字を区別せずに比べるのに加え、親の `.git` と同じディレクトリ（デバイスと inode）かでも見る
    （_inside と同じ見方。大文字と小文字を区別しないファイルシステムで、名前の比べ方に頼らない）。
    どちらかに当たれば親を範囲に入れる（範囲が広がる側に倒す）。"""
    if os.path.basename(folder).casefold() == ".git":
        return True
    try:
        return os.path.samestat(os.stat(os.path.join(os.path.dirname(folder), ".git")),
                                os.stat(folder))
    except OSError:
        return False


def _boundaries(start):
    """start が属するリポジトリの範囲（ディレクトリの一覧）。start から根まで親をたどり、.git を持つ
    ディレクトリをすべて入れる（入れ子のリポジトリの中にいても、外側のリポジトリが範囲に入る）。
    .git がファイルなら、その先のリポジトリ本体も入れる（worktree の中にいても、親のリポジトリ本体が
    範囲に入る）。.git が 1 つも無ければ start そのもの。確かめられないときは None。
    兄弟の worktree（同じリポジトリ本体から切った別の worktree）までは追わない。"""
    start = os.path.realpath(start)
    found = []
    here = start
    while True:
        dot_git = os.path.join(here, ".git")
        if os.path.lexists(dot_git):
            found.append(here)
            if not os.path.isdir(dot_git):
                more = _git_file_dirs(here)
                if more is None:
                    return None
                found.extend(more)
        parent = os.path.dirname(here)
        if parent == here:
            return found or [start]
        here = parent


def _inside(path, folder):
    """path（実体のパス）が folder の配下にあるか。パスの文字列ではなく、親ディレクトリを 1 つずつ
    たどって同じディレクトリ（デバイスと inode）に当たるかで見る。大文字と小文字を区別しない
    ファイルシステムで、別の綴りのパスを使ってすり抜けられないようにするため。
    確かめられないときは「中にある」とする。"""
    try:
        target = os.stat(folder)
        here = os.path.dirname(path)
        while True:
            if os.path.samestat(os.stat(here), target):
                return True
            parent = os.path.dirname(here)
            if parent == here:
                return False
            here = parent
    except OSError:
        return True


def _entries(cwd):
    """一覧に載っているリポジトリ（小文字にした owner/repo）の集合。空として扱う条件に
    当たれば空の集合。"""
    path = list_path()
    if not path or not isinstance(cwd, str) or not cwd:
        return frozenset()
    real = os.path.realpath(path)
    starts = [cwd]
    if os.environ.get("CLAUDE_PROJECT_DIR"):
        starts.append(os.environ["CLAUDE_PROJECT_DIR"])
    for start in starts:
        folders = _boundaries(start)
        if folders is None or any(_inside(real, folder) for folder in folders):
            return frozenset()
    with open(real, "rb") as f:
        st = os.fstat(f.fileno())  # 開いたファイルそのものを見る（リンクの先＝実体）
        if (not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & 0o022
                or st.st_size > MAX_BYTES):
            return frozenset()
        text = f.read(MAX_BYTES + 1).decode("utf-8")
    found = set()
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and REPO_RE.fullmatch(line):
            found.add(line.lower())
    return frozenset(found)


def allowed(repo, cwd):
    """github.com の `owner/repo` にコストの行を書いてよいか。

    repo は `owner/repo`（ホストなし）、cwd は hook の cwd（一覧のファイルが作業中のリポジトリの
    中にないかを見るのに使う）。一覧に載っているときだけ True。それ以外と、確かめる途中で起きた
    どんな失敗も False。"""
    try:
        if not isinstance(repo, str) or not REPO_RE.fullmatch(repo):
            return False
        return repo.lower() in _entries(cwd)
    except Exception:
        return False


def origin_repo(cwd):
    """cwd のリポジトリの origin が github.com なら `owner/repo`。それ以外（origin が無い・
    読めない・別のホスト・git リポジトリでない）は None。`git remote get-url origin` を 1 回呼ぶ。"""
    try:
        if not isinstance(cwd, str) or not cwd or not os.path.isdir(cwd):
            return None
        done = subprocess.run(["git", "-C", cwd, "remote", "get-url", "origin"],
                              stdin=subprocess.DEVNULL, capture_output=True, encoding="utf-8",
                              errors="replace", timeout=GIT_TIMEOUT)
        if done.returncode != 0:
            return None
        url = done.stdout.strip()
        for pattern in ORIGIN_RES:
            matched = pattern.fullmatch(url)
            if matched:
                if matched.group(1).lower() != "github.com":
                    return None
                return "%s/%s" % (matched.group(2), matched.group(3))
        return None
    except Exception:
        return None
