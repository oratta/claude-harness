# local-hookspath-autoset

## Why

git がフックを探すのは `core.hooksPath` が指す 1 か所だけである。push-guard-setup スキルがグローバルに `core.hooksPath=~/.githooks` を設定した PC では、リポジトリが `.githooks/pre-push`（main/master への直接 push 拒否など）を追跡していても、その clone のローカル設定に `core.hooksPath .githooks` が入っていなければ一度も実行されない。

oratta/kg-recruit でこの状態が見つかった（kg-recruit#126）。自律ループを導入した clone（住人のもの）にだけローカル設定が入っており、人間のメインチェックアウトと全ワークツリーでは main を守るフックが死んでいた。ローカル設定は clone ごとの設定（同じ clone のワークツリー間では共有）で、新しく clone したりリポジトリを別の場所で開いたりすると入っていない。

push-guard-setup の SKILL.md と spec `global-push-guard` は「ローカルの `core.hooksPath` はグローバル設定より優先されるので、loop-dev-agent 導入済み repo では従来どおりローカル層が使われる」と書いているが、これは**ローカル設定が入っている clone でだけ**正しい。読んだ人が「リポジトリにフックがあれば効いている」と誤解する書き方になっている。

kg-recruit 側は PR #127 で、`.githooks/pre-push` の末尾からグローバルの pre-push を呼び、kg-recruit 自身の SessionStart hook で `core.hooksPath` を自動設定する対処をした。harness 側では、どのリポジトリでも同じ設定漏れが起きないよう、ワークツリーのセットアップ時に自動で設定し、手順を文書に残す（リポジトリのオーナーが承認済み）。

## What Changes

- `plugins/worktree/scripts/wt-setup.sh`: リポジトリが `.githooks/` を git で追跡していて、ローカルの `core.hooksPath` が未設定なら `git config --local core.hooksPath .githooks` を設定し、1 行出力する。ローカルに既に値があれば上書きしない（husky などの設定を壊さない）。`.githooks/` を追跡していなければ何もしない。ワークツリーは clone の設定を共有するので、ワークツリーで 1 回走ればメインチェックアウトにも効く
- `plugins/worktree/skills/wt-setup/SKILL.md` と plugin.json の description にこの自動設定を追記する
- `plugins/dev-workflow/skills/push-guard-setup/SKILL.md`: 層の構成の節の優先関係の説明を「ローカル設定が入っている clone でだけ成り立つ」ことが分かる形に直し、PR 運用のリポジトリでリポジトリローカルのフックを有効にする手順（clone ごとに 1 回の設定・グローバルのフックへの引き継ぎ・設定漏れの確認方法・wt-setup の自動設定）を足す
- 両プラグインの version を上げる（worktree は minor、dev-workflow は patch）

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `global-push-guard`: Requirement「層の優先関係と副作用の明文化」の (1) を、ローカル設定が入っている clone でだけ成り立つ形に書き換える。Requirement「PR 運用リポジトリでリポジトリローカルのフックを有効にする手順」を追加する
- `worktree-setup-script-integrity`: Requirement「wt-setup.sh は追跡されている .githooks をリポジトリローカルのフックとして有効にする」を追加する

## Impact

- `plugins/worktree/scripts/wt-setup.sh`（関数 1 つとその呼び出し。既存ステップの処理は変えない）
- `plugins/worktree/tests/setup-script.bats`（回帰テストの追加）
- `plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/.claude-plugin/plugin.json`・`.claude-plugin/marketplace.json`
- `plugins/dev-workflow/skills/push-guard-setup/SKILL.md`・`plugins/dev-workflow/tests/push-guard-setup.bats`・`plugins/dev-workflow/.claude-plugin/plugin.json`・`plugins/dev-workflow/CHANGELOG.md`
- **挙動の変化**: `.githooks/` を追跡しているのにローカル設定を入れていなかったリポジトリでは、ワークツリー作成を境に（その clone のメインチェックアウトを含めて）`.githooks/` のフックが走り始める。同時に、その clone ではグローバルのフック（マージ済み PR のブランチへの push 拒否）が走らなくなる。ローカルの `.githooks/pre-push` が同じマージ済みチェックを内包していれば失うものは無いが、kg-recruit のように実際には main 拒否だけを持つリポジトリもある（kg-recruit#127 はこのためにグローバルのフックを呼ぶ形にした）。そうしたリポジトリでは `.githooks/pre-push` からグローバルのフックを呼ぶ必要がある（push-guard-setup に追記する手順）
