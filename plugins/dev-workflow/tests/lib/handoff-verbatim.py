#!/usr/bin/env python3
"""手渡し規則の正本の一文が、正本以外のファイルにそのまま（逐語で）あるかを探す（#265）。

使い方: handoff-verbatim.py <リポジトリのルート>
出力:   1 行目 `SENTENCES <件数>`、以降は見つかった写しを `COPY <相対パス> :: <文頭>` で 1 行ずつ。
終了:   写しがあれば 1、無ければ 0、正本のどちらかが読めなければ 2。

正本は 2 か所（#1683）: decision-criteria.md の「コンテキスト上限（サブエージェントの手渡し）」節（本体向け）と、
return-declaration.md の全文（W と G が読む宣言）。どちらの正本の一文も、自分以外の追跡ファイル
（もう片方の正本を含む）に逐語であれば写しとして数える。`SENTENCES` の件数は 2 つの合計。

保証するのは「正本の節の一文（MIN_LEN 文字以上）が、そのままの形で他のファイルに貼られていない」ことだけ。
言い換え・語順の入れ替え・一文を二つに割った書き方・MIN_LEN 未満の短い句は捕まえない
（規則の言い換えを機械で完全に検出することは原理的にできない。PR #253 の経緯）。
"""
import os
import re
import subprocess
import sys

CANON = "plugins/dev-workflow/skills/develop/references/decision-criteria.md"
HEADING = "## コンテキスト上限（サブエージェントの手渡し）"
# W と G の宣言の正本（全文が正本。見出しで切り出さない）
DECL = "plugins/dev-workflow/skills/develop/references/return-declaration.md"
MIN_LEN = 40


def section_lines(root):
    path = os.path.join(root, CANON)
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    body, inside = [], False
    for line in lines:
        if line == HEADING:
            inside = True
            continue
        # 次の ## / ### 見出しで節は終わる（#### 以下の小見出しは節の中）。### の小節は別の話題なので含めない
        if inside and re.match(r"^#{2,3}(?:\s|$)", line):
            break
        if inside:
            body.append(line)
    return body


def whole_file_lines(root):
    with open(os.path.join(root, DECL), encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    # 見出しの行は文として数えない
    return [line for line in lines if not line.startswith("#")]


def sentences_of(body):
    sentences = []
    in_fence = False
    for line in body:
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or line.startswith("|"):
            continue
        line = re.sub(r"^\s*(?:[-*]|\d+\.)\s+", "", line.strip())
        for s in re.split(r"(?<=。)", line):
            s = s.strip()
            if len(s) >= MIN_LEN:
                sentences.append(s)
    return sentences


def candidate_files(root):
    if os.path.exists(os.path.join(root, ".git")):
        out = subprocess.check_output(["git", "-C", root, "ls-files"], text=True)
        return [p for p in out.split("\n") if p]
    found = []
    for d, dirs, names in os.walk(root):
        dirs[:] = [x for x in dirs if x != ".git"]
        for n in names:
            found.append(os.path.relpath(os.path.join(d, n), root))
    return found


def main():
    root = sys.argv[1]
    canons = []
    for rel, reader in ((CANON, section_lines), (DECL, whole_file_lines)):
        try:
            canons.append((rel, sentences_of(reader(root))))
        except OSError:
            canons.append((rel, []))
    print("SENTENCES", sum(len(ss) for _, ss in canons))
    # どちらかの正本が読めない・文が 1 つも取れないなら、何も見ていない緑にしない
    if any(not ss for _, ss in canons):
        return 2
    copies = 0
    for rel in candidate_files(root):
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as fh:
                text = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        for canon_rel, sentences in canons:
            if rel == canon_rel:
                continue
            for s in sentences:
                if s in text:
                    print("COPY", rel, "::", s[:40])
                    copies += 1
    return 1 if copies else 0


if __name__ == "__main__":
    sys.exit(main())
