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
import json
import math
import os
import re
import sqlite3
import subprocess
import sys
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

class RepoResolver:
    """cwd からリポジトリ識別子（git-common-dir の絶対パス）と表示名を求める。

    識別子に絶対パスを採るのは、ネットワークにも remote の有無にも依存せず、worktree
    と親リポジトリが同じ値に畳まれるから。``owner/repo`` の表示名は origin の URL から
    引き、remote が無ければリポジトリのディレクトリ名に落とす（表示のためだけに使う）。
    """

    def __init__(self):
        self._ids: dict[str, str] = {}
        self._labels: dict[str, str] = {}

    def repo_id(self, cwd: str) -> str:
        if not cwd:
            return UNKNOWN_REPO
        if cwd in self._ids:
            return self._ids[cwd]
        repo_id = UNKNOWN_REPO
        if os.path.isdir(cwd):
            out = _git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir")
            if out:
                repo_id = os.path.realpath(out)
        self._ids[cwd] = repo_id
        return repo_id

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


def resolve_number(where: str, number: str):
    """番号が PR か issue かを GitHub に問い合わせ、``("pr", ヘッドブランチ)`` /
    ``("issue", 番号)`` / ``(None, None)`` を返す。

    問い合わせは REST（``gh api``）だけを使う。GraphQL 経路（``gh pr view --json`` 等）は
    Projects classic の廃止に伴うエラーで落ちるリポジトリがあり、番号の判別という
    コスト計算の入口がそれで止まるのは割に合わない。

    PR を先に見る。``/issues/<番号>`` は PR も返すため、順序を逆にすると PR 番号が
    issue と判定されてブランチ経路に入らない。
    """
    head = _gh(where, "api", "repos/{owner}/{repo}/pulls/%s" % number, "--jq", ".head.ref")
    if head:
        return "pr", head
    found = _gh(where, "api", "repos/{owner}/{repo}/issues/%s" % number, "--jq", ".number")
    if found:
        return "issue", found
    return None, None


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
    return {
        "request_id": record.get("requestId") or record.get("uuid") or "",
        "timestamp": record.get("timestamp") or "",
        # sessionId が無い行は区間を切る単位が消える。ファイルパスに落として混ざるのを防ぐ。
        "session_id": record.get("sessionId") or path,
        "is_sidechain": bool(record.get("isSidechain")),
        "repo_id": resolver.repo_id(record.get("cwd") or ""),
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


def log_files(root: str):
    """会話ログのファイルを決まった順で返す（ディレクトリ内はファイル名順）。"""
    for dirpath, dirs, filenames in os.walk(root):
        dirs.sort()
        for name in sorted(filenames):
            if name.endswith(".jsonl"):
                yield os.path.join(dirpath, name)


def facts_from_lines(lines, path: str, resolver: RepoResolver, seen, branch: str | None = None):
    """会話ログの行の列から事実を返す。``seen`` に入っている requestId は飛ばし、採った分を足す。

    ``seen`` は ``in`` と ``add`` を持てばよい（台帳の索引もこの形で渡す）。requestId も uuid も
    無い行は空文字を鍵にする。
    """
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
        if request_id in seen:
            continue
        try:
            fact = build_fact(record, resolver, path)
        except (AttributeError, TypeError, ValueError):
            # 有効な JSON だが期待する形でない行。ここで落とすと 1 行の不正で
            # 全履歴の集計が終わらなくなる（cwd 削除済みの行と同じ方針）。
            SCAN_STATS["unreadable_lines"] += 1
            continue
        seen.add(request_id)
        yield fact


def iter_facts(root: str, resolver: RepoResolver, branch: str | None = None):
    """会話ログを 1 パスで読み、requestId で重複を排除しながら事実を返す。"""
    seen: set[str] = set()
    for path in log_files(root):
        try:
            handle = open(path, encoding="utf-8", errors="replace")
        except OSError:
            continue
        with handle:
            yield from facts_from_lines(handle, path, resolver, seen, branch)


# --------------------------------------------------------------------------
# 台帳（会話ログが消えたあとも残す append-only の JSONL）
# --------------------------------------------------------------------------

# 台帳の場所を決める唯一の入口。既定のパスは持たない（個人のディレクトリ構成を
# リポジトリに残さないため。LLM_LOG_DIR と同じ扱い）。
LEDGER_ENV = "COST_LEDGER_PATH"

# 台帳の 1 行は build_fact の辞書をそのまま dumps したもので、先頭の鍵が request_id。
# 索引を作るとき、この接頭辞なら JSON をパースせずに requestId を取り出せる。
LEDGER_ID_PREFIX = '{"request_id": "'


class LedgerError(Exception):
    """台帳を使えない（場所が不正・読み書きできない）。終了コード 2 で利用者に伝える。"""


def ledger_path():
    return os.environ.get(LEDGER_ENV) or None


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
        db.execute("CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY, offset INTEGER, ino INTEGER)")
        db.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER)")
        db.execute("SELECT count(*) FROM meta").fetchone()
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
            self.db.execute("DELETE FROM files")
            start = 0
        if start < size:
            with open(ledger, "rb") as fh:
                fh.seek(start)
                data = fh.read(size - start)
            ids = []
            for raw in data.split(b"\n"):
                if not raw.strip():
                    continue
                request_id = _ledger_id(raw.decode("utf-8", errors="replace"))
                if request_id is not None:
                    ids.append((request_id,))
            self.db.executemany("INSERT OR IGNORE INTO ids (id) VALUES (?)", ids)
        self.set_covered(size)
        self.db.commit()

    def __contains__(self, request_id) -> bool:
        return self.db.execute("SELECT 1 FROM ids WHERE id = ?", (request_id,)).fetchone() is not None

    def offsets(self) -> dict:
        return {p: (o, i) for p, o, i in self.db.execute("SELECT path, offset, ino FROM files")}


class _Seen:
    """索引とこの回に採った分を合わせた requestId の集合。"""

    def __init__(self, index: LedgerIndex):
        self.index = index
        self.local: set[str] = set()

    def __contains__(self, request_id) -> bool:
        return request_id in self.local or request_id in self.index

    def add(self, request_id) -> None:
        self.local.add(request_id)


def ledger_sync(ledger: str, root: str, resolver: RepoResolver) -> int:
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
            return _ledger_sync_locked(ledger, root, resolver)
        except (OSError, sqlite3.Error) as error:
            raise LedgerError("台帳 %s へ追記できません: %s" % (ledger, error))


def _ledger_sync_locked(ledger: str, root: str, resolver: RepoResolver) -> int:
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
        for path in log_files(root):
            key = os.path.join(real_root, os.path.relpath(path, root))
            try:
                stat = os.stat(path)
            except OSError:
                continue
            offset, ino = previous.get(key, (0, None))
            if ino != stat.st_ino or not (0 <= offset <= stat.st_size):
                offset = 0
            if offset == stat.st_size:
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
            lines = (raw.decode("utf-8", errors="replace") for raw in data[:end].split(b"\n"))
            for fact in facts_from_lines(lines, path, resolver, seen):
                lines_out.append(json.dumps(fact, ensure_ascii=False))
            new_offsets.append((key, offset + end + 1, stat.st_ino))
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


def iter_ledger_issue_facts(ledger: str, issue: str):
    """台帳のうち、その issue 番号を触った行を持つセッションの事実だけを返す。

    区間は ``session_id`` ごとに切るので、その issue を触った行が 1 つも無いセッションは
    issue の集計に関係しない。1 回目の走査で、issue 番号を持つ行（``"issues": []`` でない行）
    だけを JSON として読んでセッションを集め、2 回目でそのセッションの行だけを JSON として
    読む。重複排除（requestId）は全行を読んだ場合と同じ結果にするため、絞る前の全行で行う。
    """
    handle = _open_ledger(ledger)
    if handle is None:
        return
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
                    and issue in fact["issues"] and isinstance(fact.get("session_id"), str)):
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


def load_facts(resolver: RepoResolver, branch: str | None = None, issue: str | None = None):
    """集計系サブコマンドの事実の入口。

    台帳が設定されていれば、会話ログの増えた分を追記してから台帳だけを読む（読む時点で
    台帳は会話ログの上位集合になるので、会話ログ直読みと同じ値になる）。未設定なら
    会話ログを直接読む。

    ``issue`` を渡すと、台帳からはその issue を触ったセッションの行だけを読む（区間に
    切った結果は全行を読んだ場合と同じ）。会話ログの直読みでは絞らない。
    """
    configured = ledger_path()
    if configured is None:
        return iter_facts(log_root(), resolver, branch=branch)
    ledger = resolve_ledger(configured)
    ledger_sync(ledger, log_root(), resolver)
    if issue is not None and branch is None:
        return iter_ledger_issue_facts(ledger, issue)
    return iter_ledger_facts(ledger, branch=branch)


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


# --------------------------------------------------------------------------
# 区間分割（事実の列だけを入力とする純粋な関数）
# --------------------------------------------------------------------------

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
        rows = sorted(by_session[session_id],
                      key=lambda f: (f["timestamp"], f["request_id"]))
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


def price_intervals(intervals: list, pricing: Pricing) -> list:
    """区間ごとの金額と件数を足す。単価を知るのはここだけで、区間分割は事実だけを見る。"""
    for row in intervals:
        row["usd"] = sum(pricing.cost(fact)[0] for fact in row["facts"])
        row["messages"] = len(row["facts"])
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


def build_timeline(body: str, at_ms: int, trigger: str, current, first_line) -> str:
    """既存の本文に 1 行足した新しい本文を返す（design の決定 3）。

    ``current`` は (マイクロドル, 入出力, キャッシュ)。``first_line`` はマイクロドルから
    1 行目を作る関数。同じ節目（時刻・きっかけ・累計が同じ）が既にあれば ``body`` を返す。
    """
    rows, records = parse_timeline(body)
    if records is None:
        # 記録なし: 既存の行をそのまま残し、増分は (?)。0 から全額増えたとは書かない
        kept, entries = rows, []
        new_row = timeline_row(at_ms, trigger, current, TIMELINE_UNKNOWN)
        position = 0
    else:
        # 行数が記録より多い分は、記録の無い先頭の行としてそのまま残す
        records = records[max(0, len(records) - len(rows)):]
        extra = len(rows) - len(records)
        kept = rows[:extra]
        entries = [[at, _row_trigger(row), values, row]
                   for (at, values), row in zip(records, rows[extra:])]
        key = (at_ms, trigger.encode("utf-8"), current)
        keys = [(at, name.encode("utf-8"), values) for at, name, values, _row in entries]
        if key in keys:
            return body
        position = sum(1 for other in keys if other < key)
        if position > 0:
            previous = entries[position - 1][2]
        else:
            previous = TIMELINE_UNKNOWN if kept else None
        new_row = timeline_row(at_ms, trigger, current, previous)
        if position < len(entries):
            following = entries[position]
            following[3] = timeline_rewrite_increments(following[3], following[2], current)
    entries.insert(position, [at_ms, trigger, current, new_row])
    lines = [first_line(entries[-1][2][0]), "", TIMELINE_HEADER, TIMELINE_SEPARATOR]
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
    return 0


def cmd_cost(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """``/cost`` の入口。番号の判別だけを行い、集計は branch / issue の経路に委ねる。

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
                branch=branch, target_label=None, scope_repo_id=resolver.repo_id(where)
            ),
            pricing,
            resolver,
        )

    kind, value = resolve_number(where, args.number)
    if kind == "pr":
        return cmd_branch(
            argparse.Namespace(
                branch=value, target_label="PR #%s (%s)" % (args.number, value)
            ),
            pricing,
            resolver,
        )
    if kind == "issue":
        return cmd_issue(
            argparse.Namespace(issue=value, repo=where, json=args.json), pricing, resolver
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
        repo_messages[fact["repo_id"]] += 1
        if fact["branch"]:
            branches[fact["branch"]] += usd
        else:
            unattributed += usd
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
            "messages": len(facts),
            "intervals": [interval_payload(row, resolver) for row in rows],
            "usd_jpy_rate": pricing.jpy_rate,
        }, ensure_ascii=False, indent=2))
        return 0
    target = "ブランチ %s" % args.branch if args.branch else "全履歴"
    print(headline(total, pricing, target, "区間"))
    print("  対象: %s（%d 区間 / %d メッセージ）" % (target, len(rows), len(facts)))
    for row in rows:
        print(render_interval(row))
    return 0


def issue_intervals(number: str, repo_id: str, pricing: Pricing, resolver: RepoResolver,
                    at_ms: int | None = None):
    """(リポジトリ識別子, issue 番号) に帰属する区間と、リポジトリ不明に落ちた区間を返す。

    ``cost <issue番号>``・``issue``・``timeline --issue`` の共通の入口。``at_ms`` を渡すと、
    その時刻以前の事実だけに絞ってから区間に切る。
    """
    facts = list(load_facts(resolver, issue=number))
    if at_ms is not None:
        facts = facts_until(facts, at_ms)
    rows = price_intervals(split_intervals(facts), pricing)
    matched = [r for r in rows if r["issue"] == number and r["repo_id"] == repo_id]
    unknown = [r for r in rows if r["issue"] == number and r["repo_id"] == UNKNOWN_REPO]
    return matched, unknown


def cmd_timeline(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """PR / issue のコメントに積む本文を作る（hook ``gate_report.py`` が呼ぶ）。

    標準入力で既存のコメント本文（無ければ空）を受け、行を 1 行足した本文を標準出力に返す。
    PR か issue かは呼ぶ側が判別して渡すので、ここでは ``gh`` を呼ばない。1 行目の対象の
    表記と帰属の種別は ``cmd_cost`` が同じ番号に対して作るものと同じ。積むものが無いときは
    何も出さずに終了コード 3。
    """
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
    if args.issue is not None:
        number = str(args.issue)
        repo_id = resolver.repo_id(where)
        label = resolver.label(repo_id)
        if args.target_repo is not None and args.target_repo != label:
            # issue の集計は where のリポジトリで絞る。別リポジトリの issue に貼る数字ではない
            return 3
        if repo_id == UNKNOWN_REPO:
            sys.stderr.write(
                "%s は git リポジトリではないため、issue #%s の帰属先リポジトリが決まりません。\n"
                % (where, number)
            )
            return 2
        matched, _unknown = issue_intervals(number, repo_id, pricing, resolver, at_ms=at_ms)
        facts = [fact for row in matched for fact in row["facts"]]
        total = sum(row["usd"] for row in matched)
        target, kind = "issue #%s (%s)" % (number, label), "区間"
    else:
        if not args.branch:
            # ブランチ無しで読むと全履歴の合計になる。PR の数字として返さない
            sys.stderr.write("--pr には --branch（ヘッドブランチ）を一緒に渡してください。\n")
            return 2
        facts = facts_until(load_facts(resolver, branch=args.branch), at_ms)
        total = summarise(facts, pricing)["total_usd"]
        target, kind = "PR #%s (%s)" % (args.pr, args.branch), "ブランチ"
    current = (int(round(total * 1e6)),) + token_totals(facts)
    if current == (0, 0, 0) and not body.strip():
        return 3
    sys.stdout.write(build_timeline(
        body, at_ms, args.trigger, current,
        lambda micro: headline(micro / 1e6, pricing, target, kind),
    ))
    return 0


def cmd_issue(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """(リポジトリ識別子, issue 番号) の組に帰属する区間を集める。

    issue 番号はリポジトリ内でしか一意でないので、実行した作業ディレクトリの
    リポジトリで絞る。リポジトリが不明に落ちた行は、除外も合算もせず別立てで出す。
    """
    where = os.path.abspath(args.repo) if args.repo else os.getcwd()
    repo_id = resolver.repo_id(where)
    if repo_id == UNKNOWN_REPO:
        sys.stderr.write(
            "%s は git リポジトリではないため、issue #%s の帰属先リポジトリが決まりません。\n"
            % (where, args.issue)
        )
        return 2
    number = str(args.issue)
    matched, unknown = issue_intervals(number, repo_id, pricing, resolver)
    total = sum(row["usd"] for row in matched)
    label = resolver.label(repo_id)
    payload = {
        "issue": number,
        "repo_id": repo_id,
        "repo_label": label,
        "total_usd": total,
        "messages": sum(row["messages"] for row in matched),
        "intervals": [interval_payload(row, resolver) for row in matched],
        "unknown_repo_usd": sum(row["usd"] for row in unknown),
        "unknown_repo_messages": sum(row["messages"] for row in unknown),
        "usd_jpy_rate": pricing.jpy_rate,
    }
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0
    print(headline(total, pricing, "issue #%s (%s)" % (number, label), "区間"))
    print("  対象: issue #%s（%s）— %d 区間 / %d メッセージ"
          % (number, label, len(matched), payload["messages"]))
    for row in matched:
        print(render_interval(row))
    if not matched:
        print("  この会話ログにこの issue へ帰属する区間はありません。")
    if unknown:
        print("  リポジトリ不明: %d 件 $%s（cwd が削除済みで、どのリポジトリの #%s か絞れない）"
              % (payload["unknown_repo_messages"],
                 format(payload["unknown_repo_usd"], ",.2f"), number))
    print("  ※ issue 単位は区間分割による推定です。区間の内訳で寄せ先を確かめてください。")
    return 0


def cmd_ledger_sync(args, pricing: Pricing, resolver: RepoResolver) -> int:
    """会話ログの増えた分を台帳に追記する（Stop hook と手動の取り込みの共通入口）。"""
    configured = ledger_path()
    if configured is None:
        sys.stderr.write(
            "%s が未設定です。台帳ファイルの場所（このリポジトリの外）を設定してください。\n"
            % LEDGER_ENV
        )
        return 2
    ledger = resolve_ledger(configured)
    added = ledger_sync(ledger, log_root(), resolver)
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
    issue.set_defaults(func=cmd_issue)

    cost = subparsers.add_parser(
        "cost", help="番号が PR か issue かを判別してコストを出す（/cost の実体）"
    )
    cost.add_argument("number", nargs="?", default=None,
                      help="PR か issue の番号（省略すると現在のブランチ）")
    cost.add_argument("--repo", default=None,
                      help="問い合わせと絞り込みの基準になる場所（既定はカレントディレクトリ）")
    cost.add_argument("--json", action="store_true",
                      help="issue 経路のときだけ JSON で出す")
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
                          help="issue の帰属先リポジトリを決める場所（既定はカレントディレクトリ）")
    timeline.add_argument("--target-repo", default=None,
                          help="書き込み先の owner/repo。issue で --repo のリポジトリと違えば積まない")
    timeline.set_defaults(func=cmd_timeline)

    report = subparsers.add_parser("report", help="全履歴を帰属先ごとに畳んだ監査用の出力")
    report.add_argument("--json", action="store_true")
    report.set_defaults(func=cmd_report)

    ledger = subparsers.add_parser(
        "ledger-sync", help="会話ログの増えた分を台帳（%s）に追記する" % LEDGER_ENV
    )
    ledger.add_argument("--quiet", action="store_true", help="追記した行数を出さない")
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
