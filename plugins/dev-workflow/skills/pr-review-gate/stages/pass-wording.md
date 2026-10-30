# 文言合わせの通し方（`stages/pass.md` の WAY が 1 以上）— pr-review-gate

最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があるときに読む。`$DEC` は `stages/pass.md` の値。

```bash
FIXES=$(printf '%s\n' "$DEC" | grep '^直す文: ')             # 直す要件ごとに 1 行
printf '%s\n' "$FIXES"
# 場所は PR の HEAD の作業ツリー（git rev-parse HEAD の出力が $HEAD_SHA と一致すること）。CHANGE には仕様宣言が指す change 名を入れる
ls openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md | wc -l          # ちょうど 1（archive 済みで、差分が 1 ファイル）
grep -cE '^## (ADDED|REMOVED|RENAMED) Requirements' openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md   # 0（ここも終了コードではなく出力の値で判定する）
grep -h '^### Requirement: ' openspec/changes/archive/*-"$CHANGE"/specs/*/spec.md | sed 's/^### Requirement: //' | while IFS= read -r REQ; do printf '%s\n' "$FIXES" | grep -qF "「${REQ}」" || echo "直す文に無い要件: ${REQ}"; done   # 何も出力されなければ、要件名はすべて直す文の行にある
```

`仕様レビュー:` のコメントは照合しない。実測: ①更新した＋ `仕様レビュー: 省いた（文言合わせ。` ②HEAD の `openspec/changes/archive/*-<change-name>/specs/*/spec.md` ちょうど 1 つ ③ADDED / REMOVED / RENAMED 見出しなし ④全要件名が `直す文:` の `「<要件名>」` にある。1 つでも満たさなければ合格しない。修正か、`通し方:` の行の無い仕様化判断を投稿し直して artifact 一式・仕様レビューへ
