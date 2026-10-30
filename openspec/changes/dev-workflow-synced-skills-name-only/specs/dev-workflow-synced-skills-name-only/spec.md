## ADDED Requirements

### Requirement: 同期スキルの名前は skills/synced 配下のディレクトリ名から取り、anthropic-skills: を付ける
`plugins/dev-workflow/scripts/synced-skills-name-only.sh` は、設定ディレクトリ（環境変数 `CLAUDE_CONFIG_DIR`、未設定なら `$HOME/.claude`）の `skills/synced/<バケット>/<名>/SKILL.md` が存在する `<名>` を同期スキルとして列挙し、`skillOverrides` のキーを `anthropic-skills:<名>` としなければならない（MUST）。名前が `.` で始まるディレクトリ（`.bucket-*` など）は、バケットとしても `<名>` としても数えてはならない（MUST NOT）。バケットが複数あるときは全バケットの和集合を取る（MUST）。

#### Scenario: 同期スキルをキーとして列挙する
- **WHEN** 一時ディレクトリの設定ディレクトリに `skills/synced/org_acct/pdf/SKILL.md` と `skills/synced/org_acct/docs/SKILL.md`、`skills/synced/.bucket-org_acct`、`skills/synced/org_acct/.last-complete-round` を置いて `--dry-run` で実行する
- **THEN** 足す候補は `anthropic-skills:pdf` と `anthropic-skills:docs` の 2 つだけ

### Requirement: skillOverrides には name-only で足し、既存のキーの値と他の設定を変えない
スクリプトは `settings.json` の `skillOverrides` に、まだ無いキーだけを値 `name-only` で足さなければならない（MUST）。同じキーが既にあれば、値が何であっても変えてはならない（MUST NOT）。`skillOverrides` 以外のトップレベルのキーと、既存の `skillOverrides` のキーは、そのまま残さなければならない（MUST）。

#### Scenario: 既存の値を上書きしない
- **WHEN** `settings.json` が `{"model":"opus","skillOverrides":{"anthropic-skills:pdf":"off","mine":"on"}}` で、同期スキルが pdf と docs の場合に適用する
- **THEN** `skillOverrides` は `anthropic-skills:pdf` が `off` のまま、`mine` が `on` のまま、`anthropic-skills:docs` が `name-only` で加わり、`model` は `opus` のまま

#### Scenario: skillOverrides が無い設定にも足せる
- **WHEN** `settings.json` が `{"model":"opus"}` の場合に適用する
- **THEN** `skillOverrides` が同期スキルの数だけの `name-only` で作られ、`model` は `opus` のまま

### Requirement: 足すものが無いとき、同期スキルが無いとき、dry-run のときは書かない
足すキーが 0 本のとき（同期スキルが無い、または全部が `skillOverrides` に既にある）、および `--dry-run` のとき、スクリプトは `settings.json` を変更してはならず（MUST NOT）、バックアップも作ってはならない（MUST NOT）。同期スキルが無いときは、同期スキルが無い旨を標準出力に出して exit 0 で終わらなければならない（MUST）。足すときは書き込みの前に `settings.json.bak-<日時>` を作り（MUST）、同じディレクトリの一時ファイルに書いてから置き換えなければならない（MUST）。適用の出力には足したキーを 1 行 1 件で列挙しなければならない（MUST）。

#### Scenario: 同期スキルが無い環境
- **WHEN** `skills/synced` が無い設定ディレクトリで適用する
- **THEN** 出力に同期スキルが無い旨があり、`settings.json` は変わらず、バックアップは作られず、終了コードは 0

#### Scenario: 2 回目の実行は何も書き換えない
- **WHEN** 適用した直後にもう一度適用する
- **THEN** `settings.json` の内容と更新時刻は 1 回目の直後のまま、バックアップは増えない

#### Scenario: 増えた分だけを足す
- **WHEN** 適用したあとに同期スキルが 1 本増えて、もう一度適用する
- **THEN** 足されるのは増えた 1 本だけで、すでに入っていたキーの値は変わらない

#### Scenario: dry-run は書かずに候補を見せる
- **WHEN** `--dry-run` で実行する
- **THEN** 足すキーが出力に出て、`settings.json` は変わらず、バックアップは作られない

### Requirement: 読めない設定は書かずに失敗する
`settings.json` が JSON として読めないとき、または `skillOverrides` がオブジェクトでないときは、スクリプトは何も書かずに非 0 で終わり、理由を標準エラーに出さなければならない（MUST）。`settings.json` が存在しないときは、`{}` を元にして作らなければならない（MUST。足すキーがあるときだけ）。

#### Scenario: 壊れた settings.json
- **WHEN** `settings.json` の中身が JSON でない状態で適用する
- **THEN** 終了コードは非 0 で、`settings.json` の内容は変わらず、バックアップは作られない

### Requirement: 設定コマンドは内容を見せて確認を取ってから書き、戻し方を案内する
`plugins/dev-workflow/commands/synced-skills-slim.md` は、まず `--dry-run` の結果を利用者に見せ、足すキーがあるときは利用者の確認を得てから `--dry-run` なしで実行しなければならない（MUST）。利用者が断ったときは、`settings.json` を変更してはならない（MUST NOT）。コマンドの案内には、元に戻す手順（バックアップのファイルを戻す方法、または足したキーだけを `jq` で消す方法）と、`name-only` は名前を指定した呼び出しは動くが名前を指定しない依頼での自動選択は比較していないこと、実測した Claude Code の版を書かなければならない（MUST）。`SessionStart` などの hook から確認なしにこのスクリプトを呼んではならない（MUST NOT）。

#### Scenario: 案内に戻し方がある
- **WHEN** コマンドのファイルを読む
- **THEN** `settings.json.bak-` を戻す手順と `del(.skillOverrides` を使う手順の両方が書かれている

#### Scenario: hook からは呼ばれない
- **WHEN** `plugins/dev-workflow/hooks/` を調べる
- **THEN** `synced-skills-name-only.sh` を呼ぶ記述が無い
