# handoff-requires-completed-return — 手渡しは前任の return が条件であることを明記する

## Why

develop スキルの W（作業者サブエージェント）は、コンテキスト上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）を超えたら本体が新しい W へ「手渡し」する。既存の記述（`references/decision-criteria.md`「コンテキスト上限」節・`templates/escalation-tripwires.md` トリップワイヤー 4）は「上限を超えたら手渡す」という発火条件だけを書いており、**手渡してよいタイミング**（前任がどの状態にあるか）を規定していなかった。

実際に、本体が前任 W のコンテキストを測って上限超過を検知し、新しい W へ手渡した。ところが前任 W はバックグラウンドで `bash scripts/test.sh`（15〜20 分）を実行中で、その完了通知を待って一時的に idle になっていただけだった。本体にはこの idle が「工程を終えて return した」ように見えたが、実際にはテスト完了後に前任が再び動き出し、そのまま実装を完了させて PR まで作成した。結果、**同じ worktree に新旧 2 人の W が同時に存在する**状態が生まれ、目視確認の重複コメントと共有ブラウザタブグループでのキー入力混線という実害が出た。

根本原因は「サブエージェントが idle になった」と「工程を終えて return した」が別物である、という区別が手順書に書かれていなかったこと。コンテキスト上限超過は「次に再開するときは手渡しに切り替える」という条件であって、「今すぐ前任を打ち切って交代させる」条件ではない。

## What Changes

- **手渡し可否の前提条件を明記する**: 手渡してよいのは前任が工程の終わりに return したときだけ。コンテキスト上限超過は手渡しの必要条件ではあるが十分条件ではない。
- **idle と return の区別を明記する**: バックグラウンドコマンドの完了を待って idle になっている状態は工程の終わりではない。見分け方は、return の内容が成果一覧（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）になっているか、「完了を待っています」のような途中経過だけかで判定する。
- **前任が動作中に交代させる必要がある場合の手順を追加する**: 先に前任へ停止を指示し（自分で元に戻そうとしない＝破壊的 git 操作をしないことを含める）、停止確認（何を編集・投稿したかの報告）を受け取ってから手渡し先を spawn する。
- **同時実行数の明記**: 1 つの作業ディレクトリで同時に動く同一役割のサブエージェントは常に 1 人。これは並列に回してよい単位（エピックの子どうし・独立した change の W どうし）が別々の worktree を持つこととは矛盾しない。
- ドキュメントのみの変更で、コンテキスト上限の閾値・測定方法（`subagent-context.sh`）・手渡し自体の仕組みは変えない。

## Capabilities

### Modified Capabilities

- `dev-workflow-execution-strategy`: 「サブエージェントのコンテキスト上限と手渡し」要件に、手渡し可否は前任の return が条件であること（idle ≠ return の区別・見分け方・前任が稼働中なら先に停止指示・同一作業ディレクトリでの同時実行数は常に 1）を追加する。

## Impact

- **docs**: `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（「コンテキスト上限（サブエージェントの手渡し）」節）、`plugins/dev-workflow/skills/develop/SKILL.md`（1 ループ (3)(4) への短いポインタ）、`plugins/dev-workflow/templates/escalation-tripwires.md`（トリップワイヤー 4 への追記要否を判断し記録）
- **plugin.json**: `plugins/dev-workflow/.claude-plugin/plugin.json` version bump
- **spec**: `dev-workflow-execution-strategy` の「サブエージェントのコンテキスト上限と手渡し」要件の delta（MODIFIED 1）
- **コードの振る舞い変更なし**（`subagent-context.sh` のロジック・閾値は不変）。手順書を読む本体・W の運用判断が変わるのみ
