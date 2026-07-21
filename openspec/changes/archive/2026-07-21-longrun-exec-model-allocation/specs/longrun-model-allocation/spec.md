## MODIFIED Requirements

### Requirement: plan テンプレートはモデル割り当てセクションを含む

`plugins/longrun/templates/plan-template.md` は「モデル割り当て」セクションを含まなければならない (MUST)。セクションは Markdown 表で構成し、ヘッダ行は `| change | ロール | ティア(haiku/sonnet/fable/inherit) | 理由 | 上書き |` の 5 列でなければならない。セクションには、ユーザーが plan 確認時にこの表を直接編集して推奨を上書きできる旨と、`上書き` 欄が非空の場合はティア欄より優先される旨の説明文を含めること。テンプレート本文にモデル ID（`claude-` で始まる具体的なモデル識別子）を記載してはならない (MUST NOT)。

#### Scenario: テンプレートにモデル割り当て表が存在する

- **WHEN** ユーザーが `plugins/longrun/templates/plan-template.md` を開く
- **THEN** 「モデル割り当て」セクションが存在し、`| change | ロール | ティア(haiku/sonnet/fable/inherit) | 理由 | 上書き |` のヘッダ行を持つ Markdown 表が含まれている

#### Scenario: ユーザー編集可能である旨の案内がある

- **WHEN** ユーザーが「モデル割り当て」セクションの説明文を読む
- **THEN** plan 確認時に表を直接編集して上書きできること、および `上書き` 欄がティア欄より優先されることが記載されている

#### Scenario: テンプレートにモデル ID がハードコードされていない

- **WHEN** ユーザーが `plugins/longrun/templates/plan-template.md` 内で `claude-` で始まるモデル ID 文字列を grep する
- **THEN** 該当行は 0 件である（ティア名 haiku / sonnet / fable / inherit のみが現れる）

### Requirement: ティアとモデル ID の対応はリファレンスドキュメント 1 箇所に集約する

longrun プラグインは、ティア（haiku / sonnet / fable / inherit）からモデル指定値への対応表を `plugins/longrun/references/model-tiers.md` の 1 ファイルに集約して定義しなければならない (MUST)。対応表は `haiku`・`sonnet`・`fable` の各ティアについて `opts.model` に渡す値を定義し、`inherit` については「`opts.model` を渡さない（agent 定義 frontmatter の `model:` 指定、それも無ければ親セッションのモデルが適用される）」というセマンティクスを明文化すること。同ファイルには reserve 降格ルール（`FABLE_BUDGET_MODE=reserve` かつ `LONGRUN_AUTOMATED=1` のとき `fable` は `'opus'` に解決される）も記載すること。plan-template.md・SKILL.md・exec の workflow スクリプト生成テンプレートなど他のファイルにモデル ID をハードコードしてはならない (MUST NOT)。

#### Scenario: リファレンスドキュメントが対応を定義している

- **WHEN** ユーザーが `plugins/longrun/references/model-tiers.md` を開く
- **THEN** `haiku`・`sonnet`・`fable` の各ティアに対する `opts.model` 渡し値の対応表と、`inherit` が「`opts.model` を渡さない」ことを意味する旨の説明、および reserve 降格ルールが記載されている

#### Scenario: モデル ID の散在が無い

- **WHEN** ユーザーが `plugins/longrun/` 配下で `references/model-tiers.md` を除外して `claude-` で始まるモデル ID 文字列を grep する
- **THEN** plan-template.md・longrun-plan の SKILL.md・exec.md・workflow スクリプト生成テンプレートのいずれにもヒットしない（0 件）

### Requirement: exec は plan.md のモデル割り当て表を opts.model として消費する

`/longrun:exec`（change-2 の Workflow 生成ロジック）は、workflow スクリプト生成時に plan.md の「モデル割り当て」表を読み取らなければならない (MUST)。各行について、`上書き` 欄が非空ならその値を、空ならティア欄の値を採用し、`plugins/longrun/references/model-tiers.md` の対応表を介して解決した値を該当 change × ロールの agent 呼び出しの `opts.model` に設定すること。`fable` ティアは reserve 降格条件（`FABLE_BUDGET_MODE=reserve` かつ `LONGRUN_AUTOMATED=1`）に該当する場合のみ `'opus'` に解決し、それ以外は `'fable'` に解決すること。ティアが `inherit` の行、および未知のティア値（haiku / sonnet / fable / inherit 以外）の行では `opts.model` キー自体を出力してはならない (MUST NOT)。未知のティア値を検出した場合は inherit として扱った旨の警告をユーザーに表示し、実行は中断しないこと。

#### Scenario: sonnet ティアが opts.model に反映される

- **WHEN** ユーザーが、ある change のロール `verifier` にティア `sonnet`（上書き欄は空）を指定した plan.md に対して `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 verifier agent 呼び出しに、リファレンスドキュメントで解決された sonnet ティアの値が `opts.model` として設定されている

#### Scenario: fable ティアが opts.model に反映される

- **WHEN** ユーザーが、ある change のロール `reviewer` にティア `fable`（上書き欄は空）を指定した plan.md に対して、reserve 降格条件に該当しない環境で `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 reviewer agent 呼び出しに `'fable'` が `opts.model` として設定されている

#### Scenario: inherit ティアでは opts.model を出力しない

- **WHEN** ユーザーが、ある change のロール `builder` にティア `inherit` を指定した plan.md に対して `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 builder agent 呼び出しには `opts.model` キーが存在しない

#### Scenario: 上書き欄がティア欄より優先される

- **WHEN** ユーザーが plan 確認時に、ティア欄 `haiku` の行の `上書き` 欄に `sonnet` を記入してから `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 agent 呼び出しには haiku ではなく sonnet ティアの解決値が `opts.model` として設定されている

#### Scenario: 未知のティア値は inherit として扱い警告する

- **WHEN** ユーザーが、ティア欄に `opus-max` のような未知の値を含む plan.md に対して `/longrun:exec` を実行する
- **THEN** 該当行は inherit として扱われ（`opts.model` 無し）、「未知のティア値のため inherit として扱った」旨の警告が表示され、workflow の起動は中断されない

## ADDED Requirements

### Requirement: reserve モードの自動実行では fable ティアを opus に降格する

`resolve-model-allocation.mjs` は、環境変数 `FABLE_BUDGET_MODE` が `reserve` かつ `LONGRUN_AUTOMATED` が `1` のとき、`fable` ティア（上書き欄経由を含む）を `'opus'` に解決しなければならない (MUST)。降格が発生した場合は、その旨の警告を出力 JSON の `warnings` に含めること。いずれかの環境変数が条件を満たさない場合（interactive セッションを含む）は降格せず `'fable'` に解決すること。降格は実行を中断してはならない (MUST NOT)。haiku / sonnet / inherit の解決は reserve の影響を受けない。

#### Scenario: reserve かつ自動実行では opus に降格する

- **WHEN** `FABLE_BUDGET_MODE=reserve` と `LONGRUN_AUTOMATED=1` が設定された環境で、ロール `reviewer` にティア `fable` を指定した plan.md を resolver で解決する
- **THEN** 該当行の `model` は `opus` になり、降格した旨の警告が `warnings` に含まれ、exit code は 0 である

#### Scenario: interactive では降格しない

- **WHEN** `FABLE_BUDGET_MODE=reserve` だが `LONGRUN_AUTOMATED` が未設定の環境で、同じ plan.md を resolver で解決する
- **THEN** 該当行の `model` は `fable` のままである

#### Scenario: reserve は他ティアに影響しない

- **WHEN** `FABLE_BUDGET_MODE=reserve` と `LONGRUN_AUTOMATED=1` が設定された環境で、sonnet / haiku / inherit の行を含む plan.md を resolver で解決する
- **THEN** sonnet / haiku / inherit の各行の解決値は reserve 無しの場合と同一である
