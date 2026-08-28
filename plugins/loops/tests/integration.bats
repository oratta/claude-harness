#!/usr/bin/env bats
#
# Tests for capabilities:
#   - loops-cost-guardrails            (S115-S119)
#   - loops-integration-verification   (S120-S126)
#   - loops-marketplace-sync           (S127-S133, S139)
#   - loops-readme-positioning         (S134-S138)
# Spec: openspec/changes/loops-integration/specs/*/spec.md
#
# Constraints: grep / jq / find only. No custom verification runtime / wrapper CLI.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  RECIPES="${PLUGIN_DIR}/recipes"
  REFERENCES="${PLUGIN_DIR}/references"
  COST="${REFERENCES}/cost-guardrails.md"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
  README="${PLUGIN_ROOT}/README.md"
  HEADINGS=("ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション")
}

# Extract the body of a level-2 (##) markdown section whose heading contains $2.
section_of() {
  awk -v h="$2" '
    /^## / { if (inx) exit; if (index($0, h)) { inx=1; next } }
    inx { print }
  ' "$1"
}

# Resolve the branch point ("main 時点") baseline. Empty when origin/main is
# unavailable. See design.md D8: origin/main diverged via an unrelated PR, so
# the merge-base is the honest baseline for "changed by this run / bumped".
base_ref() {
  if git -C "$PLUGIN_ROOT" rev-parse --verify -q origin/main >/dev/null 2>&1; then
    git -C "$PLUGIN_ROOT" merge-base HEAD origin/main 2>/dev/null
  fi
}

# ============================================================
# loops-cost-guardrails  (S115-S119)
# ============================================================

# --- S115: 6 items counted in a numbered form ---
@test "S115: cost-guardrails token-management section lists exactly 6 numbered items" {
  [ -f "$COST" ]
  section="$(section_of "$COST" "トークン管理")"
  [ -n "$section" ]
  count="$(echo "$section" | grep -Ec '^[0-9]+\. ')"
  [ "$count" -eq 6 ]
}

# --- S116: three key item phrasings present ---
@test "S116: cost-guardrails names frequency, scripting, and pilot items" {
  section="$(section_of "$COST" "トークン管理")"
  echo "$section" | grep -q "頻度"
  echo "$section" | grep -q "スクリプト化"
  echo "$section" | grep -q "パイロット"
}

# --- S117: quantitative facts 4x / 15x ---
@test "S117: cost-guardrails states the ~4x and ~15x token facts" {
  grep -Eq '約 ?4 ?倍|4倍' "$COST"
  grep -Eq '約 ?15 ?倍|15倍' "$COST"
}

# --- S118: /usage and /workflows review procedure ---
@test "S118: cost-guardrails documents /usage and /workflows review" {
  grep -q '/usage' "$COST"
  grep -q '/workflows' "$COST"
  # includes "when to check"
  grep -Eq 'パイロット|定期見直し|定常運用' "$COST"
}

# --- S119: no hardcoded model id ---
@test "S119: cost-guardrails has no hardcoded claude- model id" {
  run grep -Eq 'claude-[a-z0-9]' "$COST"
  [ "$status" -ne 0 ]
}

# ============================================================
# loops-integration-verification  (S120, S122-S125)
# S120 (this file all-pass) and S121 (full suite) are validated by execution.
# ============================================================

# --- S122: every recipe has all 7 fixed headings ---
@test "S122: all recipes have the 7 fixed headings (no missing)" {
  for f in "${RECIPES}"/*.md; do
    for h in "${HEADINGS[@]}"; do
      if ! grep -Eq "^#+ .*${h}" "$f"; then
        echo "missing heading '${h}' in ${f}"
        return 1
      fi
    done
  done
}

# --- S123: no recipe lacks 停止基準 heading ---
@test "S123: no recipe is missing the stop-criteria heading" {
  run grep -L '停止基準' "${RECIPES}"/*.md
  [ -z "$output" ]
}

# --- S124: no resident loop-runner / driver script in plugins/loops ---
@test "S124: no runner scripts (.sh/.js/.py) under plugins/loops" {
  # PR #76（global-rules-pack）が templates/select-target.sh を追加して以降、
  # このガードは落ちたままだった。禁じたいのは「loops がループを回すための常駐
  # ランナー / ドライバを同梱すること」であって、ユーザーがコピーして使う雛形ではない。
  #
  # ただし templates/ をディレクトリごと除外はしない。除外すると、そこに常駐
  # スクリプトを置かれたときに素通りするため。allowlist（helper.bash の
  # LOOPS_SCRIPT_ALLOWLIST）に載っている具体ファイルだけを許し、載っていない
  # スクリプトが現れたら落とす。新しい雛形を足すときは allowlist に追記して
  # 意図を宣言すること。
  #
  # 常駐プロセス化そのものの実害は下の S124b が引き続き plugins/loops 全域で見張る
  # （この節に禁止パターンそのものを書くと S124b の grep に自分で引っかかるため列挙しない）。
  run loops_unlisted_scripts
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- S124c: symlink による allowlist 迂回を塞げていること（負のテスト）---
#
# find -type f は symlink を拾わないため、対策前は templates/ に repo 外の常駐
# スクリプトへの symlink を置くだけで S23 / S124 / S124b の全てを素通りできた
# （S124b の grep もリンク先は読まないので中身が見えない）。
# 実際に symlink を作って検出されることを確かめる。allowlist に載っているパスを
# symlink に差し替える経路も塞げているかを併せて確認する。
@test "S124c: a symlinked runner under plugins/loops is reported as a violation" {
  local sneaky="${PLUGIN_DIR}/templates/sneaky-runner.sh"
  local target="${BATS_TEST_TMPDIR}/resident-runner.sh"
  printf '#!/bin/sh\n' > "$target"

  # 後片付けは必ず通す（アサーションで落ちても repo に symlink を残さない）。
  ln -s "$target" "$sneaky"
  run loops_unlisted_scripts
  rm -f "$sneaky"

  echo "$output" | grep -q 'templates/sneaky-runner.sh (symlink)'
}

@test "S124c: an allowlisted path replaced by a symlink is still a violation" {
  local allowed="${PLUGIN_DIR}/templates/select-target.sh"
  local backup="${BATS_TEST_TMPDIR}/select-target.sh.orig"
  # -p でモードごと退避する。復元時に実行ビットを落とすと、テストが repo の
  # ファイルモードを黙って書き換えることになる。
  cp -p "$allowed" "$backup"

  rm -f "$allowed"
  ln -s "$backup" "$allowed"
  run loops_unlisted_scripts
  rm -f "$allowed"
  cp -p "$backup" "$allowed"

  echo "$output" | grep -q 'templates/select-target.sh (symlink)'
  # 復元が完全であること（実体に戻り、git 上の差分が出ていない）を確認する。
  [ -f "$allowed" ] && [ ! -L "$allowed" ]
  run git -C "$PLUGIN_ROOT" status --porcelain -- plugins/loops/templates/select-target.sh
  [ -z "$output" ]
}

@test "S124b: no while-true / sleep-loop resident processes in plugins/loops" {
  run bash -c "grep -rEl 'while +true|sleep +[0-9].*done' '${PLUGIN_DIR}' || true"
  [ -z "$output" ]
}

# --- S125: every recipe startup command is a native primitive ---
@test "S125: every recipe startup section uses native primitives only" {
  for f in "${RECIPES}"/*.md; do
    section="$(section_of "$f" "起動コマンド")"
    # at least one native slash-command invocation line
    if ! echo "$section" | grep -Eq '^/(goal|loop|schedule|[a-z][a-z-]*)'; then
      echo "no native slash-command line in 起動コマンド of ${f}"
      return 1
    fi
    # no custom CLI / wrapper script invocation
    if echo "$section" | grep -Eq 'bash .*\.sh|\./[A-Za-z0-9_./-]*\.sh|node .*\.js'; then
      echo "custom script invocation found in 起動コマンド of ${f}"
      return 1
    fi
  done
}

# ============================================================
# loops-marketplace-sync  (S127-S133)
# ============================================================

# --- S127: loops entry exists with correct source ---
@test "S127: marketplace.json has a loops entry with source ./plugins/loops" {
  src="$(jq -r '.plugins[] | select(.name=="loops") | .source' "$MARKETPLACE")"
  [ "$src" = "./plugins/loops" ]
  desc="$(jq -r '.plugins[] | select(.name=="loops") | .description' "$MARKETPLACE")"
  ver="$(jq -r '.plugins[] | select(.name=="loops") | .version' "$MARKETPLACE")"
  [ -n "$desc" ] && [ "$desc" != "null" ]
  [ -n "$ver" ] && [ "$ver" != "null" ]
}

# --- S128: loops marketplace version == plugin.json version ---
@test "S128: loops version matches between marketplace.json and plugin.json" {
  m="$(jq -r '.plugins[] | select(.name=="loops") | .version' "$MARKETPLACE")"
  p="$(jq -r '.version' "${PLUGIN_DIR}/.claude-plugin/plugin.json")"
  [ "$m" = "$p" ]
}

# --- S130 / S133: every marketplace entry version == its plugin.json (parity) ---
@test "S130: all marketplace plugins[] versions match their plugin.json" {
  names="$(jq -r '.plugins[].name' "$MARKETPLACE")"
  for n in $names; do
    m="$(jq -r --arg n "$n" '.plugins[] | select(.name==$n) | .version' "$MARKETPLACE")"
    pj="${PLUGIN_ROOT}/plugins/${n}/.claude-plugin/plugin.json"
    [ -f "$pj" ]
    p="$(jq -r '.version' "$pj")"
    if [ "$m" != "$p" ]; then
      echo "version mismatch for ${n}: marketplace=${m} plugin.json=${p}"
      return 1
    fi
  done
}

# --- S130b: every plugins/ directory has a marketplace entry (reverse of S130) ---
# S130 は marketplace entry → plugin.json の一方向しか見ない。プラグインを削除するとき
# plugin.json だけ消して他のファイルを残すと、S130 も S131 も素通りして「entry の無い
# プラグインディレクトリ」が残る（claude-harness#206 のレビューで判明）。逆方向を固定する。
@test "S130b: every plugins/ directory is registered in marketplace.json" {
  registered="$(jq -r '.plugins[].name' "$MARKETPLACE" | sort)"
  present="$(ls -1 "${PLUGIN_ROOT}/plugins" | sort)"
  if [ "$registered" != "$present" ]; then
    echo "marketplace plugins[] and plugins/ differ:"
    diff <(echo "$registered") <(echo "$present") || true
    return 1
  fi
}

# --- S131: plugins changed by THIS run are bumped above the branch point ---
@test "S131: edited plugins have version bumped above merge-base" {
  base="$(base_ref)"
  [ -n "$base" ] || skip "origin/main unavailable"
  changed="$(git -C "$PLUGIN_ROOT" diff "$base" HEAD --name-only | grep '^plugins/' | sed -E 's#(plugins/[^/]+)/.*#\1#' | sort -u)"
  [ -n "$changed" ] || skip "no plugin changes vs merge-base"
  for d in $changed; do
    n="${d#plugins/}"
    # 削除されたプラグインは bump する version が存在しない（entry ごと消えるので
    # marketplace 側との齟齬は S130 が検出する）。削除を「bump 忘れ」と誤検出しない。
    [ -f "${PLUGIN_ROOT}/${d}/.claude-plugin/plugin.json" ] || continue
    cur="$(jq -r '.version' "${PLUGIN_ROOT}/${d}/.claude-plugin/plugin.json")"
    old="$(git -C "$PLUGIN_ROOT" show "${base}:${d}/.claude-plugin/plugin.json" 2>/dev/null | jq -r '.version' 2>/dev/null)"
    # new plugin (absent at base) needs no bump, only registration
    [ -z "$old" ] || [ "$old" = "null" ] && continue
    if [ "$cur" = "$old" ]; then
      echo "plugin ${n} changed by this run but version not bumped (still ${cur})"
      return 1
    fi
    lowest="$(printf '%s\n%s\n' "$cur" "$old" | sort -V | head -1)"
    [ "$lowest" = "$old" ] || { echo "${n}: ${cur} is not above ${old}"; return 1; }
  done
}

# --- S132: marketplace top-level version field is absent ---
# 旧 S132 は「トップレベル version が merge-base より bump されている」を検査していたが、
# その単一行が全プラグイン PR の共有変更点になり、無関係な PR 同士を必ず衝突させていた
# (issue #140)。トップレベル version はプラグインキャッシュのキーでも更新検知の材料でも
# ない（キャッシュは cache/<marketplace>/<plugin>/<plugin.json の version>/ 単位・更新は
# git pull）ためフィールドごと廃止した。このテストは再導入を防ぐガード。
@test "S132: marketplace.json has no top-level version field" {
  if jq -e 'has("version")' "$MARKETPLACE" >/dev/null; then
    echo "top-level version field reintroduced ($(jq -r '.version' "$MARKETPLACE")) — see issue #140"
    return 1
  fi
}

# --- S133: all JSON files parse ---
@test "S133: marketplace.json and all plugin.json parse" {
  jq empty "$MARKETPLACE"
  for pj in "${PLUGIN_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
    jq empty "$pj"
  done
}

# --- S139: unrelated plugin PRs merge cleanly via marketplace.json (issue #140) ---
# 受け入れ条件「互いに無関係なプラグインを変更する 2 本の PR が、片方のマージによって
# 他方が CONFLICTING にならない」の回帰テスト。実リポの marketplace.json を scratch repo に
# 置き、2 ブランチがそれぞれ別プラグインの entry version だけを bump（トップレベル version が
# 存在する場合は当時の規約どおりそれも bump）し、片方をマージした後にもう片方が
# クリーンにマージできることを検証する。トップレベル version が存在した旧方式では
# 両ブランチが同一行を書き換えるため、この 2 本目のマージが必ず衝突して fail する。
@test "S139: two PRs editing different plugin entries merge cleanly" {
  scratch="${BATS_TEST_TMPDIR}/mkt-repo"
  mkdir -p "$scratch"
  # jq で正規化してから base commit にする（後続の jq 編集の diff を変更行だけに局所化する）
  jq . "$MARKETPLACE" > "${scratch}/marketplace.json"
  git -C "$scratch" init -q -b main
  git -C "$scratch" config user.email loops-tests@example.invalid
  git -C "$scratch" config user.name loops-tests
  git -C "$scratch" add marketplace.json
  git -C "$scratch" commit -qm base

  # 実在の entry から離れた 2 つを選ぶ（先頭と末尾）
  first="$(jq -r '.plugins[0].name' "$MARKETPLACE")"
  last="$(jq -r '.plugins[-1].name' "$MARKETPLACE")"
  [ "$first" != "$last" ]

  bump_entry() { # $1=branch $2=plugin name $3=toplevel version if field exists
    git -C "$scratch" checkout -qb "$1" main
    jq --arg n "$2" --arg tv "$3" \
      '(.plugins[] | select(.name==$n) | .version) = "999.9.9"
       | if has("version") then .version = $tv else . end' \
      "${scratch}/marketplace.json" > "${scratch}/marketplace.json.tmp"
    mv "${scratch}/marketplace.json.tmp" "${scratch}/marketplace.json"
    git -C "$scratch" commit -qam "bump $2"
  }
  bump_entry pr-a "$first" "999.0.1"
  bump_entry pr-b "$last"  "999.0.2"

  git -C "$scratch" checkout -q main
  git -C "$scratch" merge -q --no-edit pr-a
  if ! git -C "$scratch" merge --no-edit pr-b; then
    echo "merging pr-b after pr-a conflicted — marketplace.json still has a shared single line (issue #140)"
    return 1
  fi
  # マージ結果が壊れていないこと（両 entry の bump が残り、JSON として parse できる）
  jq empty "${scratch}/marketplace.json"
  [ "$(jq -r --arg n "$first" '.plugins[] | select(.name==$n) | .version' "${scratch}/marketplace.json")" = "999.9.9" ]
  [ "$(jq -r --arg n "$last"  '.plugins[] | select(.name==$n) | .version' "${scratch}/marketplace.json")" = "999.9.9" ]
}

# ============================================================
# loops-readme-positioning  (S134-S138)
# ============================================================

# --- S134: four loop-type names present ---
@test "S134: README names all 4 loop types" {
  for w in "ターンベース" "ゴールベース" "タイムベース" "プロアクティブ"; do
    grep -q "$w" "$README"
  done
}

# --- S135: official article link present ---
@test "S135: README links the official loops article" {
  grep -q 'https://claude.com/blog/getting-started-with-loops' "$README"
}

# --- S136: install command present ---
@test "S136: README has the loops install command" {
  grep -q '/plugin install loops@oratta-claude-harness' "$README"
}

# --- S137: pointer to plugins/loops/ present ---
@test "S137: README points to plugins/loops/ for details" {
  grep -q 'plugins/loops/' "$README"
}

# --- S138: recipe fixed headings are NOT duplicated into README ---
@test "S138: README has no recipe fixed-heading structure" {
  run grep -Ec '^#+ .*(停止基準|エスカレーション)' "$README"
  [ "$output" = "0" ]
}
