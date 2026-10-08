#!/usr/bin/env python3
"""SessionStart（matcher startup|resume）hook の本体。`backfill.sh` から起動される。

手元の Bash を通らなかったマージと issue のクローズ（auto-merge のマージ、`Closes` による自動
クローズ）へ、そのリポジトリで次にセッションを始めたときに最後の行を積む（後追い）。
規範の正本は openspec の spec `cost-ledger-backfill`。

- 同期部分（引数なし）: 標準入力の hook JSON から `cwd` と `source` を読むだけ。gh も git も台帳も
  会話ログも控えも触らない。自分自身を `--work <JSON>` で切り離して起こし、すぐ終わる
- 裏の処理（`--work`）: 台帳の場所の確認 → 後追い全体のロック → `cwd` の origin → 許可の一覧
  （`write_allow.allowed()`。origin のリポジトリが載っていなければ gh を 1 回も呼ばずに終わる）→ 控えの
  「前回見た時刻」→ クローズ済みの issue / PR の一覧 1 回 → 候補ごとに（PR は対象の確認）・
  対象ごとのロック・`gate_report.stack()` → 控えの更新。gh は一覧の 1 回に、候補 1 件あたり 3 回
- `COST_LEDGER_HOOK_FOREGROUND=1` のときは切り離さず、その場で最後まで実行する（テストと実測）

行の有無の判定（同じ出来事の行が既にある・手元にコストが無い）は `cost_ledger.py timeline
--backfill` が持ち、読み取りから書き込みまでは `gate_report.stack()` をそのまま使う。ここが持つのは
候補の探し方と「どこまで見たか」の控えだけ。GitHub に書いてよいリポジトリかの判定は
`write_allow.py` が持ち（spec `cost-ledger-write-allowlist`）、ここには一覧の読み方を書き写さない。

どの経路でも stdout・stderr に何も出さず終了コード 0（SessionStart の hook の stdout は会話の
文脈に入る）。
"""
import calendar, fcntl, json, os, subprocess, sys, tempfile, time

import write_allow

FIRST_LOOKBACK = 24 * 3600  # 控えにそのリポジトリの値が無いとき、さかのぼる長さ（秒）
MAX_CANDIDATES = 20         # 1 回の実行で処理する候補の数（同じ秒の候補は超えても分けない）
SKIP_SOURCES = ("clear", "compact")  # 同じセッションの続き。matcher を通らずに来た場合の二重の確認
# 一覧の要素を 1 件 1 行にする。--paginate の出力は複数ページだと配列が連結されるので、全体を
# 1 つの JSON として読まない（gate_report.existing_comment と同じ読み方）。使う項目だけを取り出す
LIST_JQ = ('.[] | {number, state, updated_at, closed_at, is_pr: has("pull_request"), '
           'merged_at: (.pull_request.merged_at // null)} | tojson')
ISO = "%Y-%m-%dT%H:%M:%SZ"


def main():
    payload = json.loads(sys.stdin.read())
    if not isinstance(payload, dict) or not isinstance(payload.get("cwd"), str):
        return
    if payload.get("source") in SKIP_SOURCES:
        return
    if os.environ.get("GH_HOST", "").lower() not in ("", "github.com"):
        return  # 引き継いだ GH_HOST が github.com 以外。積む対象は github.com だけ（gate_report.build_job と同じ）
    job = {"cwd": payload["cwd"]}
    if os.environ.get("COST_LEDGER_HOOK_FOREGROUND") == "1":
        work(job)
        return
    subprocess.Popen([sys.executable, os.path.abspath(__file__), "--work", json.dumps(job)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)


# --------------------------------------------------------------------------
# 裏の処理
# --------------------------------------------------------------------------

def epoch(text):
    """GitHub の時刻（UTC の ISO 8601、秒まで）を epoch 秒にする。読めなければ ValueError。"""
    if not isinstance(text, str):
        raise ValueError(text)
    return calendar.timegm(time.strptime(text, ISO))


def iso(seconds):
    return time.strftime(ISO, time.gmtime(seconds))


def read_state(path):
    """控えファイルの中身。無い・読めない・形が崩れているときは空の控え。"""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("repos"), dict):
            return data
    except (OSError, ValueError):
        pass
    return {"version": 1, "repos": {}}


def seen_until(state, key):
    """そのリポジトリの前回見た時刻（epoch 秒）。値が無い・読めないときは None。"""
    try:
        return epoch(state["repos"][key]["seen_until"])
    except (KeyError, TypeError, ValueError):
        return None


def write_seen(path, key, value):
    """前回見た時刻を進める。他のリポジトリの値は残し、今の値より前には戻さない。同じディレクトリの
    一時ファイルに書いてから置き換える。"""
    state = read_state(path)
    current = seen_until(state, key)
    if current is not None and value <= current:
        return
    state["version"] = 1
    state["repos"][key] = {"seen_until": iso(value)}
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=os.path.basename(path) + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(state, f, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def list_closed(gate_report, repo, since):
    """クローズ済みの issue / PR のうち since 以降に更新されたものの一覧（gh api を 1 回）。
    呼び出しの失敗・1 行でも読めない・形が崩れているときは None（読めたページまでで進めない）。"""
    p = gate_report.gh_api([
        "--paginate",
        "repos/%s/issues?state=closed&since=%s&sort=updated&direction=asc&per_page=100" % (repo, iso(since)),
        "--jq", LIST_JQ])
    if p is None or p.returncode != 0:
        return None
    items = []
    for line in p.stdout.splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
            if not isinstance(item, dict) or type(item.get("number")) is not int or item["number"] < 1:
                return None
            items.append({
                "number": item["number"],
                "is_pr": item.get("is_pr") is True,
                "closed": item.get("state") == "closed",
                "updated": epoch(item.get("updated_at")),
                "merged": None if item.get("merged_at") is None else epoch(item["merged_at"]),
                "closed_at": None if item.get("closed_at") is None else epoch(item["closed_at"]),
            })
        except ValueError:
            return None
    return items


def candidates(items, since):
    """一覧から、出来事の時刻が since より後のものを (出来事の時刻, 番号, 種別) の昇順で返す。
    マージ済みの PR（時刻は merged_at）と、PR でないクローズ済みの issue（時刻は closed_at）だけ。"""
    found = []
    for item in items:
        if item["merged"] is not None:
            kind, at = "pr", item["merged"]
        elif not item["is_pr"] and item["closed"] and item["closed_at"] is not None:
            kind, at = "issue", item["closed_at"]
        else:
            continue  # マージされずに閉じられた PR など
        if at > since:
            found.append((at, item["number"], kind))
    return sorted(found)


def take(found):
    """今回処理する分と残り。MAX_CANDIDATES 件目と出来事の時刻が同じ候補は同じ回に含める
    （前回見た時刻は秒で区切るので、同じ秒のものを分けると後ろが落ちる）。"""
    cut = min(len(found), MAX_CANDIDATES)
    while 0 < cut < len(found) and found[cut][0] == found[cut - 1][0]:
        cut += 1
    return found[:cut], found[cut:]


def merged_head(gate_report, repo, number, cwd, at):
    """候補の PR を確かめ、積んでよければヘッドブランチを返す（1 回問い合わせる）。マージ済み・
    ベースが一覧のリポジトリ・ヘッドも同じリポジトリ（fork でない）・ヘッドブランチが空でない、の
    どれかが欠ければ None。"""
    data = gate_report.gh_json("repos/%s/pulls/%d" % (repo, number), cwd)
    if not isinstance(data, dict) or not gate_report.pr_checks(data, at)["マージ"]:
        return None
    base = ((data.get("base") or {}).get("repo") or {}).get("full_name")
    head = data.get("head") or {}
    head_repo = (head.get("repo") or {}).get("full_name")
    branch = head.get("ref")
    if not isinstance(base, str) or base.lower() != repo.lower():
        return None
    if not isinstance(head_repo, str) or head_repo.lower() != base.lower():
        return None  # fork の PR。同じ名前の手元のブランチのコストを引き込まない
    return branch if isinstance(branch, str) and branch else None


def stack_one(gate_report, repo, cwd, scripts_dir, at, number, kind):
    if kind == "pr":
        branch, names = merged_head(gate_report, repo, number, cwd, at), ["マージ"]
        if branch is None:
            return
    else:
        # 一覧が closed を返しているので、対象の確認の問い合わせは足さない
        branch, names = None, ["issue クローズ"]
    fd = gate_report.lock(repo, number)
    if fd is None:
        return
    try:
        # 行の時刻と累計を切る時刻は、GitHub が記録した出来事の時刻（セッションを始めた時刻ではない）
        gate_report.stack(kind, repo, number, branch, names, "%.3f" % at, cwd, scripts_dir,
                          extra=["--backfill"])
    finally:
        os.close(fd)  # 閉じるとロックも外れる


def sweep(cost_ledger, gate_report, ledger, cwd, scripts_dir):
    resolver = cost_ledger.RepoResolver()
    origin = resolver.origin(resolver.repo_id(cwd))
    if origin is None or origin[0] != "github.com":
        return  # git リポジトリでない・origin が無い・github.com でない
    repo = origin[1]
    if gate_report.full_name(repo) != repo:
        return  # gh api のパスに置けない名前
    # 一覧の取得も書き込みも、相手は origin のこのリポジトリだけ。許可の一覧に無ければ、どの候補にも
    # 書かないことが決まっているので、gh を 1 回も呼ばず、控えも読み書きせずに終わる
    if not write_allow.allowed(repo, cwd):
        return
    key, state_path = repo.lower(), ledger + ".backfill.json"
    since = seen_until(read_state(state_path), key)
    if since is None:
        since = int(time.time()) - FIRST_LOOKBACK  # ここだけ手元の時計を使う
    items = list_closed(gate_report, repo, since)
    if items is None:
        return  # 一覧の失敗。何も積まず、控えも変えない（次のセッション開始でやり直す）
    chosen, rest = take(candidates(items, since))
    for at, number, kind in chosen:
        try:
            stack_one(gate_report, repo, cwd, scripts_dir, at, number, kind)
        except Exception:
            pass  # 候補ごとの失敗では止めない（その 1 件に行が付かないまま先へ進む）
    if rest:
        write_seen(state_path, key, chosen[-1][0])
    elif items:
        # 手元の時計ではなく GitHub の時刻で進める（次の一覧と同じ基準で比べられる）
        write_seen(state_path, key, max(item["updated"] for item in items))


def work(job):
    cwd = job.get("cwd")
    if not isinstance(cwd, str):
        return
    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, scripts_dir)
    import cost_ledger, gate_report
    # 全体停止は一覧より先に効く。backfill.sh を通らずに直接起動されても gh を呼ばない
    # （読み方は backfill.sh と同じ: 値が off のときだけ）
    if "off" in (os.environ.get("COST_LEDGER_GATE_REPORT"), os.environ.get("COST_LEDGER_BACKFILL")):
        return
    configured = cost_ledger.ledger_path()
    if configured is None:
        return
    try:
        ledger = cost_ledger.resolve_ledger(configured)
    except cost_ledger.LedgerError:
        return  # プラグインのリポジトリの配下。控えを書かない
    os.makedirs(os.path.dirname(ledger), exist_ok=True)
    fd = os.open(ledger + ".backfill.lock", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return  # 別の後追いが実行中。待たずに終わる
        sweep(cost_ledger, gate_report, ledger, cwd, scripts_dir)
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        if len(sys.argv) >= 3 and sys.argv[1] == "--work":
            work(json.loads(sys.argv[2]))
        else:
            main()
    except BaseException:
        pass
    sys.exit(0)
