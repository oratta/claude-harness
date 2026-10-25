#!/usr/bin/env bats
#
# risk-carryover-check.sh（issue #441、#694・#478・#480・#1238・#1303）— 前の HEAD の許容を新しい HEAD に引き継げるかを、
# 積まれた merge commit の形・衝突解消の中身・根拠ファイルの PR 自身の差分（各 HEAD と base の merge-base からの差分）で判定する。
# 許可リストの条件を満たさない衝突解消は NG ではなく RESOLVED_OUTSIDE_ALLOWLIST= で出し、終了コード 3（#694）。
# merge commit でない commit は NG にせず PR_COMMITS= で数える。根拠ファイルが前後で変わっても、PR 自身の差分が同じなら
# EVIDENCE_MAIN_ONLY= で出して引き継げる側、違えば EVIDENCE_PR_CHANGED= で出して終了コード 4（#1238）。
# PR 自身の commit（merge commit でない commit）が根拠ファイルに触れたときは、PR 自身の差分が同じでも
# EVIDENCE_PR_CHANGED= で終了コード 4（比べ方が行の位置を見ないため。#1303）。
# exit 3 のケースは、根拠ファイルが前後で変わらないか main からの変更だけ（EVIDENCE_MAIN_ONLY=）の形で渡す（PR 自身の差分が変わる形は別ケースで exit 4）。
# spec: dev-workflow-pr-review-gate「risk-carryover-check.sh が差分の範囲と根拠ファイルの PR 自身の差分を判定する」

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

# evidence.txt を 10 行にして main で確定させ、pr に取り込んでから PR 側で 5 行目を変える。PREV はその commit
make_multiline_evidence() {
  git checkout -q main
  printf 'L%s\n' 1 2 3 4 5 6 7 8 9 10 > evidence.txt
  git add -A && git commit -q -m "main: multiline evidence"
  git checkout -q pr
  merge_main
  sed -i.bak 's/^L5$/L5 pr/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: evidence line 5"
  PREV="$(git rev-parse HEAD)"
}

# main で evidence.txt の 1 行を書き換える。引数: 元の行 新しい行
main_edit_evidence() {
  git checkout -q main
  sed -i.bak "s/^$1\$/$2/" evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "main: evidence $1"
  git checkout -q pr
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
  printf '%s\n' "$output" | grep -qx 'PR_COMMITS=0'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_DIFF_LINES=0'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
  ! printf '%s\n' "$output" | grep -Eq '^EVIDENCE_(MAIN_ONLY|PR_CHANGED)=' || return 1
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

@test "#1238: evidence file the PR never touched, changed by main -> exit 0, EVIDENCE_MAIN_ONLY" {
  main_commit evidence.txt 'evidence v2'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_PR_CHANGED=' || return 1
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "#1238: non-merge commit not touching evidence on top of prev HEAD -> exit 0, PR_COMMITS=1" {
  printf 'fix\n' > fix.txt
  git add -A && git commit -q -m "W fix"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
  printf '%s\n' "$output" | grep -qx 'PR_COMMITS=1'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
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

@test "#1238: binary evidence file changed -> exit 1 with NG naming the file" {
  printf '\000\001bin v1' > bin.dat
  git add -A && git commit -q -m "pr: bin"
  PREV="$(git rev-parse HEAD)"
  printf '\000\002bin v2' > bin.dat
  git add -A && git commit -q -m "pr: bin v2"
  run "$SCRIPT" --base main "$PREV" HEAD bin.dat
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: .*bin.dat'
}

@test "#1238: evidence file that is binary at the merge-base, replaced by text in the PR -> exit 1 with NG naming the file" {
  git checkout -q main
  printf '\000\001bin v1' > bin.dat
  git add -A && git commit -q -m "main: bin"
  git checkout -q pr
  merge_main
  printf 'text v1\n' > bin.dat
  git add -A && git commit -q -m "pr: bin as text"
  PREV="$(git rev-parse HEAD)"
  printf 'text v2\n' > bin.dat
  git add -A && git commit -q -m "pr: bin as text v2"
  run "$SCRIPT" --base main "$PREV" HEAD bin.dat
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: binary evidence file at merge-base or HEAD: bin.dat'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_MAIN_ONLY=' || return 1
}

@test "#1238: non-main merge plus PR's own evidence change -> exit 1 (1 wins over 4) with both lines" {
  make_multiline_evidence
  git checkout -q -b side main
  printf 'side\n' > side.txt
  git add -A && git commit -q -m side
  git checkout -q pr
  git merge -q --no-edit side >/dev/null
  sed -i.bak 's/^L5 pr$/L5 pr2/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: evidence line 5 again"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: non-main merge'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
}

@test "#1238: merge-base of new HEAD and base is not unique (criss-cross) -> exit 1 with NG naming merge-base" {
  main_commit evidence.txt 'evidence v2'
  merge_main
  git checkout -q main
  git merge -q --no-edit "$PREV" >/dev/null
  git checkout -q pr
  [ "$(git merge-base --all HEAD main | wc -l | tr -d ' ')" -eq 2 ]
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=no'
  printf '%s\n' "$output" | grep -q '^NG: cannot determine a unique merge-base'
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

@test "#1238: PR changed one evidence line, main changed a far line -> exit 0, EVIDENCE_MAIN_ONLY" {
  make_multiline_evidence
  main_edit_evidence L10 'L10 main'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_DIFF_LINES=0'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "#1238: main changed a line two lines away from the PR's line (inside the 3-line context) -> exit 0" {
  make_multiline_evidence
  main_edit_evidence L7 'L7 main'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
}

@test "#1238: main inserted a line above the PR's line (hunk header shifts) -> exit 0, EVIDENCE_MAIN_ONLY" {
  make_multiline_evidence
  git checkout -q main
  { printf 'L0\n'; cat evidence.txt; } > evidence.txt.new && mv evidence.txt.new evidence.txt
  git add -A && git commit -q -m "main: evidence L0"
  git checkout -q pr
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_PR_CHANGED=' || return 1
}

@test "#1238: two evidence files, one main-only and one PR-changed -> exit 4, both lines, DIFF_LINES counts only the PR-changed file" {
  make_multiline_evidence
  main_edit_evidence L10 'L10 main'
  merge_main
  printf 'other pr\n' > other.txt
  git add -A && git commit -q -m "pr: other"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt other.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=other.txt'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_DIFF_LINES=2'
}

@test "#1238: PR's own commit changed only the mode of the evidence file -> exit 4" {
  make_multiline_evidence
  chmod +x evidence.txt
  git add -A && git commit -q -m "pr: chmod evidence"
  [ -n "$(git diff --summary "$PREV" HEAD -- evidence.txt)" ]
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
}

@test "#1238: PR's own commit rewrote the PR's evidence line -> exit 4, if-judged, EVIDENCE_PR_CHANGED, EVIDENCE_DIFF_LINES=2" {
  make_multiline_evidence
  sed -i.bak 's/^L5 pr$/L5 pr2/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: evidence line 5 again"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-judged'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_DIFF_LINES=2'
  printf '%s\n' "$output" | grep -qx 'PR_COMMITS=1'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "#1238: PR's own commits changed the evidence and changed it back -> exit 0" {
  make_multiline_evidence
  sed -i.bak 's/^L5 pr$/L5 pr2/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: change"
  sed -i.bak 's/^L5 pr2$/L5 pr/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: change back"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'PR_COMMITS=2'
}

# 後ろへ動かす向きに限る（PR の変更は -L5 / +L5 pr の順なので、後ろへ動かしたときだけ -U0 の並びが前後で一致する）
@test "#1303: PR's own commit moved the PR's evidence line further down unchanged -> exit 4, no EVIDENCE_MAIN_ONLY" {
  make_multiline_evidence
  printf 'L%s\n' 1 2 3 4 6 7 '5 pr' 8 9 10 > evidence.txt
  git add -A && git commit -q -m "pr: move evidence line 5 below L7"
  [ "$(git diff -U0 main HEAD -- evidence.txt | grep '^[-+][^-+]')" = "$(git diff -U0 main "$PREV" -- evidence.txt | grep '^[-+][^-+]')" ]
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-judged'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_MAIN_ONLY=' || return 1
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "#1303: PR's own commits changed the evidence and changed it back, and main changed a far line -> exit 4" {
  make_multiline_evidence
  sed -i.bak 's/^L5 pr$/L5 pr2/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: change"
  sed -i.bak 's/^L5 pr2$/L5 pr/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: change back"
  main_edit_evidence L10 'L10 main'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_MAIN_ONLY=' || return 1
}

@test "#1303: PR's own commit not touching evidence plus main changing a far evidence line -> exit 0, EVIDENCE_MAIN_ONLY" {
  make_multiline_evidence
  printf 'other pr\n' > other.txt
  git add -A && git commit -q -m "pr: other"
  main_edit_evidence L10 'L10 main'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=yes'
  printf '%s\n' "$output" | grep -qx 'PR_COMMITS=1'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_PR_CHANGED=' || return 1
}

# 非 ASCII のパス（core.quotePath が既定の true だと `git diff --name-only` が "\346..." の形で出す）でも、触れたことを見落とさない。
# スクリプトは --name-only の一覧を照合しないので、quotePath の設定によらず通る
@test "#1303: PR's own commit moved the PR's line in a non-ASCII-named evidence file -> exit 4, no EVIDENCE_MAIN_ONLY" {
  git checkout -q main
  printf 'L%s\n' 1 2 3 4 5 6 7 8 9 10 > 根拠.txt
  git add -A && git commit -q -m "main: multiline evidence (non-ASCII name)"
  git checkout -q pr
  merge_main
  sed -i.bak 's/^L5$/L5 pr/' 根拠.txt && rm -f 根拠.txt.bak
  git add -A && git commit -q -m "pr: evidence line 5"
  PREV="$(git rev-parse HEAD)"
  printf 'L%s\n' 1 2 3 4 6 7 '5 pr' 8 9 10 > 根拠.txt
  git add -A && git commit -q -m "pr: move evidence line 5 below L7"
  run "$SCRIPT" --base main "$PREV" HEAD 根拠.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=根拠.txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_MAIN_ONLY=' || return 1
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

# glob の文字を含む根拠ファイルの名前は字句どおりに扱う（`ev[1].txt` を `ev1.txt` に当てない）
@test "#1303: evidence name with glob characters is matched literally (PR touching ev1.txt is not ev[1].txt) -> exit 0" {
  git checkout -q main
  printf 'g1\ng2\n' > 'ev[1].txt'
  printf 'x\n' > ev1.txt
  git add -A && git commit -q -m "main: glob-named evidence"
  git checkout -q pr
  merge_main
  PREV="$(git rev-parse HEAD)"
  printf 'x pr\n' > ev1.txt
  git add -A && git commit -q -m "pr: ev1"
  main_commit 'ev[1].txt' 'g1 main'
  merge_main
  run "$SCRIPT" --base main "$PREV" HEAD 'ev[1].txt'
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=ev\[1\].txt'
  ! printf '%s\n' "$output" | grep -q '^EVIDENCE_PR_CHANGED=' || return 1
}

@test "#1238: conflict resolution changed the PR's evidence line -> exit 4" {
  make_multiline_evidence
  main_edit_evidence L5 'L5 main'
  git merge -q --no-edit main >/dev/null 2>&1 || true
  printf 'L%s\n' 1 2 3 4 '5 resolved' 6 7 8 9 10 > evidence.txt
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-judged'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
}

@test "#1238: PR's own evidence change plus outside-allowlist resolution -> exit 4 with both lines" {
  make_multiline_evidence
  make_spec_conflict_resolution
  git add -A && git commit -q --no-edit
  sed -i.bak 's/^L5 pr$/L5 pr2/' evidence.txt && rm -f evidence.txt.bak
  git add -A && git commit -q -m "pr: evidence line 5 again"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-judged'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=openspec/specs/x/spec.md'
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

@test "#694 #1238: outside-allowlist resolution plus evidence changed by main -> exit 3 with both lines" {
  git checkout -q main
  printf 'evidence v2\n' > evidence.txt
  git add -A && git commit -q -m "main: evidence"
  git checkout -q pr
  make_spec_conflict_resolution
  git add -A && git commit -q --no-edit
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_MAIN_ONLY=evidence.txt'
  printf '%s\n' "$output" | grep -qx 'RESOLVED_OUTSIDE_ALLOWLIST=openspec/specs/x/spec.md'
  ! printf '%s\n' "$output" | grep -q '^NG:' || return 1
}

@test "#694 #1238: outside-allowlist resolution plus a non-merge commit -> exit 3" {
  make_spec_conflict_resolution
  git add -A && git commit -q --no-edit
  printf 'fix\n' > fix.txt
  git add -A && git commit -q -m "W fix"
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 3 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'CARRYOVER=if-rereviewed'
  printf '%s\n' "$output" | grep -qx 'PR_COMMITS=1'
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
  printf 'evidence pr\n' > evidence.txt
  git add -A && git commit -q -m "pr: evidence"
  cd plugins/foo
  run "$SCRIPT" --base main "$PREV" HEAD evidence.txt
  [ "$status" -eq 4 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qx 'EVIDENCE_PR_CHANGED=evidence.txt'
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
