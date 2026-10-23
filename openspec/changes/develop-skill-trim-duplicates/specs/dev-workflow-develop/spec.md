## MODIFIED Requirements

### Requirement: W の (3) は 2 回の return に分かれる
本体がサブエージェントのコンテキスト量を測れるのは、W を SendMessage で再開する直前（＝ W が return した直後）だけである。したがって return の区切りの数がそのまま計測点の数になる。W の実装以降の工程 (3) は、次の 2 つの return に分けなければならない（MUST）。

- **(3a) 実装＋verify**: 実装（仕様化した場合は `tasks.md` を上から TDD で。直行なら TDD）と verify（仕様化した場合は `openspec validate <change> --strict` と `tasks.md` のチェックボックスが全部 `[x]` であることの確認）までを行い、`工程完了: 実装＋verify` を 1 行目にして return する
- **(3b) archive＋PR＋仕様宣言**: `openspec archive <change>`（仕様化した場合）・PR を Draft のまま用意すること（記録先が Draft PR ならそのまま使い、issue が記録先なら `gh pr create --draft` で作る。Ready には切り替えない）・仕様宣言を PR コメントに書くことを行い、`工程完了: archive＋PR＋仕様宣言` を 1 行目にして return する

境界は archive の手前に置き、verify は (3a) 側に含めなければならない（MUST）。verify の失敗は実装への巻き戻しであり、実装と verify を別の担い手に割ると手渡し直後に巻き戻しが起きるためである。

**(3) をこれより細かく（`tasks.md` の項目単位・「実装／verify／archive／PR／仕様宣言」の 5 段など）分割してはならない（MUST NOT）。** 手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。この固定分は工程の大きさに依存しないため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代する。

`references/roles/worker.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。(3a) は openspec CLI 経路（`tasks.md` を TDD で実装＋`openspec validate --strict`）・コード直行（TDD）のどちらの入口でも実装後に検査を実行するため、**worker.md は「全経路共通の大原則」に、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップを読み、検査コマンド（lint・test・ビルド等）と環境セットアップ（依存インストール等）を判別し、拾った検査コマンドを種類ごとに次のとおり扱わなければならない（MUST）という指示を置かなければならない（MUST。経路それぞれに重複して書かない）**: lint・型検査などの静的検査は手元で実行する（ツールがファイルを引数に取れるなら変えたファイルに当て、取れないなら CI と同じ形で実行する）。テストの全体実行（テストランナーをファイルで絞らずに起動するもの）は手元で実行してはならず（MUST NOT）、変えたファイルに関係するテストだけを実行し、全体は CI に任せる。ビルドは手元で実行せず CI に任せる。関係するテストは、この変更で足した・変えたテストのファイル、テストのファイルのうち変えたファイルのパスかファイル名を含むもの（`git grep -l` 等で探す）、テストランナーが変えたファイルから関係するテストを選ぶ機能を持つならその結果、CI の見張りの `fix`（`references/ci-watch.md` 7）で直すときは落ちた run のログ（`gh run view <run> --log-failed`）に出たテストのファイル、の和集合とし、テストランナーにファイルを渡して実行する。例: `auto-merge.yml` や `revert-pr.yml` のように `pull_request` / `push` 以外のイベントで起動する運用系ワークフローは対象に含めない（MUST NOT）。コマンド名をこのリポジトリ固有の値（`scripts/test.sh` など）に固定してはならない（MUST NOT。develop は複数リポジトリで使われ、CI の構成はリポジトリごとに異なるため）。PR・push で起動してテストの全体実行をするジョブが無い（workflow ファイルが存在しない、テストのジョブが無い、または `run:` から検査コマンドを判別できない）ときは、全体のテストを CI に任せられないので、手元で全体を実行しなければならず（MUST）、慣例コマンド（`scripts/test.sh` 等）へのフォールバックを許容する（MAY）。Draft では CI を走らせないリポジトリは、Ready にした時点で CI が走るので CI に任せられる側に数える。手元にツールが無く実行できない検査（apt でプリインストールされた `shellcheck` 等）は「未導入」として実行結果と区別しなければならず、未導入を合格として扱ってはならない（MUST NOT）。**(3a) の return には、収集した検査コマンドの一覧・手元で実行した検査コマンド（関係するテスト・静的検査）と exit code（未導入の検査があれば未導入と明記）・関係するテストを探したコマンド・手元で実行せず CI に任せた検査とその CI のジョブ名、および `openspec validate --strict` の exit code（仕様化した場合。直行した場合は「仕様化しないため verify なし」）と、画面確認の要否の行（「W の (3a) の return は画面確認の要否を 1 行で書く」Requirement）を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。`openspec validate --strict` の exit code が無いと、(3b) の担い手は verify を通ったことを確認できないまま archive に進むことになる。CI 由来の検査コマンドをすべて return に含め、静的検査を手元で実行することで、G がゲートを合格にしたあとに CI の一部（このリポジトリでは shellcheck）が落ち、W・レビュー・G をもう 1 周回す再発を防ぐ。テストの全体実行を手元で行わないのは、CI が同じ中身を分けて短時間で回し、ゲート合格後の CI の見張り（`references/ci-watch.md`）が落ちた CI を直しに回すためで、手元で全体を回すと実装・仕上げ・指摘の修正のたびに全体の所要（claude-harness では約 40 分）を待つことになる（#1211）。

この要件の守備範囲で入力として扱うのは、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップと、変えたファイルの一覧である。拾いたい誤りは、CI が流す静的検査を W が取りこぼすこと（PR #489 の shellcheck）と、変えたファイルを名前で参照するテストの失敗をゲートより後まで持ち越すことである。変えたファイルを別のスクリプト経由で間接的に読むテストを関係するテストとして拾えないことは、この要件では止めない（CI とゲート合格後の CI の見張りが拾う）。次は通ってよく、この要件では止めない: `matrix` / `services` / `env` / `if:` 条件により CI の実行環境と手元の実行結果が食い違うこと、CI ランナー固有の環境に依存する検査、環境セットアップの `run:` ステップを検査コマンドと誤って実行すること。取りこぼしが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。CI が実際に落ちるかどうかは、G が pr-review-gate 手順 4 で対象 HEAD の CI の結果を証拠として見ることに加え、ゲート合格後の CI の見張り（`references/ci-watch.md`）が拾う。auto-merge を配備したリポジトリでは必須チェックが緑になるまでマージされない。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本である（再掲の禁止は既存の Requirement「コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く」が規定しており、ここでは重ねて規定しない）。

本体は次に指示する工程を、**自分が (3a) を指示したか (3b) を指示したかで決めなければならない**（MUST）。工程名の文字列照合で決めてはならない（MUST NOT）。

#### Scenario: worker.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker.md` の実装以降の節を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) に `openspec validate` があり `/opsx:` が無く、(3a) が CI workflow 定義から検査コマンドを収集して種類ごとに扱う義務と、return に収集した検査コマンド一覧・手元で実行した検査コマンドと exit code（未導入の検査は未導入と明記）・関係するテストを探したコマンド・CI に任せた検査とその CI のジョブ名・`openspec validate --strict` の exit code・`画面確認:` の行を含める義務が書かれ、(3b) に `openspec archive` があり `/opsx:` が無く、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: CI の定義から検査コマンドを収集する指示が全経路共通の節にある
- **WHEN** `references/roles/worker.md` の「全経路共通の大原則」の節を読む
- **THEN** PR・push で起動する `.github/workflows/*.yml` / `*.yaml` の `run:` から検査コマンドを拾うこと（`auto-merge.yml` 等の運用系ワークフローは対象外）、コマンド名をリポジトリ固有の値に固定しないこと、静的検査は手元で実行しテストの全体実行とビルドは手元で実行せず CI に任せること、関係するテストの選び方（足した・変えたテスト、変えたファイルのパスかファイル名を含むテスト、テストランナーの選ぶ機能）、PR・push で全体のテストを回すジョブが無いときは手元で全体を実行し慣例コマンドへのフォールバックが許容されること、ツール未導入は「未導入」として合格と区別することが書かれており、この指示が (3a)「コード直行する場合」手順 5 だけでなく openspec CLI 経路にも及ぶ 1 箇所にまとまっている

#### Scenario: CI が全体のテストを回すリポジトリでは手元で全体を回さない
- **WHEN** PR・push で起動する workflow にテストの全体実行をするジョブがあるリポジトリで、W が (3a) の検査を行う
- **THEN** W はテストランナーをファイルで絞らずに起動せず、関係するテストのファイルをテストランナーに渡して実行し、return にテストの全体実行を CI に任せたこととその CI のジョブ名を書く

#### Scenario: CI が全体のテストを回さないリポジトリでは手元で全体を回す
- **WHEN** PR・push で起動する workflow が無い、またはテストのジョブが無いリポジトリで、W が (3a) の検査を行う
- **THEN** W は手元でテストの全体を実行し（慣例コマンドへのフォールバックを含む）、その exit code を return に書く

#### Scenario: 守備範囲が明記されている
- **WHEN** `references/roles/worker.md` の全経路共通の大原則の節、CI 検査コマンドの収集を指示する段落を読む
- **THEN** 入力の出どころ（PR・push で起動する workflow の `run:` ステップと変えたファイルの一覧）、拾いたい誤り（CI の静的検査の取りこぼし。PR #489 の shellcheck）、間接的に読むテストを拾えないことは CI と CI の見張りが拾う旨、通ってよい入力（`matrix` / `services` / `env` / `if:` 条件による CI と手元の再現差、ランナー依存の検査、環境セットアップの `run:` ステップの誤実行）、取りこぼしを塞ぎ切ることを完了条件にしない旨（最後の防波堤は合格後の CI の見張り）が書かれている

#### Scenario: 旧世代の W が (3) を通しで返してきても (3b) を再指示しない
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** 本体は次に指示する工程を自分が指示した工程で決めると書かれており、工程名の文字列照合では決めないことが書かれている
- **AND** (3a) の return に PR 番号と仕様宣言のコメント URL が揃っているかどうかで (3b) を飛ばす分岐は書かれていない

#### Scenario: worker.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `references/roles/worker.md` のコンテキスト上限と手渡しの節を読む
- **THEN** (3) を (3a)/(3b) より細かく切らないことと、その理由（手渡しごとに払う固定分と、実装の途中で切ると後任が Red のまま止まったテストから再出発すること）が書かれている

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば `opus`。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 `opus`、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 `sonnet` で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 `opus`、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。従来経路では G の `needs-reviewer` が示す推奨 model に従い、adapter 経路では phase `review` の adapter が返した model に残量上限を適用した値を使い、G の推奨 model は参考値として扱わなければならない（MUST）。残量モード（`FABLE_BUDGET_MODE`）は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に従い、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が役割の既定モデルの下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定とし、Fable 残量モードと食い違えば共有枠モードが勝つ（MUST）。この 2 つのモードの効果の本文は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の残量モードと共有枠モードの表 1 か所に置き、SKILL.md の「モデル」節は 2 つのモードの名前（`FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`）と、効果がその表にあることだけを書かなければならない（MUST。値ごとの効果を再掲してはならない。同じ規則を 2 か所に書くと、直すときに片方が漏れて食い違うため）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目にどちらの宣言を置くか・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

この要件の守備範囲で入力として扱うのは、G の起動・再開指示にある `レビュー経路:`、G の `needs-reviewer` が示す推奨 model、phase `review` の adapter が返す model、および `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` から決まる残量上限である。防ぐ誤りは、経路ごとの決定元を取り違えること、adapter が選んだ model を G の推奨 model で上書きすること、残量上限を適用せずに model を採用することである。一方、adapter が `sonnet` を返して G が `opus` を推奨していても、残量上限を適用した adapter の値を採用することは許容する。任意の不正な経路・model・残量モード入力を検出して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet` で上限が `opus`、R1 の既定が `opus`、G の既定が `sonnet`、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由と書かれている
- **AND** `FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` の効果は `references/decision-criteria.md` の表を見るよう書かれており、`abundant`・`reserve`・`exhausted`・`throttled`・`depleted` の値ごとの効果を述べた文は無い

#### Scenario: レビュアーの model 決定元を経路で分ける
- **WHEN** SKILL.md の「G が要求するレビュアー」の行を読む
- **THEN** 従来経路では G の推奨 model に従い、adapter 経路では adapter が返した model に残量上限を適用した値を使って推奨 model は参考値とする、と書かれている

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測ること、G の再開も同じであること、上限超過のあとの扱いは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であることが参照として書かれている
- **AND** そこに手渡しの条件・宣言の選び方・停止確認の手順を言い換えた文は無い
