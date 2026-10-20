# git-destructive-guard.sh と git-guard-permit.sh が共通に使う関数（spec destructive-git-hook の要件
# 「子への拒否を記録し、親が 1 回だけ通せるようにする」「許可を書くスクリプトは一時領域の中に収まるコマンド
# だけを許可する」）。判定を 2 か所に書き分けないため、ここに 1 つだけ置く。
#
# 読み方: どちらも python3 -I で動くので、このファイルのディレクトリは sys.path に入らない。呼び出し側の bash が
# 自分のディレクトリからこのファイルのパスを求めて引数で渡し、Python 側が中身を読んで exec で取り込む:
#     ns = {}
#     exec(compile(open(path).read(), path, "exec"), ns)
#     err, scratchpad, repos = ns["check"](session_id, cwd, command)
# 読めない・取り込めないときは、呼び出し側が「判定を満たさない」側に倒す（hook は deny、スクリプトは許可を書かない）。
#
# 一時領域の判定（check）は git を実行しない。子が作った repo の設定（core.fsmonitor など）でコマンドが動きうるため。
# 判定する側の環境に cd や git の行き先・設定を変える環境変数（CDPATH・GIT_DIR など）があれば、判定を満たさない。
import hashlib
import json
import os
import re
import stat
import tempfile
import time

PERMIT_TTL = 15 * 60  # 許可の期限（秒）。環境変数での上書きは設けない
BASE_NAME = "dev-workflow-git-guard"
GIT_SUBCOMMANDS = {"checkout", "restore", "reset", "clean", "branch", "switch",
                   "status", "add", "commit", "rev-parse"}

_ALLOWED_CHARS = re.compile(r"^[A-Za-z0-9 \t\n/._,:=@+%;&-]*$")
_SESSION_ID = re.compile(r"^[A-Za-z0-9-]+$")
_HEX64 = re.compile(r"^[0-9a-f]{64}$")


def _enc(s):
    return s.encode("utf-8", "surrogatepass")


def key_of(session_id, agent_id, cwd, command):
    """拒否の記録と許可のファイル名にする key。4 つの値を NUL でつないだ文字列の sha256。"""
    return hashlib.sha256(_enc("\0".join([session_id, agent_id, cwd, command]))).hexdigest()


def count_name(session_id, agent_id):
    """子への拒否の回数のファイル名（git-destructive-guard.sh の count_child_deny と同じ決め方）。"""
    return hashlib.sha256(_enc(session_id + "\0" + agent_id)).hexdigest()


def is_key(name):
    return bool(_HEX64.match(name))


def append_log(base, entry):
    """<base>/permit-log.jsonl に 1 行足す。失敗したら例外を投げる（扱いは呼び出し側が決める）。"""
    os.makedirs(base, exist_ok=True)
    row = dict(entry)
    row.setdefault("time", int(time.time()))
    with open(os.path.join(base, "permit-log.jsonl"), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")


def write_json_atomic(path, obj):
    """一時ファイルに書いてから rename で置く。"""
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)
    tmp = os.path.join(d, ".%s.tmp.%d" % (os.path.basename(path), os.getpid()))
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(obj, fh, ensure_ascii=False)
        os.rename(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _inside(path, root):
    return path == root or path.startswith(root.rstrip("/") + "/")


# cd と git の行き先・設定を変える環境変数。判定する側（hook・スクリプト）の環境にあれば判定を満たさない。
# 子の Bash は Claude Code の環境を受け継ぐので、hook の環境にあるものは子のコマンドにも効く。値が空でも止める
_REDIRECT_ENV = ("CDPATH", "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
                 "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE",
                 "GIT_CEILING_DIRECTORIES", "GIT_DISCOVERY_ACROSS_FILESYSTEM")
_REDIRECT_ENV_PREFIX = ("GIT_CONFIG",)  # GIT_CONFIG・GIT_CONFIG_GLOBAL・GIT_CONFIG_COUNT・GIT_CONFIG_PARAMETERS など


def _redirect_env():
    """行き先・設定を変える環境変数の名前の一覧（並べ替え済み）。"""
    return sorted(k for k in os.environ
                  if k in _REDIRECT_ENV or any(k.startswith(p) for p in _REDIRECT_ENV_PREFIX))


def _temp_roots():
    """一時フォルダの置き場所の候補（realpath）。親と hook で TMPDIR が違いうるので複数持つ。"""
    roots = set()
    for c in ("/tmp", "/private/tmp", os.environ.get("TMPDIR"), tempfile.gettempdir()):
        if c:
            roots.add(os.path.realpath(c))
    return roots


def _is_scratchpad(path, session_id):
    """`<一時フォルダ>/claude-<uid>/<slug>/<session_id>/scratchpad` か。形に加えて、claude-<uid> の親が一時フォルダの
    置き場所で、claude-<uid> が今の uid の持ち物でグループ・他者に書き込み権が無いことを見る（作業ツリーの中などに
    同じ形のフォルダを作っても通さない）。"""
    if os.path.basename(path) != "scratchpad":
        return False
    sess = os.path.dirname(path)
    if os.path.basename(sess) != session_id:
        return False
    owner = os.path.dirname(os.path.dirname(sess))
    if os.path.basename(owner) != "claude-%d" % os.getuid():
        return False
    if os.path.dirname(owner) not in _temp_roots():
        return False
    try:
        st = os.lstat(owner)
    except OSError:
        return False
    return (stat.S_ISDIR(st.st_mode) and st.st_uid == os.getuid()
            and not st.st_mode & (stat.S_IWGRP | stat.S_IWOTH))


def _find_scratchpad(path, session_id):
    """path（realpath 済み）そのものか祖先のうち、いちばん近い scratchpad。無ければ None。"""
    p = path
    while True:
        if _is_scratchpad(p, session_id):
            return p
        parent = os.path.dirname(p)
        if parent == p:
            return None
        p = parent


def _looks_like_git_dir(p):
    # git の探索は各階層で <dir>/.git の次に <dir> 自身が git ディレクトリか（HEAD・objects・refs）を見る
    return os.path.lexists(os.path.join(p, "HEAD")) and (
        os.path.lexists(os.path.join(p, "objects")) or os.path.lexists(os.path.join(p, "refs")))


def _config_ok(path):
    """config に worktree のキーも include の節も無いか。無ければ None、あれば理由。大文字小文字を区別しない。
    キーや節の書き方（`[core] worktree = x` を 1 行に書く形など）によらず拾うため、文字列として探す（止めすぎる向き）。"""
    if not os.path.lexists(path):
        return None
    try:
        with open(path, "rb") as fh:
            text = fh.read().decode("utf-8", "replace").lower()
    except OSError:
        return "%s を読めない" % path
    if "worktree" in text:
        return "%s に worktree の設定がある（作業ツリーを外に向けられる）" % path
    if "[include" in text:
        return "%s に include の節がある" % path
    return None


def _resolve_repo(d, sp):
    """作業ディレクトリ d（realpath 済み、scratchpad sp の中）から git が見つける repo を辿り、
    (理由, 作業ツリーの最上位) を返す。満たせば理由は None。"""
    p = d
    while True:
        if not _inside(p, sp):
            return "scratchpad の中で .git が見つからない（git は scratchpad の外の repo を探しに行く）", None
        dotgit = os.path.join(p, ".git")
        if os.path.lexists(dotgit):
            break
        if _looks_like_git_dir(p):
            return "%s は git ディレクトリそのもの（bare repo か .git の中）で、作業ツリーを確かめられない" % p, None
        if p == sp:
            return "scratchpad の中で .git が見つからない（git は scratchpad の外の repo を探しに行く）", None
        p = os.path.dirname(p)
    top = p
    if os.path.isdir(dotgit):
        gitdir = os.path.realpath(dotgit)
    elif os.path.isfile(dotgit):
        try:
            with open(dotgit, encoding="utf-8") as fh:
                line = fh.readline().rstrip("\n")
        except (OSError, UnicodeDecodeError):
            return "%s を読めない" % dotgit, None
        if not line.startswith("gitdir: "):
            return "%s が gitdir: の形でない" % dotgit, None
        target = line[len("gitdir: "):]
        gitdir = os.path.realpath(os.path.join(top, target))
    else:
        return "%s がディレクトリでもファイルでもない" % dotgit, None
    if not os.path.isdir(gitdir):
        return "git ディレクトリ %s が無い" % gitdir, None
    common = gitdir
    cd_file = os.path.join(gitdir, "commondir")
    if os.path.lexists(cd_file):
        try:
            with open(cd_file, encoding="utf-8") as fh:
                rel = fh.readline().rstrip("\n")
        except (OSError, UnicodeDecodeError):
            return "%s を読めない" % cd_file, None
        common = os.path.realpath(os.path.join(gitdir, rel))
    for label, path in (("作業ツリー", top), ("git ディレクトリ", gitdir), ("共通の git ディレクトリ", common)):
        if not _inside(path, sp):
            return "%s %s が scratchpad %s の外にある" % (label, path, sp), None
    for cfg in (os.path.join(common, "config"), os.path.join(gitdir, "config.worktree")):
        err = _config_ok(cfg)
        if err:
            return err, None
    return None, top


def _split_simple(command):
    """`&&`・`;`・改行で区切った単純コマンドの語の並びを返す。区切り以外の `&` があれば None。"""
    out = []
    for seg in re.split(r"&&|;|\n", command):
        if "&" in seg:
            return None
        words = seg.split()
        if words:
            out.append(words)
    return out


def check(session_id, cwd, command):
    """一時領域の判定。(理由, scratchpad, 確かめた作業ツリーの一覧) を返す。満たせば理由は None。"""
    if not isinstance(session_id, str) or not _SESSION_ID.match(session_id):
        return "session_id が英数字と - だけの空でない文字列でない", None, None
    env = _redirect_env()
    if env:
        return ("cd や git の行き先・設定を変える環境変数（%s）が設定されている" % "・".join(env)), None, None
    if not isinstance(cwd, str) or not os.path.isabs(cwd):
        return "cwd が絶対パスでない", None, None
    if not isinstance(command, str) or not _ALLOWED_CHARS.match(command):
        return ("コマンドに許していない文字がある（変数・置換・引用符・リダイレクト・パイプ・グロブ・~・"
                "コメント・行継続・CR を含むものは行き先を確定できない）"), None, None
    simple = _split_simple(command)
    if simple is None:
        return "区切りの && 以外の & がある", None, None
    if not os.path.isdir(cwd):
        return "cwd %s がディレクトリでない" % cwd, None, None
    logical = os.path.normpath(cwd)
    physical = os.path.realpath(cwd)
    sp_found, repos, n_git = None, [], 0
    for words in simple:
        head, args = words[0], words[1:]
        if head == "cd":
            if len(args) != 1:
                return "cd は移り先を 1 つだけ書く（cd だけは扱わない）", None, None
            # シェルは / ・ ./ ・ ../ で始まらない引数を、オプション（-P・--）・ディレクトリスタック（+1・-1）・
            # zsh の = 展開・CDPATH や zsh の cdpath の探索として読みうる。判定はそれを辿れないので受け付けない
            if not (args[0] in (".", "..") or args[0].startswith(("/", "./", "../"))):
                return "cd の移り先は / ・ ./ ・ ../ で始めるか . ・ .. だけを書く（%s）" % args[0], None, None
            # bash の cd は .. を字句で畳み（論理的な道筋）、git の -C は chdir で実体を辿る。
            # 両者が同じ所に着くときだけ受け付け、symlink を挟んだ .. で行き先が割れる形を拒む
            nl = os.path.normpath(os.path.join(logical, args[0]))
            np_ = os.path.realpath(os.path.join(physical, args[0]))
            if not os.path.isdir(np_) or os.path.realpath(nl) != np_:
                return "cd の移り先 %s を確定できない" % args[0], None, None
            logical, physical = nl, np_
            continue
        if head != "git":
            return "cd と git 以外のコマンド（%s）がある" % head, None, None
        n_git += 1
        d = physical
        k = 0
        while k < len(args) and args[k] == "-C":
            if k + 1 >= len(args):
                return "git -C の後ろにパスが無い", None, None
            d = os.path.realpath(os.path.join(d, args[k + 1]))
            k += 2
        if k >= len(args):
            return "git のサブコマンドが無い", None, None
        sub = args[k]
        if sub.startswith("-"):
            return "git の大域オプションは -C だけを許す（%s）" % sub, None, None
        if sub not in GIT_SUBCOMMANDS:
            return "git %s は許していない（許すのは %s）" % (sub, "・".join(sorted(GIT_SUBCOMMANDS))), None, None
        if not os.path.isdir(d):
            return "git の作業ディレクトリ %s が無い" % d, None, None
        sp = _find_scratchpad(d, session_id)
        if sp is None:
            return "git の作業ディレクトリ %s がセッション %s の scratchpad の中にない" % (d, session_id), None, None
        if sp_found is not None and sp != sp_found:
            return "git の作業ディレクトリが 2 つの scratchpad にまたがる", None, None
        sp_found = sp
        err, top = _resolve_repo(d, sp)
        if err:
            return err, None, None
        if top not in repos:
            repos.append(top)
    if n_git == 0:
        return "git のコマンドが無い", None, None
    return None, sp_found, repos
