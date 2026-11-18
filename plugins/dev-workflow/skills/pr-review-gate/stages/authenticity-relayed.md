# authenticity-relayed — pr-review-gate

入口: 許容の記録が委任によらない親経由で受領の形のときだけ読む。

**親経由で受けた許容（親経由で受領）の真正性確認。** エピックの子で、主が親のセッションの会話にだけ許容を返し、親が `epic-dispatch.sh reply --as owner` で末尾に ` [主の発言: セッション <親のセッション ID> / uuid <uuid>]` を添えて送ってきたときは、develop の本体が `owner-reply-check.sh --relayed` の終了コード 0 を確かめてから値（親のセッション ID・uuid・`MATCH:` の timestamp・停止の記録の URL・`MATCH:` の全文）を渡す。宣言コメントに次の 1 行を追記する（`<日時>` は `MATCH:` の行の timestamp、`<原文>` はその行の全文。行頭は `主の回答: 許容` のままにし、手順 3-c の「前の宣言の選び方」がこの記録を主の直接の回答として拾えるようにする）:

```
主の回答: 許容 — 親経由で受領（親セッション <セッション ID> / 発言 <uuid> / <日時>）停止の記録: <URL> 原文: <原文>
```

真正性確認では次をすべて確かめる。子に届いた文は主の発言と区別できないので根拠にせず、親の会話ログの行そのものを読む。

1. 停止の記録の URL のコメントを `gh api repos/$R/issues/comments/<comment_id> --jq '{body, author_association, issue_url, html_url, created_at}'` で読み、1 行目が `子の停止: 主の返事待ち`、`author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれか、`issue_url` がこの PR の記録先の issue であることを確かめ、作成日時（`created_at`）と URL（`html_url`）を取る。あわせて `gh api repos/$R/issues/<記録先>/comments --paginate --jq '[.[] | select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR") | select((.body | split("\n")[0]) == "子の停止: 主の返事待ち")] | last | .html_url'` で記録先の最新の停止の記録の URL を取り、`html_url` と一致することを確かめる（一致しなければ別の止まりの記録を渡されているので、合格させず手順6で主に聞く）
2. 記録のセッション ID・uuid と、1 で取った `created_at`・`html_url` で次を回し（記録の URL が `html_url` と文字列で違うときは `html_url` で回し、記録の URL を `html_url` に揃えた 1 行を宣言コメントに追記する）、終了コード 0 で、`MATCH:` の timestamp が記録の日時と同じであることを確かめる

   ```bash
   bash <plugin>/scripts/owner-reply-check.sh --relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>
   # 出力: 通れば MATCH: <timestamp> <本文の全文> と MATCHES=1 / 通らなければ REASON=<理由> と MATCHES=0
   # 終了コード: 0 = 通る / 1 = 通らない / 2 = 確かめられない（引数の不備・この PC に親の会話ログが無い）
   # REASON: not-found（その uuid の行が無い）/ not-owner（主の入力でない行。ツールの結果・親の発言・要約・hook の差し込み・決まった頭の打ち込み）/ not-after（停止の記録より前の発言）/ not-asked（停止の記録より後でその行より前に、URL を書いた親の発言が無い）/ not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）
   ```

3. `MATCH:` の全文から許容の意思を読む（記録の原文だけで読まない）。全文がこの子・この PR への許容と読め、別の PR・別の記録先・別の子・別のリスクだけを名指しした答えでないことを確かめる。名指しが無い許容と、この子とほかの子をまとめて名指しした答え（例: `1034 も 1030 も許容`）は通す
4. その timestamp が、記録を追記する宣言コメントの作成日時より後であることを確かめる

通したら `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --relayed 終了コード 0）` を追記する。どれかを満たさないとき（終了コード 1 の `not-found`・`not-owner`・`not-after`・`not-asked`・`not-direct`、終了コード 2 を含む）は合格させず、手順6に戻して、主に子のタブで直接返事を打ってもらうよう頼む。

守備範囲: 親の会話ログの改変・追記と、親のターミナルに決まった頭を付けずに打ち込まれた文（`origin.kind` が human で残る）は、この確認でも主の発言と区別できない。目的は従来の経路より弱くしないことで、偽造の経路を塞ぎ切ることではない。

出口: `stages/authenticity.md` を呼んだ箇所へ戻る。合格しなければ本文どおり手順 6 へ進む。
