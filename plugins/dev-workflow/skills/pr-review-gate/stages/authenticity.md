# 許容の真正性確認（手順 5）— pr-review-gate

`$R`=`<owner>/<repo>`、`$N`=PR番号。

## 入口

手順 5 の表で、宣言が回答リンクか「会話で受領」で許容済みのときに読む。`親経由で受領` は `stages/authenticity-relayed.md`、`親経由で受領（委任）` は `stages/authenticity-delegated.md`、issue で承認済みは `stages/issue-approved.md` の確かめ直しを読む（「リスクなし」と「引き継ぎ（3-c の4行）」はどれも読まない）。通ったら `stages/pass.md` の手順 5 に戻る。

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
