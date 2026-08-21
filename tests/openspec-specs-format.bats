#!/usr/bin/env bats
# openspec-specs-format.bats — openspec/specs/*/spec.md が「現行仕様の正本」の形を保っているかの退行ガード
#
# openspec には形の違う 2 種類の spec.md がある:
#   - openspec/specs/<capability>/spec.md      現行仕様の正本。`## Purpose` と `## Requirements` を持つ
#   - openspec/changes/<id>/specs/.../spec.md  差分表現。`## ADDED Requirements` 等の delta 見出しを持つ
# archive 時に後者を前者へ変換する工程が抜けると、delta 形式のファイルが正本の置き場に残り、
# openspec のツールからは「要件ゼロの capability」に見える（実際に 22 件が取りこぼされていた: issue #156）。
# ここではその取りこぼしを 3 条件で機械検出する。
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SPECS_DIR="$REPO_ROOT/openspec/specs"
}

@test "no spec.md under openspec/specs uses change delta headings" {
  offenders=""
  for f in "$SPECS_DIR"/*/spec.md; do
    if grep -qE '^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements' "$f"; then
      offenders="$offenders $f"
    fi
  done
  [ -z "$offenders" ] || {
    echo "delta headings found in:$offenders" >&2
    echo "hint: convert to '## Requirements' and add a '## Purpose' section" >&2
    false
  }
}

@test "every spec.md has both Purpose and Requirements sections" {
  offenders=""
  for f in "$SPECS_DIR"/*/spec.md; do
    grep -qE '^## Purpose' "$f" || { offenders="$offenders $f(no-Purpose)"; continue; }
    grep -qE '^## Requirements' "$f" || offenders="$offenders $f(no-Requirements)"
  done
  [ -z "$offenders" ] || {
    echo "missing sections in:$offenders" >&2
    false
  }
}

@test "every spec.md starts with a canonical title line and none claims to be a Delta" {
  offenders=""
  for f in "$SPECS_DIR"/*/spec.md; do
    first="$(head -1 "$f")"
    case "$first" in
      "# "*Specification*) ;;
      *) offenders="$offenders $f(bad-title)"; continue ;;
    esac
    case "$first" in
      *"(Delta)"*) offenders="$offenders $f(delta-title)" ;;
    esac
  done
  [ -z "$offenders" ] || {
    echo "bad title lines in:$offenders" >&2
    echo "hint: the first line must be '# <capability> Specification' without '(Delta)'" >&2
    false
  }
}
