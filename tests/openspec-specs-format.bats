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

# develop の SKILL.md から references/ へ移した節を、spec が「SKILL.md の節」として名指ししていないこと（#1241）。
# 節名の一覧は移設先（epic.md・epic-child-stop.md・handover.md・fix-check.md・channel.md）の見出し。
# SKILL.md に中身が残る節（ループの終わり等）はこの一覧に入れない。
# grep の終了コードは 0=一致あり（落とす）/ 1=一致ゼロ（通す）/ 2=検索エラー（落とす）と分ける。
@test "no spec names a moved develop section as a SKILL.md section" {
  # C ロケールだと [^。] が 1 バイトずつ数えられ、日本語の行に一致しなくなる。UTF-8 に固定する。
  local re='SKILL\.md[^。]{0,8}[「『](エピックの扱い|エピックの子が主の返事を待って止まるとき|保留で止まるときの引き継ぎ|レビューの周を主に聞かずに続ける|channel の聞き方|channel のリスク許容|channel の主への発言|新しいセッションでの再開|回し方|作り方|完了条件|条件)'
  # 見本の行に正規表現が一致すること（一致しない環境で常に通ってしまうのを防ぐ）
  printf 'SKILL.md の「エピックの扱い」\n' | LC_ALL=C.UTF-8 grep -qE "$re"
  run env LC_ALL=C.UTF-8 grep -rnE "$re" "$SPECS_DIR"
  if [ "$status" -eq 1 ]; then return 0; fi
  echo "grep status=$status (0=stale references found, 2=search error)" >&2
  echo "$output" | cut -c1-200 >&2
  false
}
