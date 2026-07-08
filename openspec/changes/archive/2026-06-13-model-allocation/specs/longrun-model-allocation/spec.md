# longrun-model-allocation Specification (Delta)

## ADDED Requirements

### Requirement: plan テンプレートはモデル割り当てセクションを含む

`plugins/longrun/templates/plan-template.md` は「モデル割り当て」セクションを含まなければならない (MUST)。セクションは Markdown 表で構成し、ヘッダ行は `| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |` の 5 列でなければならない。セクションには、ユーザーが plan 確認時にこの表を直接編集して推奨を上書きできる旨と、`上書き` 欄が非空の場合はティア欄より優先される旨の説明文を含めること。テンプレート本文にモデル ID（`claude-` で始まる具体的なモデル識別子）を記載してはならない (MUST NOT)。

#### Scenario: テンプレートにモデル割り当て表が存在する

- **WHEN** ユーザーが `plugins/longrun/templates/plan-template.md` を開く
- **THEN** 「モデル割り当て」セクションが存在し、`| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |` のヘッダ行を持つ Markdown 表が含まれている

#### Scenario: ユーザー編集可能である旨の案内がある

- **WHEN** ユーザーが「モデル割り当て」セクションの説明文を読む
- **THEN** plan 確認時に表を直接編集して上書きできること、および `上書き` 欄がティア欄より優先されることが記載されている

#### Scenario: テンプレートにモデル ID がハードコードされていない

- **WHEN** ユーザーが `plugins/longrun/templates/plan-template.md` 内で `claude-` で始まるモデル ID 文字列を grep する
- **THEN** 該当行は 0 件である（ティア名 haiku / sonnet / inherit のみが現れる）

### Requirement: ティアとモデル ID の対応はリファレンスドキュメント 1 箇所に集約する

longrun プラグインは、ティア（haiku / sonnet / inherit）からモデル指定値への対応表を `plugins/longrun/references/model-tiers.md` の 1 ファイルに集約して定義しなければならない (MUST)。対応表は `haiku` と `sonnet` の各ティアについて `opts.model` に渡す値を定義し、`inherit` については「`opts.model` を渡さない（agent 定義 frontmatter の `model:` 指定、それも無ければ親セッションのモデルが適用される）」というセマンティクスを明文化すること。plan-template.md・SKILL.md・exec の workflow スクリプト生成テンプレートなど他のファイルにモデル ID をハードコードしてはならない (MUST NOT)。

#### Scenario: リファレンスドキュメントが対応を定義している

- **WHEN** ユーザーが `plugins/longrun/references/model-tiers.md` を開く
- **THEN** `haiku` と `sonnet` の各ティアに対する `opts.model` 渡し値の対応表と、`inherit` が「`opts.model` を渡さない」ことを意味する旨の説明が記載されている

#### Scenario: モデル ID の散在が無い

- **WHEN** ユーザーが `plugins/longrun/` 配下で `references/model-tiers.md` を除外して `claude-` で始まるモデル ID 文字列を grep する
- **THEN** plan-template.md・longrun-plan の SKILL.md・exec.md・workflow スクリプト生成テンプレートのいずれにもヒットしない（0 件）

### Requirement: exec は plan.md のモデル割り当て表を opts.model として消費する

`/longrun:exec`（change-2 の Workflow 生成ロジック）は、workflow スクリプト生成時に plan.md の「モデル割り当て」表を読み取らなければならない (MUST)。各行について、`上書き` 欄が非空ならその値を、空ならティア欄の値を採用し、`plugins/longrun/references/model-tiers.md` の対応表を介して解決した値を該当 change × ロールの agent 呼び出しの `opts.model` に設定すること。ティアが `inherit` の行、および未知のティア値（haiku / sonnet / inherit 以外）の行では `opts.model` キー自体を出力してはならない (MUST NOT)。未知のティア値を検出した場合は inherit として扱った旨の警告をユーザーに表示し、実行は中断しないこと。

#### Scenario: sonnet ティアが opts.model に反映される

- **WHEN** ユーザーが、ある change のロール `verifier` にティア `sonnet`（上書き欄は空）を指定した plan.md に対して `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 verifier agent 呼び出しに、リファレンスドキュメントで解決された sonnet ティアの値が `opts.model` として設定されている

#### Scenario: inherit ティアでは opts.model を出力しない

- **WHEN** ユーザーが、ある change のロール `builder` にティア `inherit` を指定した plan.md に対して `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 builder agent 呼び出しには `opts.model` キーが存在しない

#### Scenario: 上書き欄がティア欄より優先される

- **WHEN** ユーザーが plan 確認時に、ティア欄 `haiku` の行の `上書き` 欄に `sonnet` を記入してから `/longrun:exec` を実行する
- **THEN** 生成された workflow スクリプトの該当 agent 呼び出しには haiku ではなく sonnet ティアの解決値が `opts.model` として設定されている

#### Scenario: 未知のティア値は inherit として扱い警告する

- **WHEN** ユーザーが、ティア欄に `opus-max` のような未知の値を含む plan.md に対して `/longrun:exec` を実行する
- **THEN** 該当行は inherit として扱われ（`opts.model` 無し）、「未知のティア値のため inherit として扱った」旨の警告が表示され、workflow の起動は中断されない

### Requirement: モデル割り当てセクションが無い旧 plan.md では全 inherit にフォールバックする

`/longrun:exec` は、plan.md に「モデル割り当て」セクションが存在しない場合でもエラーにせず動作しなければならない (MUST)。この場合、全 change × 全ロールを `inherit` として扱い、生成する workflow スクリプトのいかなる agent 呼び出しにも `opts.model` を設定しないこと。フォールバックの発動についてユーザーへの追加質問（AskUserQuestion）を行ってはならない (MUST NOT)。

#### Scenario: セクション無し plan.md で exec が完走する

- **WHEN** ユーザーが「モデル割り当て」セクションを持たない旧形式の plan.md に対して `/longrun:exec` を実行する
- **THEN** エラーや追加質問なしで workflow スクリプトが生成・起動され、スクリプト内のすべての agent 呼び出しに `opts.model` キーが存在しない
