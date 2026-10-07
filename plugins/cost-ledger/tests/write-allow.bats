#!/usr/bin/env bats
#
# spec: cost-ledger-write-allowlist（と、cost-ledger-gate-report・cost-ledger-timeline に足したシナリオ）
#
# GitHub にコストの行を書くのは、許可の一覧（リポジトリの外のテキストファイル）に載っているリポジトリ
# だけであることを固定する。実物には触れない: スクリプトを一時ディレクトリへ複製し、gh は呼ばれた引数を
# 記録するだけの stub、cost_ledger.py は固定の本文を返す stub に差し替える。python3 は「起動された回数を
# 記録してから本物へ渡す」包みを PATH の先頭に置き、起動していないことを回数 0 で確かめる。
# 一覧のファイルは必ず一時ディレクトリの中に置き、HOME も一時ディレクトリへ向ける（利用者の
# $HOME/.config/cost-ledger/write-repos を読まない）。

load helper

SELF="oratta/claude-harness"       # 一覧に載せるリポジトリ（このリポジトリ自身）
OTHER="example-org/other-repo"     # 一覧に載せない架空のリポジトリ

setup() {
  cl_setup
  REAL_PYTHON="$(command -v python3)"
  WORK="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/wa"
  SCRIPTS="$WORK/scripts"
  mkdir -p "$SCRIPTS" "$WORK/bin" "$WORK/log" "$WORK/tmp" "$WORK/home" "$WORK/conf"
  for f in gate-report.sh gate_report.py write_allow.py; do
    if [ -f "$PLUGIN_DIR/scripts/$f" ]; then cp "$PLUGIN_DIR/scripts/$f" "$SCRIPTS/$f"; fi
  done
  HOOK="$SCRIPTS/gate-report.sh"
  CWD="$WORK/self"                 # origin が $SELF の作業中のリポジトリ
  CWD_OTHER="$WORK/other"          # origin が $OTHER の作業中のリポジトリ
  cl_init_repo "$CWD" "$SELF"
  cl_init_repo "$CWD_OTHER" "$OTHER"
  LIST="$WORK/conf/write-repos"    # 一覧のファイル（どのリポジトリの中でもない）
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  export HOME="$WORK/home"
  export GH_LOG="$WORK/log/gh.log" PY_LOG="$WORK/log/python.log"
  export TMPDIR="$WORK/tmp"
  export COST_LEDGER_HOOK_FOREGROUND=1
  unset COST_LEDGER_GATE_REPORT GH_REPO GH_HOST CLAUDE_PROJECT_DIR STUB_CWD_REPO STUB_RETURNS
  unset COST_LEDGER_WRITE_REPOS CLAUDE_PLUGIN_OPTION_WRITE_REPOS
  write_stubs
  export PATH="$WORK/bin:$PATH"
}

# gh: 引数を 1 呼び出し 1 行で $GH_LOG に書く。repos/{owner}/{repo}/... は STUB_CWD_REPO（既定 ${SELF}）で
#     埋め、対象の確認には「問い合わせたリポジトリ」を返す。STUB_RETURNS があればその名前を返す
#     （改名・移管で別の名前へ転送された場合の再現）
# cost_ledger.py: timeline の代わりに固定の本文を返す
# python3: 起動を $PY_LOG に 1 行書いてから本物へ渡す
write_stubs() {
  printf '#!%s\n' "$REAL_PYTHON" > "$WORK/bin/gh"
  cat >> "$WORK/bin/gh" <<'PY'
import json, os, re, sys
args = sys.argv[1:]
fd = os.open(os.environ["GH_LOG"], os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
os.write(fd, (" ".join(args).replace("\n", "\\n") + "\n").encode("utf-8"))
os.close(fd)
path = next((a for a in args[1:] if a.startswith("repos/")), "")
path = path.replace("{owner}/{repo}", os.environ.get("STUB_CWD_REPO", "oratta/claude-harness"))
m = re.fullmatch(r"repos/([^/]+/[^/]+)/(pulls|issues)/(\d+)", path)
if "-X" in args or "--input" in args:
    sys.stdin.read()
    print("{}")
elif m:
    name = os.environ.get("STUB_RETURNS") or m.group(1)
    data = {"number": int(m.group(3)), "state": "open", "draft": False, "merged": False,
            "merged_at": None, "labels": [{"name": "agent-review:passed"}]}
    if m.group(2) == "pulls":
        data.update(head={"ref": "feat/x"}, base={"repo": {"full_name": name}})
    else:
        data.update(repository_url="https://api.github.com/repos/" + name)
    print(json.dumps(data))
elif "/comments" in path:
    pass
else:
    print("{}")
PY
  cat > "$SCRIPTS/cost_ledger.py" <<'PY'
import sys
sys.stdin.read()
print("コスト: $1.23 / ¥185 @150 — PR #300 (feat/x) 帰属: ブランチ")
PY
  cat > "$WORK/bin/python3" <<SH
#!/usr/bin/env bash
echo started >> "$PY_LOG"
exec "$REAL_PYTHON" "\$@"
SH
  chmod +x "$WORK/bin/gh" "$WORK/bin/python3"
}

allow() {  # 引数を 1 行ずつ一覧のファイルに書く（権限 600）
  printf '%s\n' "$@" > "$LIST"
  chmod 600 "$LIST"
}

hook() {  # $1=コマンド $2=cwd（既定 ${CWD}）。hook JSON を標準入力から流す
  "$REAL_PYTHON" -c 'import json, sys
print(json.dumps({"session_id": "S1", "hook_event_name": "PostToolUse", "tool_name": "Bash",
                  "tool_input": {"command": sys.argv[1]},
                  "tool_response": {"stdout": "", "stderr": ""}, "cwd": sys.argv[2]}))' \
    "$1" "${2-$CWD}" > "$WORK/payload.json"
  run bash "$HOOK" < "$WORK/payload.json"
}

silent() { [ "$status" -eq 0 ] && [ -z "$output" ]; }   # run は stderr も $output に入れる
gh_calls() { if [ -f "$GH_LOG" ]; then wc -l < "$GH_LOG" | tr -d ' '; else echo 0; fi; }
py_calls() { if [ -f "$PY_LOG" ]; then wc -l < "$PY_LOG" | tr -d ' '; else echo 0; fi; }
written_to() {  # $1=owner/repo $2=番号。コメントの作成が出たか
  grep -qE -- "-X POST repos/$1/issues/$2/comments " "$GH_LOG"
}
no_write() { [ ! -f "$GH_LOG" ] || ! grep -qE -- '-X (POST|PATCH) ' "$GH_LOG"; }
reset_logs() { rm -f "$GH_LOG" "$PY_LOG"; }

# write_allow.allowed(repo, cwd) を直接呼ぶ。書いてよければ終了コード 0
judge() {  # $1=owner/repo $2=cwd（既定 ${CWD}）
  "$REAL_PYTHON" -c 'import sys
sys.path.insert(0, sys.argv[1])
import write_allow
sys.exit(0 if write_allow.allowed(sys.argv[2], sys.argv[3]) is True else 1)' "$SCRIPTS" "$1" "${2-$CWD}"
}

# --- GitHub に書き込むのは許可の一覧に載っているリポジトリだけ ---

@test "write-allow: a listed repository gets its row" {  # 一覧に oratta/claude-harness があり、origin がそのリポジトリの cwd で gh pr comment 300 を流すと #300 に行が積まれる（gh は 3 回）
  allow "$SELF"
  hook "gh pr comment 300 --body x"
  silent
  written_to "$SELF" 300
  [ "$(gh_calls)" -eq 3 ]
}

@test "write-allow: a repository that is not listed gets nothing and gh is never called" {  # 一覧に oratta/claude-harness だけがあり、origin が example-org/other-repo の cwd では gh が 0 回
  allow "$SELF"
  STUB_CWD_REPO="$OTHER" hook "gh pr comment 300 --body x" "$CWD_OTHER"
  silent
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: without a list no trigger calls gh or python3" {  # 一覧のファイルが無いと、きっかけ 8 種のどれでも gh も python3 も 0 回で、無出力・終了コード 0
  [ ! -e "$LIST" ]
  for command in \
    "gh pr comment 300 --body x" "gh pr ready 300" "gh pr close 300" "gh pr merge 300" \
    "gh issue comment 12 --body x" "gh issue close 12" "gh issue reopen 12" \
    "gh api -X POST repos/$SELF/issues/300/labels -f 'labels[]=agent-review:passed'"; do
    hook "$command"
    silent || { echo "not silent: $command"; return 1; }
    [ "$(gh_calls)" -eq 0 ] || { echo "gh called: $command"; return 1; }
    [ "$(py_calls)" -eq 0 ] || { echo "python3 started: $command"; return 1; }
  done
}

# --- 一覧はリポジトリの外のテキストファイルから読む ---

@test "write-allow: comments and blank lines are skipped" {  # `# 自分のリポジトリ`・空行・oratta/claude-harness の 3 行で、書いてよいと判定される
  allow "# 自分のリポジトリ" "" "  $SELF  "
  judge "$SELF"
}

@test "write-allow: matching ignores case" {  # 一覧の Oratta/Claude-Harness は oratta/claude-harness を許可する
  allow "Oratta/Claude-Harness"
  judge "$SELF"
  judge "ORATTA/claude-harness"
}

@test "write-allow: lines that are not owner/repo are ignored one by one" {  # ホスト付き・ワイルドカード・URL の行だけが無視され、書式に合う行は効く
  allow "github.com/$SELF" "example-org/*" "https://github.com/$SELF" "example-org/sample"
  judge "example-org/sample"
  ! judge "$SELF" || return 1
  ! judge "$OTHER" || return 1
  ! judge "example-org/*" || return 1
}

@test "write-allow: a line with a trailing comment is ignored as a whole" {  # `oratta/claude-harness # 自分の` は行ごと無視される。1 行に 2 つ並べた行も同じ
  allow "$SELF # 自分の"
  ! judge "$SELF" || return 1
  allow "$SELF $OTHER"
  ! judge "$SELF" || return 1
  ! judge "$OTHER" || return 1
}

@test "write-allow: a list written in an environment variable has no effect" {  # 一覧のファイルが無く COST_LEDGER_WRITE_REPOS・CLAUDE_PLUGIN_OPTION_WRITE_REPOS に名前を書いても、gh は 0 回
  COST_LEDGER_WRITE_REPOS="$SELF" CLAUDE_PLUGIN_OPTION_WRITE_REPOS="$SELF" hook "gh pr comment 300 --body x"
  silent
  [ "$(gh_calls)" -eq 0 ]
  ! COST_LEDGER_WRITE_REPOS="$SELF" CLAUDE_PLUGIN_OPTION_WRITE_REPOS="$SELF" judge "$SELF" || return 1
}

@test "write-allow: the default place is \$HOME/.config/cost-ledger/write-repos" {  # COST_LEDGER_WRITE_REPOS_FILE が空か未設定なら既定の場所を読む
  mkdir -p "$HOME/.config/cost-ledger"
  LIST="$HOME/.config/cost-ledger/write-repos"
  allow "$SELF"
  unset COST_LEDGER_WRITE_REPOS_FILE
  judge "$SELF"
  hook "gh pr comment 300 --body x"
  written_to "$SELF" 300
  export COST_LEDGER_WRITE_REPOS_FILE=""
  judge "$SELF"
}

@test "write-allow: a file others can write is treated as empty" {  # 権限 666・620 の一覧は空として扱う
  allow "$SELF"
  chmod 666 "$LIST"
  ! judge "$SELF" || return 1
  chmod 620 "$LIST"
  ! judge "$SELF" || return 1
  chmod 644 "$LIST"
  judge "$SELF"
}

@test "write-allow: a symlink to a regular file outside the repository works" {  # 一覧のファイルが、リポジトリの外の通常のファイル（権限 600）へのシンボリックリンクなら有効
  LIST="$WORK/conf/real-list"
  allow "$SELF"
  ln -s "$WORK/conf/real-list" "$WORK/conf/write-repos"
  judge "$SELF"
  hook "gh pr comment 300 --body x"
  written_to "$SELF" 300
}

@test "write-allow: a symlink whose target others can write is treated as empty" {  # 実体が権限 666 なら無効（リンクそのものではなく実体を見る）
  LIST="$WORK/conf/real-list"
  allow "$SELF"
  chmod 666 "$WORK/conf/real-list"
  ln -s "$WORK/conf/real-list" "$WORK/conf/write-repos"
  ! judge "$SELF" || return 1
}

@test "write-allow: something that is not a readable regular file is treated as empty" {  # ディレクトリ・読めないファイル・UTF-8 でない中身・相対パスは空として扱い、例外を出さない
  mkdir "$LIST"
  ! judge "$SELF" || return 1
  rmdir "$LIST"
  allow "$SELF"
  chmod 000 "$LIST"
  if [ "$(id -u)" -ne 0 ]; then ! judge "$SELF" || return 1; fi
  chmod 600 "$LIST"
  printf 'oratta/claude-harness\n\377\376\n' > "$LIST"
  ! judge "$SELF" || return 1
  allow "$SELF"
  ! (cd "$WORK/conf" && COST_LEDGER_WRITE_REPOS_FILE="write-repos" judge "$SELF") || return 1
  judge "$SELF"
}

@test "write-allow: allowed() rejects anything that is not a plain owner/repo" {  # None・空・ホスト付き・cwd が空のときは書いてはいけない
  allow "$SELF"
  "$REAL_PYTHON" -c 'import sys
sys.path.insert(0, sys.argv[1])
import write_allow
cwd = sys.argv[2]
assert write_allow.allowed("oratta/claude-harness", cwd) is True
for repo in (None, "", "oratta", "github.com/oratta/claude-harness", "oratta/claude-harness\n", 3):
    assert write_allow.allowed(repo, cwd) is False, repo
for bad in ("", None):
    assert write_allow.allowed("oratta/claude-harness", bad) is False, bad' "$SCRIPTS" "$CWD"
}

# --- 作業中のリポジトリの中のファイルだけでは有効にならない ---

@test "write-allow: a list inside the working repository does not count" {  # origin が example-org/other-repo の cwd の中に一覧を置いて COST_LEDGER_WRITE_REPOS_FILE を向けても、gh は 0 回
  mkdir -p "$CWD_OTHER/conf"
  LIST="$CWD_OTHER/conf/write-repos"
  allow "$OTHER"
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  STUB_CWD_REPO="$OTHER" hook "gh pr comment 300 --body x" "$CWD_OTHER"
  silent
  [ "$(gh_calls)" -eq 0 ]
  ! judge "$OTHER" "$CWD_OTHER" || return 1
  ! judge "$OTHER" "$CWD_OTHER/conf" || return 1   # cwd がリポジトリの下位のディレクトリでも同じ
  judge "$OTHER" "$CWD"                            # 別のリポジトリから見れば、ただの外のファイル
}

@test "write-allow: pointing HOME into the repository does not count" {  # リポジトリの中に .config/cost-ledger/write-repos を置いて HOME を最上位に向けても、gh は 0 回
  mkdir -p "$CWD_OTHER/.config/cost-ledger"
  LIST="$CWD_OTHER/.config/cost-ledger/write-repos"
  allow "$OTHER"
  unset COST_LEDGER_WRITE_REPOS_FILE
  HOME="$CWD_OTHER" STUB_CWD_REPO="$OTHER" hook "gh pr comment 300 --body x" "$CWD_OTHER"
  silent
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: a symlink into the repository does not count" {  # 外に置いた一覧が、リポジトリの中のファイルへのシンボリックリンクなら空
  LIST="$CWD_OTHER/list-in-repo"
  allow "$OTHER"
  ln -s "$CWD_OTHER/list-in-repo" "$WORK/conf/write-repos"
  export COST_LEDGER_WRITE_REPOS_FILE="$WORK/conf/write-repos"
  STUB_CWD_REPO="$OTHER" hook "gh pr comment 300 --body x" "$CWD_OTHER"
  silent
  no_write
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: the repository's own settings file cannot enable writing" {  # .claude/settings.json の env が指すリポジトリの中のファイルは、その env を環境変数として付けても効かない
  mkdir -p "$CWD_OTHER/.claude"
  LIST="$CWD_OTHER/.claude/write-repos"
  allow "$OTHER"
  printf '{"env": {"COST_LEDGER_WRITE_REPOS_FILE": "%s", "COST_LEDGER_GATE_REPORT": "on"}}\n' "$LIST" \
    > "$CWD_OTHER/.claude/settings.json"
  from_settings="$("$REAL_PYTHON" -c 'import json, sys
print(json.load(open(sys.argv[1]))["env"]["COST_LEDGER_WRITE_REPOS_FILE"])' "$CWD_OTHER/.claude/settings.json")"
  COST_LEDGER_WRITE_REPOS_FILE="$from_settings" COST_LEDGER_GATE_REPORT=on STUB_CWD_REPO="$OTHER" \
    hook "gh pr comment 300 --body x" "$CWD_OTHER"
  silent
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: a list inside CLAUDE_PROJECT_DIR does not count" {  # cwd が別の場所でも、一覧が CLAUDE_PROJECT_DIR のリポジトリの中にあれば空
  LIST="$CWD_OTHER/list-in-repo"
  allow "$SELF"
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  judge "$SELF" "$CWD"
  ! CLAUDE_PROJECT_DIR="$CWD_OTHER" judge "$SELF" "$CWD" || return 1
}

@test "write-allow: spelling the path in another case does not get around the check" {  # 大文字小文字を区別しないファイルシステムで、リポジトリの中のファイルを別の綴りで指しても空
  mkdir -p "$CWD_OTHER/conf"
  LIST="$CWD_OTHER/conf/write-repos"
  allow "$OTHER"
  upper="$WORK/OTHER/conf/write-repos"
  [ -e "$upper" ] || skip "大文字小文字を区別するファイルシステム"
  COST_LEDGER_WRITE_REPOS_FILE="$upper" judge "$OTHER" "$CWD"   # ファイル自体は一覧として読める
  ! COST_LEDGER_WRITE_REPOS_FILE="$upper" judge "$OTHER" "$CWD_OTHER" || return 1
}

@test "write-allow: a cwd that is not a git repository is its own boundary" {  # .git が見つからない cwd は cwd そのものを境界にする
  mkdir -p "$WORK/plain/sub"
  LIST="$WORK/plain/sub/write-repos"
  allow "$SELF"
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  ! judge "$SELF" "$WORK/plain/sub" || return 1
  judge "$SELF" "$CWD"                                         # ファイル自体は一覧として読める
  [ ! -e "$WORK/.git" ] && [ ! -e "$WORK/plain/.git" ]
}

@test "write-allow: a list inside the main repository does not count from a linked worktree" {  # git の worktree の中で作業していても、親のリポジトリ本体の中の一覧は空
  cl_init_repo "$WORK/main" "$OTHER"
  git -C "$WORK/main" worktree add -q -b wt "$WORK/linked" >/dev/null 2>&1
  [ -f "$WORK/linked/.git" ]                                   # worktree の .git はファイル
  mkdir -p "$WORK/main/conf" "$WORK/linked/sub"
  LIST="$WORK/main/conf/write-repos"
  allow "$OTHER"
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  ! judge "$OTHER" "$WORK/linked" || return 1
  ! judge "$OTHER" "$WORK/linked/sub" || return 1
  ! CLAUDE_PROJECT_DIR="$WORK/linked" judge "$OTHER" "$CWD" || return 1
  STUB_CWD_REPO="$OTHER" hook "gh pr comment 300 --body x" "$WORK/linked"
  silent
  [ "$(gh_calls)" -eq 0 ]
  judge "$OTHER" "$CWD"                                        # 別のリポジトリから見れば、ただの外のファイル
}

@test "write-allow: a list inside the outer repository does not count from a nested repository" {  # リポジトリの中に置いた別の clone や submodule の中で作業していても、外側のリポジトリの中の一覧は空
  cl_init_repo "$WORK/outer" "$OTHER"
  cl_init_repo "$WORK/outer/vendor/inner" "$OTHER"
  mkdir -p "$WORK/outer/conf" "$WORK/outer/vendor/inner/sub"
  LIST="$WORK/outer/conf/write-repos"
  allow "$OTHER"
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  ! judge "$OTHER" "$WORK/outer/vendor/inner" || return 1
  ! judge "$OTHER" "$WORK/outer/vendor/inner/sub" || return 1
  STUB_CWD_REPO="$OTHER" hook "gh pr comment 300 --body x" "$WORK/outer/vendor/inner"
  silent
  [ "$(gh_calls)" -eq 0 ]
  # submodule の形（.git が外側の .git/modules/... を指すファイル）でも同じ
  mkdir -p "$WORK/outer/.git/modules/sm" "$WORK/outer/sm"
  printf 'gitdir: ../.git/modules/sm\n' > "$WORK/outer/sm/.git"
  ! judge "$OTHER" "$WORK/outer/sm" || return 1
  judge "$OTHER" "$CWD"                                        # 別のリポジトリから見れば、ただの外のファイル
}

@test "write-allow: a .git file that cannot be followed makes the list empty" {  # .git がファイルで gitdir: の先を読めない・解釈できないときは、確かめられないので空
  mkdir -p "$WORK/odd1" "$WORK/odd2"
  printf 'not a gitdir line\n' > "$WORK/odd1/.git"
  printf 'gitdir: %s\n' "$WORK/nowhere/.git/worktrees/x" > "$WORK/odd2/.git"
  allow "$SELF"
  judge "$SELF" "$CWD"                                         # 一覧そのものは有効
  ! judge "$SELF" "$WORK/odd1" || return 1
  ! judge "$SELF" "$WORK/odd2" || return 1
}

@test "write-allow: a list inside a repository whose git directory is kept elsewhere does not count" {  # worktree が指す先が bare なリポジトリでも、その中の一覧は空
  git init -q --bare "$WORK/bare.git"
  git -C "$WORK/bare.git" -c user.email=t@example.com -c user.name=t commit-tree -m init \
    "$(git -C "$WORK/bare.git" hash-object -t tree -w /dev/null)" > "$WORK/commit"
  git -C "$WORK/bare.git" worktree add -q "$WORK/from-bare" "$(cat "$WORK/commit")" >/dev/null 2>&1
  [ -f "$WORK/from-bare/.git" ]
  LIST="$WORK/bare.git/write-repos"
  allow "$SELF"
  export COST_LEDGER_WRITE_REPOS_FILE="$LIST"
  ! judge "$SELF" "$WORK/from-bare" || return 1
  judge "$SELF" "$CWD"
}

# --- 一覧に無いリポジトリでは gh を呼ばない ---

@test "write-allow: an empty list file does not start python3" {  # 大きさ 0 の一覧では gh も python3 も 0 回
  : > "$LIST"
  hook "gh pr comment 300 --body x"
  silent
  [ "$(gh_calls)" -eq 0 ]
  [ "$(py_calls)" -eq 0 ]
}

@test "write-allow: a list with only a comment never calls gh" {  # `# まだ何も許可していない` だけの一覧では gh が 0 回で無出力
  allow "# まだ何も許可していない"
  hook "gh pr comment 300 --body x"
  silent
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: a named repository that is not listed is never asked" {  # origin は一覧にあるが -R で名指ししたリポジトリが一覧に無いと gh は 0 回（--repo・GH_REPO=・URL・gh api のパスも同じ）
  allow "$SELF"
  for command in \
    "gh pr comment 300 -R $OTHER --body x" \
    "gh pr comment 300 --repo $OTHER --body x" \
    "GH_REPO=$OTHER gh pr comment 300 --body x" \
    "gh pr comment https://github.com/$OTHER/pull/300 --body x" \
    "gh api -X POST repos/$OTHER/issues/300/labels -f 'labels[]=agent-review:passed'"; do
    hook "$command"
    silent || { echo "not silent: $command"; return 1; }
    [ "$(gh_calls)" -eq 0 ] || { echo "gh called: $command"; return 1; }
  done
}

@test "write-allow: only the listed targets of one command go ahead" {  # 対象が 2 つで片方だけ一覧にあるとき、そちらにだけ積み、gh の引数にもう片方の名前は一度も現れない
  allow "$SELF"
  hook "gh pr comment 300 --body x; gh issue comment 12 -R $OTHER --body y"
  silent
  written_to "$SELF" 300
  ! grep -qF "$OTHER" "$GH_LOG" || return 1
  [ "$(gh_calls)" -eq 3 ]
}

@test "write-allow: a name returned by GitHub that is not listed stops after the first call" {  # 対象の確認（pulls/300）の応答のリポジトリ名が一覧に無ければ、gh はその 1 回だけで書き込まない
  allow "$SELF"
  STUB_RETURNS="$OTHER" hook "gh pr comment 300 --body x"
  silent
  [ "$(gh_calls)" -eq 1 ]
  grep -qE '(^| )repos/\{owner\}/\{repo\}/pulls/300( |$)' "$GH_LOG"
  no_write
}

@test "write-allow: a cwd without an origin never calls gh" {  # git リポジトリでない cwd では、名指しのリポジトリが一覧にあっても gh は 0 回。origin が github.com でないときも同じ
  allow "$SELF"
  mkdir -p "$WORK/plain"
  hook "gh api -X POST repos/$SELF/issues/300/labels -f 'labels[]=agent-review:passed'" "$WORK/plain"
  silent
  [ "$(gh_calls)" -eq 0 ]
  git -C "$CWD" remote set-url origin "https://ghe.example/$SELF.git"
  hook "gh pr comment 300 --body x"
  silent
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: the background work started on its own obeys the list too" {  # 裏の処理（--work）を直接起こしても、一覧に無い origin では gh が 0 回
  allow "$SELF"
  job='{"cwd": "'"$CWD_OTHER"'", "at": "1900000000.000", "targets": [{"kind": "pr", "repo": null, "number": 300, "triggers": ["PR コメント"]}]}'
  STUB_CWD_REPO="$OTHER" run "$REAL_PYTHON" "$SCRIPTS/gate_report.py" --work "$job"
  silent
  [ "$(gh_calls)" -eq 0 ]
  job='{"cwd": "'"$CWD"'", "at": "1900000000.000", "targets": [{"kind": "pr", "repo": null, "number": 300, "triggers": ["PR コメント"]}]}'
  run "$REAL_PYTHON" "$SCRIPTS/gate_report.py" --work "$job"
  silent
  written_to "$SELF" 300
}

# --- 全体停止は一覧より先に効く ---

@test "write-allow: COST_LEDGER_GATE_REPORT=off wins over the list" {  # 一覧に載っていても off なら python3 は起動せず（一覧の中身は読まれない）、gh も呼ばれない
  allow "$SELF"
  COST_LEDGER_GATE_REPORT=off hook "gh pr comment 300 --body x"
  silent
  [ "$(py_calls)" -eq 0 ]
  [ "$(gh_calls)" -eq 0 ]
  reset_logs
  COST_LEDGER_GATE_REPORT=off hook "gh api -X POST repos/$SELF/issues/300/labels -f 'labels[]=agent-review:passed'"
  silent
  [ "$(py_calls)" -eq 0 ]
  [ "$(gh_calls)" -eq 0 ]
}

@test "write-allow: with a list, a Bash call without a trigger still starts nothing" {  # 一覧があっても、きっかけの文字列が無い Bash では python3 を起動しない（評価の順: 全体停止 → 一覧が空か → きっかけの文字列）
  allow "$SELF"
  hook "ls -la"
  silent
  [ "$(py_calls)" -eq 0 ]
  [ "$(gh_calls)" -eq 0 ]
}

# --- 判定は 1 つの関数が行い、書き込む経路はすべてそれを通す ---

# 調べるディレクトリの *.py のうち、gh を起動するのに write_allow を読み込んでいないものの名前を出す。
# 1 つでもあれば終了コード 1。write_allow.py 自身と、GitHub から読むだけの例外（下の一覧）は除く。
#   cost_ledger.py — 番号が PR か issue かの判別と、エピックの子 issue の問い合わせだけを行い、書き込まない
READ_ONLY_SCRIPTS="cost_ledger.py"
check_gh_scripts() {  # $1=調べるディレクトリ
  "$REAL_PYTHON" - "$1" "$READ_ONLY_SCRIPTS" <<'PY'
import glob, os, re, sys
folder, skip = sys.argv[1], set(sys.argv[2].split()) | {"write_allow.py"}
starts_gh = re.compile(r"""\[\s*["']gh["']""")
imports = re.compile(r"^\s*(?:import\s+(?:[\w.]+\s*,\s*)*write_allow\b|from\s+write_allow\s+import\b)", re.M)
bad = []
for path in sorted(glob.glob(os.path.join(folder, "*.py"))):
    name = os.path.basename(path)
    if name in skip:
        continue
    source = open(path, encoding="utf-8").read()
    if starts_gh.search(source) and not imports.search(source):
        bad.append(name)
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
}

@test "write-allow: every script that starts gh imports write_allow" {  # plugins/cost-ledger/scripts の、gh を起動する *.py はすべて write_allow を読み込んでいる
  run check_gh_scripts "$PLUGIN_DIR/scripts"
  [ "$status" -eq 0 ] || { echo "write_allow を読み込まずに gh を起動している: $output"; return 1; }
  grep -qE '^import write_allow$' "$PLUGIN_DIR/scripts/gate_report.py"
}

@test "write-allow: the check fails for a script that starts gh without write_allow" {  # 複製に、gh を起動して write_allow を読み込まないスクリプトを足すと検査が落ち、名前を示す。本物のディレクトリは増えない
  before="$(ls "$PLUGIN_DIR/scripts" | wc -l | tr -d ' ')"
  mkdir "$WORK/copy"
  cp "$PLUGIN_DIR/scripts/"*.py "$WORK/copy/"
  run check_gh_scripts "$WORK/copy"
  [ "$status" -eq 0 ]
  printf 'import subprocess\nsubprocess.run(["gh", "api", "-X", "POST", "repos/o/r/issues/1/comments"])\n' \
    > "$WORK/copy/rogue.py"
  printf 'import os, write_allow\nimport subprocess\nsubprocess.run(["gh", "api", "user"])\n' > "$WORK/copy/fine.py"
  run check_gh_scripts "$WORK/copy"
  [ "$status" -eq 1 ]
  [ "$output" = "rogue.py" ]
  [ "$(ls "$PLUGIN_DIR/scripts" | wc -l | tr -d ' ')" -eq "$before" ]
  [ ! -e "$PLUGIN_DIR/scripts/rogue.py" ]
}

@test "write-allow: origin_repo() agrees with cost_ledger.py on every URL form" {  # https・git@・ssh の 3 つの形で両者の答えが一致し、github.com でないホストはどちらも github.com のリポジトリとして扱わない
  cp "$PLUGIN_DIR/scripts/cost_ledger.py" "$SCRIPTS/cost_ledger.py"
  for url in "https://github.com/o/r.git" "git@github.com:o/r.git" "ssh://git@github.com/o/r.git" \
             "https://github.com/o/r" "ssh://git@github.com:22/o/r.git" "https://GitHub.com/o/r.git" \
             "https://ghe.example/o/r.git" "git@ghe.example:o/r.git" "not a url"; do
    git -C "$CWD" remote set-url origin "$url"
    run "$REAL_PYTHON" -c 'import sys
sys.path.insert(0, sys.argv[1])
import cost_ledger, write_allow
cwd = sys.argv[2]
mine = write_allow.origin_repo(cwd)
resolver = cost_ledger.RepoResolver()
theirs = resolver.origin(resolver.repo_id(cwd))
theirs = theirs[1] if theirs and theirs[0] == "github.com" else None
print("%s %s" % (mine, theirs))
sys.exit(0 if mine == theirs else 1)' "$SCRIPTS" "$CWD"
    [ "$status" -eq 0 ] || { echo "$url -> $output"; return 1; }
    case "$url" in
      *ghe.example*|"not a url") [ "$output" = "None None" ] || { echo "$url -> $output"; return 1; } ;;
      *) [ "$output" = "o/r o/r" ] || { echo "$url -> $output"; return 1; } ;;
    esac
  done
  [ "$("$REAL_PYTHON" -c 'import sys
sys.path.insert(0, sys.argv[1])
import write_allow
print(write_allow.origin_repo(sys.argv[2]), write_allow.origin_repo(""), write_allow.origin_repo("/nonexistent/x"))' \
    "$SCRIPTS" "$WORK")" = "None None None" ]
}

# --- 一覧の作り方と、既に付いた行の消し方を README に書く ---

@test "write-allow: README explains the list and how to delete rows already posted" {  # README に write-repos・COST_LEDGER_WRITE_REPOS_FILE・一覧するコマンド・-X DELETE がある
  readme="$PLUGIN_DIR/README.md"
  grep -qF 'write-repos' "$readme"
  grep -qF 'COST_LEDGER_WRITE_REPOS_FILE' "$readme"
  grep -qF '$HOME/.config/cost-ledger/write-repos' "$readme"
  grep -qF 'gh api --paginate "repos/<owner>/<repo>/issues/comments?per_page=100"' "$readme"
  grep -qF '<!-- cost-ledger:timeline' "$readme"
  grep -qF -- '-X DELETE' "$readme"
  grep -qF '既に付いた行を消す' "$readme"
}
