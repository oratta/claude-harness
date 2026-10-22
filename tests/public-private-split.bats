#!/usr/bin/env bats
#
# 公開版と個人版の仕分けの表と、公開版に残る部品の固有記述の一覧の形と網羅の検査（issue #1128）。
#
# spec: harness-public-private-split
#
# 表と一覧（docs/public-private-split.md）は担い手が部品を読んで手で書く。このテストはそれを、
# 実行時点の git ls-files・rules/*.md・output-styles/*.md・marketplace.json の plugins[].name・
# 直下の scripts/ の項目・Markdown の `## ` の見出しと突き合わせる。突き合わせる相手はテストが
# 自分で列挙し、文書から取らない。
#
# 守備範囲（正本は spec「表と一覧の検査の守備範囲」）:
#   拾う: 表に無い部品・同じ部品の 2 行・どのファイルにも当たらない行・分割のプラグインで行の
#         決まらないファイル・節の行の覆い漏れと重複・決めた値以外の分類・空の理由・実在しない
#         パスや行数を超える行番号の一覧の行・公開版に決まらない部品を指す一覧の行
#   通す: 分類の判断の誤り・中身の薄い理由・候補語に当たらない固有記述の取りこぼし・行数以内に
#         収まる行番号のずれ（人のレビューと #1098 の再検索が見る）

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DOC="${REPO_ROOT}/docs/public-private-split.md"
  WORK_DOC="${BATS_TEST_TMPDIR}/public-private-split.md"
}

# 検査の本体。引数: <リポジトリのルート> <文書のパス>。誤りを 1 行ずつ出して exit 1、無ければ exit 0。
check_split() {
  python3 -I - "$1" "$2" <<'PY'
import json, os, re, subprocess, sys

root, doc = sys.argv[1], sys.argv[2]
errors = []
def err(msg):
    errors.append(msg)

ALLOWED = {"公開版", "個人版", "保留（#1123 の後）", "分割"}
KINDS = {"固有名", "環境依存"}
TABLE_HEADER = ["部品", "分類", "理由"]
LIST_HEADER = ["場所", "種別", "内容", "直す issue"]
ATTACH_FILES = {".claude-plugin/plugin.json", "README.md", "CHANGELOG.md", "hooks/hooks.json"}
ATTACH_DIRS = ("changes/", "tests/")

def git_files(*paths):
    out = subprocess.run(["git", "-C", root, "ls-files", "--", *paths],
                         capture_output=True, text=True, check=True).stdout
    return [l for l in out.splitlines() if l]

def cells(line):
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return None
    return [c.strip() for c in s[1:-1].split("|")]

def unquote(c):
    m = re.fullmatch(r"`([^`]+)`", c)
    return m.group(1) if m else c

if not os.path.isfile(doc):
    print(f"文書がない: {doc}")
    sys.exit(1)
with open(doc, encoding="utf-8") as f:
    doc_lines = f.read().splitlines()

def read_table(header):
    starts = [i for i, l in enumerate(doc_lines) if cells(l) == header]
    if len(starts) != 1:
        err(f"見出しが {' | '.join(header)} の表が {len(starts)} 個ある（1 個であるべき）")
        return []
    rows = []
    i = starts[0] + 2
    while i < len(doc_lines) and doc_lines[i].strip().startswith("|"):
        c = cells(doc_lines[i])
        if c is None or len(c) != len(header):
            err(f"{i + 1} 行目: 列の数が {len(header)} でない: {doc_lines[i]}")
        else:
            rows.append((i + 1, c))
        i += 1
    return rows

table = read_table(TABLE_HEADER)
listing = read_table(LIST_HEADER)

# --- 突き合わせる相手をテスト側で列挙する ---
with open(os.path.join(root, ".claude-plugin/marketplace.json"), encoding="utf-8") as f:
    plugins = {p["name"]: re.sub(r"^\./", "", p["source"]).rstrip("/") for p in json.load(f)["plugins"]}
tracked = set(git_files())
expected = set()
for d in ("rules", "output-styles"):
    expected |= {p for p in git_files(f"{d}/*.md") if p.count("/") == 1}
expected |= set(plugins)
for p in git_files("scripts"):
    parts = p.split("/")
    expected.add(parts[0] + "/" + parts[1] + ("/" if len(parts) > 2 else ""))

# --- 行を読む ---
cls_of = {}
seen = {}
component_rows = []
for ln, (part, cls, reason) in table:
    key = unquote(part)
    if key in seen:
        err(f"{ln} 行目: 同じ部品の行が 2 行ある: {key}（{seen[key]} 行目にもある）")
    seen[key] = ln
    if cls not in ALLOWED:
        err(f"{ln} 行目: 分類が決めた値でない: {key} → {cls}")
    if not reason:
        err(f"{ln} 行目: 理由が空: {key}")
    cls_of[key] = cls
    if key.startswith("plugins/"):
        component_rows.append((ln, key, cls))
        if cls == "分割":
            err(f"{ln} 行目: 部品の行の分類に「分割」は使えない: {key}")
    else:
        if cls == "分割" and key not in plugins:
            err(f"{ln} 行目: 「分割」はプラグインの行だけに使える: {key}")

top_rows = {k for k in seen if not k.startswith("plugins/")}
for k in sorted(expected - top_rows):
    err(f"表に行が無い部品: {k}")
for k in sorted(top_rows - expected):
    err(f"表の行が部品に当たらない: {k}")

# --- 分割したプラグインを部品の行で覆う ---
def headings(path):
    with open(os.path.join(root, path), encoding="utf-8") as f:
        lines = f.read().splitlines()
    fence = False
    heads = []  # (行番号, 見出し)
    for i, l in enumerate(lines, 1):
        if re.match(r"^(```|~~~)", l):
            fence = not fence
            continue
        if not fence and l.startswith("## "):
            heads.append((i, l[3:].strip()))
    first = heads[0][0] if heads else len(lines) + 1
    has_top = any(l.strip() for l in lines[:first - 1])
    return heads, has_top

split_plugins = {n: d for n, d in plugins.items() if cls_of.get(n) == "分割"}
rows_by_plugin = {n: [] for n in split_plugins}
for ln, key, cls in component_rows:
    owner = [n for n, d in plugins.items() if key.startswith(d + "/")]
    if not owner:
        err(f"{ln} 行目: 部品の行がどのプラグインの配下でもない: {key}")
        continue
    if owner[0] not in split_plugins:
        err(f"{ln} 行目: 分割でないプラグインに部品の行がある: {key}")
        continue
    rows_by_plugin[owner[0]].append((ln, key, cls))

# file -> {"cls": 分類} または {"sections": {見出し: 分類}, "top": 分類, "heads": [...]}
resolved = {}
for name, pdir in split_plugins.items():
    files = []
    for p in git_files(pdir + "/"):
        rel = p[len(pdir) + 1:]
        if rel in ATTACH_FILES or rel.startswith(ATTACH_DIRS):
            continue
        files.append(p)
    rows = rows_by_plugin[name]
    file_rows = {k: (ln, c) for ln, k, c in rows if "#" not in k and not k.endswith("/")}
    dir_rows = {k: (ln, c) for ln, k, c in rows if "#" not in k and k.endswith("/")}
    sec_rows = {}
    for ln, k, c in rows:
        if "#" in k:
            path, sec = k.split("#", 1)
            sec_rows.setdefault(path, []).append((ln, sec, c))
    matched = set()
    for f in files:
        dirs = [d for d in dir_rows if f.startswith(d)]
        matched.update(dirs)
        if f in sec_rows:
            if f in file_rows:
                err(f"{file_rows[f][0]} 行目: 節で分けたファイルにファイルの行も置いている: {f}")
                matched.add(f)
            heads, has_top = headings(f)
            names = [h for _, h in heads]
            if len(set(names)) != len(names):
                err(f"節で分けたファイルに同じ見出しが 2 つある: {f}")
            secs = {}
            tops = []
            for ln, sec, c in sec_rows[f]:
                if sec == "冒頭":
                    tops.append(c)
                elif sec not in names:
                    err(f"{ln} 行目: 節の行の見出しがファイルに無い: {f}#{sec}")
                else:
                    secs[sec] = c
            for h in names:
                if h not in secs:
                    err(f"節の行で覆われていない見出し: {f}#{h}")
            if has_top and len(tops) != 1:
                err(f"最初の ## より前が空でないのに #冒頭 の行が {len(tops)} 行: {f}")
            if not has_top and tops:
                err(f"最初の ## より前が空なのに #冒頭 の行がある: {f}")
            resolved[f] = {"sections": secs, "top": tops[0] if tops else None, "heads": heads}
            continue
        if f in file_rows:
            matched.add(f)
            resolved[f] = {"cls": file_rows[f][1]}
        elif dirs:
            resolved[f] = {"cls": dir_rows[max(dirs, key=len)][1]}
        else:
            err(f"行の決まらないファイル: {f}（{name} は分割なので部品の行で覆う）")
    fileset = set(files)
    for k, (ln, _) in file_rows.items():
        if k not in fileset:
            err(f"{ln} 行目: どのファイルにも当たらない行: {k}")
    for k, (ln, _) in dir_rows.items():
        if k not in matched:
            err(f"{ln} 行目: どのファイルにも当たらない行: {k}")
    for path, lst in sec_rows.items():
        if path not in fileset:
            for ln, sec, _ in lst:
                err(f"{ln} 行目: どのファイルにも当たらない行: {path}#{sec}")

# --- 一覧 ---
def destination(path, line):
    for name, pdir in plugins.items():
        if path.startswith(pdir + "/"):
            c = cls_of.get(name)
            if c != "分割":
                return c
            r = resolved.get(path)
            if r is None:
                # 分割したプラグインの付属のファイル（plugin.json・README.md など）は行で覆わない。
                # 公開版の部品の行が 1 つでもあれば、付属は公開版に残るとみなす（文書の冒頭に書く）。
                rel = path[len(pdir) + 1:]
                if rel in ATTACH_FILES or rel.startswith(ATTACH_DIRS):
                    if any(c == "公開版" for _, _, c in rows_by_plugin.get(name, [])):
                        return "公開版"
                return None
            if "cls" in r:
                return r["cls"]
            sec = None
            for hl, h in r["heads"]:
                if hl <= line:
                    sec = h
            return r["top"] if sec is None else r["sections"].get(sec)
    if path in cls_of:
        return cls_of[path]
    parts = path.split("/")
    if parts[0] == "scripts" and len(parts) > 2:
        return cls_of.get(parts[0] + "/" + parts[1] + "/")
    return None

for ln, (place, kind, content, issue) in listing:
    m = re.fullmatch(r"(.+):(\d+)", unquote(place))
    if not m:
        err(f"{ln} 行目: 場所が <パス>:<行> の形でない: {place}")
        continue
    path, line = m.group(1), int(m.group(2))
    if path not in tracked:
        err(f"{ln} 行目: 一覧のパスが git 管理下に無い: {path}")
        continue
    with open(os.path.join(root, path), encoding="utf-8") as f:
        n = len(f.read().splitlines())
    if not 1 <= line <= n:
        err(f"{ln} 行目: 行番号がファイルの行数（{n}）を超える: {path}:{line}")
    dest = destination(path, line)
    if dest != "公開版":
        err(f"{ln} 行目: 一覧の行が公開版に決まる部品に属さない（{dest}）: {path}:{line}")
    if kind not in KINDS:
        err(f"{ln} 行目: 種別が固有名／環境依存のどちらでもない: {kind}")
    if not content:
        err(f"{ln} 行目: 内容が空: {path}:{line}")
    if not issue:
        err(f"{ln} 行目: 直す issue が空: {path}:{line}")

for e in errors:
    print(e)
sys.exit(1 if errors else 0)
PY
}

# 文書の写しを作り、指定した固定文字列を含む行を消す
drop_row() { # <固定文字列>
  grep -v -F -- "$1" "$DOC" >"$WORK_DOC"
}

# 文書の写しを作り、python の置換を 1 回当てる（置換が当たらなければ失敗）
edit_doc() { # <置換前> <置換後>
  python3 -I - "$DOC" "$WORK_DOC" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
text = open(src, encoding="utf-8").read()
if old not in text:
    sys.exit(f"置換前の文字列が無い: {old}")
open(dst, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
}

@test "the split table and the listing pass the shape and coverage checks" {
  run check_split "$REPO_ROOT" "$DOC"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "a missing document fails" {
  run check_split "$REPO_ROOT" "${BATS_TEST_TMPDIR}/no-such.md"
  [ "$status" -eq 1 ]
}

@test "dropping a top-level row fails and names the part" {
  drop_row '| `rules/dev-server.md` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"表に行が無い部品: rules/dev-server.md"* ]] || return 1
}

@test "a new rules file without a row fails (fixture repo)" {
  local fx="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$fx"
  (cd "$REPO_ROOT" && git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "$fx"
  cp "$DOC" "${fx}/docs/public-private-split.md"
  git -C "$fx" init -q
  printf '# new\n' >"${fx}/rules/zz-new-rule.md"
  git -C "$fx" add -A
  run check_split "$fx" "${fx}/docs/public-private-split.md"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"表に行が無い部品: rules/zz-new-rule.md"* ]] || return 1
}

@test "dropping a component row of a split plugin fails and names the file" {
  drop_row '| `plugins/capability-registry/scripts/fmtoken.sh` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"行の決まらないファイル: plugins/capability-registry/scripts/fmtoken.sh"* ]] || return 1
}

@test "dropping a section row fails" {
  drop_row '| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"覆われていない見出し: plugins/capability-registry/skills/capability-registry/SKILL.md#原則"* ]] || return 1
}

@test "a duplicated section row fails" {
  edit_doc '| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` |' \
    '| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` | 公開版 | 重複 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"同じ部品の行が 2 行ある"* ]] || return 1
}

@test "a file row next to section rows fails" {
  edit_doc '| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` |' \
    '| `plugins/capability-registry/skills/capability-registry/SKILL.md` | 公開版 | 併置 |
| `plugins/capability-registry/skills/capability-registry/SKILL.md#原則` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ファイルの行も置いている"* ]] || return 1
}

@test "dropping the top-of-file row of a sectioned file fails" {
  drop_row '| `plugins/capability-registry/skills/capability-registry/SKILL.md#冒頭` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"#冒頭 の行が 0 行"* ]] || return 1
}

@test "a classification outside the decided values fails" {
  edit_doc '| `rules/dev-server.md` | 公開版 |' '| `rules/dev-server.md` | 配る |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"分類が決めた値でない: rules/dev-server.md"* ]] || return 1
}

@test "an empty reason fails" {
  python3 -I - "$DOC" "$WORK_DOC" <<'PY'
import re, sys
src, dst = sys.argv[1:]
out = []
for l in open(src, encoding="utf-8").read().splitlines():
    if l.startswith("| `rules/dev-server.md` |"):
        l = "| `rules/dev-server.md` | 公開版 |  |"
    out.append(l)
open(dst, "w", encoding="utf-8").write("\n".join(out) + "\n")
PY
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"理由が空: rules/dev-server.md"* ]] || return 1
}

@test "a component row that matches no file fails" {
  edit_doc '| `plugins/capability-registry/scripts/fmtoken.sh` |' \
    '| `plugins/capability-registry/scripts/no-such.sh` | 公開版 | 無いファイル |
| `plugins/capability-registry/scripts/fmtoken.sh` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"どのファイルにも当たらない行: plugins/capability-registry/scripts/no-such.sh"* ]] || return 1
}

@test "a listing row pointing at a private part, a missing file or a line past the end fails" {
  local anchor='| 場所 | 種別 | 内容 | 直す issue |'
  edit_doc "${anchor}
|---|---|---|---|" "${anchor}
|---|---|---|---|
| \`plugins/capability-registry/scripts/fmtoken.sh:1\` | 固有名 | 個人版の部品 | 担い手なし |
| \`rules/no-such.md:1\` | 固有名 | 無いファイル | 担い手なし |
| \`rules/dev-server.md:9999\` | 固有名 | 行数超え | 担い手なし |"
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"公開版に決まる部品に属さない（個人版）: plugins/capability-registry/scripts/fmtoken.sh:1"* ]] || return 1
  [[ "$output" == *"git 管理下に無い: rules/no-such.md"* ]] || return 1
  [[ "$output" == *"行数"*"rules/dev-server.md:9999"* ]] || return 1
}

@test "a judgement error in a classification passes (left to human review)" {
  edit_doc '| `scripts/lint.sh` | 公開版 |' '| `scripts/lint.sh` | 個人版 |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 0 ]
}

# --- 配る候補の 6 ファイルに環境固有の記述が無い（#1098）---
# 守備範囲: 固定の検索語に当たる行と、条件つきの書き方の欠落だけを拾う。別の固有名や文の良し悪しは人のレビューが見る。

DELIVERED_SIX=(rules/communication-style.md rules/link-when-requesting-review.md rules/dev-server.md
  rules/browser-infra-env-capture.md rules/destructive-git-guard.md output-styles/readable.md)

@test "the six delivered files carry no owner-specific words" {
  local f
  for f in "${DELIVERED_SIX[@]}"; do
    ! grep -n -i -E 'oratta|genetta|suimei|flatmate|fmtoken|Dropbox|marketplaces/' "${REPO_ROOT}/$f" || return 1
  done
}

@test "communication-style names the output style by a cwd-independent path" {
  grep -qF '~/.claude/output-styles/readable.md' "${REPO_ROOT}/rules/communication-style.md"
}

@test "browser-infra-env-capture names capability-registry only conditionally" {
  local line
  line="$(grep -F 'capability-registry' "${REPO_ROOT}/rules/browser-infra-env-capture.md")"
  [[ "$line" == *"入っていれば"* ]] || return 1
}

@test "destructive-git-guard has no rules-archive path and the hook section is conditional" {
  ! grep -qF 'rules-archive' "${REPO_ROOT}/rules/destructive-git-guard.md" || return 1
  awk '/^## hook との分担/{f=1; next} /^## /{f=0} f' "${REPO_ROOT}/rules/destructive-git-guard.md" | grep -qF '入っていれば'
}

# --- dev-workflow 以外の公開版の部品が決めた固有名とオーナーの PC のパスを持たない（#1168）---
# 守備範囲: 固定の検索語の当たりが許可リストの行だけであること。別の固有名や文の良し悪しは人のレビューが見る。
# 許可リストの各件（ファイル|行に含まれる固定の文字列|当たる基準）は、change の tasks の判定の表に同じ行を持つ。

NONDEV_SCOPE=(rules/README.md scripts/sync.sh scripts/test-auto-merge-workflow.sh plugins/capability-registry
  plugins/statusline plugins/worktree plugins/product-handover plugins/casting plugins/cost-ledger plugins/infra)

# 出典や経緯としてだけ名前を挙げる行 = 出典、互換のために残す旧名の読み取り = 互換
NONDEV_ALLOW=(
  'rules/README.md|経緯（flatmate#599 / #608）|出典'
  'scripts/sync.sh|なぜ存在するか（flatmate#362）|出典'
  'plugins/infra/agents/infra-phase-1-hearing.md|2026-07 に suimei で|出典'
  'plugins/infra/skills/infra-setup/SKILL.md|2026-07 に suimei で Actions free 枠|出典'
  'plugins/infra/skills/infra-setup/SKILL.md|flatmate で 2026-10 に実発生|出典'
  'plugins/infra/templates/workflows/ci.yml.template|2026-07 に suimei で free 枠|出典'
  'plugins/infra/templates/workflows/weekly-full.yml.template|2026-07-25 に suimei で実発生|出典'
  'plugins/statusline/README.md|旧名の `FLATMATE_RATE_SHARE_DIR`（互換。主は|互換'
  'plugins/statusline/scripts/statusline.sh|# Order: CLAUDE_RATE_SHARE_DIR, FLATMATE_RATE_SHARE_DIR|互換'
  'plugins/statusline/scripts/statusline.sh|# The FLATMATE_* names are the old names|互換'
  'plugins/statusline/scripts/statusline.sh|elif [ "${FLATMATE_RATE_SHARE_DIR+x}" ]|互換'
  'plugins/statusline/scripts/statusline.sh|dir="$FLATMATE_RATE_SHARE_DIR"; have_dir=1  # old name, compatibility|互換'
  'plugins/statusline/scripts/statusline.sh|"${FLATMATE_RATE_SHARE_CONF:-$HOME/.claude/flatmate-rate-share}"|互換'
  'plugins/statusline/scripts/statusline.sh|flatmate#605 と同じ誤り|出典'
  'plugins/worktree/.claude-plugin/plugin.json|flatmate#320: find -path|出典'
  'plugins/worktree/references/wt-clean-orphan-detection.md|2026-08-10 に flatmate リポで全件実行したとき|出典'
  'plugins/worktree/references/wt-clean-verification.md|2026-08-10 に flatmate で、PR が OPEN|出典'
  'plugins/worktree/scripts/wt-setup.sh|flatmate#320|出典'
  'plugins/worktree/scripts/wt-setup.sh|実例: suimei の .env.local.example|出典'
  'plugins/worktree/skills/wt-clean/SKILL.md|2026-08-01 に flatmate リポで、壁打ち|出典'
  'plugins/worktree/skills/wt-clean/SKILL.md|2026-08-10 に flatmate で実走したとき|出典'
  'plugins/worktree/skills/wt-clean/SKILL.md|2026-08-07 に shukan-dev で実走したところ|出典'
)

# 検索の対象にする公開版のファイル（changes/・CHANGELOG.md・tests/・evals/ と、個人版に決まるファイルは除く）
nondev_files() {
  git -C "$REPO_ROOT" ls-files -- "${NONDEV_SCOPE[@]}" \
    | grep -v -E '/(changes|tests|evals)/|(^|/)CHANGELOG\.md$|capability-registry/scripts/fmtoken\.sh$|capability-registry/skills/capability-registry/1password\.md$'
}

# 個人版に決まる節（capability-registry の SKILL.md の「表記規約」「資格情報の階層」）を除いて、行ごとに file:line:text で出す
nondev_hits() {
  local re="$1" f
  for f in $(nondev_files); do
    awk -v f="$f" '
      /^## / { skip = (f ~ /capability-registry\/SKILL\.md$/ && ($0 ~ /表記規約/ || $0 ~ /資格情報の階層/)) }
      !skip { print f ":" NR ":" $0 }' "${REPO_ROOT}/$f" | grep -E -e "^[^:]*:[0-9]+:.*(${re})" || true
  done
}

nondev_unlisted() {
  local re="$1" hit file text e afile astr allowed
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; text="${hit#*:*:}"; allowed=""
    for e in "${NONDEV_ALLOW[@]}"; do
      afile="${e%%|*}"; astr="${e#*|}"; astr="${astr%|*}"
      [ "$file" = "$afile" ] && [[ "$text" == *"$astr"* ]] && { allowed=1; break; }
    done
    [ -n "$allowed" ] || printf '%s\n' "$hit"
  done
}

@test "non-dev-workflow public parts carry no owner-specific names outside the allow list" {
  local out
  out="$(nondev_hits 'moko|suimei|uranai|shukan|sns-autopilot|flatmate|FLATMATE|/Users/oratta' | nondev_unlisted)"
  echo "$out"
  [ -z "$out" ]
}

@test "the worktree plugin carries no owner PC path" {
  local out
  out="$(nondev_hits '/Users/oratta')"
  echo "$out"
  [ -z "$out" ]
}

@test "every allow-list entry still matches a line (no stale entries)" {
  local e afile astr
  for e in "${NONDEV_ALLOW[@]}"; do
    afile="${e%%|*}"; astr="${e#*|}"; astr="${astr%|*}"
    grep -qF -e "$astr" "${REPO_ROOT}/$afile" || { echo "stale: $e"; return 1; }
  done
}

# --- dev-workflow の公開版の部品が決めた固有名を持たない（Orca 経路を除く。#1168）---
# 守備範囲: 固定の検索語の当たりが許可リストの行だけであること。別の固有名や文の良し悪しは人のレビューが見る。
# 許可リストの各件（ファイル|行に含まれる固定の文字列|当たる基準）は、change の tasks の判定の表に同じ行を持つ。

DEVWF_FLATMATE_FILES=(plugins/dev-workflow/references/pr-body-format.md
  plugins/dev-workflow/skills/issueify/SKILL.md
  plugins/dev-workflow/skills/push-guard-setup/SKILL.md
  plugins/dev-workflow/templates/escalation-tripwires.md
  plugins/dev-workflow/scripts/pr-state.sh
  plugins/dev-workflow/skills/memory-refresh/SKILL.md
  plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md)

DEVWF_DEVDIR_FILES=(plugins/dev-workflow/references/ci-watch.md plugins/dev-workflow/skills/memory-refresh/SKILL.md)

# 出典や経緯としてだけ名前を挙げる行 = 出典
DEVWF_ALLOW=(
)

# moko の検索の対象: dev-workflow の公開版のファイル（個人版に決まる auto-merge-deployments.md、changes/・CHANGELOG.md・tests/・evals/ を除く）
devwf_public_files() {
  git -C "$REPO_ROOT" ls-files -- plugins/dev-workflow \
    | grep -v -E '/(changes|tests|evals)/|(^|/)CHANGELOG\.md$|plugins/dev-workflow/docs/auto-merge-deployments\.md$'
}

# 引数: 正規表現 ファイル... → 許可リストに無い当たりを file:line:text で出す
devwf_unlisted() {
  local re="$1" f hit file text e afile astr allowed
  shift
  for f in "$@"; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      file="${hit%%:*}"; text="${hit#*:*:}"; allowed=""
      for e in "${DEVWF_ALLOW[@]}"; do
        afile="${e%%|*}"; astr="${e#*|}"; astr="${astr%|*}"
        [ "$file" = "$afile" ] && [[ "$text" == *"$astr"* ]] && { allowed=1; break; }
      done
      [ -n "$allowed" ] || printf '%s\n' "$hit"
    done < <(awk -v f="$f" '{ print f ":" NR ":" $0 }' "${REPO_ROOT}/$f" | grep -E -e "^[^:]*:[0-9]+:.*(${re})" || true)
  done
}

@test "dev-workflow public parts carry no owner project name moko" {
  local out
  # shellcheck disable=SC2046
  out="$(devwf_unlisted 'moko' $(devwf_public_files))"
  echo "$out"
  [ -z "$out" ]
}

@test "dev-workflow public parts carry no new-resident or flatmate outside the allow list" {
  local out
  out="$(devwf_unlisted 'new-resident|flatmate|FLATMATE' "${DEVWF_FLATMATE_FILES[@]}")"
  echo "$out"
  [ -z "$out" ]
}

@test "dev-workflow public parts carry no CLAUDE_HARNESS_DEV_DIR outside the allow list" {
  local out
  out="$(devwf_unlisted 'CLAUDE_HARNESS_DEV_DIR' "${DEVWF_DEVDIR_FILES[@]}")"
  echo "$out"
  [ -z "$out" ]
}

@test "every dev-workflow allow-list entry still matches a line (no stale entries)" {
  local e afile astr
  for e in "${DEVWF_ALLOW[@]}"; do
    afile="${e%%|*}"; astr="${e#*|}"; astr="${astr%|*}"
    grep -qF -e "$astr" "${REPO_ROOT}/$afile" || { echo "stale: $e"; return 1; }
  done
}

# --- 固有記述の一覧に担い手なしの行も #1177 の行も残さない（#1177）---
# 守備範囲: 一覧の表の行の「直す issue」の欄が「担い手なし」「#1177」でないこと、一覧が空でも形の検査が通ること。
# 基準に当たるとした判定の正しさ・直した文の良し悪しは人のレビューが見る。
# 引数: 文書のパス → 一覧の行（`| ` で始まり「直す issue」が担い手なし／#1177）を出し、あれば exit 1
listing_unowned() {
  local out
  out="$(grep -E '^[[:space:]]*\|.*\|[[:space:]]*(担い手なし|#1177)[[:space:]]*\|[[:space:]]*$' "$1" || true)"
  [ -z "$out" ] || { printf '%s\n' "$out"; return 1; }
}

@test "no row in the listing is left without an owner or owned by #1177" {
  run listing_unowned "$DOC"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "a listing row without an owner fails the owner check" {
  local anchor='| 場所 | 種別 | 内容 | 直す issue |'
  edit_doc "${anchor}
|---|---|---|---|" "${anchor}
|---|---|---|---|
| \`rules/dev-server.md:1\` | 固有名 | 例 | 担い手なし |"
  run listing_unowned "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"rules/dev-server.md:1"* ]] || return 1
}

@test "a listing row without an owner is caught however it is written" {
  local anchor='| 場所 | 種別 | 内容 | 直す issue |' row
  for row in '| `rules/dev-server.md:1` | 固有名 | 例 |  担い手なし  |' \
             '| rules/dev-server.md:1 | 固有名 | 例 | 担い手なし |' \
             '| `rules/dev-server.md:1` | 固有名 | 例 | 担い手なし | ' \
             '|`rules/dev-server.md:1`|固有名|例|#1177|'; do
    edit_doc "${anchor}
|---|---|---|---|" "${anchor}
|---|---|---|---|
${row}"
    run listing_unowned "$WORK_DOC"
    echo "$row => $output"
    [ "$status" -eq 1 ]
  done
}

# 引数: 元の文書 書き出す先 → 一覧の表の行だけを消す（後ろの表は残す）
empty_listing() {
  awk '
    f==0 && /^\| 場所 \| 種別 \| 内容 \| 直す issue \|$/ { f=1; print; next }
    f==1 && /^\|---/ { print; f=2; next }
    f==2 && /^\|/ { next }
    f==2 { f=3 }
    { print }' "$1" >"$2"
}

@test "an empty listing keeps the tables after it" {
  empty_listing "$DOC" "$WORK_DOC"
  [ "$(grep -c 'SKILL.md:' "$WORK_DOC")" -eq "$(grep -c 'SKILL.md:' "$DOC")" ] || { echo "後ろの表が消えた"; return 1; }
}

@test "an empty listing passes the shape checks" {
  empty_listing "$DOC" "$WORK_DOC"
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "epic-launch-orca.sh is a pending part, so a listing row pointing at it fails" {
  local anchor='| 場所 | 種別 | 内容 | 直す issue |'
  edit_doc "${anchor}
|---|---|---|---|" "${anchor}
|---|---|---|---|
| \`plugins/dev-workflow/scripts/epic-launch-orca.sh:2\` | 環境依存 | Orca の起動部品 | #1123 |"
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"公開版に決まる部品に属さない（保留（#1123 の後））: plugins/dev-workflow/scripts/epic-launch-orca.sh:2"* ]] || return 1
}
