# develop 配下の手順書をつないで出す関数（issue #1683）
#
# 手順書の文言の検査で「その文が develop 配下の手順書のどこかにあること」を確かめるときに使う。
# 文を develop 配下の別のファイルへ移しただけでは検査が落ちないようにするためで、
# 場所の守りは場面ごとの字数の予算（tests/develop-startup-budget.bats・tests/develop-worker-stage-budget.bats）が持つ。
# 「この文が無いこと」を確かめる否定の検査には使わない（対象を広げると意味が変わる）。
#
# 対象（plugins/dev-workflow/ から）:
#   skills/develop/SKILL.md
#   skills/develop/references/ 配下の *.md（roles/ などのサブディレクトリを含む）
#   references/*.md
#   templates/escalation-tripwires.md
#
# 使い方: load で読み込み、`develop_docs | grep -qF '<文>'` の形で使う。

_DEVELOP_DOCS_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

develop_docs() {
  local p="$_DEVELOP_DOCS_PLUGIN_DIR"
  cat "$p/skills/develop/SKILL.md"
  find "$p/skills/develop/references" -type f -name '*.md' | LC_ALL=C sort | while IFS= read -r f; do cat "$f"; done
  cat "$p"/references/*.md
  cat "$p/templates/escalation-tripwires.md"
}
