## ADDED Requirements

### Requirement: develop スキルは入口を問わず発火する
`plugins/dev-workflow/skills/develop/SKILL.md` は、ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業を、依頼の入口（GitHub issue・会話・cron・エピックの子）を問わずこのスキルを通すことを「いつ使うか」として規定しなければならない（MUST）。例外は「読むだけ・回答だけ・生成物を出すだけ」の作業に限る（SHALL）。frontmatter の `description` は、旧 `github-issue` の発火語（issue 番号・issue URL・「この issue 対応して」等の自然文）を含まなければならない（MUST）。`skills/github-issue/` は存在してはならない（MUST NOT）。

#### Scenario: いつ使うかと例外が書かれている
- **WHEN** `skills/develop/SKILL.md` の「いつ使うか」節を読む
- **THEN** コード・スキル・コマンド・規範文書を変える作業は入口を問わず通すこと、例外が「読むだけ・回答だけ・生成物を出すだけ」であることが書かれている

#### Scenario: 旧 github-issue の発火語を吸収している
- **WHEN** `skills/develop/SKILL.md` の frontmatter `description` を読む
- **THEN** issue 番号・URL・「この issue 対応して」の発火語が含まれ、`skills/github-issue/SKILL.md` は存在しない

### Requirement: 本体はオーケストレータ専任でコードもレビューも書かない
SKILL.md は本体（メインセッション）の役割を「役割 W / R1 / G を `model` 明示で spawn し、return の要約と記録先（issue または Draft PR）のコメント・ラベルだけを見て次に誰を起こすかを決める」と規定しなければならない（MUST）。禁止事項として、本体が Edit でコードを書かないこと、本体がレビュー（仕様レビュー・PR レビュー）を代行しないことを明記しなければならない（MUST）。並列可能な役割は並列に起こしてよい（MAY）。W は名前付きで spawn し、再開は SendMessage でコンテキストを引き継ぐ（SHALL）。別コンテキストを要する工程はすべて本体が起こし、W が孫を呼ぶ必要がある工程を設けてはならない（MUST NOT）。

#### Scenario: 禁止事項が明記されている
- **WHEN** SKILL.md の「本体の役割」節を読む
- **THEN** 本体が Edit でコードを書かないこと、レビューを代行しないこと、役割を `model` 明示で spawn することが書かれている

#### Scenario: W の再開は SendMessage
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** W を名前付きで spawn し SendMessage で再開すること、W が孫を呼ぶ工程が無いことが書かれている

### Requirement: 入口 0 は記録先を決める
SKILL.md は 1 ループの最初の工程「入口 0」として記録先の決め方を規定しなければならない（MUST）: issue があれば（番号・URL・自然文マッチ）それを記録先にする。無ければ issue を切らず、worktree を切って最初の commit を積んだ時点で Draft PR を開き、それを記録先にする。Draft PR を記録先にする場合、受け入れ条件は PR 本文（位置づけ・動作確認ポイント）に書かなければならず（MUST）、受け入れ条件自体を省いてはならない（MUST NOT）。仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）・仕様宣言は記録先のコメントに置く（SHALL）。issue を切るのは追跡・キュー・議論が要るとき（エピック／無人キュー／判断を残す議論）に限ることを明記する（SHALL）。

#### Scenario: issue が無い依頼は Draft PR が記録先になる
- **WHEN** 会話で依頼された変更に対応する issue が無い
- **THEN** SKILL.md は issue を切らず、最初の commit の時点で Draft PR を開いて記録先にし、受け入れ条件を PR 本文に書くよう指示している

#### Scenario: issue を切る条件が限定されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** issue を切る条件がエピック・無人キュー・判断を残す議論の 3 つに限定されている

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 → (1) W が worktree・仕様化判断の記録・分割判定・`/opsx:ff` まで行い return（仕様化しない判定なら (3) へ直行）→ (2) R1 が別コンテキストで仕様レビューし結果を記録先にコメントして return。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（2 周キャップ。超えたら `needs-approval`）→ (3) W を再開して apply（TDD）・verify・archive・PR を Ready に（または作成）・仕様宣言まで書いて return → (4) G が pr-review-gate の手順 1〜5 を実行し passed / failed / 保留を return。failed なら W を再開（実装品質起因は fable）し G を再開して差分再レビュー（2 周）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ 2 周キャップがある

#### Scenario: G の failed は W の再開に戻る
- **WHEN** G が failed を return する
- **THEN** SKILL.md は W を再開（実装品質起因なら fable）して修正させ、G を再開して差分再レビューするよう指示している

### Requirement: 役割の指示書は references/roles/ に分かれている
`skills/develop/references/roles/` に `worker.md`（W）・`spec-reviewer.md`（R1）・`gate-runner.md`（G）が存在しなければならない（MUST）。`worker.md` は仕様化判断の記録書式（1 行目 `^仕様化判断: (する|しない)$`）・仕様レビュー結果の記録書式・「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務）を含み（MUST）、この表がモデル事前分類の正本である（SHALL）。`spec-reviewer.md` は 5 観点（受け入れ条件の一意性・既存 spec との整合・固有値の直書き・前提の明記・相互整合）と 2 周キャップを含む（MUST）。`gate-runner.md` は pr-review-gate スキルを読んで手順 1〜5 を実行する指示と、G が孫を持てないための別コンテキストレビューの扱い（Codex は Bash 経由で G の中から呼ぶ。Codex が使えない／light 判定のときは G が `needs-reviewer` を return し、本体が別のレビュアーを spawn してその要約を G に SendMessage で渡す）を含む（MUST）。

#### Scenario: worker.md に記録書式と事前分類表がある
- **WHEN** `references/roles/worker.md` を読む
- **THEN** `^仕様化判断: (する|しない)$` の書式、`gh` で記録先にコメントする手順、4 分類の事前分類表が書かれている

#### Scenario: spec-reviewer.md に 5 観点と 2 周キャップがある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** 5 観点がすべて列挙され、2 周で確定し 3 周目の例外を設けないことが書かれている

#### Scenario: gate-runner.md は pr-review-gate を手順書として参照する
- **WHEN** `references/roles/gate-runner.md` を読む
- **THEN** pr-review-gate スキルを読んで手順 1〜5 を実行すること、Codex が使えないときは `needs-reviewer` を return して本体にレビュアーの spawn を委ねることが書かれている

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `opus`、`worker.md` の「重要実装の事前分類」表に当たれば `fable`。R1 / G は既定 `opus`、仕様やゲートがマージ条件・聖域・層間契約に触れれば `fable`。残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md` の表に従い、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した → 1 段昇格）は W の再開時のモデル選択として残す（SHALL）。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W / R1 / G の既定が `opus`、事前分類・マージ条件・聖域・層間契約で `fable`、`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限、と書かれている

#### Scenario: 実行戦略の 3 分岐が消えている
- **WHEN** `skills/develop/` 配下の全ファイルを grep する
- **THEN** 「delegate+verify」「workflow 型」の戦略分岐と、`gh issue view ... | length` 等の決定論的シグナル収集コマンドが存在しない

### Requirement: エピックの条件・作り方・回し方・完了条件を規定する
SKILL.md は次を規定しなければならない（MUST）。**条件**（いずれか）: 1 つのユーザーストーリーの原因が複数あり独立してマージできる PR が 2 本以上に割れる／複数の capability（openspec の spec）にまたがる／子の間に順序依存があり 1 サイクルで終わらない。**作り方**: エピック issue にユーザーストーリー・完了条件・子 issue の一覧と依存順を書き、エピック自身にコードを紐づけない（PR の `Closes` は子に向ける）。子 issue はそれ単体で実装可能な記述と測定可能な受け入れ条件を持ち、依存は `gh api .../dependencies/blocked_by` で張る。洗い出しと解決はセッションを分け、解決セッションの入口は `/develop <エピック番号>`。**回し方**: 本体は子の依存グラフを読み、blocked されていない子から 1 ループを子ごとに並列で起こす（worktree は子ごと、`isolation: "worktree"`）。子の PR がマージされたらエピックに 1 行コメントし、依存が解けた子を次に起こす。スタック PR は避け、やむを得ない場合は先行マージ後に base を本体が張り替える。子の実装中に見つかった新しい問題は新しい子 issue として追加する。**完了条件**: 全子 PR がマージされ、かつ本体（または G）がエピックの完了条件を実機で確認して証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない（MUST NOT）。

#### Scenario: エピックの 4 節が存在する
- **WHEN** SKILL.md の「エピックの扱い」節を読む
- **THEN** 条件・作り方・回し方・完了条件の 4 つが揃い、完了条件に「子が全部マージされただけでは閉じない」が書かれている

#### Scenario: 子は並列に worktree 分離で起こす
- **WHEN** エピックの回し方を読む
- **THEN** blocked されていない子から `isolation: "worktree"` で 1 ループを並列に起こすこと、新しい問題は子の中で直さず新しい子 issue にすることが書かれている

### Requirement: /develop コマンドと /work-issue エイリアス
`plugins/dev-workflow/commands/develop.md` が存在し、`skills/develop/SKILL.md` を path-discovery で特定して Read し interactive モードでインライン実行する薄いラッパーでなければならない（MUST）。`commands/work-issue.md` は `/develop` のエイリアスとして残し、同じ引数を develop の手順に渡す（MUST）。plugin.json の `skills` に `./skills/develop`、`commands` に `./commands/develop.md` と `./commands/work-issue.md` が登録されている（MUST）。

#### Scenario: /work-issue が /develop として動く
- **WHEN** `/work-issue 42` を起動する
- **THEN** `commands/work-issue.md` は develop の手順に `42` を渡す旨だけを書いており、独自の手順を持たない

#### Scenario: plugin.json の登録
- **WHEN** `.claude-plugin/plugin.json` を読む
- **THEN** `skills` に `./skills/develop` があり `./skills/github-issue` が無く、`commands` に `./commands/develop.md` と `./commands/work-issue.md` がある
