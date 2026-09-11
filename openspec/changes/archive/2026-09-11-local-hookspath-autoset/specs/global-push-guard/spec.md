## MODIFIED Requirements

### Requirement: 層の優先関係と副作用の明文化

SKILL.md は次の 3 点を明記しなければならない (MUST): (1) リポジトリローカルの `core.hooksPath` はグローバル設定より優先されるが、それは**その clone のローカル設定に `core.hooksPath` が入っているときだけ**であり、リポジトリが `.githooks/pre-push` を追跡していても、ローカル設定の無い clone ではグローバル層だけが使われること。loop-dev-agent 導入済み repo（flatmate の `new-resident` が `<repo>/.githooks/pre-push` を設置する）でも、ローカル設定が入っている clone でだけローカル層（main 拒否込み）が使われること、(2) グローバル `core.hooksPath` の設定は、自前で `core.hooksPath` を設定していないリポジトリの `.git/hooks/` 直置きフックを無効化すること、(3) その回避方法が当該リポジトリでの `git config core.hooksPath .git/hooks` であること。ローカル層の設置者として解散した `loops-dev-agent-install` を名指ししてはならない (MUST NOT)。

#### Scenario: 優先関係が説明されている

- **WHEN** SKILL.md を読む
- **THEN** ローカル設定がグローバルより優先されることと、その帰結（loop-dev-agent 導入済み repo でも、ローカル設定が入っている clone では厳しい方＝ローカル層が使われ、入っていない clone ではグローバル層だけが使われる）が説明され、`loops-dev-agent-install` の文字列は無い

#### Scenario: 優先関係の成立条件がローカル設定の有無として書かれている

- **WHEN** SKILL.md の層の構成の節を読む
- **THEN** ローカル層が使われるのはその clone のローカル設定に `core.hooksPath` が入っているときだけで、リポジトリが `.githooks/` を追跡しているだけでは使われないことが読み取れる

#### Scenario: .git/hooks 無効化の副作用と回避方法が示されている

- **WHEN** SKILL.md の注意事項を読む
- **THEN** `.git/hooks/` 直置きフックが無効化されること、および `git config core.hooksPath .git/hooks` で回避できることが示されている

## ADDED Requirements

### Requirement: PR 運用リポジトリでリポジトリローカルのフックを有効にする手順

SKILL.md は、`.githooks/` を追跡している PR 運用のリポジトリでリポジトリローカルのフックを有効にする手順を示さなければならない (MUST)。手順は次を含まなければならない (MUST): (a) 各 clone で `git config --local core.hooksPath .githooks` を実行すること、およびローカル設定は同じ clone のワークツリー間で共有されるので clone ごとに 1 回でよいこと、(b) 有効にするとその clone ではグローバルのフック（マージ済み PR のブランチへの push 拒否）が走らなくなるので、ローカルの pre-push からグローバルの pre-push を呼ぶか、同じチェックを内包すること、(c) 設定の有無を `git config --local --get core.hooksPath` で確認できること、(d) worktree プラグインの wt-setup がワークツリー作成時にこの設定を自動で入れること（ローカルに値があるとき・`.git/hooks/` に既存のフックがあるときは入れないこと）、(e) ローカル設定が無いために追跡しているフックが走らなかった過去の事故例を 1 件以上挙げること。

グローバルの pre-push を呼ぶ例を示す場合、例は次の条件を満たさなければならない (MUST): main/master への直接 push を自分で拒否すること、標準入力を変数に保持して自分の判定とグローバルのフックの両方に同じ内容を渡すこと、グローバルのフックの場所を `git config --global --type=path --get core.hooksPath` で引くこと、そのディレクトリが自分自身のディレクトリと（`pwd -P` で解決して）同じときは呼ばないこと、呼んだときはグローバルのフックの終了コードで終わること。`--type=path` は git 2.18 以上を前提とする。

#### Scenario: 有効化の手順と確認方法が書かれている

- **WHEN** SKILL.md のリポジトリローカルのフックを有効にする節を読む
- **THEN** `git config --local core.hooksPath .githooks`、clone ごとに 1 回でよいこと、`git config --local --get core.hooksPath` による確認、wt-setup の自動設定、過去の事故例が 1 件以上書かれている

#### Scenario: ローカルの pre-push がグローバルのフックへ引き継ぐ

- **WHEN** SKILL.md の例にあるローカルの pre-push を、グローバルの `core.hooksPath` に別のディレクトリが入った状態で、main 以外のブランチへの push として実行する
- **THEN** グローバルの pre-push が同じ引数と同じ標準入力で呼ばれ、ローカルの pre-push はその終了コードで終わる

#### Scenario: ローカルの pre-push は main への push を自分で拒否する

- **WHEN** 同じ例のローカルの pre-push を main への push として実行する
- **THEN** 非 0 で終了する

#### Scenario: グローバルの設定が自分自身を指すときは呼ばない

- **WHEN** グローバルの `core.hooksPath` がローカルの pre-push と同じディレクトリを指す状態で、同じ例を main 以外のブランチへの push として実行する
- **THEN** 自分自身を再帰的に呼ばずに 0 で終了する
