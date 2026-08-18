# casting-project-files Specification

## Purpose
TBD - created by archiving change casting-plugin. Update Purpose after archive.
## Requirements
### Requirement: 3層デフォルトの配置規約

プロジェクト側の配役ファイルは `<repo>/.claude/casting/` 配下に置かなければならない (MUST)。第1層＝`project.md`（git 追跡・プロジェクト既定）、第2層＝`local.md`（gitignore 対象・エージェント/マシン別上書き）、第3層＝セッション起動時のプロンプト宣言（ファイルなし。宣言形式は `skills/casting/SKILL.md` に定義）とする (MUST)。解決は**観点（行）単位**で行い、強い順にセッション宣言 > local.md > project.md > catalog.md とし、ある観点の行を持つ最も強い層がその観点の有効値になる (MUST)。各層のファイルには**カタログと変えたい観点の行だけ**を書き、行を書く場合は5列すべてを記載する (MUST)。列の部分上書きをしてはならない (MUST NOT)。判例台帳は同ディレクトリの `precedents.md`（git 追跡・追記型）とする (MUST)。project.md / local.md / precedents.md は front matter に `catalog_version` を持たなければならない (MUST)。

#### Scenario: 行単位の解決規則が SKILL.md に定義されている

- **WHEN** `plugins/casting/skills/casting/SKILL.md` を読む
- **THEN** 3層の置き場・観点（行）単位の解決順・「変えたい行だけ書く」規則・セッション宣言の形式が定義されている

#### Scenario: 書いていない観点はカタログに踏襲される

- **WHEN** project.md に1観点だけ上書き行があるプロジェクトの有効な配役を合成する
- **THEN** その1観点は project.md の値、残りの観点はカタログの既定値になる

### Requirement: /casting:init による生成

`/casting:init` コマンドは、実行した git repo に `.claude/casting/project.md`（差分方式の空表＋書き方説明。カタログ全行のコピーを含まない）と `.claude/casting/precedents.md` を雛形から生成し、`.gitignore` に `.claude/casting/local.md` を追記しなければならない (MUST)。あわせて導入 repo 台帳 `~/.claude/casting/registry.txt` に repo ルートの絶対パスを追記しなければならない (MUST)。既存のファイルがある場合は上書きしてはならない (MUST NOT)。gitignore 追記と台帳追記は冪等でなければならない (MUST)。

#### Scenario: 初回実行で一式が生成される

- **WHEN** `.claude/casting/` が無い git repo で init の生成手順を実行する
- **THEN** project.md（カタログ全行のコピーを含まない差分表）と precedents.md が生成され、.gitignore に local.md の行が1行だけ追加され、registry.txt に repo パスが1行追加される

#### Scenario: 再実行しても上書き・重複しない

- **WHEN** 生成済みの repo で project.md を編集した後、もう一度 init の生成手順を実行する
- **THEN** 編集内容が保持され、.gitignore と registry.txt の行も重複しない

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

### Requirement: resolve による有効な配役表の合成表示

`casting-check.sh resolve [<repo-root>]` は、catalog.md・project.md・local.md を観点（行）単位で合成した有効な配役表を出力しなければならない (MUST)。各観点の行には、その値がどの層から来たかの由来（`カタログ既定`／`project`／`local`）を付けなければならない (MUST)。カタログの全観点が出力に含まれなければならない (MUST)。

#### Scenario: 上書きと継承が由来つきで合成される

- **WHEN** project.md で1観点、local.md でさらに別の1観点を上書きしたフィクスチャに対して resolve を実行する
- **THEN** 上書きした2観点はそれぞれ project／local の値と由来、残りの観点はカタログの値と由来 `カタログ既定` で出力される

### Requirement: 導入 repo 台帳

導入 repo 台帳は `~/.claude/casting/registry.txt`（1行1 repo ルートの絶対パス）とする (MUST)。casting-set.sh は台帳を走査して影響一覧を表示し、存在しないパスはスキップして警告を出さなければならない (MUST)。テストではホームディレクトリ直書きを避け、台帳パスを環境変数で差し替えられなければならない (MUST)。

#### Scenario: 存在しないパスが台帳にあっても走査が失敗しない

- **WHEN** 台帳に存在しないパスを1行含めて casting-set.sh を実行する
- **THEN** そのパスは警告つきでスキップされ、他の repo の影響一覧は正常に出力される

