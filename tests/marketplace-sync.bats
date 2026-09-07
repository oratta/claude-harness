#!/usr/bin/env bats
#
# marketplace.json <-> plugins/ の整合ガード（リポ横断）
#
# spec: marketplace-plugin-sync
#
# 旧 plugins/loops/tests/integration.bats に同居していた S130 / S130b / S131 / S132 / S133 / S139
# を、loops の解散（issue #205）に伴いリポジトリ直下へ移したもの。特定プラグインに属さない
# 検査なので、どのプラグインを消してもここは残る。
#
# Constraints: jq / git / find のみ。他プラグインのテストヘルパに依存しない。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
}

# Resolve the branch point baseline. Empty when origin/main is unavailable.
base_ref() {
  if git -C "$REPO_ROOT" rev-parse --verify -q origin/main >/dev/null 2>&1; then
    git -C "$REPO_ROOT" merge-base HEAD origin/main 2>/dev/null
  fi
}

# --- S130: every marketplace entry version == its plugin.json ---
@test "S130: all marketplace plugins[] versions match their plugin.json" {
  names="$(jq -r '.plugins[].name' "$MARKETPLACE")"
  for n in $names; do
    m="$(jq -r --arg n "$n" '.plugins[] | select(.name==$n) | .version' "$MARKETPLACE")"
    pj="${REPO_ROOT}/plugins/${n}/.claude-plugin/plugin.json"
    [ -f "$pj" ] || { echo "no plugin.json for ${n}"; return 1; }
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
  present="$(find "${REPO_ROOT}/plugins" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
  if [ "$registered" != "$present" ]; then
    echo "marketplace plugins[] and plugins/ differ:"
    diff <(echo "$registered") <(echo "$present") || true
    return 1
  fi
}

# --- S131: plugins changed since merge-base are bumped ---
@test "S131: edited plugins have version bumped above merge-base" {
  base="$(base_ref)"
  [ -n "$base" ] || skip "origin/main unavailable"
  changed="$(git -C "$REPO_ROOT" diff "$base" HEAD --name-only | grep '^plugins/' | sed -E 's#(plugins/[^/]+)/.*#\1#' | sort -u)"
  [ -n "$changed" ] || skip "no plugin changes vs merge-base"
  for d in $changed; do
    n="${d#plugins/}"
    # 削除されたプラグインは bump する version が存在しない（entry ごと消えるので
    # marketplace 側との齟齬は S130 / S130b が検出する）。削除を「bump 忘れ」と誤検出しない。
    [ -f "${REPO_ROOT}/${d}/.claude-plugin/plugin.json" ] || continue
    cur="$(jq -r '.version' "${REPO_ROOT}/${d}/.claude-plugin/plugin.json")"
    old="$(git -C "$REPO_ROOT" show "${base}:${d}/.claude-plugin/plugin.json" 2>/dev/null | jq -r '.version' 2>/dev/null)"
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
    echo "merging pr-b after pr-a conflicted - marketplace.json still has a shared single line (issue #140)"
    return 1
  fi
  jq empty "${scratch}/marketplace.json"
  [ "$(jq -r --arg n "$first" '.plugins[] | select(.name==$n) | .version' "${scratch}/marketplace.json")" = "999.9.9" ]
  [ "$(jq -r --arg n "$last"  '.plugins[] | select(.name==$n) | .version' "${scratch}/marketplace.json")" = "999.9.9" ]
}
