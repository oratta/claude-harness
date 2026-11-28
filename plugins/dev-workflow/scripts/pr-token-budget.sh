#!/usr/bin/env bash
# 記録先（issue または Draft PR）単位で、その記録先のために起こしたサブエージェントの
# 全リクエストの usage と、その記録先のために使った Codex の消費を合計し、上限と比べる。
#
#   pr-token-budget.sh <記録先番号>... [--cap <tokens>] [--projects <dir>]
#                      [--codex-records <file>] [--codex-home <dir>]...
#
# 出力（stdout, 1 行 JSON）:
#   {"records":[288],"claude_tokens":7110,"codex_tokens":1550,"total_tokens":8660,
#    "agent_count":3,"codex_threads":3,"cap":30000000,"over_cap":false,"unresolved":0,
#    "codex_unresolved":0,"skipped_lines":0,"agents":[{"name":…,"description":…,"model":…,
#    "tokens":…,"requests":…}],"codex":[{"thread_id":…,"tokens":…,"source":"record|rollout"}]}
# exit code: 0 = 上限以内 / 2 = 上限超過（over_cap）/ 1 = 引数エラー・python3 が無い・
#            カレントディレクトリがリポジトリでない・上限を解決できない（表・上書きの不正、
#            共通処理 token_thresholds.py を読めない。stdout は {"error": …}）
#
# 紐付けの規約（正本は openspec の dev-workflow-pr-token-budget と skills/develop/SKILL.md）:
# - Claude 分: develop の本体は spawn 時の Agent ツールの description に記録先番号を `#N` で入れる。
#   ${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}/*/*/subagents/agent-*.meta.json の description に
#   渡した番号のどれかが `#N`（直後が数字でない）で現れ、作業ディレクトリ（meta の worktreePath、
#   無ければトランスクリプトの最初の cwd）が実行時のリポジトリと同じもの（git common dir で比較。
#   worktree は親に畳む）を数える。識別子が求まらないものは unresolved に数える。
#   1 リクエスト = input + cache_creation + cache_read + output。requestId → message.id → uuid で重複排除。
# - Codex 分: 本体が記録先の `Codex 消費: <thread_id> <tokens>` コメントを scripts/codex-records.sh で集めて作ったファイルを
#   --codex-records で渡す。同じ thread_id は 1 回（最大値）。`-` は --codex-home（無ければ
#   ${CODEX_HOME:-~/.codex}）の sessions/*/*/*/rollout-*-<thread_id>.jsonl の token_count の
#   total_token_usage.total_tokens の最大値を使う。見つからなければ codex_unresolved に数える。
# 上限は total_tokens に 1 本で掛ける。--cap > DEV_WORKFLOW_PR_TOKEN_CAP > モデル別の表（token_thresholds.py）の順。
# 表は数えた各リクエストの message.model ごとに引き、最小値を使う（Codex は含めない。0 件なら fallback を診断なしで）。
# 未知モデル・再検証の診断は stderr に出す（手順: skills/develop/references/token-thresholds.md）。
# このスクリプトは GitHub を読まない。exit 2 のあとの扱いは skills/develop/SKILL.md が正本。
set -uo pipefail

records=()
cap=""
projects="${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}"
codex_records=""
session_records=""
codex_homes=()
usage='usage: pr-token-budget.sh <番号>... [--cap N] [--projects DIR] [--codex-records FILE] [--codex-home DIR]...'
while [ $# -gt 0 ]; do
  case "$1" in
    --cap)
      if [ -z "${2-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then echo '{"error":"--cap needs a non-negative integer"}'; exit 1; fi
      cap="$2"; shift 2 ;;
    --projects)
      if [ -z "${2-}" ]; then echo '{"error":"--projects needs a directory"}'; exit 1; fi
      projects="$2"; shift 2 ;;
    --session-records)
      if [ -z "${2-}" ] || [ ! -f "$2" ]; then echo '{"error":"--session-records needs an existing file"}'; exit 1; fi
      session_records="$2"; shift 2 ;;
    --codex-records)
      if [ -z "${2-}" ] || [ ! -f "$2" ]; then echo '{"error":"--codex-records needs an existing file"}'; exit 1; fi
      codex_records="$2"; shift 2 ;;
    --codex-home)
      if [ -z "${2-}" ]; then echo '{"error":"--codex-home needs a directory"}'; exit 1; fi
      codex_homes+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,31p' "$0"; exit 0 ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then records+=("$1"); shift
      else echo "unknown arg: $1" >&2; echo "$usage" >&2; exit 1; fi ;;
  esac
done
if [ ${#records[@]} -eq 0 ]; then echo "$usage" >&2; exit 1; fi
if [ ${#codex_homes[@]} -eq 0 ]; then codex_homes=("${CODEX_HOME:-$HOME/.codex}"); fi
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 not found"}'; exit 1; }
repo_id="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || repo_id=""
if [ -z "$repo_id" ]; then echo '{"error":"current directory is not a git repository"}'; exit 1; fi

SCRIPT_PATH="${BASH_SOURCE[0]}" RECORDS="${records[*]}" CAP="$cap" PROJECTS="$projects" REPO_ID="$repo_id" \
SESSION_RECORDS="$session_records" CODEX_RECORDS="$codex_records" CODEX_HOMES="$(printf '%s\n' "${codex_homes[@]}")" python3 <<'PY'
import glob, importlib.util, json, os, re, subprocess, sys
from pathlib import Path
sys.dont_write_bytecode = True

records = [int(x) for x in os.environ["RECORDS"].split()]
projects = os.environ["PROJECTS"]
repo_id = os.path.realpath(os.environ["REPO_ID"])
codex_records = os.environ["CODEX_RECORDS"]
codex_homes = [h for h in os.environ["CODEX_HOMES"].split("\n") if h]

num_re = re.compile(r"#(\d+)(?!\d)")
wanted = set(records)
skipped = 0

# 作業ディレクトリ → リポジトリ識別子（git common dir）。同じディレクトリは 1 回だけ git を呼ぶ
repo_cache = {}
def repo_of(path):
    if path not in repo_cache:
        rid = None
        if path and os.path.isdir(path):
            try:
                out = subprocess.run(["git", "-C", path, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                     capture_output=True, text=True, timeout=10)
                if out.returncode == 0 and out.stdout.strip():
                    rid = os.path.realpath(out.stdout.strip())
            except Exception:
                rid = None
        repo_cache[path] = rid
    return repo_cache[path]

def first_cwd(path):
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if isinstance(d, dict) and d.get("cwd"):
                    return d["cwd"]
    except Exception:
        pass
    return None

def n(u, k):
    v = u.get(k)
    return int(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else 0

agents = []
measured_paths = set()
models = set()  # 数えたリクエストの message.model（不明は None）。Codex は入れない
unresolved = 0
for meta_path in sorted(glob.glob(os.path.join(projects, "*", "*", "subagents", "agent-*.meta.json"))):
    try:
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
    except Exception:
        continue
    if not isinstance(meta, dict):
        continue
    desc = meta.get("description") or ""
    if not isinstance(desc, str) or not wanted.intersection(int(m) for m in num_re.findall(desc)):
        continue
    transcript = meta_path[: -len(".meta.json")] + ".jsonl"
    workdir = meta.get("worktreePath") or first_cwd(transcript)
    rid = repo_of(workdir) if isinstance(workdir, str) else None
    if rid is None:
        unresolved += 1
        continue
    if rid != repo_id:
        continue
    measured_paths.add(os.path.realpath(transcript))
    seen = {}
    try:
        with open(transcript, encoding="utf-8") as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    skipped += 1
                    continue
                if not isinstance(d, dict):
                    skipped += 1
                    continue
                if d.get("type") != "assistant":
                    continue
                msg = d.get("message")
                u = msg.get("usage") if isinstance(msg, dict) else None
                if not isinstance(u, dict):
                    skipped += 1
                    continue
                key = d.get("requestId") or (msg.get("id") if isinstance(msg, dict) else None) or d.get("uuid") or line
                model = msg.get("model")
                if not isinstance(model, str) or not model.strip():
                    model = None
                seen[key] = (n(u, "input_tokens") + n(u, "cache_creation_input_tokens")
                             + n(u, "cache_read_input_tokens") + n(u, "output_tokens"), model)
    except FileNotFoundError:
        pass
    agents.append({"name": meta.get("name"), "description": desc, "model": meta.get("model"),
                   "tokens": sum(v[0] for v in seen.values()), "requests": len(seen)})
    models.update(v[1] for v in seen.values())

# Codex: thread_id → 記録されたトークン数の最大値（None は `-` だけの thread）
threads = {}
if codex_records:
    with open(codex_records, encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            if len(parts) != 2 or not (parts[1] == "-" or parts[1].isdigit()):
                skipped += 1
                continue
            tid, tok = parts[0], (None if parts[1] == "-" else int(parts[1]))
            prev = threads.get(tid)
            threads[tid] = tok if prev is None else (prev if tok is None else max(prev, tok))

def rollout_total(tid):
    best = None
    for home in codex_homes:
        # 1 thread あたり glob 1 回。全 rollout は走査しない
        for path in glob.glob(os.path.join(glob.escape(home), "sessions", "*", "*", "*", f"rollout-*-{glob.escape(tid)}.jsonl")):
            try:
                with open(path, encoding="utf-8") as f:
                    for line in f:
                        if '"token_count"' not in line:
                            continue
                        try:
                            d = json.loads(line)
                        except Exception:
                            continue
                        p = d.get("payload") if isinstance(d, dict) else None
                        if d.get("type") != "event_msg" or not isinstance(p, dict) or p.get("type") != "token_count":
                            continue
                        info = p.get("info")
                        t = info.get("total_token_usage") if isinstance(info, dict) else None
                        v = t.get("total_tokens") if isinstance(t, dict) else None
                        if isinstance(v, int) and not isinstance(v, bool):
                            best = v if best is None else max(best, v)
            except Exception:
                continue
    return best

# Explicit sessions are attribution inputs, never a replacement for live usage.
session_errors = []
claude_sessions = []
explicit_claude_tokens = 0
explicit_session_ids = set()
explicit_claude = {}
explicit_codex = {}
coordinator_seen = False
session_file = os.environ.get("SESSION_RECORDS")
if session_file:
    try:
        with open(session_file, encoding="utf-8") as handle:
            rows = handle.readlines()
    except OSError as error:
        rows = []
        session_errors.append({"reason": "records_unreadable", "detail": str(error)})
    for line in rows:
        try:
            row = json.loads(line)
            if not isinstance(row, dict):
                raise ValueError("record must be an object")
            if not isinstance(row.get("records"), list):
                raise ValueError("record numbers missing")
            if not wanted.intersection(row["records"]):
                continue
            common = row.get("repo_common_dir")
            if not isinstance(common, str) or not os.path.isabs(common):
                raise ValueError("repo_common_dir missing")
            if os.path.realpath(common) != repo_id:
                continue
            if row.get("schema_version") != 1 or repo_of(row.get("cwd")) != repo_id:
                raise ValueError("schema/cwd attribution unavailable")
            path = row.get("log_path")
            if not isinstance(path, str) or not os.path.isabs(path):
                raise ValueError("absolute log_path required")
            path = os.path.realpath(path)
            if row.get("provider") == "claude" and row.get("kind") == "role":
                sid = row.get("session_id")
                if not isinstance(sid, str) or not sid or not row.get("role") or not row.get("model"):
                    raise ValueError("Claude identity/role/model missing")
                explicit_claude[(sid, path)] = row
            elif row.get("provider") == "codex" and row.get("kind") == "coordinator":
                tid = row.get("thread_id")
                home = row.get("codex_home")
                if not isinstance(tid, str) or not tid or not isinstance(home, str) or not os.path.isabs(home):
                    raise ValueError("Codex identity/home missing")
                coordinator_seen = True
                explicit_codex[(tid, path)] = row
            else:
                raise ValueError("unknown provider/kind")
        except (ValueError, TypeError, OSError) as error:
            session_errors.append({"reason": "invalid_record", "detail": str(error)})
    if not coordinator_seen:
        session_errors.append({"reason": "coordinator_missing"})

for (sid, path), row in explicit_claude.items():
    seen = {}
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(d, dict):
                    continue
                if d.get("sessionId") and d["sessionId"] != sid:
                    raise ValueError("session ID mismatch")
                if d.get("cwd") and repo_of(d["cwd"]) != repo_id:
                    raise ValueError("transcript cwd mismatch")
                msg = d.get("message")
                u = msg.get("usage") if isinstance(msg, dict) else None
                if d.get("type") != "assistant" or not isinstance(u, dict):
                    continue
                if not any(isinstance(u.get(k), (int, float)) and not isinstance(u.get(k), bool)
                           for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")):
                    continue
                key = d.get("requestId") or msg.get("id") or d.get("uuid") or line
                seen[key] = (sum(n(u, k) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")), msg.get("model"))
        if not seen:
            raise ValueError("usage unavailable")
        if sid in explicit_session_ids:
            continue
        explicit_session_ids.add(sid)
        counted = path not in measured_paths
        claude_sessions.append({"session_id": sid, "log_path": path,
                                "tokens": sum(v[0] for v in seen.values()), "requests": len(seen)})
        if counted:
            explicit_claude_tokens += sum(v[0] for v in seen.values())
            models.update(v[1] if isinstance(v[1], str) else None for v in seen.values())
            measured_paths.add(path)
    except (OSError, ValueError, TypeError) as error:
        session_errors.append({"session_id": sid, "reason": "claude_unresolved", "detail": str(error)})

# Live explicit rollouts are read every time, even when an older numeric comment exists.
for (tid, path), row in explicit_codex.items():
    try:
        home = Path(row["codex_home"]).resolve()
        if home not in Path(path).parents:
            raise ValueError("rollout outside registered home")
        best = None
        identity_seen = False
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(d, dict):
                    continue
                payload = d.get("payload")
                if not isinstance(payload, dict):
                    continue
                if d.get("type") == "session_meta":
                    if payload.get("id") != tid:
                        raise ValueError("thread ID mismatch")
                    identity_seen = True
                if d.get("type") == "event_msg" and payload.get("type") == "token_count":
                    info = payload.get("info")
                    usage = info.get("total_token_usage") if isinstance(info, dict) else None
                    value = usage.get("total_tokens") if isinstance(usage, dict) else None
                    if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
                        best = value if best is None else max(best, value)
        if not identity_seen or best is None:
            raise ValueError("thread identity/usage unavailable")
        threads[tid] = max(threads.get(tid) or 0, best)
    except (OSError, ValueError, TypeError) as error:
        session_errors.append({"thread_id": tid, "reason": "codex_unresolved", "detail": str(error)})

codex = []
codex_unresolved = 0
for tid, tok in threads.items():
    if tok is not None:
        codex.append({"thread_id": tid, "tokens": tok, "source": "record"})
        continue
    v = rollout_total(tid)
    if v is None:
        codex_unresolved += 1
    else:
        codex.append({"thread_id": tid, "tokens": v, "source": "rollout"})

# A session may also be present in legacy subagent discovery. Report it in
# both attribution lists, but include its real log only once in the total.
claude_tokens = sum(a["tokens"] for a in agents) + explicit_claude_tokens
codex_tokens = sum(c["tokens"] for c in codex)
total = claude_tokens + codex_tokens

# 上限の解決。実行中のスクリプトの実体と同じ配布物の共通処理を使い、cwd / Python 環境から探さない。
# 共通処理との境界（取得・callable 確認・呼出し・必須結果の取り出し・診断の準備）で起きた Exception は
# resolver_unavailable、表・上書きの不正（ValueError）はその理由で、どちらも error の JSON と exit 1。
def fail(message):
    print(f"pr-token-budget: {message}", file=sys.stderr)
    print(json.dumps({"records": records, "error": message}, ensure_ascii=False))
    sys.exit(1)

try:
    plugin = Path(os.environ["SCRIPT_PATH"]).resolve().parent.parent
    spec = importlib.util.spec_from_file_location("token_thresholds", plugin / "scripts/token_thresholds.py")
    resolver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(resolver)
    resolve = resolver.resolve_thresholds
    if not callable(resolve):
        raise TypeError("resolve_thresholds is not callable")
except Exception as error:
    fail(f"resolver_unavailable: {type(error).__name__}: {error}")
# 有効な --cap は env を遮る（不正な env も見ない）。無ければ DEV_WORKFLOW_PR_TOKEN_CAP だけを渡す
if os.environ["CAP"]:
    env = {"DEV_WORKFLOW_PR_TOKEN_CAP": os.environ["CAP"]}
else:
    env = {k: os.environ[k] for k in ("DEV_WORKFLOW_PR_TOKEN_CAP",) if k in os.environ}
targets = sorted(models, key=lambda m: (m is not None, m or "")) or [None]
results = []
for model in targets:
    try:
        results.append((model, resolve(model, env)))
    except ValueError as error:
        fail(str(error))
    except Exception as error:
        fail(f"resolver_unavailable: {type(error).__name__}: {error}")
try:
    guide = plugin / "skills/develop/references/token-thresholds.md"
    values = []
    lines = []
    for model, resolved in results:
        value = resolved["thresholds"]["pr_token_cap"]["value"]
        if isinstance(value, bool) or not isinstance(value, int):
            raise TypeError("threshold value is not an integer")
        values.append(value)
        if not models:
            continue  # 数えたリクエストが無ければ、使っていないモデルについて知らせない
        for diagnostic in resolved["diagnostics"]:
            if diagnostic["code"] == "unknown_model":
                line = f"pr-token-budget: {diagnostic['message']}"
            elif diagnostic.get("metric") == "pr_token_cap":
                line = (f"pr-token-budget: revalidation_required: {model or '不明'}; "
                        f"根拠モデル={diagnostic['decided_models']}; 対象=pr_token_cap; 手順={guide}")
            else:
                continue
            if line not in lines:
                lines.append(line)
    cap = min(values)
except Exception as error:
    fail(f"resolver_unavailable: {type(error).__name__}: {error}")
for line in lines:
    print(line, file=sys.stderr)

for error in session_errors:
    print("pr-token-budget: session_unresolved: " + json.dumps(error, ensure_ascii=False), file=sys.stderr)
over = total > cap
print(json.dumps({"records": records, "claude_tokens": claude_tokens, "codex_tokens": codex_tokens,
                  "total_tokens": total, "agent_count": len(agents), "codex_threads": len(codex),
                  "cap": cap, "over_cap": over, "unresolved": unresolved,
                  "codex_unresolved": codex_unresolved, "session_unresolved": len(session_errors),
                  "session_errors": session_errors, "skipped_lines": skipped,
                  "agents": agents, "claude_sessions": claude_sessions, "codex": codex}, ensure_ascii=False))
sys.exit(2 if over else 1 if session_errors else 0)
PY
