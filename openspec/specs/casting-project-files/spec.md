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

`precedents.md` の判例は1判例1ブロックの追記型とし、見出し（日付＋論点1行）と4フィールド — 観点（catalog.md の語彙、当てはまらなければ「カタログ外」）・経路（主に上げた／自走した／相談の上自走した）・帰結（論点だった／じゃなかった＋一言の理由）・還元（配役既定表のどこを変えたか。変更なしは「なし」）— を持たなければならない (MUST)。この形式は雛形 `templates/precedents.md` と SKILL.md の両方に記載されなければならない (MUST)。

#### Scenario: 雛形が4フィールドの記入例を含む

- **WHEN** `plugins/casting/templates/precedents.md` を読む
- **THEN** 観点・経路・帰結・還元の4フィールドを持つ記入例が含まれている

### Requirement: casting-check.sh の検出項目

`plugins/casting/scripts/casting-check.sh` は対象 repo の `.claude/casting/` に対して次の7項目を検査しなければならない (MUST): ⓪配役表の表行が5列ちょうどに割れるか（`|` が6個ちょうどでない行は malformed-row として報告する。5列未満だけでなく、セル内の `|` で6列以上に割れる行も対象にしなければならない (MUST)。列がずれると `既定の担い手` 列が別のセルに解決されるため。壊れた行は resolve の合成で有効値として扱わない）⓪'各ファイルで開いた HTML コメント `<!--` が閉じられているか（対応する `-->` が無いままファイル末尾に達したときだけ unclosed-comment として報告しなければならない (MUST)。閉じ忘れは以降の行を EOF まで無視させ、上書き行を黙って全滅させるため。`<!--` と `-->` の出現「個数」で判定してはならない (MUST NOT)（コメントの外にある対応先の無い `-->`（本文の矢印・コード例）だけを含む正常な配役表を止めてしまい、逆にその `-->` が本物の閉じ忘れ `<!--` と釣り合うと検出を落とすため）。判定はパース側のコメント除去と同一の走査で行わなければならない (MUST)）①配役表・判例台帳に catalog.md に無い観点語彙（「カタログ外」を除く）が使われていないか ②判例台帳に「カタログ外」判例があるか（観点追加の起案シグナルとして報告）③同一観点で帰結「論点じゃなかった」が2件以上あるか（移譲仕組み化の起案シグナルとして報告）④各ファイルの `catalog_version` が catalog.md の `version` と一致するか⑤判例台帳の相談判例（経路「相談の上自走した」のブロック）が事後報告フォーマットの5要素（論点・各人格の主張・裁定・根拠・判例リンク）をすべて**実質的な値つきで**持つか（ラベルだけ並べて値が空・空白のみのものは欠落として報告する。規約に反する形の相談実例が過去判例として配られるのを防ぐ）。検出なしなら exit 0、検出ありなら対象の一覧を出力して exit 1 としなければならない (MUST)。対象 repo ルートが存在しない場合は検査結果を返してはならず (MUST NOT)、使い方エラーとして exit 2 としなければならない (MUST)（打ち間違えたパスを「問題のない repo」と同じ exit 0 で返さないため）。日本語語彙の照合に awk のマルチバイト文字列比較を使ってはならない (MUST NOT)（macOS awk は多バイト比較が壊れるため。`LC_ALL=C` の grep -F 等で照合する）。

#### Scenario: 問題のないフィクスチャで exit 0

- **WHEN** カタログ語彙のみ・カタログ外なし・version 一致のフィクスチャに対して実行する
- **THEN** exit code が 0 になる

#### Scenario: 7種の検出がそれぞれ報告される

- **WHEN** ⓪5列未満の壊れた表行 ⓪'閉じ忘れの HTML コメント ①未知語彙 ②カタログ外判例 ③同一観点の「論点じゃなかった」2件 ④version 不一致 ⑤事後報告5要素を欠くか値が空の相談判例 をそれぞれ含む7つのフィクスチャに対して実行する
- **THEN** いずれも該当項目が一覧出力され、exit code が 1 になる

#### Scenario: セル内の | で6列以上に割れる行が報告される

- **WHEN** 観点の説明セルに `|` が含まれ、表行が6列以上に割れる project.md に対して実行する
- **THEN** malformed-row として該当行が出力され、exit code が 1 になる

#### Scenario: 閉じ忘れの HTML コメントが報告される

- **WHEN** 閉じ `-->` の無い `<!--` を含む配役表に対して実行する
- **THEN** unclosed-comment として該当ファイルが出力され、exit code が 1 になる

#### Scenario: コメントの外の `-->` だけを含む配役表は止めない

- **WHEN** HTML コメントを1つも含まず、本文に対応先の無い `-->` だけがある配役表に対して実行する
- **THEN** unclosed-comment は報告されず、exit code が 0 になる（resolve も上書き行を由来 `project` で出力する）

#### Scenario: 対応の無い `-->` があっても閉じ忘れは検出される

- **WHEN** 本文の対応先の無い `-->` と、閉じ `-->` の無い `<!--` を両方含む配役表に対して実行する
- **THEN** 開閉の個数が釣り合っていても unclosed-comment が報告され、exit code が 1 になる

#### Scenario: 1行で閉じたコメントは以降の行を飲み込まない

- **WHEN** `<!-- メモ -->` のように同じ行で閉じたコメントの後ろに上書き行が続く配役表に対して実行する
- **THEN** exit code が 0 になり、resolve はその上書き行を由来 `project` で出力する

#### Scenario: 存在しない repo ルートは使い方エラーになる

- **WHEN** 存在しないパスを対象に実行する
- **THEN** 検査結果を出力せず、exit code が 2 になる

### Requirement: 検出項目数の表記と実装の一致

検出項目数を数字で書いている文書（`plugins/casting/README.md`・`plugins/casting/skills/casting/SKILL.md`・`plugins/casting/scripts/casting-check.sh` の冒頭コメント・`plugins/casting/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の description・この spec の「casting-check.sh の検出項目」要件）の「N項目」は、`casting-check.sh` が実際に報告する検出カテゴリ（`report` の第1引数）の異なり数と一致しなければならない (MUST)。この一致は人手のレビューではなくテストで機械的に突き合わせなければならない (MUST)（検出が後から足されたときに文書だけ取り残される事故が起きたため）。

検出カテゴリの数え上げは、シェルのコード領域にある `report` 呼び出しだけを対象にしなければならない (MUST)。ヒアドキュメント本文・行末コメント・文字列リテラルの中に現れる `report` を呼び出しとして数えてはならない (MUST NOT)（`report` の語を含む使い方出力やエラーメッセージを `casting-check.sh` に足しただけで、数え方と無関係なテストが落ちて原因が分かりにくくなるため）。判定に迷う形は多めに数える側（偽陽性）へ倒し、数え落とし側へ倒してはならない (MUST NOT)（検出カテゴリが黙って減ると、文書の「N項目」との突き合わせと「第1引数はリテラル」の検査の両方がすり抜けるため）。

#### Scenario: コードではない report は呼び出しとして数えない

- **WHEN** ヒアドキュメント本文・行末コメント・文字列リテラルの中に `report "..."` を書いたスクリプトから検出カテゴリを数える
- **THEN** どれも呼び出しとして数えられず、同じスクリプトに本物の `report` 呼び出しを1件足すとカテゴリ数が1になる

#### Scenario: ヒアドキュメントや引用と紛らわしい構文の後ろの呼び出しも数える

- **WHEN** 算術式の左シフト（`(( value = 1 << 2 ))` / `$(( 1 << 3 ))`）や ANSI-C クオート（`$'don\'t'`）を含む行の後ろに本物の `report` 呼び出しを書いたスクリプトから検出カテゴリを数える
- **THEN** 算術式の `<<` がヒアドキュメント開始と、`$'…'` の中の `\'` が引用の終端と誤認されず、後続の呼び出しがすべて数えられる

#### Scenario: 実行されるコマンド置換の中の report を数える

- **WHEN** 二重引用の中のコマンド置換（`out="$(report "x" "m")"`）と、未引用ヒアドキュメント本文の中のコマンド置換（`$(report "x" "m")`）を書いたスクリプトから検出カテゴリを数える
- **THEN** どちらも呼び出しとして数えられる（区切り語が引用されたヒアドキュメント本文の中の `$(report …)` は展開されないため、引き続き数えない）

#### Scenario: 検出カテゴリを増やすと文書を直すまでテストが落ちる

- **WHEN** `casting-check.sh` の検出カテゴリ数と文書の「N項目」表記が食い違っている状態でテストスイートを実行する
- **THEN** 該当テストが失敗し、実装側のカテゴリ数と文書側の表記の両方が失敗メッセージに出る

#### Scenario: 数え方から漏れる report 呼び出しは無言で通らない

- **WHEN** 第1引数がリテラルでない `report` 呼び出し（`report "$var"` 等）を、既存のリテラル呼び出しと同一行に並べた状態でテストスイートを実行する
- **THEN** 呼び出しの数え方が行単位ではなく出現単位であるため食い違いが検出され、該当テストが失敗する

### Requirement: resolve による有効な配役表の合成表示

`casting-check.sh resolve [<repo-root>]` は、catalog.md・project.md・local.md を観点（行）単位で合成した有効な配役表を出力しなければならない (MUST)。出力の前に、合成の入力になる project.md・local.md へ check モードと同じ配役表検証（⓪5列ちょうどに割れない表行 ⓪'閉じられていない HTML コメント ①catalog.md に無い観点語彙 ④catalog_version の catalog.md との不一致・front matter 欠落）を実行しなければならず (MUST)、検証に失敗した場合は合成表を stdout に一切出力せず（部分表・ヘッダ行も含む）、失敗理由（検出カテゴリ・ファイル・該当行または観点）を stderr に出して exit 1 しなければならない (MUST)。配役表（project.md・local.md）が1枚も存在しない対象に対しては、カタログ既定だけの合成表を stdout に出力してはならず (MUST NOT)、配役表が無い旨を stderr に出して exit 3 としなければならない (MUST)（repo ルートの打ち間違え・casting 未導入と「検証を通った解決結果」を呼び出し側が区別できるようにするため）。起案シグナル（②「カタログ外」判例 ③同一観点の「論点じゃなかった」2件以上）と precedents.md を resolve の検証対象にしてはならない (MUST NOT)（観点追加の提案がその repo の自走を止めないため。check モードでは従来どおり検査する）。検証バイパスのフラグを設けてはならない (MUST NOT)。HTML コメント（`<!-- -->`）内の表行（テンプレートの記入例など）を実在の上書き行として扱ってはならない (MUST NOT)。同じ行で閉じた HTML コメント（`<!-- メモ -->`）が、その行より後ろの行をパース対象から外してはならない (MUST NOT)（1行コメント1つで以降の上書き行が黙って全滅し、`全部カタログ既定` に化けるため）。`resolve` サブコマンドは引数の位置に依存してはならず (MUST NOT)、オプションより後ろに置かれても resolve として扱わなければならない (MUST)（黙って check モードに落ちないため）。対象 repo ルートの positional 引数は1個までとし、2個以上・不明なオプション・`--catalog` の値欠落は usage を出して exit 2 としなければならない (MUST)。各観点の行には、その値がどの層から来たかの由来（`カタログ既定`／`project`／`local`）を付けなければならない (MUST)。カタログの全観点が出力に含まれなければならない (MUST)。

#### Scenario: 上書きと継承が由来つきで合成される

- **WHEN** project.md で1観点、local.md でさらに別の1観点を上書きしたフィクスチャに対して resolve を実行する
- **THEN** 上書きした2観点はそれぞれ project／local の値と由来、残りの観点はカタログの値と由来 `カタログ既定` で出力される

#### Scenario: 検証を通らない配役表では合成表を出さない

- **WHEN** 壊れた表行（5列未満・6列以上）・閉じ忘れコメント・未知語彙・catalog_version 不一致・front matter 欠落のいずれかを project.md または local.md に含む repo に対して resolve を実行する
- **THEN** stdout には何も出力されず、stderr に検出カテゴリ・ファイル・該当行（または観点名）が出て、exit code が 1 になる

#### Scenario: 配役表が1枚も無い repo では解決しない

- **WHEN** `.claude/casting/` に precedents.md だけがあり project.md も local.md も無い repo に対して resolve を実行する
- **THEN** stdout には何も出力されず、stderr に配役表が無い旨と対処が出て、exit code が 3 になる

#### Scenario: オプションの後ろの resolve も resolve として扱われる

- **WHEN** `--catalog <path> resolve <repo-root>` の順で実行する
- **THEN** 合成表が出力され（壊れた配役表なら fail-closed で exit 1 になり）、check モードへ黙って落ちない

#### Scenario: 起案シグナルだけの repo は合成できる

- **WHEN** 有効な project.md があり、precedents.md に「カタログ外」判例（または同一観点の「論点じゃなかった」2件以上）がある repo に対して resolve を実行する
- **THEN** 合成表が出力され exit code が 0 になる

### Requirement: 導入 repo 台帳

導入 repo 台帳は `~/.claude/casting/registry.txt`（1行1 repo ルートの絶対パス）とする (MUST)。casting-set.sh は台帳を走査して影響一覧を表示し、存在しないパスはスキップして警告を出さなければならない (MUST)。テストではホームディレクトリ直書きを避け、台帳パスを環境変数で差し替えられなければならない (MUST)。

#### Scenario: 存在しないパスが台帳にあっても走査が失敗しない

- **WHEN** 台帳に存在しないパスを1行含めて casting-set.sh を実行する
- **THEN** そのパスは警告つきでスキップされ、他の repo の影響一覧は正常に出力される

