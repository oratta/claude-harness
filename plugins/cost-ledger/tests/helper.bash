#!/usr/bin/env bash
# cost-ledger の bats スイート共通のセットアップ。
#
# 会話ログのルートは ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects なので、テストは
# CLAUDE_CONFIG_DIR を一時ディレクトリに向けて合成ログだけを読ませる。実環境の
# ~/.claude は一切読まない。

cl_setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
  CL="$PLUGIN_DIR/scripts/cost_ledger.py"
  PRICING="$PLUGIN_DIR/pricing.json"
  CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  mkdir -p "$CONFIG_DIR/projects"
  export CLAUDE_CONFIG_DIR="$CONFIG_DIR"
  # 実行環境のレート上書きがテストに漏れないようにする
  unset COST_LEDGER_USD_JPY
}

# 実在の git リポジトリを 1 つ作る（リポジトリ識別子の導出に本物の git が要る）
cl_init_repo() {  # $1=path  $2=owner/repo
  git init -q "$1"
  git -C "$1" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git -C "$1" remote add origin "https://github.com/$2.git"
}

# 合成 fixture を一時ディレクトリへ展開し、__REPO_*__ を実在のパスへ差し替える
cl_materialize() {
  REPO_A="$BATS_TEST_TMPDIR/repo-a"
  REPO_B="$BATS_TEST_TMPDIR/repo-b"
  REPO_A_WT="$BATS_TEST_TMPDIR/repo-a-wt"
  cl_init_repo "$REPO_A" "acme/repo-a"
  cl_init_repo "$REPO_B" "acme/repo-b"
  git -C "$REPO_A" worktree add -q -b wt "$REPO_A_WT" >/dev/null 2>&1
  cp -R "$PLUGIN_DIR/tests/fixtures/projects/." "$CONFIG_DIR/projects/"
  # 長い方（__REPO_A_WT__）を先に置換する
  find "$CONFIG_DIR/projects" -name '*.jsonl' -print0 | while IFS= read -r -d '' f; do
    python3 - "$f" "$REPO_A_WT" "$REPO_A" "$REPO_B" <<'PY'
import sys
path, wt, a, b = sys.argv[1:5]
s = open(path, encoding="utf-8").read()
s = s.replace("__REPO_A_WT__", wt).replace("__REPO_A__", a).replace("__REPO_B__", b)
open(path, "w", encoding="utf-8").write(s)
PY
  done
}

# 1 行だけの合成ログを書く（単価まわりの検査用）
cl_mini_log() {  # $1=branch $2=model $3=usage(JSON)
  mkdir -p "$CONFIG_DIR/projects/mini"
  python3 - "$CONFIG_DIR/projects/mini/mini.jsonl" "$1" "$2" "$3" <<'PY'
import json, sys
path, branch, model, usage = sys.argv[1:5]
d = {"type": "assistant", "requestId": "mini-1", "uuid": "u-mini-1",
     "timestamp": "2026-09-01T00:00:00.000Z", "sessionId": "M1", "isSidechain": False,
     "cwd": "/nonexistent/mini", "gitBranch": branch,
     "message": {"model": model, "role": "assistant", "content": [],
                 "usage": json.loads(usage)}}
open(path, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False) + "\n")
PY
}

# gh を差し替えた PATH を作る（番号の判別をネットワークから切り離す）
cl_fake_gh() {  # $1=script body
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  {
    echo '#!/usr/bin/env bash'
    cat
  } > "$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}
