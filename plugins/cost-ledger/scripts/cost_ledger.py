#!/usr/bin/env python3
"""cost-ledger — Claude Code の会話ログから API 換算コストを集計する。

読むのは ``${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects`` 配下の JSONL。
アシスタントの 1 メッセージが 1 行で、``gitBranch`` / ``cwd`` / ``sessionId`` /
``timestamp`` / ``isSidechain`` / ``message.model`` / ``message.usage`` /
``requestId`` / ツール呼び出しの入力を持つ。

設計上の要点:

- **事実の抽出と帰属の導出を分ける。** 1 行から取るのは事実だけで、区間の帰属は
  事実の列に対する関数として別に導く。区間の帰属は次の投稿が来るまで確定しないので、
  1 行ずつ追記する経路（台帳）が書けるのは事実の側に限られる。
- **会話ログは既定 30 日で消える。** 環境変数 ``COST_LEDGER_PATH`` が設定されていれば、
  事実をリポジトリ外の append-only の台帳へ焼き付け（``ledger-sync``・Stop hook）、
  集計は台帳から読む。未設定なら会話ログを直接読む。
- **単価と換算レートはこのファイルに書かない。** 隣の ``pricing.json`` だけが持つ。
- **速度は 1 行目の文字列判定に依存する。** JSON にパースする前に生の行へ
  ``"assistant"`` が含まれるかで弾く。パースしてから判定すると桁違いに遅くなる。
"""

from __future__ import annotations

import argparse
import datetime
import fcntl
import io
import json
import math
import os
import re
import sqlite3
import subprocess
import sys
import time
import unicodedata
from collections import defaultdict

# リポジトリ識別子が導けなかった行の印。黙って除外も合算もせず、この名前で別立てにする。
UNKNOWN_REPO = "不明"

# 期待する形になっていない行の件数。1 行の構造不正で全集計を落とさず、かといって
# 黙って捨てもしない（リポジトリ不明・未帰属と同じ扱い）。集計の最後に件数だけ出す。
SCAN_STATS = {"unreadable_lines": 0}

# 第 2 の鍵になる issue 番号を拾うコマンド。拾う 5 つのサブコマンドは設計の根拠になった
# 計測（archive 済みの change cost-ledger-aggregation の design に記録）と一致させるが、
# 走査する場所は実行された Bash の command だけに限る（計測はツール入力全体を見ており、
# 実行していない文字列にも反応する）。
ISSUE_RE = re.compile(r"gh issue (?:view|comment|edit|close|develop)\s+(\d+)")

# 区間の境界になる投稿。設計の根拠になった計測（archive 済みの change cost-ledger-aggregation
# の design に記録）が境界にしている集合と一致させる。
POST_MARKERS = ("gh pr comment", "gh issue comment", "gh pr create", "gh pr ready")

# 事実側のトークン 5 種と、料金表側の単価 5 種の対応（順序が対応そのもの）
TOKEN_FIELDS = (
    "input_tokens",
    "output_tokens",
    "cache_write_5m_tokens",
    "cache_write_1h_tokens",
    "cache_read_tokens",
)
PRICE_FIELDS = ("input", "output", "cache_write_5m", "cache_write_1h", "cache_read")

DEFAULT_PRICING = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "pricing.json")

# 単価表のずれの警告。Claude Code 本体が出すセッションコスト（statusline が
# <設定ディレクトリ>/.session-cost/<セッション ID> に書き残した値）と自前の計算の差が、
# 下の差額と割合の**両方**を超えたセッションを「ずれあり」とする。閾値はここにだけ置き、
# 警告の文面もこの値から作る。
DRIFT_MIN_USD = 0.50      # 差額（USD）
DRIFT_MIN_RATIO = 0.10    # 割合（本体の値と自前の計算の大きい方に対して）
# 浮動小数の誤差の分。差額がちょうど閾値のとき（$10.00 と $9.50）に「超えた」にしない。
DRIFT_EPSILON = 1e-9

# 突き合わせのためだけに会話ログ（または台帳）を読み直す時間の上限。答えを出したあとに
# 足される待ち時間なので、既定は 1 秒で打ち切る。環境変数で 0 以上の秒数か inf に変えられる。
DRIFT_BUDGET_SECONDS = 1.0
DRIFT_BUDGET_ENV = "COST_LEDGER_DRIFT_BUDGET_SECONDS"
# 1 つのファイルの中で、生の行をこの数だけ読むごとに経過時間を確かめる
# （台帳は 1 つの大きなファイルなので、ファイルの切れ目だけでは打ち切れない）。
DRIFT_CHECK_EVERY_LINES = 5000

# 記録のファイル名に使われるセッション ID の形（statusline が書くときの検査と同じ）。
# 会話ログに sessionId が無い行は session_id がファイルパスになるので、ここで弾く。
SESSION_ID_RE = re.compile(r"[A-Za-z0-9_-]{1,128}")
RECORD_NUMBER_RE = re.compile(r"[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?")


# --------------------------------------------------------------------------
# 料金表
# --------------------------------------------------------------------------

class Pricing:
    """pricing.json の内容。単価と換算レートを持つ唯一の入口。"""

    def __init__(self, data: dict):
        self.models = data["models"]
        self.rate_env = data.get("usd_jpy_rate_env", "COST_LEDGER_USD_JPY")
        rate = data["usd_jpy_rate"]
        override = os.environ.get(self.rate_env)
        if override:
            try:
                rate = float(override)
            except ValueError:
                raise SystemExit("%s の値が数値ではありません: %r" % (self.rate_env, override))
        self.jpy_rate = float(rate)
        # 最長一致の前方一致にするため、鍵を長い順に見る（表の並び順に依存させない）
        self._keys = sorted(self.models, key=len, reverse=True)

    @classmethod
    def load(cls, path: str) -> "Pricing":
        with open(path, encoding="utf-8") as fh:
            return cls(json.load(fh))

    def find(self, model: str):
        name = model or ""
        for key in self._keys:
            if name.startswith(key):
                return self.models[key]
        return None

    def cost(self, fact: dict):
        """(USD, 単価が引けたか) を返す。引けなければ 0 円だが、呼び出し側が別立てにする。"""
        price = self.find(fact["model"])
        if price is None:
            return 0.0, False
        total = 0.0
        for token_field, price_field in zip(TOKEN_FIELDS, PRICE_FIELDS):
            total += fact[token_field] * float(price[price_field])
        return total / 1e6, True

    def yen(self, usd: float) -> float:
        return usd * self.jpy_rate


# --------------------------------------------------------------------------
# リポジトリ識別子
# --------------------------------------------------------------------------

# Claude Code が作業ツリーを置く場所。この並びの下にあるのは、手前のリポジトリの作業ツリー
WORKTREES_MARK = "/.claude/worktrees/"


class RepoResolver:
    """cwd からリポジトリ識別子（git-common-dir の絶対パス）と表示名を求める。

    識別子に絶対パスを採るのは、ネットワークにも remote の有無にも依存せず、worktree
    と親リポジトリが同じ値に畳まれるから。``owner/repo`` の表示名は origin の URL から
    引き、remote が無ければリポジトリのディレクトリ名に落とす（表示のためだけに使う）。
    """

    def __init__(self):
        self._ids: dict[str, str] = {}
        self._labels: dict[str, str] = {}
        self._inferred: set[str] = set()   # 削除済みで、パスからの推定で決めた cwd
        self._places: dict[str, str] = {}  # 置き場ごとの判定結果

    def repo_id(self, cwd: str) -> str:
        if not cwd:
            return UNKNOWN_REPO
        if cwd in self._ids:
            return self._ids[cwd]
        if os.path.isdir(cwd):
            # 存在するのに git が失敗する cwd は推定しない（不明のまま）
            repo_id = self._git_id(cwd)
        else:
            repo_id = self._infer(cwd)
            if repo_id != UNKNOWN_REPO:
                self._inferred.add(cwd)
        self._ids[cwd] = repo_id
        return repo_id

    def inferred(self, cwd: str) -> bool:
        """``repo_id(cwd)`` が、削除済みの cwd の文字列からの推定で決めた値か。"""
        return cwd in self._inferred

    @staticmethod
    def _git_id(where: str) -> str:
        out = _git(where, "rev-parse", "--path-format=absolute", "--git-common-dir")
        return os.path.realpath(out) if out else UNKNOWN_REPO

    @staticmethod
    def _linked_id(child: str) -> str:
        """リンクされた作業ツリー ``child`` の識別子を、git を起動せず ``.git`` ファイルから読む。

        ``.git`` ファイルの ``gitdir: <パス>`` が指すディレクトリに ``commondir`` があれば、それを
        ``<パス>`` からの相対として解決したものが、無ければ ``<パス>`` そのものが共通の git
        ディレクトリで、``_git_id()`` が ``git rev-parse --git-common-dir`` から決める値と同じ
        文字列になる。置き場の子の数だけ git を起動すると Stop hook が 1 秒を超えうるので
        （実測）、ここでは起動しない。読めない・``gitdir:`` の行が無い・指す先が無いときは不明。
        """
        try:
            with open(os.path.join(child, ".git"), encoding="utf-8", errors="replace") as fh:
                head = fh.read(4096)
        except OSError:
            return UNKNOWN_REPO
        gitdir = ""
        for line in head.splitlines():
            if line.startswith("gitdir:"):
                gitdir = line[len("gitdir:"):].strip()
                break
        if not gitdir:
            return UNKNOWN_REPO
        gitdir = os.path.join(child, gitdir)  # 相対なら作業ツリーから。絶対ならそのまま
        if not os.path.isdir(gitdir):
            return UNKNOWN_REPO
        common = gitdir
        try:
            with open(os.path.join(gitdir, "commondir"), encoding="utf-8", errors="replace") as fh:
                rel = fh.read(4096).strip()
            if rel:
                common = os.path.join(gitdir, rel)
        except OSError:
            pass
        if not os.path.isdir(common):
            return UNKNOWN_REPO
        return os.path.realpath(common)

    def _infer(self, cwd: str) -> str:
        """ディレクトリとして存在しない cwd の文字列からリポジトリを推定する（決まらなければ不明）。

        (1) ``/.claude/worktrees/`` を含むなら、最後のその並びの手前を持ち主とする。その下に
        置かれるのは手前のリポジトリの作業ツリーだと決まっているので、持ち主の識別子をそのまま
        使う（持ち主も削除済みなら、持ち主のパスを同じ手順で推定する）。(2) それ以外は、現存する
        最も近い祖先を置き場として ``_place_id()`` で決める。
        """
        if not os.path.isabs(cwd):
            return UNKNOWN_REPO
        at = cwd.rfind(WORKTREES_MARK)
        if at >= 0:
            # 持ち主は cwd より必ず短いので、持ち主も削除済みで推定を繰り返しても止まる
            return self.repo_id(cwd[:at])
        place = os.path.dirname(cwd.rstrip(os.sep))
        while place and not os.path.isdir(place):
            parent = os.path.dirname(place)
            if parent == place:
                return UNKNOWN_REPO
            place = parent
        if not place:
            return UNKNOWN_REPO
        if place not in self._places:
            self._places[place] = self._place_id(place)
        return self._places[place]

    def _place_id(self, place: str) -> str:
        """置き場（削除済みの cwd の、現存する最も近い祖先）の直下の作業ツリーからリポジトリを決める。

        決めるのは、直下のリンクされた作業ツリー（``.git`` がファイルのディレクトリ）の識別子
        （``_linked_id()`` がファイルから読む。読めない子は除く）がちょうど 1 種類で、置き場の名前がそのリポジトリのメインの作業ツリーのディレクトリ名
        （bare なら識別子のパスの末尾の名前）か origin のリポジトリ名と一致するときだけ。
        名前の一致を求めるのは、複数のリポジトリの作業ツリーを混ぜて置くディレクトリで、たまたま
        残っている 1 つに寄せないため。置き場が git リポジトリの中のときは決めない（消えたのが
        入れ子の別リポジトリだった場合に、外側のリポジトリへ寄せないため）。
        """
        if os.path.dirname(place) == place or self._git_id(place) != UNKNOWN_REPO:
            return UNKNOWN_REPO
        try:
            names = sorted(os.listdir(place))
        except OSError:
            return UNKNOWN_REPO
        found = None
        for name in names:
            child = os.path.join(place, name)
            if not os.path.isfile(os.path.join(child, ".git")):
                continue
            # 子ごとに git を起動しない。.git ファイルを解決できない子（指す先の無い残骸など）は
            # 数えず、残りの子で判定する
            repo_id = self._linked_id(child)
            if repo_id == UNKNOWN_REPO:
                continue
            if found is not None and repo_id != found:
                return UNKNOWN_REPO
            found = repo_id
        if found is None:
            return UNKNOWN_REPO
        root = os.path.dirname(found) if os.path.basename(found) == ".git" else found
        # label() は origin が読めれば owner/repo、読めなければディレクトリ名を返す
        if os.path.basename(place) in (os.path.basename(root), self.label(found).rsplit("/", 1)[-1]):
            return found
        return UNKNOWN_REPO

    def label(self, repo_id: str) -> str:
        if repo_id == UNKNOWN_REPO:
            return UNKNOWN_REPO
        if repo_id in self._labels:
            return self._labels[repo_id]
        root = os.path.dirname(repo_id) if os.path.basename(repo_id) == ".git" else repo_id
        label = os.path.basename(root) or repo_id
        url = _git(root, "remote", "get-url", "origin")
        if url:
            matched = re.search(r"[:/]([^/:]+)/([^/]+?)(?:\.git)?/?$", url)
            if matched:
                label = "%s/%s" % (matched.group(1), matched.group(2))
        self._labels[repo_id] = label
        return label

    def origin(self, repo_id: str):
        """origin の URL を ``(ホスト, "owner/repo")`` にする。読めなければ None。

        ``label()`` は表示用にホストを捨てるので、書き込み先との照合にはこちらを使う。
        扱う形は ``https://host/o/r(.git)``・``git@host:o/r(.git)``・``ssh://git@host[:port]/o/r(.git)``。
        """
        if repo_id == UNKNOWN_REPO:
            return None
        root = os.path.dirname(repo_id) if os.path.basename(repo_id) == ".git" else repo_id
        url = _git(root, "remote", "get-url", "origin") or ""
        matched = (
            re.fullmatch(r"(?:https?|ssh)://(?:[^@/]+@)?([^/:]+)(?::[0-9]+)?/([^/]+)/([^/]+?)(?:\.git)?/?", url)
            or re.fullmatch(r"[^@/:]+@([^/:]+):/?([^/]+)/([^/]+?)(?:\.git)?/?", url)
        )
        if not matched:
            return None
        return matched.group(1).lower(), "%s/%s" % (matched.group(2), matched.group(3))


def _gh(cwd: str, *args: str):
    """gh を叩いて標準出力を返す（失敗と空出力は None）。"""
    try:
        done = subprocess.run(
            ["gh", *args], cwd=cwd or None, capture_output=True, text=True, timeout=30
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if done.returncode != 0:
        return None
    return done.stdout.strip() or None


# issue の問い合わせから番号と子 issue の数を 1 回で取り出す（値が無い・読めないときは 0）
ISSUE_JQ = r'"\(.number) \((.sub_issues_summary.total)? // 0)"'


def resolve_number(where: str, number: str):
    """番号が PR か issue かを GitHub に問い合わせ、``("pr", ヘッドブランチ, 0)`` /
    ``("issue", 番号, 子 issue の数)`` / ``(None, None, 0)`` を返す。

    子 issue の数は、issue の問い合わせの応答の ``sub_issues_summary.total``（同じ呼び出しの
    jq で番号と一緒に取り出すので、``gh`` の回数は増えない）。応答に無い・整数として読めない
    ときは 0（子を持たない issue として扱う）。

    問い合わせは REST（``gh api``）だけを使う。GraphQL 経路（``gh pr view --json`` 等）は
    Projects classic の廃止に伴うエラーで落ちるリポジトリがあり、番号の判別という
    コスト計算の入口がそれで止まるのは割に合わない。

    PR を先に見る。``/issues/<番号>`` は PR も返すため、順序を逆にすると PR 番号が
    issue と判定されてブランチ経路に入らない。
    """
    head = _gh(where, "api", "repos/{owner}/{repo}/pulls/%s" % number, "--jq", ".head.ref")
    if head:
        return "pr", head, 0
    found = _gh(where, "api", "repos/{owner}/{repo}/issues/%s" % number, "--jq", ISSUE_JQ)
    parts = (found or "").split()
    if parts:
        children = 0
        if len(parts) == 2 and re.fullmatch(r"[0-9]+", parts[1]):
            children = int(parts[1])
        return "issue", parts[0], children
    return None, None, 0


class EpicError(Exception):
    """子 issue の木を読み切れなかった（一部しか読めていない額を合計にしないために止める）。"""


# 子 issue を辿る深さの上限（エピックから数えた段数。GitHub が許す入れ子の上限と同じ）
EPIC_MAX_DEPTH = 8

_CLOSING_FIELDS = (
    "closedByPullRequestsReferences(first: 100) {"
    " nodes { number headRefName isCrossRepository baseRepository { nameWithOwner } }"
    " pageInfo { hasNextPage } }"
)
# ある issue の子と、子ごとの閉じた PR を 1 回で取る。owner・name・number は変数で渡し、
# 問い合わせの文字列に埋め込まない
SUB_ISSUES_QUERY = (
    "query($owner: String!, $name: String!, $number: Int!) {"
    " repository(owner: $owner, name: $name) { nameWithOwner issue(number: $number) {"
    " number title state " + _CLOSING_FIELDS +
    " subIssues(first: 100) {"
    " nodes { number title state repository { nameWithOwner } subIssuesSummary { total } "
    + _CLOSING_FIELDS + " }"
    " pageInfo { hasNextPage } } } } }"
)


def _closing_refs(refs, repo: str, number: int):
    """``closedByPullRequestsReferences`` から、数える PR の ``[(番号, ヘッドブランチ)]`` を作る。

    数えるのは、ベースが対象のリポジトリ（大文字と小文字は区別しない）で ``isCrossRepository``
    が偽の PR だけ（``gate_report.py`` の ``closing_prs()`` と同じ絞り方）。同じヘッドブランチが
    複数あれば番号のいちばん小さいものだけを残し、番号の昇順に並べる。
    """
    if not isinstance(refs, dict) or not isinstance(refs.get("pageInfo"), dict):
        raise EpicError("issue #%d を閉じた PR の一覧が期待する形ではありません" % number)
    if refs["pageInfo"].get("hasNextPage") is not False:
        raise EpicError("issue #%d を閉じた PR が 100 件を超えています" % number)
    nodes = refs.get("nodes")
    if not isinstance(nodes, list):
        raise EpicError("issue #%d を閉じた PR の一覧が期待する形ではありません" % number)
    by_branch = {}
    for node in nodes:
        base = node.get("baseRepository") if isinstance(node, dict) else None
        base = base.get("nameWithOwner") if isinstance(base, dict) else None
        pr = node.get("number") if isinstance(node, dict) else None
        head = node.get("headRefName") if isinstance(node, dict) else None
        cross = node.get("isCrossRepository") if isinstance(node, dict) else None
        if (type(pr) is not int or pr < 1 or not isinstance(head, str) or not head
                or not isinstance(cross, bool) or not isinstance(base, str)):
            raise EpicError("issue #%d を閉じた PR の応答に、形の崩れた項目があります" % number)
        if cross or base.lower() != repo.lower():
            continue
        if head not in by_branch or pr < by_branch[head]:
            by_branch[head] = pr
    return sorted((pr, head) for head, pr in by_branch.items())


# ある issue を閉じた PR だけを取る（子 issue は辿らない）。変数は問い合わせの文字列に埋め込まない
CLOSING_ONLY_QUERY = (
    "query($owner: String!, $name: String!, $number: Int!) {"
    " repository(owner: $owner, name: $name) { nameWithOwner issue(number: $number) { "
    + _CLOSING_FIELDS + " } } }"
)


def fetch_closing_prs(where: str, number: int):
    """issue を閉じた PR のうち数えるものの ``[(番号, ヘッドブランチ)]``。``gh api graphql`` を 1 回呼ぶ。

    読めなかった（失敗・JSON でない・形の崩れ・100 件超）ときは None。0 件は空の配列。
    """
    raw = _gh(where, "api", "graphql", "-f", "query=" + CLOSING_ONLY_QUERY,
              "-F", "owner={owner}", "-F", "name={repo}", "-F", "number=%d" % number)
    if raw is None:
        return None
    try:
        repository = json.loads(raw)["data"]["repository"]
        repo, issue = repository["nameWithOwner"], repository["issue"]
        if not isinstance(repo, str) or not repo:
            return None
        return _closing_refs(issue["closedByPullRequestsReferences"], repo, number)
    except (ValueError, KeyError, TypeError, EpicError):
        return None


def _issue_fields(node, number: int):
    """応答の issue 1 件から ``(番号, 題名, 状態)`` を取り出す（状態は ``open`` / ``closed``）。"""
    if not isinstance(node, dict):
        raise EpicError("issue #%d の子 issue の応答に、形の崩れた項目があります" % number)
    found, title, state = node.get("number"), node.get("title"), node.get("state")
    if (type(found) is not int or found < 1 or not isinstance(title, str)
            or state not in ("OPEN", "CLOSED")):
        raise EpicError("issue #%d の子 issue の応答に、形の崩れた項目があります" % number)
    return found, title, state.lower()


def fetch_epic_tree(where: str, number: int):
    """エピックと子孫の issue を辿り、``(対象の issue の一覧, 数えなかった子の一覧)`` を返す。

    対象の issue は表示の順（エピック自身、あとは GitHub が返した子の順で、子を持つ issue の
    直後にその子）。1 件は ``number``・``parent``・``depth``・``title``・``state``・``prs``
    （数える PR の ``[(番号, ヘッドブランチ)]``）。``gh api graphql`` は、子を持つ issue 1 件に
    つき 1 回だけ呼ぶ。一度出た番号と別のリポジトリの子は数えず辿らない。読み切れなければ
    EpicError（呼ぶ側が標準出力に何も書かずに終了コード 2 を返す）。
    """
    issues, skipped, seen = [], [], {number}
    state = {"repo": None}

    def query(target: int):
        raw = _gh(where, "api", "graphql", "-f", "query=" + SUB_ISSUES_QUERY,
                  "-F", "owner={owner}", "-F", "name={repo}", "-F", "number=%d" % target)
        if raw is None:
            raise EpicError("issue #%d の子 issue の問い合わせ（gh api graphql）が失敗しました" % target)
        try:
            repository = json.loads(raw)["data"]["repository"]
            repo, issue = repository["nameWithOwner"], repository["issue"]
            subs = issue["subIssues"]
            nodes, more = subs["nodes"], subs["pageInfo"]["hasNextPage"]
        except (ValueError, KeyError, TypeError):
            raise EpicError("issue #%d の子 issue の応答が期待する形ではありません" % target)
        if not isinstance(repo, str) or not repo or not isinstance(nodes, list):
            raise EpicError("issue #%d の子 issue の応答が期待する形ではありません" % target)
        if more is not False:
            raise EpicError("issue #%d の子 issue が 100 件を超えています" % target)
        if state["repo"] is None:
            state["repo"] = repo
        return issue, nodes

    def walk(target: int, depth: int, known):
        issue, nodes = query(target)
        if known is None:
            _found, title, status = _issue_fields(issue, target)
            issues.append({"number": target, "parent": None, "depth": 0, "title": title,
                           "state": status,
                           "prs": _closing_refs(issue.get("closedByPullRequestsReferences"),
                                                state["repo"], target)})
        for node in nodes:
            child, title, status = _issue_fields(node, target)
            owner = node.get("repository")
            owner = owner.get("nameWithOwner") if isinstance(owner, dict) else None
            summary = node.get("subIssuesSummary")
            total = summary.get("total") if isinstance(summary, dict) else None
            if not isinstance(owner, str) or not owner or type(total) is not int or total < 0:
                raise EpicError("issue #%d の子 issue #%d の応答が期待する形ではありません"
                                % (target, child))
            if owner.lower() != state["repo"].lower():
                skipped.append({"repo": owner, "number": child, "parent": target})
                continue
            if child in seen:
                continue
            seen.add(child)
            issues.append({"number": child, "parent": target, "depth": depth + 1, "title": title,
                           "state": status,
                           "prs": _closing_refs(node.get("closedByPullRequestsReferences"),
                                                state["repo"], child)})
            if total > 0:
                if depth + 1 >= EPIC_MAX_DEPTH:
                    raise EpicError("issue #%d は %d 段より深い子 issue を持っています"
                                    % (child, EPIC_MAX_DEPTH))
                walk(child, depth + 1, True)

    walk(number, 0, None)
    return issues, skipped


def current_branch(where: str):
    name = _git(where, "rev-parse", "--abbrev-ref", "HEAD")
    return None if name in (None, "HEAD") else name


def _git(cwd: str, *args: str):
    try:
        done = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=15
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if done.returncode != 0:
        return None
    return done.stdout.strip() or None


# --------------------------------------------------------------------------
# 事実の抽出（1 パス）
# --------------------------------------------------------------------------

def log_root() -> str:
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    return os.path.join(base, "projects")


def session_cost_dir() -> str:
    """statusline が本体のセッションコストを書き残す場所（会話ログと同じ設定ディレクトリ）。"""
    return os.path.join(os.path.dirname(log_root()), ".session-cost")


def read_session_cost(session_id: str):
    """1 セッション分の記録を (t0, v0, t1, v1) で返す。突き合わせの対象外なら None。

    記録は ``1 <t0> <v0> <t1> <v1>`` の 1 行（t は epoch 秒、v は本体の値）。形が違う・
    読めない・観測が 1 回だけ（t1 が t0 と同じで増分を持たない）は対象外にする。
    """
    if not isinstance(session_id, str) or not SESSION_ID_RE.fullmatch(session_id):
        return None
    try:
        with open(os.path.join(session_cost_dir(), session_id), encoding="utf-8") as handle:
            text = handle.read(4096)
    except (OSError, ValueError):
        return None
    fields = text.split()
    if len(fields) != 5 or fields[0] != "1":
        return None
    if not (fields[1].isascii() and fields[1].isdigit() and fields[3].isascii() and fields[3].isdigit()):
        return None
    if not (RECORD_NUMBER_RE.fullmatch(fields[2]) and RECORD_NUMBER_RE.fullmatch(fields[4])):
        return None
    try:
        t0, t1 = int(fields[1]), int(fields[3])
        v0, v1 = float(fields[2]), float(fields[4])
    except (ValueError, OverflowError):
        return None
    if t1 == t0:
        return None
    return t0, v0, t1, v1


def drift_budget() -> float:
    """読み直しの上限の秒数。未設定・数として読めない値・負の値は既定に倒す。"""
    raw = os.environ.get(DRIFT_BUDGET_ENV)
    if raw is None:
        return DRIFT_BUDGET_SECONDS
    try:
        value = float(raw)
    except ValueError:
        return DRIFT_BUDGET_SECONDS
    if value != value or value < 0:
        return DRIFT_BUDGET_SECONDS
    return value


def scan_tool_calls(message: dict):
    """その行が**実行した** Bash コマンドから、触った issue 番号の列と投稿の印を拾う。

    見るのは ``Bash`` ツールの ``command`` フィールドだけ。ツール入力全体を文字列に
    して当てると、サブエージェントへの指示文やファイル編集の中身に書かれた
    ``gh issue view <番号>`` という**文字列**にも反応し、実行していない issue へ
    コストが帰属する。実際に実行された ``gh`` は必ずここを通る。
    """
    issues: list[str] = []
    marker = None
    for block in message.get("content") or []:
        if not isinstance(block, dict) or block.get("type") != "tool_use":
            continue
        if block.get("name") != "Bash":
            continue
        payload = block.get("input")
        if not isinstance(payload, dict):
            continue
        command = payload.get("command")
        if not isinstance(command, str):
            continue
        for number in ISSUE_RE.findall(command):
            if number not in issues:
                issues.append(number)
        if marker is None:
            for pattern in POST_MARKERS:
                if pattern in command:
                    marker = pattern
                    break
    return issues, marker


def build_fact(record: dict, resolver: RepoResolver, path: str) -> dict:
    message = record.get("message") or {}
    usage = message.get("usage") or {}
    created = usage.get("cache_creation") or {}
    write_5m = created.get("ephemeral_5m_input_tokens") or 0
    write_1h = created.get("ephemeral_1h_input_tokens") or 0
    if not (write_5m or write_1h):
        # 内訳を持たない古い形の行。キャッシュ書込 5m として読む。
        write_5m = usage.get("cache_creation_input_tokens") or 0
    issues, marker = scan_tool_calls(message)
    cwd = record.get("cwd") or ""
    fact = {
        "request_id": record.get("requestId") or record.get("uuid") or "",
        # 先頭の行の uuid。複製された会話ログの先頭の行と、真の後続行を区別する鍵
        "uuid": record["uuid"] if isinstance(record.get("uuid"), str) else "",
        "timestamp": record.get("timestamp") or "",
        # sessionId が無い行は区間を切る単位が消える。ファイルパスに落として混ざるのを防ぐ。
        "session_id": record.get("sessionId") or path,
        "is_sidechain": bool(record.get("isSidechain")),
        "repo_id": resolver.repo_id(cwd),
        "branch": record.get("gitBranch") or "",
        "model": message.get("model") or "",
        "input_tokens": usage.get("input_tokens") or 0,
        "output_tokens": usage.get("output_tokens") or 0,
        "cache_write_5m_tokens": write_5m,
        "cache_write_1h_tokens": write_1h,
        "cache_read_tokens": usage.get("cache_read_input_tokens") or 0,
        "issues": issues,
        "post_marker": marker,
    }
    if resolver.inferred(cwd):
        # 削除済みの cwd の文字列から推定した識別子。偽のときは欄そのものを書かない
        # （git で決まった行と、この欄ができる前に書かれた行の形を変えないため）
        fact["repo_inferred"] = True
    return fact


def log_files(root: str):
    """会話ログのファイルを決まった順で返す（ディレクトリ内はファイル名順）。"""
    for dirpath, dirs, filenames in os.walk(root):
        dirs.sort()
        for name in sorted(filenames):
            if name.endswith(".jsonl"):
                yield os.path.join(dirpath, name)


TOKEN_KEYS = ("input_tokens", "output_tokens", "cache_write_5m_tokens",
              "cache_write_1h_tokens", "cache_read_tokens")


class SeenSet:
    """読んだ requestId の集合と、その応答の先頭の行の uuid（会話ログの直読み用）。"""

    def __init__(self):
        self.ids: set[str] = set()
        self.heads: dict[str, str] = {}
        self.counts: dict[str, int] = {}

    def __contains__(self, request_id) -> bool:
        return request_id in self.ids

    def add(self, request_id) -> None:
        self.ids.add(request_id)

    def add_head(self, request_id, uuid: str, output: int = 0) -> None:
        self.ids.add(request_id)
        self.heads[request_id] = uuid
        self.counts[request_id] = output

    def head_uuid(self, request_id):
        return self.heads.get(request_id)

    def counted_output(self, request_id) -> int:
        return self.counts.get(request_id, 0)

    def bump_output(self, request_id, delta: int) -> None:
        self.counts[request_id] = self.counts.get(request_id, 0) + delta


def _head_uuid(seen, request_id):
    lookup = getattr(seen, "head_uuid", None)
    return lookup(request_id) if lookup else None


def _add_head(seen, request_id, uuid: str, output: int = 0) -> None:
    add_head = getattr(seen, "add_head", None)
    if add_head:
        add_head(request_id, uuid, output)
    else:
        seen.add(request_id)


def _counted_output(seen, request_id) -> int:
    """この応答について、台帳（または同じ読み取りの中）に既に数えた出力トークン。"""
    lookup = getattr(seen, "counted_output", None)
    return lookup(request_id) if lookup else 0


def _bump_output(seen, request_id, delta: int) -> None:
    bump = getattr(seen, "bump_output", None)
    if bump and delta:
        bump(request_id, delta)


def final_output(message: dict):
    """確定行（``stop_reason`` が空でない文字列の行）なら出力トークン、そうでなければ None。"""
    stop = message.get("stop_reason")
    if not isinstance(stop, str) or not stop:
        return None
    out = (message.get("usage") or {}).get("output_tokens")
    if isinstance(out, bool) or not isinstance(out, int):
        return None
    return out


class PositionedLines:
    """バイト列の行を文字列にして返しつつ、いま返した行の行頭のバイト位置を ``position`` に持つ。

    位置はデコード・行の絞り込みより前の生バイトから数える（日本語・不正な UTF-8・CRLF でも
    ずれない）。行は ``\\n`` だけで区切る。``base`` は最初の行の位置（途中から読むとき用）。
    間に ``_drift_lines`` のような絞り込みを挟んでも、行を返した直後の ``position`` はその行の位置。
    """

    def __init__(self, raw_lines, base: int = 0):
        self._raw = raw_lines
        self._base = base
        self.position = base

    def __iter__(self):
        position = self._base
        for raw in self._raw:
            self.position = position
            position += len(raw)
            yield raw.decode("utf-8", errors="replace")


def facts_from_lines(lines, path: str, resolver: RepoResolver, seen, branch: str | None = None,
                     from_start: bool = True, offset_of=None):
    """会話ログの行の列から事実を返す。``seen`` に入っている requestId は先頭の行として扱わない。

    ``seen`` は ``SeenSet`` か、同じメソッドを持つもの（台帳の索引を包んだ ``_Seen``）を渡す。
    先頭の行の uuid を持てる ``seen``（``add_head`` / ``head_uuid``）なら、複製された先頭の行を
    後続行と取り違えない。確定行の出力の差分を正しく出すには、数えた出力を覚える
    ``counted_output`` / ``bump_output`` が要る（素の ``set`` を渡すと数えた出力が常に 0 になり、
    確定行の値がそのまま足されて二重に数える）。requestId も uuid も無い行は空文字を鍵にする。

    1 つの応答が複数の行に分かれるとき、そのファイルで最初に現れる行が先頭の行で、通常の事実を
    1 つ出す。それ以降の行（後続行）は、実行した Bash が issue 番号か投稿の印を持つとき、または
    確定行（``stop_reason`` が付く行）の出力がそれまでに数えた出力より大きいときだけ、入力・
    キャッシュ 0 で出力がその差分（差分が無ければ 0）の補足の事実を ``<requestId>#<uuid>`` の
    鍵で出す。``from_start`` は、この呼び出しが
    ファイルの先頭から読んでいるか（uuid を持たない古い台帳の行の先頭の行を見分けるのに使う）。
    ``offset_of`` は、いま読んでいる行の元ログ内の行頭バイト位置を返す関数（``PositionedLines.position``
    を返す形）。渡されたとき、補足の事実に ``source_offset`` として保存し、同時刻の後続行の
    順序に使う。
    """
    first_seen: dict[str, str] = {}  # この呼び出しで最初に見た行の uuid（先頭の行の uuid）
    for line in lines:
        # パースの前に生の文字列で弾く（全履歴 1 パスの速度はここに依存する）
        if '"assistant"' not in line:
            continue
        if branch is not None and branch not in line:
            continue
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if not isinstance(record, dict):
            SCAN_STATS["unreadable_lines"] += 1
            continue
        if record.get("type") != "assistant":
            continue
        if branch is not None and (record.get("gitBranch") or "") != branch:
            continue
        request_id = record.get("requestId") or record.get("uuid") or ""
        if not isinstance(request_id, str):
            SCAN_STATS["unreadable_lines"] += 1
            continue
        uuid = record["uuid"] if isinstance(record.get("uuid"), str) else ""
        if request_id not in first_seen and request_id not in seen:
            try:
                fact = build_fact(record, resolver, path)
            except (AttributeError, TypeError, ValueError):
                # 有効な JSON だが期待する形でない行。ここで落とすと 1 行の不正で
                # 全履歴の集計が終わらなくなる（cwd 削除済みの行と同じ方針）。
                SCAN_STATS["unreadable_lines"] += 1
                continue
            first_seen[request_id] = uuid
            _add_head(seen, request_id, uuid, fact["output_tokens"])
            yield fact
            continue
        if request_id not in first_seen:
            # 前の回・別のファイルで先頭の行を読んだ応答の、この呼び出しで最初の行
            head = _head_uuid(seen, request_id)
            if head is None:
                if not from_start:
                    continue  # 先頭の行の uuid を知らない古い行。--rescan 以外では扱わない
                first_seen[request_id] = uuid  # このファイルで最初の行を先頭の行として捨てる
                continue
            first_seen[request_id] = head
        if uuid == first_seen[request_id] or not uuid:
            continue
        if '"Bash"' not in line and '"stop_reason":"' not in line and '"stop_reason": "' not in line:
            continue
        key = "%s#%s" % (request_id, uuid)
        if key in seen:
            continue
        try:
            message = record.get("message") or {}
            issues, marker = scan_tool_calls(message)
            final = final_output(message)
            delta = max(0, final - _counted_output(seen, request_id)) if final is not None else 0
            if not issues and marker is None and not delta:
                continue
            fact = build_fact(record, resolver, path)
        except (AttributeError, TypeError, ValueError):
            SCAN_STATS["unreadable_lines"] += 1
            continue
        fact["request_id"] = key
        for field in TOKEN_KEYS:
            fact[field] = 0
        fact["output_tokens"] = delta
        _bump_output(seen, request_id, delta)
        fact["continuation"] = True
        if offset_of is not None:
            fact["source_offset"] = offset_of()
        seen.add(key)
        yield fact


def is_continuation(fact: dict) -> bool:
    """同じ応答の後続行から出した補足の事実か（入力・キャッシュは 0、出力は確定値との差分。メッセージ数に数えない）。"""
    return bool(fact.get("continuation"))


def iter_facts(root: str, resolver: RepoResolver, branch: str | None = None):
    """会話ログを 1 パスで読み、requestId で重複を排除しながら事実を返す。"""
    seen = SeenSet()
    for path in log_files(root):
        try:
            handle = open(path, "rb")
        except OSError:
            continue
        with handle:
            lines = PositionedLines(handle)
            yield from facts_from_lines(lines, path, resolver, seen, branch,
                                        offset_of=lambda: lines.position)


# --------------------------------------------------------------------------
# 台帳（会話ログが消えたあとも残す append-only の JSONL）
# --------------------------------------------------------------------------

# 台帳の場所を決める唯一の入口。既定のパスは持たない（個人のディレクトリ構成を
# リポジトリに残さないため。LLM_LOG_DIR と同じ扱い）。
LEDGER_ENV = "COST_LEDGER_PATH"
# plugin.json の userConfig（LEDGER_PATH）の値。プラグインを有効にするときと /config で設定され、
# hook のプロセスにこの名前の環境変数で渡る。設定されていれば LEDGER_ENV より優先する。
LEDGER_OPTION_ENV = "CLAUDE_PLUGIN_OPTION_LEDGER_PATH"

# 台帳の 1 行は build_fact の辞書をそのまま dumps したもので、先頭の鍵が request_id。
# 索引を作るとき、この接頭辞なら JSON をパースせずに requestId を取り出せる。
LEDGER_ID_PREFIX = '{"request_id": "'


LEDGER_UUID_PREFIX = '", "uuid": "'


def _ledger_id_uuid(line: str):
    """台帳の 1 行から (requestId, 先頭の行の uuid) を取り出す。uuid の欄が無ければ uuid は None。"""
    if line.startswith(LEDGER_ID_PREFIX):
        rest = line[len(LEDGER_ID_PREFIX):]
        end = rest.find('"')
        if end >= 0 and "\\" not in rest[:end]:
            tail = rest[end:]
            if tail.startswith(LEDGER_UUID_PREFIX):
                body = tail[len(LEDGER_UUID_PREFIX):]
                stop = body.find('"')
                if stop >= 0 and "\\" not in body[:stop]:
                    return rest[:end], body[:stop]
            elif not tail.startswith('", "uuid"'):
                return rest[:end], None
    try:
        record = json.loads(line)
    except ValueError:
        return None, None
    if isinstance(record, dict) and isinstance(record.get("request_id"), str):
        uuid = record.get("uuid")
        return record["request_id"], uuid if isinstance(uuid, str) else None
    return None, None


OUTPUT_KEY = '"output_tokens": '


def _ledger_output(line: str, request_id: str) -> int:
    """台帳の 1 行の出力トークン。値の前の欄は文字列のエスケープ済みの値だけなので、最初の一致が欄そのもの。"""
    at = line.find(OUTPUT_KEY)
    if at >= 0:
        digits = line[at + len(OUTPUT_KEY):at + len(OUTPUT_KEY) + 20]
        end = 0
        while end < len(digits) and digits[end].isdigit():
            end += 1
        if end:
            return int(digits[:end])
    try:
        value = json.loads(line).get("output_tokens")
    except (ValueError, AttributeError):
        return 0
    return value if isinstance(value, int) and not isinstance(value, bool) else 0


class LedgerError(Exception):
    """台帳を使えない（場所が不正・読み書きできない）。終了コード 2 で利用者に伝える。"""


def ledger_path():
    option = os.environ.get(LEDGER_OPTION_ENV, "")
    # userConfig が未設定のとき、/cost の本文は置換されなかった文字列 ${user_config.LEDGER_PATH}
    # をそのまま渡してくる。空文字と同じ未設定として扱い、COST_LEDGER_PATH に落とす。
    if option.startswith("${user_config."):
        option = ""
    return option or os.environ.get(LEDGER_ENV) or None


def protected_root() -> str:
    """台帳を置いてはいけない場所。このスクリプトを含むリポジトリ（無ければプラグイン）。"""
    plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    top = _git(plugin_root, "rev-parse", "--show-toplevel")
    return os.path.realpath(top or plugin_root)


def resolve_ledger(path: str) -> str:
    """台帳の実パスを返す。リポジトリ配下を指していれば LedgerError。"""
    real = os.path.realpath(os.path.abspath(os.path.expanduser(path)))
    root = protected_root()
    if real == root or real.startswith(root + os.sep):
        raise LedgerError(
            "%s が指す台帳 %s はプラグインのリポジトリ（%s）の配下です。"
            "自動更新や再 clone で消えるので、リポジトリの外を指してください。"
            % (LEDGER_ENV, real, root)
        )
    return real


def _ledger_id(line: str):
    """台帳の 1 行から requestId を取り出す（取れなければ None）。"""
    if line.startswith(LEDGER_ID_PREFIX):
        rest = line[len(LEDGER_ID_PREFIX):]
        end = rest.find('"')
        if end >= 0 and "\\" not in rest[:end]:
            return rest[:end]
    try:
        record = json.loads(line)
    except ValueError:
        return None
    if isinstance(record, dict) and isinstance(record.get("request_id"), str):
        return record["request_id"]
    return None


class LedgerIndex:
    """台帳に書いた requestId の索引と、会話ログごとの読み終え位置（控え）。

    索引は台帳の先頭からの写しで、``covered``（台帳の何バイト目まで反映したか）を持つ。
    台帳が伸びていれば差分だけを足し、縮んでいれば作り直す。控えが壊れていれば捨てて
    作り直す。正しさは台帳が持ち、ここは速さのためだけにある。
    """

    def __init__(self, path: str):
        self.path = path
        try:
            self.db = self._open()
        except sqlite3.DatabaseError:
            for suffix in ("", "-journal", "-wal", "-shm"):
                try:
                    os.remove(path + suffix)
                except OSError:
                    pass
            self.db = self._open()

    def _open(self):
        db = sqlite3.connect(self.path)
        db.execute("CREATE TABLE IF NOT EXISTS ids (id TEXT PRIMARY KEY)")
        db.execute("CREATE TABLE IF NOT EXISTS heads (id TEXT PRIMARY KEY, uuid TEXT)")
        old_form = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='counted'").fetchone() is None
        db.execute("CREATE TABLE IF NOT EXISTS counted (id TEXT PRIMARY KEY, out INTEGER)")
        db.execute("CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY, offset INTEGER, ino INTEGER)")
        db.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER)")
        db.execute("SELECT count(*) FROM meta").fetchone()
        if old_form:
            # 応答ごとの出力を持たない古い形の控え。台帳を先頭から読み直して作り直す。
            db.execute("DELETE FROM counted")
            db.execute("DELETE FROM meta WHERE key = 'covered'")
            db.commit()
        return db

    def covered(self) -> int:
        row = self.db.execute("SELECT value FROM meta WHERE key = 'covered'").fetchone()
        return int(row[0]) if row else 0

    def set_covered(self, size: int) -> None:
        self.db.execute("INSERT OR REPLACE INTO meta (key, value) VALUES ('covered', ?)", (size,))

    def catch_up(self, ledger: str) -> None:
        """台帳の伸びた分を索引に取り込む（台帳が縮んでいれば作り直す）。"""
        try:
            size = os.path.getsize(ledger)
        except OSError:
            size = 0
        start = self.covered()
        if start > size:
            self.db.execute("DELETE FROM ids")
            self.db.execute("DELETE FROM heads")
            self.db.execute("DELETE FROM counted")
            self.db.execute("DELETE FROM files")
            start = 0
        if start < size:
            with open(ledger, "rb") as fh:
                fh.seek(start)
                data = fh.read(size - start)
            ids = []
            heads = []
            counts: dict[str, int] = {}
            for raw in data.split(b"\n"):
                if not raw.strip():
                    continue
                text = raw.decode("utf-8", errors="replace")
                request_id, uuid = _ledger_id_uuid(text)
                if request_id is not None:
                    ids.append((request_id,))
                    if uuid is not None:
                        heads.append((request_id, uuid))
                    base = request_id.split("#", 1)[0]
                    counts[base] = counts.get(base, 0) + _ledger_output(text, request_id)
            self.db.executemany(
                "INSERT INTO counted (id, out) VALUES (?, ?) "
                "ON CONFLICT(id) DO UPDATE SET out = out + excluded.out", list(counts.items()))
            self.db.executemany("INSERT OR IGNORE INTO ids (id) VALUES (?)", ids)
            self.db.executemany("INSERT OR IGNORE INTO heads (id, uuid) VALUES (?, ?)", heads)
        self.set_covered(size)
        self.db.commit()

    def __contains__(self, request_id) -> bool:
        return self.db.execute("SELECT 1 FROM ids WHERE id = ?", (request_id,)).fetchone() is not None

    def head_uuid(self, request_id):
        row = self.db.execute("SELECT uuid FROM heads WHERE id = ?", (request_id,)).fetchone()
        return row[0] if row else None

    def counted_output(self, request_id) -> int:
        row = self.db.execute("SELECT out FROM counted WHERE id = ?", (request_id,)).fetchone()
        return row[0] if row else 0

    def offsets(self) -> dict:
        return {p: (o, i) for p, o, i in self.db.execute("SELECT path, offset, ino FROM files")}


class _Seen:
    """索引とこの回に採った分を合わせた requestId の集合。"""

    def __init__(self, index: LedgerIndex):
        self.index = index
        self.local: set[str] = set()
        self.heads: dict[str, str] = {}
        self.counts: dict[str, int] = {}

    def __contains__(self, request_id) -> bool:
        return request_id in self.local or request_id in self.index

    def add(self, request_id) -> None:
        self.local.add(request_id)

    def add_head(self, request_id, uuid: str, output: int = 0) -> None:
        self.local.add(request_id)
        self.heads[request_id] = uuid
        self.counts[request_id] = output

    def head_uuid(self, request_id):
        if request_id in self.heads:
            return self.heads[request_id]
        return self.index.head_uuid(request_id)

    def counted_output(self, request_id) -> int:
        if request_id in self.counts:
            return self.counts[request_id]
        return self.index.counted_output(request_id)

    def bump_output(self, request_id, delta: int) -> None:
        self.counts[request_id] = self.counted_output(request_id) + delta


def ledger_sync(ledger: str, root: str, resolver: RepoResolver, rescan: bool = False) -> int:
    """会話ログの増えた分を台帳に追記し、追記した行数を返す。

    台帳の隣のロックファイルに排他ロックを取ってから読み書きする（複数セッションの
    Stop hook が同時に走るため）。台帳へ追記してから控えを更新する。
    """
    directory = os.path.dirname(ledger)
    try:
        os.makedirs(directory, exist_ok=True)
        lock = open(ledger + ".lock", "a")
    except OSError as error:
        raise LedgerError("台帳の場所 %s を用意できません: %s" % (ledger, error))
    with lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return _ledger_sync_locked(ledger, root, resolver, rescan)
        except (OSError, sqlite3.Error) as error:
            raise LedgerError("台帳 %s へ追記できません: %s" % (ledger, error))


REPO_FIX_PREFIX = "repo-fix#"
LEDGER_UNKNOWN_REPO = '"repo_id": "%s"' % UNKNOWN_REPO


def _unknown_groups(ledger: str) -> dict:
    """台帳の識別子が不明の行（補正行を除く）を持つ (session_id, branch) と、その組の最も早い timestamp。"""
    groups: dict = {}
    if not os.path.exists(ledger):
        return groups
    with open(ledger, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if LEDGER_UNKNOWN_REPO not in line:
                continue
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if not isinstance(row, dict) or row.get("repo_id") != UNKNOWN_REPO or row.get("repo_fix"):
                continue
            session, branch = row.get("session_id") or "", row.get("branch") or ""
            if not (isinstance(session, str) and isinstance(branch, str)):
                continue
            stamp = row.get("timestamp") if isinstance(row.get("timestamp"), str) else ""
            key = (session, branch)
            if key not in groups or (stamp and (not groups[key] or stamp < groups[key])):
                groups[key] = stamp
    return groups


def _collect_group_cwds(data: bytes, path: str, groups: dict, cwds: dict, no_cwd: set) -> None:
    """会話ログのバイト列の応答の行から、groups の組ごとの cwd と「cwd の無い行がある」ことを集める。

    組の鍵は build_fact と同じ（sessionId が無ければファイルのパス, gitBranch）。
    """
    for raw in data.split(b"\n"):
        if b'"assistant"' not in raw:
            continue
        try:
            record = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(record, dict) or record.get("type") != "assistant":
            continue
        session, branch = record.get("sessionId") or path, record.get("gitBranch") or ""
        if not (isinstance(session, str) and isinstance(branch, str)):
            continue
        key = (session, branch)
        if key not in groups:
            continue
        cwd = record.get("cwd")
        if isinstance(cwd, str) and cwd:
            cwds.setdefault(key, set()).add(cwd)
        else:
            no_cwd.add(key)


def _repo_fix_rows(groups: dict, cwds: dict, no_cwd: set, resolver: RepoResolver, seen) -> list[str]:
    """全 cwd が同じ 1 リポジトリに決まり、cwd の無い応答の行を含まない組の補正行（索引に無いものだけ）。"""
    rows: list[str] = []
    for key in sorted(groups):
        if key in no_cwd or not cwds.get(key):
            continue
        repos = {resolver.repo_id(cwd) for cwd in sorted(cwds[key])}
        if len(repos) != 1 or UNKNOWN_REPO in repos:
            continue
        repo = repos.pop()
        session, branch = key
        request_id = "%s%s#%s#%s" % (REPO_FIX_PREFIX, session, branch, repo)
        if request_id in seen:
            continue
        seen.add(request_id)
        # 補足の事実の形に寄せる（古い版の読み手には、トークン 0・issue なし・印なしの補足に見える）
        rows.append(json.dumps({
            "request_id": request_id,
            "timestamp": groups[key],
            "session_id": session,
            "is_sidechain": False,
            "repo_id": repo,
            "branch": branch,
            "model": "",
            "input_tokens": 0,
            "output_tokens": 0,
            "cache_write_5m_tokens": 0,
            "cache_write_1h_tokens": 0,
            "cache_read_tokens": 0,
            "issues": [],
            "post_marker": None,
            "continuation": True,
            "repo_fix": True,
        }, ensure_ascii=False))
    return rows


def _ledger_sync_locked(ledger: str, root: str, resolver: RepoResolver, rescan: bool = False) -> int:
    index = LedgerIndex(ledger + ".state.sqlite")
    try:
        index.catch_up(ledger)
        previous = index.offsets()
        seen = _Seen(index)
        lines_out: list[str] = []
        new_offsets = []
        # 控えのキーは置き場所を実パスに直した形で持つ（シンボリックリンク経由で同じ置き場所を
        # 指しても、同じ会話ログを別のキーで先頭から読み直さないため）。os.walk は root の
        # 表記のまま返すので、root からの相対パスを実パスの root に付け直す
        real_root = os.path.realpath(root)
        # --rescan のときだけ、台帳の「不明」の行の組と、その組の cwd を集めて補正行を書く
        groups = _unknown_groups(ledger) if rescan else {}
        group_cwds: dict = {}
        no_cwd: set = set()
        for path in log_files(root):
            key = os.path.join(real_root, os.path.relpath(path, root))
            try:
                stat = os.stat(path)
            except OSError:
                continue
            offset, ino = previous.get(key, (0, None))
            if rescan or ino != stat.st_ino or not (0 <= offset <= stat.st_size):
                offset = 0
            if offset == stat.st_size and not rescan:
                new_offsets.append((key, offset, stat.st_ino))
                continue
            try:
                with open(path, "rb") as fh:
                    fh.seek(offset)
                    data = fh.read(stat.st_size - offset)
            except OSError:
                continue
            end = data.rfind(b"\n")
            if end < 0:
                # 書きかけの 1 行だけ。次回に回す
                new_offsets.append((key, offset, stat.st_ino))
                continue
            lines = PositionedLines(io.BytesIO(data[:end + 1]), base=offset)
            for fact in facts_from_lines(lines, path, resolver, seen, from_start=(offset == 0),
                                         offset_of=lambda: lines.position):
                lines_out.append(json.dumps(fact, ensure_ascii=False))
            if groups:
                _collect_group_cwds(data[:end + 1], path, groups, group_cwds, no_cwd)
            new_offsets.append((key, offset + end + 1, stat.st_ino))
        if groups:
            lines_out.extend(_repo_fix_rows(groups, group_cwds, no_cwd, resolver, seen))
        if lines_out:
            prefix = ""
            if os.path.exists(ledger) and os.path.getsize(ledger) > 0:
                with open(ledger, "rb") as fh:
                    fh.seek(-1, os.SEEK_END)
                    if fh.read(1) != b"\n":
                        prefix = "\n"
            with open(ledger, "a", encoding="utf-8") as fh:
                fh.write(prefix + "\n".join(lines_out) + "\n")
                fh.flush()
                os.fsync(fh.fileno())
        # 追記した分を索引に足してから、読み終え位置を差し替える。差し替えるのは今回読んだ
        # 置き場所（root）の配下だけ。CLAUDE_CONFIG_DIR の違うアカウントが同じ台帳を共有しても、
        # 他の置き場所の読み終え位置を消さない（消すと次の hook が全件を読み直す）
        index.catch_up(ledger)
        root_prefix = os.path.join(real_root, "")
        gone = [(p,) for p in previous if p.startswith(root_prefix)]
        index.db.executemany("DELETE FROM files WHERE path = ?", gone)
        index.db.executemany("INSERT OR REPLACE INTO files (path, offset, ino) VALUES (?, ?, ?)", new_offsets)
        index.db.commit()
        return len(lines_out)
    finally:
        index.db.close()


LEDGER_NO_ISSUES = '"issues": []'
LEDGER_SESSION_RE = re.compile(r'"session_id": "([^"\\]*)"')


def _open_ledger(ledger: str):
    try:
        return open(ledger, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return None
    except OSError as error:
        raise LedgerError("台帳 %s を読めません: %s" % (ledger, error))


def _ledger_session(line: str):
    """台帳の 1 行から session_id を取り出す（取れなければ None）。"""
    matched = LEDGER_SESSION_RE.search(line)
    if matched:
        return matched.group(1)
    try:
        record = json.loads(line)
    except ValueError:
        return None
    return record.get("session_id") if isinstance(record, dict) else None


def iter_ledger_issue_facts(ledger: str, issue):
    """台帳のうち、その issue 番号を触った行を持つセッションの事実だけを返す。

    ``issue`` は番号 1 件（文字列）か、番号の集合（エピックの集計が、対象の issue すべての分を
    台帳の同じ 2 回の走査でまとめて読むために渡す。どれかを触ったセッションを返す）。

    区間は ``session_id`` ごとに切るので、その issue を触った行が 1 つも無いセッションは
    issue の集計に関係しない。1 回目の走査で、issue 番号を持つ行（``"issues": []`` でない行）
    だけを JSON として読んでセッションを集め、2 回目でそのセッションの行だけを JSON として
    読む。重複排除（requestId）は全行を読んだ場合と同じ結果にするため、絞る前の全行で行う。
    """
    handle = _open_ledger(ledger)
    if handle is None:
        return
    wanted = {issue} if isinstance(issue, str) else set(issue)
    sessions: set[str] = set()
    with handle:
        for line in handle:
            if LEDGER_NO_ISSUES in line or not line.strip():
                continue
            try:
                fact = json.loads(line)
            except ValueError:
                continue
            if (isinstance(fact, dict) and isinstance(fact.get("issues"), list)
                    and not wanted.isdisjoint(n for n in fact["issues"] if isinstance(n, str))
                    and isinstance(fact.get("session_id"), str)):
                sessions.add(fact["session_id"])
    handle = _open_ledger(ledger)
    if handle is None:
        return
    seen: set[str] = set()
    with handle:
        for line in handle:
            if not line.strip():
                continue
            request_id = _ledger_id(line)
            if request_id is None:
                SCAN_STATS["unreadable_lines"] += 1
                continue
            if request_id in seen:
                continue
            seen.add(request_id)
            if not sessions or _ledger_session(line) not in sessions:
                continue
            try:
                fact = json.loads(line)
            except ValueError:
                SCAN_STATS["unreadable_lines"] += 1
                continue
            if isinstance(fact, dict) and isinstance(fact.get("request_id"), str):
                yield fact


def iter_ledger_facts(ledger: str, branch: str | None = None):
    """台帳から事実を返す。重複排除とブランチの絞り込みは会話ログ直読みと同じ規則。"""
    seen: set[str] = set()
    try:
        handle = open(ledger, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return
    except OSError as error:
        raise LedgerError("台帳 %s を読めません: %s" % (ledger, error))
    with handle:
        for line in handle:
            if not line.strip():
                continue
            if branch is not None and branch not in line:
                continue
            try:
                fact = json.loads(line)
            except ValueError:
                SCAN_STATS["unreadable_lines"] += 1
                continue
            if not isinstance(fact, dict) or not isinstance(fact.get("request_id"), str):
                SCAN_STATS["unreadable_lines"] += 1
                continue
            if branch is not None and fact.get("branch") != branch:
                continue
            if fact["request_id"] in seen:
                continue
            seen.add(fact["request_id"])
            yield fact


LEDGER_REPO_FIX = '"repo_fix": true'


def _group_key(row: dict):
    """補正の組の鍵 (session_id, branch)。形が崩れていれば None。"""
    session, branch = row.get("session_id"), row.get("branch") or ""
    if isinstance(session, str) and isinstance(branch, str):
        return session, branch
    return None


def ledger_repo_fixes(ledger: str) -> dict:
    """台帳の補正行を 1 回の走査で集め、組ごとの repo_id の集合を返す。"""
    fixes: dict = {}
    handle = _open_ledger(ledger)
    if handle is None:
        return fixes
    with handle:
        for line in handle:
            if LEDGER_REPO_FIX not in line:
                continue
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if not isinstance(row, dict) or row.get("repo_fix") is not True:
                continue
            key, repo = _group_key(row), row.get("repo_id")
            if key is not None and isinstance(repo, str) and repo:
                fixes.setdefault(key, set()).add(repo)
    return fixes


def apply_repo_fixes(facts, fixes: dict):
    """事実の列から補正行を取り除き、補正の repo_id がちょうど 1 種類の組の不明の事実を置き換える。"""
    for fact in facts:
        if fact.get("repo_fix"):
            continue
        if fixes and fact.get("repo_id") == UNKNOWN_REPO:
            repos = fixes.get(_group_key(fact))
            if repos is not None and len(repos) == 1:
                fact = dict(fact, repo_id=next(iter(repos)), repo_inferred=True)
        yield fact


def load_facts(resolver: RepoResolver, branch: str | None = None, issue: str | None = None):
    """集計系サブコマンドの事実の入口。

    台帳が設定されていれば、会話ログの増えた分を追記してから台帳だけを読む（読む時点で
    台帳は会話ログの上位集合になるので、会話ログ直読みと同じ値になる）。未設定なら
    会話ログを直接読む。

    ``issue`` を渡すと、台帳からはその issue を触ったセッションの行だけを読む（区間に
    切った結果は全行を読んだ場合と同じ）。番号の集合を渡せば、どれかを触ったセッションの行を
    まとめて読む。会話ログの直読みでは絞らない。
    """
    configured = ledger_path()
    if configured is None:
        return iter_facts(log_root(), resolver, branch=branch)
    ledger = resolve_ledger(configured)
    ledger_sync(ledger, log_root(), resolver)
    fixes = ledger_repo_fixes(ledger)
    if issue is not None and branch is None:
        return apply_repo_fixes(iter_ledger_issue_facts(ledger, issue), fixes)
    return apply_repo_fixes(iter_ledger_facts(ledger, branch=branch), fixes)


def load_branches_facts(resolver: RepoResolver, branches) -> dict:
    """ブランチごとの事実の列を ``{ブランチ: [事実]}`` で返す（issue の合計の PR の分）。

    各ブランチの列は ``load_facts(resolver, branch=<ブランチ>)`` と同じ行になる（重複排除も
    ブランチごと）。台帳への差分追記は行わない（呼ぶ側が直前に ``load_facts()`` で 1 回追記
    している前提）。台帳も会話ログも 1 回だけ走査し、ブランチの数に比例させない。
    """
    wanted = list(dict.fromkeys(branches))
    found = {branch: [] for branch in wanted}
    if not wanted:
        return found
    configured = ledger_path()
    if configured is None:
        # 素の set を渡すと数えた出力が常に 0 になり、確定行の値がそのまま足される
        seen = {branch: SeenSet() for branch in wanted}
        for path in log_files(log_root()):
            try:
                handle = open(path, encoding="utf-8", errors="replace")
            except OSError:
                continue
            with handle:
                lines = [line for line in handle
                         if '"assistant"' in line and any(branch in line for branch in wanted)]
            for branch in wanted:
                found[branch].extend(facts_from_lines(lines, path, resolver, seen[branch], branch))
        return found
    ledger = resolve_ledger(configured)
    seen = set()
    try:
        handle = open(ledger, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return found
    except OSError as error:
        raise LedgerError("台帳 %s を読めません: %s" % (ledger, error))
    with handle:
        for line in handle:
            if not line.strip() or not any(branch in line for branch in wanted):
                continue
            try:
                fact = json.loads(line)
            except ValueError:
                SCAN_STATS["unreadable_lines"] += 1
                continue
            if not isinstance(fact, dict) or not isinstance(fact.get("request_id"), str):
                SCAN_STATS["unreadable_lines"] += 1
                continue
            branch = fact.get("branch")
            if branch not in found or (branch, fact["request_id"]) in seen:
                continue
            seen.add((branch, fact["request_id"]))
            found[branch].append(fact)
    return found


class _DriftCutOff(Exception):
    """突き合わせのための読み直しが上限の時間に達した。"""


class _NoRepo:
    """読み直しではリポジトリを引かない（突き合わせに使わず、git の起動を増やさないため）。"""

    def repo_id(self, cwd: str) -> str:
        return UNKNOWN_REPO

    def inferred(self, cwd: str) -> bool:
        return False


def _drift_lines(handle, mentions, expired):
    """対象のセッション ID を含む生の行だけを返す。一定の行数ごとに上限を確かめる。

    確かめるのは「まだ読んでいない行が残っている」ときの打ち切りのため。読み終えたあとに
    確認を足さない（読み終えた結果は上限を超えていても使う。待った時間は結果を捨てても
    戻らず、全行を読んだ結果は正しい比較のため。openspec の change drift-final-read-result、
    issue #701）。
    """
    for count, line in enumerate(handle, 1):
        if count % DRIFT_CHECK_EVERY_LINES == 0 and expired():
            raise _DriftCutOff()
        if mentions(line):
            yield line


def session_facts(session_ids, earliest: int, budget: float):
    """対象のセッション ID を持つ行を、ブランチやリポジトリで絞らずに集める（読み直し）。

    本体の値はセッション全体の値で、1 つのセッションがサブエージェントの worktree など
    別のブランチの行を持つので、答えのためにブランチで絞って読んだ行では比べられない。
    台帳が設定されていれば台帳だけを読む（取り込みは答えを出すときに済んでいる）。
    未設定なら会話ログを読み、更新時刻が ``earliest``（記録の t0 の最小値）より前の
    ファイルは区間の行を持ちえないので開かない。

    始めてからの経過時間が ``budget`` 秒に達したら読むのをやめて None を返す（読めた分の
    行は返さない。読み切っていない行の合計で比べると、単価表が正しくても差が出るため）。
    ただし最後まで読み終えた結果は、その時点で上限を超えていても返す（issue #701）。
    読み取れなかった行の件数は、答えのための読みで数え済みなので増やさない。
    """
    started = time.monotonic()

    def expired() -> bool:
        return time.monotonic() - started >= budget

    wanted = set(session_ids)
    mentions = re.compile("|".join(re.escape(s) for s in sorted(wanted))).search
    unreadable = SCAN_STATS["unreadable_lines"]
    facts = []
    try:
        configured = ledger_path()
        if configured is not None:
            seen: set[str] = set()  # 台帳の行の request_id の重複排除だけに使う
            if expired():
                return None
            try:
                handle = open(resolve_ledger(configured), encoding="utf-8", errors="replace")
            except OSError:
                return facts
            with handle:
                for line in _drift_lines(handle, mentions, expired):
                    try:
                        fact = json.loads(line)
                    except ValueError:
                        continue
                    if not isinstance(fact, dict) or fact.get("session_id") not in wanted:
                        continue
                    request_id = fact.get("request_id")
                    if not isinstance(request_id, str) or request_id in seen:
                        continue
                    seen.add(request_id)
                    facts.append(fact)
            return facts
        resolver = _NoRepo()
        heads = SeenSet()  # 数えた出力を覚える（素の set だと確定行の値がそのまま足される）
        for path in log_files(log_root()):
            if expired():
                return None
            try:
                if os.stat(path).st_mtime < earliest:
                    continue
                handle = open(path, "rb")
            except OSError:
                continue
            with handle:
                positioned = PositionedLines(handle)
                lines = _drift_lines(positioned, mentions, expired)
                for fact in facts_from_lines(lines, path, resolver, heads,
                                             offset_of=lambda: positioned.position):
                    if fact["session_id"] in wanted:
                        facts.append(fact)
        return facts
    except _DriftCutOff:
        return None
    finally:
        SCAN_STATS["unreadable_lines"] = unreadable


# --------------------------------------------------------------------------
# 集計
# --------------------------------------------------------------------------

def summarise(facts, pricing: Pricing):
    """事実の列をモデル別に畳む。未知モデルは名前と行数を別に数える。"""
    per_model = {}
    unknown = defaultdict(int)
    total = 0.0
    messages = 0
    for fact in facts:
        usd, known = pricing.cost(fact)
        total += usd
        if is_continuation(fact):
            # 補足の事実はメッセージ数に数えないが、確定行の出力の差分と金額は内訳にも足す
            # （足さないと 1 行目の額とモデル別の内訳の合計が合わない）
            if known and fact.get("output_tokens"):
                row = per_model.setdefault(
                    fact["model"], {"messages": 0, "usd": 0.0, **{f: 0 for f in TOKEN_FIELDS}}
                )
                row["usd"] += usd
                row["output_tokens"] += fact["output_tokens"]
            continue
        messages += 1
        if not known:
            unknown[fact["model"] or "(モデル名なし)"] += 1
            continue
        row = per_model.setdefault(
            fact["model"], {"messages": 0, "usd": 0.0, **{f: 0 for f in TOKEN_FIELDS}}
        )
        row["messages"] += 1
        row["usd"] += usd
        for field in TOKEN_FIELDS:
            row[field] += fact[field]
    return {"total_usd": total, "messages": messages, "per_model": per_model,
            "unknown_models": dict(unknown)}


def token_totals(facts) -> tuple[int, int]:
    """(入出力トークン, キャッシュトークン) の合計。

    単価が引けないモデルの行も数える（量は単価と無関係に事実だから。``summarise()`` の
    モデル別の内訳は未知モデルの行のトークンを数えないので、ここでは使わない）。
    """
    io = cache = 0
    for fact in facts:
        io += (fact.get("input_tokens") or 0) + (fact.get("output_tokens") or 0)
        cache += ((fact.get("cache_write_5m_tokens") or 0) + (fact.get("cache_write_1h_tokens") or 0)
                  + (fact.get("cache_read_tokens") or 0))
    return io, cache


_EPOCH = datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc)


def timestamp_ms(text):
    """ISO 8601 の ``timestamp`` を epoch ミリ秒の整数にする（読めなければ None）。"""
    if not isinstance(text, str) or not text:
        return None
    try:
        moment = datetime.datetime.fromisoformat(text[:-1] + "+00:00" if text.endswith("Z") else text)
    except ValueError:
        return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=datetime.timezone.utc)
    delta = moment - _EPOCH
    return (delta.days * 86400 + delta.seconds) * 1000 + delta.microseconds // 1000


def facts_until(facts, at_ms: int) -> list:
    """``timestamp`` が ``at_ms`` 以前の事実だけを残す。読めない ``timestamp`` の行は残す。"""
    kept = []
    for fact in facts:
        stamp = timestamp_ms(fact.get("timestamp"))
        if stamp is None or stamp <= at_ms:
            kept.append(fact)
    return kept


def fact_epoch(fact: dict):
    """行の時刻（ISO 形式・末尾 Z）を epoch 秒にする。読めなければ None（区間の外として扱う）。"""
    stamp = fact.get("timestamp")
    if not isinstance(stamp, str) or not stamp:
        return None
    if stamp.endswith("Z"):
        stamp = stamp[:-1] + "+00:00"
    try:
        moment = datetime.datetime.fromisoformat(stamp)
    except ValueError:
        return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=datetime.timezone.utc)
    return moment.timestamp()


def compare_sessions(records: dict, facts, pricing: Pricing) -> dict:
    """記録のあるセッションごとに、本体の値と自前の計算を突き合わせる。

    ``records`` は セッション ID → (t0, v0, t1, v1)。本体の値は ``v1 - v0``、自前の計算は
    そのセッションの行のうち時刻が ``[t0 + 1, t1 + 1)`` のものの合計。statusline は応答の
    あとに描画されるので、t0 と同じ秒の行は最初の観測値に含まれ、t1 と同じ秒の行は最後の
    観測値に含まれる。
    """
    own = {sid: 0.0 for sid in records}
    unpriced = {sid: set() for sid in records}
    for fact in facts:
        record = records.get(fact.get("session_id"))
        if record is None:
            continue
        moment = fact_epoch(fact)
        if moment is None or not (record[0] + 1 <= moment < record[2] + 1):
            continue
        usd, known = pricing.cost(fact)
        own[fact["session_id"]] += usd
        # トークンの無い行（<synthetic> など API 呼び出しを伴わない行）は 0 円で正しい
        if not known and any(fact[field] >= 1 for field in TOKEN_FIELDS):
            unpriced[fact["session_id"]].add(fact["model"] or "(モデル名なし)")
    drifted = 0
    worst = None
    missing = {"sessions": 0, "models": set(), "official_usd": 0.0, "own_usd": 0.0}
    for sid in sorted(records):
        t0, v0, t1, v1 = records[sid]
        official = v1 - v0
        diff = abs(official - own[sid])
        larger = max(official, own[sid])
        if diff > DRIFT_MIN_USD + DRIFT_EPSILON and diff > larger * DRIFT_MIN_RATIO + DRIFT_EPSILON:
            drifted += 1
            if worst is None or diff > worst["diff_usd"]:
                worst = {"session_id": sid, "official_usd": official, "own_usd": own[sid],
                         "diff_usd": diff, "ratio": diff / larger if larger > 0 else 0.0}
        if unpriced[sid]:
            missing["sessions"] += 1
            missing["models"] |= unpriced[sid]
            missing["official_usd"] += official
            missing["own_usd"] += own[sid]
    return {
        "checked": len(records),
        "drifted": drifted,
        "worst": worst,
        "unpriced": dict(missing, models=sorted(missing["models"])) if missing["sessions"] else None,
        "cut_off": False,
    }


def price_drift(session_ids, pricing: Pricing, facts=None):
    """答えに含まれるセッションの突き合わせの結果を返す。知らせることが無ければ None。

    ``facts`` に対象のセッションの全行（ブランチで絞っていないもの）を渡せば読み直さない。
    渡さなければ読み直し、上限の時間で打ち切られたら ``cut_off`` を立てて返す。
    """
    records = {}
    for sid in set(session_ids):
        record = read_session_cost(sid)
        if record is not None:
            records[sid] = record
    if not records:
        return None
    if facts is None:
        budget = drift_budget()
        facts = session_facts(records, min(r[0] for r in records.values()), budget)
        if facts is None:
            return {"checked": len(records), "drifted": 0, "worst": None, "unpriced": None,
                    "cut_off": True, "budget_seconds": budget}
    result = compare_sessions(records, facts, pricing)
    if not result["drifted"] and result["unpriced"] is None:
        return None
    return result


# --------------------------------------------------------------------------
# 区間分割（事実の列だけを入力とする純粋な関数）
# --------------------------------------------------------------------------

def _origin_request_id(fact: dict) -> str:
    """補足の事実の ``<requestId>#<uuid>`` から元の requestId を返す（通常の事実はそのまま）。"""
    request_id = fact["request_id"]
    return request_id.rsplit("#", 1)[0] if is_continuation(fact) else request_id


def _ordered(rows: list) -> list:
    """同じセッションの事実を、timestamp → 元の requestId → 通常の事実が先 → 補足は元ログの位置順に並べる。

    補足の事実は ``source_offset``（元ログの行頭バイト位置）の数値順、同値なら ``request_id`` 順。
    ``source_offset`` を持たない補足（位置を保存する前の版が書いたもの）が混ざる同時刻・同一
    requestId のグループは、順序を復元できないので従来の ``request_id`` 順に戻す。
    """
    legacy = {(f["timestamp"], _origin_request_id(f)) for f in rows
              if is_continuation(f) and not isinstance(f.get("source_offset"), int)}

    def key(fact):
        group = (fact["timestamp"], _origin_request_id(fact))
        if not is_continuation(fact):
            return group + (0, 0, fact["request_id"])
        offset = 0 if group in legacy else fact["source_offset"]
        return group + (1, offset, fact["request_id"])

    return sorted(rows, key=key)


def split_intervals(facts):
    """事実の列を ``sessionId`` ごとに ``timestamp`` 順で区間に切る。

    会話ログを読み直さずに、抽出済みの事実の列だけから同じ区間分割が再現できる。
    ブランチ全体を時刻順に並べて切ってはいけない。利用者は複数セッションを並行して
    走らせるので、そうすると別セッションの行が互いの区間に混ざる。

    区間の帰属先は **(リポジトリ識別子, issue 番号) の組**。issue 番号はリポジトリ内で
    しか一意でないため、番号だけを鍵にしない。
    """
    by_session = defaultdict(list)
    for fact in facts:
        by_session[fact["session_id"]].append(fact)
    result = []
    for session_id in sorted(by_session):
        rows = _ordered(by_session[session_id])
        current = []
        for fact in rows:
            current.append(fact)
            if fact["post_marker"]:
                result.append(_interval(session_id, current, fact["post_marker"]))
                current = []
        if current:
            # 投稿で閉じていない末尾の区間。落とさずに残す。
            result.append(_interval(session_id, current, None))
    return result


def _interval(session_id: str, rows: list, closed_by):
    issue = None
    repo_id = rows[-1]["repo_id"]
    for fact in rows:
        # その区間で直近に触った issue へ寄せる。リポジトリは触った行のものを採る。
        for number in fact["issues"]:
            issue = number
            repo_id = fact["repo_id"]
    branches = []
    for fact in rows:
        if fact["branch"] and fact["branch"] not in branches:
            branches.append(fact["branch"])
    return {
        "session_id": session_id,
        "issue": issue,
        "repo_id": repo_id,
        "branches": branches,
        "started_at": rows[0]["timestamp"],
        "ended_at": rows[-1]["timestamp"],
        "closed_by": closed_by,
        "request_ids": [f["request_id"] for f in rows],
        "facts": rows,
    }


INFERRED_LINE = "  推定で数えた行: %d 件 $%s（cwd が削除済みで、パスからリポジトリを推定した。合計に入れている）"


def inferred_totals(facts, pricing: Pricing) -> tuple[float, int]:
    """事実の列のうち、識別子を推定で決めた行（repo_inferred が真）の額と件数（補足は件数に数えない）。"""
    usd, messages = 0.0, 0
    for fact in facts:
        if fact.get("repo_inferred"):
            usd += pricing.cost(fact)[0]
            if not is_continuation(fact):
                messages += 1
    return usd, messages


def render_inferred(usd: float, messages: int) -> list[str]:
    """「推定で数えた行」の表示。件数が 0 なら出さない。"""
    if not messages:
        return []
    return [INFERRED_LINE % (messages, format(usd, ",.2f"))]


def price_intervals(intervals: list, pricing: Pricing) -> list:
    """区間ごとの金額と件数を足す。単価を知るのはここだけで、区間分割は事実だけを見る。"""
    for row in intervals:
        row["usd"] = sum(pricing.cost(fact)[0] for fact in row["facts"])
        row["messages"] = sum(1 for fact in row["facts"] if not is_continuation(fact))
    return intervals


def interval_payload(row: dict, resolver: RepoResolver) -> dict:
    """区間を JSON に出せる形にする（事実の実体は落とし、requestId だけを残す）。"""
    return {
        "session_id": row["session_id"],
        "issue": row["issue"],
        "repo_id": row["repo_id"],
        "repo_label": resolver.label(row["repo_id"]),
        "branches": row["branches"],
        "started_at": row["started_at"],
        "ended_at": row["ended_at"],
        "closed_by": row["closed_by"],
        "messages": row["messages"],
        "usd": row["usd"],
        "request_ids": row["request_ids"],
    }


def render_interval(row: dict) -> str:
    target = "issue #%s" % row["issue"] if row["issue"] else "帰属先なし"
    boundary = "境界: %s" % row["closed_by"] if row["closed_by"] else "境界なし・末尾"
    return "    %s %s〜%s %d メッセージ $%s → %s（%s）" % (
        row["session_id"], row["started_at"], row["ended_at"], row["messages"],
        format(row["usd"], ",.2f"), target, boundary,
    )


# --------------------------------------------------------------------------
# 出力
# --------------------------------------------------------------------------

def format_rate(rate: float) -> str:
    return ("%f" % rate).rstrip("0").rstrip(".") if rate != int(rate) else "%d" % int(rate)


def money(usd: float, pricing: Pricing) -> str:
    # 先に 6 桁（マイクロドル）に揃える。timeline は隠し行の 6 桁の記録から 1 行目を作るので、
    # /cost も同じ値から丸めないと、6 桁目の丸めで 1 セント動く境界の値で表示が割れる
    usd = round(usd * 1e6) / 1e6
    return "$%s / ¥%s @%s" % (
        format(usd, ",.2f"),
        format(pricing.yen(usd), ",.0f"),
        format_rate(pricing.jpy_rate),
    )


def headline(usd: float, pricing: Pricing, target: str, kind: str) -> str:
    """出力の 1 行目。後続のゲート連携がこの 1 行だけを取って PR に貼る。"""
    return "コスト: %s — %s 帰属: %s" % (money(usd, pricing), target, kind)


# --------------------------------------------------------------------------
# 節目ごとの行（PR / issue のコメントに積む表）
# --------------------------------------------------------------------------

TIMELINE_MARK = "<!-- cost-ledger:timeline v1"
TIMELINE_HEADER = "| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |"
TIMELINE_SEPARATOR = "|---|---|---|---|---|"
TIMELINE_UNKNOWN = "(?)"
_INCREMENT_RE = re.compile(r"\([^()]*\)(\s*)$")


def format_tokens(count: int) -> str:
    """トークン数を短く書く（``999``・``900K``・``2.1M``・``81M``・``1.2B``）。

    四捨五入は整数演算で行い、結果が次の単位に届くときは次の単位で書く
    （999,999 は ``1.0M``、9,999,999 は ``10M``、999,999,999 は ``1.0B``）。
    """
    if count < 1000:
        return "%d" % count
    thousands = (count + 500) // 1000
    if thousands < 1000:
        return "%dK" % thousands
    tenths = (count + 50_000) // 100_000
    if tenths < 100:
        return "%d.%dM" % divmod(tenths, 10)
    millions = (count + 500_000) // 1_000_000
    if millions < 1000:
        return "%dM" % millions
    return "%d.%dB" % divmod((count + 50_000_000) // 100_000_000, 10)


def _signed(text: str, negative: bool, zero: str) -> str:
    # 表示が 0 になる差は、元の値が負でも + と書く（-0.00 を出さない）
    return ("-" if negative and text != zero else "+") + text


def timeline_increments(current, previous) -> tuple[str, str, str]:
    """増分 3 項目（金額・入出力・キャッシュ）の ``(...)`` を作る。

    ``current`` / ``previous`` は (金額のマイクロドル, 入出力, キャッシュ)。前の値が
    読めなかったときは ``previous`` に ``TIMELINE_UNKNOWN`` を渡す。前の行が無いときは
    ``None`` を渡す（増分は累計と同じ値になる）。
    """
    if previous == TIMELINE_UNKNOWN:
        return (TIMELINE_UNKNOWN,) * 3
    base = previous or (0, 0, 0)
    usd = current[0] - base[0]
    parts = ["(%s)" % _signed(format(abs(usd) / 1e6, ",.2f"), usd < 0, "0.00")]
    for now, before in zip(current[1:], base[1:]):
        parts.append("(%s)" % _signed(format_tokens(abs(now - before)), now < before, "0"))
    return tuple(parts)


def timeline_row(at_ms: int, trigger: str, current, previous) -> str:
    """表の 1 行。この書式を持つのはここだけ（合算・後追いの行もここを通す）。"""
    stamp = datetime.datetime.fromtimestamp(at_ms / 1000).strftime("%m/%d %H:%M")
    usd, io, cache = timeline_increments(current, previous)
    return "| %s | %s | $%s %s | %s %s | %s %s |" % (
        stamp, trigger, format(current[0] / 1e6, ",.2f"), usd,
        format_tokens(current[1]), io, format_tokens(current[2]), cache,
    )


TIMELINE_TOTAL_PREFIX = "合計（"


def timeline_total_trigger(prs, outside_usd: float) -> str:
    """合計の行の「きっかけ」の欄。``合計（#300 $3.00 + PR 外 $2.00）``。

    PR は件数によらず全部を ``#<番号> $<額>`` で番号の昇順に書く（まとめない）。
    """
    parts = ["#%d %s" % (pr["number"], _dollars(pr["usd"])) for pr in sorted(prs, key=lambda p: p["number"])]
    parts.append("PR 外 %s" % _dollars(outside_usd))
    return "%s%s）" % (TIMELINE_TOTAL_PREFIX, " + ".join(parts))


def timeline_epic_total_trigger(children: int, prs: int, pr_usd: float, outside_usd: float) -> str:
    """子 issue 込みの合計の行の「きっかけ」の欄。

    ``合計（子 issue 2 件込み: PR 2 件 $3.00 + PR 外 $2.00）``。PR ごとの額は並べない（子の数に
    比例して長くならないように）。内訳は ``/cost <番号>`` で見る。
    """
    return "%s子 issue %d 件込み: PR %d 件 %s + PR 外 %s）" % (
        TIMELINE_TOTAL_PREFIX, children, prs, _dollars(pr_usd), _dollars(outside_usd))


def _is_total_trigger(trigger: str) -> bool:
    return trigger.startswith(TIMELINE_TOTAL_PREFIX)


def timeline_rewrite_increments(row: str, current, previous) -> str:
    """既存の行の増分 3 項目だけを書き直す。時刻・きっかけ・累計の表示は元の文字列のまま。"""
    cells = row.split("|")
    if len(cells) < 7:
        return row
    for index, text in zip((3, 4, 5), timeline_increments(current, previous)):
        cells[index] = _INCREMENT_RE.sub(lambda m, text=text: text + m.group(1), cells[index], count=1)
    return "|".join(cells)


def _timeline_record(text: str):
    """記録 ``<時刻>:<金額>:<入出力>:<キャッシュ>`` を (ミリ秒, (マイクロドル, 入出力, キャッシュ)) にする。"""
    parts = text.split(":")
    if len(parts) != 4:
        raise ValueError(text)
    at, usd = float(parts[0]), float(parts[1])
    if not (math.isfinite(at) and math.isfinite(usd)):
        raise ValueError(text)
    return int(round(at * 1000)), (int(round(usd * 1e6)), int(parts[2]), int(parts[3]))


def _timeline_record_text(at_ms: int, values) -> str:
    sign = "-" if values[0] < 0 else ""
    return "%d.%03d:%s%d.%06d:%d:%d" % (
        *divmod(at_ms, 1000), sign, *divmod(abs(values[0]), 1_000_000), values[1], values[2])


def parse_timeline(body: str):
    """既存の本文から (表の行, 記録) を取り出す。記録が読めなければ記録は None。"""
    rows, records, marked = [], [], False
    for line in body.split("\n"):
        line = line.rstrip("\r")
        if line.startswith(TIMELINE_MARK):
            marked = True
            tail = line[len(TIMELINE_MARK):].strip()
            try:
                if not tail.endswith("-->"):
                    raise ValueError(line)
                records = [_timeline_record(part) for part in tail[:-3].split()]
            except ValueError:
                records = None
        elif (line.startswith("|") and not line.startswith(TIMELINE_HEADER[:5])
              and not line.startswith("|--")):
            rows.append(line)
    if not body.strip():
        return [], []
    if not marked or not records:
        return rows, None
    return rows, records


def _row_trigger(row: str) -> str:
    cells = row.split("|")
    return cells[2].strip() if len(cells) > 2 else ""


# 後追い（--backfill）が「同じ出来事の行が既にある」と見る幅。手で積んだ行の時刻は hook が動いた
# 手元の時刻で、GitHub が記録した出来事の時刻と数秒ずれる。手元の時計のずれも見込む
BACKFILL_SAME_EVENT_MS = 300_000


def timeline_has_trigger_near(parsed, trigger: str, at_ms: int) -> bool:
    """``parse_timeline()`` の結果に、同じきっかけの行が ``at_ms`` の近くにあるか（後追いの二重追記の判定）。

    きっかけの欄を ``+`` で分けた要素に ``trigger`` を含み、記録の時刻が ``at_ms`` の 300 秒前以降の
    行があれば真。記録と対応しない行（行数が記録より多いときの先頭の余りの行と、最終行が読めない
    本文のすべての行）は、時刻を見ずに呼び名だけで判定する。合計の行は対象にしない。
    """
    rows, records = parsed
    if records is None:
        times = [None] * len(rows)
    else:
        # 行と記録の対応は build_timeline と同じ（記録は後ろから行に当てる）
        records = records[max(0, len(records) - len(rows)):]
        times = [None] * (len(rows) - len(records)) + [at for at, _values in records]
    for row, at in zip(rows, times):
        name = _row_trigger(row)
        if _is_total_trigger(name) or trigger not in name.split("+"):
            continue
        if at is None or at >= at_ms - BACKFILL_SAME_EVENT_MS:
            return True
    return False


def _timeline_insert(entries: list, at_ms: int, trigger: str, values, kept, base=None) -> bool:
    """``entries``（``[時刻, きっかけ, 累計, 行]`` の列）の鍵の位置に 1 行入れる。同じ鍵が既に
    あれば入れずに False。

    ``base`` を渡すと合計の行として扱い、増分はその値との差で、ほかの行を書き直さない。渡さない
    ときは、前にある合計でない、いちばん近い行を増分の基準にし、後ろにある合計でない最初の
    1 行の増分を新しい行の累計との差に書き直す。
    """
    key = (at_ms, trigger.encode("utf-8"), values)
    keys = [(at, name.encode("utf-8"), other) for at, name, other, _row in entries]
    if key in keys:
        return False
    position = sum(1 for other in keys if other < key)
    if base is not None:
        previous = base
    else:
        before = [entry for entry in entries[:position] if not _is_total_trigger(entry[1])]
        if before:
            previous = before[-1][2]
        else:
            previous = TIMELINE_UNKNOWN if kept else None
        for following in entries[position:]:
            if not _is_total_trigger(following[1]):
                following[3] = timeline_rewrite_increments(following[3], following[2], values)
                break
    entries.insert(position, [at_ms, trigger, values, timeline_row(at_ms, trigger, values, previous)])
    return True


def build_timeline(body: str, at_ms: int, trigger: str, current, first_line, total=None) -> str:
    """既存の本文に節目の行（と合計の行）を足した新しい本文を返す（#303 の design の決定 3、
    #689 の design の決定 4〜6）。

    ``current`` は (マイクロドル, 入出力, キャッシュ)。``first_line`` はマイクロドルと「最後の行が
    合計の行か」から 1 行目を作る関数。``total`` は合計の行の ``(きっかけ, 累計)``（無ければ None）。
    合計の行の増分は ``current`` との差で、既存の行を書き直さない。合計でない行の増分は、前にある
    合計でない、いちばん近い行との差。節目の行と合計の行は別々に二重実行を判定し、どちらも既に
    あれば ``body`` を返す。
    """
    rows, records = parse_timeline(body)
    if records is None:
        # 記録なし: 既存の行をそのまま残し、増分は (?)。0 から全額増えたとは書かない
        kept, entries = rows, []
        entries.append([at_ms, trigger, current, timeline_row(at_ms, trigger, current, TIMELINE_UNKNOWN)])
        if total is not None:
            entries.append([at_ms, total[0], total[1], timeline_row(at_ms, total[0], total[1], current)])
    else:
        # 行数が記録より多い分は、記録の無い先頭の行としてそのまま残す
        records = records[max(0, len(records) - len(rows)):]
        extra = len(rows) - len(records)
        kept = rows[:extra]
        entries = [[at, _row_trigger(row), values, row]
                   for (at, values), row in zip(records, rows[extra:])]
        added = _timeline_insert(entries, at_ms, trigger, current, kept)
        if total is not None:
            added = _timeline_insert(entries, at_ms, total[0], total[1], kept, base=current) or added
        if not added:
            return body
    last = entries[-1]
    lines = [first_line(last[2][0], _is_total_trigger(last[1])), "", TIMELINE_HEADER, TIMELINE_SEPARATOR]
    lines.extend(kept)
    lines.extend(entry[3] for entry in entries)
    lines.append("")
    lines.append("%s %s -->" % (
        TIMELINE_MARK, " ".join(_timeline_record_text(e[0], e[2]) for e in entries)))
    return "\n".join(lines) + "\n"


def render_breakdown(summary: dict, pricing: Pricing) -> list[str]:
    lines = []
    if summary["per_model"]:
        lines.append("  内訳（モデル別）:")
        for model, row in sorted(summary["per_model"].items(), key=lambda kv: -kv[1]["usd"]):
            lines.append(
                "    %-22s msgs=%5d  in=%s  out=%s  cw=%s  cr=%s  $%s"
                % (
                    model,
                    row["messages"],
                    format(row["input_tokens"], ","),
                    format(row["output_tokens"], ","),
                    format(row["cache_write_5m_tokens"] + row["cache_write_1h_tokens"], ","),
                    format(row["cache_read_tokens"], ","),
                    format(row["usd"], ",.2f"),
                )
            )
    for model, count in sorted(summary["unknown_models"].items()):
        lines.append(
            "  未知モデル: %s %d 行（料金表に単価が無いため 0 円として扱っている）" % (model, count)
        )
    return lines


def render_price_drift(result) -> list[str]:
    """単価表のずれの警告行。1 行目のあと、内訳と既存の注記のうしろに出す。"""
    if result is None:
        return []
    if result["cut_off"]:
        return [
            "  単価表のずれ: 未確認（本体の値の記録がある %d セッションを突き合わせるための"
            "読み直しが上限の %g 秒に達したので、途中で打ち切った。%s=inf を付けて実行すると"
            "最後まで突き合わせる）" % (result["checked"], result["budget_seconds"], DRIFT_BUDGET_ENV)
        ]
    lines = []
    worst = result["worst"]
    if worst is not None:
        lines.append(
            "  単価表のずれ: 突き合わせた %d セッションのうち %d セッションで、Claude Code 本体の"
            "値と自前の計算の差が閾値（$%s かつ %d%%）を超えた。差が最大のセッション %s は"
            "本体 $%s・自前 $%s（差 $%s、%d%%）。pricing.json の単価を確かめてください。"
            % (result["checked"], result["drifted"], format(DRIFT_MIN_USD, ",.2f"),
               round(DRIFT_MIN_RATIO * 100), worst["session_id"],
               format(worst["official_usd"], ",.2f"), format(worst["own_usd"], ",.2f"),
               format(worst["diff_usd"], ",.2f"), round(worst["ratio"] * 100))
        )
    unpriced = result["unpriced"]
    if unpriced is not None:
        lines.append(
            "  単価表のずれ: 料金表に単価の無いモデル（%s）の行が %d セッションにあり、その分を"
            "0 円として計算している。それらのセッションの合計は本体 $%s・自前 $%s。"
            "pricing.json に単価を足してください。"
            % ("、".join(unpriced["models"]), unpriced["sessions"],
               format(unpriced["official_usd"], ",.2f"), format(unpriced["own_usd"], ",.2f"))
        )
    return lines


# --------------------------------------------------------------------------
# サブコマンド
# --------------------------------------------------------------------------

def branch_label(facts, resolver: RepoResolver):
    """そのブランチの行が 1 つのリポジトリに収まるならその表示名を返す。"""
    known = {f["repo_id"] for f in facts if f["repo_id"] != UNKNOWN_REPO}
    if len(known) == 1:
        return resolver.label(next(iter(known)))
    return None


def cmd_facts(args, pricing: Pricing, resolver: RepoResolver) -> int:
    for fact in load_facts(resolver):
        sys.stdout.write(json.dumps(fact, ensure_ascii=False) + "\n")
    return 0


def cmd_branch(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """ブランチに帰属する行を集計する。

    ``args.scope_repo_id`` があるときは、そのリポジトリの行だけを合計する。``main`` や
    ``develop`` のように別リポジトリにも同名で存在するブランチを、番号なしの ``/cost`` で
    引いたときに他リポジトリの行を足さないため。リポジトリが不明に落ちた行は除外も合算も
    せず、件数と金額を別立てで出す。PR 経路は絞らない（ヘッドブランチが main になることは
    なく、削除済み worktree の行を落とさないため）。
    """
    scope = getattr(args, "scope_repo_id", None)
    all_facts = list(load_facts(resolver, branch=args.branch))
    unknown = []
    if scope is None:
        facts = all_facts
    else:
        facts = [f for f in all_facts if f["repo_id"] == scope]
        unknown = [f for f in all_facts if f["repo_id"] == UNKNOWN_REPO]
    summary = summarise(facts, pricing)
    label = resolver.label(scope) if scope is not None else branch_label(facts, resolver)
    target = "ブランチ %s" % args.branch
    if args.target_label:
        target = args.target_label
    elif label:
        target = "ブランチ %s (%s)" % (args.branch, label)
    print(headline(summary["total_usd"], pricing, target, "ブランチ"))
    print("  対象: ブランチ %s（%d メッセージ）" % (args.branch, summary["messages"]))
    for line in render_breakdown(summary, pricing):
        print(line)
    if not facts:
        print("  この会話ログにそのブランチの行はありません。")
    if unknown:
        unknown_usd = summarise(unknown, pricing)["total_usd"]
        print("  リポジトリ不明: %d 件 $%s（cwd が削除済みで、どのリポジトリの %s か絞れない）"
              % (len(unknown), format(unknown_usd, ",.2f"), args.branch))
    if scope is not None:
        for line in render_inferred(*inferred_totals(facts, pricing)):
            print(line)
    if not getattr(args, "no_drift_check", False):
        for line in render_price_drift(price_drift({f["session_id"] for f in facts}, pricing)):
            print(line)
    return 0


def cmd_cost(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """``/cost`` の入口。番号の判別だけを行い、集計は branch / issue / epic の経路に委ねる。
    issue のうち子 issue を持つもの（判別の応答の子の数が 1 以上）は ``cmd_epic`` へ渡す。

    1 行目を作るのは ``headline()`` だけで、この関数は帰属先の表記を渡すにとどめる。
    PR 経路が独自の書式を持つと、ゲート連携が貼る 1 行が経路ごとに割れる。
    """
    where = os.path.abspath(args.repo) if args.repo else os.getcwd()

    if args.number is None:
        branch = current_branch(where)
        if not branch:
            sys.stderr.write(
                "%s では現在のブランチが決まりません（git リポジトリの中で実行するか、"
                "PR か issue の番号を渡してください）。\n" % where
            )
            return 2
        # 番号なしは現在のリポジトリのブランチを見るので、同名の別リポジトリの行は足さない
        return cmd_branch(
            argparse.Namespace(
                branch=branch, target_label=None, scope_repo_id=resolver.repo_id(where),
                no_drift_check=args.no_drift_check,
            ),
            pricing,
            resolver,
        )

    kind, value, children = resolve_number(where, args.number)
    if kind == "pr":
        return cmd_branch(
            argparse.Namespace(
                branch=value, target_label="PR #%s (%s)" % (args.number, value),
                no_drift_check=args.no_drift_check,
            ),
            pricing,
            resolver,
        )
    if kind == "issue" and children >= 1 and re.fullmatch(r"[0-9]+", value):
        return cmd_epic(
            argparse.Namespace(issue=value, repo=where, json=args.json,
                               no_drift_check=args.no_drift_check),
            pricing,
            resolver,
        )
    if kind == "issue":
        # 子を持たない issue だけ、閉じた PR を 1 回問い合わせて合計に重ねる
        found = fetch_closing_prs(where, int(value)) if re.fullmatch(r"[0-9]+", value) else []
        return cmd_issue(
            argparse.Namespace(issue=value, repo=where, json=args.json,
                               no_drift_check=args.no_drift_check,
                               closing_pr=["%d:%s" % pair for pair in found or []],
                               closing_prs_error=found is None),
            pricing,
            resolver,
        )
    sys.stderr.write(
        "#%s は PR としても issue としても見つかりません（%s のリポジトリに問い合わせました）。"
        "コストは 0 ではなく不明です。\n" % (args.number, where)
    )
    return 2


def cmd_report(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """監査用。全行を帰属先ごとに畳み、合計が総額と合うことを見えるようにする。"""
    facts = list(load_facts(resolver))
    branches: dict[str, float] = defaultdict(float)
    repos: dict[str, float] = defaultdict(float)
    repo_messages: dict[str, int] = defaultdict(int)
    unattributed = 0.0
    unattributed_messages = 0
    summary = summarise(facts, pricing)
    for fact in facts:
        usd, _known = pricing.cost(fact)
        repos[fact["repo_id"]] += usd
        if not is_continuation(fact):
            repo_messages[fact["repo_id"]] += 1
        if fact["branch"]:
            branches[fact["branch"]] += usd
        else:
            unattributed += usd
            if not is_continuation(fact):
                unattributed_messages += 1
    payload = {
        "total_usd": summary["total_usd"],
        "messages": summary["messages"],
        "branches": dict(branches),
        "unattributed_branch_usd": unattributed,
        "unattributed_branch_messages": unattributed_messages,
        "repos": {
            key: {"label": resolver.label(key), "usd": value, "messages": repo_messages[key]}
            for key, value in repos.items()
        },
        "unknown_models": summary["unknown_models"],
        "unreadable_lines": SCAN_STATS["unreadable_lines"],
        "usd_jpy_rate": pricing.jpy_rate,
    }
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0
    print(headline(summary["total_usd"], pricing, "全履歴", "ブランチ"))
    for branch, usd in sorted(branches.items(), key=lambda kv: -kv[1]):
        print("  %-40s $%s" % (branch, format(usd, ",.2f")))
    print("  未帰属（gitBranch なし）: %d 件 $%s"
          % (unattributed_messages, format(unattributed, ",.2f")))
    if UNKNOWN_REPO in repos:
        print("  リポジトリ不明: %d 件 $%s"
              % (repo_messages[UNKNOWN_REPO], format(repos[UNKNOWN_REPO], ",.2f")))
    for line in render_breakdown(summary, pricing):
        print(line)
    return 0


def cmd_intervals(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """区間分割そのものを見る窓口。ブランチの総額が区間の合計と合うことを確かめられる。"""
    facts = list(load_facts(resolver, branch=args.branch))
    rows = price_intervals(split_intervals(facts), pricing)
    total = sum(row["usd"] for row in rows)
    if args.json:
        print(json.dumps({
            "branch": args.branch,
            "total_usd": total,
            "messages": sum(1 for fact in facts if not is_continuation(fact)),
            "intervals": [interval_payload(row, resolver) for row in rows],
            "usd_jpy_rate": pricing.jpy_rate,
        }, ensure_ascii=False, indent=2))
        return 0
    target = "ブランチ %s" % args.branch if args.branch else "全履歴"
    print(headline(total, pricing, target, "区間"))
    print("  対象: %s（%d 区間 / %d メッセージ）" % (
        target, len(rows), sum(1 for fact in facts if not is_continuation(fact))))
    for row in rows:
        print(render_interval(row))
    return 0


def issue_intervals(number: str, repo_id: str, pricing: Pricing, resolver: RepoResolver,
                    at_ms: int | None = None, also=()):
    """(リポジトリ識別子, issue 番号) に帰属する区間と、リポジトリ不明に落ちた区間と、
    区間に切る前の事実の列を返す。

    ``also`` に番号を渡すと、それらの issue の区間も同じ読み取りでまとめて返す（子 issue 込みの
    ``timeline``。台帳への差分の追記も 1 回のまま）。

    ``cost <issue番号>``・``issue``・``timeline --issue`` の共通の入口。``at_ms`` を渡すと、
    その時刻以前の事実だけに絞ってから区間に切る。事実の列は、その issue を触った
    セッションの全行を含む（台帳から絞って読んでもセッション単位で絞るため）ので、
    単価表のずれの突き合わせに読み直さずに渡せる。
    """
    wanted = {number} | {str(other) for other in also}
    facts = list(load_facts(resolver, issue=wanted if also else number))
    if at_ms is not None:
        facts = facts_until(facts, at_ms)
    rows = price_intervals(split_intervals(facts), pricing)
    matched = [r for r in rows if r["issue"] in wanted and r["repo_id"] == repo_id]
    unknown = [r for r in rows if r["issue"] in wanted and r["repo_id"] == UNKNOWN_REPO]
    return matched, unknown, facts


def parse_closing_prs(values, flag: str = "--closing-pr"):
    """``--closing-pr <番号>:<ヘッドブランチ>``（``--child-pr`` も同じ形。``flag`` はエラーに出す名前）の値の列を ``[(番号, ブランチ)]`` にする。

    最初の ``:`` で分け、前が 1 以上の整数、後ろが空でない文字列のときだけ受ける（崩れていれば
    ValueError）。同じヘッドブランチが複数あれば番号のいちばん小さいものだけを残し、番号の昇順に
    並べる（同じブランチの行を 2 回足さない）。
    """
    by_branch = {}
    for value in values or []:
        head, sep, branch = value.partition(":")
        if not sep or not re.fullmatch(r"[0-9]+", head) or int(head) < 1 or not branch:
            raise ValueError("%s は <PR番号>:<ヘッドブランチ> の形で渡してください: %s" % (flag, value))
        number = int(head)
        if branch not in by_branch or number < by_branch[branch]:
            by_branch[branch] = number
    return sorted((number, branch) for branch, number in by_branch.items())


def parse_child_issues(values):
    """``--child-issue <番号>`` の値の列を、重複を除いた昇順の整数の列にする（1 以上の整数でなければ ValueError）。"""
    found = set()
    for value in values or []:
        if not re.fullmatch(r"[0-9]+", value) or int(value) < 1:
            raise ValueError("--child-issue は 1 以上の整数で渡してください: %s" % value)
        found.add(int(value))
    return sorted(found)


def issue_combined_total(matched, closing_prs, pricing: Pricing, resolver: RepoResolver,
                         at_ms: int | None = None) -> dict:
    """issue の合計（spec cost-ledger-attribution）を出す。

    PR の分は、閉じた PR のヘッドブランチごとにそのブランチの行の合計（``/cost <PR番号>`` と
    同じ引き方）。PR の外の分は、区間に帰属した行（``matched`` の各区間の ``facts``）のうち、
    どのヘッドブランチとも一致しない行の合計。1 つの行のブランチは 1 つなので重ならない。
    ``at_ms`` を渡すと PR の分もその時刻以前の行だけを数える（区間の行は呼ぶ側が切ってある）。
    台帳への差分追記はしない（``issue_intervals()`` が 1 回行っている）。
    """
    by_branch = load_branches_facts(resolver, [branch for _number, branch in closing_prs])
    prs, all_facts, total = [], [], 0.0
    for number, branch in closing_prs:
        facts = by_branch[branch] if at_ms is None else facts_until(by_branch[branch], at_ms)
        usd = summarise(facts, pricing)["total_usd"]
        prs.append({"number": number, "branch": branch, "usd": usd})
        all_facts.extend(facts)
        total += usd
    heads = {branch for _number, branch in closing_prs}
    outside = [fact for row in matched for fact in row["facts"] if fact.get("branch") not in heads]
    outside_usd = summarise(outside, pricing)["total_usd"]
    all_facts.extend(outside)
    total += outside_usd
    return {"prs": prs, "outside_usd": outside_usd, "total_usd": total,
            "current": (int(round(total * 1e6)),) + token_totals(all_facts)}


def epic_rows(numbers, repo_id: str, heads, resolver: RepoResolver):
    """対象の issue すべての区間の行と、ヘッドブランチすべての行をまとめて読む。

    返すのは ``({issue の番号: 区間の行}, リポジトリ不明の区間の行, {ヘッドブランチ: 行})``。
    台帳への差分の追記は ``load_facts()`` の 1 回だけで、台帳を読み通す回数は issue の数にも
    PR の数にも比例しない（区間は番号の集合で 1 度に、PR の分は全ブランチを 1 度に読む）。
    """
    wanted = {str(number) for number in numbers}
    facts = list(load_facts(resolver, issue=wanted))
    interval_facts, unknown = defaultdict(list), []
    for row in split_intervals(facts):
        if row["issue"] not in wanted:
            continue
        if row["repo_id"] == repo_id:
            interval_facts[int(row["issue"])].extend(row["facts"])
        elif row["repo_id"] == UNKNOWN_REPO:
            unknown.extend(row["facts"])
    return interval_facts, unknown, load_branches_facts(resolver, heads)


def _micro(facts, pricing: Pricing) -> int:
    """事実の列の金額をマイクロドルの整数にする（``money()`` と同じ 6 桁への丸め）。"""
    return int(round(sum(pricing.cost(fact)[0] for fact in facts) * 1e6))


def assign_epic_rows(issues, interval_facts, branch_facts, unknown_facts, pricing: Pricing) -> dict:
    """エピックの合計（spec cost-ledger-attribution）を出す。``gh`` も台帳も読まない。

    ``issues`` は ``fetch_epic_tree()`` の対象の issue の一覧（先頭がエピック自身）、
    ``interval_facts`` は ``{issue の番号: その issue に帰属した区間の行}``、``branch_facts`` は
    ``{ヘッドブランチ: そのブランチの行}``、``unknown_facts`` はリポジトリ識別子が不明の区間の行。

    行は次の順で 1 つの issue に割り当てる。(1) ブランチ名がどれかのヘッドブランチと一致する行は、
    そのブランチの PR が閉じた対象の issue のうち番号がいちばん小さい issue へ。(2) それ以外の
    区間の行は、その区間の issue へ。1 つの行のブランチは 1 つで、区間は 1 つの issue にしか帰属
    しないので、割り当てた額の和は「行ごとに 1 回だけ足した額」になる。

    金額は、ブランチごと・(issue, ブランチ) ごとにマイクロドルの整数へ丸めてから足し、ドルへの
    変換は最後に行う（割り当てた額の和と合計が、浮動小数の誤差なしで一致するように）。
    """
    owner = {}
    for row in issues:
        for _pr, branch in row["prs"]:
            if branch not in owner or row["number"] < owner[branch]:
                owner[branch] = row["number"]
    branch_micro = {branch: _micro(branch_facts.get(branch, []), pricing) for branch in owner}
    counted = [fact for branch in owner for fact in branch_facts.get(branch, [])]

    result, own, usd, inferred = [], {}, {}, []
    for row in issues:
        number = row["number"]
        by_branch = defaultdict(list)
        for fact in interval_facts.get(number, []):
            by_branch[fact.get("branch")].append(fact)
        heads = {branch for _pr, branch in row["prs"]}
        assigned = sum(branch_micro[branch] for branch in heads if owner[branch] == number)
        standalone = sum(branch_micro[branch] for branch in heads)
        for branch, facts in by_branch.items():
            micro = _micro(facts, pricing)
            if branch not in owner:
                assigned += micro
                counted.extend(facts)
                # 区間で割り当てた行のうち推定で決めた行（ヘッドブランチの経路の行は含めない）
                inferred.extend(fact for fact in facts if fact.get("repo_inferred"))
            if branch not in heads:
                standalone += micro
        own[number] = usd[number] = assigned
        result.append({
            "number": number, "parent": row["parent"], "depth": row["depth"],
            "title": row["title"], "state": row["state"],
            "own_micro": assigned, "standalone_micro": standalone,
            "closing_prs": [{"number": pr, "branch": branch, "usd": branch_micro[branch] / 1e6,
                             "counted_in": owner[branch]} for pr, branch in row["prs"]],
        })
    # 子は必ず親より後ろに並ぶので、後ろから親へ足し上げる
    for row in reversed(result):
        if row["parent"] is not None:
            usd[row["parent"]] += usd[row["number"]]
    for row in result:
        row["usd"] = usd[row["number"]] / 1e6
        row["own_usd"] = row.pop("own_micro") / 1e6
        row["standalone_usd"] = row.pop("standalone_micro") / 1e6
    epic = issues[0]["number"]
    total = sum(own.values())
    unknown = [fact for fact in unknown_facts if fact.get("branch") not in owner]
    return {
        "issues": result,
        "total_usd": total / 1e6,
        "children_usd": (total - own[epic]) / 1e6,
        "self_usd": own[epic] / 1e6,
        "unknown_repo_usd": _micro(unknown, pricing) / 1e6,
        # 同じ応答の 2 行目以降の事実はメッセージ数に数えない（``summarise()`` と同じ）
        "unknown_repo_messages": sum(1 for fact in unknown if not is_continuation(fact)),
        "inferred_repo_usd": _micro(inferred, pricing) / 1e6,
        "inferred_repo_messages": sum(1 for fact in inferred if not is_continuation(fact)),
        "sessions": {fact["session_id"] for fact in counted},
    }


def _dollars(usd: float) -> str:
    """内訳の額。``$`` と小数 2 桁、3 桁区切り（``money()`` と同じく先に 6 桁に揃える）。"""
    return "$" + format(round(usd * 1e6) / 1e6, ",.2f")


def cmd_timeline(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """PR / issue のコメントに積む本文を作る（hook ``gate_report.py`` が呼ぶ）。

    標準入力で既存のコメント本文（無ければ空）を受け、節目の行を 1 行足した本文を標準出力に
    返す。``--issue`` に ``--closing-pr`` が 1 つ以上あれば、続けて issue の合計の行を 1 行足す。
    PR か issue か、issue を閉じた PR はどれかは呼ぶ側が調べて渡すので、ここでは ``gh`` を
    呼ばない。1 行目の対象の表記と帰属の種別は、最後の行が合計の行でなければ ``cmd_cost`` が
    同じ番号に対して作るものと同じ。積むものが無いとき、``--target-repo`` が ``--repo`` の
    場所のリポジトリと違うとき（PR でも issue でも）は、何も出さずに終了コード 3。
    """
    if args.closing_pr and args.issue is None:
        sys.stderr.write("--closing-pr は --issue と一緒にだけ渡せます。\n")
        return 2
    if (args.child_issue or args.child_pr) and args.issue is None:
        sys.stderr.write("--child-issue と --child-pr は --issue と一緒にだけ渡せます。\n")
        return 2
    try:
        closing_prs = parse_closing_prs(args.closing_pr)
        child_prs = parse_closing_prs(args.child_pr, "--child-pr")
        children = parse_child_issues(args.child_issue)
    except ValueError as error:
        sys.stderr.write("%s\n" % error)
        return 2
    try:
        at = float(args.at)
    except ValueError:
        at = float("nan")
    if not math.isfinite(at):
        sys.stderr.write("--at は epoch 秒で渡してください: %s\n" % args.at)
        return 2
    at_ms = int(round(at * 1000))
    body = sys.stdin.read()
    where = os.path.abspath(args.repo) if args.repo else os.getcwd()
    repo_id = resolver.repo_id(where)
    label = resolver.label(repo_id)
    if args.target_repo is not None and resolver.origin(repo_id) != ("github.com", args.target_repo):
        # where（作業中）のリポジトリのコストを、別のリポジトリの PR / issue に書き出さない。
        # 書き込み先は github.com なので、origin のホストも github.com であることまで確かめる。
        # where のリポジトリや origin のホストが判別できないときも一致しないので、ここで止まる
        return 3
    total_row = None  # 合計の行の (きっかけ, 累計)。--issue に --closing-pr があるときだけ作る
    if args.issue is not None:
        number = str(args.issue)
        if repo_id == UNKNOWN_REPO:
            sys.stderr.write(
                "%s は git リポジトリではないため、issue #%s の帰属先リポジトリが決まりません。\n"
                % (where, number)
            )
            return 2
        children = [child for child in children if str(child) != number]
        target, kind = "issue #%s (%s)" % (number, label), "区間"
        if children:
            # 子 issue 込み: エピックと子孫の区間の行と、PR のブランチの行を、行ごとに 1 回だけ数える
            # （累計の相手は ``cost <番号>`` の 1 行目。台帳の差分の追記は 1 回のまま）
            matched, _unknown, _facts = issue_intervals(number, repo_id, pricing, resolver,
                                                        at_ms=at_ms, also=children)
            counted_prs = parse_closing_prs(
                ["%d:%s" % pair for pair in child_prs + closing_prs])
            combined = issue_combined_total(matched, counted_prs, pricing, resolver, at_ms=at_ms)
            total, kind = combined["total_usd"], "子 issue 込み"
            if closing_prs:
                total_row = (timeline_epic_total_trigger(
                    len(children), len(counted_prs), sum(pr["usd"] for pr in combined["prs"]),
                    combined["outside_usd"]), combined["current"])
            current = combined["current"]
        else:
            matched, _unknown, _facts = issue_intervals(number, repo_id, pricing, resolver, at_ms=at_ms)
            facts = [fact for row in matched for fact in row["facts"]]
            total = sum(row["usd"] for row in matched)
            if closing_prs:
                combined = issue_combined_total(matched, closing_prs, pricing, resolver, at_ms=at_ms)
                total_row = (timeline_total_trigger(combined["prs"], combined["outside_usd"]),
                             combined["current"])
            current = (int(round(total * 1e6)),) + token_totals(facts)
    else:
        if not args.branch:
            # ブランチ無しで読むと全履歴の合計になる。PR の数字として返さない
            sys.stderr.write("--pr には --branch（ヘッドブランチ）を一緒に渡してください。\n")
            return 2
        facts = facts_until(load_facts(resolver, branch=args.branch), at_ms)
        total = summarise(facts, pricing)["total_usd"]
        target, kind = "PR #%s (%s)" % (args.pr, args.branch), "ブランチ"
        current = (int(round(total * 1e6)),) + token_totals(facts)
    nothing = current == (0, 0, 0) and (total_row is None or total_row[1] == (0, 0, 0))
    if nothing and not body.strip():
        return 3
    if args.backfill:
        # 後追いだけの 2 つの判定（spec cost-ledger-timeline）。行を足す前に見る
        if timeline_has_trigger_near(parse_timeline(body), args.trigger, at_ms):
            sys.stdout.write(body)  # 同じ出来事の行が既にある。合計の行も足さない
            return 0
        if nothing:
            return 3  # 手元にコストが無い。別の PC が積んだ累計を 0 の行で打ち消さない
    sys.stdout.write(build_timeline(
        body, at_ms, args.trigger, current,
        lambda micro, is_total: headline(
            micro / 1e6, pricing, target,
            "区間+閉じた PR" if is_total and kind == "区間" else kind),
        total=total_row,
    ))
    return 0


def cmd_issue(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """(リポジトリ識別子, issue 番号) の組に帰属する区間を集める。

    issue 番号はリポジトリ内でしか一意でないので、実行した作業ディレクトリの
    リポジトリで絞る。リポジトリが不明に落ちた行は、除外も合算もせず別立てで出す。
    ``--closing-pr`` を渡すと、閉じた PR の分を重ねずに合わせた issue の合計も出す。
    """
    try:
        closing_prs = parse_closing_prs(getattr(args, "closing_pr", None))
    except ValueError as error:
        sys.stderr.write("%s\n" % error)
        return 2
    where = os.path.abspath(args.repo) if args.repo else os.getcwd()
    repo_id = resolver.repo_id(where)
    if repo_id == UNKNOWN_REPO:
        sys.stderr.write(
            "%s は git リポジトリではないため、issue #%s の帰属先リポジトリが決まりません。\n"
            % (where, args.issue)
        )
        return 2
    number = str(args.issue)
    matched, unknown, all_facts = issue_intervals(number, repo_id, pricing, resolver)
    total = sum(row["usd"] for row in matched)
    if closing_prs:
        combined = issue_combined_total(matched, closing_prs, pricing, resolver)
    else:
        combined = {"prs": [], "outside_usd": total, "total_usd": total}
    label = resolver.label(repo_id)
    inferred_usd, inferred_messages = inferred_totals(
        (fact for row in matched for fact in row["facts"]), pricing)
    payload = {
        "issue": number,
        "repo_id": repo_id,
        "repo_label": label,
        "total_usd": total,
        "messages": sum(row["messages"] for row in matched),
        "intervals": [interval_payload(row, resolver) for row in matched],
        "unknown_repo_usd": sum(row["usd"] for row in unknown),
        "unknown_repo_messages": sum(row["messages"] for row in unknown),
        "inferred_repo_usd": inferred_usd,
        "inferred_repo_messages": inferred_messages,
        "usd_jpy_rate": pricing.jpy_rate,
        "closing_prs": combined["prs"],
        "outside_pr_usd": combined["outside_usd"],
        "combined_total_usd": combined["total_usd"],
        "closing_prs_error": bool(getattr(args, "closing_prs_error", False)),
    }
    drift = None
    if not getattr(args, "no_drift_check", False):
        # ここでは最初から全行を読んでいるので、突き合わせのために読み直さない
        sessions = {row["session_id"] for row in matched}
        drift = price_drift(sessions, pricing,
                            facts=[f for f in all_facts if f["session_id"] in sessions])
    payload["price_drift"] = drift
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0
    print(headline(total, pricing, "issue #%s (%s)" % (number, label), "区間"))
    if closing_prs:
        print("  合計（閉じた PR 込み）: %s — %s" % (
            _dollars(combined["total_usd"]),
            " + ".join(["PR #%d %s" % (pr["number"], _dollars(pr["usd"])) for pr in combined["prs"]]
                       + ["PR 外 %s" % _dollars(combined["outside_usd"])])))
    print("  対象: issue #%s（%s）— %d 区間 / %d メッセージ"
          % (number, label, len(matched), payload["messages"]))
    if payload["closing_prs_error"]:
        print("  閉じた PR を読めなかったため、PR の分は合計に入っていません。")
    for row in matched:
        print(render_interval(row))
    if not matched:
        print("  この会話ログにこの issue へ帰属する区間はありません。")
    if unknown:
        print("  リポジトリ不明: %d 件 $%s（cwd が削除済みで、どのリポジトリの #%s か絞れない）"
              % (payload["unknown_repo_messages"],
                 format(payload["unknown_repo_usd"], ",.2f"), number))
    for line in render_inferred(inferred_usd, inferred_messages):
        print(line)
    print("  ※ issue 単位は区間分割による推定です。区間の内訳で寄せ先を確かめてください。")
    for line in render_price_drift(drift):
        print(line)
    return 0


EPIC_TITLE_WIDTH = 40

# 表示の前に空白へ置き換える文字の一般カテゴリ（制御文字・書式文字・行と段落の区切り）
_UNPRINTABLE_CATEGORIES = frozenset(("Cc", "Cf", "Zl", "Zp"))


def _display_text(text: str) -> str:
    """GitHub から取った文字列を、端末に出せる形にする（``--json`` には使わない）。

    制御文字（改行・タブ・ESC・双方向制御文字など）を空白 1 つに置き換え、続いた空白を 1 つに
    畳み、前後の空白を落とす。題名で内訳の行を割ったり、端末の表示を書き換えたりできないように
    するためで、文としての内容は見ない。
    """
    cleaned = "".join(" " if unicodedata.category(char) in _UNPRINTABLE_CATEGORIES else char
                      for char in text)
    return re.sub(" {2,}", " ", cleaned).strip(" ")


def _epic_line(row: dict, has_children: bool) -> str:
    """内訳の 1 行。額はその issue と下の issue すべての和で、段ごとに空白を 2 つ足す。"""
    title = _display_text(row["title"])
    if len(title) > EPIC_TITLE_WIDTH:
        title = title[:EPIC_TITLE_WIDTH - 1] + "…"
    line = "%s#%d %s %s" % ("  " * (row["depth"] + 1), row["number"], row["state"],
                            _dollars(row["usd"]))
    if has_children:
        line += "（自身 %s）" % _dollars(row["own_usd"])
    line += " — %s" % title
    if round(row["own_usd"] * 1e6) != round(row["standalone_usd"] * 1e6):
        line += "（単独 %s%s）" % (
            _dollars(row["standalone_usd"]),
            "".join("、PR #%d は #%d に計上" % (pr["number"], pr["counted_in"])
                    for pr in row["closing_prs"] if pr["counted_in"] != row["number"]))
    return line


def cmd_epic(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """子 issue を持つ issue の、子 issue ごとの内訳と合計を出す（``cost`` から呼ばれる）。

    合計は、エピック自身と子孫の issue が数える行を 1 回ずつ足した額。木を読み切れなければ、
    標準出力に何も書かずに終了コード 2 を返す（一部の子だけの額を合計として見せない）。
    """
    where = os.path.abspath(args.repo) if args.repo else os.getcwd()
    repo_id = resolver.repo_id(where)
    if repo_id == UNKNOWN_REPO:
        sys.stderr.write(
            "%s は git リポジトリではないため、issue #%s の帰属先リポジトリが決まりません。\n"
            % (where, args.issue)
        )
        return 2
    number = int(args.issue)
    try:
        issues, skipped = fetch_epic_tree(where, number)
    except EpicError as error:
        sys.stderr.write(
            "%s。issue #%d の合計は出しません（一部の子 issue しか読めていない額を合計にしないため）。\n"
            % (error, number)
        )
        return 2
    heads = [branch for row in issues for _pr, branch in row["prs"]]
    interval_facts, unknown, branch_facts = epic_rows(
        [row["number"] for row in issues], repo_id, heads, resolver)
    result = assign_epic_rows(issues, interval_facts, branch_facts, unknown, pricing)
    label = resolver.label(repo_id)
    drift = None
    if not getattr(args, "no_drift_check", False):
        # 対象のセッションが多いので、上限つきの読み直しに任せる（facts を渡さない）
        drift = price_drift(result["sessions"], pricing)
    if args.json:
        print(json.dumps({
            "issue": str(number),
            "repo_id": repo_id,
            "repo_label": label,
            "usd_jpy_rate": pricing.jpy_rate,
            "price_drift": drift,
            "total_usd": result["total_usd"],
            "children_usd": result["children_usd"],
            "self_usd": result["self_usd"],
            "issues": result["issues"],
            "skipped": skipped,
            "unknown_repo_usd": result["unknown_repo_usd"],
            "unknown_repo_messages": result["unknown_repo_messages"],
            "inferred_repo_usd": result["inferred_repo_usd"],
            "inferred_repo_messages": result["inferred_repo_messages"],
        }, ensure_ascii=False, indent=2))
        return 0
    print(headline(result["total_usd"], pricing, "issue #%d (%s)" % (number, label), "子 issue 込み"))
    print("  対象: issue #%d（%s）と子孫の issue %d 件" % (number, label, len(issues) - 1))
    print("  子 issue の合計: %s" % _dollars(result["children_usd"]))
    print("  issue #%d 自身: %s" % (number, _dollars(result["self_usd"])))
    parents = {row["parent"] for row in result["issues"]}
    for row in result["issues"]:
        print(_epic_line(row, row["number"] in parents))
    if skipped:
        print("  数えていない子 issue: %s（別のリポジトリ）"
              % "、".join("%s#%d" % (_display_text(row["repo"]), row["number"])
                             for row in skipped))
    if result["unknown_repo_messages"]:
        print("  リポジトリ不明: %d 件 %s（cwd が削除済みで、どのリポジトリの issue か絞れない。"
              "合計には入れていない）"
              % (result["unknown_repo_messages"], _dollars(result["unknown_repo_usd"])))
    for line in render_inferred(result["inferred_repo_usd"], result["inferred_repo_messages"]):
        print(line)
    print("  ※ 額は区間分割による推定です。issue ごとの区間の内訳は /cost <その issue の番号> で"
          "見られます（区間だけの額なので、閉じた PR の分を含むこの内訳の額とは一致しません）。")
    for line in render_price_drift(drift):
        print(line)
    return 0


def cmd_ledger_sync(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """会話ログの増えた分を台帳に追記する（Stop hook と手動の取り込みの共通入口）。"""
    configured = ledger_path()
    if configured is None:
        sys.stderr.write(
            "%s（または userConfig の LEDGER_PATH）が未設定です。台帳ファイルの場所"
            "（このリポジトリの外）を設定してください。\n" % LEDGER_ENV
        )
        return 2
    ledger = resolve_ledger(configured)
    added = ledger_sync(ledger, log_root(), resolver, rescan=args.rescan)
    if not args.quiet:
        print("台帳 %s に %d 行追記しました。" % (ledger, added))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cost_ledger.py",
        description="Claude Code の会話ログから API 換算コストを集計する",
    )
    parser.add_argument("--pricing", default=DEFAULT_PRICING,
                        help="料金表の場所（既定はプラグイン同梱の pricing.json）")
    subparsers = parser.add_subparsers(dest="command", required=True)

    facts = subparsers.add_parser("facts", help="行から抽出した事実を JSONL で出す")
    facts.set_defaults(func=cmd_facts)

    branch = subparsers.add_parser("branch", help="ブランチに帰属するコストを出す")
    branch.add_argument("branch")
    branch.add_argument("--target-label", default=None,
                        help="1 行目に出す帰属先の表記を差し替える（PR 経路が使う）")
    branch.set_defaults(func=cmd_branch)

    intervals = subparsers.add_parser("intervals", help="セッションごとに切った区間を出す")
    intervals.add_argument("--branch", default=None, help="このブランチの行だけを対象にする")
    intervals.add_argument("--json", action="store_true")
    intervals.set_defaults(func=cmd_intervals)

    issue = subparsers.add_parser("issue", help="issue に帰属する区間のコストを出す")
    issue.add_argument("issue")
    issue.add_argument("--repo", default=None,
                       help="帰属先リポジトリを決める場所（既定はカレントディレクトリ）")
    issue.add_argument("--json", action="store_true")
    issue.add_argument("--closing-pr", action="append", default=None,
                       help="issue を閉じた PR を <PR番号>:<ヘッドブランチ> で渡す（繰り返し可）。"
                            "渡すと、重なる行を除いて PR の分を合わせた issue の合計も出す")
    issue.set_defaults(func=cmd_issue)

    cost = subparsers.add_parser(
        "cost", help="番号が PR か issue かを判別してコストを出す（/cost の実体）"
    )
    cost.add_argument("number", nargs="?", default=None,
                      help="PR か issue の番号（省略すると現在のブランチ）")
    cost.add_argument("--repo", default=None,
                      help="問い合わせと絞り込みの基準になる場所（既定はカレントディレクトリ）")
    cost.add_argument("--json", action="store_true",
                      help="issue 経路のときだけ JSON で出す（子 issue を持つ issue では、"
                           "子 issue ごとの内訳つきの JSON になる）")
    cost.add_argument("--no-drift-check", action="store_true",
                      help="単価表のずれの突き合わせ（本体のセッションコストとの比較）を行わない")
    cost.set_defaults(func=cmd_cost)

    timeline = subparsers.add_parser(
        "timeline", help="PR / issue のコメントに積む本文を作る（標準入力は既存の本文）"
    )
    target = timeline.add_mutually_exclusive_group(required=True)
    target.add_argument("--pr", default=None, help="PR の番号（--branch と一緒に渡す）")
    target.add_argument("--issue", default=None, help="issue の番号")
    timeline.add_argument("--branch", default=None, help="PR のヘッドブランチ")
    timeline.add_argument("--trigger", required=True, help="行の「きっかけ」の欄に書く呼び名")
    timeline.add_argument("--at", required=True,
                          help="きっかけの時刻（小数つきの epoch 秒）。累計はこの時刻で切る")
    timeline.add_argument("--repo", default=None,
                          help="作業中のリポジトリの場所。issue の帰属先と --target-repo の照合に使う"
                               "（既定はカレントディレクトリ）")
    timeline.add_argument("--target-repo", default=None,
                          help="書き込み先の owner/repo。--repo のリポジトリと違えば積まない")
    timeline.add_argument("--closing-pr", action="append", default=None,
                          help="issue を閉じた PR を <PR番号>:<ヘッドブランチ> で渡す（繰り返し可。"
                               "--issue と一緒にだけ）。節目の行に続けて issue の合計の行を積む")
    timeline.add_argument("--child-issue", action="append", default=None,
                          help="子孫の issue の番号（繰り返し可。--issue と一緒にだけ）。渡すと、"
                               "節目の行の累計はエピックと子孫の区間と --child-pr のブランチの合計になる")
    timeline.add_argument("--child-pr", action="append", default=None,
                          help="エピックと子孫を閉じた PR を <PR番号>:<ヘッドブランチ> で渡す"
                               "（繰り返し可。--issue と一緒にだけ。--child-issue があるときに使う）")
    timeline.add_argument("--backfill", action="store_true",
                          help="後追い（セッション開始の hook）からの呼び出し。同じきっかけの行が --at の"
                               "近くに既にあれば本文を変えず、手元にコストが無ければ積まない")
    timeline.set_defaults(func=cmd_timeline)

    report = subparsers.add_parser("report", help="全履歴を帰属先ごとに畳んだ監査用の出力")
    report.add_argument("--json", action="store_true")
    report.set_defaults(func=cmd_report)

    ledger = subparsers.add_parser(
        "ledger-sync", help="会話ログの増えた分を台帳（%s）に追記する" % LEDGER_ENV
    )
    ledger.add_argument("--quiet", action="store_true", help="追記した行数を出さない")
    ledger.add_argument("--rescan", action="store_true",
                        help="読み終え位置を使わず会話ログを先頭から読み直し、足りない補足の事実だけを追記する"
                             "（手動で 1 回。実行前に台帳の控えを取る）")
    ledger.set_defaults(func=cmd_ledger_sync)

    return parser


def report_unreadable() -> None:
    """読み取れなかった行があれば件数を出す。JSONL・JSON の出力を汚さないよう stderr へ。"""
    count = SCAN_STATS["unreadable_lines"]
    if count:
        sys.stderr.write(
            "  読み取れなかった行: %d 件（有効な JSON だが期待する形でないため集計から外した）\n"
            % count
        )


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    pricing = Pricing.load(args.pricing)
    resolver = RepoResolver()
    try:
        return args.func(args, pricing, resolver)
    except LedgerError as error:
        sys.stderr.write("%s\n" % error)
        return 2
    finally:
        sys.stdout.flush()
        report_unreadable()


if __name__ == "__main__":
    sys.exit(main())
