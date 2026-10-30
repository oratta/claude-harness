# 許容の真正性確認: 親経由で受領（手順 5）— pr-review-gate

`$R`=`<owner>/<repo>`、`$N`=PR番号。宣言が `親経由で受領` の形のときに読む。通ったら `stages/pass.md` の手順 5 に戻る。

**親経由で受けた許容（親経由で受領）の真正性確認。** 本体の値（日時・原文=`MATCH:`）:

```
主の回答: 許容 — 親経由で受領（親セッション <セッション ID> / 発言 <uuid> / <日時>）停止の記録: <URL> 原文: <原文>
```

親ログで全条件必須（不成立・exit 1/2 は合格不可、手順6）:

1. `gh api repos/$R/issues/comments/<comment_id> --jq '{body, author_association, issue_url, html_url, created_at}'` で先頭行=`子の停止: 主の返事待ち`、author_association=OWNER/MEMBER/COLLABORATOR、issue_url=記録先を確認。`created_at`・`html_url` を取得。`gh api repos/$R/issues/<記録先>/comments --paginate --jq '[.[] | select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR") | select((.body | split("\n")[0]) == "子の停止: 主の返事待ち")] | last | .html_url'` で最新の停止の記録と URL 一致必須。不一致は手順6。

2. ID・uuid と 1 で取った `created_at`・`html_url` で実行。exit 0・同 timestamp。不一致 URL は `html_url` で実行・宣言に追記

   ```bash
   bash <plugin>/scripts/owner-reply-check.sh --relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>
   # 出力: 通れば MATCH: <timestamp> <本文の全文> と MATCHES=1 / 通らなければ REASON=<理由> と MATCHES=0
   # 終了コード: 0 = 通る / 1 = 通らない / 2 = 確かめられない（引数の不備・この PC に親の会話ログが無い）
   # REASON: not-found（その uuid の行が無い）/ not-owner（主の入力でない行。ツールの結果・親の発言・要約・hook の差し込み・決まった頭の打ち込み）/ not-after（停止の記録より前の発言）/ not-asked（停止の記録より後でその行より前に、URL を書いた親の発言が無い）/ not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）
   ```

3. 全文がこの子・この PR への許容で、別の PR・別の記録先・別の子・別のリスクだけを名指しした答えでない。名指しが無い許容・この子を含む複数への許容は通す
4. timestamp が宣言コメントの作成日時より後

通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --relayed 終了コード 0）`。不成立は手順6で子のタブへ。

守備範囲: 親の会話ログの改変・頭を付けずに打ち込まれた文は塞ぎ切る対象外。

**引き継ぎのとき**（`stages/carryover-origin.md` から）: 上の 1〜3（停止の記録のコメントの確かめ方・`owner-reply-check.sh --relayed` の終了コード 0 と記録の日時と同じ timestamp の `MATCH:`・全文から読む許容の意思と名指し）を元の記録の値で確かめ直し、その timestamp が元の記録を最初に追記した宣言（`引き継ぎ元:` をたどった最初の宣言）の作成日時より後であるときだけ引き継ぐ。`--relayed` の終了コードが 0 でないときを含め、どれかを満たさなければ引き継がず手順6で主に聞く。
