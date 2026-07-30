## MODIFIED Requirements

### Requirement: マージ済み PR ブランチへの push 拒否

`plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 6 の `.githooks/pre-push` テンプレートは、push 先ブランチに **merged 状態の PR が 1 件以上存在し、かつ open 状態の PR が 1 件も存在しない**場合に、exit code 1 で push を拒否しなければならない (MUST)。判定は `gh pr list --head <branch> --state all --json state` の **1 回の呼び出し**で取得した状態一覧から merged / open の件数を数えて行わなければならない (MUST)。`--state merged` と `--state open` を別々に呼ぶ 2 回呼び出しを残してはならない (MUST NOT)。既存の main/master 直 push 拒否は維持しなければならない (MUST)。

#### Scenario: マージ済み PR のブランチへの push が拒否される

- **WHEN** merged PR が 1 件あり open PR が 0 件のブランチへ push する
- **THEN** フックが exit 1 を返して push を中断し、新しいブランチを切るよう促すメッセージを stderr に出す

#### Scenario: 初回 push（PR 未作成）は通る

- **WHEN** そのブランチに PR が 1 件も存在しない（merged 件数が 0）状態で push する
- **THEN** フックはマージ済みチェックで拒否せず push を通す

#### Scenario: 同名ブランチで PR を開き直した場合は通る

- **WHEN** merged PR が 1 件以上あり、かつ open PR も 1 件以上存在するブランチへ push する
- **THEN** フックは push を通す

#### Scenario: main/master 直 push 拒否が維持されている

- **WHEN** `refs/heads/main` または `refs/heads/master` を remote_ref とする push を行う
- **THEN** フックは従来どおり exit 1 で拒否する

#### Scenario: gh の呼び出しが 1 push あたり 1 回に収まっている

- **WHEN** 1 つの ref を push してフック内の `gh` 呼び出し回数を数える
- **THEN** 呼び出しは 1 回だけである

### Requirement: gh 失敗時の fail-open

テンプレートは、`gh` コマンドが失敗した場合（未インストール・未認証・オフライン・非 GitHub remote 等）に push を拒否してはならない (MUST NOT)。判定値が取得できないときは当該 ref のチェックをスキップして push を通す fail-open 方針であることを、テンプレート内のコメントまたは SKILL.md 本文に明記しなければならない (MUST)。

さらにテンプレートは、`gh` が応答しない場合に**有限時間で諦めて push を通さなければならない** (MUST)。タイムアウトは 3 秒とし、`timeout` または `gtimeout` が PATH にあればそれを使い、無い場合はバックグラウンド実行とポーリングによるフォールバックで同じ上限を実現しなければならない (MUST)。

#### Scenario: gh が失敗しても push が通る

- **WHEN** `gh pr list` が非 0 で終了する、または出力が空である
- **THEN** フックは push を拒否せず、そのまま処理を継続する

#### Scenario: fail-open 方針が明記されている

- **WHEN** SKILL.md Step 6 のフックテンプレートおよび説明文を読む
- **THEN** gh 失敗時に push を通す（fail-open）ことが明記されている

#### Scenario: gh が応答しないときタイムアウトして push が通る

- **WHEN** `gh` が応答を返さない（ハングする）状態で push する
- **THEN** フックは 3 秒程度で諦め、exit 0 で push を通す

#### Scenario: timeout コマンドが無い環境でもタイムアウトが効く

- **WHEN** `timeout` も `gtimeout` も PATH に無い環境で、応答しない `gh` に対して push する
- **THEN** フォールバック経路が働き、フックは有限時間で exit 0 を返す
