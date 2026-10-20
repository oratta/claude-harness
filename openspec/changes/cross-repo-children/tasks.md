## 1. 実機の確認

- [ ] 1.1 実機で `orca worktree create --parent-worktree path:<別リポジトリの親のワークツリー>` が通るかを確かめ、結果をこの行の実施欄に残す。あわせて実機で `orca repo list --json` の形（`repoId` と `path` の項目名）と `orca worktree create --repo` の selector の書式を確かめ、epic-state の spec の「Orca のリポジトリの引き当て」に書き戻す。通らなければ、別のリポジトリの子の `orca worktree create` から `--parent-worktree` を外す（親子の線は Orca の画面の写しで、正本は記録の `parent_worktree`。design の Risks）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:462-654（cmd_launch の `orca worktree create` の呼び出し）

## 2. launch（別のリポジトリの子）

- [ ] 2.0 `orca repo list --json` で clone のパスに当たるリポジトリから `repoId` と selector を決める。当たらなければ記録を書く前に `failed <child> not-in-orca`（stderr に `orca repo add` の案内。記録も枠も使わない）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:462-654（cmd_launch）
- [ ] 2.1 clone の探索を足す: `EPIC_DISPATCH_CLONES` の解釈（`<owner>/<repo>=<絶対パス>` を改行か `;` で区切る。左辺は小文字。絶対パスでない項目は無かったことにして stderr）→ `orca repo list --json` の `path`。候補ごとに `git -C <候補> remote get-url origin` を `epic-state.sh` の 3 つの形で読んで照合する。見つからなければ `failed <child> no-clone`（stderr に `EPIC_DISPATCH_CLONES` の書き方と `git clone` のコマンド）、同じ段に 2 つ以上なら `failed <child> ambiguous-clone`。どちらも exit 1・記録なし・枠なし。1 回の `launch` の中では同じリポジトリの探索を 1 回にまとめる。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:462-654（cmd_launch。535-539 行の `other-repo` の分岐を置き換える）、plugins/dev-workflow/scripts/epic-dispatch.sh:225-260（child_label・child_ref・issue_api の近くに探索の関数を足す）
- [ ] 2.2 書き込み権と起点を足す: 別のリポジトリの子だけ、clone の探索と引き当てのあと空き枠の判定より前に、`gh api repos/<o>/<r>` の応答から `.permissions.push` と `.default_branch` を 1 回で読み、`true` 以外は `failed <child> no-push`、読めなければ `failed <child> permission-lookup-failed`（stderr に認証アカウントと子のリポジトリ）。起点は `--base` / `EPIC_DISPATCH_BASE`、無ければ応答の `.default_branch`（読めなければ `failed <child> base-lookup-failed`・記録も枠もなし）。同じリポジトリの子の呼び出しの形は変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:462-654（cmd_launch）
- [ ] 2.3 判定の順序と作成を直す: 記録の読み取り → clone の探索 → 書き込み権 → 子のリポジトリの Orca の一覧で同じ issue があれば `skipped` → 空き枠（`deferred`）→ 記録を書く（`repo`・`child`・`number`・`base`・`parent_worktree`・`launcher`・`worktree`）→ `git -C <clone> fetch origin <base>` → `orca worktree create --repo <clone の selector> --parent-worktree path:<親> --issue <N> --base-branch origin/<base>`。`git -C <clone> fetch` の失敗と作成の失敗は記録を消して `failed <child>`。`worktree` が空のまま残った記録は子の `repoId` の一覧で埋めるか上書きして、枠は増やさない。親にエピックを結ぶ処理は `launch` の最初に 1 回、親の clone の fetch は同じリポジトリの子が 1 件以上あるときだけ。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:462-654（cmd_launch）
- [ ] 2.4 書式を別リポジトリのエピックの形にする: 起動の最初の入力 `/develop #<N> （エピック #<E> の子。エピックのリポジトリ <owner>/<repo>。…）`（先頭は同じリポジトリの子と同じ形のまま）、`EPIC_DISPATCH_PARENT_EPIC=<owner>/<repo>#<E>`（`launch` だけでなく `agent_setup` を呼ぶ全経路。値は記録の `epic` と `repo` から）、注意書き `gh issue comment <N> -R <子のリポジトリ> --body '親エピックからの注意書き: <owner>/<repo>#<E>…'`（投稿し直しのコマンドも `-R` 付き）。同じリポジトリの子は変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:462-654（cmd_launch）、plugins/dev-workflow/scripts/epic-dispatch.sh:707（relaunch の指示）、plugins/dev-workflow/scripts/epic-dispatch.sh:733-753（cmd_reply の agent_setup）、cmd_notify_closed と cmd_wait の agent_setup の呼び出し

## 3. 親の見張り（reap・reply）

- [ ] 3.1 `reap` の `gh pr list`（`--search` の形も）に別リポジトリの子では `-R <記録の repo>` を付け、base の名前を記録の `base` にし、base の照会の `git ls-remote origin` / `git fetch origin` と `git cat-file -e` を `git -C <記録の worktree>` に向け、base の先端をリポジトリごとに 1 回読み、ブランチの片付けを子の clone に向ける（`orca worktree rm` の前に `git -C <worktree> rev-parse --path-format=absolute --git-common-dir` で控える）。記録の `repo` が記録の `epic` のリポジトリと同じ子は呼び出しの形を変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1134-1278（cmd_reap。1167-1207 行が呼び出し）
- [ ] 3.2 `deliver_reply` / `notify-closed` / `wait --resolve` が子に送る返事の頭を、別のリポジトリのエピックでは `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<owner>/<repo>）経由）: ` にする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:660-665（deliver_reply の頭の組み立て）、plugins/dev-workflow/scripts/epic-dispatch.sh:1280-1333（cmd_adopt。別リポジトリの子に `none` を返す今のままを確かめるだけで変えない）
- [ ] 3.3 `stop-judge.sh` が子の引数に番号か `<owner>/<repo>#<N>` を受け、後者は `repos/<o>/<r>/issues/<N>` から読み、過去の判断を `親の判断: 子 <o>/<r>#<N> ` で探し、入力文の見出しも同じ呼び方にする。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:34-120

## 4. テスト

- [ ] 4.1 `epic-dispatch.bats` に、epic-state の spec の Scenario（`EPIC_DISPATCH_CLONES` / Orca の clone で作る・`no-clone`・origin 不一致・`ambiguous-clone`・起動済みは clone を探さず `skipped`・別リポジトリの子も `deferred`・`not-in-orca`・`no-push`・`permission-lookup-failed`・`base-lookup-failed`・子の clone の fetch の失敗・親の clone を fetch しない場合・`worktree` が空の記録・同じリポジトリの子は権限を読まない・既定ブランチと `--base`・書式の 4 箇所・返事の頭・`reap` の `-R` と `git -C`・混ぜて渡した `reap`・起動し直しの `EPIC_DISPATCH_PARENT_EPIC` の前置き・`other-repo` を返さない）を足す。スタブの `gh` / `orca` / `git` は既存の仕組みを使う。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:591-1134（launch）、plugins/dev-workflow/tests/epic-dispatch.bats（reap・reply の節）
- [ ] 4.2 `stop-judge.sh` のテストに、`<owner>/<repo>#<N>` の子と同じリポジトリの子の Scenario を足す。触る範囲: plugins/dev-workflow/tests/stop-judge.bats
- [ ] 4.3 `owner-reply-check.bats` に、別のリポジトリの子の `launch` の指示と起動し直しの指示が `<command-args>` にあるときに主の発言として数えない Scenario を足す。触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats

## 5. 手順書と変更の記録

- [ ] 5.1 SKILL.md「エピックの扱い」に、dev-workflow-develop の spec の表のとおり複数リポジトリの挙動を書く（経路の決め方・子エピックの外し方・`nested` を受けたセッション・手順 1 の `--base` の注意・手順 3〜4 のコメント・手順 6 の `failed` の新しい理由・サブエージェント方式では別のリポジトリの子を W に渡さないこと・表の読み先の行・マージ待ちの子・子が主の返事を待って止まるとき・完了条件の報告）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:479-527（エピックの扱い）、plugins/dev-workflow/skills/develop/SKILL.md:348-375（子の側）
- [ ] 5.2 `references/ci-watch.md` の親から届く返事の頭の照合に、番号のあとに `（<owner>/<repo>）` が付く形を足す。触る範囲: plugins/dev-workflow/references/ci-watch.md:85
- [ ] 5.3 `develop-skill.bats` に、dev-workflow-develop の spec の Scenario（手順書の照合）を足す。触る範囲: plugins/dev-workflow/tests/develop-skill.bats
- [ ] 5.4 変更の記録に、この change（別リポジトリの子、2/3）を追記する。触る範囲: plugins/dev-workflow/changes/1123.md

## 6. 確認

- [ ] 6.1 `bats plugins/dev-workflow/tests/` が全部通り、`tests/injection-budget.bats` も通ることを確かめる。`openspec validate cross-repo-children --type change --strict` が通ることを確かめる
- [ ] 6.2 実機で 1 回、別リポジトリの子を `launch` に渡してワークツリーができ、記録が作られ、親の `wait`・`reap` で見張れることを確かめる（受け入れ条件。結果の URL をこの行の実施欄に残す）。`no-clone` の案内の文面も画面で確かめる
