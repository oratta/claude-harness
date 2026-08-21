# loops-marketplace-sync Specification

## Purpose
TBD - created by archiving change loops-integration. Update Purpose after archive.
## Requirements

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

### Requirement: marketplace.json はトップレベル version を持たず JSON 構文が正しい

`.claude-plugin/marketplace.json` はトップレベルの `version` フィールドを持ってはならない (MUST NOT)。また、marketplace.json および全プラグインの plugin.json は JSON として構文的に正しくなければならない (MUST)。トップレベル version は全プラグイン共通の単一行で、プラグインを変更するすべての PR を互いに衝突させるため廃止した（oratta/claude-harness#140）。バージョンの正本は各 `plugin.json` と marketplace.json の対応エントリの 2 点同期で、プラグインキャッシュ（`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`）もプラグイン単位の version をキーにする。

#### Scenario: トップレベル version が存在しない

- **WHEN** ユーザーが `jq 'has("version")' .claude-plugin/marketplace.json` を実行する
- **THEN** 出力は `false` である

#### Scenario: 全 JSON ファイルが parse できる

- **WHEN** ユーザーが `jq . .claude-plugin/marketplace.json` と、全プラグインの `jq . plugins/*/.claude-plugin/plugin.json` を実行する
- **THEN** 全ファイルが exit 0 で parse に成功する
