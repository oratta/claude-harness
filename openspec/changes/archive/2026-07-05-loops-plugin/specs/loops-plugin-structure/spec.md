# loops-plugin-structure Specification (Delta)

## ADDED Requirements

### Requirement: loops プラグインのディレクトリ構成と plugin.json

`plugins/loops/` は新規プラグインとして以下を含まなければならない (MUST): `.claude-plugin/plugin.json`（JSON parse が通り、`name` が `loops`、`version` が semver 形式）、`skills/loops-design/SKILL.md`、`skills/loops-goalify/SKILL.md`、`references/loop-types.md`、`references/recipe-format.md`、`templates/recipe-template.md`、`templates/state-template.md`。

#### Scenario: plugin.json が妥当な JSON である

- **WHEN** `plugins/loops/.claude-plugin/plugin.json` を JSON としてパースする（例: `jq . plugins/loops/.claude-plugin/plugin.json`）
- **THEN** exit 0 でパースが成功し、`name` フィールドが `loops`、`version` フィールドが semver 形式（`X.Y.Z`）である

#### Scenario: 必須ファイル一式が存在する

- **WHEN** `plugins/loops/` 配下のファイル存在を確認する
- **THEN** `skills/loops-design/SKILL.md`・`skills/loops-goalify/SKILL.md`・`references/loop-types.md`・`references/recipe-format.md`・`templates/recipe-template.md`・`templates/state-template.md` がすべて存在する

### Requirement: 独自ループランタイムを含まない

`plugins/loops/` は独自のループ実行系を含んではならない (MUST NOT)。具体的には、ループを回す常駐スクリプト・カスタム driver スクリプト（例: `build-loop.sh` 相当）・ループ定義の宣言的 schema（例: `loop-definition.schema.json` 相当）を配置しないこと。プラグインが配布するのは Markdown（SKILL.md / references / templates）とテスト（*.bats）のみとし、反復・スケジュール・停止判定はネイティブプリミティブ（/goal の最大試行・/loop・/schedule のキャンセル・Workflow の budget）に委ねる。

#### Scenario: 実行スクリプトが存在しない

- **WHEN** `plugins/loops/` 配下で `*.bats` を除く実行可能スクリプト（`*.sh`・`*.js`・`*.py` 等）を検索する（例: `find plugins/loops -type f \( -name '*.sh' -o -name '*.js' -o -name '*.py' \) ! -name '*.bats'`）
- **THEN** 該当ファイルは 0 件である

#### Scenario: ループ定義 schema が存在しない

- **WHEN** `plugins/loops/` 配下で `*.schema.json` を検索する
- **THEN** 該当ファイルは 0 件である

### Requirement: モデル ID を直書きしない

`plugins/loops/` 配下のいかなるファイルにも、`claude-` で始まる具体的なモデル識別子を記載してはならない (MUST NOT)。モデルティアに言及する必要がある場合は `plugins/longrun/references/model-tiers.md` への参照で表現する。

#### Scenario: モデル ID の grep が 0 件である

- **WHEN** `plugins/loops/` 配下で `claude-` で始まるモデル ID 文字列を grep する（例: `grep -rE 'claude-(opus|sonnet|haiku|[0-9])' plugins/loops/`）
- **THEN** 該当行は 0 件である
