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
# tests/ 配下は常に対象外。テスト用のヘルパは配布されるランタイムではないため
# （現状 tests/ に *.sh / *.js / *.py は 1 件も無く、この除外は将来の保険）。
loops_unlisted_scripts() {
  local f rel
  find "${PLUGIN_DIR}" -type f \
    \( -name '*.sh' -o -name '*.js' -o -name '*.py' \) ! -name '*.bats' \
    | LC_ALL=C sort \
    | while IFS= read -r f; do
        rel="${f#"${PLUGIN_DIR}/"}"
        case "$rel" in
          tests/*) continue ;;
        esac
        if printf '%s\n' "$LOOPS_SCRIPT_ALLOWLIST" | grep -qxF -- "$rel"; then
          continue
        fi
        printf '%s\n' "$rel"
      done
}
