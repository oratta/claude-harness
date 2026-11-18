# authenticity — pr-review-gate

**許容リンク経由の合格では、リンクの真正性を確認する。** リンク先を実際に開き、
①**主のアカウントによる発言**であること ②**許容の意思が読み取れる**こと、の両方を確認し、
結果を宣言コメントに追記する（形式: `真正性確認: 済 — 確認者 <エージェント名> / <日時>`）。
リンクが GitHub コメントの場合は author を実測する:

```bash
gh api repos/$R/issues/comments/<comment_id> --jq '.user.login'   # 主のアカウント名と一致すること
```

Discord 等の外部サービスのリンクは目視確認でよい（確認記録は同じ形式で残す）。
リンク先が開けない・主本人の発言と確認できない場合は合格処理をしない（手順6に戻して主に再確認する）。


会話で受領の記録なら `stages/authenticity-conversation.md` を読む。

親経由で受領（委任でない）の記録なら `stages/authenticity-relayed.md` を読む。

親経由で受領（委任）の記録なら `stages/authenticity-delegated.md` を読む。
