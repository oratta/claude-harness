## Why

サブエージェント（W / R1 / G）が背景タスクの完了通知を待つつもりでターンを終えると、名前付き background サブエージェントは通知では再起動されないので、親が SendMessage を送るまで止まる。#509 の実測ではマージ済み PR 12 本で 7 件（3.47 ドル）起き、うち 3 件は主の「止まってる？」で初めて発覚した。代金より、主が気づくまで作業が止まる時間のほうが大きい。

禁止そのものは正本 `plugins/dev-workflow/references/subagent-waiting.md` と各指示書に既に書いてあり、`tests/subagent-waiting.bats` が文言を検査している。しかし文言検査は既知の固定文字列しか見ないので、意味を保った言い換えも、書いてあるのに従わない振る舞いも止められない（PR #256 のゲートで「原理的に止められない、実行時の仕組みが要る」と合意済みの限界）。文言をこれ以上足しても 7 件は減らないので、ターンを終える瞬間そのものを実行時に止める。

## What Changes

- dev-workflow プラグインに hook スクリプト `scripts/subagent-stop-guard.sh` を 1 本追加し、`hooks/hooks.json` の **SubagentStop** に登録する。
- サブエージェントがターンを終えようとした時点で、そのサブエージェント自身のトランスクリプトから「自分が `run_in_background` で起動し、まだ終了通知（`<task-notification>` の `<status>` が `completed` / `failed` / `killed`）が記録されていない背景タスク」を数える。1 件以上あれば停止を拒否し（`{"decision":"block","reason":…}`）、未完了のタスク ID と出力ファイルのパス、前景の待ちループで待つこと、正本の場所を理由に書いて返す。
- 上限到達後の正当な出口を 1 つ決める: 待ちをやめて return するとき（上限到達・結果の放棄）は、return する前に背景タスクを TaskStop（旧名 KillShell）で停止する。停止で `killed` の通知が記録されるので hook はその停止を 1 回目で通す。この規則を正本と既存要件「待ちは前景の有限ループを上限回数まで呼び直す」に足し、拒否理由にも書く。
- 同じサブエージェントへの拒否は正本の総待ちの上限回数（3 回）までとし、それを超えた停止は通す。これは理由を無視して停止を繰り返すサブエージェントを無限に止めないための後詰めで、通した時点でカウンタを消す。
- メインセッション（`agent_id` が無い）は対象外。判定できないときは停止を通す（fail-open）。`DEV_WORKFLOW_STOP_GUARD=off` で全解除できる。
- 正本 `subagent-waiting.md` に、この実行時の検査が存在すること・何を見て何を止めるか・上限到達後は TaskStop で停止してから return すること・拒否回数を上限回数と一致させることを書く。指示書側には再掲しない（正本 1 本の原則）。
- issue #264 のコメントにある宿題 4 件（手順 2・3 の実行時検査、雛形抽出の横展開、companion 経路の評価、`$RANDOM` 版の実測）を実装工程で個別の issue に起票する。
- 規約違反の待ち方をわざと行う再現ケースを 2 つ用意する: bats の合成トランスクリプト（文言検査の素通りは、プラグインの複製に違反を差し込んで既存の `subagent-waiting.bats` を走らせて示す）と、`claude -p --plugin-dir` の実セッションで背景 `sleep` を起動してターンを終えるサブエージェント。`subagent-waiting.bats` は素通りし、新しい hook は止めることを示す。

破壊的変更なし。未完了の背景タスクを持たないサブエージェントの停止、メインセッションの停止には何も出力しない。

## Capabilities

### New Capabilities

なし（既存 capability の要件変更と追加のみ）。

### Modified Capabilities

- `dev-workflow-subagent-waiting`: 「サブエージェントは完了を待つためにターンを終えない」を、手順書の禁止だけでなく SubagentStop hook による実行時の拒否で守る要件に改める。hook の守備範囲（拾う誤り・通す入力・守らないもの）・判定対象（自分の未完了の背景タスク）・拒否の書式と理由文・拒否回数の上限（後詰め）・対象外と fail-open・全解除の環境変数・hooks.json への登録を要件として足す。文言検査では止められない違反を実行時の検査が止めることを再現ケースで示す要件も足す（既存の要件「待ち方の退行を機械検出する」は変えない）。既存要件「待ちは前景の有限ループを上限回数まで呼び直す」に、待ちをやめて return する前に TaskStop で背景タスクを停止する規則を足す。

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（SubagentStop のエントリを追加。**聖域パスかつ層間契約**）
- `plugins/dev-workflow/scripts/subagent-stop-guard.sh`（新規）
- `plugins/dev-workflow/tests/subagent-stop-guard.bats`（新規。hooks.json の登録内容の検査もここに置く）
- `plugins/dev-workflow/references/subagent-waiting.md`（実行時の検査の 1 節と、「総待ちの上限と超過時の分岐」への TaskStop の規則を追加）
- GitHub issue: 宿題 4 件の新規起票（#264 へのコメントで番号を残す）
- `plugins/dev-workflow/changes/264.md`（変更の記録。版は上げない）
- SubagentStop は install 先の全サブエージェントの停止ごとに 1 回走る。トランスクリプト全体を読むので、対象行だけを先に絞り込み、5MB のトランスクリプトでも 200ms 未満で終える
