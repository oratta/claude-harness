## 1. 実行ファイル

- [x] 1.1 `bin/cld` を書く（probe → selector → `env`/`env -u` で `claude`、selector 非 0 はそのまま終了、`CLD_DEFAULT_ARGS` を先頭に、`CLAUDE_HARNESS_SCRIPTS` 未設定なら自分の位置から `../scripts`）。実行権限を付ける。触る範囲: `plugins/dev-workflow/bin/cld`（新規）
- [x] 1.2 `bin/cld-account` を書く（slot id 必須、usage は stderr に出して exit 2）。触る範囲: `plugins/dev-workflow/bin/cld-account`（新規）

## 2. epic-dispatch.sh の既定

- [x] 2.1 `agent_setup` で、親の環境の `CLD_DEFAULT_ARGS`（非空）を `shq` で包んだ代入として `EPIC_DISPATCH_PARENT_EPIC=` の直後に付ける（`agent_rest` の先頭に代入を置けば `agent_cmd` と `agent_cmd_for` の両方に載る。`launch` と `reply` が通る）。`EPIC_DISPATCH_CLAUDE_CMD` 未設定時の既定を `bin/cld` の絶対パス（空白の有無によらず無条件に `shq` で包む。無ければ `cld`）にし、52 行目のコメントを直す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:52-52`、`plugins/dev-workflow/scripts/epic-dispatch.sh:444-454`

## 3. 文書

- [x] 3.1 README「Claude アカウントの起動時選択」の関数の貼り付け例と説明を、PATH 1 行 + `CLD_DEFAULT_ARGS` 1 行と「関数・`unalias` を消す」手順に置き換える（#501 の食い違いの解消を含む）。他の子（#1233〜#1236）の記述は書かない。触る範囲: `plugins/dev-workflow/README.md:15-15`、`plugins/dev-workflow/README.md:40-80`
- [x] 3.2 `epic.md` の `cld` の説明（既定は `bin/cld`、`--dangerously-skip-permissions` は `CLD_DEFAULT_ARGS` から来て、`launch` / `reply` が親の環境の値を子に渡す。親に値が無ければ子は許可確認で止まる）と `SKILL.md` の同じ説明を直す。触る範囲: `plugins/dev-workflow/skills/develop/references/epic.md:136-140`、`plugins/dev-workflow/skills/develop/SKILL.md`（`cld` を含む行を `git grep -n cld` で探す）
- [x] 3.3 `plugins/dev-workflow/changes/1232.md` を書く。触る範囲: `plugins/dev-workflow/changes/1232.md`（新規）

## 4. テスト

- [x] 4.1 `account-selector.bats` の「README zsh functions」3 本を、`bin/cld` / `bin/cld-account` を PATH 経由で呼ぶテストにし、次を足す: symlink 経由の呼び出し、`CLAUDE_HARNESS_SCRIPTS` の上書き、`cld-account` の slot id 欠落（exit 2・`claude` 不起動）、`cld` と `cld-account` の両方への `CLD_DEFAULT_ARGS` の適用、`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` を上書きしないこと。触る範囲: `plugins/dev-workflow/tests/account-selector.bats:320-370`（`extract_readme_functions` の定義も）
- [x] 4.2 `epic-dispatch.bats` の起動コマンドの照合を既定の語（絶対パス）に合わせ、次のテストを足す: 未設定・非ログインの既定（PATH に `cld` が無い）、Orca の `terminal create` と tmux の `start` の両経路で `CLD_DEFAULT_ARGS='…'` の代入が起動コマンドに載ること、`reply` の起動し直しにも載ること、親に値が無いとき代入が付かないこと、起動コマンドを非ログインの `sh -c` で実行すると `bin/cld` 経由でスタブの `claude` に `CLD_DEFAULT_ARGS` の語が届くこと。`--command` の照合は代入に続くコマンド部分を見る。bats の `setup` で `CLD_DEFAULT_ARGS` を unset する（既存の `EPIC_DISPATCH_*` と同じ扱い）。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`（`cld --settings` を含む 644・729・760・768・794・4201 行付近、3409-3410 行の SKILL 文言の照合）
- [x] 4.3 `tests/injection-budget.bats` が通ることを確認する（README・SKILL.md の description は常時注入でないが、`SKILL.md` の `description` を変えた場合は予算を見る）
