# handoff-requires-completed-return — 手渡しは前任の return が条件であることを明記する

## Why

develop スキルの W（作業者サブエージェント）は、コンテキスト上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）を超えたら本体が新しい W へ「手渡し」する。既存の記述（`references/decision-criteria.md`「コンテキスト上限」節・`templates/escalation-tripwires.md` トリップワイヤー 4）は「上限を超えたら手渡す」という発火条件だけを書いており、**手渡してよいタイミング**（前任がどの状態にあるか）を規定していなかった。

実際に、本体が前任 W のコンテキストを測って上限超過を検知し、新しい W へ手渡した。ところが前任 W はバックグラウンドで `bash scripts/test.sh`（15〜20 分）を実行中で、その完了通知を待って一時的に idle になっていただけだった。本体にはこの idle が「工程を終えて return した」ように見えたが、実際にはテスト完了後に前任が再び動き出し、そのまま実装を完了させて PR まで作成した。結果、**同じ worktree に新旧 2 人の W が同時に存在する**状態が生まれ、目視確認の重複コメントと共有ブラウザタブグループでのキー入力混線という実害が出た。

**1 周目の設計は不十分だった**（R1 の仕様レビューで REQUEST_CHANGES）。「return の内容が成果一覧か途中経過か」という本体側の内容判断だけでは、W が成果一覧とバックグラウンドコマンドの完了待ちを同じ return に併記した場合（実際の W の通常形）に判定が素通りする。バックグラウンドのコマンドが残っているかを知っているのは W 自身だけで、本体には原理的に観測できない。判定の重心を W 側の明示的な宣言に移す必要がある。

## What Changes

- **W / G の return に 1 行目完全一致の宣言契約を導入する**: `工程完了: <工程名>`（成果一覧を伴う、正真正銘の工程の終わり）／`工程中断: <理由>`（バックグラウンドコマンド待ちなど、工程がまだ終わっていない状態）。書式は既存の `仕様化判断: する|しない` / `仕様レビュー: APPROVE|REQUEST_CHANGES` と同じ「1 行目完全一致」契約に揃える。
- **W / G の義務を追加する**: 自分が起動したバックグラウンドコマンドが完了していない状態で `工程完了:` を宣言してはならない。成果一覧を併記していても、そのコマンドが未完了なら 1 行目は `工程中断:` でなければならない。
- **「再開の禁止」と「手渡しの許可」を分離する**: exit 2（コンテキスト上限超過）のときは前任の状態にかかわらず**無条件に** SendMessage で再開しない（従来どおり）。一方、**手渡し**（新しい W / G を spawn すること）を行ってよいのは前任の直近の return が `工程完了:` のときだけであり、`工程中断:` のときは再開も手渡しもしない。
- **前任が動作中に交代させる必要がある場合の手順を追加する**: 先に前任へ停止を指示し（自分で元に戻そうとしない＝破壊的 git 操作をしないことを含める）、停止確認（何を編集・投稿したかの報告）を受け取ってから手渡し先を spawn する。停止確認を待つ間は本体はブロックせず、他に進められる役割（別 worktree の並列作業）があれば先に進めてよい。unmanned で他に進められる作業が無ければ、そのサイクル内で待ち続けずサイクルを終える。
- **同一作業ディレクトリでの同時実行数を明記する**: 1 つの worktree で同時に動く同一役割のサブエージェントは常に 1 人。並列に起こしてよいのは別々の worktree を持つ役割（エピックの子どうし・独立した change の W どうし）に限る。この制約は「本体はオーケストレータ専任」要件（並列許可の MAY）の直接の限定なので `dev-workflow-develop` capability 側に置く（`dev-workflow-execution-strategy` 側は手渡し・宣言契約に専念させる）。
- ドキュメントのみの変更で、コンテキスト上限の閾値・測定方法（`subagent-context.sh`）自体は変えない。

## Capabilities

### Modified Capabilities

- `dev-workflow-execution-strategy`: 「サブエージェントのコンテキスト上限と手渡し」要件を、①exit 2 の無条件再開禁止と②`工程完了:`/`工程中断:` の 1 行目宣言契約による条件付き手渡し許可、に分離する。W / G の宣言義務、停止指示〜停止確認の手順、停止確認待ちのノンブロッキング方針、unmanned のサイクル終了条件を追加する。
- `dev-workflow-develop`: 「本体はオーケストレータ専任でコードもレビューも書かない」要件に、同一 worktree での同一役割の同時実行数は常に 1 であることを追加する（既存の並列許可 MAY の限定）。

## Impact

- **docs**: `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（「コンテキスト上限（サブエージェントの手渡し）」節）、`plugins/dev-workflow/skills/develop/references/roles/worker.md`（W の宣言義務・`工程完了:`/`工程中断:` 書式）、`plugins/dev-workflow/skills/develop/SKILL.md`（1 ループ (3)(4) への短いポインタ、並列許可の限定）、`plugins/dev-workflow/templates/escalation-tripwires.md`（トリップワイヤー 4 に宣言契約への簡潔なポインタを追記）
- **plugin.json**: `plugins/dev-workflow/.claude-plugin/plugin.json` version bump
- **spec**: `dev-workflow-execution-strategy` と `dev-workflow-develop` の delta（それぞれ MODIFIED 1）
- **コードの振る舞い変更なし**（`subagent-context.sh` のロジック・閾値は不変）。手順書を読む本体・W の運用判断と return の書式が変わる
