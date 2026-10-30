## ADDED Requirements

### Requirement: 開発用 clone の場所の変数が未設定のとき、harness のリポジトリでだけ警告する

worktree プラグインは、SessionStart で環境変数 `CLAUDE_HARNESS_DEV_DIR` が未設定か空であり、かつ作業ディレクトリが `oratta-claude-harness` の marketplace.json を最上位に持つ git リポジトリ（開発用 clone またはその worktree）のときだけ、変数の名前と入れ方の案内を含む 1 行の警告を利用者に出さなければならない（MUST）。それ以外では何も出力してはならない（MUST NOT）。どの場合もセッションの開始を止めてはならず、終了コードは 0 でなければならない（MUST）。

この判定の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 想定する入力の出どころ: セッションが継承した環境変数 `CLAUDE_HARNESS_DEV_DIR`、フックを起動した作業ディレクトリ、そのリポジトリ最上位の `.claude-plugin/marketplace.json`。利用者が自分の settings.json や shell の設定で入れた値を、そのまま継承して読む
- 拾う誤り: 変数が未設定のまま harness のリポジトリで始めること／空文字のまま始めること
- 通してよい入力の具体例: 値が存在しないパスや開発用 clone でないパスでも、非空なら警告しない（値の中身は検証しない）／harness の marketplace.json の name を持つ別の clone でも警告の対象になる／marketplace.json が壊れていて name を読めないときは無出力
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: harness のリポジトリで未設定

- **WHEN** 変数が未設定で、作業ディレクトリが harness の開発用 clone の worktree である
- **THEN** 変数名と README の案内を含む警告が 1 行出て、終了コードは 0

#### Scenario: 変数が設定済み

- **WHEN** 変数に値があり、作業ディレクトリが harness のリポジトリである
- **THEN** 何も出力されない

#### Scenario: harness を直さない利用者

- **WHEN** 変数が未設定で、作業ディレクトリが harness 以外のリポジトリまたは git の外である
- **THEN** 何も出力されず、終了コードは 0

### Requirement: README が変数の意味と入れ方を説明する

README の導入手順（ローカル開発の節）は、`CLAUDE_HARNESS_DEV_DIR` が開発用 clone の場所を指すこと、未設定だと何が困るか、`~/.claude/settings.json` の `env` への入れ方を書かなければならない（MUST）。

#### Scenario: README を読んで入れられる

- **WHEN** 利用者が README のローカル開発の節を読む
- **THEN** 変数の意味・未設定時の影響・`~/.claude/settings.json` の `env` への入れ方が書かれている
