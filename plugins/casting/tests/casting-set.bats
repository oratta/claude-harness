#!/usr/bin/env bats
#
# casting-catalog: casting-set.sh によるカタログ書き込み
# spec: openspec/changes/casting-row-level-inheritance/specs/casting-catalog/spec.md
#   Requirement: casting-set.sh によるカタログ書き込み
# spec: openspec/changes/casting-row-level-inheritance/specs/casting-project-files/spec.md
#   Requirement: 導入 repo 台帳
#
# 実カタログ・実 home を汚さないよう、一時ディレクトリにカタログをコピーして --catalog で渡し、
# CASTING_REGISTRY を一時ファイルに向けて検証する。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/casting-set.sh"
  TMP="$BATS_TEST_TMPDIR"

  CATALOG="${TMP}/catalog.md"
  cp "${PLUGIN_DIR}/catalog/catalog.md" "$CATALOG"

  REGISTRY="${TMP}/registry.txt"
  : > "$REGISTRY"
  export CASTING_REGISTRY="$REGISTRY"
}

# --- Scenario: owner が行単位で書き換え変更記録を残す ---

@test "owner rewrites only the owner column and appends a changelog entry" {
  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "エージェント（予算方針文の範囲内）" --why "uranai の予算方針文を整備したため"
  [ "$status" -eq 0 ]

  row="$(grep -F '| 財務・コスト |' "$CATALOG")"
  [[ "$row" == *"エージェント（予算方針文の範囲内）"* ]]
  [[ "$row" != *"方針文あり: エージェント"* ]]
  [[ "$row" == *"支出・API 消費・収益に影響するか"* ]]

  # 他の行は変わっていない
  grep -qF '| 法的・規制 | 契約・規制・知財・プラットフォーム規約に触れるか' "$CATALOG"

  # 変更記録節に日付・観点名・新旧の値・理由が追記される
  today="$(date +%F)"
  grep -qF -- "| ${today} | 観点「財務・コスト」の既定の担い手を" "$CATALOG"
  grep -qF -- "| uranai の予算方針文を整備したため |" "$CATALOG"
}

# --- Scenario: 存在しない観点名はエラー ---

@test "owner errors on an unknown perspective name" {
  run "$SCRIPT" --catalog "$CATALOG" owner "存在しない観点" "主" --why "test"
  [ "$status" -ne 0 ]
  [[ "$output" == *"観点が見つかりません"* ]]
}

# --- Scenario: --why 欠落はエラー ---

@test "owner errors when --why is missing" {
  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "主"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--why"* ]]
}

# --- Scenario: version が増えていない差し替えは拒否される ---

@test "replace-catalog rejects a file whose version did not increase" {
  before="$(cat "$CATALOG")"
  newfile="${TMP}/same-version.md"
  cp "$CATALOG" "$newfile"

  run "$SCRIPT" --catalog "$CATALOG" replace-catalog "$newfile" --why "no-op"
  [ "$status" -ne 0 ]
  [[ "$output" == *"version"* ]]
  [ "$(cat "$CATALOG")" = "$before" ]
}

@test "replace-catalog accepts a higher version and appends a changelog entry" {
  newfile="${TMP}/v2.md"
  sed 's/^version: 1$/version: 2/' "$CATALOG" > "$newfile"

  run "$SCRIPT" --catalog "$CATALOG" replace-catalog "$newfile" --why "v2 rollout"
  [ "$status" -eq 0 ]
  head -3 "$CATALOG" | grep -qx 'version: 2'
  grep -qF -- "| v2 rollout |" "$CATALOG"
}

# --- Scenario: 継承中と上書き中が区別して表示される ---

@test "registry impact listing distinguishes overridden repos from inherited ones" {
  repo_override="${TMP}/repo-override"
  repo_inherit="${TMP}/repo-inherit"
  mkdir -p "${repo_override}/.claude/casting" "${repo_inherit}/.claude/casting"
  cat > "${repo_override}/.claude/casting/project.md" <<'EOF'
---
catalog_version: 1
---

| 観点 | この観点が要る論点の条件 | 判断基準の出どころ | 移譲に必要な文書 | 既定の担い手 |
|---|---|---|---|---|
| 財務・コスト | 支出に影響するか | 混合 | 予算方針文 | 主 |
EOF
  printf '%s\n%s\n' "$repo_override" "$repo_inherit" > "$REGISTRY"

  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "エージェント" --why "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${repo_override}: 上書き中（影響なし）"* ]]
  [[ "$output" == *"${repo_inherit}: 継承中（影響あり）"* ]]
}

# --- Scenario: 存在しないパスが台帳にあっても走査が失敗しない ---

@test "registry scan skips a missing path with a warning and still reports the others" {
  repo_ok="${TMP}/repo-ok"
  mkdir -p "${repo_ok}/.claude/casting"
  printf '%s\n%s\n' "${TMP}/does-not-exist" "$repo_ok" > "$REGISTRY"

  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "エージェント" --why "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"警告"* ]]
  [[ "$output" == *"does-not-exist"* ]]
  [[ "$output" == *"${repo_ok}: 継承中（影響あり）"* ]]
}

# --- 回帰: 2周目レビューの blocking 指摘 ---

@test "owner rejects a new owner value containing a pipe" {
  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "agent|主" --why "test"
  [ "$status" -ne 0 ]
  [[ "$output" == *"| は使えません"* ]]
  grep -qF '方針文あり: エージェント' "$CATALOG"
}

@test "owner rejects a --why containing a pipe" {
  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "主" --why "a|b"
  [ "$status" -ne 0 ]
  [[ "$output" == *"| は使えません"* ]]
}

@test "replace-catalog rejects a structurally empty file even with a higher version" {
  newfile="${TMP}/empty-v3.md"
  printf -- '---\nversion: 3\n---\n\nこれはカタログではない\n' > "$newfile"
  run "$SCRIPT" --catalog "$CATALOG" replace-catalog "$newfile" --why "test"
  [ "$status" -ne 0 ]
  [[ "$output" == *"必須節がありません"* ]]
  head -3 "$CATALOG" | grep -qx 'version: 1'
}

@test "replace-catalog prints the registry impact listing" {
  repo="${TMP}/repo-r"
  mkdir -p "${repo}/.claude/casting"
  printf -- '---\ncatalog_version: 1\n---\n' > "${repo}/.claude/casting/project.md"
  printf '%s\n' "$repo" > "$REGISTRY"
  newfile="${TMP}/v2.md"
  sed 's/^version: 1$/version: 2/' "$CATALOG" > "$newfile"
  run "$SCRIPT" --catalog "$CATALOG" replace-catalog "$newfile" --why "v2 rollout"
  [ "$status" -eq 0 ]
  [[ "$output" == *"影響一覧"* ]]
  [[ "$output" == *"${repo}: 全観点継承中（影響あり）"* ]]
}

@test "registry without a trailing newline: the last repo is still scanned" {
  repo="${TMP}/repo-nl"
  mkdir -p "${repo}/.claude/casting"
  printf '%s' "$repo" > "$REGISTRY"
  run "$SCRIPT" --catalog "$CATALOG" owner "財務・コスト" "主" --why "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${repo}: 継承中（影響あり）"* ]]
}
