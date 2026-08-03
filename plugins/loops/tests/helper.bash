#!/usr/bin/env bash
#
# Shared bats helper for plugins/loops/tests/*.bats
#
# Conventions:
#   - PLUGIN_DIR  : absolute path to plugins/loops
#   - PLUGIN_ROOT : repository root
#
# Usage:
#   load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
#   setup() { loops_setup_paths; }

loops_setup_paths() {
  PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  export PLUGIN_DIR PLUGIN_ROOT
}

# ── plugins/loops に同梱してよいスクリプトの allowlist（S23 / S124 の正本）──
#
# S23 / S124 が守りたいのは「loops がループを回すための常駐ランナー / ドライバを
# 同梱していないこと」。ユーザーがコピーして使う雛形はその対象外だが、
# templates/ をディレクトリごと除外すると、そこに常駐スクリプトを置かれたときに
# 素通りしてしまう。そこで「今この repo に存在する具体ファイル」だけを列挙し、
# ここに載っていない *.sh / *.js / *.py が現れたらテストが落ちるようにする。
#
# 新しい雛形を追加するときは、このリストに 1 行足して
# 「これは常駐ランナーではなく雛形である」という意図を明示的に宣言すること。
# 無言で増やせないことがこのガードの本体。
#
# 1 行 1 パス。PLUGIN_DIR からの相対パスで書く。
LOOPS_SCRIPT_ALLOWLIST='
templates/select-target.sh
'

# allowlist に載っていないスクリプトを PLUGIN_DIR 配下から列挙する（相対パスで出力）。
# 出力が空であることが S23 / S124 の合格条件。
#
# symlink の扱い（重要）:
#   find の -type f は symlink を拾わない。そのため templates/ に repo 外の常駐
#   スクリプトへの symlink を置くだけで、このガードも S124b の grep も丸ごと
#   素通りする（grep はリンク先を読まないため中身も見えない）。
#   そこで -type l も対象に含め、**allowlist に載っていても symlink なら違反**として扱う。
#   リンク先の検査はしない。「plugins/loops に *.sh / *.js / *.py の symlink が
#   存在すること自体を禁止」が、最も単純で抜け穴の作りようがないため。
#   allowlist はあくまで「実体のファイル」を許すための仕組みで、
#   allowlist 済みパスを symlink に差し替える抜け道を残さない。
#
# tests/ 配下は通常ファイルに限り対象外。テスト用のヘルパは配布されるランタイム
# ではないため（現状 tests/ に *.sh / *.js / *.py は 1 件も無く、この除外は将来の保険）。
# ただし symlink はこの除外より先に判定するので、tests/ 配下でも見逃さない。
loops_unlisted_scripts() {
  local f rel
  find "${PLUGIN_DIR}" \( -type f -o -type l \) \
    \( -name '*.sh' -o -name '*.js' -o -name '*.py' \) ! -name '*.bats' \
    | LC_ALL=C sort \
    | while IFS= read -r f; do
        rel="${f#"${PLUGIN_DIR}/"}"
        # symlink は tests/ 除外にも allowlist にも優先して違反にする。
        if [ -L "$f" ]; then
          printf '%s (symlink)\n' "$rel"
          continue
        fi
        case "$rel" in
          tests/*) continue ;;
        esac
        if printf '%s\n' "$LOOPS_SCRIPT_ALLOWLIST" | grep -qxF -- "$rel"; then
          continue
        fi
        printf '%s\n' "$rel"
      done
}
