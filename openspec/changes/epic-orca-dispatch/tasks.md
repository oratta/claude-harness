## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/epic-dispatch.bats` を新しく作り、スタブの仕組みを書く: `BATS_TEST_TMPDIR` にスタブ置き場を作り、`orca`・`gh`・`git`・`sleep` のスタブが自分の名前と引数（`printf '%q '`）を共通のログに 1 行ずつ追記する。`orca` の返り値はサブコマンドごと（`worktree current` の exit code と `--json`、`worktree list --json`、`set` / `create` の成否）に設定ファイルで切り替える。`gh` の返り値は呼び出し回数ファイルと子番号ごとの設定ファイルで制御する。スクリプトは `PATH="<スタブ置き場>:/usr/bin:/bin"` で走らせる（`jq` は実物）。テスト名は ASCII のみ、途中に素の `[[ ]]` を置かない
- [ ] 1.2 `route` の検査を書く: `orca` スタブなしで子 2 件 → `subagent`／`orca` スタブありで `worktree current` が exit 1、子 2 件 → `subagent`／Orca 管理下で子 1 件 → `subagent`／Orca 管理下で子 2 件 → `orca`／番号でない引数（`#12` など）→ exit 1
- [ ] 1.3 `launch` の検査を書く: 呼び出しログが `orca worktree current --json`・`git rev-parse --show-toplevel`・`git fetch origin main`・`orca worktree set --worktree path:<親> --issue <epic>`・`orca worktree list --json`・子ごとの `orca worktree create ...` の順で、create の引数に `--parent-worktree path:<親>`・`--name issue-<N>`・`--issue <N>`・`--base-branch origin/main`・`--agent claude`・`/develop #<N>` で始まりエピック番号を含む `--prompt` があること／`--note` の文が prompt に入ること／`EPIC_DISPATCH_BASE` で起点が変わり、`--base` が環境変数より優先すること（fetch と `--base-branch` の両方）／stdout が子ごとの `launched <N>`／一覧に同じ `repoId`・同じ `linkedIssue`・archive されていないワークツリーがある子は create が呼ばれず `skipped <N>` で exit 0（`repoId` が違う、または archive 済みなら `launched`）／`worktree current`・fetch・set・list の失敗で create が 0 回かつ exit 1／1 件の create 失敗で `failed <N>` を出しても残りの子を作り exit 1／`orca` スタブなしで何も呼ばれず exit 1
- [ ] 1.4 `wait` の検査を書く: 途中から閉じる子で `closed <N>` と exit 0／全部 open で `--timeout 0` のとき `timeout <N>...` と exit 2／`sleep` スタブに `--interval` の値が渡ること／`EPIC_DISPATCH_TIMEOUT=0` だけでも timeout になり、フラグが環境変数より優先すること／`gh` が失敗し続けると 3 ポーリング後に `error gh <N>` と exit 1／子 11 だけが失敗し続け子 12 が `open` のとき 3 ポーリング後に `error gh 11` と exit 1／`open` / `closed` 以外の値（空文字）も失敗に数えること／失敗の無いポーリングを挟むと数え直すこと／一部の子の `gh` が失敗しても別の子が閉じていれば `closed` が優先されること／子 0 件・非負整数でない間隔で exit 1／どの終わり方でも stdout がちょうど 1 行であること
- [ ] 1.5 SKILL.md の記述の検査を同じファイルに書く: 「エピックの扱い」の「回し方」に `epic-dispatch.sh route`・`launch`・`wait`・`run_in_background`・振り分け条件（2 件以上・`orca`・Orca 管理のワークツリー）・サブエージェント方式・経路を途中で変えないこと・再開時に `回し方:` のコメントから引き継ぐこと・unmanned はサブエージェント方式・`state_reason`・`子 #N マージ → 残り k 件`・`見送り`・timeout のあと再び待つこと・子のタブでの質問は検知できないこと・`--dangerously-skip-permissions`・自動でマージしないことが書かれている／「前提」表に `orca` の行があり、Orca 管理外のときもサブエージェント方式になると書かれている
- [ ] 1.6 `bash scripts/test.sh epic-dispatch` で新しいテストが落ちること（Red）を確かめる

## 2. 実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/epic-dispatch.sh` を実装する（`route` / `launch` / `wait`。設計は design.md の「`launch` の手順と引数」「`wait` の出力・exit code・待ちの上限と間隔」のとおり。冒頭のコメントに使い方・出力・exit code を書く）。実行権限を付ける
- [ ] 2.2 `plugins/dev-workflow/skills/develop/SKILL.md` の「前提」表に `orca` の行を足す（使い方: エピックの子を Orca の子ワークツリーで独立セッションとして起動する／無いとき・本体が Orca 管理外のワークツリーにいるとき: エピックはサブエージェント方式で回す）
- [ ] 2.3 同じ SKILL.md の「エピックの扱い」→「回し方」を書き直す: 経路の決め方（`route`、最初の開始時に 1 回、エピックへの `回し方:` の 1 行コメント、再開時はそのコメントから引き継ぐ、unmanned はサブエージェント方式）、Orca 経路の本体の手順（`launch` → `wait` を `run_in_background: true` → 出力ごとの動き。`closed` では `state_reason` で `マージ` と `見送り` を分ける、`timeout` では報告したうえで再び待つ、子のタブでの質問は検知できない、再開時の起動済みの子は `skipped` で見分ける）、子セッションは `--dangerously-skip-permissions` で動き許可の確認画面が出ないこと、マージを止めているのは develop と pr-review-gate の規則と hooks で、マージは人の承認であること、サブエージェント方式の今の記述（`isolation: "worktree"`・並列）、両経路に共通のスタック PR と新しい子 issue の記述。既存の `develop-skill.bats` のエピックの検査が通る語を残す
- [ ] 2.4 `bash scripts/test.sh epic-dispatch develop-skill` が通ること（Green）を確かめる

## 3. 版と記録

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の版を上げ、`plugins/dev-workflow/CHANGELOG.md` に追記する（着手時に origin/main の版を確かめ、先に上がっていればその次にする）

## 4. 確認（自動）

- [ ] 4.1 `bash scripts/test.sh` を引数なしで全件実行し、exit code と件数を記録する。`scripts/lint.sh`（shellcheck）も通す
- [ ] 4.2 `openspec validate epic-orca-dispatch --strict` が通ることを確かめる

## 5. 手動確認（実機。自動テストの外）

この 2 件はチェックボックスにしない（実エピックの進行と #402 の残りの子の完了を待つため、この change の archive を止めない）。進み具合は issue #420 の受け入れ条件のチェックで追う。

- 実エピックで 1 回通す: 並列にできる子が 2 件以上あるエピックで `/develop <エピック>` を起動し、`route` が `orca` を返すこと、`launch` で子が起動され Orca の UI で親の下に並ぶこと、子の PR がマージされたあと `wait` が `closed <N>` で終わって本体が起こされ、依存が解けた次の子が自動で `launch` されることを確かめ、エピックのコメントに記録する
- トークン量の比較: #402 の残りの子 #284・#283 が終わった時点で、子セッションごとのトークン量と、今のサブエージェント方式で 1 本体に集まる量を比べた数字を #420 のコメントに残す
