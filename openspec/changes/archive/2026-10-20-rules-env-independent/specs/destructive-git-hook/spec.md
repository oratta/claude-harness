## MODIFIED Requirements

### Requirement: ルール本文と hook の分担

`rules/destructive-git-guard.md` は、次の 4 点を「hook との分担」の節に持たなければならない（MUST）。節は「dev-workflow プラグインの hook が入っていれば」の条件つきで書き、hook が入っていない環境では一覧の操作もこのルールだけが止めることを書く（MUST）: 一覧の操作は dev-workflow の hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く。拒否されたセッションでは承認後も主が自分で実行する）／hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`、スクリプトファイル経由の git は止まらないこと／サブエージェントから呼ばれたときは確認画面を出さずに拒否され、子は打ち直さず作業を止めて親に返ること／画面を見ている人のいないセッション（起動時に無人の印を付けたセッション）でも確認画面を出さずに拒否されるので、チャンネルで主に承認を求めること。印の環境変数の名前はルール本文に書かなくてよい（MAY。起動する側の設定で、ルールを読む Claude が付け外しするものではないため）。ルール本文は、オーナーの環境のパス（`~/.claude/rules-archive/` など）を書いてはならない（MUST NOT）。それ以外の既存の文は外さず（`always-on-injection-scope` の「縮約は削除ではなく移設」と、一覧・目印を本文に残す要件のため）、目印「例外なく事前承認」を含む文は変えてはならない（MUST NOT）。`rules/README.md` の該当行はこの分担に合わせて直さなければならない（MUST）。`DEV_WORKFLOW_GIT_GUARD_FORCE` はルール本文に書いてはならない（MUST NOT）。

この要件の検査の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。入力の出どころは、テストの実行時点の `rules/destructive-git-guard.md` と `rules/README.md` の本文で、テストが自分で読む。拾う誤りは、「hook との分担」の節の語（サブエージェント・確認画面を出さず・打ち直さず・親に返る・画面を見ている人のいないセッション・チャンネル・主に承認を求める）の欠落、条件の語（「入っていれば」）の欠落、`rules-archive` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の混入。通してよい具体例は、条件の文の言い回しの良し悪し、節の語は揃っているが事実が hook の実際の振る舞いとずれている文（hook 側の spec の検査と人のレビューが見る）。見つかる穴をすべて塞ぐことは完了条件にしない。

#### Scenario: ルール本文に hook との分担がある

- **WHEN** `rules/destructive-git-guard.md` を読む
- **THEN** hook が一覧の操作を止めること、拒否されたら承認後も主が実行すること、hook で止まらないもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）、サブエージェントは確認画面を出さずに拒否されて親に返ること、画面を見ている人のいないセッションでも確認画面を出さずに拒否されてチャンネルで主に承認を求めることが書かれ、`tests/always-on-injection-scope.bats` の目印がすべて残っている

#### Scenario: hook が無い環境でも読める

- **WHEN** dev-workflow プラグインが入っていない環境で `rules/destructive-git-guard.md` を読む
- **THEN** 「hook との分担」の節が「hook が入っていれば」の条件つきで書かれ、hook が無ければ一覧の操作もこのルールだけが止めることが書かれている

#### Scenario: ルール本文にオーナーの環境のパスが無い

- **WHEN** `rules/destructive-git-guard.md` を `rules-archive` と `marketplaces/` で検索する
- **THEN** 見つからない

#### Scenario: 上書きの環境変数がルールに無い

- **WHEN** `rules/destructive-git-guard.md` を `DEV_WORKFLOW_GIT_GUARD_FORCE` で検索する
- **THEN** 見つからない

#### Scenario: README の該当行が子と無人のセッションの扱いに触れる

- **WHEN** `rules/README.md` の `destructive-git-guard.md` の行を読む
- **THEN** サブエージェントは確認画面を出さずに拒否されて親に返ること、画面を見ている人のいないセッションでも確認画面を出さずに拒否されてチャンネルで主に承認を求めることが書かれている
