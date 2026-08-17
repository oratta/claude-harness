# casting-project-files Specification

## Purpose
TBD - created by archiving change casting-plugin. Update Purpose after archive.
## Requirements
### Requirement: 3層デフォルトの配置規約

プロジェクト側の配役ファイルは `<repo>/.claude/casting/` 配下に置かなければならない (MUST)。第1層＝`project.md`（git 追跡・プロジェクト既定表）、第2層＝`local.md`（gitignore 対象・エージェント/マシン別上書き）、第3層＝セッション起動時のプロンプト宣言（ファイルなし。宣言形式は `skills/casting/SKILL.md` に定義）とし、番号の大きい層が小さい層を上書きする (MUST)。判例台帳は同ディレクトリの `precedents.md`（git 追跡・追記型）とする (MUST)。project.md / local.md / precedents.md は front matter に `catalog_version` を持たなければならない (MUST)。

#### Scenario: 層の優先順位が SKILL.md に定義されている

- **WHEN** `plugins/casting/skills/casting/SKILL.md` を読む
- **THEN** 3層の置き場・上書き順・セッション宣言の形式が定義されている

### Requirement: /casting:init による生成

`/casting:init` コマンドは、実行した git repo に `.claude/casting/project.md`（カタログの既定の担い手をコピーした5列表）と `.claude/casting/precedents.md` を雛形から生成し、`.gitignore` に `.claude/casting/local.md` を追記しなければならない (MUST)。既存のファイルがある場合は上書きしてはならない (MUST NOT)。gitignore 追記は冪等でなければならない (MUST)。

#### Scenario: 初回実行で一式が生成される

- **WHEN** `.claude/casting/` が無い git repo で init の生成手順を実行する
- **THEN** project.md と precedents.md が生成され、.gitignore に local.md の行が1行だけ追加される

#### Scenario: 再実行しても上書きされない

- **WHEN** 生成済みの repo で project.md を編集した後、もう一度 init の生成手順を実行する
- **THEN** 編集内容が保持され、.gitignore の行も重複しない

### Requirement: 判例台帳の形式

`precedents.md` の判例は1判例1ブロックの追記型とし、見出し（日付＋論点1行）と4フィールド — 観点（catalog.md の語彙、当てはまらなければ「カタログ外」）・経路（主に上げた／自走した）・帰結（論点だった／じゃなかった＋一言の理由）・還元（配役既定表のどこを変えたか。変更なしは「なし」）— を持たなければならない (MUST)。この形式は雛形 `templates/precedents.md` と SKILL.md の両方に記載されなければならない (MUST)。

#### Scenario: 雛形が4フィールドの記入例を含む

- **WHEN** `plugins/casting/templates/precedents.md` を読む
- **THEN** 観点・経路・帰結・還元の4フィールドを持つ記入例が含まれている

### Requirement: casting-check.sh の検出項目

`plugins/casting/scripts/casting-check.sh` は対象 repo の `.claude/casting/` に対して次の4項目を検査しなければならない (MUST): ①配役表・判例台帳に catalog.md に無い観点語彙（「カタログ外」を除く）が使われていないか ②判例台帳に「カタログ外」判例があるか（観点追加の起案シグナルとして報告）③同一観点で帰結「論点じゃなかった」が2件以上あるか（移譲仕組み化の起案シグナルとして報告）④各ファイルの `catalog_version` が catalog.md の `version` と一致するか。検出なしなら exit 0、検出ありなら対象の一覧を出力して exit 1 としなければならない (MUST)。日本語語彙の照合に awk のマルチバイト文字列比較を使ってはならない (MUST NOT)（macOS awk は多バイト比較が壊れるため。`LC_ALL=C` の grep -F 等で照合する）。

#### Scenario: 問題のないフィクスチャで exit 0

- **WHEN** カタログ語彙のみ・カタログ外なし・version 一致のフィクスチャに対して実行する
- **THEN** exit code が 0 になる

#### Scenario: 4種の検出がそれぞれ報告される

- **WHEN** ①未知語彙②カタログ外判例③同一観点の「論点じゃなかった」2件④version 不一致 をそれぞれ含む4つのフィクスチャに対して実行する
- **THEN** いずれも該当項目が一覧出力され、exit code が 1 になる

