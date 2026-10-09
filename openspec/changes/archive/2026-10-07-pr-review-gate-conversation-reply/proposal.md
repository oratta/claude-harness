## Why

pr-review-gate の合格条件は主のリスク許容を「回答リンク」と、リンク先の投稿者を `gh api` で確かめること（真正性確認）で受けている。会話での返事にはリンクが無いので、主は会話で許容と答えたあとに同じ内容を PR にコメントし直すよう頼まれている（2026-09-16〜10-06 の 3 週間で少なくとも 7 回。issue #721）。しかも `gh` は主のアカウントで認証されているので、エージェントが投稿したコメントも投稿者は主になり、投稿者の確認は本人確認になっていない。会話ログ（`~/.claude/projects/<プロジェクト>/<セッション ID>.jsonl`）に残る主の発言のほうが、書き手を区別できる。

## What Changes

- 会話ログに主の発言が実在するかを確かめるスクリプト `plugins/dev-workflow/scripts/owner-reply-check.sh` を新設する。セッション ID と原文（部分一致）を受け取り、主の発言として実在すれば exit 0、無ければ exit 1、引数や環境の不備（会話ログが見つからない別の PC を含む）は exit 2 を返す。アシスタントの発言・サブエージェントの会話・ツールの結果・他のセッションからの転送・`isMeta` の行は主の発言として数えない
- pr-review-gate 手順 5 の合格条件に「会話で受領」の回答の形を足す。宣言コメントに `主の回答: 許容 — 会話で受領（セッション <ID> / <日時>）原文: <原文>` を追記し、スクリプトの exit 0 を真正性確認とする
- 手順 6 の復帰手順と手順 3-c の引き継ぎ条件 3 を、会話で受けた回答でも通るようにする。会話で返事を受けたときは主に PR へのコメントを求めない
- develop の「保留で止まるときの引き継ぎ」の主への案内を「会話で返すか、新しいセッションで `/develop <記録先> 許容する` と打つ」に変え、再開手順で `/develop` の引数を会話で受けた回答として扱う
- 会話ログを読めない PC でゲートが動くときは、これまでどおり PR のコメントで受ける（スクリプトは exit 2 で通さない側に倒す）。Discord など外部サービスの回答リンク（目視確認）は変えない

## Capabilities

### New Capabilities

- `dev-workflow-owner-reply-check`: 会話ログから主の発言の実在を確かめるスクリプトの入出力・終了コード・主の発言として数える行と数えない行

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 合格条件の真正性確認に「会話で受領」の形を足す（収束ルールの ④ を含む）。手順 6 の復帰と 3-c の引き継ぎ条件 3 を会話の回答でも通るようにし、会話で受けたら PR へのコメントを求めない
- `dev-workflow-develop`: 保留で止まるときの主への案内と、新しいセッションでの再開手順で、会話の返事と `/develop` の引数を正式な回答として扱う

## Impact

- 新規: `plugins/dev-workflow/scripts/owner-reply-check.sh`、`plugins/dev-workflow/tests/owner-reply-check.bats`、`plugins/dev-workflow/changes/721.md`
- 変更: `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（手順 5）、`plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（手順 3-c・手順 6）、`plugins/dev-workflow/skills/develop/SKILL.md`（保留で止まるときの引き継ぎ）、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`、必要なら `plugins/dev-workflow/tests/develop-handover.bats`
- 依存: スクリプトは埋め込みの `python3` で JSONL を読む（`context-tripwire.sh` など既存スクリプトと同じ）
- 安全面: ゲートの合格条件を変えるので、この PR 自体が「安全ゲートの弱体化」に当たり、主の許容で保留になる見込み（epic #725 で主が方向を認めている）
- 後続: epic #725 の子 #723 がこのスクリプトを使う
