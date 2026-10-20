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


# Claude Code が全セッションの Bash に入れる GIT_CONFIG_COUNT / KEY_<n> / VALUE_<n> の組のうち、キーがすべてこの一覧にある
# ものだけは、行き先も git の挙動も変えないので数えない。足すのは、無害と確かめたキーだけ（足すときは spec を直す）
_HARMLESS_CONFIG_KEYS = ("credential.interactive", "credential.guiPrompt")
_CONFIG_SET_VAR = re.compile(r"^GIT_CONFIG_(COUNT|KEY_[0-9]+|VALUE_[0-9]+)$")


def _harmless_config_set():
    """GIT_CONFIG_COUNT・KEY_<n>・VALUE_<n> の組が、無害なキーだけで揃っていれば、その変数名の集合を返す。
    COUNT が 10 進の非負整数（符号・先頭の 0 の連続なし）で、0..COUNT-1 の KEY と VALUE がすべてあり、KEY がすべて
    一覧にあり、範囲外の番号の KEY / VALUE が無いときだけ。崩れていれば空集合（全部を今までどおり数える）。"""
    count = os.environ.get("GIT_CONFIG_COUNT")
    if count is None or not re.fullmatch(r"0|[1-9][0-9]{0,2}", count):
        return set()
    n = int(count)
    names = {"GIT_CONFIG_COUNT"}
    for i in range(n):
        key = os.environ.get("GIT_CONFIG_KEY_%d" % i)
        if key not in _HARMLESS_CONFIG_KEYS or ("GIT_CONFIG_VALUE_%d" % i) not in os.environ:
            return set()
        names.update(("GIT_CONFIG_KEY_%d" % i, "GIT_CONFIG_VALUE_%d" % i))
    for k in os.environ:
        if _CONFIG_SET_VAR.match(k) and k not in names:
            return set()  # 範囲外の番号
    return names


def _redirect_env():
    """行き先・設定を変える環境変数の名前の一覧（並べ替え済み）。"""
    harmless = _harmless_config_set()
    return sorted(k for k in os.environ
                  if k not in harmless
                  and (k in _REDIRECT_ENV or any(k.startswith(p) for p in _REDIRECT_ENV_PREFIX)))


def _temp_roots(temp_dir=None):
    """一時フォルダの置き場所の候補（realpath）。/tmp・/private/tmp（Claude Code の scratchpad の置き場所）と、
    temp_dir を渡されたらそれ、渡されなければ自分の TMPDIR と tempfile.gettempdir()。許可を書くスクリプトは
    記録の場所から hook の TMPDIR を渡す（自分の TMPDIR で数えると、hook が使えない許可を書いてしまう）。"""
    roots = set()
    extra = (temp_dir,) if temp_dir is not None else (os.environ.get("TMPDIR"), tempfile.gettempdir())
    for c in ("/tmp", "/private/tmp") + extra:
        if c:
            roots.add(os.path.realpath(c))
    return roots


def _is_scratchpad(path, session_id, temp_dir=None):
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
    if os.path.dirname(owner) not in _temp_roots(temp_dir):
        return False
    try:
        st = os.lstat(owner)
    except OSError:
        return False
    return (stat.S_ISDIR(st.st_mode) and st.st_uid == os.getuid()
            and not st.st_mode & (stat.S_IWGRP | stat.S_IWOTH))


def _find_scratchpad(path, session_id, temp_dir=None):
    """path（realpath 済み）そのものか祖先のうち、いちばん近い scratchpad。無ければ None。"""
    p = path
    while True:
        if _is_scratchpad(p, session_id, temp_dir):
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
    if "submodule" in text:
        return "%s に submodule の設定がある（サブモジュールの git ディレクトリを確かめない）" % path
    return None


def _read_one_line(path):
    """.git ファイルと commondir を git と同じに読む: ファイル全体を読み、末尾の CR と LF だけを落とす。
    (中身, 理由) を返す。落としたあとに CR・LF・NUL が残るもの（2 行以上ある・行の途中に改行文字がある）は、
    git の使うパス（改行を含んだまま）と判定が見るパスが割れうるので拒む。"""
    try:
        with open(path, "rb") as fh:
            text = fh.read().decode("utf-8")
    except (OSError, UnicodeDecodeError):
        return None, "%s を読めない" % path
    text = text.rstrip("\r\n")
    if any(c in text for c in "\r\n\0"):
        return None, "%s が 1 行でない（行の途中に改行文字か NUL がある）" % path
    return text, None


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
        line, err = _read_one_line(dotgit)
        if err:
            return err, None
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
        rel, err = _read_one_line(cd_file)
        if err:
            return err, None
        common = os.path.realpath(os.path.join(gitdir, rel))
    for label, path in (("作業ツリー", top), ("git ディレクトリ", gitdir), ("共通の git ディレクトリ", common)):
        if not _inside(path, sp):
            return "%s %s が scratchpad %s の外にある" % (label, path, sp), None
    if not _git_accepts(gitdir, common):
        # git は受け入れない .git を飛ばして上の階層へ探しに行くので、判定が見た repo と別の repo を使う
        return ("%s は git が git ディレクトリとして受け入れない形（HEAD・objects・refs が揃わないか、中に入れない）"
                % gitdir), None
    # 判定と git の受け入れ方がまだどこかでずれていても、git が上の階層の別の repo（確かめていない repo や、
    # scratchpad の外に置かれた .git）を使えないよう、作業ツリーより上のどの階層にも .git や git ディレクトリを許さない
    p = os.path.dirname(top)
    while True:
        if os.path.lexists(os.path.join(p, ".git")) or _looks_like_git_dir(p):
            return "作業ツリー %s より上の %s に別の repo がある（git がそちらを使う余地がある）" % (top, p), None
        parent = os.path.dirname(p)
        if parent == p:
            break
        p = parent
    for g in sorted({gitdir, common}):
        err = _no_links(g, sp)
        if err:
            return err, None
        if os.path.lexists(os.path.join(g, "modules")):
            return "%s にサブモジュールの git ディレクトリ（modules）がある" % g, None
    if os.path.lexists(os.path.join(top, ".gitmodules")):
        return "%s にサブモジュールの定義（.gitmodules）がある" % top, None
    for cfg in (os.path.join(common, "config"), os.path.join(gitdir, "config.worktree")):
        err = _config_ok(cfg)
        if err:
            return err, None
    return None, top


_HEAD_HASH = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")


def _git_accepts(gitdir, common):
    """git が git ディレクトリとして受け入れる形か（git の is_git_directory と同じく、共通の git ディレクトリに
    objects と refs のディレクトリがあって中に入れ（実行権限）、git ディレクトリの HEAD が ref: refs/ で始まるか
    ハッシュ）。git は objects と refs に access(X_OK) を求めるので、入れないものは git が受け入れない。"""
    for p in (gitdir, common, os.path.join(common, "objects"), os.path.join(common, "refs")):
        if not (os.path.isdir(p) and os.access(p, os.X_OK)):
            return False
    try:
        with open(os.path.join(gitdir, "HEAD"), encoding="utf-8") as fh:
            head = fh.readline().rstrip("\r\n")
    except (OSError, UnicodeDecodeError):
        return False
    return head.startswith("ref: refs/") or bool(_HEAD_HASH.match(head))


def _no_links(g, sp):
    """git ディレクトリ g の中に symlink が無く、どれも scratchpad sp の中か。無ければ None、あれば理由。
    refs・index・objects などが外を指すと、判定が中と見た repo の操作が外の repo を書き換える。"""
    for dirpath, dirnames, filenames in os.walk(g, followlinks=False):
        for name in dirnames + filenames:
            p = os.path.join(dirpath, name)
            if os.path.islink(p):
                return "git ディレクトリの中に symlink %s がある" % p
        if not _inside(os.path.realpath(dirpath), sp):
            return "git ディレクトリの中の %s が scratchpad %s の外にある" % (dirpath, sp)
    return None


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


def check(session_id, cwd, command, temp_dir=None):
    """一時領域の判定。(理由, scratchpad, 確かめた作業ツリーの一覧) を返す。満たせば理由は None。
    temp_dir は一時フォルダの置き場所の候補に足す hook の TMPDIR（_temp_roots）。hook は渡さない。"""
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
    # 判定は単純コマンドを実行前のファイルの配置で左から解くので、前のコマンドが成功し配置を変えないことを前提に
    # している。cd が失敗したり、前の git が作業ツリーを書き換えたりすると、判定が見た行き先と実際が割れる。
    # その前提が崩れうる形を次の 4 つで拒む（判定から実行までの短い窓とは別に、コマンド自身の結果で起きる）。
    # 規則 1 と 3 はループで個々の cd と git の形を確かめた後に見る（形の誤りを先に理由として返すため）
    total_git = sum(1 for w in simple if w[0] == "git")
    logical = os.path.normpath(cwd)
    physical = os.path.realpath(cwd)
    sp_found, repos, n_git = None, [], 0
    for words in simple:
        head, args = words[0], words[1:]
        if head == "cd":
            # 規則 2: 前の git が移り先を消したり symlink に置き換えたりしうるので、cd は最初の git より前だけ
            if n_git:
                return "cd は最初の git より前にだけ書く（前の git が移り先を書き換えうる）", None, None
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
        sp = _find_scratchpad(d, session_id, temp_dir)
        if sp is None:
            return "git の作業ディレクトリ %s がセッション %s の scratchpad の中にない" % (d, session_id), None, None
        if sp_found is not None and sp != sp_found:
            return "git の作業ディレクトリが 2 つの scratchpad にまたがる", None, None
        sp_found = sp
        err, top = _resolve_repo(d, sp)
        if err:
            return err, None, None
        # 規則 4: 作業ツリーの中のサブディレクトリは前の git に消されたり置き換えられたりしうる
        if total_git >= 2 and os.path.realpath(d) != os.path.realpath(top):
            return ("git が 2 つ以上あるコマンドは作業ツリーの最上位 %s で走らせる（作業ディレクトリ %s は"
                    "前の git が書き換えうる）" % (top, d)), None, None
        if top not in repos:
            repos.append(top)
    if n_git == 0:
        return "git のコマンドが無い", None, None
    # 規則 1: cd が失敗すると ; や改行の後ろが元の cwd で走るので、cd を含むなら区切りは && だけ
    if any(w[0] == "cd" for w in simple) and re.search(r"[;\n]", command):
        return "cd を含むコマンドの区切りは && だけにする（cd が失敗すると ; や改行の後ろが元の cwd で走る）", None, None
    # 規則 3: 前の git が作業ツリーを書き換えると、後ろの git の -C が辿る道筋が変わる
    if total_git >= 2 and any(w[0] == "git" and "-C" in w[1:2] for w in simple):
        return "git が 2 つ以上あるコマンドでは -C を使わない（前の git が -C の辿る道筋を書き換えうる）", None, None
    return None, sp_found, repos


# --- rm 用の一時領域の判定（spec rm-permission-hook の要件「rm の一時領域の判定」）---
_RM_ALLOWED_CHARS = re.compile(r"^[A-Za-z0-9 \t\n/._,:@+%;&*?-]*$")
_RM_FLAG = re.compile(r"^-[rRf]+$")
_GLOB_CHARS = ("*", "?")


def is_rm_command(command):
    """単純コマンド（; & | && || 改行で区切ったもの）のどれかの先頭の語が rm か。hook が答える入口の形。"""
    if not isinstance(command, str):
        return False
    for seg in re.split(r"&&|\|\||[;&|\n]", command):
        words = seg.split()
        if words and words[0] == "rm":
            return True
    return False


def _rm_target_err(target, base, session_id, temp_dir):
    """削除先 1 つを base（物理パス）基準で解決し、(理由, scratchpad)。満たせば理由は None。"""
    if target.endswith("/"):
        return "削除先 %s が / で終わる" % target, None
    last = os.path.basename(target)
    if last in ("", ".", ".."):
        return "削除先 %s の末尾が . か .. か空" % target, None
    dirpart = os.path.dirname(target) or "."
    if any(c in dirpart for c in _GLOB_CHARS):
        return "削除先 %s のグロブが末尾の要素以外にある" % target, None
    glob = any(c in last for c in _GLOB_CHARS)
    if glob and last.startswith("."):
        return "削除先 %s のグロブが . で始まる（. や .. に当たりうる）" % target, None
    parent = os.path.realpath(os.path.join(base, dirpart))
    sp = _find_scratchpad(parent, session_id, temp_dir)
    if sp is None:
        return "削除先 %s（親 %s）がセッション %s の scratchpad の中にない" % (target, parent, session_id), None
    if glob and parent == sp:
        return "削除先 %s は scratchpad 直下の全消しになる" % target, None
    return None, sp


def check_rm(session_id, cwd, command, temp_dir=None):
    """rm 用の一時領域の判定。(理由, scratchpad, 確かめた削除先の親の一覧) を返す。満たせば理由は None。
    rm も git も実行しない。"""
    if not isinstance(session_id, str) or not _SESSION_ID.match(session_id):
        return "session_id が英数字と - だけの空でない文字列でない", None, None
    if not isinstance(cwd, str) or not os.path.isabs(cwd):
        return "cwd が絶対パスでない", None, None
    if not isinstance(command, str) or not _RM_ALLOWED_CHARS.match(command):
        return "コマンドに許していない文字がある（変数・置換・引用符・リダイレクト・パイプ・~・{} ・コメント・行継続・CR など）", None, None
    simple = _split_simple(command)
    if simple is None:
        return "区切りの && 以外の & がある", None, None
    if not os.path.isdir(cwd):
        return "cwd %s がディレクトリでない" % cwd, None, None
    physical = os.path.realpath(cwd)
    logical = os.path.normpath(cwd)
    bases = [physical]
    rms = []
    n_cd = 0
    for words in simple:
        head, args = words[0], words[1:]
        if head == "cd":
            if rms or n_cd:
                return "cd は 1 つまでで、最初の rm より前にだけ書く", None, None
            n_cd += 1
            if len(args) != 1:
                return "cd は移り先を 1 つだけ書く", None, None
            if not (args[0] in (".", "..") or args[0].startswith(("/", "./", "../"))):
                return "cd の移り先は / ・ ./ ・ ../ で始めるか . ・ .. だけを書く（%s）" % args[0], None, None
            nl = os.path.normpath(os.path.join(logical, args[0]))
            np_ = os.path.realpath(os.path.join(physical, args[0]))
            if not os.path.isdir(np_) or os.path.realpath(nl) != np_:
                return "cd の移り先 %s を確定できない" % args[0], None, None
            bases.append(np_)  # cd が成功した基準。失敗した場合の基準は physical（cwd）
            continue
        if head != "rm":
            return "cd と rm 以外のコマンド（%s）がある" % head, None, None
        targets = []
        for a in args:
            if _RM_FLAG.match(a):
                continue
            if a.startswith("-"):
                return "rm のフラグは -r -R -f の組み合わせだけを許す（%s）" % a, None, None
            targets.append(a)
        if not targets:
            return "rm の削除先が無い", None, None
        rms.append(targets)
    if not rms:
        return "rm のコマンドが無い", None, None
    sp_found, parents = None, []
    for targets in rms:
        for t in targets:
            for base in bases:
                err, sp = _rm_target_err(t, base, session_id, temp_dir)
                if err:
                    return err, None, None
                if sp_found is not None and sp != sp_found:
                    return "削除先が 2 つの scratchpad にまたがる", None, None
                sp_found = sp
                parents.append(t if os.path.isabs(t) else os.path.join(base, t))
    return None, sp_found, sorted(set(parents))


def check_command(session_id, cwd, command, temp_dir=None):
    """記録の command だけで rm 用か git 用かを決めて判定する（記録の kinds は見ない）。"""
    if is_rm_command(command):
        return check_rm(session_id, cwd, command, temp_dir)
    return check(session_id, cwd, command, temp_dir)
