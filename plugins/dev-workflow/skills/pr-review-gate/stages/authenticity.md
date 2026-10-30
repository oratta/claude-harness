# 許容の真正性確認（手順 5）— pr-review-gate

`$R`=`<owner>/<repo>`、`$N`=PR番号。

## 入口

手順 5 の表で、宣言が「回答リンク」「会話で受領」「親経由で受領」「親経由で受領（委任）」「issue で承認済み」のどれかで許容済みになっているときに読む（「リスクなし」と「引き継ぎ（3-c の4行）」だけなら読まない）。通ったら `stages/pass.md` の手順 5 に戻る。

## 手順

**リンク**: 開いて主本人の許容を確認、 `真正性確認: 済 — 確認者 <エージェント名> / <日時>` を追記。GitHub author:

```bash
gh api repos/$R/issues/comments/<comment_id> --jq '.user.login'   # 主のアカウント名と一致すること
```

外部は目視。開けない・本人でない・許容無しは手順6。

**会話で受けた許容（会話で受領）の真正性確認。** 本体の値:

```
主の回答: 許容 — 会話で受領（セッション <セッション ID> / <日時>）原文: <原文>
```

```bash
bash <plugin>/scripts/owner-reply-check.sh <セッション ID> <原文>
# 出力: 一致した主の発言ごとに MATCH: <timestamp> <本文の全文> / 最後に MATCHES=<件数>
# 終了コード: 0 = 主の発言として実在する / 1 = 実在しない / 2 = 確かめられない（引数の不備・この PC に会話ログが無い）
```

exit 0、同じ timestamp の `MATCH:` 全文で意思確認。宣言コメントの作成日時（`gh api repos/$R/issues/comments/<comment_id> --jq '.created_at'`）より後のこの宣言への返事だけ有効。通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh 終了コード 0）`。

- 終了コード 0 でも同じ timestamp の `MATCH:` 無し・全文が `許容しない` なら合格させない
- 宣言より前・同時、別の PR・記録先・リスクへの返事も合格させない
- 終了コード 1 は手順6（記録改変禁止）
- exit 2 は通さず理由を伝え、PR コメントか同じ PC の `/develop <記録先> 許容する` で受け直す

守備範囲: 会話ログの改変は対象外。決まった頭 `主の返事（親エピック #` / `親エピック #` は除外。頭の無い文は識別不可。

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

**主の委任で親経由に受けた許容（親経由で受領（委任））の真正性確認。** 本体の値（日時・原文=`MATCH:`）:

```
主の回答: 許容 — 親経由で受領（委任）（親セッション <セッション ID> / 委任の確認 <uuid> / <日時>）委任の記録: <URL> 停止の記録: <URL> 原文: <原文>
```

`--relayed` で確かめない（`not-after` になる）。

1. 親経由1の `gh api` で `子の停止: 主の返事待ち` の本文・投稿者・記録先・日時を再確認。`--jq '... | last | .html_url'` で最新の停止の記録と一致必須
2. 委任の記録が、①エピック #<E> の issue のコメントで、1〜4 行目が定型の文ちょうど、2 行目の番号が <E> ②投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` のどれか ③エピックの、投稿者が同じ 3 種の `主の委任:` で始まるコメントのうち最新 ④`lastEditedAt` が null ⑤エピックが開いている ⑥子 issue がエピックの子（sub-issue か本文の子の表にある）。<E> は子に届いた返事の頭 `主の返事（親エピック #<E> 経由）` の番号で、委任の記録 URL の issue 番号と一致必須（定型文: develop `references/epic.md`）
3. ①子 issue の番号を、本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` に持つ開いた PR に `needs-approval` が付いている ②その PR の、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` で `## リスク宣言` で始まる最新のコメントが `主のリスク許容が必要。` の行を持ち、`対象 HEAD:` が PR の今の HEAD と同じで、`主の回答:` で始まる行をまだ持たない（G では、今確かめている委任の形の記録の行だけは除く） ③停止の記録の作成日時が、そのコメントの作成日時と委任の確認の timestamp の両方より後 ④停止の記録の `推奨:` の値（先頭の空白を除く）が `許容する` で始まる
4. 委任の日時（`gh api repos/$R/issues/comments/<comment_id> --jq .created_at`）・停止日時で実行。exit 0・同 timestamp の `MATCH:` 全文に任せる意思が必須

   ```bash
   bash <plugin>/scripts/owner-reply-check.sh --delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>
   # 出力: 通れば MATCH: <timestamp> <本文の全文> と MATCHES=1 / 通らなければ REASON=<理由> と MATCHES=0
   # 終了コード: 0 = 通る / 1 = 通らない / 2 = 確かめられない（引数の不備・この PC に親の会話ログが無い）
   # REASON: not-found（その uuid の行が無い）/ not-owner（主の入力でない行）/ not-after（委任の記録より後でない発言）/ not-asked（委任の記録より後でその行より前に、委任の記録の URL を書いた親の発言が無い）/ not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）/ not-before（停止の記録より前でない発言）
   ```

通れば `真正性確認: 済 — 確認者 <エージェント名> / <日時>（owner-reply-check.sh --delegated 終了コード 0）`。不成立・exit 1/2 は合格させず手順6で子のタブへ。

守備範囲（委任の形）: 親が起動し直したものは可。ログ改変・穴を塞ぎ切る対象外。

**issue で承認済みの確かめ直し。** `declarations.md` 3の全条件を確かめ直す（`owner-reply-check.sh`・`agent-proposed`・`lastEditedAt`・`EPIC_DISPATCH_PARENT_EPIC`・`--unmanned`・事後報告を届ける先・返事が答えた起票の提案に目的と引用した各効果、子は承認された提案の範囲内）。不成立は手順6（不足条件も）。通れば:

```
確かめ直し: 済 — 確認者 <エージェント名> / <日時>（手順 5）
```

`真正性確認: 済` の行は足さない（3-c「前の宣言の選び方」）。

無人運用（loop-dev-agent）・主に事後報告を届ける先が無い経路は issue で承認済みを当てない。あっても手順6。

事後報告は 1 回: 宣言コメントの URL・引用・分類（G は return）。後日の不許容は手順6（revert 等）。
