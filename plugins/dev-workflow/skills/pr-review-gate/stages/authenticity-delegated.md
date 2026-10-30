# 許容の真正性確認: 親経由で受領（委任）（手順 5）— pr-review-gate

`$R`=`<owner>/<repo>`、`$N`=PR番号。宣言が `親経由で受領（委任）` の形のときに読む。通ったら `stages/pass.md` の手順 5 に戻る。

**主の委任で親経由に受けた許容（親経由で受領（委任））の真正性確認。** 本体の値（日時・原文=`MATCH:`）:

```
主の回答: 許容 — 親経由で受領（委任）（親セッション <セッション ID> / 委任の確認 <uuid> / <日時>）委任の記録: <URL> 停止の記録: <URL> 原文: <原文>
```

`--relayed` で確かめない（`not-after` になる）。引き継ぎでなければ加えて `stages/authenticity-delegated-first.md` の 1 と 3 を確かめる。

2. 委任の記録が、①エピック #<E> の issue のコメントで、1〜4 行目が定型の文ちょうど、2 行目の番号が <E> ②投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれか ③エピックの、投稿者が同じ 3 種の `主の委任:` で始まるコメントのうち最新 ④`lastEditedAt` が null ⑤エピックが開いている ⑥子 issue がエピックの子（sub-issue か本文の子の表にある）。<E> は子に届いた返事の頭 `主の返事（親エピック #<E> 経由）` の番号で、委任の記録 URL の issue 番号と一致必須（定型文: develop `references/epic.md`）
4. 委任の日時（`gh api repos/$R/issues/comments/<comment_id> --jq .created_at`）・停止日時で実行。exit 0・同 timestamp の `MATCH:` 全文に任せる意思が必須

   ```bash
   bash <plugin>/scripts/owner-reply-check.sh --delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>
   # 出力: 通れば MATCH: <timestamp> <本文の全文> と MATCHES=1 / 通らなければ REASON=<理由> と MATCHES=0
   # 終了コード: 0 = 通る / 1 = 通らない / 2 = 確かめられない（引数の不備・この PC に親の会話ログが無い）
   # REASON: not-found（その uuid の行が無い）/ not-owner（主の入力でない行）/ not-after（委任の記録より後でない発言）/ not-asked（委任の記録より後でその行より前に、委任の記録の URL を書いた親の発言が無い）/ not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）/ not-before（停止の記録より前でない発言）
   ```

通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --delegated 終了コード 0）`。不成立・exit 1/2 は合格させず手順6で子のタブへ。

守備範囲（委任の形）: 親が起動し直したものは可。ログ改変・穴を塞ぎ切る対象外。

**引き継ぎのとき**（`stages/carryover-origin.md` から）: 上の 4（`owner-reply-check.sh --delegated` の終了コード 0・記録の日時と同じ timestamp の `MATCH:`・全文から読む任せる意思）を元の記録の値で確かめ直し、引き継ぎの時点で上の 2 の「委任が有効か」の文を満たし、停止の記録の作成日時が元の記録を最初に追記した宣言（`引き継ぎ元:` をたどった最初の宣言）の作成日時より後であるときだけ引き継ぐ。`--relayed` で確かめ直さない（委任の確認は停止の記録より前の発言なので必ず `not-after` で落ちる）。取り消し（エピックの最新の `主の委任:` で始まるコメントが `主の委任: 取り消し`）・新しい委任の記録がある・エピックが閉じた・記録が編集されたときを含め、どれかを満たさなければ引き継がず手順6で主に聞く。
