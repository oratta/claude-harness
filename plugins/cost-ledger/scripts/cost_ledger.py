#!/usr/bin/env python3
"""cost-ledger — Claude Code の会話ログから API 換算コストを集計する。

読むのは ``${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects`` 配下の JSONL。
アシスタントの 1 メッセージが 1 行で、``gitBranch`` / ``cwd`` / ``sessionId`` /
``timestamp`` / ``isSidechain`` / ``message.model`` / ``message.usage`` /
``requestId`` / ツール呼び出しの入力を持つ。

設計上の要点:

- **事実の抽出と帰属の導出を分ける。** 1 行から取るのは事実だけで、区間の帰属は
  事実の列に対する関数として別に導く。区間の帰属は次の投稿が来るまで確定しないので、
  1 行ずつ追記する経路（後続の台帳）が書けるのは事実の側に限られる。
- **単価と換算レートはこのファイルに書かない。** 隣の ``pricing.json`` だけが持つ。
- **速度は 1 行目の文字列判定に依存する。** JSON にパースする前に生の行へ
  ``"assistant"`` が含まれるかで弾く。パースしてから判定すると桁違いに遅くなる。
"""

from __future__ import annotations

import argparse
import json
import os
import re
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


def iter_facts(root: str, resolver: RepoResolver, branch: str | None = None):
    """会話ログを 1 パスで読み、requestId で重複を排除しながら事実を返す。"""
    seen: set[str] = set()
    for dirpath, _dirs, filenames in os.walk(root):
        for name in sorted(filenames):
            if not name.endswith(".jsonl"):
                continue
            path = os.path.join(dirpath, name)
            try:
                handle = open(path, encoding="utf-8", errors="replace")
            except OSError:
                continue
            with handle:
                for line in handle:
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
                    request_id = record.get("requestId") or record.get("uuid")
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
    for fact in iter_facts(log_root(), resolver):
        sys.stdout.write(json.dumps(fact, ensure_ascii=False) + "\n")
    return 0


def cmd_branch(args, pricing: Pricing, resolver: RepoResolver) -> int:
    facts = list(iter_facts(log_root(), resolver, branch=args.branch))
    summary = summarise(facts, pricing)
    label = branch_label(facts, resolver)
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
        return cmd_branch(
            argparse.Namespace(branch=branch, target_label=None), pricing, resolver
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
    facts = list(iter_facts(log_root(), resolver))
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
    facts = list(iter_facts(log_root(), resolver, branch=args.branch))
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
    rows = price_intervals(split_intervals(list(iter_facts(log_root(), resolver))), pricing)
    matched = [r for r in rows if r["issue"] == number and r["repo_id"] == repo_id]
    unknown = [r for r in rows if r["issue"] == number and r["repo_id"] == UNKNOWN_REPO]
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

    report = subparsers.add_parser("report", help="全履歴を帰属先ごとに畳んだ監査用の出力")
    report.add_argument("--json", action="store_true")
    report.set_defaults(func=cmd_report)

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
    finally:
        sys.stdout.flush()
        report_unreadable()


if __name__ == "__main__":
    sys.exit(main())
