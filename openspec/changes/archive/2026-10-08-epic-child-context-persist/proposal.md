## Why

`epic-dispatch.sh launch` が子に渡す情報のうち、子ごとの注意書き（`launch --note` の文。「後続の範囲に手を出さない」など）は子のターミナルに最初に送る指示の文面にしか無く、「自分はエピックの子である」という情報は子の端末を起動するコマンドに付けた環境変数 `EPIC_DISPATCH_PARENT_EPIC` にしか無い。オーナーが子のセッションを閉じて同じワークツリーで `/develop #N` だけを打ち直すと、両方が消える。注意書きは守られず、自分を子だと知らないセッションは `route` で `nested` を受けられず、自分の issue をエピックとして孫のワークツリーを作りうる（issue #809、エピック #811）。

あわせて、同じファイルの同じ箇所を触る小さな直しを同じ PR で閉じる（エピック #811 の判断）: `route` の冒頭コメントに `nested` 優先を書く（#532）、`resend_hint` のハンドル引数を `shq` に通す（#487）、端末の作り直しの案内の前に既存端末の有無を確かめる案内を出す（#498）、develop の SKILL.md に端末を作れなかった子の再開手順を書く（#499）。

## What Changes

- `launch --note <text>` は、`orca worktree create` が exit 0 で終わった子ごとに 1 回、子 issue に注意書きをコメントとして投稿する。1 行目は `親エピックからの注意書き: #<epic>` に固定する。`--note` が無ければ投稿しない。`skipped` の子には投稿しない。投稿に失敗しても子の stdout の 1 行と exit code は変えず、stderr に `note not posted to #<N>` と手で投稿するコマンドを出す
- `route` は、`EPIC_DISPATCH_PARENT_EPIC` が空でも、今のワークツリーに親ワークツリーがあり（`orca worktree current --json` の `parentWorktreeId`）、`orca worktree list --json` のうち `id` がその値のワークツリーに `linkedIssue` があれば `nested` を返す。子の件数によらず、この判定は `orca` / `subagent` の判定より先に行う。`nested` のときは stderr に `parent epic: #<N>` を出す（環境変数があればその値、無ければ親の `linkedIssue`）。stdout は今までどおり `nested` の 1 行
- `launch` も同じ判定を `git fetch`・`orca worktree set` より前に行い、親ワークツリーに `linkedIssue` があれば子ワークツリーを作らずに stderr に理由（`child epics are not expanded here` を含む）を出して exit 1 で終わる
- develop の SKILL.md「エピックの扱い」に、記録先の `親エピックからの注意書き:` のコメントに従い W・R1・G に渡すこと、`nested` の親エピックの番号を `route` の stderr から読むこと、端末を作れなかった `failed` の子の再開手順（既存端末の有無を確かめてから作り直して送る）を書く。`orca` のコマンドは書かない
- `epic-dispatch.sh` の冒頭コメント（#532）、`resend_hint`（#487）、`recreate_hint`（#498）を直す
- 変更の記録 `plugins/dev-workflow/changes/809.md` を足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの並列起動は 1 段で止める」の `nested` の条件（環境変数に加えてワークツリーの親子関係）と、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `launch` の振る舞い（注意書きのコメント投稿、作り直しの案内）と `route` の判定順を、優先する ADDED 要件として足す（#805 の変更と同じく、並行する子の archive 後に元の要件へ畳み込む）

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`route`・`launch`・`resend_hint`・`recreate_hint`・冒頭コメント）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（`gh issue comment` のスタブ、親子関係の判定、SKILL.md の記述）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「エピックの扱い」）
- `openspec/specs/dev-workflow-develop/spec.md`（archive 時に反映）
- `plugins/dev-workflow/changes/809.md`（新規）
- `route` の呼び出し 1 回あたり、Orca 管理のワークツリーでは `orca worktree current --json` を子の件数によらず 1 回呼び、親ワークツリーがあるときだけ `orca worktree list --json` を 1 回足す。LLM の呼び出しは増えない。wt-clean・wt-setup は触らない
