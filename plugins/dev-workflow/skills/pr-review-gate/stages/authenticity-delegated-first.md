# 許容の真正性確認: 親経由で受領（委任）の初回だけの確認（手順 5）— pr-review-gate

`$R`=`<owner>/<repo>`、`$N`=PR番号。`stages/authenticity-delegated.md` の 2・4 に加えて確かめる（引き継ぎでは読まない）。

1. 停止の記録を `gh api repos/$R/issues/comments/<comment_id> --jq '{body, author_association, issue_url, html_url, created_at}'` で確かめる: 先頭行=`子の停止: 主の返事待ち`、author_association=OWNER/MEMBER/COLLABORATOR、issue_url=記録先。`gh api repos/$R/issues/<記録先>/comments --paginate --jq '[.[] | select(.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR") | select((.body | split("\n")[0]) == "子の停止: 主の返事待ち")] | last | .html_url'` で最新の停止の記録と一致必須
3. ①子 issue の番号を、本文で最初に現れる `Closes #N`・`Fixes #N`・`Refs #N` の `N` に持つ開いた PR に `needs-approval` が付いている ②その PR の、投稿者が `OWNER`・`MEMBER`・`COLLABORATOR` で `## リスク宣言` で始まる最新のコメントが `主のリスク許容が必要。` の行を持ち、`対象 HEAD:` が PR の今の HEAD と同じで、`主の回答:` で始まる行をまだ持たない（G では、今確かめている委任の形の記録の行だけは除く） ③停止の記録の作成日時が、そのコメントの作成日時と委任の確認の timestamp の両方より後 ④停止の記録の `推奨:` の値（先頭の空白を除く）が `許容する` で始まる
