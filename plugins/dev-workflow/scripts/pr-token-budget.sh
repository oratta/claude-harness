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
#            カレントディレクトリがリポジトリでない
#
# 紐付けの規約（正本は openspec の dev-workflow-pr-token-budget と skills/develop/SKILL.md）:
# - Claude 分: develop の本体は spawn 時の Agent ツールの description に記録先番号を `#N` で入れる。
#   ${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*.meta.json の description に
#   渡した番号のどれかが `#N`（直後が数字でない）で現れ、作業ディレクトリ（meta の worktreePath、
#   無ければトランスクリプトの最初の cwd）が実行時のリポジトリと同じもの（git common dir で比較。
#   worktree は親に畳む）を数える。識別子が求まらないものは unresolved に数える。
#   1 リクエスト = input + cache_creation + cache_read + output。requestId → message.id → uuid で重複排除。
# - Codex 分: 本体が記録先の `Codex 消費: <thread_id> <tokens>` コメントを scripts/codex-records.sh で集めて作ったファイルを
#   --codex-records で渡す。同じ thread_id は 1 回（最大値）。`-` は --codex-home（無ければ
#   ${CODEX_HOME:-~/.codex}）の sessions/*/*/*/rollout-*-<thread_id>.jsonl の token_count の
#   total_token_usage.total_tokens の最大値を使う。見つからなければ codex_unresolved に数える。
# 上限は total_tokens に 1 本で掛ける。--cap > DEV_WORKFLOW_PR_TOKEN_CAP > 30000000 の順。
# このスクリプトは GitHub を読まない。exit 2 のあとの扱いは skills/develop/SKILL.md が正本。
set -uo pipefail

records=()
cap="${DEV_WORKFLOW_PR_TOKEN_CAP:-30000000}"
projects="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
codex_records=""
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
    --codex-records)
      if [ -z "${2-}" ] || [ ! -f "$2" ]; then echo '{"error":"--codex-records needs an existing file"}'; exit 1; fi
      codex_records="$2"; shift 2 ;;
    --codex-home)
      if [ -z "${2-}" ]; then echo '{"error":"--codex-home needs a directory"}'; exit 1; fi
      codex_homes+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then records+=("$1"); shift
      else echo "unknown arg: $1" >&2; echo "$usage" >&2; exit 1; fi ;;
  esac
done
if [ ${#records[@]} -eq 0 ]; then echo "$usage" >&2; exit 1; fi
if ! [[ "$cap" =~ ^[0-9]+$ ]]; then echo '{"error":"DEV_WORKFLOW_PR_TOKEN_CAP must be a non-negative integer"}'; exit 1; fi
if [ ${#codex_homes[@]} -eq 0 ]; then codex_homes=("${CODEX_HOME:-$HOME/.codex}"); fi
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 not found"}'; exit 1; }
repo_id="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || repo_id=""
if [ -z "$repo_id" ]; then echo '{"error":"current directory is not a git repository"}'; exit 1; fi

RECORDS="${records[*]}" CAP="$cap" PROJECTS="$projects" REPO_ID="$repo_id" \
CODEX_RECORDS="$codex_records" CODEX_HOMES="$(printf '%s\n' "${codex_homes[@]}")" python3 <<'PY'
import glob, json, os, re, subprocess, sys

records = [int(x) for x in os.environ["RECORDS"].split()]
cap = int(os.environ["CAP"])
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
                seen[key] = (n(u, "input_tokens") + n(u, "cache_creation_input_tokens")
                             + n(u, "cache_read_input_tokens") + n(u, "output_tokens"))
    except FileNotFoundError:
        pass
    agents.append({"name": meta.get("name"), "description": desc, "model": meta.get("model"),
                   "tokens": sum(seen.values()), "requests": len(seen)})

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

claude_tokens = sum(a["tokens"] for a in agents)
codex_tokens = sum(c["tokens"] for c in codex)
total = claude_tokens + codex_tokens
over = total > cap
print(json.dumps({"records": records, "claude_tokens": claude_tokens, "codex_tokens": codex_tokens,
                  "total_tokens": total, "agent_count": len(agents), "codex_threads": len(codex),
                  "cap": cap, "over_cap": over, "unresolved": unresolved,
                  "codex_unresolved": codex_unresolved, "skipped_lines": skipped,
                  "agents": agents, "codex": codex}, ensure_ascii=False))
sys.exit(2 if over else 0)
PY
