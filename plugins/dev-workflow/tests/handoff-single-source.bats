#!/usr/bin/env bats
#
# 手渡し規則の本文が正本 1 箇所にしかないことの機械検査（逐語一致だけ。#265）
#
# 正本: skills/develop/references/decision-criteria.md の「コンテキスト上限（サブエージェントの手渡し）」節。
# 他の面は正本への参照だけを持つ（PR #253）。この検査は、その節の一文（40 文字以上）が
# リポジトリのどこかのファイルにそのまま貼られていないかを見る。
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
}

@test "single source: the canonical section yields enough sentences to scan" {
  run python3 "$SCAN" "$REPO_ROOT"
  [[ "${lines[0]}" =~ ^SENTENCES\ ([0-9]+)$ ]]
  [ "${BASH_REMATCH[1]}" -ge 20 ]
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
  mkdir -p "$d/$(dirname "$CANON_REL")" "$d/plugins/dev-workflow/skills/develop"
  cp "${REPO_ROOT}/${CANON_REL}" "$d/${CANON_REL}"
  sentence="$(awk '/^- \*\*測り方\*\*/{print; exit}' "$d/${CANON_REL}" | sed 's/^- //' | awk -F'。' '{print $1 "。"}')"
  [ "${#sentence}" -ge 40 ]
  printf '前置き\n%s\n後書き\n' "$sentence" > "$d/plugins/dev-workflow/skills/develop/SKILL.md"
  run python3 "$SCAN" "$d"
  rm -rf "$d"
  [ "$status" -eq 1 ]
  [[ "$output" == *"COPY plugins/dev-workflow/skills/develop/SKILL.md"* ]]
}

# 限界の明示: 言い換えは捕まえない（これが落ちるようになったら spec とコメントを書き換えること）
@test "single source: a paraphrase is not detected (documented limitation)" {
  d="$(mktemp -d)"
  mkdir -p "$d/$(dirname "$CANON_REL")"
  cp "${REPO_ROOT}/${CANON_REL}" "$d/${CANON_REL}"
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
