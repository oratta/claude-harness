## ADDED Requirements

### Requirement: アカウントレジストリの定義と所在
使用量観測の対象となる Claude アカウントは、レジストリファイル `~/.claude/accounts.json`（環境変数 `CLAUDE_ACCOUNTS_FILE` で上書き可能）にスロットの配列として定義されなければならない（SHALL）。各スロットは次のフィールドを持つ:

- `id`: スロットの識別子（snapshot のキーになる。英数字とハイフン）
- `label`: statusline に表示する短いラベル（1〜4 文字程度を想定）
- `securestorage`: そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` または空文字は既定アカウント（`CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定の状態）を意味する

リポジトリはレジストリの雛形または生成手段（コマンドか README の手順）を提供しなければならない（SHALL）。実ファイル自体はリポジトリに含めない。

#### Scenario: 複数スロットを読む
- **WHEN** 2 つのスロット（既定アカウントと `securestorage` を持つアカウント）を含むレジストリを与えて読み取り処理を実行する
- **THEN** 2 つのスロットが宣言順に、それぞれ `id` / `label` / `securestorage` を保って得られる

#### Scenario: 環境変数でレジストリの場所を上書きする
- **WHEN** `CLAUDE_ACCOUNTS_FILE` に別のパスを設定して読み取り処理を実行する
- **THEN** `~/.claude/accounts.json` ではなく、指定されたパスのレジストリが読まれる

### Requirement: レジストリ不在時は既定スロット 1 つに縮退する
レジストリファイルが存在しない、読み取れない、または JSON としてパースできない場合、読み取り処理は「既定アカウントを指すスロットが 1 つだけ存在するレジストリ」として扱わなければならない（SHALL）。この縮退はエラーとして扱ってはならない（MUST NOT）。

これにより、レジストリを導入していない環境（既定の環境）では使用量観測の挙動が一切変わらない。

#### Scenario: レジストリが存在しない
- **WHEN** レジストリファイルが存在しない状態で読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

#### Scenario: レジストリが壊れている
- **WHEN** JSON としてパースできない内容のレジストリファイルを与えて読み取り処理を実行する
- **THEN** 既定アカウントを指すスロットが 1 つだけ得られ、処理はエラーにならない

#### Scenario: スロットが空配列
- **WHEN** スロットが 0 件のレジストリを与えて読み取り処理を実行する
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
