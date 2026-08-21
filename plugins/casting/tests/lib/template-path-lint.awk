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
#   検査対象は「コードスパンの中身」だけ（インラインの `…` とフェンス ``` の中）。
#   スパンの外の平文は対象にしない（スパンを跨いだ偽陽性を避けるため）。
#   スパン内はデリミタでトークンに割り、トークンの先頭が禁止プレフィックスのものだけを
#   違反にする。`~/` `/` で始まるトークン（インストール先を明示した絶対パス表記
#   `~/.claude/plugins/marketplaces/*/plugins/casting/…`）は正しい表記なので除外する。

BEGIN { fence = 0; rc = 0 }

# フェンス（``` / ~~~）の開始・終了行。行そのものは検査せず状態だけ切り替える
/^[ \t]*(```|~~~)/ { fence = 1 - fence; next }

fence == 1 { scan_span($0, FILENAME, FNR); next }

{
  # インラインコードスパン: バッククォートで割り、偶数番のかけらがスパンの中身。
  # 閉じられていない最後のかけら（parts[n]）は平文なので検査しない。
  n = split($0, parts, "`")
  for (i = 2; i < n; i += 2) scan_span(parts[i], FILENAME, FNR)
}

END { exit rc }

function scan_span(span, file, lineno,   m, toks, j, t) {
  # 全角の区切り（LC_ALL=C でもバイト列として安全に効くよう、文字クラスでなく交替で書く）
  gsub(/（|）|「|」|『|』|、|。|：|；/, " ", span)
  # 半角の区切り
  gsub(/[()\[\]{}"<>|,:;=]/, " ", span)
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
