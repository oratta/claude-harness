# handoff-requires-completed-return — 手渡しは前任の return が条件であることを明記する

## Why

develop スキルの W（作業者サブエージェント）は、コンテキスト上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）を超えたら本体が新しい W へ「手渡し」する。既存の記述（`references/decision-criteria.md`「コンテキスト上限」節・`templates/escalation-tripwires.md` トリップワイヤー 4）は「上限を超えたら手渡す」という発火条件だけを書いており、**手渡してよいタイミング**（前任がどの状態にあるか）を規定していなかった。

実際に、本体が前任 W のコンテキストを測って上限超過を検知し、新しい W へ手渡した。ところが前任 W はバックグラウンドで `bash scripts/test.sh`（15〜20 分）を実行中で、その完了通知を待って一時的に idle になっていただけだった。本体にはこの idle が「工程を終えて return した」ように見えたが、実際にはテスト完了後に前任が再び動き出し、そのまま実装を完了させて PR まで作成した。結果、**同じ worktree に新旧 2 人の W が同時に存在する**状態が生まれ、目視確認の重複コメントと共有ブラウザタブグループでのキー入力混線という実害が出た。

**1 周目の設計は不十分だった**（R1 の仕様レビューで REQUEST_CHANGES）。「return の内容が成果一覧か途中経過か」という本体側の内容判断だけでは、W が成果一覧とバックグラウンドコマンドの完了待ちを同じ return に併記した場合（実際の W の通常形）に判定が素通りする。バックグラウンドのコマンドが残っているかを知っているのは W 自身だけで、本体には原理的に観測できない。判定の重心を W 側の明示的な宣言に移す必要がある。

**2 周目以降でさらに分かったこと（2026-09-09 の設計変更）**: 同じ規則の言い換えが 10 前後の面（正本・2 つの live spec とその delta・README・SKILL.md・worker.md・gate-runner.md・escalation-tripwires.md・2 つのスクリプト・plugin.json の description）に散らばっており、1 箇所を直すたびに残りを目視で探す形になっていた。1 周目は 6 箇所、2 周目は 1 箇所、3 周目は 6 箇所の取り残しが出て、そのたびにテストも取り残しを検出できなかった（テストが「特定の言い回しを探す」形だったため、言い回しが変わると素通りする）。**取り残しの数を人が見積もる限りこれは繰り返す**ので、言い回しの多様性そのものを無くす。本文を 1 箇所に畳み、他の面は参照だけにする。

## What Changes

- **W / G の return に 1 行目完全一致の宣言契約を導入する**: `工程完了: <工程名>`（成果一覧を伴う、正真正銘の工程の終わり）／`工程中断: <理由>`（バックグラウンドコマンド待ちなど、工程がまだ終わっていない状態）。書式は既存の `仕様化判断: する|しない` / `仕様レビュー: APPROVE|REQUEST_CHANGES` と同じ「1 行目完全一致」契約に揃える。
- **W / G の義務を追加する**: 自分が起動したバックグラウンドコマンドが完了していない状態で `工程完了:` を宣言してはならない。成果一覧を併記していても、そのコマンドが未完了なら 1 行目は `工程中断:` でなければならない。
- **「再開の禁止」と「手渡しの許可」を分離する**: exit 2（コンテキスト上限超過）のときは前任の状態にかかわらず**無条件に** SendMessage で再開しない（従来どおり）。一方、**手渡し**（新しい W / G を spawn すること）を行ってよいのは、①前任の直近の return が `工程完了:` のとき、②前任へ停止を指示して停止確認を受け取ったとき、のいずれかだけであり、`工程中断:` のままどちらも満たさないうちは再開も手渡しもしない。
- **前任が動作中に交代させる必要がある場合の手順を追加する**: 先に前任へ停止を指示し（自分で元に戻そうとしない＝破壊的 git 操作をしないことを含める）、停止確認（何を編集・投稿したかの報告）を受け取ってから手渡し先を spawn する。停止確認を待つ間は本体はブロックせず、他に進められる役割（別 worktree の並列作業）があれば先に進めてよい。unmanned で他に進められる作業が無ければ、そのサイクル内で待ち続けずサイクルを終える。
- **同一作業ディレクトリでの同時実行数を明記する**: 1 つの worktree で同時に動く同一役割のサブエージェントは常に 1 人。並列に起こしてよいのは別々の worktree を持つ役割（エピックの子どうし・独立した change の W どうし）に限る。この制約は「本体はオーケストレータ専任」要件（並列許可の MAY）の直接の限定なので `dev-workflow-develop` capability 側に置く（`dev-workflow-execution-strategy` 側は手渡し・宣言契約に専念させる）。
- **手渡し規則の本文を 1 箇所に畳む（2026-09-09 の設計変更）**: 本文（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させるときの手順）は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」節にだけ置く。`README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`escalation-tripwires.md`・`session-tripwires.sh` の常駐ルール文・`subagent-context.sh` のヘッダコメント・2 つの live spec は、正本への参照だけを書き、独自の言い換えを書かない。`.claude-plugin/plugin.json` の `description` だけは例外としてズレを許容する（エージェントが読まない配布メタデータのため）。
- **本文が 1 箇所にあることの機械検査は入れない（2026-09-09 に撤回）**: 一度は「正本以外の面が手渡しに言及するなら、その箇所は正本への参照を含む」を検査するホワイトリストと、規則の言い換えを文単位で拾う走査を作った。どちらも「緑が『違反が無い』のか『検査が何も見ていない』のか区別できない」形に 7 周続けて落ち、原因が調整不足ではなく「規則の言い換えを機械で検出する」という目的そのものにあると判断して、この change から外した。本文の一本化は規約として spec の MUST NOT に残し、破りを捕まえるのは仕様レビューとする。機械検査が成立するかごと https://github.com/oratta/claude-harness/issues/265 に切り出した。正本が①〜④を現に規定していることを固定する `criteria:` 系のテストは残す。
- `工程完了: <工程名>` / `工程中断: <理由>` の書式リテラルは変えない（別エピックの子 issue がこの書式を前提に設計されているため）。後任の名前・model・spawn プロンプトの生成は別 issue の担当で、この change ではスクリプトを作らない。
- ドキュメントのみの変更で、コンテキスト上限の閾値・測定方法（`subagent-context.sh`）自体は変えない。

## Capabilities

### Modified Capabilities

- `dev-workflow-execution-strategy`: 「サブエージェントのコンテキスト上限と手渡し」要件を、①exit 2 の無条件再開禁止と②`工程完了:`/`工程中断:` の 1 行目宣言契約による条件付き手渡し許可、に分離する。W / G の宣言義務、停止指示〜停止確認の手順、停止確認待ちのノンブロッキング方針、unmanned のサイクル終了条件を追加する。 2026-09-09 の設計変更で、同要件をさらに「規則の本文の置き場所（正本 1 箇所）」「参照だけにする面の一覧」「テストの形（ホワイトリスト・機械的な列挙）」を規定する形に組み替え、条件・書式・手順の本文自体は spec に再掲しない。
- `dev-workflow-develop`: 「本体はオーケストレータ専任でコードもレビューも書かない」要件に、同一 worktree での同一役割の同時実行数は常に 1 であることを追加する（既存の並列許可 MAY の限定）。あわせて「役割のモデルは事前分類と残量モードで決める」要件に重複していた手渡しの記述（`dev-workflow-execution-strategy` と同じ規則の要約）も、無条件の再開禁止と条件付きの手渡し許可に分離した形へ揃える。

## Impact

- **docs**: `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（「コンテキスト上限（サブエージェントの手渡し）」節）、`plugins/dev-workflow/skills/develop/references/roles/worker.md`（W の宣言義務・`工程完了:`/`工程中断:` 書式）、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（G の宣言義務・return の 1 行目）、`plugins/dev-workflow/skills/develop/SKILL.md`（1 ループ (3)(4) への短いポインタ、並列許可の限定）、`plugins/dev-workflow/templates/escalation-tripwires.md`（トリップワイヤー 4 に宣言契約への簡潔なポインタを追記）
- **plugin.json**: `plugins/dev-workflow/.claude-plugin/plugin.json` version bump
- **spec**: `dev-workflow-execution-strategy`（MODIFIED 1）と `dev-workflow-develop`（MODIFIED 2）の delta
- **重複記述の追随**: 同じ規則を要約している面をすべて揃える — `plugins/dev-workflow/README.md`、`plugins/dev-workflow/scripts/session-tripwires.sh`（毎セッション注入される案内文）、`plugins/dev-workflow/scripts/subagent-context.sh`（ヘッダコメント）、`plugins/dev-workflow/.claude-plugin/plugin.json`（description）
- **tests**: 新規 bats（`plugins/dev-workflow/tests/handoff-declaration.bats`）で `工程完了:`/`工程中断:` 宣言契約・無条件再開禁止・同一 worktree 制約の記述を grep で固定する
- **重複の解消（2026-09-09）**: 上の「重複記述の追随」で列挙した面は、追随ではなく**正本への参照だけに置き換える**。対象は `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`escalation-tripwires.md`・`scripts/session-tripwires.sh`・`scripts/subagent-context.sh`・2 つの live spec とその delta。`plugin.json` の `description` は対象外
- **CHANGELOG**: 2.5.1 の記述を、追随ではなく統合（本文 1 箇所＋参照）に合わせて書き直す（apply 時）
- **コードの振る舞い変更なし**（`subagent-context.sh` のロジック・閾値は不変）。手順書を読む本体・W / G の運用判断と return の書式が変わる
