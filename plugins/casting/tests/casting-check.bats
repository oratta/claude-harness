#!/usr/bin/env bats
#
# casting-catalog / casting-project-files: casting-check.sh の8検出項目
# spec: openspec/changes/casting-plugin/specs/casting-project-files/spec.md
#   Requirement: casting-check.sh の検出項目

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/casting-check.sh"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  FIXTURES="${PLUGIN_DIR}/tests/fixtures"
}

# --- Scenario: 問題のないフィクスチャで exit 0 ---

@test "ok fixture: exits 0 with no findings" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ "$status" -eq 0 ]
}

# --- Scenario: 宣言ファイル delegation.md は check の対象外（issue #207） ---

@test "ok fixture: a delegation.md with a 3-column tools table is not reported as malformed-row" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ -f "${FIXTURES}/ok/.claude/casting/delegation.md" ]
  [ "$status" -eq 0 ]
  [[ "$output" != *"delegation.md"* ]] || return 1
}

# --- Scenario: 8種の検出がそれぞれ報告される（⓪malformed-row はファイル末尾） ---

@test "unknown-vocab fixture: reports the unknown perspective name and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [ "$status" -eq 1 ]
  [[ "$output" == *"謎の観点"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
}

@test "catalog-external-precedent fixture: reports the out-of-catalog precedent and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/catalog-external-precedent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"カタログ外"* ]] || return 1
  [[ "$output" == *"precedents.md"* ]] || return 1
}

@test "repeated-not-issue fixture: reports the perspective repeated as not-an-issue and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/repeated-not-issue"
  [ "$status" -eq 1 ]
  [[ "$output" == *"信用・レピュテーション"* ]] || return 1
  [[ "$output" == *"論点じゃなかった"* ]] || return 1
}

@test "version-mismatch fixture: reports the catalog_version mismatch and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/version-mismatch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
}

# --- 補足: 未知語彙のフィクスチャは version 不一致など他項目を誤検出しない ---

@test "unknown-vocab fixture: does not also report a version mismatch" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [[ "$output" != *"version-mismatch"* ]] || return 1
}

@test "ok fixture: catalog_version matches so no version-mismatch finding" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [[ "$output" != *"version-mismatch"* ]] || return 1
}

# --- 回帰: 1周目レビューの blocking 指摘（シェル堅牢性） ---

@test "missing-version fixture: reports the missing catalog_version instead of dying silently" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/missing-version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version が front matter に無い"* ]] || return 1
}

@test "no-front-matter fixture: treated as missing catalog_version without misparsing the body" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/no-front-matter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version が front matter に無い"* ]] || return 1
  [[ "$output" != *"unknown-vocab"* ]] || return 1
}

@test "tight-pipes fixture: rows without a space after the pipe are still linted" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/tight-pipes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"謎のタイト観点"* ]] || return 1
  [[ "$output" != *"財務・コスト"* ]] || return 1
}

@test "trailing-space fixture: trailing spaces do not cause a false unknown-vocab" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/trailing-space"
  [ "$status" -eq 0 ]
}

@test "multi-perspective fixture: comma-separated perspectives are each validated" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/multi-perspective"
  [ "$status" -eq 0 ]
}

@test "malformed-row fixture: a row with fewer than 5 columns is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/malformed-row"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]] || return 1
  [[ "$output" == *"5列未満"* ]] || return 1
}

# --- 検出5: 相談判例（経路「相談の上自走した」）の事後報告5要素 ---

@test "consultation-missing-element fixture: reports the missing report elements and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/consultation-missing-element"
  [ "$status" -eq 1 ]
  [[ "$output" == *"consultation-missing-element"* ]] || return 1
  # ブロック見出しと、欠けている要素名（各人格の主張・根拠・判例リンク）が列挙される
  [[ "$output" == *"相談を経たが事後報告が欠けた判例"* ]] || return 1
  [[ "$output" == *"各人格の主張"* ]] || return 1
  [[ "$output" == *"判例リンク"* ]] || return 1
}

# ラベルの存在だけを見る実装では、値が空のラベルを5つ並べただけのブロックが通ってしまう
# （実質的な事後報告を欠いた判例が無言で配布される fail-open）。fixture は空値・半角空白のみ・
# 全角スペースのみの3種を1ブロックに混ぜてあり、どれも欠落として数えることを固定する。
# 全角スペースを別建てにするのは、LC_ALL=C の [[:space:]] がこれを空白と見なさないため。
@test "consultation-empty-value fixture: labels present but with empty values are reported and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/consultation-empty-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"consultation-missing-element"* ]] || return 1
  [[ "$output" == *"5要素のラベルはあるが値が空の判例"* ]] || return 1
  # 5要素すべてが欠落として列挙される（半角空白のみの「- 根拠:」と全角スペースのみの「- 裁定:」を含む）
  [[ "$output" == *"論点"* ]] || return 1
  [[ "$output" == *"各人格の主張"* ]] || return 1
  [[ "$output" == *"裁定"* ]] || return 1
  [[ "$output" == *"根拠"* ]] || return 1
  [[ "$output" == *"判例リンク"* ]] || return 1
}

# 空白除去は「値が空か」の判定にだけ効かせる。値の先頭に全角スペースが混ざっていても、
# 実質的な中身があれば有効な値として扱う（過剰検出の回帰よけ）。
@test "consultation block: a value padded with a full-width space but carrying content passes" {
  local dir="${BATS_TEST_TMPDIR}/fullwidth-padded"
  mkdir -p "${dir}/.claude/casting"
  cat > "${dir}/.claude/casting/precedents.md" <<'PRECEDENTS'
---
catalog_version: 1
---

# 判例台帳

### 2026-08-21 全角スペースで字下げされた値

- 観点: 技術設計・品質
- 経路: 相談の上自走した
- 帰結: 論点じゃなかった（意見が一致し合意で確定）
- 還元: なし
- 論点: 　実装方式Aか方式Bか
- 各人格の主張: 　メインセッション「方式A」／見張りのハト「方式Aを支持」
- 裁定: 合意（方式A）
- 根拠: 判断基準の互換性優先の定め
- 判例リンク: 「2026-08-17 API の月額プランを Pro に上げるか」
PRECEDENTS
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]] || return 1
}

@test "ok fixture: a compliant consultation block and a note block without a route line pass" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]] || return 1
}

# --- 回帰: #186（ラベル照合の部分文字列一致と末尾改行なしで検査が外れる） ---

# ラベル照合が `.*- ラベル:` の部分文字列一致だと、別要素の値の中に現れた
# 「- 論点:」がその要素の行の実在に化け、欠落が素通りする（fail-open）。
# 照合は行頭アンカー（インデント許容）でなければならない。
@test "consultation block: a label string inside another element's value does not stand in for the missing line" {
  local dir="${BATS_TEST_TMPDIR}/label-in-value"
  mkdir -p "${dir}/.claude/casting"
  cat > "${dir}/.claude/casting/precedents.md" <<'PRECEDENTS'
---
catalog_version: 1
---

# 判例台帳

### 2026-08-27 別要素の値がラベルを含む判例

- 観点: 技術設計・品質
- 経路: 相談の上自走した
- 帰結: 論点じゃなかった（意見が一致し合意で確定）
- 還元: なし
- 各人格の主張: メイン「本文中で - 論点: に触れた」
- 裁定: 合意
- 根拠: 判断基準の互換性優先の定め
- 判例リンク: 「2026-08-17 API の月額プランを Pro に上げるか」
PRECEDENTS
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"consultation-missing-element"* ]] || return 1
  [[ "$output" == *"（論点）"* ]] || return 1
}

# インデントされた箇条書きのラベル行は行頭アンカー化の後も有効な要素として数える
# （厳密化の巻き添えで正しい判例を落とさない回帰よけ）
@test "consultation block: an indented label line still counts as the element" {
  local dir="${BATS_TEST_TMPDIR}/indented-label"
  mkdir -p "${dir}/.claude/casting"
  cat > "${dir}/.claude/casting/precedents.md" <<'PRECEDENTS'
---
catalog_version: 1
---

# 判例台帳

### 2026-08-27 インデントされた要素を持つ判例

- 観点: 技術設計・品質
- 経路: 相談の上自走した
- 帰結: 論点じゃなかった（意見が一致し合意で確定）
- 還元: なし
  - 論点: 実装方式Aか方式Bか
- 各人格の主張: メイン「方式A」／見張りのハト「方式Aを支持」
- 裁定: 合意（方式A）
- 根拠: 判断基準の互換性優先の定め
- 判例リンク: 「2026-08-17 API の月額プランを Pro に上げるか」
PRECEDENTS
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]] || return 1
}

# 経路の照合も同じ部分文字列一致の穴を持つ: 相談していない注記ブロックの値に
# 「- 経路: 相談の上自走した」が引用されているだけで相談判例扱いになり、
# 5要素の欠落が誤検出される。行頭アンカーで経路行の実在だけを見る。
@test "consultation block: a quoted route string inside a value does not turn a note block into a consultation" {
  local dir="${BATS_TEST_TMPDIR}/route-in-value"
  mkdir -p "${dir}/.claude/casting"
  cat > "${dir}/.claude/casting/precedents.md" <<'PRECEDENTS'
---
catalog_version: 1
---

# 判例台帳

### 2026-08-27 経路文字列を引用しただけの注記

- 観点: 技術設計・品質
- 帰結: 自走した
- 還元: 台帳の書き方メモ「相談したら - 経路: 相談の上自走した と書く」を追記
PRECEDENTS
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]] || return 1
}

# 末尾改行の無いファイルで最終行が「- 判例リンク:」のとき、read ループが最終行を
# 落とすと実在する要素が「欠落」に化ける（誤検出）。
@test "consultation block: a complete block in a file without a trailing newline is not flagged" {
  local dir="${BATS_TEST_TMPDIR}/no-eol-complete"
  mkdir -p "${dir}/.claude/casting"
  printf -- '---\ncatalog_version: 1\n---\n\n# 判例台帳\n\n### 2026-08-27 末尾改行なしの相談判例\n\n- 観点: 技術設計・品質\n- 経路: 相談の上自走した\n- 帰結: 論点じゃなかった（意見が一致し合意で確定）\n- 還元: なし\n- 論点: 実装方式Aか方式Bか\n- 各人格の主張: メイン「方式A」／見張りのハト「方式Aを支持」\n- 裁定: 合意（方式A）\n- 根拠: 判断基準の互換性優先の定め\n- 判例リンク: 「2026-08-17 API の月額プランを Pro に上げるか」' \
    > "${dir}/.claude/casting/precedents.md"
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]] || return 1
}

# 末尾改行の無いファイルで最終行が「- 経路: 相談の上自走した」のとき、最終行が
# 落ちるとブロックが相談判例に見えず、5要素の検査ごと無言でスキップされる。
@test "consultation block: a route line as the last line without a trailing newline still triggers the check" {
  local dir="${BATS_TEST_TMPDIR}/no-eol-route-last"
  mkdir -p "${dir}/.claude/casting"
  printf -- '---\ncatalog_version: 1\n---\n\n# 判例台帳\n\n### 2026-08-27 末尾改行なしで経路が最終行\n\n- 観点: 技術設計・品質\n- 帰結: 自走した\n- 還元: なし\n- 経路: 相談の上自走した' \
    > "${dir}/.claude/casting/precedents.md"
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"consultation-missing-element"* ]] || return 1
  [[ "$output" == *"論点・各人格の主張・裁定・根拠・判例リンク"* ]] || return 1
}

# --- 回帰: macOS の sort/uniq がロケール照合で異なる日本語観点列を同一視する（LC_ALL=C 強制） ---

@test "distinct-not-issue fixture: two different multi-perspective strings are not merged into a repeated-not-issue" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/distinct-not-issue"
  [ "$status" -eq 0 ]
  [[ "$output" != *"repeated-not-issue"* ]] || return 1
}

# --- 回帰: #139（check モードでも同じ経路を検出する） ---

@test "over-column fixture: a row that splits into more than 5 columns is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/over-column"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]] || return 1
  [[ "$output" == *"6列以上"* ]] || return 1
}

@test "unclosed-comment fixture: an unbalanced HTML comment is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unclosed-comment"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-comment"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
}

@test "local-malformed fixture: a broken local.md is reported with its own path" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/local-malformed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]] || return 1
  [[ "$output" == *"local.md"* ]] || return 1
}

@test "ok fixture: a balanced HTML comment is not reported as unclosed" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [[ "$output" != *"unclosed-comment"* ]] || return 1
}

@test "template project.md: the commented-out example is balanced and not reported" {
  REPO="${BATS_TEST_TMPDIR}/template-repo"
  mkdir -p "${REPO}/.claude/casting"
  cp "${PLUGIN_DIR}/templates/project.md" "${REPO}/.claude/casting/project.md"
  run "$SCRIPT" --catalog "$CATALOG" "$REPO"
  [ "$status" -eq 0 ]
}

# --- 回帰: #145 レビュー（開閉の「個数」判定と stripped_copy の行範囲走査のずれ） ---
#
# 個数比較は (A) HTML コメントを1つも持たず本文に `-->` があるだけの正常な配役表を
# 止め、(B) 対応の無い `-->` と本物の閉じ忘れ `<!--` が釣り合うと検出を落とし、
# (C) 1行で閉じたコメントが以降を EOF まで飲み込む事故を報告しない。
# 判定は「開いた `<!--` が閉じられているか」で行い、対応の無い `-->` は無視する。

@test "stray-close-arrow fixture: a lone --> with no HTML comment is not reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/stray-close-arrow"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-comment"* ]] || return 1
}

@test "stray-close-arrow fixture: resolve keeps the human-written row" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/stray-close-arrow"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト |"*"| 主 | project |"* ]] || return 1
}

@test "stray-close-plus-unclosed fixture: an unclosed <!-- is reported even when a stray --> balances the count" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/stray-close-plus-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-comment"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
}

@test "stray-close-plus-unclosed fixture: resolve refuses instead of silently dropping the swallowed row" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/stray-close-plus-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" != *"| project |"* ]] || return 1
}

@test "inline-comment fixture: a comment closed on its own line does not swallow the rows after it" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/inline-comment"
  [ "$status" -eq 0 ]
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/inline-comment"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト |"*"| 主 | project |"* ]] || return 1
}

# --- Scenario: コードフェンス内の <!-- は HTML コメントとして走査しない（#187） ---

@test "code-fence-comment fixture: a literal <!-- inside a code fence is not reported as unclosed" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/code-fence-comment"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-comment"* ]] || return 1
}

@test "code-fence-comment fixture: resolve keeps the human-written row after the fences" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/code-fence-comment"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト |"*"| 主 | project |"* ]] || return 1
}

@test "comment-with-fence-marks fixture: fence marks inside an HTML comment do not open a fence, so the comment still closes" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/comment-with-fence-marks"
  [ "$status" -eq 0 ]
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/comment-with-fence-marks"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト |"*"| 主 | project |"* ]] || return 1
  [[ "$output" != *"記入例（コメント内なので無効）"* ]] || return 1
}

@test "code-fence-unclosed fixture: a fence left open until EOF is reported as unclosed-fence, not unclosed-comment" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/code-fence-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-fence"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
  [[ "$output" != *"unclosed-comment"* ]] || return 1
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/code-fence-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" != *"| project |"* ]] || return 1
}

# --- 回帰: 閉じ忘れフェンスより後ろの上書き行が黙って落ちる経路を止める（#187） ---
#
# フェンス内の行をパースから外す扱いの裏返しで、閉じ忘れたフェンスは以降の行を EOF まで
# 出力から落とす。担い手を『主』に引き戻す上書き行がそこにあると、検出も無いまま
# カタログ既定（エージェント）に化けて人間承認が要る論点が自走扱いに倒れる。

@test "code-fence-unclosed-swallow fixture: an override row swallowed by an unclosed fence is reported instead of silently dropped" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/code-fence-unclosed-swallow"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-fence"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
}

@test "code-fence-unclosed-swallow fixture: resolve refuses instead of silently dropping the swallowed row" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/code-fence-unclosed-swallow"
  [ "$status" -eq 1 ]
  [[ "$output" != *"| project |"* ]] || return 1
}

@test "code-fence-example-row fixture: a sample row inside a code fence does not win over the human-written row" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/code-fence-example-row"
  [ "$status" -eq 0 ]
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/code-fence-example-row"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト | 実際の指定 |"*"| 主 | project |"* ]] || return 1
  [[ "$output" != *"採用されてはならない"* ]] || return 1
}

@test "code-fence-plus-unclosed fixture: a real unclosed <!-- outside the fence is still reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/code-fence-plus-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-comment"* ]] || return 1
  [[ "$output" == *"project.md"* ]] || return 1
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/code-fence-plus-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" != *"| project |"* ]] || return 1
}

# --- #307: 閉じフェンス行の末尾判定が CommonMark（スペース・タブのみ）より広い ---
#
# CommonMark（§4.5 Fenced code blocks）が閉じフェンス行の末尾に許すのはスペースと
# タブだけだが、旧実装の [[:space:]]* は POSIX ロケールでもフォームフィード（\f）・
# 垂直タブ（\v）・キャリッジリターン（\r）を含む。これらを末尾に置いた ``` 行は
# フェンスを閉じてはならない（GitHub の表示を含む CommonMark パーサとの解釈のずれ
# を無くす）。制御文字はエディタ・git 双方で消えやすいので、静的フィクスチャではなく
# printf で都度生成する（no-eol-* と同じ理由）。
#
# 各ケースは、フェンス内に「本来なら偽の閉じ行の直後もまだフェンス内」の1行を挟み、
# その後ろに本物の閉じフェンス（余計な文字なしの ```）を置く。旧実装は偽の閉じ行で
# 一旦フェンスを抜けてしまい、直後の本物の ``` を「新しい開きフェンス」として誤読
# する。結果、その後ろの本文（表の見出し・区切り・上書き行）が EOF まで丸ごと
# 未閉じフェンスに飲み込まれ、unclosed-fence になったうえで人間が書いた上書き行
# （担い手『主』）が resolve から消える（code-fence-unclosed-swallow と同じ失敗
# モード）。修正後は偽の閉じ行でフェンスが閉じず、直後の本物の ``` で正しく閉じる
# ため、検出なし・上書き行が resolve に残る。
_fence_trailing_ctrl_fixture() { # $1=出力先ディレクトリ $2=行末に置く制御文字
  local dir="$1" ctrl="$2"
  mkdir -p "${dir}/.claude/casting"
  printf -- '---\ncatalog_version: 1\n---\n\n# 配役表（閉じフェンス行の末尾に CommonMark が許さない制御文字がある）\n\n```markdown\n<!-- 記入例（この行はフェンス内にあるべき）\n| 財務・コスト | 記入例（採用されてはならない） | 混合 | 予算方針文 | エージェント |\n-->\n```%s\nまだフェンスの中のはずの行（CommonMark は空白とタブしか閉じフェンスの末尾に許さない）\n```\n\n| 観点 | この観点が要る論点の条件 | 判断基準の出どころ | 移譲に必要な文書 | 既定の担い手 |\n|---|---|---|---|---|\n| 財務・コスト | 実際の指定 | 混合（判断力は内蔵・閾値は注入） | 予算方針文（上限額と裁量範囲） | 主 |\n' \
    "$ctrl" > "${dir}/.claude/casting/project.md"
}

@test "closing-fence-trailing-formfeed: a \`\`\` line ending in \\f does not close the fence" {
  local dir="${BATS_TEST_TMPDIR}/closing-fence-formfeed"
  _fence_trailing_ctrl_fixture "$dir" $'\f'
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-fence"* ]] || return 1
  run "$SCRIPT" resolve --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト | 実際の指定 |"*"| 主 | project |"* ]] || return 1
}

@test "closing-fence-trailing-vtab: a \`\`\` line ending in \\v does not close the fence" {
  local dir="${BATS_TEST_TMPDIR}/closing-fence-vtab"
  _fence_trailing_ctrl_fixture "$dir" $'\v'
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-fence"* ]] || return 1
  run "$SCRIPT" resolve --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト | 実際の指定 |"*"| 主 | project |"* ]] || return 1
}

@test "closing-fence-trailing-cr: a \`\`\` line ending in \\r does not close the fence" {
  local dir="${BATS_TEST_TMPDIR}/closing-fence-cr"
  _fence_trailing_ctrl_fixture "$dir" $'\r'
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-fence"* ]] || return 1
  run "$SCRIPT" resolve --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト | 実際の指定 |"*"| 主 | project |"* ]] || return 1
}

# 回帰よけ: CommonMark が実際に許すスペース・タブは、修正後も従来どおり閉じフェンス
# として扱われる（[[:space:]]* を狭めすぎて空白・タブまで拒否する誤修正を防ぐ）。
@test "closing-fence-trailing-space-tab: \`\`\` lines ending in a space or a tab still close the fence" {
  local dir="${BATS_TEST_TMPDIR}/closing-fence-space-tab"
  mkdir -p "${dir}/.claude/casting"
  printf -- '---\ncatalog_version: 1\n---\n\n# 配役表\n\n```markdown\n記入例\n``` \n\n~~~\n記入例2\n~~~\t\n\n| 観点 | この観点が要る論点の条件 | 判断基準の出どころ | 移譲に必要な文書 | 既定の担い手 |\n|---|---|---|---|---|\n| 財務・コスト | 実際の指定 | 混合（判断力は内蔵・閾値は注入） | 予算方針文（上限額と裁量範囲） | 主 |\n' \
    > "${dir}/.claude/casting/project.md"
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-fence"* ]] || return 1
  run "$SCRIPT" resolve --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト | 実際の指定 |"*"| 主 | project |"* ]] || return 1
}
