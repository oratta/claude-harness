#!/usr/bin/env bats
#
# 守備範囲: 三表と順 3 の一覧がコメント長の上限を超えるときの規則（#1249）。
# 文面の検査は stages/triage.md の節と案内の文字列だけを見て、手順に従って動くかは見ない。
# 動きの検査は、規則のとおりに切った部分から復元の 2 行で作った表ファイルが
# review-hit-set.py を通ることを見る（切る処理はこのファイルのヘルパーで、規則の実装ではない）。
# gh は呼ばず、取得の代わりに部分のファイルを読む。投稿の順と、親の数と取得した部分の数を
# 比べる確認は G と W の手順なのでここでは見ない（部分を丸ごと抜く入力は扱わない）。

bats_require_minimum_version 1.5.0

setup() {
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TRIAGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/triage.md"
  IMPLEMENT="${PLUGIN_DIR}/skills/develop/references/roles/worker/implement.md"
  CHECKER="${PLUGIN_DIR}/scripts/review-hit-set.py"
  WORK="$(mktemp -d "${BATS_TEST_TMPDIR}/work.XXXXXX")"
}

section() {
  awk '/^## コメント長の上限を超えるとき（三表と順 3 の一覧）$/ { found = 1; next }
       found && /^## / { exit }
       found { print }' "$TRIAGE"
}

# 200 行のヒットを持つリポジトリを作り、3 通りの扱いが混ざる修正を commit する。
# 行番号を 3 で割った余りで決める: 0 は直した、1 は該当しない（本文そのまま）、
# 2 は該当しない（本文を書き換えたので補助表に載る）。
# 本文は日本語なので、表は字数では上限に収まりバイト数で超える。
make_repo() {
  REPO="$(mktemp -d "${BATS_TEST_TMPDIR}/repo.XXXXXX")"
  git -C "$REPO" init -q
  git -C "$REPO" config user.name test
  git -C "$REPO" config user.email test@example.com
  python3 - "$REPO/hits.txt" <<'PY'
import sys
pad = "あ" * 200
with open(sys.argv[1], "w", encoding="utf-8") as out:
    for number in range(1, 201):
        out.write(f"needle {number} {pad}\n")
PY
  git -C "$REPO" add .
  git -C "$REPO" commit -qm before
  SHA="$(git -C "$REPO" rev-parse HEAD)"
  python3 - "$REPO/hits.txt" <<'PY'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as src:
    rows = src.read().splitlines()
for index, row in enumerate(rows):
    number = index + 1
    if number % 3 == 0:
        rows[index] = row.replace("needle", "fixed", 1)
    elif number % 3 == 2:
        rows[index] = row + " 書き換え"
with open(path, "w", encoding="utf-8") as out:
    out.write("\n".join(rows) + "\n")
PY
  git -C "$REPO" commit -qam after
  HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
}

# 主表と補助表（分ける対象の本文）を $WORK/body.md に書く。
write_body() {
  python3 - "$WORK/body.md" <<'PY'
import sys
pad = "あ" * 200
with open(sys.argv[1], "w", encoding="utf-8") as out:
    out.write("| ファイル | 行（修正前 SHA） | ヒットした行の本文 | 扱い |\n")
    out.write("|---|---:|---|---|\n")
    for number in range(1, 201):
        handling = "直した" if number % 3 == 0 else "該当しない: 例の中の語"
        out.write(f"| hits.txt | {number} | `needle {number} {pad}` | {handling} |\n")
    out.write("\n### 書き換えた該当しない行\n\n")
    out.write("| ファイル | 行（修正前 SHA） | 修正後の本文 |\n")
    out.write("|---|---:|---|\n")
    for number in range(2, 201, 3):
        out.write(f"| hits.txt | {number} | `needle {number} {pad} 書き換え` |\n")
PY
}

# 分けないときのコメントと同じ内容の表ファイルを作る。
write_unsplit() {
  {
    printf '## 一覧（順 3）\n'
    printf '修正前 SHA: %s\n' "$SHA"
    printf '検索コマンド: git grep -n needle <rev> -- .\n'
    printf '\n'
    cat "$WORK/body.md"
  } > "$WORK/unsplit.md"
}

# body.md を行の境界で切り、部分のコメント $WORK/parts/part-<k>.md を書く。
# 引数が無ければ 65,536 バイトの上限まで詰める。引数があれば、その本文の行番号の前で切る
# （切り方の規則どおり、空行の次の行を引数にしない）。
# 奇数番目の本文は末尾に改行なし、偶数番目は改行ありにして、取得の 2 通りを混ぜる。
split_body() {
  mkdir -p "$WORK/parts"
  python3 - "$WORK/body.md" "$WORK/parts" "$SHA" "$@" <<'PY'
import sys
body_path, parts_dir, sha, *cuts = sys.argv[1:]
limit = 65536
with open(body_path, encoding="utf-8") as src:
    lines = src.read().splitlines()

chunks = []
if cuts:
    start = 0
    for cut in [int(value) - 1 for value in cuts] + [len(lines)]:
        chunks.append(lines[start:cut])
        start = cut
else:
    room = limit - 200  # 部分の先頭の 3 行の分
    current = []
    size = 0
    for index, line in enumerate(lines):
        width = len(line.encode()) + 1
        if size + width > room:
            # 空行で部分を終えない。取得で末尾の改行といっしょに落ちるので、空行は次の部分へ送る。
            carried = []
            while current and current[-1] == "":
                carried.insert(0, current.pop())
            chunks.append(current)
            current = carried
            size = sum(len(row.encode()) + 1 for row in carried)
        current.append(line)
        size += width
    chunks.append(current)

total = len(chunks)
for k, chunk in enumerate(chunks, 1):
    text = f"一覧（順 3）の部分 {k}/{total}\n修正前 SHA: {sha}\n\n" + "\n".join(chunk)
    if k % 2 == 0:
        text += "\n"
    with open(f"{parts_dir}/part-{k}.md", "w", encoding="utf-8") as out:
        out.write(text)
PY
  PART_COUNT="$(find "$WORK/parts" -name 'part-*.md' | wc -l | tr -d ' ')"
}

# stages/triage.md の復元の 2 行のとおりに表ファイルを作る。cat が gh api の代わり。
restore_table() {
  local table="$WORK/restored.md" k body
  {
    printf '## 一覧（順 3）\n'
    printf '修正前 SHA: %s\n' "$SHA"
    printf '検索コマンド: git grep -n needle <rev> -- .\n'
    printf '\n'
  } > "$table"
  for k in $(seq 1 "$PART_COUNT"); do
    body="$(cat "$WORK/parts/part-${k}.md")"
    printf '%s\n' "$body" | tail -n +4 >> "$table"
  done
}

check_table() {
  python3 "$CHECKER" --repo "$REPO" --head "$HEAD_SHA" "$1"
}

# ---- 文面の検査 ----

@test "long comment (#1249): the rule section sits right before the exit section of triage" {
  rule="$(grep -n '^## コメント長の上限を超えるとき（三表と順 3 の一覧）$' "$TRIAGE" | cut -d: -f1)"
  exit_section="$(grep -n '^## 出口$' "$TRIAGE" | cut -d: -f1)"
  [ -n "$rule" ] && [ -n "$exit_section" ]
  [ "$rule" -lt "$exit_section" ]
}

@test "long comment (#1249): length is measured in bytes with wc -c against 65,536" {
  s="$(section)"
  echo "$s" | grep -qF '65,536'
  echo "$s" | grep -qF 'wc -c'
  echo "$s" | grep -qF '分けずに'
}

@test "long comment (#1249): the rule fixes the first lines of parents and parts" {
  s="$(section)"
  echo "$s" | grep -qF '部分 k/n: <コメントの URL>'
  echo "$s" | grep -qF '`レビュー三表の部分 k/n`'
  echo "$s" | grep -qF '`一覧（順 3）の部分 k/n`'
  echo "$s" | grep -qF '`レビュー三表:`'
  echo "$s" | grep -qF '`## 一覧（順 3）`'
  echo "$s" | grep -qF '`固定 HEAD: <40 桁>`'
  echo "$s" | grep -qF '`修正前 SHA: <40 桁>`'
  echo "$s" | grep -qF '`補足済み回数: <0 \| 1>`'
  echo "$s" | grep -qF '`一周目の区画: <なし \| n>`'
  echo "$s" | grep -qF '`検索コマンド: <コマンド>`'
}

@test "long comment (#1249): the rule cuts at line boundaries and never repeats the table header" {
  s="$(section)"
  echo "$s" | grep -qF '行の境界で切る'
  echo "$s" | grep -qF '部分を空行で終えない'
  echo "$s" | grep -qF '表の見出しを部分ごとに繰り返さない'
  echo "$s" | grep -qF '全ヒット要約に置き換えない'
}

@test "long comment (#1249): parts are posted first and the parent last" {
  s="$(section)"
  echo "$s" | grep -qF 'gh pr comment'
  echo "$s" | grep -qF -- '--body-file'
  echo "$s" | grep -qF '親を最後に投稿する'
  echo "$s" | grep -qF '親のない部分は読まない'
  echo "$s" | grep -qF '`needs-reviewer` を返す前に'
  echo "$s" | grep -qF 'push の前に'
}

@test "long comment (#1249): the rule carries the two restore lines and the checks" {
  s="$(section)"
  echo "$s" | grep -qF 'body="$(gh api repos/$R/issues/comments/<コメント ID> --jq .body)"'
  echo "$s" | grep -qF "printf '%s\\n' \"\$body\" | tail -n +4 >> <table-file>"
  echo "$s" | grep -qF '行区切りを 1 個'
  echo "$s" | grep -qF '`部分 k/n:` の行が n 行'
  echo "$s" | grep -qF '同じ PR'
  echo "$s" | grep -qF '`部分 k/n:` の行を入れない'
}

@test "long comment (#1249): unreadable parts stop the existing way" {
  s="$(section)"
  echo "$s" | grep -qF '`review-incomplete`'
  echo "$s" | grep -qF '差し戻し 1 回'
  echo "$s" | grep -qF '照合を行わず'
  echo "$s" | grep -qF '2 回目の `needs-reviewer` を返さない'
}

@test "long comment (#1249): matching after the restore stays on the existing paths" {
  s="$(section)"
  echo "$s" | grep -qF 'review-hit-set.py'
  echo "$s" | grep -qF '場合分けの軸はスクリプトへ渡さず'
  echo "$s" | grep -qF '全域との集合一致'
}

@test "long comment (#1249): a single line over the limit stops both writers" {
  s="$(section)"
  echo "$s" | grep -qF '1 行だけで部分に収まらない'
  echo "$s" | grep -qF '投稿も push もせず'
  echo "$s" | grep -qF '補足の `needs-reviewer` を返さず'
}

@test "long comment (#1249): row 3 of triage points at the rule and keeps its one-comment sentence" {
  grep -qF '全ヒットに「直した／該当しない理由」を付けた表を 1 つの PR コメントに投稿してから push する' "$TRIAGE"
  grep -E '^- 一覧が 65,536 バイトを超えるときは' "$TRIAGE" | grep -qF '「コメント長の上限を超えるとき（三表と順 3 の一覧）」'
}

@test "long comment (#1249): the worker brief points at the rule and at stopping" {
  grep -F '「コメント長の上限を超えるとき（三表と順 3 の一覧）」' "$IMPLEMENT" | grep -qF 'stages/triage.md'
  grep -F '「コメント長の上限を超えるとき（三表と順 3 の一覧）」' "$IMPLEMENT" | grep -qF '投稿も push もせず'
}

# ---- 動きの検査 ----

@test "long comment (#1249): a table within the character limit but over in bytes is split and restores exactly" {
  make_repo
  write_body
  write_unsplit
  [ "$(python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$WORK/unsplit.md")" -le 65536 ]
  [ "$(wc -c < "$WORK/unsplit.md")" -gt 65536 ]
  split_body
  [ "$PART_COUNT" -ge 2 ]
  for k in $(seq 1 "$PART_COUNT"); do
    [ "$(wc -c < "$WORK/parts/part-${k}.md")" -le 65536 ]
  done
  restore_table
  cmp "$WORK/restored.md" "$WORK/unsplit.md"
}

@test "long comment (#1249): the restored table gets the same result as the unsplit table" {
  make_repo
  write_body
  write_unsplit
  split_body
  restore_table
  run --separate-stderr check_table "$WORK/unsplit.md"
  [ "$status" -eq 0 ]
  unsplit_output="$output"
  run --separate-stderr check_table "$WORK/restored.md"
  [ "$status" -eq 0 ]
  [ "$output" = "$unsplit_output" ]
}

@test "long comment (#1249): a boundary inside the rewritten-rows table gives the same result" {
  make_repo
  write_body
  write_unsplit
  heading="$(grep -n '^### 書き換えた該当しない行$' "$WORK/body.md" | cut -d: -f1)"
  # 補助表の見出しのすぐ下と、補助表の行の途中の 2 か所で切る
  split_body "$((heading + 1))" "$((heading + 20))"
  [ "$PART_COUNT" -eq 3 ]
  restore_table
  cmp "$WORK/restored.md" "$WORK/unsplit.md"
  run --separate-stderr check_table "$WORK/restored.md"
  [ "$status" -eq 0 ]
}

@test "long comment (#1249): adjacent parts stay on separate lines without a blank line between" {
  make_repo
  write_body
  write_unsplit
  split_body 90 150
  restore_table
  for k in 1 2; do
    last="$(tail -n 1 "$WORK/parts/part-${k}.md")"
    first="$(tail -n +4 "$WORK/parts/part-$((k + 1)).md" | head -n 1)"
    at="$(grep -nFx -- "$last" "$WORK/restored.md" | cut -d: -f1)"
    [ -n "$at" ]
    [ "$(sed -n "$((at + 1))p" "$WORK/restored.md")" = "$first" ]
  done
}

@test "long comment (#1249): forgetting to drop the part header makes the script refuse the table" {
  make_repo
  write_body
  write_unsplit
  split_body
  { cat "$WORK/unsplit.md"; sed -n 2p "$WORK/parts/part-1.md"; } > "$WORK/with-sha-line.md"
  run --separate-stderr check_table "$WORK/with-sha-line.md"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"contract: 修正前 SHA: must appear exactly once"* ]]
}

@test "long comment (#1249): a main-table row missing from the restored table exits one with missing:" {
  make_repo
  write_body
  write_unsplit
  split_body
  restore_table
  # 3 行目は「直した」の行で、補助表が指していない
  grep -vF '| hits.txt | 3 | `needle 3 ' "$WORK/restored.md" > "$WORK/short.md"
  [ "$(wc -l < "$WORK/short.md")" -eq "$(($(wc -l < "$WORK/restored.md") - 1))" ]
  run --separate-stderr check_table "$WORK/short.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing: hits.txt:3"* ]]
  [[ "$output" != *"contract:"* ]]
}
