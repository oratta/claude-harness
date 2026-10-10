#!/usr/bin/env bats
#
# skill-pack・telegram・experience-to-skill の 3 プラグインの解散（PR #841）の構造検証
#
# spec: skill-pack-telegram-e2s-retirement
#
# 3 プラグインは解散し、harness にディレクトリ・marketplace 登録・bundles 登録・参照が
# 戻ってこないことと、解散の記録が README にあることを git / jq / grep だけで検査する。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。
#
# 参照掃除の許容場所（spec の (a)〜(e)）。文字列一致ではなくパス列挙にする:
#   (a) 過去の記録 openspec/changes/archive/ と _longruns/
#   (b) 作業中の change openspec/changes/retire-skill-pack-telegram-e2s/
#   (c) 解散の記録と切り替え手順を書くルート README.md
#   (d) この bats 自身
#   (e) archive で生成される解散 capability の正本 openspec/specs/skill-pack-telegram-e2s-retirement/

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"
  ROOT_README="${REPO_ROOT}/README.md"
  ALLOW_RE='^(openspec/changes/archive/|_longruns/|openspec/changes/retire-skill-pack-telegram-e2s/|README\.md:|tests/skill-pack-telegram-e2s-retirement\.bats:|openspec/specs/skill-pack-telegram-e2s-retirement/)'
  PLUGINS="skill-pack telegram experience-to-skill"
}

@test "the three plugin directories are neither tracked nor present" {
  for p in $PLUGINS; do
    n="$(git -C "$REPO_ROOT" ls-files "plugins/$p" | wc -l | tr -d ' ')"
    [ "$n" = "0" ] || { echo "tracked: $p"; return 1; }
    [ ! -e "${REPO_ROOT}/plugins/$p" ] || { echo "present: $p"; return 1; }
  done
}

@test "marketplace plugins[] has none of the three plugins" {
  jq -e '[.plugins[].name] | (index("skill-pack") == null) and (index("telegram") == null) and (index("experience-to-skill") == null)' "$MARKETPLACE"
}

@test "no marketplace bundle lists any of the three plugins" {
  jq -e '[.bundles[]?.plugins[]?] | (index("skill-pack") == null) and (index("telegram") == null) and (index("experience-to-skill") == null)' "$MARKETPLACE"
}

@test "experience-to-skill-jsonl-distillation spec directory is absent" {
  [ ! -e "${REPO_ROOT}/openspec/specs/experience-to-skill-jsonl-distillation" ]
}

@test "no references to the three plugins outside the allow list" {
  run bash -c "cd '${REPO_ROOT}' && git grep -n -e 'plugins/skill-pack' -e 'plugins/telegram' -e 'plugins/experience-to-skill' -e 'skill-pack@oratta-claude-harness' -e 'telegram@oratta-claude-harness' -e 'experience-to-skill@oratta-claude-harness' -e 'experience-to-skill-jsonl-distillation' | grep -vE '${ALLOW_RE}'"
  [ -z "$output" ] || { echo "$output"; return 1; }
}

@test "README plugin table has no row for the three plugins" {
  for p in $PLUGINS; do
    # 「解散済みプラグイン」節の表（解散の理由と代替）は対象外。節より前だけを見る
    run bash -c "awk '/^### 解散済みプラグイン/{exit} {print}' '$ROOT_README' | grep -n '^| \`$p\` |'"
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  done
}

@test "README records the retirement, the uninstall steps and the alternatives" {
  for p in $PLUGINS; do
    grep -qF "claude plugin uninstall ${p}@oratta-claude-harness" "$ROOT_README" || { echo "missing uninstall: $p"; return 1; }
  done
  grep -qF 'telegram@claude-plugins-official' "$ROOT_README"
  grep -qF 'skillOverrides' "$ROOT_README"
  grep -qF 'skill-creator' "$ROOT_README"
}
