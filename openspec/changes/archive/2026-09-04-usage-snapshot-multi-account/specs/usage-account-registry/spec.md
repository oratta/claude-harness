## ADDED Requirements

### Requirement: アカウントレジストリの所在と形状
使用量観測の対象となる Claude アカウントは、レジストリファイル `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（環境変数 `CLAUDE_ACCOUNTS_FILE` で上書き可能）に定義されなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を使う運用の前提が「`CLAUDE_CONFIG_DIR` は共有する」ことであるため、レジストリは `CLAUDE_CONFIG_DIR` 配下に置く。

レジストリのトップレベルは**オブジェクト**でなければならず（SHALL）、次の形状に固定する。トップレベルが裸の配列であってはならない（MUST NOT）:

```json
{
  "schema": 1,
  "accounts": [
    { "id": "a", "label": "A", "securestorage": null },
    { "id": "b", "label": "B", "securestorage": "/Users/example/.claude-b" }
  ]
}
```

- `schema`: 整数。省略時は `1` とみなす
- `accounts`: スロットの配列（必須）
- スロットの `id`: snapshot のキーになる識別子。`^[A-Za-z0-9-]{1,32}$` に一致しなければならない（SHALL）
- スロットの `label`: statusline に表示する短いラベル（1〜4 文字を想定）。省略時は `id` を用いる
- スロットの `securestorage`: そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` または空文字は既定アカウント（`CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定の状態）を意味する

スロットの順序は宣言順を保たなければならない（SHALL）。リポジトリはレジストリの雛形または生成手段（コマンドか README の手順）を提供しなければならない（SHALL）。実ファイル自体はリポジトリに含めない。

#### Scenario: 複数スロットを読む
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null},{"id":"b","label":"B","securestorage":"/tmp/cb"}]}` を与えて読み取り処理を実行する
- **THEN** 宣言順に 2 つのスロットが得られ、それぞれ `id` / `label` / `securestorage` を保つ

#### Scenario: 環境変数でレジストリの場所を上書きする
- **WHEN** `CLAUDE_ACCOUNTS_FILE` に別のパスを設定して読み取り処理を実行する
- **THEN** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json` ではなく、指定されたパスのレジストリが読まれる

#### Scenario: CLAUDE_CONFIG_DIR に追随する
- **WHEN** `CLAUDE_CONFIG_DIR` を一時ディレクトリに設定し、`CLAUDE_ACCOUNTS_FILE` を設定せずに読み取り処理を実行する
- **THEN** レジストリは `$CLAUDE_CONFIG_DIR/accounts.json` から読まれ、`$HOME/.claude/accounts.json` は読まれない

#### Scenario: トップレベルが配列なら不正として扱う
- **WHEN** トップレベルが裸の配列 `[{"id":"a"}]` のレジストリを与えて読み取り処理を実行する
- **THEN** 不正なレジストリとして扱われ、既定アカウントを指すスロットが 1 つだけ得られる

### Requirement: 不正なスロットの除外と id の一意性
`id` は全スロットで一意でなければならない（MUST）。読み取り処理は次の規則で不正なスロットを除外しなければならない（SHALL）:

- `id` が欠けている、または `^[A-Za-z0-9-]{1,32}$` に一致しないスロットは捨てる
- `id` が既出のスロットと重複する場合、先に現れたものを残し、後のものを捨てる
- スロットは先頭から最大 8 個までを採用し、それを超えるスロットは捨てる（probe の実行時間がスロット数に比例するため）
- `label` または `securestorage` に制御文字（`\t` `\n` `\r` 等の C0 制御文字および DEL）を含むスロットは捨てる。これらの値はスロット一覧として区切り付きで受け渡されるため、区切りを壊すと列がずれ、実在しない「幽霊スロット」が生まれる。幽霊スロットは `securestorage` が空になりやすく既定サービス名に一致して active を乗っ取りうるので、入口で落とす

除外の結果スロットが 0 個になった場合は、レジストリ不在時と同じく既定スロット 1 つに縮退しなければならない（SHALL）。除外はエラーとして扱ってはならない（MUST NOT）。

#### Scenario: id が重複したスロットを捨てる
- **WHEN** 同じ `id` を持つスロットが 2 つ含まれるレジストリを与えて読み取り処理を実行する
- **THEN** 先に現れたスロットだけが残り、後のものは捨てられる

#### Scenario: id を欠くスロットを捨てる
- **WHEN** `id` の無いスロットと正しいスロットが 1 つずつ含まれるレジストリを与えて読み取り処理を実行する
- **THEN** 正しいスロットだけが得られる

#### Scenario: label を欠くスロットは id を label にする
- **WHEN** `label` の無いスロット（`id` は `"a"`）を含むレジストリを与えて読み取り処理を実行する
- **THEN** そのスロットの `label` は `"a"` になる

#### Scenario: 制御文字を含むスロットを捨てる
- **WHEN** `label` に改行を含むスロットと正しいスロットが 1 つずつ含まれるレジストリを与えて読み取り処理を実行する
- **THEN** 正しいスロットだけが得られ、列のずれによる幽霊スロットは現れない

#### Scenario: 全スロットが不正なら既定スロットに縮退する
- **WHEN** 全スロットが `id` を欠くレジストリを与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

### Requirement: レジストリ不在時は既定スロット 1 つに縮退する
レジストリファイルが存在しない、読み取れない、または JSON としてパースできない場合、読み取り処理は「既定アカウント（`securestorage` が `null`）を指すスロットが 1 つだけ存在するレジストリ」として扱わなければならない（SHALL）。この縮退はエラーとして扱ってはならない（MUST NOT）。

これにより、レジストリを導入していない環境（既定の環境）では使用量観測の挙動が一切変わらない。

#### Scenario: レジストリが存在しない
- **WHEN** レジストリファイルが存在しない状態で読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

#### Scenario: レジストリが壊れている
- **WHEN** JSON としてパースできない内容のレジストリファイルを与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

#### Scenario: accounts が空配列
- **WHEN** `{"schema":1,"accounts":[]}` を与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られる

### Requirement: スロットから Keychain サービス名を導出する規則
スロットから macOS Keychain のサービス名を導出する規則は、Claude Code 本体の生成ロジックと一致しなければならない（SHALL）:

- `securestorage` が `null` または空文字のとき → `Claude Code-credentials`
- それ以外のとき → `Claude Code-credentials-` + `sha256(<securestorage を NFC 正規化した文字列>)` の先頭 8 桁（小文字 16 進）

#### Scenario: 既定スロットのサービス名
- **WHEN** `securestorage` が `null` または空文字のスロットからサービス名を導出する
- **THEN** サービス名は `Claude Code-credentials` である

#### Scenario: securestorage を持つスロットのサービス名
- **WHEN** `securestorage` に具体的なパスを持つスロットからサービス名を導出する
- **THEN** サービス名は `Claude Code-credentials-` に、そのパスを NFC 正規化した文字列の sha256 の先頭 8 桁を続けたものである

#### Scenario: NFC 正規化を経る
- **WHEN** 合成済み文字と結合文字で表記が異なるが NFC 正規化すると同一になる 2 つのパスからサービス名を導出する
- **THEN** 2 つのサービス名は一致する

### Requirement: active スロットの判定規則
現在アクティブなスロットの判定は、probe と statusline の双方で同一の規則に従わなければならない（SHALL）。突き合わせは `CLAUDE_SECURESTORAGE_CONFIG_DIR` の**値そのものの文字列比較ではなく、その値から導出した Keychain サービス名**で行わなければならない（SHALL）。

サービス名での比較は、Claude Code 本体が認証情報を実際に置く場所と同じ同値関係になる。末尾スラッシュや `~` 展開が異なるパスは本体にとっても別の Keychain 項目であり、サービス名が異なれば「そのスロットの認証情報はそこには無い」ことを正しく意味する。素の文字列比較を使うと、この同値関係とずれて無言の取り違えが起きる。レジストリの `securestorage` には、実際に環境変数へ設定しているのと同一の文字列を記録すること。

判定の優先順位:

1. `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出したサービス名と一致するスロットがあれば、それを active とする。**環境変数が未設定または空文字の場合も、空文字からの導出（＝既定サービス名 `Claude Code-credentials`）として突き合わせる**。既定スロット（`securestorage` が `null` または空文字）が存在すればここで一致する
2. 一致するスロットが無い場合、snapshot の `active` が実在するスロット id を指していればそれを active とする（probe 側では前回の snapshot、statusline 側では現在の snapshot）。既定スロットを持たないレジストリ（全スロットが explicit な `securestorage` を持つ）で環境変数が未設定のときが、この経路に落ちる代表例
3. どちらも得られない場合は最初のスロットを active とする

#### Scenario: サービス名が一致すれば active になる
- **WHEN** スロットの `securestorage` と `CLAUDE_SECURESTORAGE_CONFIG_DIR` が同一の文字列である状態で判定する
- **THEN** 導出されるサービス名が一致し、そのスロットが active になる

#### Scenario: 表記が違えば別の Keychain 項目として扱う
- **WHEN** スロットの `securestorage` が `/Users/example/.claude-b`、`CLAUDE_SECURESTORAGE_CONFIG_DIR` が同じパスに末尾スラッシュを付けた値である状態で判定する
- **THEN** 導出されるサービス名が異なるため一致せず（本体にとっても別の Keychain 項目であるため）、フォールバック（snapshot の `active`、無ければ最初のスロット）に進む

#### Scenario: env がどのスロットにも一致しない
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` がレジストリのどのスロットの `securestorage` とも一致せず、snapshot の `active` が実在するスロットを指す状態で判定する
- **THEN** snapshot の `active` が指すスロットが active になる

#### Scenario: env 未設定は既定スロットに一致する
- **WHEN** 既定スロット（`securestorage` が `null`）を含むレジストリで `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定の状態で判定する
- **THEN** 空文字から導出した既定サービス名が一致し、優先順位 1 でその既定スロットが active になる（snapshot の `active` が別のスロットを指していても優先順位 1 が勝つ）

#### Scenario: 手掛かりが無ければ最初のスロット
- **WHEN** 既定スロットを持たないレジストリで `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定、かつ snapshot も存在しない状態で判定する
- **THEN** レジストリの最初のスロットが active になる
