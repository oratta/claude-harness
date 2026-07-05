# loops-marketplace-sync Specification (Delta)

## ADDED Requirements

### Requirement: loops プラグインが marketplace.json に登録されている

`.claude-plugin/marketplace.json` の `plugins[]` 配列は、新プラグイン `loops` のエントリを含まなければならない (MUST)。エントリは `name: "loops"`、`source: "./plugins/loops"`、`description`、`version` を持ち、`version` は `plugins/loops/.claude-plugin/plugin.json` の `version` と文字列完全一致でなければならない (MUST)。

#### Scenario: loops エントリが存在する

- **WHEN** ユーザーが `jq '.plugins[] | select(.name == "loops")' .claude-plugin/marketplace.json` を実行する
- **THEN** `source` が `./plugins/loops` であるエントリが 1 件返り、`description` と `version` が非空である

#### Scenario: loops の version が plugin.json と一致する

- **WHEN** ユーザーが `jq -r '.plugins[] | select(.name == "loops") | .version' .claude-plugin/marketplace.json` と `jq -r '.version' plugins/loops/.claude-plugin/plugin.json` の出力を比較する
- **THEN** 両者は文字列として完全一致する

#### Scenario: インストールコマンドで新プラグインが見える

- **WHEN** マージ後の新セッションでユーザーが `/plugin install loops@oratta-claude-harness` → `/reload-plugins` を実行する
- **THEN** `/loops:design`・`/loops:goalify` がスラッシュコマンド一覧に現れる

### Requirement: 編集済み全プラグインの version が bump され marketplace.json と完全一致する

本 run（change-1〜4）でファイルを変更した全プラグインについて、`plugins/<name>/.claude-plugin/plugin.json` の `version` を main の HEAD 時点より上げなければならない (MUST)。かつ、marketplace.json の `plugins[]` 内の対応エントリの `version` は各 plugin.json の `version` と文字列完全一致でなければならない (MUST)。変更していないプラグインの version を bump してはならない (MUST NOT)。

#### Scenario: 全プラグインで plugin.json と marketplace.json の version が一致する

- **WHEN** ユーザーが marketplace.json の `plugins[]` 全エントリについて、`jq -r .version plugins/<name>/.claude-plugin/plugin.json` と marketplace.json 側の `version` を突き合わせるループを実行する
- **THEN** 全エントリで両者が完全一致し、不一致は 0 件である

#### Scenario: 編集済みプラグインの version が bump されている

- **WHEN** ユーザーが `git diff origin/main --name-only` で変更されたプラグインを特定し、各プラグインの plugin.json の `version` を `git show origin/main:plugins/<name>/.claude-plugin/plugin.json` の `version` と比較する
- **THEN** 変更された全プラグインで version が main 時点より上がっている

### Requirement: marketplace.json top-level version が bump され JSON 構文が正しい

プラグイン構成の変更（loops 追加・各プラグイン version 更新）に伴い、`.claude-plugin/marketplace.json` の top-level `version` を bump しなければならない (MUST)。また、変更後の marketplace.json および全プラグインの plugin.json は JSON として構文的に正しくなければならない (MUST)。

#### Scenario: top-level version が上がっている

- **WHEN** ユーザーが `jq -r .version .claude-plugin/marketplace.json` の出力を `git show origin/main:.claude-plugin/marketplace.json | jq -r .version` と比較する
- **THEN** top-level version が main 時点より上がっている

#### Scenario: 全 JSON ファイルが parse できる

- **WHEN** ユーザーが `jq . .claude-plugin/marketplace.json` と、全プラグインの `jq . plugins/*/.claude-plugin/plugin.json` を実行する
- **THEN** 全ファイルが exit 0 で parse に成功する
