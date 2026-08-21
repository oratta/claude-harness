# template-path-lint.awk — テンプレのコードスパン内にあるプラグイン内相対パス表記を検出する
#
# issue #116: /casting:init の生成先 repo ルートから解決できないパス表記
#   （scripts/… skills/… plugins/casting/…）はテンプレに含めない。
# issue #137: 検出をコードスパンの「先頭」からスパン内の任意位置に広げる。
#
# 使い方:  awk -f template-path-lint.awk <file>...
# 出力:    違反 1 件につき "<file>:<行番号>: プラグイン内相対パス表記: <トークン>"
# 終了コード: 違反 0 件で 0、1 件以上で 1
#
# 判定の考え方:
#   検査対象は「コードスパンの中身」だけ（インラインの `…` とフェンスの中）。スパンの外の
#   平文は対象にしない（スパンを跨いだ偽陽性を避けるため）。スパン内はデリミタでトークンに
#   割り、トークンの先頭が禁止プレフィックスのものだけを違反にする。`~/` `/` で始まる
#   トークン（インストール先を明示した絶対パス表記
#   `~/.claude/plugins/marketplaces/*/plugins/casting/…`）は正しい表記なので除外する。
#
# LC_ALL=C 前提でバイト単位に走る。デリミタ判定に使う文字はすべて ASCII で、UTF-8 の
# 継続バイトが ASCII と衝突しないため、日本語混じりの行でも安全に走査できる。

BEGIN { rc = 0 }

# ファイルが変わったらフェンス状態を捨てる（前のファイルの開きっぱなしを持ち越さない）
FNR == 1 { fence = 0 }

{
  # フェンス行（``` / ~~~ の3個以上）。開いた記号と長さを覚え、同種で同じ長さ以上の
  # 行だけを閉じとして受理する。合わない行はフェンスの中身として検査に回す。
  if (match($0, /^[ \t]*(`{3,}|~{3,})/)) {
    fmark = substr($0, RSTART, RLENGTH)
    gsub(/[ \t]/, "", fmark)
    if (fence == 0) {
      fence = 1; fence_char = substr(fmark, 1, 1); fence_len = length(fmark)
      next
    } else if (substr(fmark, 1, 1) == fence_char && length(fmark) >= fence_len) {
      fence = 0
      next
    }
  }

  if (fence == 1) { scan_span($0, FILENAME, FNR); next }
  scan_line($0, FILENAME, FNR)
}

END { exit rc }

# 行からインラインコードスパンの中身だけを取り出して検査する。
# バッククォートは連続数を数え、開いたのと同じ長さの並びだけを閉じとして扱う
# （``…`` のような多重スパンに対応する）。`\`` はエスケープなのでデリミタにしない。
# 閉じられなかったスパンは平文なので検査しない。
function scan_line(line, file, lineno,   len, i, c, run, in_span, open_run, buf) {
  len = length(line); i = 1; in_span = 0; open_run = 0; buf = ""
  while (i <= len) {
    c = substr(line, i, 1)
    if (c == "\\" && substr(line, i + 1, 1) == "`") {
      if (in_span == 1) buf = buf " "
      i += 2
      continue
    }
    if (c == "`") {
      run = 1
      while (substr(line, i + run, 1) == "`") run++
      if (in_span == 0) {
        in_span = 1; open_run = run; buf = ""
      } else if (run == open_run) {
        scan_span(buf, file, lineno); in_span = 0; buf = ""
      } else {
        # 開きと長さが違うバッククォートはスパンの中身。デリミタとして扱う
        buf = buf " "
      }
      i += run
      continue
    }
    if (in_span == 1) buf = buf c
    i++
  }
}

# スパンの中身をトークンに割り、先頭が禁止プレフィックスのトークンを違反として報告する
function scan_span(span, file, lineno,   m, toks, j, t) {
  # 全角の区切り（LC_ALL=C でもバイト列として安全に効くよう、文字クラスでなく交替で書く）
  gsub(/（|）|「|」|『|』|、|。|：|；/, " ", span)
  # 半角の区切り（先頭の ] は文字クラス内でリテラル扱いになる POSIX の書き方）
  gsub(/[][(){}"'<>|,:;=`]/, " ", span)
  m = split(span, toks, /[ \t]+/)
  for (j = 1; j <= m; j++) {
    t = toks[j]
    # インストール先を明示した絶対パス表記は生成先 repo からも解決できる正表記
    if (t ~ /^[~\/]/) continue
    sub(/^\.\//, "", t)
    if (t ~ /^(scripts\/|skills\/|plugins\/casting\/)/) {
      printf "%s:%d: プラグイン内相対パス表記: %s\n", file, lineno, toks[j]
      rc = 1
    }
  }
}
