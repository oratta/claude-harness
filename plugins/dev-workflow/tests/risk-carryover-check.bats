#!/usr/bin/env bats
#
# risk-carryover-check.sh（issue #441、#694・#478・#480）— 前の HEAD の許容を新しい HEAD に引き継げるかを、
# 差分が main の取り込みだけか・衝突解消の中身・根拠ファイルの無変更で判定する。
# 許可リストの条件を満たさない衝突解消は NG ではなく RESOLVED_OUTSIDE_ALLOWLIST= で出し、終了コード 3（#694）。
# exit 3 のケースはどれも、変わっていない evidence.txt だけを根拠ファイルに渡す（根拠ファイルの変更は別ケースで exit 1）。
# spec: dev-workflow-pr-review-gate「risk-carryover-check.sh が差分の範囲と根拠ファイルの無変更を判定する」

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/risk-carryover-check.sh"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  git config commit.gpgsign false
  mkdir -p plugins/foo/.claude-plugin
  printf '{\n  "name": "foo",\n  "version": "1.0.0",\n  "description": "d"\n}\n' > plugins/foo/.claude-plugin/plugin.json
  printf '# Changelog\n\n## base\n' > CHANGELOG.md
  printf 'evidence v1\n' > evidence.txt
  printf 'other v1\n' > other.txt
  git add -A && git commit -q -m base
  git checkout -q -b pr
  printf 'pr work\n' > pr.txt
  git add -A && git commit -q -m "pr work"
  PREV="$(git rev-parse HEAD)"
}

# main に 1 commit 積む。引数: ファイル 内容
main_commit() {
  git checkout -q main
  printf '%s\n' "$2" > "$1"
  git add -A && git commit -q -m "main: $1"
  git checkout -q pr
}

# pr に main をマージ（衝突なし前提）
merge_main() {
  git merge -q --no-edit main >/dev/null
}

# 版の行と CHANGELOG を両側で変えて衝突させる
make_version_changelog_conflict() {
  git checkout -q main
  sed -i.bak 's/"1.0.0"/"1.0.1"/' plugins/foo/.claude-plugin/plugin.json && rm -f plugins/foo/.claude-plugin/plugin.json.bak
  printf '# Changelog\n\n## main entry\n\n## base\n' > CHANGELOG.md
  git add -A && git commit -q -m "main: bump"
  git checkout -q pr
  sed -i.bak 's/"1.0.0"/"1.1.0"/' plugins/foo/.claude-plugin/plugin.json && rm -f plugins/foo/.claude-plugin/plugin.json.bak
  printf '# Changelog\n\n## pr entry\n\n## base\n' > CHANGELOG.md
  git add -A && git commit -q -m "pr: bump"
  PREV="$(git rev-parse HEAD)"
  git merge -q --no-edit main >/dev/null 2>&1 || true
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "main merged without conflict -> exit 0, CARRYOVER=yes, MAIN_MERGES=1, RESOLVED_FILES=none" {
  main_commit other.txt 'other v2'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt pr.txt
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
  printf '%s\n' "$output" | grep -qx 'MAIN_MERGES=1'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_FILES=none'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "--base defaults to origin/main" {
  main_commit other.txt 'other v2'
  merge_main
  git update-ref refs/remotes/origin/main main
  run "$SCRIPT" "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
}

@test "same prev and new HEAD -> exit 0 with MAIN_MERGES=0" {
  run "$SCRIPT" --base main "$PREV" "$PREV" evidence.txt
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'MAIN_MERGES=0'
}

@test "version line and CHANGELOG reorder resolution only -> exit 0, RESOLVED_FILES lists both" {
  make_version_changelog_conflict
  printf '{\n  "name": "foo",\n  "version": "1.1.0",\n  "description": "d"\n}\n' > plugins/foo/.claude-plugin/plugin.json
  printf '# Changelog\n\n## main entry\n\n## pr entry\n\n## base\n' > CHANGELOG.md
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
  printf '%s\n' "$output" | grep -q '^RESOLVED_FILES=.*plugins/foo/.claude-plugin/plugin.json'
  printf '%s\n' "$output" | grep -q '^RESOLVED_FILES=.*CHANGELOG.md'
}

@test "evidence file changed by main -> exit 1 with NG naming the file" {
  main_commit evidence.txt 'evidence v2'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: .*evidence.txt'
}

@test "non-merge commit on top of prev HEAD -> exit 1 with NG naming the commit" {
  printf 'fix\n' > fix.txt
  git add -A && git commit -q -m "W fix"
  sha="$(git rev-parse HEAD)"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q "^NG: .*$sha"
}

@test "merge of a non-main branch -> exit 1" {
  git checkout -q -b side main
  printf 'side\n' > side.txt
  git add -A && git commit -q -m side
  git checkout -q pr
  git merge -q --no-edit side >/dev/null
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^NG:'
}

@test "conflict resolution outside the allow list -> exit 3 with RESOLVED_OUTSIDE_ALLOWLIST naming the file" {
  main_commit other.txt 'other main'
  printf 'other pr\n' > other.txt
  git add -A && git commit -q -m "pr: other"
  PREV="$(git rev-parse HEAD)"
  git merge -q --no-edit main >/dev/null 2>&1 || true
  printf 'other resolved\n' > other.txt
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=other.txt'
}

@test "hand edit to a non-conflicting file inside the merge commit -> exit 3" {
  main_commit other.txt 'other v2'
  git merge -q --no-commit main >/dev/null 2>&1 || true
  printf 'sneaked\n' > pr.txt
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=pr.txt'
}

@test "plugin.json resolution changes a non-version line -> exit 3" {
  make_version_changelog_conflict
  printf '{\n  "name": "foo",\n  "version": "1.1.0",\n  "description": "changed"\n}\n' > plugins/foo/.claude-plugin/plugin.json
  printf '# Changelog\n\n## main entry\n\n## pr entry\n\n## base\n' > CHANGELOG.md
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=plugins/foo/.claude-plugin/plugin.json'
}

@test "CHANGELOG resolution adds a new sentence -> exit 3" {
  make_version_changelog_conflict
  printf '{\n  "name": "foo",\n  "version": "1.1.0",\n  "description": "d"\n}\n' > plugins/foo/.claude-plugin/plugin.json
  printf '# Changelog\n\n## main entry\n\n## pr entry\n\nnew sentence\n\n## base\n' > CHANGELOG.md
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=CHANGELOG.md'
}

@test "other JSON files are not in the allow list -> exit 3" {
  printf '{\n  "version": "1"\n}\n' > package.json
  git add -A && git commit -q -m "pr: package.json"
  git checkout -q main
  printf '{\n  "version": "2"\n}\n' > package.json
  git add -A && git commit -q -m "main: package.json"
  git checkout -q pr
  PREV="$(git rev-parse HEAD)"
  git merge -q --no-edit main >/dev/null 2>&1 || true
  printf '{\n  "version": "1"\n}\n' > package.json
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=package.json'
}

# openspec/specs/x/spec.md を両側で変えて衝突させ、手で解いた merge commit を作る（#694 の再現）
make_spec_conflict_resolution() {
  mkdir -p openspec/specs/x
  printf 'spec v1\n' > openspec/specs/x/spec.md
  git add -A && git commit -q -m "pr: spec"
  git checkout -q main
  mkdir -p openspec/specs/x
  printf 'spec main\n' > openspec/specs/x/spec.md
  git add -A && git commit -q -m "main: spec"
  git checkout -q pr
  PREV="$(git rev-parse HEAD)"
  git merge -q --no-edit main >/dev/null 2>&1 || true
  printf 'spec resolved\n' > openspec/specs/x/spec.md
}

@test "#694: spec file resolution with unchanged evidence -> exit 3, RESOLVED_OUTSIDE_ALLOWLIST line, no NG" {
  make_spec_conflict_resolution
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  printf '%s\n' "$output" | grep -qx 'MAIN_MERGES=1'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_FILES=openspec/specs/x/spec.md'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=openspec/specs/x/spec.md'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "#694: outside-allowlist resolution plus evidence changed by main -> exit 1 with NG naming the evidence" {
  git checkout -q main
  printf 'evidence v2\n' > evidence.txt
  git add -A && git commit -q -m "main: evidence"
  git checkout -q pr
  make_spec_conflict_resolution
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: .*evidence.txt'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=openspec/specs/x/spec.md'
}

@test "#694: outside-allowlist resolution plus a non-merge commit -> exit 1" {
  make_spec_conflict_resolution
  git add -A && git commit -q --no-edit
  printf 'fix\n' > fix.txt
  git add -A && git commit -q -m "W fix"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
}

@test "#480: deleting an outside-allowlist file and adding a similar one in the merge lists the deleted file" {
  seq 1 40 > old-name.txt
  git add -A && git commit -q -m "pr: old-name"
  main_commit other.txt 'other v2'
  PREV="$(git rev-parse HEAD)"
  git merge -q --no-commit main >/dev/null 2>&1 || true
  git rm -q old-name.txt
  { seq 1 40; echo 41; } > new-name.txt
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=old-name.txt'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=new-name.txt'
  printf '%s\n' "$output" | grep -q '^RESOLVED_FILES=.*old-name.txt'
}

@test "prev HEAD is not an ancestor of new HEAD (history rewritten) -> exit 1" {
  git commit -q --amend -m "pr work rewritten"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: .*ancestor'
}

@test "no evidence files -> exit 2" {
  run "$SCRIPT" --base main "$PREV" HEAD
  [ "$status" -eq 2 ]
}

@test "#478: evidence path that exists at neither HEAD -> exit 2" {
  main_commit other.txt 'other v2'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD no-such-file.txt
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF 'no-such-file.txt'
}

@test "#478: running from a subdirectory reads evidence paths relative to the repo root" {
  main_commit evidence.txt 'evidence v2'
  merge_main
  cd plugins/foo
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -q '^NG: .*evidence.txt'
}

@test "missing arguments -> exit 2" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "unresolvable SHA -> exit 2" {
  run "$SCRIPT" --base main 0000000000000000000000000000000000000000 HEAD evidence.txt
  [ "$status" -eq 2 ]
}

@test "runs under /bin/bash (bash 3.2 on macOS)" {
  main_commit other.txt 'other v2'
  merge_main
  run /bin/bash "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ]
}
