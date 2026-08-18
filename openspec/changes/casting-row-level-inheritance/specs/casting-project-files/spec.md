## MODIFIED Requirements

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

## ADDED Requirements

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
