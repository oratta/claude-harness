#!/usr/bin/env bats
#
# casting-catalog / casting-project-files: 構成物の構造要件
# spec: openspec/specs/casting-catalog/spec.md
#   Requirement: カタログ正本の存在と構成 / 常時ロード層の返信前チェック rule
# spec: openspec/specs/casting-project-files/spec.md
#   Requirement: 3層デフォルトの配置規約 / 判例台帳の形式

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  PATH_LINT="${PLUGIN_DIR}/tests/lib/template-path-lint.awk"
  FIXTURES="${PLUGIN_DIR}/tests/fixtures/template-paths"
}

# テンプレのパス表記検査。違反 0 件で exit 0、1 件以上で違反行を出して exit 1。
# LC_ALL=C はマルチバイトの扱いを awk 実装差から切り離すため（macOS awk 対策）。
lint_template_paths() {
  LC_ALL=C awk -f "$PATH_LINT" "$@"
}

# --- Scenario: カタログに version と14観点が入っている ---

@test "catalog: front matter declares version 1" {
  head -5 "$CATALOG" | grep -qx 'version: 1'
}

@test "catalog: all 14 perspectives are present" {
  local names=(
    "法的・規制" "財務・コスト" "信用・レピュテーション" "情報セキュリティ・プライバシー"
    "資産・回復可能性" "報告の正確性"
    "事業方向性・戦略整合" "優先順位・資源配分" "開発スピード・機会損失" "運用工数・維持"
    "技術設計・品質" "ユーザー価値・市場"
    "美意識・ブランド感覚" "感情的受容度"
  )
  for n in "${names[@]}"; do
    LC_ALL=C grep -qF -- "| ${n} " "$CATALOG"
  done
}

# --- Scenario: 列定義がカタログ内に存在する ---

@test "catalog: legend defines all five column names" {
  for col in "観点" "この観点が要る論点の条件" "判断基準の出どころ" "移譲に必要な文書" "既定の担い手"; do
    LC_ALL=C grep -qF -- "$col" "$CATALOG"
  done
}

# --- Scenario: 変更手続きの2ルートが明記されている ---

@test "catalog: documents both change routes" {
  LC_ALL=C grep -qF -- "軽量ルート" "$CATALOG"
  LC_ALL=C grep -qF -- "重量ルート" "$CATALOG"
  LC_ALL=C grep -qF -- "変更記録" "$CATALOG"
}

# --- Scenario: rule が薄く保たれている / README の一覧に載っている ---

@test "rule: perspective-casting.md stays within 30 lines and keeps the 5 steps" {
  RULE="${REPO_ROOT}/rules/perspective-casting.md"
  [ -f "$RULE" ]
  [ "$(wc -l < "$RULE" | tr -d ' ')" -le 30 ]
  LC_ALL=C grep -qF -- "聖域" "$RULE"
  LC_ALL=C grep -qF -- "判例台帳" "$RULE"
  LC_ALL=C grep -qF -- "plugins/casting/catalog/catalog.md" "$RULE"
}

@test "rule: listed in rules/README.md" {
  LC_ALL=C grep -qF -- "perspective-casting.md" "${REPO_ROOT}/rules/README.md"
}

# --- Scenario: 3層の配置と判例台帳形式が定義されている ---

@test "skill: defines the three layers and the session declaration" {
  SKILL="${PLUGIN_DIR}/skills/casting/SKILL.md"
  LC_ALL=C grep -qF -- "project.md" "$SKILL"
  LC_ALL=C grep -qF -- "local.md" "$SKILL"
  LC_ALL=C grep -qF -- "セッション" "$SKILL"
}

@test "templates: both carry catalog_version 1 front matter" {
  head -3 "${PLUGIN_DIR}/templates/project.md" | grep -qx 'catalog_version: 1'
  head -3 "${PLUGIN_DIR}/templates/precedents.md" | grep -qx 'catalog_version: 1'
}

@test "template precedents: example carries the four fields" {
  T="${PLUGIN_DIR}/templates/precedents.md"
  for f in "観点" "経路" "帰結" "還元"; do
    LC_ALL=C grep -qF -- "- ${f}: " "$T"
  done
}

# --- Scenario: テンプレのパス表記が生成先 repo ルートから解決できる ---
# issue #116: プラグイン内相対のパス表記（scripts/… skills/… plugins/casting/…）は
# /casting:init の生成先 repo ルートから解決できないため、テンプレに含めない
# issue #137: 検出をコードスパンの先頭からスパン内の任意位置に広げる。検査ロジックは
# tests/lib/template-path-lint.awk に切り出し、下のフィクスチャで検査自体を検証する

@test "templates: no plugin-internal relative path notation in code spans" {
  run lint_template_paths "${PLUGIN_DIR}"/templates/*.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "path lint: flags a plugin-internal path that is not at the head of the code span" {
  run lint_template_paths "${FIXTURES}/violation-mid-span.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/casting-check.sh"* ]]
}

@test "path lint: flags quoted tokens inside a code span" {
  run lint_template_paths "${FIXTURES}/violation-quoted-token.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/casting-check.sh"* ]]
  [[ "$output" == *"skills/casting/SKILL.md"* ]]
}

@test "path lint: flags a multi-backtick code span" {
  run lint_template_paths "${FIXTURES}/violation-double-backtick.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/casting-check.sh"* ]]
}

@test "path lint: flags a plugin-internal path inside a fenced code block" {
  run lint_template_paths "${FIXTURES}/violation-fenced-block.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/casting/scripts/casting-check.sh"* ]]
}

@test "path lint: stays inside the fence when a different fence marker appears" {
  run lint_template_paths "${FIXTURES}/violation-nested-fence.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/casting/scripts/casting-check.sh"* ]]
}

# 検出プレフィックスを1つ削っても全フィクスチャが通ってしまう状態を防ぐ
@test "path lint: the violation fixtures exercise all three forbidden prefixes" {
  run lint_template_paths "${FIXTURES}"/violation-*.md
  [ "$status" -eq 1 ]
  [[ "$output" == *": scripts/"* ]]
  [[ "$output" == *": skills/"* ]]
  [[ "$output" == *": plugins/casting/"* ]]
}

@test "path lint: passes install-path notation that contains the plugin directory names" {
  run lint_template_paths "${FIXTURES}/ok-install-path.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "path lint: passes forbidden tokens that sit in plain text outside code spans" {
  run lint_template_paths "${FIXTURES}/ok-plain-text-outside-span.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "path lint: passes backslash-escaped backticks (not code span delimiters)" {
  run lint_template_paths "${FIXTURES}/ok-escaped-backtick.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- marketplace 登録 ---

@test "marketplace: casting plugin is registered" {
  M="${REPO_ROOT}/.claude-plugin/marketplace.json"
  LC_ALL=C grep -qF -- '"name": "casting"' "$M"
  [ -f "${PLUGIN_DIR}/.claude-plugin/plugin.json" ]
}

# --- 検出項目数の表記と実装の一致 ---
#
# spec: openspec/specs/casting-project-files/spec.md
#   Requirement: 検出項目数の表記と実装の一致
#
# 検出0（malformed-row）を後から足したときに、文書側が「4項目」のまま取り残された
# 事故（#141）の再発防止。実装が報告する検出カテゴリ（report の第1引数）を
# スクリプトから機械的に取り、「N項目」と書いている文書がその数と一致するかを見る。

CHECK_SCRIPT() { printf '%s\n' "${PLUGIN_DIR}/scripts/casting-check.sh"; }

# 行頭コメント行を落とした本文を出す（コメント中の report "..." を数えないため）。
# 引数でスクリプトを差し替えられるのは、数え方そのものを検査するテストが
# 合成スクリプトを食わせるため（既定は casting-check.sh 本体）。
check_script_body() {
  LC_ALL=C sed -E 's/^[[:space:]]*#.*$//' "${1:-$(CHECK_SCRIPT)}"
}

# report の実呼び出しから検出カテゴリ名を1行1件で出す。
#   - report と第1引数の間の空白は可変（空白2個・タブでもすり抜けない）
#   - report() の定義行は直後が "(" なので拾わない
detection_categories() {
  check_script_body "$@" \
    | LC_ALL=C grep -oE '(^|[;&|(){}[:space:]])report[[:space:]]+"[a-z][a-z-]*"' \
    | LC_ALL=C sed -E 's/.*report[[:space:]]+"([a-z][a-z-]*)".*/\1/' \
    | LC_ALL=C sort -u
}

detection_category_count() {
  detection_categories "$@" | wc -l | tr -d ' '
}

# 呼び出しは「行数」ではなく「出現数」で数える。grep -c は一致した行数しか返さないので、
# 1行に `report "literal" …; report "$var" …` と並べると calls == literal になり、
# 非リテラル呼び出しがこの検査をすり抜ける（Codex レビュー指摘・実測で再現）。
count_report_calls() { check_script_body "$@" \
  | LC_ALL=C grep -oE '(^|[;&|(){}[:space:]])report[[:space:]]+[^[:space:]]' | wc -l | tr -d ' '; }
count_literal_report_calls() { check_script_body "$@" \
  | LC_ALL=C grep -oE '(^|[;&|(){}[:space:]])report[[:space:]]+"[a-z][a-z-]*"' | wc -l | tr -d ' '; }

# 第1引数がリテラルでない report 呼び出し（report "$var" 等）があると
# detection_categories が黙って数え漏らす。数え方の前提そのものを検査する。
@test "check: every report call passes a literal lowercase category as its first argument" {
  local calls literal
  calls="$(count_report_calls)"
  literal="$(count_literal_report_calls)"
  if [ "$calls" != "$literal" ]; then
    echo "report の呼び出し ${calls} 件のうちリテラルの第1引数は ${literal} 件。" >&2
    echo "リテラルでない呼び出しは検出カテゴリの数え方（detection_categories）から漏れる。" >&2
    check_script_body | LC_ALL=C grep -nE '(^|[;&|(){}[:space:]])report[[:space:]]+[^"]' >&2 || true
    return 1
  fi
  [ "$calls" -ge 1 ]
}

# 上の検査が「行数」で数えていた頃は、1行に2件並べると非リテラル呼び出しを見逃した。
# 合成スクリプトで、同一行の混在・行継続の両方が数え方に乗ることを直接確かめる。
@test "check: the report-call counter counts occurrences, not lines" {
  local synthetic="${BATS_TEST_TMPDIR}/casting-check-synthetic.sh"

  # 同一行にリテラルと非リテラルを並べた形
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'report() { printf "[%s] %s\n" "$1" "$2"; }' \
    '  report "malformed-row" "a"; report "${EXTRA:-sixth-category}" "b"' \
    > "$synthetic"
  [ "$(count_report_calls "$synthetic")" = "2" ]
  [ "$(count_literal_report_calls "$synthetic")" = "1" ]
  [ "$(detection_category_count "$synthetic")" = "1" ]

  # 行継続で第1引数を次の行に送った形
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'report() { printf "[%s] %s\n" "$1" "$2"; }' \
    '  report \' \
    '    "sixth-category" "b"' \
    > "$synthetic"
  [ "$(count_report_calls "$synthetic")" = "1" ]
  [ "$(count_literal_report_calls "$synthetic")" = "0" ]
}

@test "check: detection categories in casting-check.sh are the documented six" {
  local expected actual
  expected="catalog-external-precedent consultation-missing-element malformed-row repeated-not-issue unknown-vocab version-mismatch"
  actual="$(detection_categories | tr '\n' ' ')"
  actual="${actual% }"
  if [ "$actual" != "$expected" ]; then
    echo "検出カテゴリが変わっている。実装: [${actual}] / テストの想定: [${expected}]" >&2
    echo "カテゴリを増減したら、この配列と文書の「N項目」表記の両方を直すこと。" >&2
    return 1
  fi
}

# 「N項目」と書いている全文書を、出現ごとに実装のカテゴリ数と突き合わせる。
# 全角数字（「５項目」）も半角に正規化してから比較するので、片側だけ全角で
# 残した状態も落ちる。失敗時は実装側の数と文書側の表記の両方を出す。
@test "docs: item-count wording in README, SKILL, script, plugin.json and marketplace.json matches the implementation" {
  local n
  n="$(detection_category_count)"
  [ "$n" -ge 1 ]

  run python3 - "$n" "${PLUGIN_DIR}" "${REPO_ROOT}/.claude-plugin/marketplace.json" <<'PY'
import json, re, sys, unicodedata

n = int(sys.argv[1])
plugin_dir, marketplace_path = sys.argv[2], sys.argv[3]

targets = {}
for rel in ("README.md", "skills/casting/SKILL.md",
            "scripts/casting-check.sh", ".claude-plugin/plugin.json"):
    with open(f"{plugin_dir}/{rel}", encoding="utf-8") as fh:
        targets[rel] = fh.read()

with open(marketplace_path, encoding="utf-8") as fh:
    entries = json.load(fh)["plugins"]
desc = next((e["description"] for e in entries if e.get("name") == "casting"), None)
if desc is None:
    print("marketplace.json に casting エントリが無い")
    raise SystemExit(1)
targets["marketplace.json (casting description)"] = desc

pattern = re.compile(r"([0-9０-９]+)項目")
failures = []
for name, text in targets.items():
    found = [int(unicodedata.normalize("NFKC", m)) for m in pattern.findall(text)]
    if not found:
        failures.append(f"{name}: 実装の検出カテゴリ数は {n} だが「{n}項目」の記述が無い")
        continue
    stale = sorted({v for v in found if v != n})
    if stale:
        failures.append(
            f"{name}: 実装の検出カテゴリ数は {n} だが文書の表記は {stale}（全角も半角に正規化して比較）"
        )

for line in failures:
    print(line)
raise SystemExit(1 if failures else 0)
PY

  if [ "$status" -ne 0 ]; then
    echo "$output" >&2
    return 1
  fi
}
