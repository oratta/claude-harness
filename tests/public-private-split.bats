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

if not listing:
    err("固有記述の一覧に行が無い")
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
