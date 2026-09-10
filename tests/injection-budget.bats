#!/usr/bin/env bats
# injection-budget.bats — 常時注入される「固定分」の合計サイズに予算を置くゲート（issue #258）
#
# 全セッション・全サブエージェントの起動直後に必ず載る固定分（rules / CLAUDE.md /
# output-styles / 各種 description）は、誰も見ていない間に増え続ける。実行時に切り捨てる
# 仕組みは作らず（どのルールが落ちたか誰も気づけない）、編集時にこのテストで止めて
# 「削るか、予算を動かすか」を PR の diff として主の前に出す。
#
# 予算値は tests/injection-budget.txt（数字だけの 1 行）。閾値をこのファイルに直書きしない。
# 判定は上下両方向のラチェット: 実測が予算を超えたら fail、予算が実測の 1.1 倍を超えても
# fail。削減 PR に予算の引き下げを強制し、削った分が次の増加の余地として残らないようにする。
#
# 測定単位はバイト（wc -c）。文字数（wc -m）はロケール依存で、CI（ubuntu-latest、LC_ALL 未設定）
# と手元（en_US.UTF-8）で同じ日本語ファイルが違う値になるため使わない。
#
# このゲートの目的は「測定合計だけを減らす抜け道を塞ぐ」ことなので、集計を迂回できる経路を
# 作らないことを最優先にする。
#
# frontmatter の書式検査（check_frontmatter_shape_z）は許可リスト方式（PR #268 / 子 issue #258
# の決める役の裁定）。「既知の悪い書き方を列挙する」形だと、既定の分岐が「通す」になるため
# 未知の構文が必ず素通りする（YAML anchor/alias による迂回が実際にこの形で 2 周レビューを
# すり抜けた）。反転して「このゲートが字面のまま読める 8 条件の形以外はすべて違反」にすると、
# 未知の構文は「どの形にも当たらない行」として自動的に落ちる。今後ここに穴が開くのは、誰かが
# 許可リストを明示的に広げたときだけで、それは diff として見える。
#
# 集計・判定については次の点にそれぞれ退行テストがある:
#   - description は frontmatter 内の**全件**を見る（重複キーは書式検査で拒否するが、
#     集計側の全件加算は二重の守りとして残す）
#   - 一覧の受け渡しは NUL 区切り（空白や改行を含むファイル名が単語分割で漏れない）
#   - カテゴリのルートを plugins/<プラグイン>/<カテゴリ> に固定する（入れ子で二重計上しない）
#   - 予算ファイルは数字だけの 1 行しか受理しない（変更が 1 行の diff として見える）
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

# ── 一覧の受け渡し規約 ────────────────────────────────────────
# ファイルの一覧は必ず NUL 区切りで渡す。改行区切りにして $(...) で展開すると、
# 空白を含むファイル名が単語分割で 2 つに割れ、どちらも実在しないパスになって
# 測定から丸ごと漏れる（測定合計を減らす抜け道になる）。正本の scripts/sync.sh も
# glob と "$f" の引用で同じ安全性を持っている。
# 表示・件数だけが要る場面は lines_of / count_z を通す。

# emit_z <file...> — 引数のパスを NUL 区切りで出力する。
emit_z() {
  local f
  for f in "$@"; do printf '%s\0' "$f"; done
}

# lines_of — NUL 区切りの一覧を改行区切りに直す（表示・grep 用）。
lines_of() { tr '\000' '\n'; }

# count_z — NUL 区切りの一覧の件数（改行を含むパスでも正しく数える）。
count_z() { tr -cd '\000' | wc -c | tr -d '[:space:]'; }

# ── 集計ヘルパ（すべて「ファイルの一覧を渡す」形。テストは実 repo の
#    ファイルを 1 バイトも書き換えず、渡す一覧を差し替えて異常系を作る）──────

# sum_files_z — stdin の NUL 区切り一覧について wc -c の合計（バイト）を返す。
sum_files_z() {
  local total=0 n f
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    n=$(wc -c < "$f")
    total=$((total + n))
  done
  printf '%s\n' "$total"
}

# sum_files <file...> — 引数版（sum_files_z の薄いラッパ）。
sum_files() { emit_z "$@" | sum_files_z; }

# list_synced_md <dir> — <dir>/*.md から basename が README.md のものを除いた一覧（NUL 区切り）。
# 注入対象の正本は scripts/sync.sh の link_dir（sync.sh:76-79 と 108-109 の 2 呼び出し）。
# rules と output-styles はどちらも同じ 1 条件なので、テストは独自の除外リストを持たない。
list_synced_md() {
  local f b
  for f in "$1"/*.md; do
    if [ -f "$f" ]; then
      b=$(basename "$f")
      if [ "$b" != "README.md" ]; then
        printf '%s\0' "$f"
      fi
    fi
  done
}

# frontmatter_descriptions <file> — frontmatter（1 行目の `---` から次の `---` まで）に
# 現れる `description:` 行を**全件**、「行番号<TAB>値」で出力する。
#
# 1 本目だけを見る（grep -m1）と、`description:` を 2 回書いて 2 本目を折りたたみ記法に
# する経路（YAML の重複キー）が集計とガードの両方をすり抜ける。逆に本文中の
# `description:`（SKILL.md のテンプレート例など、実在する）は注入されないので対象にしない。
frontmatter_descriptions() {
  awk 'NR == 1 { if ($0 != "---") exit; next }
       /^---[ \t]*$/ { exit }
       /^description:/ { line = $0; sub(/^description:[ \t]*/, "", line); print NR "\t" line }' "$1"
}

# sum_descriptions_z — stdin の NUL 区切り一覧について、frontmatter の description の
# **値のみ**のバイト数を足す。末尾改行は数えない（printf '%s' で改行を付けずに wc -c へ流す）。
# 1 行ずつ改行込みで流すとファイル本数ぶん（現状 59 バイト）ずれるため、この定義を動かさない。
sum_descriptions_z() {
  local total=0 f v n
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    while IFS= read -r v; do
      n=$(printf '%s' "$v" | wc -c)
      total=$((total + n))
    done < <(frontmatter_descriptions "$f" | cut -f2-)
  done
  printf '%s\n' "$total"
}

# sum_descriptions <file...> — 引数版（sum_descriptions_z の薄いラッパ）。
sum_descriptions() { emit_z "$@" | sum_descriptions_z; }

# list_dir_files <dir> <find の -name パターン> — <dir> 配下を任意の深さで走査した一覧。
# 1 階層深いディレクトリに置いて集計から逃げる経路を残さないため、glob ではなく find を使う。
list_dir_files() {
  [ -d "$1" ] || return 0
  find "$1" -type f -name "$2" -print0 | LC_ALL=C sort -z
}

# list_plugin_category <plugins ルート> <カテゴリ名> <find の -name パターン>
# カテゴリのルートを plugins/<プラグイン>/<カテゴリ> に固定したうえで、その下は任意の
# 深さで走査する。find の -path '*/skills/*' で書くと * が / にも一致するため、
# plugins/p/commands/x/skills/y/SKILL.md が skills と commands の両方に一致して二重計上される。
list_plugin_category() {
  local root="$1" category="$2" pattern="$3" d
  [ -d "$root" ] || return 0
  for d in "$root"/*/"$category"; do
    [ -d "$d" ] || continue
    find "$d" -type f -name "$pattern" -print0
  done | LC_ALL=C sort -z
}

list_plugin_skills()   { list_plugin_category "$REPO_ROOT/plugins" skills   'SKILL.md'; }
list_plugin_agents()   { list_plugin_category "$REPO_ROOT/plugins" agents   '*.md'; }
list_plugin_commands() { list_plugin_category "$REPO_ROOT/plugins" commands '*.md'; }
list_local_skills()    { list_dir_files "$REPO_ROOT/.claude/skills" 'SKILL.md'; }
list_local_commands()  { list_dir_files "$REPO_ROOT/.claude/commands" '*.md'; }

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
breakdown() {
  printf '%s\t%s\n' "rules/*.md"        "$(list_synced_md "$REPO_ROOT/rules" | sum_files_z)"
  printf '%s\t%s\n' "CLAUDE.md"         "$(emit_z "$REPO_ROOT/CLAUDE.md" | sum_files_z)"
  printf '%s\t%s\n' "output-styles/*.md（メインセッションのみ。サブエージェントには載らない）" \
                                        "$(list_synced_md "$REPO_ROOT/output-styles" | sum_files_z)"
  printf '%s\t%s\n' "plugins SKILL.md description"   "$(list_plugin_skills | sum_descriptions_z)"
  printf '%s\t%s\n' "plugins agent description"      "$(list_plugin_agents | sum_descriptions_z)"
  printf '%s\t%s\n' "plugins command description"    "$(list_plugin_commands | sum_descriptions_z)"
  printf '%s\t%s\n' ".claude/skills SKILL.md description" "$(list_local_skills | sum_descriptions_z)"
  printf '%s\t%s\n' ".claude/commands description"   "$(list_local_commands | sum_descriptions_z)"
}

sum_breakdown() { # 内訳テキストを stdin から受け、バイト数の列を足す
  awk -F'\t' '{ s += $2 } END { print s + 0 }'
}

# read_budget_from <file> — 予算ファイルを検証して値を返す。数字 1 個以上に
# 末尾改行が 0 個か 1 個付いた形だけを受理し、それ以外は何も出力せず rc=1 を返す。
# 空白を落としてから数字として読む（tr -d '[:space:]'）と複数行の予算ファイルが
# 1 つの整数として通ってしまい、「予算の変更が 1 行の diff として見える」前提が崩れる。
read_budget_from() {
  local f="$1" content
  [ -f "$f" ] || return 1
  content=$(cat "$f"; printf 'X')   # 末尾の改行が $(...) に食われないようマーカーを付ける
  content=${content%X}
  case "$content" in
    *$'\n') content=${content%$'\n'} ;;   # 末尾改行 1 個だけを許す
  esac
  case "$content" in
    '' | *[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "$content"
}

read_budget() { read_budget_from "$BUDGET_FILE"; }

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

# ── frontmatter 書式ガード（許可リスト方式）───────────────────
# 「このゲートが字面のまま読める形」（決める役の裁定、PR #268 / 子 issue #258）以外を
# すべて違反にする。ひとつでも当たらなければ違反、という既定「拒否」の検査:
#
#   0. ファイル全体が NUL バイト（0x00）を含まない。awk 実装で NUL の扱いが違う
#      （macOS awk は文字列終端、gawk は保持）ため、awk に渡す前にバイト数一致で落とす
#   1. 1 行目が厳密に `---`。終端も厳密に `---` の行（EOF まで見つからない／`...` 終端は違反）
#   2. frontmatter 内の各行は次の 5 形のいずれかのみ（それ以外は「読めない行」として違反）:
#      トップレベルキー `^key:( 値)?$` ／ 2 スペース字下げの入れ子キー（タブ字下げは違反）／
#      `  - ` か `    - ` で始まる並び項目 ／ 空行 ／ `#` で始まるコメント行
#   3. `&` と `<<` をどこにも含まない（アンカー定義の手段を断てばエイリアスは解決先を持たない。
#      フロー写像の中の位置解析が不要になる）
#   4. トップレベルの description: は 0 個か 1 個（2 個以上は違反。集計側の全件加算は残す）
#   5. description の値の先頭 1 バイトは ASCII 英数字 / `/` / `"` / `'` / 0x80 以上のバイトのみ
#      （`>` `|` `*` 等の YAML 指示子は許可リストに無いので自動的に落ちる）
#   6. description の値が `"` か `'` で始まるなら、行の最終バイトが同じ引用符で、かつ
#      値にバックスラッシュを含まない
#   7. description: の次の行は、トップレベルキー行か終端の `---` のいずれかであること
#
# LC_ALL=C で awk を走らせ、判定はバイト単位（substr/length がマルチバイトを 1 文字として
# 数えない）で書く。ロケール既定のまま日本語を含む値へ文字クラスを当てると
# 「awk: towc: multibyte conversion failure」で落ちる環境があるため。
# 違反したファイル名を出力し、1 件でもあれば 1 を返す。
check_frontmatter_shape_z() { # stdin: NUL 区切りの一覧
  # 使う awk は差し替え可能にする（CI の gawk と手元の one true awk で判定が割れないことを
  # 検査するため）。既定は PATH の awk。
  local f rc=0 awkbin="${INJECTION_BUDGET_AWK:-awk}"
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    # 条件 0: NUL を含むファイルは awk に渡す前に落とす。awk 実装ごとに NUL の扱いが違い
    # （macOS awk は文字列終端、gawk は保持）、awk の中では両実装で同じ答えにできない。
    [ "$(LC_ALL=C tr -d '\000' < "$f" | wc -c)" -eq "$(wc -c < "$f")" ] || { printf '%s\n' "$f"; rc=1; continue; }
    if ! LC_ALL=C "$awkbin" -v sq="'" '
      { lines[NR] = $0 }
      END {
        n = NR
        ok = 1
        if (n < 1 || lines[1] != "---") { ok = 0 }
        else {
          term = 0
          for (i = 2; i <= n; i++) {
            if (lines[i] == "---") { term = i; break }
          }
          if (term == 0) { ok = 0 }
          else {
            desc_count = 0
            for (i = 2; i < term; i++) {
              line = lines[i]
              if (index(line, "&") > 0)  { ok = 0 }
              if (index(line, "<<") > 0) { ok = 0 }

              is_top     = (line ~ /^[A-Za-z_][A-Za-z0-9_-]*:( .+)?$/)
              is_nested  = (line ~ /^  [A-Za-z_][A-Za-z0-9_-]*:( .+)?$/)
              is_list    = (line ~ /^  - /) || (line ~ /^    - /)
              is_blank   = (line == "")
              is_comment = (substr(line, 1, 1) == "#")

              if (!(is_top || is_nested || is_list || is_blank || is_comment)) {
                ok = 0
              }

              if (is_top && line ~ /^description:/) {
                desc_count++
                val = line
                sub(/^description:[ \t]*/, "", val)
                if (val != "") {
                  fb = substr(val, 1, 1)
                  # 許可集合を 1 個のブラケット式で書き、拒否リストは持たない。
                  # 仕様 5 が「この 5 種だけ許可」の肯定形なので実装も肯定形にする
                  # （拒否側を列挙する書き方は NUL・C0・DEL の取りこぼしを繰り返した）。
                  # `\200-\377` は POSIX awk の 8 進エスケープで、LC_ALL=C では
                  # バイト値 0x80-0xFF の範囲指定になる（GNU 拡張ではない）。
                  # スラッシュと単一引用符は正規表現リテラルに入れると扱いが面倒（awk の
                  # プログラム全体がシェルの単一引用符の中にある）なので等値比較で並べる。
                  fb_ok = (fb ~ /^[A-Za-z0-9"\200-\377]$/ || fb == "/" || fb == sq)
                  if (!fb_ok) ok = 0

                  if (fb == "\"" || fb == sq) {
                    lastb = substr(line, length(line), 1)
                    if (lastb != fb) ok = 0
                    if (index(val, "\\") > 0) ok = 0
                  }
                }
                nextline = (i + 1 <= n) ? lines[i + 1] : ""
                next_is_top  = (nextline ~ /^[A-Za-z_][A-Za-z0-9_-]*:( .+)?$/)
                next_is_term = (nextline == "---")
                if (!(next_is_top || next_is_term)) ok = 0
              }
            }
            if (desc_count > 1) ok = 0
          }
        }
        exit (ok ? 0 : 1)
      }
    ' "$f"; then
      printf '%s\n' "$f"
      rc=1
    fi
  done
  return "$rc"
}

check_frontmatter_shape() { emit_z "$@" | check_frontmatter_shape_z; }
check_all_frontmatter_shapes() { list_all_description_files | check_frontmatter_shape_z; }

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
  [ "$(list_synced_md "$TMPD" | lines_of | grep -c 'README.md')" -eq 0 ]
  [ "$(list_synced_md "$TMPD" | sum_files_z)" -eq 10 ]
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
  [ "$(list_dir_files "$TMPD/commands" '*.md' | lines_of | grep -c 'deep.md')" -eq 1 ]
  [ "$(list_dir_files "$TMPD/commands" '*.md' | sum_descriptions_z)" -eq 20 ]
}

@test "a file name containing spaces is still measured" {
  # 改行区切りの一覧を $(...) で展開すると単語分割で丸ごと漏れる（測定を回避できる）。
  printf '1234567890' > "$TMPD/with space.md"
  printf '12345' > "$TMPD/plain.md"
  [ "$(list_synced_md "$TMPD" | count_z)" -eq 2 ]
  [ "$(list_synced_md "$TMPD" | sum_files_z)" -eq 15 ]
  mkdir -p "$TMPD/cat"
  printf -- '---\ndescription: 0123456789\n---\n' > "$TMPD/cat/with space.md"
  [ "$(list_dir_files "$TMPD/cat" '*.md' | count_z)" -eq 1 ]
  [ "$(list_dir_files "$TMPD/cat" '*.md' | sum_descriptions_z)" -eq 10 ]
}

@test "a file name containing a newline is still measured" {
  local nl
  nl=$(printf 'line1\nline2')
  printf '1234567890' > "$TMPD/$nl.md"
  printf '12345' > "$TMPD/plain.md"
  [ "$(list_synced_md "$TMPD" | count_z)" -eq 2 ]
  [ "$(list_synced_md "$TMPD" | sum_files_z)" -eq 15 ]
  mkdir -p "$TMPD/cat"
  printf -- '---\ndescription: 0123456789\n---\n' > "$TMPD/cat/$nl.md"
  [ "$(list_dir_files "$TMPD/cat" '*.md' | count_z)" -eq 1 ]
  [ "$(list_dir_files "$TMPD/cat" '*.md' | sum_descriptions_z)" -eq 10 ]
}

@test "a skills directory nested under commands is not counted twice" {
  # find の -path '*/skills/*' は * が / にも一致するため、commands 配下の入れ子
  # （plugins/p/commands/x/skills/y/SKILL.md）が skills と commands の両方に一致する。
  mkdir -p "$TMPD/plugins/p/commands/x/skills/y"
  printf -- '---\ndescription: 0123456789\n---\n' > "$TMPD/plugins/p/commands/x/skills/y/SKILL.md"
  [ "$(list_plugin_category "$TMPD/plugins" skills 'SKILL.md' | count_z)" -eq 0 ]
  [ "$(list_plugin_category "$TMPD/plugins" commands '*.md' | count_z)" -eq 1 ]
  local skills commands
  skills=$(list_plugin_category "$TMPD/plugins" skills 'SKILL.md' | sum_descriptions_z)
  commands=$(list_plugin_category "$TMPD/plugins" commands '*.md' | sum_descriptions_z)
  [ "$((skills + commands))" -eq 10 ]
}

@test "a plugin category is still walked at any depth below its root" {
  mkdir -p "$TMPD/plugins/p/skills/a/b"
  printf -- '---\ndescription: 0123456789\n---\n' > "$TMPD/plugins/p/skills/a/b/SKILL.md"
  [ "$(list_plugin_category "$TMPD/plugins" skills 'SKILL.md' | count_z)" -eq 1 ]
  [ "$(list_plugin_category "$TMPD/plugins" skills 'SKILL.md' | sum_descriptions_z)" -eq 10 ]
}

@test "every description key in the frontmatter is counted, not just the first" {
  # YAML の重複キー。1 本目だけを見ると 2 本目のバイト数が測定から漏れる。
  printf -- '---\ndescription: 0123456789\ndescription: 0123456789\n---\nbody\n' > "$TMPD/dup.md"
  run sum_descriptions "$TMPD/dup.md"
  [ "$status" -eq 0 ]
  [ "$output" -eq 20 ]
}

@test "a description written in the body is measured neither in the total nor by the guard" {
  # 本文にテンプレートとして `description:` を書いてあるファイルが実在する
  # （plugins/experience-to-skill 配下）。frontmatter の外は注入されないので対象外。
  printf -- '---\ndescription: 0123456789\n---\n\ntemplate:\n\ndescription: >\n  folded example\n' > "$TMPD/body.md"
  run sum_descriptions "$TMPD/body.md"
  [ "$output" -eq 10 ]
  run check_frontmatter_shape "$TMPD/body.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ══ 2. 予算ファイルと判定 ═══════════════════════════════════

@test "budget file holds a single integer" {
  [ -f "$BUDGET_FILE" ]
  run read_budget
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$(wc -l < "$BUDGET_FILE" | tr -d '[:space:]')" -eq 1 ]
}

@test "a budget file that is not a single integer line is rejected" {
  # 空白を落としてから読むと、複数行でも 1 つの整数として通ってしまい、
  # 「予算の変更が 1 行の diff として見える」という前提が崩れる。
  printf '98765\n' > "$TMPD/ok.txt"
  run read_budget_from "$TMPD/ok.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "98765" ]

  printf '98765' > "$TMPD/no-newline.txt"
  run read_budget_from "$TMPD/no-newline.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "98765" ]

  printf '987\n65\n' > "$TMPD/two-lines.txt"
  run read_budget_from "$TMPD/two-lines.txt"
  [ "$status" -ne 0 ]
  [ -z "$output" ]

  printf '98765\n\n' > "$TMPD/trailing-blank.txt"
  run read_budget_from "$TMPD/trailing-blank.txt"
  [ "$status" -ne 0 ]

  printf '98765 \n' > "$TMPD/padded.txt"
  run read_budget_from "$TMPD/padded.txt"
  [ "$status" -ne 0 ]

  printf '# comment\n98765\n' > "$TMPD/commented.txt"
  run read_budget_from "$TMPD/commented.txt"
  [ "$status" -ne 0 ]
}

@test "this suite is picked up by the dynamic test discovery" {
  run git -C "$REPO_ROOT" ls-files -- '*.bats'
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^tests/injection-budget.bats$')" -eq 1 ]
}

@test "current total stays inside the budget (resident ratchet, both directions)" {
  local total budget v shape_violations
  # frontmatter が許可リストの書式から外れているファイルがあれば、合計を計算・報告する
  # 前にここで fail する（読めない frontmatter があるまま「予算内」と言わせない）。
  shape_violations=$(check_all_frontmatter_shapes || true)
  if [ -n "$shape_violations" ]; then
    echo "frontmatter が許可リストの書式から外れている（合計は計算していない）:" >&2
    printf '%s\n' "$shape_violations" >&2
    false
  fi
  total=$(breakdown | sum_breakdown)
  if ! budget=$(read_budget); then
    echo "tests/injection-budget.txt は数字だけの 1 行でなければならない（複数行・空白・コメントは不可）" >&2
    false
  fi
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
  base=$(list_synced_md "$REPO_ROOT/rules" | sum_files_z)
  budget=$(read_budget)
  # 予算を確実に超える大きさの余分なファイルを 1 本足す
  head -c $((budget + 1)) /dev/zero | tr '\000' 'x' > "$TMPD/extra.md"
  total=$({ list_synced_md "$REPO_ROOT/rules"; emit_z "$TMPD/extra.md"; } | sum_files_z)
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

@test "AGENTS.md is not counted; CLAUDE.md appears exactly once" {
  # AGENTS.md は CLAUDE.md の同期複製（tests/agents-md-sync.bats が同一性を強制）で、
  # セッションに注入されるのは片方だけ。両方数えると同じ文が二重計上される。
  local lines
  lines=$(breakdown)
  [ "$(printf '%s\n' "$lines" | grep -c 'AGENTS.md')" -eq 0 ]
  # grep の BRE では '\t' はタブにならず（GNU grep ではリテラルの t として扱われる）、
  # CLAUDE.md の 1 行だけを取り出す判定に使うと Linux で 0 件になる。タブ区切りの列比較は
  # 既存の claude_bytes 抽出と同じく awk -F'\t' に揃える。
  [ "$(printf '%s\n' "$lines" | awk -F'\t' '$1 == "CLAUDE.md"' | wc -l | tr -d '[:space:]')" -eq 1 ]
  # 合計も CLAUDE.md 1 本ぶんしか増えていない（AGENTS.md のバイト数は含まれない）
  local claude_bytes
  claude_bytes=$(printf '%s\n' "$lines" | awk -F'\t' '$1 == "CLAUDE.md" { print $2 }')
  [ "$claude_bytes" -eq "$(sum_files "$REPO_ROOT/CLAUDE.md")" ]
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
  reduced=$(( full - $(list_synced_md "$REPO_ROOT/rules" | sum_files_z) ))
  budget=$(read_budget)
  [ "$(verdict "$budget" "$reduced")" = "under" ]
}

# ══ 4. frontmatter 書式ガード（許可リスト方式）═══════════════

@test "every measured frontmatter in the repo is inside the allowed shape" {
  run check_all_frontmatter_shapes
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the guard covers all measured description files" {
  # 5 カテゴリすべてがガードの対象に入っていること（どれかが 0 件なら glob の書き間違い）。
  [ "$(list_plugin_skills | count_z)" -ge 1 ]
  [ "$(list_plugin_agents | count_z)" -ge 1 ]
  [ "$(list_plugin_commands | count_z)" -ge 1 ]
  [ "$(list_local_skills | count_z)" -ge 1 ]
  [ "$(list_local_commands | count_z)" -ge 1 ]
  # 合計は description を集計する対象と一致する。
  [ "$(list_all_description_files | count_z)" -eq "$(( $(list_plugin_skills | count_z) + $(list_plugin_agents | count_z) + $(list_plugin_commands | count_z) + $(list_local_skills | count_z) + $(list_local_commands | count_z) ))" ]
}

@test "a folded description is detected and its filename is printed" {
  printf -- '---\nname: evil\ndescription: >\n  first line of the folded value\n  second line hidden from the total\n---\nbody\n' > "$TMPD/evil.md"
  run check_frontmatter_shape "$TMPD/evil.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil.md"* ]]
}

@test "a literal block description is detected" {
  printf -- '---\nname: evil2\ndescription: |\n  hidden\n---\nbody\n' > "$TMPD/evil2.md"
  run check_frontmatter_shape "$TMPD/evil2.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil2.md"* ]]
}

@test "a continuation line without a folding marker is detected" {
  printf -- '---\nname: evil3\ndescription: visible part\n  hidden continuation\n---\nbody\n' > "$TMPD/evil3.md"
  run check_frontmatter_shape "$TMPD/evil3.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil3.md"* ]]
}

@test "a folded second description key is detected" {
  # 重複キー＋折りたたみ。1 本目は単一行なので、1 本目だけを見るガードはこれを見逃す。
  printf -- '---\nname: evil4\ndescription: short and innocent\ndescription: >\n  the real payload hidden on the second key\n---\nbody\n' > "$TMPD/evil4.md"
  run check_frontmatter_shape "$TMPD/evil4.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evil4.md"* ]]
}

@test "two single-line top-level description keys are detected even without folding" {
  # 値が両方とも単一行でも、トップレベル description: が 2 本あれば違反（重複キーの経路）。
  printf -- '---\nname: dup\ndescription: first\ndescription: second\n---\nbody\n' > "$TMPD/dup-single.md"
  run check_frontmatter_shape "$TMPD/dup-single.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dup-single.md"* ]]
}

@test "a single line description passes the guard" {
  printf -- '---\nname: fine\ndescription: all on one line\nversion: 1.0.0\n---\nbody\n' > "$TMPD/fine.md"
  run check_frontmatter_shape "$TMPD/fine.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an anchor paired with an alias in the description is detected" {
  # 今回の迂回そのもの。argument-hint に定義したアンカーの値を description のエイリアスで
  # 読ませる。& の存在でも、description の値先頭が * であることでも落ちる。
  printf -- '---\nargument-hint: &payload this description is forty-eight bytes of injected text\ndescription: *payload\n---\n' > "$TMPD/anchor-alias.md"
  run check_frontmatter_shape "$TMPD/anchor-alias.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"anchor-alias.md"* ]]
}

@test "a merge key is detected" {
  printf -- '---\nname: x\n<<: *base\ndescription: hello\n---\n' > "$TMPD/merge-key.md"
  run check_frontmatter_shape "$TMPD/merge-key.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"merge-key.md"* ]]
}

@test "a whole-document flow mapping is detected" {
  # `{name: a, description: <長文>}` は従来 ^description: に当たらず合計 0 バイトで素通りしていた。
  printf -- '---\n{name: a, description: this text used to be counted as zero bytes}\n---\n' > "$TMPD/flow-map.md"
  run check_frontmatter_shape "$TMPD/flow-map.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"flow-map.md"* ]]
}

@test "a quoted key is detected" {
  # `"description": <長文>` も従来 ^description: に当たらず合計 0 バイトで素通りしていた。
  printf -- '---\nname: x\n"description": this text used to be counted as zero bytes\n---\n' > "$TMPD/quoted-key.md"
  run check_frontmatter_shape "$TMPD/quoted-key.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"quoted-key.md"* ]]
}

@test "a first line that is blank before the opening --- is detected" {
  printf -- '\n---\nname: x\ndescription: hi\n---\n' > "$TMPD/blank-first.md"
  run check_frontmatter_shape "$TMPD/blank-first.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"blank-first.md"* ]]
}

@test "a UTF-8 BOM before the opening --- is detected" {
  printf '\xEF\xBB\xBF---\nname: x\ndescription: hi\n---\n' > "$TMPD/bom-first.md"
  run check_frontmatter_shape "$TMPD/bom-first.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bom-first.md"* ]]
}

@test "a %YAML directive line before the opening --- is detected" {
  printf -- '%%YAML 1.2\n---\nname: x\ndescription: hi\n---\n' > "$TMPD/yaml-directive.md"
  run check_frontmatter_shape "$TMPD/yaml-directive.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"yaml-directive.md"* ]]
}

@test "a document-end terminator of ... instead of --- is detected" {
  printf -- '---\nname: x\ndescription: hi\n...\n' > "$TMPD/dots-terminator.md"
  run check_frontmatter_shape "$TMPD/dots-terminator.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dots-terminator.md"* ]]
}

@test "a frontmatter with no closing --- before EOF is detected" {
  printf -- '---\nname: x\ndescription: hi\nno closing marker\n' > "$TMPD/no-terminator.md"
  run check_frontmatter_shape "$TMPD/no-terminator.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no-terminator.md"* ]]
}

@test "a tab-indented nested key is detected" {
  printf -- '---\nmetadata:\n\tversion: 1\ndescription: hi\n---\n' > "$TMPD/tab-indent.md"
  run check_frontmatter_shape "$TMPD/tab-indent.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"tab-indent.md"* ]]
}

@test "an anchor inside a flow sequence is detected" {
  printf -- '---\ntags: [&p this payload rides inside a flow sequence anchor]\ndescription: hi\n---\n' > "$TMPD/flow-anchor.md"
  run check_frontmatter_shape "$TMPD/flow-anchor.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"flow-anchor.md"* ]]
}

@test "a backslash inside a quoted description is detected" {
  # \L のような U+2028 エスケープは書いた字面より解決後の値が大きくなる。
  printf -- '---\ndescription: "backslash \\L\\L\\L payload"\n---\n' > "$TMPD/backslash-quote.md"
  run check_frontmatter_shape "$TMPD/backslash-quote.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"backslash-quote.md"* ]]
}

@test "a description starting with a C0 control byte (0x01) is detected" {
  # 受理条件は「先頭 1 バイトが ASCII 英数字 / スラッシュ / 引用符 / 0x80 以上」。
  # 「印字可能 ASCII でない」で判定すると C0 制御文字が許可集合をすり抜ける。
  printf -- '---\ndescription: \001payload smuggled behind a control byte\n---\n' > "$TMPD/ctl-01.md"
  run check_frontmatter_shape "$TMPD/ctl-01.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ctl-01.md"* ]]
}

@test "a description starting with a C0 control byte (0x07) is detected" {
  printf -- '---\ndescription: \007payload smuggled behind a control byte\n---\n' > "$TMPD/ctl-07.md"
  run check_frontmatter_shape "$TMPD/ctl-07.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ctl-07.md"* ]]
}

@test "a description starting with DEL (0x7F) is detected" {
  printf -- '---\ndescription: \177payload smuggled behind a control byte\n---\n' > "$TMPD/ctl-7f.md"
  run check_frontmatter_shape "$TMPD/ctl-7f.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ctl-7f.md"* ]]
}

# 先頭バイト判定の fixture 一覧。各行は「期待する verdict（1=通る / 0=落ちる） パス」。
# 落ちる/通るの両方を 1 か所に置き、既定 awk での個別検査と awk 実装間の一致検査の
# どちらもこの同じ一覧を回す（片方だけ更新されて食い違うのを防ぐ）。
# 0x09（タブ）は値の取り出しでストリップされるので対象外。
first_byte_fixtures() {
  local d="$TMPD/first-byte" oct
  mkdir -p "$d"
  # 落ちる先頭バイト: NUL・C0 制御文字・DEL・許可集合に無い ASCII 記号
  for oct in 000 001 037 177 076 174 055 052 046 041 045 100 140 133 173; do
    printf -- '---\ndescription: \'"$oct"'x\n---\n' > "$d/bad-$oct.md"
    printf '0 %s\n' "$d/bad-$oct.md"
  done
  # 通る先頭バイト: ASCII 英数字（a / Z / 0）・スラッシュ・0x80・0xFF
  for oct in 141 132 060 057 200 377; do
    printf -- '---\ndescription: \'"$oct"'x\n---\n' > "$d/good-$oct.md"
    printf '1 %s\n' "$d/good-$oct.md"
  done
  # 通る: 同じ引用符で終端する引用値と、0xE6 で始まるマルチバイト値
  printf -- '---\ndescription: "quoted value"\n---\n' > "$d/good-dq.md"
  printf '1 %s\n' "$d/good-dq.md"
  printf -- '---\ndescription: %s\n---\n' "'quoted value'" > "$d/good-sq.md"
  printf '1 %s\n' "$d/good-sq.md"
  printf -- '---\ndescription: 日本語の説明\n---\n' > "$d/good-ja.md"
  printf '1 %s\n' "$d/good-ja.md"
}

# 一覧を配列に読み込む（`while read` の中で run を呼ばないため先に展開する）。
read_first_byte_fixtures() {
  local line
  FIXTURES=()
  while IFS= read -r line; do FIXTURES+=("$line"); done < <(first_byte_fixtures)
}

@test "a file containing a NUL byte is rejected without relying on awk" {
  # awk 実装で NUL の扱いが違う（macOS awk は文字列終端、gawk は保持）ため、
  # NUL だけは awk に渡す前にバイト数一致で落とす。
  printf -- '---\ndescription: \000payload smuggled behind a NUL\n---\n' > "$TMPD/nul.md"
  run check_frontmatter_shape "$TMPD/nul.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"nul.md"* ]]
}

@test "every first byte outside the allowed set is rejected" {
  local line expected path
  read_first_byte_fixtures
  [ "${#FIXTURES[@]}" -eq 24 ]
  for line in "${FIXTURES[@]}"; do
    expected=${line%% *}
    path=${line#* }
    [ "$expected" = "0" ] || continue
    run check_frontmatter_shape "$path"
    if [ "$status" -eq 0 ]; then
      echo "expected a violation but the guard passed: $path" >&2
      false
    fi
    [[ "$output" == *"$(basename "$path")"* ]]
  done
}

@test "every first byte inside the allowed set passes" {
  local line expected path
  read_first_byte_fixtures
  for line in "${FIXTURES[@]}"; do
    expected=${line%% *}
    path=${line#* }
    [ "$expected" = "1" ] || continue
    run check_frontmatter_shape "$path"
    if [ "$status" -ne 0 ]; then
      echo "expected the guard to pass but it flagged: $path ($output)" >&2
      false
    fi
    [ -z "$output" ]
  done
}

@test "every awk implementation on PATH agrees on the first-byte verdicts" {
  # CI（ubuntu-latest）は gawk、手元（macOS）は one true awk。判定が実装で割れると
  # 片方だけで素通りする経路ができるので、PATH にある全実装で verdict の並びを揃える。
  local line path a impl verdicts want=''
  local -a impls=()
  read_first_byte_fixtures
  for line in "${FIXTURES[@]}"; do want+="${line%% *}"; done
  for a in awk gawk mawk; do
    command -v "$a" >/dev/null 2>&1 && impls+=("$a")
  done
  # 既定の awk は必ず PATH にある（skip でこの検査を黙って無効化しない）。
  [ "${#impls[@]}" -ge 1 ]
  printf 'awk implementations under test: %s\n' "${impls[*]}" >&2
  for impl in "${impls[@]}"; do
    verdicts=''
    for line in "${FIXTURES[@]}"; do
      path=${line#* }
      if INJECTION_BUDGET_AWK="$impl" check_frontmatter_shape "$path" >/dev/null 2>&1; then
        verdicts+='1'
      else
        verdicts+='0'
      fi
    done
    if [ "$verdicts" != "$want" ]; then
      echo "awk=$impl verdicts=$verdicts want=$want" >&2
      false
    fi
  done
}

@test "a shape violation blocks the budget total instead of being silently summed" {
  # 常駐テスト「current total stays inside the budget」と同じ経路（先に書式検査、通らなければ
  # 合計を計算しない）を、実 repo を汚さずに検証する。
  printf -- '---\nargument-hint: &payload this description is forty-eight bytes of injected text\ndescription: *payload\n---\n' > "$TMPD/gate-check.md"
  local shape_violations
  shape_violations=$(check_frontmatter_shape "$TMPD/gate-check.md" || true)
  [ -n "$shape_violations" ]
  [[ "$shape_violations" == *"gate-check.md"* ]]
}

@test "a composite file using every allowed line form passes the guard" {
  # 5 形すべて（トップレベルキー／入れ子キー／並び項目／空行／コメント）と、値の途中に
  # * を含む行を 1 ファイルに詰め込んだ合成ファイル。今のリポジトリに実在する形の組み合わせ。
  printf -- '---\nname: x\n\n# comment line\ndescription: plain text\ntags: [a, b]\nmetadata:\n  version: 1\nallowed-tools:\n  - Bash(mkdir *)\n---\nbody\n' > "$TMPD/composite.md"
  run check_frontmatter_shape "$TMPD/composite.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a quoted description without a backslash passes the guard" {
  # .claude/commands/opsx/explore.md:3 に実在する形。
  printf -- '---\nname: x\ndescription: "Enter explore mode - think through ideas"\n---\n' > "$TMPD/quoted-ok.md"
  run check_frontmatter_shape "$TMPD/quoted-ok.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a description starting with a slash passes the guard" {
  # plugins/dev-workflow/commands/work-issue.md に実在する形。
  printf -- '---\nname: x\ndescription: /develop のエイリアス（旧名）\n---\n' > "$TMPD/slash-ok.md"
  run check_frontmatter_shape "$TMPD/slash-ok.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a frontmatter with no description key passes the guard" {
  # description を持たない frontmatter は 0 バイト計上が正直な結果なので違反にしない。
  printf -- '---\nname: x\nversion: 1.0.0\n---\n' > "$TMPD/no-desc.md"
  run check_frontmatter_shape "$TMPD/no-desc.md"
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
