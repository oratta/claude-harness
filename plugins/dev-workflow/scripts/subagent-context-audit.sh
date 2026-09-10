#!/usr/bin/env bash
# subagent-context-audit.sh — サブエージェントのコンテキスト量を母集団で測る（観測専用）。
#
#   subagent-context-audit.sh [--days N] [--cap N] [--projects DIR]
#                             [--cache FILE] [--refresh] [-h|--help]
#
# 出力（stdout, 1 行 JSON）:
#   {"count":44,"first_median":54300,"first_max":98000,"last_median":121000,
#    "last_max":312000,"over_cap_pct":31.8,"cap":150000,"days":14,
#    "sources":{"isolated":{"count":12,"first_median":...,"last_median":...,"over_cap_pct":...},
#               "non_isolated":{...}},
#    "generated_at":"2026-09-09T12:00:00Z"}
# exit code: 0 = 常に（fail-open）/ 1 = 引数エラーのみ
#
# 何のためのものか: `subagent-context.sh` は「今この 1 体がいくら読んでいるか」を測る。
# こちらは母集団の傾向（起動直後の固定分が増えていないか、上限を超えて再開できない割合が
# 増えていないか）を測る。読み方の正本は plugins/dev-workflow/docs/usage-audit.md。
#
# 走査経路: <projects>/*/*/subagents/agent-*.jsonl の 1 経路だけ。isolation: "worktree" の
# サブエージェントも同じ場所に置かれ、変わるのはファイル名だけなので、この 1 経路で
# 隔離ありも含まれる。`subagents/` の外（メインセッション・worktree の中から起動された
# 入れ子の claude セッション）と Workflow 経由（subagents/workflows/<wf-id>/）は含まない。
# 隔離の有無は隣の agent-<id>.meta.json の spawnedWithWorktree で分類し、meta が
# 無い / 壊れているときは non_isolated に寄せる（全体の count からは落とさない）。
#
# コンテキスト量の定義は subagent-context.sh と同一:
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# 初回はファイル先頭から最初の usage 付き assistant レコード、最終は末尾から
# 256 KiB の窓を後ろ向きに探索（見つからなければ 4 MiB まで倍加）。全文は読まない。
#
# キャッシュ: 結果は --cache（既定 ${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}）
# に 1 行 JSON で残す。mtime が SUBAGENT_CONTEXT_AUDIT_TTL（秒、既定 21600）以内なら
# 走査せずその内容を返す。--refresh で TTL を無視して再走査する。走査できなかった結果
# （projects ディレクトリが無い / 読めないディレクトリがあった / python3 が無い）は
# キャッシュに書かない。TTL のあいだ空の結果を正解として配ってしまうため。
#
# この集計は観測専用で、閾値による停止・警告は行わない（強制停止は別の仕組みが担う）。
set -uo pipefail

days=14
cap="${DEV_WORKFLOW_CONTEXT_CAP:-150000}"
projects="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
cache="${SUBAGENT_CONTEXT_AUDIT_CACHE:-$HOME/.claude/.subagent-context-audit}"
ttl="${SUBAGENT_CONTEXT_AUDIT_TTL:-21600}"
refresh=0

die_arg() { echo "{\"error\":\"$1\"}" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --days)
      [ -n "${2-}" ] && [[ "$2" =~ ^[0-9]+$ ]] || die_arg "--days needs a non-negative integer"
      days="$2"; shift 2 ;;
    --cap)
      [ -n "${2-}" ] && [[ "$2" =~ ^[0-9]+$ ]] || die_arg "--cap needs a non-negative integer"
      cap="$2"; shift 2 ;;
    --projects)
      [ -n "${2-}" ] || die_arg "--projects needs a directory"
      projects="$2"; shift 2 ;;
    --cache)
      [ -n "${2-}" ] || die_arg "--cache needs a file path"
      cache="$2"; shift 2 ;;
    --refresh) refresh=1; shift ;;
    -h|--help) sed -n '2,37p' "$0"; exit 0 ;;
    *) die_arg "unknown arg: $1" ;;
  esac
done
[[ "$cap" =~ ^[0-9]+$ ]] || die_arg "DEV_WORKFLOW_CONTEXT_CAP must be a non-negative integer"
[[ "$ttl" =~ ^[0-9]+$ ]] || die_arg "SUBAGENT_CONTEXT_AUDIT_TTL must be a non-negative integer"

# TTL 内のキャッシュがあれば、トランスクリプトを 1 個も開かずにそれを返す。
if [ "$refresh" -eq 0 ] && [ -s "$cache" ] && [ "$ttl" -gt 0 ]; then
  # GNU（-c）を先に試す。逆順にすると Linux で `stat -f` が「ファイルシステム情報の
  # 表示」として扱われ（BSD の -f=フォーマット指定とは別物）、mtime ではない文字列が
  # stdout に出て || のフォールバックに落ちない。macOS の stat は -c を不正オプションと
  # して非0終了するため、この順序なら両プラットフォームで mtime が取れる
  # （usage-probe.sh / statusline.sh と同じ理由）。
  mt="$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo '')"
  # 数値でなければキャッシュを使わず走査に落とす。ここで弾かないと、mtime でない文字列が
  # そのまま算術展開に入って構文エラーになり、監査自体が非0終了する（fail-open に反する）。
  [[ "$mt" =~ ^[0-9]+$ ]] || mt=""
  if [ -n "$mt" ] && [ $(( $(date +%s) - mt )) -le "$ttl" ]; then
    cat "$cache"
    exit 0
  fi
fi

# python3 が無い環境でも監査の呼び出し側を巻き込まない（空の結果を出して exit 0）。
if ! command -v python3 >/dev/null 2>&1; then
  printf '{"count": 0, "first_median": null, "first_max": null, "last_median": null, "last_max": null, "over_cap_pct": 0.0, "cap": %s, "days": %s, "sources": {"isolated": {"count": 0, "first_median": null, "last_median": null, "over_cap_pct": 0.0}, "non_isolated": {"count": 0, "first_median": null, "last_median": null, "over_cap_pct": 0.0}}, "generated_at": null, "note": "python3 not found"}\n' "$cap" "$days"
  exit 0
fi

CAP="$cap" DAYS="$days" PROJECTS="$projects" CACHE="$cache" python3 <<'PY'
import datetime, json, os, sys, time

cap = int(os.environ["CAP"])
days = int(os.environ["DAYS"])
projects = os.environ["PROJECTS"]
cache = os.environ["CACHE"]

WINDOW = 256 * 1024          # 最終コンテキストを探す末尾の窓（既定）
WINDOW_MAX = 4 * 1024 * 1024 # 窓の倍加上限。これを超えたらその件は最終不明


def ctx_of(line):
    """assistant レコードなら input + cache_creation + cache_read を返す。それ以外は None。"""
    try:
        d = json.loads(line)
    except Exception:
        return None
    if not isinstance(d, dict) or d.get("type") != "assistant":
        return None
    msg = d.get("message")
    u = msg.get("usage") if isinstance(msg, dict) else None
    if not isinstance(u, dict):
        return None

    total = 0
    for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
        v = u.get(k)
        if isinstance(v, bool) or not isinstance(v, (int, float)):
            continue  # 欠けている / 数値でない項目は 0 として足す
        try:
            total += int(v)
        except (OverflowError, ValueError):
            # 1e999（inf）や NaN は実在のトークン数ではない。JSON としては妥当なので
            # 例外を投げずに「usage の無い行」として飛ばす（例外を上げると exit 1 になり
            # fail-open に反する）。
            return None
    return total


def first_ctx(path):
    """先頭から読み、最初の usage 付き assistant レコードで打ち切る（全文を読まない）。"""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                v = ctx_of(line)
                if v is not None:
                    return v
    except Exception:
        pass
    return None


def last_ctx(path):
    """末尾から窓を読んで後ろ向きに探索。見つからなければ窓を倍加し、上限で諦める。"""
    try:
        size = os.path.getsize(path)
    except Exception:
        return None
    win = WINDOW
    while True:
        start = max(0, size - win)
        try:
            with open(path, "rb") as f:
                # 窓の 1 バイト手前から読む。そこが改行なら窓の先頭はちょうど行頭なので、
                # 先頭行は完全な行として残す（捨てると最終 usage 行を 1 件落とす）。
                f.seek(max(0, start - 1))
                chunk = f.read()
        except Exception:
            return None
        head_is_partial = False
        if start > 0:
            head_is_partial = chunk[:1] != b"\n"
            chunk = chunk[1:]
        lines = chunk.decode("utf-8", "replace").split("\n")
        if head_is_partial:
            lines = lines[1:]  # 窓の先頭が行の途中で切れているときだけ捨てる
        for line in reversed(lines):
            v = ctx_of(line)
            if v is not None:
                return v
        if start == 0 or win >= WINDOW_MAX:
            return None
        win *= 2


def is_isolated(path):
    """隣の agent-<id>.meta.json の spawnedWithWorktree で分類。読めなければ False（non_isolated）。"""
    meta = path[: -len(".jsonl")] + ".meta.json"
    try:
        with open(meta, encoding="utf-8") as f:
            d = json.load(f)
    except Exception:
        return False
    return bool(isinstance(d, dict) and d.get("spawnedWithWorktree"))


def median(vals):
    """偶数件は中央 2 値の平均を四捨五入した整数。空なら None。"""
    if not vals:
        return None
    s = sorted(vals)
    n = len(s)
    if n % 2:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2] + 1) // 2


def summarize(items):
    """items = [(first, last), ...] から件数・中央値・最大・上限超割合を出す。
    first / last の母数は互いに独立で、last 側は最終が見つかった件だけを数える。"""
    firsts = [f for f, _ in items if f is not None]
    lasts = [l for _, l in items if l is not None]
    over = sum(1 for l in lasts if l > cap)
    return {
        "count": len(items),
        "first_median": median(firsts),
        "first_max": max(firsts) if firsts else None,
        "last_median": median(lasts),
        "last_max": max(lasts) if lasts else None,
        "over_cap_pct": round(100.0 * over / len(lasts), 1) if lasts else 0.0,
    }


def source_view(items):
    """sources.* は count / first_median / last_median / over_cap_pct の 4 キーに絞る。"""
    s = summarize(items)
    return {k: s[k] for k in ("count", "first_median", "last_median", "over_cap_pct")}


def scan(root):
    """<root>/*/*/subagents/agent-*.jsonl を集めて (パスの列, 走査に失敗したか) を返す。

    glob は走査に失敗しても空リストを返すので「該当 0 件」と「読めなかった」を
    区別できない。ここは自前で listdir し、1 つでも読めないディレクトリがあれば
    incomplete=True を立てる。呼び出し側はその結果をキャッシュに書かない
    （権限が戻っても TTL のあいだ空の結果を配り続けてしまうため）。"""
    incomplete = False

    def listdir(d):
        nonlocal incomplete
        try:
            return sorted(os.listdir(d))
        except OSError:
            incomplete = True
            return []

    paths = []
    for slug in listdir(root):
        if slug.startswith("."):
            continue
        d1 = os.path.join(root, slug)
        if not os.path.isdir(d1):
            continue
        for sess in listdir(d1):
            if sess.startswith("."):
                continue
            d2 = os.path.join(d1, sess, "subagents")
            if not os.path.isdir(d2):
                continue
            for name in listdir(d2):
                if name.startswith("agent-") and name.endswith(".jsonl"):
                    paths.append(os.path.join(d2, name))
    return sorted(paths), incomplete


def emit(result, write_cache):
    line = json.dumps(result, ensure_ascii=False)
    print(line)
    if write_cache:
        try:
            d = os.path.dirname(cache)
            if d:
                os.makedirs(d, exist_ok=True)
            tmp = "%s.tmp.%d" % (cache, os.getpid())
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(line + "\n")
            os.replace(tmp, cache)
        except Exception:
            pass  # キャッシュに書けなくても集計結果は出す（fail-open）
    sys.exit(0)


now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# projects ディレクトリが無い環境（別 PC 等）でも止めない。この場合はキャッシュを
# 更新しない — 走査できなかった結果を TTL のあいだ正解として配りたくないため。
if not os.path.isdir(projects):
    empty = summarize([])
    empty.update({"cap": cap, "days": days, "generated_at": now,
                  "sources": {"isolated": source_view([]), "non_isolated": source_view([])},
                  "note": "projects dir not found"})
    emit(empty, write_cache=False)

# 走査は固定深さの 1 経路だけ。Workflow 経由（subagents/workflows/<wf-id>/agent-*.jsonl）は
# 階層が深いのでこの経路に当たらず、母集団に入らない（仕様どおり）。
paths, incomplete = scan(projects)
cutoff = time.time() - days * 86400

isolated, non_isolated = [], []
for path in paths:
    try:
        if os.path.getmtime(path) < cutoff:
            continue
    except Exception:
        continue
    try:
        entry = (first_ctx(path), last_ctx(path))
    except Exception:
        entry = (None, None)  # 1 個の壊れたファイルで集計全体を止めない
    (isolated if is_isolated(path) else non_isolated).append(entry)

result = summarize(isolated + non_isolated)
result.update({
    "cap": cap,
    "days": days,
    "sources": {"isolated": source_view(isolated), "non_isolated": source_view(non_isolated)},
    "generated_at": now,
})
if incomplete:
    # 読めないディレクトリがあった＝この結果は母集団の全部ではない。出しはするが
    # キャッシュには書かず、次回また走査させる。
    result["note"] = "scan incomplete (unreadable directories)"
emit(result, write_cache=not incomplete)
PY
