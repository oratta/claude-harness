#!/usr/bin/env bats
#
# 手渡し規則の本文が正本 1 箇所にしかないことの機械検査（逐語一致だけ。#265）
#
# 正本は 2 か所（#1683）: skills/develop/references/decision-criteria.md の「コンテキスト上限（サブエージェントの手渡し）」節
# （本体向け）と、skills/develop/references/return-declaration.md の全文（W と G の宣言）。
# 他の面は正本への参照だけを持つ（PR #253）。この検査は、どちらかの正本の一文（40 文字以上）が
# 自分以外のファイル（もう片方の正本を含む）にそのまま貼られていないかを見る。
#
# 緑が保証すること: 正本の節の一文が、正本以外のどの追跡ファイルにも逐語では存在しない。
# 緑が保証しないこと:
#   - 言い換えは検出しない（任意の言い換えを機械で検出することは原理的にできない。PR #253 で
#     ゲート 7 周・仕様レビュー 4 周を使って収束しなかった）
#   - 40 文字未満の短い句、一文を割って貼った写し、語順を変えた写しは検出しない
#   - 表・コードブロックの行は対象外
# 言い換えの再掲を捕まえるのは spec の MUST NOT と仕様レビューである。
# 「何も見ていない緑」を避けるため、(1) 正本の節から十分な件数の文を読めていること、
# (2) 実際に貼り付けた写しで落ちること、の 2 つを別のテストで固定する。
#
# spec: dev-workflow-handoff-single-source

setup() {
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SCAN="${PLUGIN_DIR}/tests/lib/handoff-verbatim.py"
  CANON_REL="plugins/dev-workflow/skills/develop/references/decision-criteria.md"
  DECL_REL="plugins/dev-workflow/skills/develop/references/return-declaration.md"
}

# 使い捨ての root に 2 つの正本を写す
copy_canons() {
  mkdir -p "$1/$(dirname "$CANON_REL")"
  cp "${REPO_ROOT}/${CANON_REL}" "$1/${CANON_REL}"
  cp "${REPO_ROOT}/${DECL_REL}" "$1/${DECL_REL}"
}

@test "single source: the canonical section yields enough sentences to scan" {
  run python3 "$SCAN" "$REPO_ROOT"
  [ "${lines[0]%% *}" = "SENTENCES" ]
  [ "${lines[0]##* }" -ge 20 ]
}

@test "single source: no sentence of the canonical section is pasted verbatim elsewhere" {
  run python3 "$SCAN" "$REPO_ROOT"
  if [ "$status" -ne 0 ]; then
    echo "$output"
    echo "正本の一文がそのまま貼られている。正本への参照に置き換えること"
    return 1
  fi
}

# 負例: 正本の一文を別ファイルへコピーすると落ちる（検査が何かを見ていることの証拠）
@test "single source: pasting one canonical sentence into another file fails the scan" {
  d="$(mktemp -d)"
  copy_canons "$d"
  sentence="$(awk '/^- \*\*測り方\*\*/{print; exit}' "$d/${CANON_REL}" | sed 's/^- //' | awk -F'。' '{print $1 "。"}')"
  [ "${#sentence}" -ge 40 ]
  printf '前置き\n%s\n後書き\n' "$sentence" > "$d/plugins/dev-workflow/skills/develop/SKILL.md"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF "COPY plugins/dev-workflow/skills/develop/SKILL.md"
}

# #### 以下の小見出しは節の中として走査を続ける（レビュー指摘: 4 階層の見出しで走査が打ち切られていた）
@test "single source: a level-4 heading inside the section does not end the scan" {
  d="$(mktemp -d)"
  copy_canons "$d"
  {
    printf '## コンテキスト上限（サブエージェントの手渡し）\n\n#### 小見出し\n\n'
    printf 'これは四階層の見出しより後ろにある、四十文字を超える長さの正本の一文であるものとする。\n\n## 次の節\n'
  } > "$d/${CANON_REL}"
  printf 'これは四階層の見出しより後ろにある、四十文字を超える長さの正本の一文であるものとする。\n' > "$d/other.md"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 1 ]
}

# 限界の明示: 言い換えは捕まえない（これが落ちるようになったら spec とコメントを書き換えること）
@test "single source: a paraphrase is not detected (documented limitation)" {
  d="$(mktemp -d)"
  copy_canons "$d"
  printf 'W を再開する前に毎回、本体がサブエージェントのコンテキスト量を測る。上限を超えたら再開しない。\n' > "$d/other.md"
  run python3 "$SCAN" "$d"
  [ "$status" -eq 0 ]
}

@test "single source: an unreadable canonical section is an error, not a green" {
  d="$(mktemp -d)"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 2 ]
}

# return-declaration.md の一文を別のファイルに写すと落ちる（#1683）
@test "single source: pasting one return-declaration sentence into another file fails the scan" {
  d="$(mktemp -d)"
  copy_canons "$d"
  sentence="$(grep -F '成果一覧を書いていても、そのバックグラウンドコマンドが' "$d/${DECL_REL}" | sed 's/^ *//' | awk -F'。' '{print $1 "。"}')"
  [ "${#sentence}" -ge 40 ]
  printf '前置き\n%s\n後書き\n' "$sentence" > "$d/other.md"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF "COPY other.md"
}

# 一方の正本の一文をもう一方の正本に貼っても落ちる（互いを除外しない。#1683）
@test "single source: pasting a decision-criteria sentence into return-declaration.md fails the scan" {
  d="$(mktemp -d)"
  copy_canons "$d"
  sentence="$(awk '/^- \*\*測り方\*\*/{print; exit}' "$d/${CANON_REL}" | sed 's/^- //' | awk -F'。' '{print $1 "。"}')"
  [ "${#sentence}" -ge 40 ]
  printf '\n%s\n' "$sentence" >> "$d/${DECL_REL}"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF "COPY ${DECL_REL}"
}

# どちらか片方の正本が無いと exit 2（#1683）
@test "single source: a missing return-declaration.md is an error, not a green" {
  d="$(mktemp -d)"
  copy_canons "$d"
  rm -f "$d/${DECL_REL}"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 2 ]
}

@test "single source: a missing decision-criteria.md is an error, not a green" {
  d="$(mktemp -d)"
  copy_canons "$d"
  rm -f "$d/${CANON_REL}"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 2 ]
}
