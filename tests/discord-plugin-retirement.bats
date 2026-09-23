#!/usr/bin/env bats
#
# Discord 改造版プラグインの撤去（issue #314）の構造検証
#
# spec: discord-plugin-retirement
#
# 改造版は flatmate に移り（genetta-inc/flatmate#851）、flatmate 自身が配っている。
# harness 側にディレクトリ・marketplace 登録・CI の bun 導入・capability spec が
# 戻ってこないことと、移設の記録が README にあることを git / jq / grep だけで検査する。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。
#
# 参照掃除の許容場所（spec の (a)〜(e)）。文字列一致ではなくパス列挙にする:
#   (a) 過去の記録 openspec/changes/archive/ と _longruns/
#   (b) 作業中の change openspec/changes/remove-discord-plugin/
#   (c) 移設の記録と切り替え手順を書くルート README.md
#   (d) この bats 自身
#   (e) archive で生成される撤去 capability の正本 openspec/specs/discord-plugin-retirement/

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
  CI_YML="${REPO_ROOT}/.github/workflows/ci.yml"
  ROOT_README="${REPO_ROOT}/README.md"
  ALLOW_RE='^(openspec/changes/archive/|_longruns/|openspec/changes/remove-discord-plugin/|README\.md:|tests/discord-plugin-retirement\.bats:|openspec/specs/discord-plugin-retirement/)'
}

# --- Requirement: ディレクトリは git 追跡の削除として取り除く ---

@test "plugins/discord is neither tracked nor present" {
  n="$(git -C "$REPO_ROOT" ls-files plugins/discord | wc -l | tr -d ' ')"
  [ "$n" = "0" ]
  [ ! -e "${REPO_ROOT}/plugins/discord" ]
}

# --- Requirement: marketplace.json から discord のエントリを外す ---

@test "marketplace plugins[] has no discord entry" {
  jq -e '[.plugins[].name] | index("discord") == null' "$MARKETPLACE"
}

@test "no marketplace bundle lists discord" {
  jq -e '[.bundles[]?.plugins[]?] | index("discord") == null' "$MARKETPLACE"
}

# --- Requirement: CI は Discord のテストのための bun を導入しない ---

@test "ci.yml mentions neither discord nor setup-bun" {
  run grep -n -i -e discord -e setup-bun "$CI_YML"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "ci.yml keeps the third-party action SHA pinning policy of issue 138" {
  grep -q '#138' "$CI_YML"
  grep -q 'コミット SHA で固定する' "$CI_YML"
}

# --- Requirement: 廃止した capability の spec を正本の置き場から消す ---

@test "discord-reaction-delivery spec directory is absent" {
  [ ! -e "${REPO_ROOT}/openspec/specs/discord-reaction-delivery" ]
}

# --- Requirement: Discord 改造版への参照を掃除する ---

@test "no references to the discord fork outside the allow list" {
  run bash -c "cd '${REPO_ROOT}' && git grep -n -e 'plugins/discord' -e 'discord@oratta-claude-harness' -e 'discord-reaction-delivery' | grep -vE '${ALLOW_RE}'"
  [ -z "$output" ] || { echo "$output"; return 1; }
}

# --- Requirement: 移設の記録と切り替え手順をルート README に書く ---

@test "README plugin table has no discord row" {
  run grep -n '^| `discord` |' "$ROOT_README"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "README records the move to flatmate and the switch steps" {
  grep -qF 'genetta-inc/flatmate/issues/851' "$ROOT_README"
  grep -qF 'claude plugin uninstall discord@oratta-claude-harness' "$ROOT_README"
  grep -qF 'discord@flatmate' "$ROOT_README"
  grep -qF 'plugin:discord@flatmate' "$ROOT_README"
}
