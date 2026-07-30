# loops-pre-push-guard Specification

## Purpose
`loops-dev-agent-install` が対象リポジトリに設置する `.githooks/pre-push` の拒否条件を定める。main/master への直接 push に加え、**マージ済み PR のブランチ（open な PR が無いブランチ）への push** を push の瞬間に止めることで、行き場のないコミットが積み上がる事故を防ぐ。同時に、ガードが日常の push を止めて `--no-verify` の常用を招かないよう、fail-open 方針と明示バイパス手段を規定する。
## Requirements
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

さらにテンプレートは、`gh` が応答しない場合に**有限時間で諦めて push を通さなければならない** (MUST)。タイムアウトは 3 秒とし、実装はバックグラウンド実行とポーリングによって行い、`timeout` / `gtimeout` などの外部コマンドに依存してはならない (MUST NOT)。`gh` は `</dev/null` を付けて起動し、フック本体が読む stdin を子プロセスに渡してはならない (MUST NOT)。

#### Scenario: gh が失敗しても push が通る

- **WHEN** `gh pr list` が非 0 で終了する、または出力が空である
- **THEN** フックは push を拒否せず、そのまま処理を継続する

#### Scenario: fail-open 方針が明記されている

- **WHEN** SKILL.md Step 6 のフックテンプレートおよび説明文を読む
- **THEN** gh 失敗時に push を通す（fail-open）ことが明記されている

#### Scenario: gh が応答しないときタイムアウトして push が通る

- **WHEN** `gh` が応答を返さない（ハングする）状態で push する
- **THEN** フックは 3 秒程度で諦め、exit 0 で push を通す

#### Scenario: timeout コマンドに依存していない

- **WHEN** フックテンプレートの本文を読む
- **THEN** `timeout` / `gtimeout` の呼び出しが含まれていない

#### Scenario: gh に stdin を渡していない

- **WHEN** フックテンプレートの `gh` 呼び出しを読む
- **THEN** `</dev/null` が付いている

### Requirement: ブランチ削除 push の許可

テンプレートは、ブランチ削除 push（`local_sha` が全ゼロ）に対してマージ済みチェックを適用してはならない (MUST NOT)。該当 ref は `continue` でスキップする。

#### Scenario: ブランチ削除 push が許可される

- **WHEN** `git push origin --delete <branch>` 相当の push（local_sha が `0000000000000000000000000000000000000000`）が行われる
- **THEN** フックはマージ済みチェックを行わず push を通す

### Requirement: 環境変数による明示バイパス

テンプレートは、環境変数 `PREPUSH_ALLOW_MERGED=1` が設定されている場合にマージ済みチェックをスキップしなければならない (MUST)。拒否メッセージには、このバイパス方法を利用者が実行できる形（コマンド例）で案内しなければならない (MUST)。バイパスは main/master 直 push 拒否には影響してはならない (MUST NOT)。

#### Scenario: バイパス環境変数でマージ済みチェックが無効化される

- **WHEN** `PREPUSH_ALLOW_MERGED=1 git push` を実行する
- **THEN** マージ済み PR のブランチであってもフックは push を通す

#### Scenario: 拒否メッセージにバイパス方法が含まれる

- **WHEN** マージ済みチェックで push が拒否される
- **THEN** stderr のメッセージに `PREPUSH_ALLOW_MERGED=1` を用いたバイパスコマンド例が含まれる

#### Scenario: バイパスしても main 直 push は拒否される

- **WHEN** `PREPUSH_ALLOW_MERGED=1` を設定して `refs/heads/main` へ push する
- **THEN** フックは main 直 push 拒否により exit 1 で拒否する

### Requirement: 導入済みリポジトリへの再適用手順

SKILL.md は、既に loop-dev-agent を導入済みのリポジトリへフック更新を反映するための再適用手順を記述しなければならない (MUST)。手順は Step 6 の再実行（`.githooks/pre-push` の上書き・`chmod +x`・`core.hooksPath` の確認）と、反映されたことの確認方法を含む。

#### Scenario: 再適用手順が記述されている

- **WHEN** SKILL.md の再導入・再適用に関する記述を読む
- **THEN** 導入済み repo で Step 6 のみを再実行してフックを更新する手順が示されている

### Requirement: レシピ本文へのガード説明の反映

`plugins/loops/recipes/loop-dev-agent.md` のガード説明は、pre-push フックが main 直 push に加えてマージ済み PR ブランチへの push も拒否することに言及しなければならない (MUST)。

#### Scenario: レシピがマージ済み PR チェックに言及している

- **WHEN** `plugins/loops/recipes/loop-dev-agent.md` の pre-push フックに関する記述を読む
- **THEN** マージ済み PR ブランチへの push 拒否に言及がある

### Requirement: プラグインバージョンの更新

`plugins/loops/.claude-plugin/plugin.json` の `version` は、本変更に伴い更新前より大きい値へ上げなければならない (MUST)。`~/.claude/plugins/cache/` がバージョン単位キャッシュのため、据え置きでは他プロジェクトに反映されない。

#### Scenario: バージョンが上がっている

- **WHEN** `plugins/loops/.claude-plugin/plugin.json` の `version` を変更前後で比較する
- **THEN** 変更後の値が変更前より大きい

