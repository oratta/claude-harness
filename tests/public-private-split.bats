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
#         パスや行数を超える行番号の一覧の行・公開版に決まらない部品を指す一覧の行・
#         #1129 で公開版に確定した 5 行（CONFIRMED_PUBLIC）が表に無いか公開版から外れること
#   通す: 確定した 5 行以外の部品の分類の判断の誤り・中身の薄い理由・候補語に当たらない固有記述の取りこぼし・行数以内に
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

ALLOWED = {"公開版", "個人版", "分割"}
# #1129 で公開版に確定した 5 行。確定を覆すときはここも一緒に直す（spec「表と一覧の検査の守備範囲」）
CONFIRMED_PUBLIC = [
    "plugins/dev-workflow/scripts/epic-dispatch.sh",
    "plugins/dev-workflow/scripts/epic-launch-orca.sh",
    "plugins/dev-workflow/scripts/stop-judge.sh",
    "plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md",
    "plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md",
]
KINDS = {"固有名", "環境依存"}
TABLE_HEADER = ["部品", "分類", "理由"]
LIST_HEADER = ["場所", "種別", "内容", "直す issue"]
MOVED_HEADER = ["部品", "移した先", "写し元の commit"]
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

# --- #1129 で公開版に確定した 5 行 ---
for path in CONFIRMED_PUBLIC:
    hits = [(ln, cls) for ln, (part, cls, _) in table if unquote(part) == path]
    if len(hits) != 1:
        err(f"確定した行が表に {len(hits)} 行ある（1 行であるべき）: {path}")
    for ln, cls in hits:
        if cls != "公開版":
            err(f"{ln} 行目: 確定した行の分類が公開版でない: {path} → {cls}")

top_rows = {k for k in seen if not k.startswith("plugins/")}
for k in sorted(expected - top_rows):
    err(f"表に行が無い部品: {k}")
for k in sorted(top_rows - expected):
    err(f"表の行が部品に当たらない: {k}")

# --- 個人版に移した部品（#1129）: 節「個人版に移した部品」の表から読み、公開版に無いことを確かめる ---
with open(os.path.join(root, ".claude-plugin/marketplace.json"), encoding="utf-8") as f:
    bundled = {n for b in json.load(f).get("bundles", []) for n in b.get("plugins", [])}
def has_heading(path, sec):
    full = os.path.join(root, path)
    if path not in tracked or not os.path.isfile(full):
        return False
    with open(full, encoding="utf-8") as f:
        return any(l.startswith("## ") and l[3:].strip() == sec for l in f.read().splitlines())
for ln, (part, dest, sha) in read_table(MOVED_HEADER):
    key = unquote(part)
    if not unquote(dest):
        err(f"{ln} 行目: 移した先が空: {key}")
    if not re.fullmatch(r"[0-9a-f]{40}", unquote(sha)):
        err(f"{ln} 行目: 写し元の commit が 40 桁の SHA でない: {key} → {sha}")
    if key in seen:
        err(f"{seen[key]} 行目: 移した部品の行が仕分けの表に残っている: {key}")
    if "#" in key:
        path, sec = key.split("#", 1)
        if has_heading(path, sec):
            err(f"移した節の見出しが公開版に残っている: {key}")
        continue
    if git_files(key):
        err(f"移した部品が公開版に残っている: {key}")
    m = re.fullmatch(r"plugins/([^/]+)/", key)
    if m:
        if m.group(1) in plugins:
            err(f"移したプラグインが marketplace.json の plugins[] に残っている: {m.group(1)}")
        if m.group(1) in bundled:
            err(f"移したプラグインが marketplace.json の bundle に残っている: {m.group(1)}")

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
  drop_row '| `plugins/capability-registry/scripts/browser-guard.sh` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"行の決まらないファイル: plugins/capability-registry/scripts/browser-guard.sh"* ]] || return 1
}

# --- 個人版に移した部品（#1129）---
# 守備範囲: 移した部品が公開版に戻ること・仕分けの表に残ること・移した記録の行が移した先か SHA を欠くこと。
# 個人版の中身が写し元と一致するかと、公開版の文に残る個人版の固有名は個人版の check-public-leak.sh と人のレビューが見る。

@test "moved parts: putting rules/plugin-editing.md back fails and names the path (fixture repo)" {
  local fx="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$fx"
  (cd "$REPO_ROOT" && git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "$fx"
  cp "$DOC" "${fx}/docs/public-private-split.md"
  git -C "$fx" init -q
  printf '# plugin editing\n' >"${fx}/rules/plugin-editing.md"
  git -C "$fx" add -A
  run check_split "$fx" "${fx}/docs/public-private-split.md"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"移した部品が公開版に残っている: rules/plugin-editing.md"* ]] || return 1
}

@test "moved parts: a row for fmtoken.sh left in the split table fails" {
  edit_doc '| `plugins/capability-registry/scripts/browser-guard.sh` |' \
    '| `plugins/capability-registry/scripts/fmtoken.sh` | 個人版 | 残した行 |
| `plugins/capability-registry/scripts/browser-guard.sh` |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"移した部品の行が仕分けの表に残っている: plugins/capability-registry/scripts/fmtoken.sh"* ]] || return 1
}

@test "moved parts: each row of the moved table has a destination and a 40-digit source commit" {
  run python3 -I - "$DOC" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = [i for i, l in enumerate(lines) if re.fullmatch(r"\|\s*部品\s*\|\s*移した先\s*\|\s*写し元の commit\s*\|", l.strip())]
assert len(start) == 1, f"表が {len(start)} 個"
rows = []
for l in lines[start[0] + 2:]:
    if not l.strip().startswith("|"):
        break
    rows.append([c.strip() for c in l.strip()[1:-1].split("|")])
parts = {r[0].strip("`") for r in rows}
want = {"rules/plugin-editing.md", "plugins/weekly-report/", "plugins/daily-report/",
        "plugins/dev-workflow/docs/auto-merge-deployments.md",
        "plugins/capability-registry/scripts/fmtoken.sh",
        "plugins/capability-registry/skills/capability-registry/1password.md",
        "plugins/capability-registry/skills/capability-registry/SKILL.md#表記規約（生成文にも適用すること）",
        "plugins/capability-registry/skills/capability-registry/SKILL.md#資格情報の階層（どこに置くかはプロジェクトごとに決めない）"}
assert want <= parts, f"足りない行: {sorted(want - parts)}"
for r in rows:
    assert r[1].strip("`"), f"移した先が空: {r[0]}"
    assert re.fullmatch(r"`?[0-9a-f]{40}`?", r[2]), f"SHA でない: {r}"
PY
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "moved parts: dropping the destination or the source commit of a moved row fails" {
  run python3 -I - "$DOC" "$WORK_DOC" <<'PY'
import re, sys
src, dst = sys.argv[1:]
text = open(src, encoding="utf-8").read()
new, n = re.subn(r"^(\| `rules/plugin-editing\.md` \|)[^|]*\|[^|]*\|$", r"\1  | xyz |", text, count=1, flags=re.M)
assert n == 1, "移した記録に rules/plugin-editing.md の行が無い"
open(dst, "w", encoding="utf-8").write(new)
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"移した先が空: rules/plugin-editing.md"* ]] || return 1
  [[ "$output" == *"写し元の commit が 40 桁の SHA でない: rules/plugin-editing.md"* ]] || return 1
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
  edit_doc '| `plugins/capability-registry/scripts/browser-guard.sh` |' \
    '| `plugins/capability-registry/scripts/no-such.sh` | 公開版 | 無いファイル |
| `plugins/capability-registry/scripts/browser-guard.sh` |'
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
| \`scripts/lint.sh:1\` | 固有名 | 個人版の部品 | 担い手なし |
| \`rules/no-such.md:1\` | 固有名 | 無いファイル | 担い手なし |
| \`rules/dev-server.md:9999\` | 固有名 | 行数超え | 担い手なし |"
  # 個人版の部品は #1129 で公開版から無くなったので、行を 1 つ個人版に変えて指す
  python3 -I -c 'import sys; p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = "| `scripts/lint.sh` | 公開版 |"; assert o in t; open(p, "w", encoding="utf-8").write(t.replace(o, "| `scripts/lint.sh` | 個人版 |", 1))' "$WORK_DOC"
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"公開版に決まる部品に属さない（個人版）: scripts/lint.sh:1"* ]] || return 1
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

# --- 公開版の部品が決めた固有名とオーナーの PC のパスを持たない: 検索の範囲（#1168）---
# 守備範囲: 検索の範囲の決定はここ、語（tests/public-names/dict/）と許可（tests/public-names/allow/）はファイルに置く。
# 共有スクリプトの呼び出しは下の pn_* にまとめ、語の検索はその呼び出しの結果だけを見る。
# 別の固有名や文の良し悪しは人のレビューが見る。

NONDEV_SCOPE=(rules/README.md scripts/sync.sh scripts/test-auto-merge-workflow.sh plugins/capability-registry
  plugins/statusline plugins/worktree plugins/product-handover plugins/casting plugins/cost-ledger plugins/infra)

# 検索の対象にする公開版のファイル（changes/・CHANGELOG.md・tests/・evals/ を除く。個人版の部品は #1129 で公開版から無くなったので除く処理は無い）
nondev_files() {
  git -C "$REPO_ROOT" ls-files -- "${NONDEV_SCOPE[@]}" \
    | grep -v -E '/(changes|tests|evals)/|(^|/)CHANGELOG\.md$'
}

DEVWF_FLATMATE_FILES=(plugins/dev-workflow/references/pr-body-format.md
  plugins/dev-workflow/skills/issueify/SKILL.md
  plugins/dev-workflow/skills/push-guard-setup/SKILL.md
  plugins/dev-workflow/templates/escalation-tripwires.md
  plugins/dev-workflow/scripts/pr-state.sh
  plugins/dev-workflow/skills/memory-refresh/SKILL.md
  plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md)

DEVWF_DEVDIR_FILES=(plugins/dev-workflow/references/ci-watch.md plugins/dev-workflow/skills/memory-refresh/SKILL.md)

# dev-workflow の公開版のファイル（changes/・CHANGELOG.md・tests/・evals/ を除く）
devwf_public_files() {
  git -C "$REPO_ROOT" ls-files -- plugins/dev-workflow \
    | grep -v -E '/(changes|tests|evals)/|(^|/)CHANGELOG\.md$'
}

# --- 公開版の部品の禁止語検査: 共有スクリプトの呼び出しと、その検査（#1207）---
# 守備範囲: 辞書の語を含む行が公開版の部品に足されると落ちること、許可（tests/public-names/allow/）が行の中身で絞られること、
# 辞書が公開済みの語だけであること。辞書の網羅（辞書に無い固有名）と許可の基準の良し悪しは人のレビューが見る。
# 呼び出しは 5 つ（nondev・nondev-pc-path・devwf-moko・devwf-flatmate・devwf-dev-dir）。名前ごとに一覧・辞書・allow が決まる。

# 呼び出しの名前 → 検査するファイルの一覧（1 行 1 パス）
pn_list() {
  case "$1" in
    nondev | nondev-pc-path) nondev_files ;;
    devwf-moko) devwf_public_files ;;
    devwf-flatmate) printf '%s\n' "${DEVWF_FLATMATE_FILES[@]}" ;;
    devwf-dev-dir) printf '%s\n' "${DEVWF_DEVDIR_FILES[@]}" ;;
  esac
}

# 呼び出しの名前 → 辞書のファイル名（拡張子なし。空白区切り）
pn_dicts() {
  case "$1" in
    nondev) echo "moko other-projects flatmate owner-pc-path" ;;
    nondev-pc-path) echo "owner-pc-path" ;;
    devwf-moko) echo "moko" ;;
    devwf-flatmate) echo "new-resident flatmate" ;;
    devwf-dev-dir) echo "dev-dir-env" ;;
  esac
}

# 呼び出しの名前 → allow のファイル名（拡張子なし。allow が無ければ空）
pn_allow() {
  case "$1" in
    nondev) echo "nondev" ;;
  esac
}

# 辞書の先頭の語（コメント行と空行を除く）
pn_first_word() {
  grep -v -e '^#' -e '^$' "${REPO_ROOT}/tests/public-names/dict/$1.txt" | head -n 1
}

# 一覧のファイルを一時ディレクトリへ同じ相対パスでコピーする → PN_ROOT
pn_stage() {
  PN_ROOT="${BATS_TEST_TMPDIR}/stage-$1"
  mkdir -p "$PN_ROOT"
  pn_list "$1" > "${BATS_TEST_TMPDIR}/list-$1.txt"
  tar -C "$REPO_ROOT" -cf - -T "${BATS_TEST_TMPDIR}/list-$1.txt" | tar -C "$PN_ROOT" -xf -
}

# 共有スクリプトを呼ぶ。引数: 呼び出しの名前 検査 root。標準入力: ファイルの一覧。
# 辞書と allow は元のリポジトリの絶対パスで渡す（root が一時ディレクトリでも解けるように）。
# PN_ALLOW が空でなければ、その呼び出しの allow の代わりにそのパスを渡す。
pn_run() {
  local name="$1" root="$2" args=() d a
  for d in $(pn_dicts "$name"); do
    args+=(--dict "${REPO_ROOT}/tests/public-names/dict/${d}.txt")
  done
  a="$(pn_allow "$name")"
  if [ -n "${PN_ALLOW:-}" ]; then
    args+=(--allow "$PN_ALLOW")
  elif [ -n "$a" ]; then
    args+=(--allow "${REPO_ROOT}/tests/public-names/allow/${a}.txt")
  fi
  FORBIDDEN_WORDS_NO_GH=1 bash "${REPO_ROOT}/plugins/dev-workflow/scripts/forbidden-words-check.sh" \
    --root "$root" --name "$name" "${args[@]}"
}

# 引数: 呼び出しの名前 検査 root [一覧に足すパス]
pn_check() {
  { pn_list "$1"; [ -z "${3:-}" ] || printf '%s\n' "$3"; } | pn_run "$1" "$2"
}

# 引数: ファイル 文字列。末尾に 1 行足し、足した行の行番号を PN_LINE に入れる
pn_append() {
  [ -z "$(tail -c 1 "$1")" ] || echo >> "$1"
  printf '%s\n' "$2" >> "$1"
  PN_LINE="$(wc -l < "$1" | tr -d ' ')"
}

# 引数: 呼び出しの名前 → 段階化して PN_ROOT に入れる（個人版の節を空行にする処理は #1129 で外した）
pn_ready() {
  pn_stage "$1"
}

pn_names() { echo "nondev nondev-pc-path devwf-moko devwf-flatmate devwf-dev-dir"; }

@test "pn: the five calls pass on the current tree" {
  local name root
  for name in $(pn_names); do
    case "$name" in
      nondev*) pn_ready "$name"; root="$PN_ROOT" ;;
      *) root="$REPO_ROOT" ;;
    esac
    run pn_check "$name" "$root"
    echo "$name: $output"
    [ "$status" -eq 0 ] || return 1
  done
}

@test "pn: the moko search covers stop-judge.sh, a part confirmed public in #1129" {
  local f=plugins/dev-workflow/scripts/stop-judge.sh word
  pn_list devwf-moko | grep -qxF "$f" || { echo "not in the devwf-moko list: $f"; return 1; }
  pn_ready devwf-moko
  word="$(pn_first_word moko)"
  pn_append "${PN_ROOT}/${f}" "# ${word}"
  run pn_check devwf-moko "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *"${f}:${PN_LINE}:${word}"* ]] || return 1
}

@test "pn: a dictionary word added to a public part fails with path, line and word" {
  local name word f
  for name in $(pn_names); do
    pn_ready "$name"
    word="$(pn_first_word "$(pn_dicts "$name" | awk '{ print $1 }')")"
    f="$(pn_list "$name" | head -n 1)"
    pn_append "${PN_ROOT}/${f}" "$word"
    run pn_check "$name" "$PN_ROOT"
    echo "$name: $output"
    [ "$status" -eq 1 ] || return 1
    [[ "$output" == *"${f}:${PN_LINE}:${word}"* ]] || return 1
  done
}

@test "pn: an allowed line passes and the same word on another line of the same file fails" {
  local entry path rest word str
  entry="$(grep -v -e '^#' -e '^$' "${REPO_ROOT}/tests/public-names/allow/nondev.txt" | head -n 1)"
  path="${entry%%:*}"; rest="${entry#*:}"; word="${rest%%:*}"; str="${rest#*:=}"
  pn_ready nondev
  pn_append "${PN_ROOT}/${path}" "$str"
  run pn_check nondev "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 0 ] || return 1
  pn_append "${PN_ROOT}/${path}" "別の行 ${word}"
  run pn_check nondev "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *"${path}:${PN_LINE}:${word}"* ]] || return 1
}

@test "pn: a capitalized spelling of a dictionary word also fails" {
  local name word cap f
  for name in nondev devwf-moko; do
    pn_ready "$name"
    word="$(pn_first_word moko)"
    cap="$(printf '%s' "$word" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')"
    f="$(pn_list "$name" | head -n 1)"
    pn_append "${PN_ROOT}/${f}" "$cap"
    run pn_check "$name" "$PN_ROOT"
    echo "$name: $output"
    [ "$status" -eq 1 ] || return 1
    [[ "$output" == *"${f}:${PN_LINE}:${word}"* ]] || return 1
  done
}

@test "pn: a file whose name contains a dictionary word fails with path match" {
  local name word newpath
  for name in nondev devwf-moko; do
    pn_ready "$name"
    word="$(pn_first_word moko)"
    case "$name" in
      nondev) newpath="plugins/casting/notes-${word}.md" ;;
      *) newpath="plugins/dev-workflow/notes-${word}.md" ;;
    esac
    mkdir -p "${PN_ROOT}/$(dirname "$newpath")"
    echo "clean text" > "${PN_ROOT}/${newpath}"
    run pn_check "$name" "$PN_ROOT" "$newpath"
    echo "$name: $output"
    [ "$status" -eq 1 ] || return 1
    [[ "$output" == *"${newpath}:path:${word}"* ]] || return 1
  done
}

@test "pn: an allow line that cancels nothing fails as unused" {
  local word
  word="$(pn_first_word moko)"
  cp "${REPO_ROOT}/tests/public-names/allow/nondev.txt" "${BATS_TEST_TMPDIR}/allow-copy.txt"
  echo "rules/README.md:${word}:=no-such-line-anywhere" >> "${BATS_TEST_TMPDIR}/allow-copy.txt"
  pn_ready nondev
  PN_ALLOW="${BATS_TEST_TMPDIR}/allow-copy.txt" run pn_check nondev "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *"何も打ち消していない"* ]] || return 1
}

@test "pn: a dictionary word added to the 原則 section of capability-registry SKILL.md fails" {
  local word f
  word="$(pn_first_word moko)"
  f="plugins/capability-registry/skills/capability-registry/SKILL.md"
  # 個人版の節を除く手当ては無いので、SKILL.md のどの節に書いても当たる
  pn_ready nondev
  awk -v w="$word" '{ print } /^## 原則/ { print w }' "${PN_ROOT}/${f}" > "${PN_ROOT}/${f}.new"
  mv "${PN_ROOT}/${f}.new" "${PN_ROOT}/${f}"
  run pn_check nondev "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *"${f}:"*":${word}"* ]] || return 1
}

@test "pn: the dictionary has six files and nine distinct words" {
  local d n=0 words dups
  for d in moko other-projects flatmate owner-pc-path new-resident dev-dir-env; do
    [ -f "${REPO_ROOT}/tests/public-names/dict/${d}.txt" ] || { echo "missing: $d"; return 1; }
  done
  [ "$(find "${REPO_ROOT}/tests/public-names/dict" -type f | wc -l | tr -d ' ')" -eq 6 ] || return 1
  words="$(cat "${REPO_ROOT}"/tests/public-names/dict/*.txt | grep -v -e '^#' -e '^$')"
  n="$(printf '%s\n' "$words" | wc -l | tr -d ' ')"
  dups="$(printf '%s\n' "$words" | sort | uniq -d)"
  echo "words=$n dups=[$dups]"
  [ "$n" -eq 9 ] || return 1
  [ -z "$dups" ] || return 1
}

@test "pn: this file keeps no search regex and no allow array of its own" {
  local alt
  [ -d "${REPO_ROOT}/tests/public-names/dict" ] || return 1
  # 配列の名前を 2 つに割って書くので、このテスト自身は当たらない
  ! grep -q -e "NONDEV_""ALLOW" -e "DEVWF_""ALLOW" "$BATS_TEST_FILENAME" || return 1
  alt="$(cat "${REPO_ROOT}"/tests/public-names/dict/*.txt | grep -v -e '^#' -e '^$' | paste -s -d '|' -)"
  # 辞書の語を | でつないだ正規表現が残っていない（配る候補の語を並べた別の検査の行は、別の目的なので数えない）
  ! grep -E -e "(${alt})\|(${alt})" "$BATS_TEST_FILENAME" | grep -v 'Dropbox' | grep -q . || return 1
}

# --- 語の検索（共有スクリプトを呼ぶ）---

@test "non-dev-workflow public parts carry no owner-specific names outside the allow list" {
  pn_ready nondev
  run pn_check nondev "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "the worktree plugin carries no owner PC path" {
  pn_ready nondev-pc-path
  run pn_check nondev-pc-path "$PN_ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "dev-workflow public parts carry no owner project name" {
  run pn_check devwf-moko "$REPO_ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "dev-workflow public parts carry no new resident or second project name outside the allow list" {
  run pn_check devwf-flatmate "$REPO_ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "dev-workflow public parts carry no dev directory variable outside the allow list" {
  run pn_check devwf-dev-dir "$REPO_ROOT"
  echo "$output"
  [ "$status" -eq 0 ]
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

@test "epic-launch-orca.sh is a confirmed public part, so a listing row pointing at it is not rejected as non-public" {
  local anchor='| 場所 | 種別 | 内容 | 直す issue |'
  edit_doc "${anchor}
|---|---|---|---|" "${anchor}
|---|---|---|---|
| \`plugins/dev-workflow/scripts/epic-launch-orca.sh:2\` | 環境依存 | Orca の起動部品 | #1129 |"
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  # 終了コードは担い手の検査など他の理由で落ちうるので、属さないの文言が無いことだけを見る
  [[ "$output" != *"公開版に決まる部品に属さない"*"epic-launch-orca.sh"* ]] || return 1
}

@test "a row put back to the pending value fails as a classification outside the decided values" {
  edit_doc '| `plugins/dev-workflow/scripts/stop-judge.sh` | 公開版 |' '| `plugins/dev-workflow/scripts/stop-judge.sh` | 保留（#1123 の後） |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"分類が決めた値でない: plugins/dev-workflow/scripts/stop-judge.sh"* ]] || return 1
}

@test "the five rows confirmed in #1129 each appear once and are public" {
  run check_split "$REPO_ROOT" "$DOC"
  echo "$output"
  [[ "$output" != *"確定した行"* ]] || return 1
  local p
  for p in plugins/dev-workflow/scripts/epic-dispatch.sh plugins/dev-workflow/scripts/epic-launch-orca.sh \
    plugins/dev-workflow/scripts/stop-judge.sh plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md \
    plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md; do
    [ "$(grep -c -F "| \`${p}\` | 公開版 |" "$DOC")" -eq 1 ] || { echo "not one public row: $p"; return 1; }
  done
}

@test "turning a confirmed row to private fails and names the part" {
  edit_doc '| `plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md` | 公開版 |' \
    '| `plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md` | 個人版 |'
  run check_split "$REPO_ROOT" "$WORK_DOC"
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"確定した行の分類が公開版でない: plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md"* ]] || return 1
}
