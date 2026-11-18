# pass-wording — pr-review-gate

```bash
# ここから下の 3 本は WAY が 1 以上のときだけ実行する。場所は PR の HEAD の作業ツリー（git rev-parse HEAD の出力が $HEAD_SHA と一致すること）。CHANGE には仕様宣言が指す change 名を入れる
ls openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md | wc -l          # ちょうど 1（archive 済みで、差分が 1 ファイル）
grep -cE '^## (ADDED|REMOVED|RENAMED) Requirements' openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md   # 0（ここも終了コードではなく出力の値で判定する）
grep -h '^### Requirement: ' openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md | sed 's/^### Requirement: //' | while IFS= read -r REQ; do printf '%s\n' "$FIXES" | grep -qF "「${REQ}」" || echo "直す文に無い要件: ${REQ}"; done   # 何も出力されなければ、要件名はすべて直す文の行にある
```

| `仕様化判断: する`＋`通し方: 文言合わせ` の行あり | `仕様レビュー:` のコメントは照合しない（この通し方では R1 を起こさないので、コメントが無いことを不合格の理由にしない）。代わりに次の 4 点をすべて実測する: ①仕様宣言が `仕様レビュー: 省いた（文言合わせ。` を含む「更新した」形 ②PR の HEAD で `openspec/changes/archive/*-<change-name>/specs/*/spec.md` に当たるファイルがちょうど 1 つ（archive 済みで、差分が 1 ファイル） ③そのファイルに ADDED / REMOVED / RENAMED の見出しが無い ④そのファイルの `### Requirement:` の要件名がすべて、`直す文:` で始まるどれかの行に `「<要件名>」` の形で現れる。1 つでも満たさなければ合格しない。直し方は、差分か仕様化判断のコメントを直して 4 点を満たすか、`通し方:` の行の無い仕様化判断を投稿し直して artifact 一式と仕様レビューからやり直すかのどちらか |

最新判断に文言合わせの行が無い場合は `stages/pass.md` の通常の照合表を使う。
