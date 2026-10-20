## 1. #1120 の取り込み

- [ ] 1.1 PR #1120（#1106、同時に枠を使う子の上限）がマージされていれば `git fetch origin` のあと origin/main に rebase し、`bats plugins/dev-workflow/tests/epic-dispatch.bats` が通ることを確かめる。まだマージされていなければ design.md Decision 10 の最後の項に従い、#1120 の差分を取り込まずに進め、5.1 を #1120 のマージ後に回す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:323-437（cmd_launch。#1120 の max_parallel_setup と使用中の数え方が入る場所）

## 2. 状態の記録の読み書き

- [x] 2.1 `epic-state.sh` を新しく作り、置き場の組み立て（`EPIC_STATE_ROOT` の相対パスの解決、`<o>.<r>-<E>/<o>.<r>-<N>.json`、origin の URL の 3 つの形から小文字の `<owner>/<repo>` を読む。GitHub 以外は exit 1）・読めない記録の判定・子の引数の解釈（番号だけ／`<owner>/<repo>#<N>`、エピックと同じリポジトリなら番号と同じ扱い）・一時ファイルからの `mv`・`mkdir` の排他（`EPIC_STATE_LOCK_TIMEOUT` の検査、残ったロックの案内）・項目の読み書き（知らない項目を残す）・今のワークツリーのパスでの記録の検索・親の側の照合（番号だけは `number` と記録の `epic` のリポジトリ、`<owner>/<repo>#<N>` は `child`。origin を読まない）を関数で置く。`orca` の語を書かない。触る範囲: plugins/dev-workflow/scripts/epic-state.sh（新規）
- [x] 2.2 `epic-dispatch.sh` から `epic-state.sh` を source し、子の引数の検査（`check_children`）を `<owner>/<repo>#<N>` も受ける形にする（出力は受けた形のまま。`#12`・`owner/repo#` などの欠けは使い方を出す）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-175（仕様コメントと usage・is_num・check_children）
- [x] 2.3 bats の共通の setup で `EPIC_STATE_ROOT` を `BATS_TEST_TMPDIR` の下に向け、記録を作るヘルパーを足す。記録の書式・排他（残ったロックで `mark` が `failed`）・一時ファイルが残らないことのテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:34-337（setup とスタブ）

## 3. 子の側（mark・route）

- [x] 3.1 `mark` を、今のワークツリーのパスで自分の記録を探して `status` / `stop` を書き換える形にし、書けたあとに Orca の印へ写す（写しの失敗は stderr に出して成功扱い）。`skipped <N> no-workspace` / `not-linked` / `not-stopped`・`failed <N>` を spec のとおりにする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:621-662（cmd_mark）
- [x] 3.2 `route` と `launch` の子のセッションの判定を、`EPIC_DISPATCH_PARENT_EPIC` か今のワークツリーの記録で行い、`parentWorktreeId` を見ないようにする。stderr の `parent epic:` を記録の `epic` から出す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:177-211（parent_from_worktree・cmd_route）
- [x] 3.3 mark と route のテストを、Orca の印・`parentWorktreeId` を置く形から記録を置く形に直し、spec の Scenario（止まった印・再開の印・記録の無いワークツリー・起動し直した子の nested・写しの失敗・Orca 管理外）を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:338-590（route）、plugins/dev-workflow/tests/epic-dispatch.bats:1135-1289（mark）

## 4. 親の見張り（wait・pending-owner・notify-closed・reply・reap）

- [x] 4.1 `wait` を、ポーリングごとに渡された子の記録を 1 回ずつ読む形にし、`--watch-done` は `status` が `done`、`--watch-stopped` は `stop` を排他つきで `stopped` → `stopped-seen` に書き換えてから Orca へ写す形にする。子 issue の state は、エピックと同じリポジトリの子と記録の無い子は今のまま `repos/{owner}/{repo}`、違う子だけ `repos/<repo>` で読む。読めない記録は失敗したポーリングに数える。`--resolve` の判断と送り方は変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:769-909（cmd_wait）、plugins/dev-workflow/scripts/epic-dispatch.sh:665-768（repost_hint・decide_relaunch・resolve_stopped の子のワークツリーの見つけ方）
- [x] 4.2 `pending-owner`・`notify-closed`・`reply`（deliver_reply）の子のワークツリーの見つけ方と状態の判定を記録に置き換える（2 件以上は `failed <N> ambiguous-worktree`、読めない記録は `failed <N> state-unreadable`、`pending-owner` は飛ばす）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:442-616（deliver_reply・cmd_reply・cmd_notify_closed）、plugins/dev-workflow/scripts/epic-dispatch.sh:912-933（cmd_pending_owner）
- [x] 4.3 `reap` を記録の `worktree` で安全確認する形にする（`gh pr list`・`git ls-remote` の呼び出しの形は変えない）。読めない記録は `kept <N> state-unreadable`。記録の無い子と `worktree` のディレクトリが無い（`[ -d ]` が偽）子は `gone <N>`（後者は記録を消す）、`reaped <N>`（`branch-kept` を含む）で記録を消す。`kept <N> not-child` を出さない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:937-1089（cmd_reap）
- [x] 4.4 wait・reap・reply・wait --resolve・notify-closed・pending-owner のテストを、一覧の `workspaceStatus` / `comment` を置く形から記録の `status` / `stop` を置く形に直し、出力が今と同じことを確かめる。spec の Scenario（Orca の印だけでは起きない・別の親の記録は見ない・片付け済みの子は gone・`owner/repo#N` の子は `repos/<repo>/issues/<N>` を読む・同じリポジトリの子は `repos/{owner}/{repo}` のまま・読めない記録）を足す。gh のスタブの `repos/` の照合（`wait: gh uses the REST issues endpoint` のテスト、1313 行付近）が別リポジトリの子でも働くようにする。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1290-2227（wait・reap）、plugins/dev-workflow/tests/epic-dispatch.bats:2699-3397（reply・wait --resolve・notify-closed・pending-owner）

## 5. 起動（launch）と、adopt・clear

- [ ] 5.1 `launch` を、`deferred` の判定のあとに記録を書いてから子のワークツリーを作る形にする。作成に失敗したら記録を消し、作れたら `worktree`・`branch`・`session` を書き足し、端末・起動待ち・送信の失敗は `launch_failed` に段を書く。別リポジトリの子は `failed <child> other-repo`。`worktree` が空の記録が残っていれば上書きして作成に進む。自分の記録が読めなければ `failed <N> state-unreadable`。#1120 の枠の数え方を、全エピックのディレクトリを横断した `parent_worktree` が今のワークツリーの記録に置き換え、ほかの子の読めない記録は 1 枠に数える（上限の値と `deferred` の出し方は変えない）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:323-437（cmd_launch）、plugins/dev-workflow/scripts/epic-dispatch.sh:242-322（agent_setup・pick_session_term・shell_start の段の名前）
- [ ] 5.2 新しいサブコマンド `adopt <epic> <child>...`（`base` は `EPIC_DISPATCH_BASE`、空なら `main`。前提の失敗は stdout を空にして exit 1）と `clear <epic>`（番号の検査・`/`・`..`・空の置き場・`/` や `$HOME` そのもの・シンボリックリンクを消さない）を足し、usage と仕様コメントと末尾の振り分けに加える。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-160（仕様コメント・usage）、plugins/dev-workflow/scripts/epic-dispatch.sh:1090-1103（サブコマンドの振り分け）
- [ ] 5.3 launch のテストを記録で確かめる形に直し、spec の Scenario（記録の置き場・項目・origin を読めない・作成失敗で記録が残らない・送信失敗で次は skipped・別リポジトリの子は other-repo・記録で数えた使用中で deferred）と、adopt・clear の Scenario を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:591-1134（launch）、plugins/dev-workflow/tests/epic-dispatch.bats（末尾に adopt・clear を新規）

## 6. 手順書と変更の記録

- [ ] 6.1 SKILL.md の回し方の手順 7 に `adopt` を `reap` の前に足し、手順 3・4・7 の「`wait` を呼ばずに待ちを終える」箇所に `clear` を足す。完了条件の節に状態ディレクトリが消えていることの確認を足す。子の状態の正本が記録で Orca の画面の印は写しだと書く。「エピックの子が主の返事を待って止まるとき」の印の説明を記録に合わせる。手順 3 の「`ambiguous`・`not-child` は確かめず残す」から `not-child` を外し、`state-unreadable` を確かめず残す扱いを足す。手順 6 の「`--watch-done` / `--watch-stopped` を付けた `wait` が stdout 空で exit 1 なら親ワークツリーで開き直す」を消し、`launch` の exit 1 と `adopt` の stdout 空の exit 1 の報告として書き直す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:341-368（エピックの子が主の返事を待って止まるとき）、plugins/dev-workflow/skills/develop/SKILL.md:417-459（回し方の手順 3・4・6・7・完了条件）
- [ ] 6.2 reply-after-idle.md の主の返事待ちの子の見分け方を記録の `stop` に直す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:51
- [ ] 6.3 SKILL.md の skill テスト（`skill:` で始まる bats）に、手順 7 の `adopt`・待ちを終える箇所の `clear`・Orca の印が写しであること・手順 3 に `not-child` が無いことの照合を足す。`grep -rlw orca` のテストが `epic-state.sh` を足したあとも `epic-dispatch.sh` の 1 行だけを返すことを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2228-2698（skill）
- [ ] 6.4 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1123.md（新規）

## 7. 確認

- [ ] 7.1 `bats plugins/dev-workflow/tests/` が全部通り、`tests/injection-budget.bats` も通ることを確かめる。`openspec validate epic-state-files --type change --strict` が通ることを確かめる
- [ ] 7.2 実機で 1 回、Orca 環境で小さなエピック（子 1 件）を `launch` → 子の `mark stopped` → 親の `wait` の `stopped` → 子の `mark done` → `reap` → `clear` まで回し、`~/.claude/epic-state/` の記録が作られて消えることを確かめる（受け入れ条件「Orca の部品で今までどおり動く」「完了時に状態ディレクトリが消える」）。親を起動し直して `adopt` → `pending-owner` で続きが組み立て直せることも確かめる
