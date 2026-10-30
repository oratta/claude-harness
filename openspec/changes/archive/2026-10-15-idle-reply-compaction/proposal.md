## Why

エピックの子（Orca の子セッション）と親（エピックを回すセッション）は、1 時間以上止まってから返事を受けることが多い（会話 100k トークン以上の止まった点のうち、子 3.2%・親 40.6%）。会話のキャッシュは 1 時間で切れるので、そのまま返事を送ると会話全体を書き込み直す（費用 2N）。Claude Code の待っている間の自動コンパクト（最後のリクエストから約 54 分で会話を要約に置き換える）はこの費用を減らせるが、既定の閾値 `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=200000` では、1 時間以上たってから返事が来た止まり方の大半（会話の中央値 子 159k・親 152k）で走らない。あわせて、止まった子を親が解決する手順（#1034）は「そのまま送る」か「起動し直す」かを分ける条件を持っていない。ログから測った損益（#1039 のコメント https://github.com/oratta/claude-harness/issues/1039#issuecomment-6182988861 ）で、閾値と分ける条件を決めて手順に入れる。

## What Changes

- `epic-dispatch.sh launch` が子の端末を起動するコマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` を前置きする。値の既定は 120000 で、環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられる。主の手元のセッション（親を含む）には影響させない
- 時間がたった子・親への返事の規則を `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に新設する: 子と親の閾値（子 120,000・親 100,000）、子の端末に「そのまま送る」か「起動し直す」かを分ける条件、条件の判定に使う観測できる事実、親への適用（親は主が起動するので主の起動コマンドで値を付ける）、親の状態をエピックのコメントから復元できること、1〜2 週間後の再集計
- develop の SKILL.md「エピックの扱い」→「回し方」に、子の起動コマンドに閾値が付くことと、時間がたった子・親に返事を送る前に上のファイルの規則で決めることを短く足す。送り方・起動し直し方の手順本体は #1034 が書く（このファイルを参照する）
- `plugins/dev-workflow/tests/epic-dispatch.bats` の `--command` の期待値を前置き付きに直し、環境変数での上書き・不正値の拒否・規則のファイルと SKILL.md の記述を確かめるテストを足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの並列起動は 1 段で止める」の子の起動コマンドの形に閾値の前置きを足す。時間がたった子・親への返事の規則（値・分ける条件・置き場）を新しい要件として足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`launch` の起動コマンドを組み立てる部分とヘッダコメントだけ）
- `plugins/dev-workflow/skills/develop/references/reply-after-idle.md`（新規）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「回し方」の Orca 経路の段落に 2 か所の追記だけ。他の節は触らない）
- `plugins/dev-workflow/tests/epic-dispatch.bats`
- `plugins/dev-workflow/changes/1039.md`（新規）
- この変更より前に起動された子セッションには前置きが無く、既定の 200,000 のまま動く
