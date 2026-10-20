# statusline-copy-update Specification

## Purpose
statusline の /statusline:setup が配ったコピー（statusline.sh・statusline-codex.py）を、手を入れていなければセッション開始時にプラグインの本体へ揃え、手を入れていれば上書きせず「更新あり」を知らせる（issue #1113）。
## Requirements
### Requirement: install.sh がコピーした内容のハッシュを記録する
`plugins/statusline/scripts/install.sh` は、`--dry-run` でない実行でコピーを置き終えたあと、`<config>/statusline.sh` と `<config>/statusline-codex.py` の内容の SHA-256 を `<config>/.statusline-installed` に書かなければならない（SHALL）。`<config>` は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` とする。コピーの内容が既にプラグインの本体と一致していて書き換えなかった実行でも書く（SHALL）。

記録は 1 ファイル 1 行で、各行は `<64 桁の小文字 16 進数><半角空白 2 つ><ファイル名>` とする（SHALL）。ファイル名は `statusline.sh` と `statusline-codex.py` のどちらか。記録は同じディレクトリの一時ファイルに書いてから置き換える（SHALL）。

記録を書いたあと、`<config>/.statusline-update-available` があれば消さなければならない（SHALL）。打ち直した直後に、同じセッションの中で「更新あり」が残らないようにするため。

`--dry-run` の実行では記録を書いてはならず、印も消してはならない（MUST NOT）。`shasum` と `sha256sum` のどちらも使えない環境では、記録を書かず、警告を 1 行出して導入自体は続ける（SHALL）。

#### Scenario: 導入すると記録ができる
- **WHEN** 空の設定ディレクトリで `install.sh` を実行する
- **THEN** `<config>/.statusline-installed` に 2 行があり、それぞれのハッシュがコピーの SHA-256 と一致する

#### Scenario: 内容が既に同じでも記録を書く
- **WHEN** コピーがプラグインの本体と同じ内容で、記録ファイルが無い状態で `install.sh` を実行する
- **THEN** `<config>/.statusline-installed` が作られる

#### Scenario: dry-run は記録を書かない
- **WHEN** `install.sh --dry-run` を実行する
- **THEN** `<config>/.statusline-installed` は作られず、既にあれば内容は変わらない。`<config>/.statusline-update-available` があればそのまま残る

#### Scenario: 打ち直した直後に印が消える
- **WHEN** `<config>/.statusline-update-available` がある状態で `install.sh` を実行する
- **THEN** `install.sh` を実行した直後に `<config>/.statusline-update-available` は無い

### Requirement: SessionStart フックが手を入れていないコピーを本体に揃える
statusline プラグインは SessionStart フック（`plugins/statusline/hooks/hooks.json`。matcher `startup|resume|clear`）で `plugins/statusline/scripts/statusline-update-hook.sh` を走らせなければならない（SHALL）。フックは `<config>/statusline.sh` と `<config>/statusline-codex.py` のそれぞれについて、`$CLAUDE_PLUGIN_ROOT/scripts/` の同名ファイル（以下「本体」）と記録を比べ、次のとおり動かなければならない（SHALL）。

- コピーが無い: 何もしない
- コピーが本体と同じ内容: 記録のそのファイルの行を本体のハッシュにする
- コピーが本体と違い、コピーのハッシュが記録のそのファイルの行と一致する: コピーを本体の内容で置き換え（一時ファイルからの置き換え。権限は `statusline.sh` が 755、`statusline-codex.py` が 644）、記録のその行を本体のハッシュに書き直す

フックは python3 を起動してはならない（MUST NOT）。

守備範囲（この要件と「手を入れたコピーと記録の無いコピーは上書きせず印を置く」「フックはインストール済みのプラグインから起動されたときだけ動き、失敗しても止めない」の 3 要件に共通）: フックが読む入力は、install.sh が置いたコピーと記録、利用者がエディタで直したコピー、Claude Code が渡す `$CLAUDE_PLUGIN_ROOT` である。拾いたい誤りは、利用者が直したコピーをプラグインの更新で消すこと、`--plugin-dir` で読み込んだ未マージの版で本物のコピーを置き換えること、プラグイン更新より前から開いているセッション（`$CLAUDE_PLUGIN_ROOT` が古い版のディレクトリを指したまま）から走ったフックで、新しい版に揃えたコピーを古い版に巻き戻すことの 3 つに限る。次の入力はこの 3 要件の判定を通ってしまう、または意図と違う結果になるが、塞ぐことは完了条件にしない。

- `<config>/.statusline-installed` を手で書き換えたもの（書き換えた記録と一致するコピーは、手を入れていないものとして本体で置き換わる）
- 内容は変えず、権限や更新日時だけ変えたコピー（内容のハッシュは同じなので、手を入れていないものとして置き換わる）
- 別の版の本体の内容に手で差し替えたコピー（記録と違うので上書きせず、印を出すだけ）
- `<config>/plugins/` の下に置いた開発版を `--plugin-dir` で読んだとき（インストール済みと見分けられず、開発版でコピーを置き換える）
- marketplace dir から `install.sh` を直接走らせた直後で、cache の版と内容に差があるとき（記録どおりのコピーなので、次のセッション開始で cache の版に置き換わる）
- `jq` が無い環境、または Claude Code が `<config>/plugins/installed_plugins.json` の形を変えたとき（いまの版かを判定できないのでフックは何もせず、コピーは自動では揃わない。`/statusline:setup` の打ち直しで揃う）

#### Scenario: 記録どおりの古いコピーは本体と同じになる
- **WHEN** `<config>/statusline.sh` が古い内容で、記録のハッシュがその古い内容と一致する状態でフックを走らせる
- **THEN** `cmp` で `<config>/statusline.sh` と本体が一致し、記録のハッシュが本体のハッシュになる

#### Scenario: Codex helper も同じ扱いになる
- **WHEN** `<config>/statusline-codex.py` が記録どおりの古い内容でフックを走らせる
- **THEN** `cmp` で `<config>/statusline-codex.py` と本体が一致する

#### Scenario: 導入していなければ何も作らない
- **WHEN** `<config>/statusline.sh` も `<config>/statusline-codex.py` も無い状態でフックを走らせる
- **THEN** `<config>` にファイルは増えない

### Requirement: 手を入れたコピーと記録の無いコピーは上書きせず印を置く
コピーが本体と違い、コピーのハッシュが記録のそのファイルの行と一致しないとき、記録にそのファイルの行が無いとき、または記録ファイルが無いとき、フックはそのコピーを書き換えてはならない（MUST NOT）。

判定のあと、上の条件に当たり、かつ本体のハッシュが記録のそのファイルの行と違うファイル（記録にそのファイルの行が無いとき・記録ファイルが無いときを含む）が 1 つ以上あれば、フックは `<config>/.statusline-update-available` にそのファイル名を 1 行 1 件で書かなければならない（SHALL）。1 つも無ければ `<config>/.statusline-update-available` を消さなければならない（SHALL）。本体のハッシュが記録の行と同じとき（手を入れたあと、プラグインはまだ更新されていない）は、配った版から本体が変わっておらず更新は無いので、印の対象にしない。

#### Scenario: 本体が記録と同じなら手を入れたコピーにも印を置かない
- **WHEN** 記録どおりに導入したあと `<config>/statusline.sh` に 1 行書き足し、プラグインの本体は変えずにフックを走らせる
- **THEN** `<config>/statusline.sh` と記録の内容は変わらず、`<config>/.statusline-update-available` は無い

#### Scenario: 1 行書き足したコピーは変わらない
- **WHEN** 記録どおりに導入したあと `<config>/statusline.sh` に 1 行書き足し、プラグインの本体を別の内容にしてフックを走らせる
- **THEN** `<config>/statusline.sh` の内容は書き足した状態のままで、`<config>/.statusline-update-available` に `statusline.sh` の行がある

#### Scenario: 記録ファイルが無いコピーは上書きしない
- **WHEN** `<config>/.statusline-installed` が無く、`<config>/statusline.sh` が本体と違う状態でフックを走らせる
- **THEN** `<config>/statusline.sh` の内容は変わらず、`<config>/.statusline-update-available` がある

#### Scenario: 本体と同じになったらフックが印を消す
- **WHEN** `<config>/.statusline-update-available` がある状態で、利用者がコピーを手で本体と同じ内容に戻してからフックを走らせる
- **THEN** `<config>/.statusline-update-available` は無く、記録のそのファイルの行が本体のハッシュになる

### Requirement: ステータスラインは印があるとき 1 行目の末尾に「更新あり」を出す
`plugins/statusline/scripts/statusline.sh` は、`<config>/.statusline-update-available` が存在するとき、1 行目の末尾に `更新あり /statusline:setup` を足さなければならない（SHALL）。判定はファイルの有無だけで行い、描画のたびにハッシュを取ってはならない（MUST NOT）。

印が無いとき、出力はこの変更の前と 1 バイトも変わってはならない（MUST NOT）。印があるときも、1 行目の既存の部分（ディレクトリ・モデル・ブランチ）と 2 行目以降は変わってはならない（MUST NOT）。

#### Scenario: 手を入れたコピーで描画すると更新ありが出る
- **WHEN** 1 行書き足したコピーでフックを走らせたあと、そのコピーで描画する
- **THEN** 描画の 1 行目（ANSI エスケープを除いたもの）が `更新あり /statusline:setup` で終わる

#### Scenario: 印が無ければ出力は変わらない
- **WHEN** `<config>/.statusline-update-available` が無い状態で描画する
- **THEN** 出力に `更新あり` は含まれない

### Requirement: 印を描けない古いコピーにはフックが開始時に案内を出す
フックが `<config>/.statusline-update-available` を置いたとき、`<config>/statusline.sh` のコピーに文字列 `.statusline-update-available` が含まれていなければ、フックは標準出力に `systemMessage` だけを持つ JSON を 1 行出し、`/statusline:setup` で更新できることを伝えなければならない（SHALL）。コピーがその文字列を含むとき、または印を置かなかったときは、標準出力に何も出してはならない（MUST NOT）。

#### Scenario: 古いコピーには案内が出る
- **WHEN** 記録ファイルが無く、印を読む処理を持たない `<config>/statusline.sh` がある状態でフックを走らせる
- **THEN** 標準出力が `systemMessage` を持つ JSON 1 行で、その値に `/statusline:setup` が含まれる

#### Scenario: 新しいコピーには案内を重ねない
- **WHEN** 印を読む処理を持つコピーに 1 行書き足した状態でフックを走らせる
- **THEN** 標準出力は空

### Requirement: フックはインストール済みのプラグインから起動されたときだけ動き、失敗しても止めない
フックは、`$CLAUDE_PLUGIN_ROOT` が空のとき、または `$CLAUDE_PLUGIN_ROOT` の実体のパスが `<config>/plugins/` の実体のパスの下にないとき、コピー・記録・印のどれも書き換えてはならない（MUST NOT）。`claude --plugin-dir` で開発中の版を読み込んだセッションで、利用者のコピーを未マージの版に置き換えないため。

また、`$CLAUDE_PLUGIN_ROOT` の実体のパスが、`<config>/plugins/installed_plugins.json` の `plugins` のうちキーが `statusline@` で始まる項目の `installPath`（実体のパスに解決したもの）のどれとも一致しないとき、フックはコピー・記録・印のどれも書き換えてはならない（MUST NOT）。`installed_plugins.json` が無い・読めないとき、`jq` が無いときも同じとする。プラグイン更新より前から開いているセッションの `$CLAUDE_PLUGIN_ROOT` は古い版のディレクトリを指したままなので、そこから走ったフックが新しい版に揃えたコピーを古い版に巻き戻さないため。

フックはどの失敗でも exit 0 で終わり、標準エラーに何も出してはならない（MUST NOT）。

#### Scenario: plugin-dir で読み込んだ版では何もしない
- **WHEN** `CLAUDE_PLUGIN_ROOT` が `<config>/plugins/` の外を指し、記録どおりの古いコピーがある状態でフックを走らせる
- **THEN** コピー・記録・印のどれも変わらず、exit 0

#### Scenario: 古い版のセッションから走っても巻き戻さない
- **WHEN** `installed_plugins.json` の `installPath` が新しい版を指し、コピーと記録が新しい版に揃った状態で、`CLAUDE_PLUGIN_ROOT` が古い版のディレクトリを指すフックを走らせる
- **THEN** コピー・記録・印のどれも変わらず、exit 0

#### Scenario: インストールの記録が読めなければ何もしない
- **WHEN** `<config>/plugins/installed_plugins.json` が無い状態で、記録どおりの古いコピーがありフックを走らせる
- **THEN** コピー・記録・印のどれも変わらず、exit 0

#### Scenario: CLAUDE_PLUGIN_ROOT が空でも止まらない
- **WHEN** `CLAUDE_PLUGIN_ROOT` を空にしてフックを走らせる
- **THEN** exit 0 で、何も書き換えない

