#!/usr/bin/env bats
#
# marketplace.json <-> plugins/ の整合ガード（リポ横断）
#
# spec: marketplace-plugin-sync
#
# 旧 plugins/loops/tests/integration.bats に同居していた S130 / S130b / S131 / S132 / S133 / S139
# を、loops の解散（issue #205）に伴いリポジトリ直下へ移したもの。S130 / S131 は issue #447 で
# 「version を持たない」検査に置き換えた。特定プラグインに属さない
# 検査なので、どのプラグインを消してもここは残る。
#
# Constraints: jq / git / find のみ。他プラグインのテストヘルパに依存しない。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
}

# --- S130: no plugin.json carries a version field (issue #447) ---
# version を書くとその値が版として固定され、上げない限り利用者に更新が届かない。書かなければ
# Claude Code が marketplace clone の HEAD の commit SHA を版にする。版を上げていた古い PR が
# 後からマージされて version が戻る経路を、origin/main を要さず常に走る検査で落とす。
# 見るのは manifest のトップレベルの version キーの有無だけ（値は問わない）。SKILL.md の
# frontmatter や package.json の version は版の決定に使われないので見ない。
@test "S130: no plugin.json has a version field" {
  bad=""
  for pj in "${REPO_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
    if jq -e 'has("version")' "$pj" >/dev/null; then
      n="$(basename "$(dirname "$(dirname "$pj")")")"
      bad="${bad}${n}=$(jq -r '.version' "$pj") "
    fi
  done
  if [ -n "$bad" ]; then
    echo "plugin.json has version (remove it; the commit SHA is the version - issue #447): ${bad}"
    return 1
  fi
}

# --- S130b: every plugins/ directory has a marketplace entry (reverse of S130) ---
# プラグインを削除するとき plugin.json だけ消して他のファイルを残すと「entry の無い
# プラグインディレクトリ」が残る（claude-harness#206 のレビューで判明）。両方向を固定する。
@test "S130b: every plugins/ directory is registered in marketplace.json" {
  registered="$(jq -r '.plugins[].name' "$MARKETPLACE" | sort)"
  present="$(find "${REPO_ROOT}/plugins" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
  if [ "$registered" != "$present" ]; then
    echo "marketplace plugins[] and plugins/ differ:"
    diff <(echo "$registered") <(echo "$present") || true
    return 1
  fi
}

# --- S131: no marketplace plugins[] entry carries a version field (issue #447) ---
# plugins[] の version も plugin.json と同じく版を固定するので、両方を見る。
@test "S131: no marketplace plugins[] entry has a version field" {
  bad="$(jq -r '.plugins[] | select(has("version")) | "\(.name)=\(.version)"' "$MARKETPLACE")"
  if [ -n "$bad" ]; then
    echo "marketplace plugins[] has version (remove it - issue #447):"
    echo "$bad"
    return 1
  fi
}

# --- S132: marketplace top-level version field is absent (issue #140) ---
@test "S132: marketplace.json has no top-level version field" {
  if jq -e 'has("version")' "$MARKETPLACE" >/dev/null; then
    echo "top-level version field reintroduced ($(jq -r '.version' "$MARKETPLACE")) - see issue #140"
    return 1
  fi
}

# --- S133: all JSON files parse ---
@test "S133: marketplace.json and all plugin.json parse" {
  jq empty "$MARKETPLACE"
  for pj in "${REPO_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
    jq empty "$pj"
  done
}

# --- S139: unrelated plugin PRs merge cleanly via marketplace.json (issue #140) ---
@test "S139: two PRs editing different plugin entries merge cleanly" {
  scratch="${BATS_TEST_TMPDIR}/mkt-repo"
  mkdir -p "$scratch"
  jq . "$MARKETPLACE" > "${scratch}/marketplace.json"
  git -C "$scratch" init -q -b main
  git -C "$scratch" config user.email marketplace-tests@example.invalid
  git -C "$scratch" config user.name marketplace-tests
  git -C "$scratch" add marketplace.json
  git -C "$scratch" commit -qm base

  first="$(jq -r '.plugins[0].name' "$MARKETPLACE")"
  last="$(jq -r '.plugins[-1].name' "$MARKETPLACE")"
  [ "$first" != "$last" ]

  edit_entry() { # $1=branch $2=plugin name
    git -C "$scratch" checkout -qb "$1" main
    jq --arg n "$2" '(.plugins[] | select(.name==$n) | .description) = "edited by \($n)"' \
      "${scratch}/marketplace.json" > "${scratch}/marketplace.json.tmp"
    mv "${scratch}/marketplace.json.tmp" "${scratch}/marketplace.json"
    git -C "$scratch" commit -qam "edit $2"
  }
  edit_entry pr-a "$first"
  edit_entry pr-b "$last"

  git -C "$scratch" checkout -q main
  git -C "$scratch" merge -q --no-edit pr-a
  if ! git -C "$scratch" merge --no-edit pr-b; then
    echo "merging pr-b after pr-a conflicted - marketplace.json still has a shared single line (issue #140)"
    return 1
  fi
  jq empty "${scratch}/marketplace.json"
  [ "$(jq -r --arg n "$first" '.plugins[] | select(.name==$n) | .description' "${scratch}/marketplace.json")" = "edited by ${first}" ]
  [ "$(jq -r --arg n "$last"  '.plugins[] | select(.name==$n) | .description' "${scratch}/marketplace.json")" = "edited by ${last}" ]
}
