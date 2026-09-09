#!/usr/bin/env bats
# injection-budget.bats — 常時注入される「固定分」の合計サイズに予算を置くゲート（issue #258）
#
# 全セッション・全サブエージェントの起動直後に必ず載る固定分（rules / CLAUDE.md /
# output-styles / 各種 description）は、誰も見ていない間に増え続ける。実行時に切り捨てる
# 仕組みは作らず（どのルールが落ちたか誰も気づけない）、編集時にこのテストで止めて
# 「削るか、予算を動かすか」を PR の diff として主の前に出す。
#
# 予算値は tests/injection-budget.txt（数値 1 行）。閾値をこのファイルに直書きしない。
# 判定は上下両方向のラチェット: 実測が予算を超えたら fail、予算が実測の 1.1 倍を超えても
# fail。削減 PR に予算の引き下げを強制し、削った分が次の増加の余地として残らないようにする。
#
# 測定単位はバイト（wc -c）。文字数（wc -m）はロケール依存で、CI（ubuntu-latest、LC_ALL 未設定）
# と手元（en_US.UTF-8）で同じ日本語ファイルが違う値になるため使わない。
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  BUDGET_FILE="$REPO_ROOT/tests/injection-budget.txt"
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPD"
}

# ── 集計ヘルパ（すべて「ファイルの一覧を引数で渡す」形。テストは実 repo の
#    ファイルを 1 バイトも書き換えず、渡す一覧を差し替えて異常系を作る）──────

# sum_files <file...> — 渡されたファイルの wc -c の合計（バイト）を返す。
sum_files() {
  local total=0 n f
  for f in "$@"; do
    [ -f "$f" ] || continue
    n=$(wc -c < "$f")
    total=$((total + n))
  done
  printf '%s\n' "$total"
}

# list_synced_md <dir> — <dir>/*.md から basename が README.md のものを除いた一覧。
# 注入対象の正本は scripts/sync.sh の link_dir（sync.sh:76-79 と 108-109 の 2 呼び出し）。
# rules と output-styles はどちらも同じ 1 条件なので、テストは独自の除外リストを持たない。
list_synced_md() {
  local f b
  for f in "$1"/*.md; do
    if [ -f "$f" ]; then
      b=$(basename "$f")
      if [ "$b" != "README.md" ]; then
        printf '%s\n' "$f"
      fi
    fi
  done
}

# sum_descriptions <file...> — 各ファイルの frontmatter の最初の description 行から
# `description:` の接頭辞と続く空白を落とした**値のみ**のバイト数を足す。
# 末尾改行は数えない（printf '%s' で改行を付けずに wc -c へ流す）。1 行ずつ改行込みで
# 流すとファイル本数ぶん（現状 59 バイト）ずれるため、この定義を動かさない。
sum_descriptions() {
  local total=0 f v n
  for f in "$@"; do
    [ -f "$f" ] || continue
    v=$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//')
    n=$(printf '%s' "$v" | wc -c)
    total=$((total + n))
  done
  printf '%s\n' "$total"
}

# description を持つカテゴリの一覧。1 階層深いディレクトリに置いて集計から逃げる経路を
# 残さないため、glob ではなく find でディレクトリ配下を任意の深さで走査する。
list_under() { # <dir> <find の -name パターン> [<find の -path パターン>]
  [ -d "$1" ] || return 0
  if [ "$#" -ge 3 ]; then
    find "$1" -type f -name "$2" -path "$3" | LC_ALL=C sort
  else
    find "$1" -type f -name "$2" | LC_ALL=C sort
  fi
}

list_plugin_skills()   { list_under "$REPO_ROOT/plugins" 'SKILL.md' '*/skills/*'; }
list_plugin_agents()   { list_under "$REPO_ROOT/plugins" '*.md' '*/agents/*'; }
list_plugin_commands() { list_under "$REPO_ROOT/plugins" '*.md' '*/commands/*'; }
list_local_skills()    { list_under "$REPO_ROOT/.claude/skills" 'SKILL.md'; }
list_local_commands()  { list_under "$REPO_ROOT/.claude/commands" '*.md'; }

# すべての description 対象ファイル（折りたたみ記法ガードの対象でもある）。
list_all_description_files() {
  list_plugin_skills
  list_plugin_agents
  list_plugin_commands
  list_local_skills
  list_local_commands
}

# ── 内訳と合計 ──────────────────────────────────────────────
# 内訳は「表示名 <TAB> バイト数」を 8 行。AGENTS.md は CLAUDE.md の同期複製
# （tests/agents-md-sync.bats が同一性を強制）で、セッションに注入されるのは片方だけ
# なので測定対象に含めない（含めると同じ文が二重計上される）。
#
# 一覧は改行区切りで、引数として単語分割させて渡す（このリポの git パスに空白は無い。
# scripts/test.sh が bats へ $SUITES を渡すのと同じ前提）。
# shellcheck disable=SC2046
breakdown() {
  printf '%s\t%s\n' "rules/*.md"        "$(sum_files $(list_synced_md "$REPO_ROOT/rules"))"
  printf '%s\t%s\n' "CLAUDE.md"         "$(sum_files "$REPO_ROOT/CLAUDE.md")"
  printf '%s\t%s\n' "output-styles/*.md（メインセッションのみ。サブエージェントには載らない）" \
                                        "$(sum_files $(list_synced_md "$REPO_ROOT/output-styles"))"
  printf '%s\t%s\n' "plugins SKILL.md description"   "$(sum_descriptions $(list_plugin_skills))"
  printf '%s\t%s\n' "plugins agent description"      "$(sum_descriptions $(list_plugin_agents))"
  printf '%s\t%s\n' "plugins command description"    "$(sum_descriptions $(list_plugin_commands))"
  printf '%s\t%s\n' ".claude/skills SKILL.md description" "$(sum_descriptions $(list_local_skills))"
  printf '%s\t%s\n' ".claude/commands description"   "$(sum_descriptions $(list_local_commands))"
}

sum_breakdown() { # 内訳テキストを stdin から受け、バイト数の列を足す
  awk -F'\t' '{ s += $2 } END { print s + 0 }'
}

read_budget() {
  tr -d '[:space:]' < "$BUDGET_FILE"
}

# ── 判定（整数演算のみ。浮動小数点を使わない）────────────────────
# (a) total > budget            → 超過側 fail
# (b) budget * 10 > total * 11  → 下振れ側 fail（budget > 1.1 * total の整数等価）
# (c) それ以外                  → pass（budget == total は pass）
verdict() { # <budget> <total> → over | under | ok
  local budget="$1" total="$2"
  if [ "$total" -gt "$budget" ]; then printf 'over\n'; return 0; fi
  if [ $((budget * 10)) -gt $((total * 11)) ]; then printf 'under\n'; return 0; fi
  printf 'ok\n'
}

# 推奨予算 = 実測 + 約 5%（整数演算）。
recommended_budget() { printf '%s\n' "$(( $1 + $1 / 20 ))"; }

# ── 失敗時の出力（予算・実測・差分量／どちら側か／8 種の内訳／取るべき行動）──
report() { # <verdict> <budget> <total> <内訳テキスト>
  local v="$1" budget="$2" total="$3" lines="$4" name bytes
  if [ "$v" = "over" ]; then
    echo "注入予算オーバー（超過側 fail）: 予算 ${budget} バイト / 実測 ${total} バイト / 超過 $((total - budget)) バイト"
  else
    echo "注入予算の下振れ（下振れ側 fail）: 予算 ${budget} バイト / 実測 ${total} バイト / 下振れ $((budget - total)) バイト"
  fi
  echo "--- 内訳（測定対象 8 種）---"
  printf '%s\n' "$lines" | while IFS=$'\t' read -r name bytes; do
    printf '  %8s バイト  %s\n' "$bytes" "$name"
  done
  echo "--- 取るべき行動 ---"
  if [ "$v" = "over" ]; then
    echo "  (1) 固定分を削る（内訳の大きい行から、常時注入をやめて必要時読み込みへ移す）"
    echo "  (2) tests/injection-budget.txt を上げて、PR 本文に理由を書く（何を削ろうとして、なぜ超えるままにするか）"
    echo "      予算ファイルは聖域なので、動かす PR は機械マージされず人間のマージになる"
  else
    echo "  tests/injection-budget.txt を推奨値 $(recommended_budget "$total")（実測 + 約 5%）に下げる"
    echo "  削った分を予算に残さないためのラチェット。引き下げも同じ diff に載せること"
  fi
}

# ── 折りたたみ記法のガード ──────────────────────────────────
# description の値が単一行であることを検査する。YAML の折りたたみ／リテラル記法
# （> | >- |- >+ |+）を使うと 2 行目以降が集計から漏れ、description を無制限に
# 増やせてしまう。違反したファイル名を出力し、1 件でもあれば 1 を返す。
check_single_line_description() { # <file...>
  local f n v next rc=0
  for f in "$@"; do
    [ -f "$f" ] || continue
    n=$(grep -n -m1 '^description:' "$f" | cut -d: -f1)
    [ -n "$n" ] || continue
    v=$(sed -n "${n}p" "$f" | sed 's/^description:[[:space:]]*//')
    case "$v" in
      '>'*|'|'*) printf '%s\n' "$f"; rc=1; continue ;;
    esac
    next=$(sed -n "$((n + 1))p" "$f")
    case "$next" in
      '---') continue ;;
    esac
    if printf '%s' "$next" | grep -qE '^[A-Za-z_][A-Za-z0-9_-]*:'; then
      continue
    fi
    printf '%s\n' "$f"
    rc=1
  done
  return "$rc"
}

# ══ 1. 集計ヘルパ ══════════════════════════════════════════

@test "sum_files adds up the byte counts of the given list" {
  printf '12345' > "$TMPD/a.md"      # 5 bytes
  printf '1234567890' > "$TMPD/b.md" # 10 bytes
  run sum_files "$TMPD/a.md" "$TMPD/b.md"
  [ "$status" -eq 0 ]
  [ "$output" -eq 15 ]
}

@test "README.md is excluded from rules and output-styles listings" {
  printf '1234567890' > "$TMPD/README.md"
  printf '12345' > "$TMPD/kept.md"
  printf '12345' > "$TMPD/also-kept.md"
  run list_synced_md "$TMPD"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c 'README.md')" -eq 0 ]
  # shellcheck disable=SC2046
  run sum_files $(list_synced_md "$TMPD")
  [ "$output" -eq 10 ]
}

@test "description totals do not count trailing newlines" {
  # 値が 12 バイト（"012345678901"）の description を 3 本。合計はちょうど 36。
  # 1 行ずつ改行込みで wc -c に流すと 39 になる（ファイル本数ぶんのずれ）。
  local i
  for i in 1 2 3; do
    printf -- '---\nname: f%s\ndescription: 012345678901\n---\nbody\n' "$i" > "$TMPD/f$i.md"
  done
  run sum_descriptions "$TMPD/f1.md" "$TMPD/f2.md" "$TMPD/f3.md"
  [ "$status" -eq 0 ]
  [ "$output" -eq 36 ]
}

@test "description listings walk directories at any depth" {
  mkdir -p "$TMPD/commands/a/b"
  printf -- '---\ndescription: 0123456789\n---\n' > "$TMPD/commands/top.md"
  printf -- '---\ndescription: 0123456789\n---\n' > "$TMPD/commands/a/b/deep.md"
  run list_under "$TMPD/commands" '*.md'
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c 'deep.md')" -eq 1 ]
  # shellcheck disable=SC2046
  run sum_descriptions $(list_under "$TMPD/commands" '*.md')
  [ "$output" -eq 20 ]
}

# ══ 2. 予算ファイルと判定 ═══════════════════════════════════

@test "budget file holds a single integer" {
  [ -f "$BUDGET_FILE" ]
  run read_budget
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "this suite is picked up by the dynamic test discovery" {
  run git -C "$REPO_ROOT" ls-files -- '*.bats'
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^tests/injection-budget.bats$')" -eq 1 ]
}

@test "current total stays inside the budget (resident ratchet, both directions)" {
  local total budget v
  total=$(breakdown | sum_breakdown)
  budget=$(read_budget)
  v=$(verdict "$budget" "$total")
  if [ "$v" != "ok" ]; then
    report "$v" "$budget" "$total" "$(breakdown)" >&2
  fi
  [ "$v" = "ok" ]
}

@test "the budget keeps roughly 5 percent of headroom at introduction" {
  local total budget
  total=$(breakdown | sum_breakdown)
  budget=$(read_budget)
  [ "$budget" -ge "$total" ]
  [ $((budget * 10)) -le $((total * 11)) ]
}

@test "the threshold is read from the budget file, not hardcoded in the suite" {
  local budget
  budget=$(read_budget)
  run grep -c -- "$budget" "$BATS_TEST_FILENAME"
  [ "$output" -eq 0 ]
}

@test "budget equal to the total passes" {
  # 判定は純粋な整数演算なので、実測とは無関係の合成値で境界を固定する。
  run verdict 12345 12345
  [ "$output" = "ok" ]
}

@test "total one byte above the budget fails on the over side" {
  run verdict 12345 12346
  [ "$output" = "over" ]
}

@test "the smallest budget satisfying budget*10 > total*11 fails on the under side" {
  # 「実測 x 1.1 + 1」は実測が 10 の倍数でないと整数にならないので使わない。
  # budget * 10 > total * 11 を満たす最小の budget = floor(total * 11 / 10) + 1。
  local total=12345 smallest
  smallest=$(( total * 11 / 10 + 1 ))
  run verdict "$smallest" "$total"
  [ "$output" = "under" ]
  run verdict "$((smallest - 1))" "$total"
  [ "$output" = "ok" ]
}

@test "an over-budget failure is cleared by changing the budget value alone" {
  # 実 repo のファイルは書き換えず、集計ヘルパに渡す一覧に余分なファイルを足して超過を作る。
  local base extra total budget raised
  # shellcheck disable=SC2046
  base=$(sum_files $(list_synced_md "$REPO_ROOT/rules"))
  budget=$(read_budget)
  # 予算を確実に超える大きさの余分なファイルを 1 本足す
  head -c $((budget + 1)) /dev/zero | tr '\0' 'x' > "$TMPD/extra.md"
  # shellcheck disable=SC2046
  total=$(sum_files $(list_synced_md "$REPO_ROOT/rules") "$TMPD/extra.md")
  [ "$total" -gt "$base" ]
  [ "$(verdict "$budget" "$total")" = "over" ]
  # 予算値だけを「超過量以上、かつ実測の 1.1 倍以下」に変える（このファイルは 1 文字も変えない）
  raised=$(recommended_budget "$total")
  [ "$(verdict "$raised" "$total")" = "ok" ]
}

# ══ 3. 失敗時の出力 ═════════════════════════════════════════

@test "the over-budget report shows budget, total and the overshoot" {
  run report over 50000 52000 "$(breakdown)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"50000"* ]]
  [[ "$output" == *"52000"* ]]
  [[ "$output" == *"2000"* ]]
  [[ "$output" == *"超過側 fail"* ]]
}

@test "the over-budget report lists all eight categories" {
  run report over 50000 52000 "$(breakdown)"
  [[ "$output" == *"rules/*.md"* ]]
  [[ "$output" == *"CLAUDE.md"* ]]
  [[ "$output" == *"output-styles/*.md"* ]]
  [[ "$output" == *"plugins SKILL.md description"* ]]
  [[ "$output" == *"plugins agent description"* ]]
  [[ "$output" == *"plugins command description"* ]]
  [[ "$output" == *".claude/skills SKILL.md description"* ]]
  [[ "$output" == *".claude/commands description"* ]]
}

@test "the output-styles line carries the main-session-only note" {
  run report over 50000 52000 "$(breakdown)"
  [[ "$output" == *"メインセッションのみ"* ]]
}

@test "the over-budget report offers both available actions" {
  run report over 50000 52000 "$(breakdown)"
  [[ "$output" == *"固定分を削る"* ]]
  [[ "$output" == *"tests/injection-budget.txt を上げて"* ]]
  [[ "$output" == *"PR 本文に理由を書く"* ]]
}

@test "the under-budget report names a concrete recommended value" {
  # 実測 40000・予算 52000 は下振れ側（52000 * 10 > 40000 * 11）。推奨値は 42000。
  [ "$(verdict 52000 40000)" = "under" ]
  run report under 52000 40000 "$(breakdown)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"下振れ側 fail"* ]]
  [[ "$output" == *"12000"* ]]
  [[ "$output" == *"42000"* ]]
  [[ "$output" == *"tests/injection-budget.txt を推奨値"* ]]
  [[ "$output" == *"内訳（測定対象 8 種）"* ]]
}

@test "removing more than ten percent of the total fails on the under side" {
  # 集計ヘルパに渡す一覧から rules を丸ごと落とす（合計の 10% を超える削減）。
  local full reduced budget
  full=$(breakdown | sum_breakdown)
  # shellcheck disable=SC2046
  reduced=$(( full - $(sum_files $(list_synced_md "$REPO_ROOT/rules")) ))
  budget=$(read_budget)
  [ "$(verdict "$budget" "$reduced")" = "under" ]
}

# ══ 4. 折りたたみ記法のガード ═══════════════════════════════

@test "every measured description in the repo is written on a single line" {
  # shellcheck disable=SC2046
  run check_single_line_description $(list_all_description_files)
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the guard covers all measured description files" {
  # 5 カテゴリすべてがガードの対象に入っていること（どれかが 0 件なら glob の書き間違い）。
  [ "$(list_plugin_skills | wc -l)" -ge 1 ]
  [ "$(list_plugin_agents | wc -l)" -ge 1 ]
  [ "$(list_plugin_commands | wc -l)" -ge 1 ]
  [ "$(list_local_skills | wc -l)" -ge 1 ]
  [ "$(list_local_commands | wc -l)" -ge 1 ]
  # 合計は description を集計する対象と一致する。
  [ "$(list_all_description_files | wc -l)" -eq "$(( $(list_plugin_skills | wc -l) + $(list_plugin_agents | wc -l) + $(list_plugin_commands | wc -l) + $(list_local_skills | wc -l) + $(list_local_commands | wc -l) ))" ]
}

@test "a folded description is detected and its filename is printed" {
  printf -- '---\nname: evil\ndescription: >\n  first line of the folded value\n  second line hidden from the total\n---\nbody\n' > "$TMPD/evil.md"
  run check_single_line_description "$TMPD/evil.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil.md"* ]]
}

@test "a literal block description is detected" {
  printf -- '---\nname: evil2\ndescription: |\n  hidden\n---\nbody\n' > "$TMPD/evil2.md"
  run check_single_line_description "$TMPD/evil2.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil2.md"* ]]
}

@test "a continuation line without a folding marker is detected" {
  printf -- '---\nname: evil3\ndescription: visible part\n  hidden continuation\n---\nbody\n' > "$TMPD/evil3.md"
  run check_single_line_description "$TMPD/evil3.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil3.md"* ]]
}

@test "a single line description passes the guard" {
  printf -- '---\nname: fine\ndescription: all on one line\nversion: 1.0.0\n---\nbody\n' > "$TMPD/fine.md"
  run check_single_line_description "$TMPD/fine.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ══ 5-6. 聖域と変更手続き ════════════════════════════════════

@test "the budget file is matched by the SACRED regex of auto-merge.yml" {
  local sacred
  sacred=$(grep -m1 "SACRED='" "$REPO_ROOT/.github/workflows/auto-merge.yml" | sed "s/^ *SACRED='//; s/'\$//")
  [ -n "$sacred" ]
  run grep -qE "$sacred" <<< "tests/injection-budget.txt"
  [ "$status" -eq 0 ]
}

@test "the auto-merge invariants script lists the budget file as a must-match path" {
  run grep -c 'tests/injection-budget.txt' "$REPO_ROOT/scripts/test-auto-merge-workflow.sh"
  [ "$output" -ge 1 ]
}

@test "CLAUDE.md documents how to move the budget file" {
  run grep -c 'injection-budget' "$REPO_ROOT/CLAUDE.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -c '本文に理由' "$REPO_ROOT/CLAUDE.md"
  [ "$output" -ge 1 ]
}

@test "the budget convention is not placed under rules/" {
  # rules/*.md は全プロジェクトのセッションに注入される。このリポ固有の規約をそこに
  # 置くと、この change 自身が減らそうとしている固定分を増やすことになる。
  run grep -rn 'injection-budget' "$REPO_ROOT/rules/"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}
