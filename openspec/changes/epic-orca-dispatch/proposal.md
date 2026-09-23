## Why

今の develop は、エピックの子を 1 つの本体（メインセッション）がまとめて抱える。子ごとに `isolation: "worktree"` の W を起こし、R1・G も本体が起こすため（サブエージェントは孫を起こせない）、子が増えるほど本体のコンテキストに子ごとの往復が積もる。実運用では人がタブを分けて子ごとにセッションを起動しており、この手作業を自動にしたい（issue #420）。

エピック #402 で、親ワークツリーから `orca worktree create --parent-worktree ... --agent claude --prompt "/develop #<N> ..."` で子ごとに独立した Claude Code セッションを起動し、親はシェルのループで子 issue が閉じるのを待つ形を手で試した。#344（PR #413）と #332（PR #418）が並列に完走してマージされ、依存が解けた #284 も同じ手順で起動できた。待っている間の親のトークンは 0 だった。

## What Changes

- `plugins/dev-workflow/skills/develop/SKILL.md` の「エピックの扱い」→「回し方」に振り分けを足す。blocked されていない子が 2 件以上あり `orca` が PATH にあれば Orca 経路（子ごとに Orca の子ワークツリーで独立セッションとして `/develop #<N>` を丸ごと回し、本体はスクリプトで待つ）、それ以外は今のサブエージェント方式のまま。入口は `/develop <エピック番号>` のままで、新しいコマンド名は作らない
- 振り分けの判定・子の起動・待ち受けを、LLM を使わないスクリプト `plugins/dev-workflow/scripts/epic-dispatch.sh` にまとめる。サブコマンドは `route <child>...`（経路を 1 語で出す）、`launch [--note <text>] <epic> <child>...`（`git fetch origin main` → 親ワークツリーをエピックに関連付け → 子ごとに `orca worktree create`）、`wait [--interval <sec>] [--timeout <sec>] <child>...`（子 issue のどれかが閉じるか上限時間に達するまで待ち、1 行を出して終わる）
- 本体は `wait` を背景で起動し、終わって起こされたら依存グラフを読み直して次の子を `launch` し、エピックに `子 #N マージ → 残り k 件` をコメントする
- SKILL.md の「前提」表に `orca` の行を足す（無ければサブエージェント方式）
- bats（`plugins/dev-workflow/tests/epic-dispatch.bats`）で `orca`・`gh`・`git`・`sleep` をスタブにして、引数・呼び出し順・出力・exit code と、`orca` が無い環境でサブエージェント方式に倒れることを確かめる

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの条件・作り方・回し方・完了条件を規定する」の回し方に Orca 経路との振り分けを足す。要件「前提環境を明記する」に `orca` を足す。`epic-dispatch.sh` の `route` / `launch` / `wait` の契約を新しい要件として足す

## Impact

- 追加: `plugins/dev-workflow/scripts/epic-dispatch.sh`、`plugins/dev-workflow/tests/epic-dispatch.bats`
- 変更: `plugins/dev-workflow/skills/develop/SKILL.md`（前提表・エピックの回し方）
- バージョン: `plugins/dev-workflow/.claude-plugin/plugin.json` と `plugins/dev-workflow/CHANGELOG.md`（実装工程で上げる）
- 既存の bats（`develop-skill.bats` のエピックの検査）は、今のサブエージェント方式の記述（`isolation: "worktree"`・並列・スタック）を残すので変えずに通る
- `orca` が無い環境（CI の ubuntu を含む）では振る舞いが変わらない
- やらないこと: Orca 以外のツール（`claude --worktree`、agent view 等）での並列起動、子の PR の自動マージ（マージは今までどおり人の承認）
