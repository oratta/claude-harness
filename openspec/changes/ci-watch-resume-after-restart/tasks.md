## 1. 前提の確かめ（通知がターンを起こすか）

- [ ] 1.1 起動し直したセッションで、背景タスクの `stopped` / `killed` の通知が入力なしにターンを起こすかを再現で確かめる。scratchpad に作った作業ディレクトリで、tmux の中で対話の `claude` を起動し、Bash の `run_in_background` で `sleep 900` を起動させてから、事故に近い形にするため `claude` のプロセスを `kill -9` で落とし、同じディレクトリで `claude --resume <セッション ID>` で起動し直して何も入力しない。確かめ方: そのセッションの会話ログ（`~/.claude/projects/<ディレクトリを変換した名前>/<セッション ID>.jsonl`）で、`<status>stopped</status>` か `<status>killed</status>` の `<task-notification>` の行のあとに `type: assistant` の行が入力なしに続くかを見る。記録（手順・セッション ID・`claude --version` の版・通知の行・続く行、または続かないこと）を issue #1085 にコメントで残す。続かなければ実装に進まず、そのコメントの URL を添えて本体に返す（本体が主に聞く内容は design.md の「1.1 で通知がターンを起こさなかったとき」）。触る範囲: なし（scratchpad の検証用ディレクトリと issue #1085 のコメントだけ）

## 2. 見張りの手順に再開の節を足す

- [ ] 2.1 `references/ci-watch.md` の末尾に節「9. 起動し直したセッションが見張りの待ちの `stopped` / `killed` の通知を受けたとき」を足す。spec の 5 つの要件（「reference は切れた見張りの再開の節を持つ」「起動し直したセッションは切れた見張りを主の入力なしに next から再開する」「決着済みの見張りは起動し直しても再開しない」「決着済みの判定の守備範囲を書く」「起動し直しの再開は同じ見張りの続きとして扱う」）の中身（きっかけと TaskStop の除外・主に聞かずに通知を受けたあとの最初のターンで `next`（`--unrelated` なし）・決着済みの判定（コメントは `gh api --paginate` で全ページ）と merged / closed のときの `CI 見張り終了:` の投稿・判定の守備範囲の段落・開始の判定と開始のコメントをしない・2 との書き分け）を書く。確かめ方: 2.4 のテスト。触る範囲: plugins/dev-workflow/references/ci-watch.md:106-110（「8. 状態ファイル」のあと）
- [ ] 2.2 `references/ci-watch.md` の 2 の「オーナーの指示で見張りを再開するとき（前のセッションが閉じて終了のコメントが残らなかった…）」の文に、自分の会話で起動した待ちの `stopped` / `killed` の通知を受けた起動し直しのセッションは 9 に従う（オーナーの指示を待たない）と書き分ける一文を足す。確かめ方: 2.4 のテスト。触る範囲: plugins/dev-workflow/references/ci-watch.md:20-31（「2. 1 つの PR を見張るのは 1 セッションだけ」）
- [ ] 2.3 develop の `SKILL.md` の「passed → 本体が … ci-watch.md の手順で CI の見張りを始める」の行の続きに、見張りの背景タスクの `stopped` / `killed` の通知を受けたら `references/ci-watch.md` の 9 に従う、と 1 行で指す（条件や手順を言い換えない）。確かめ方: 2.4 のテスト。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:149-155
- [ ] 2.4 `tests/ci-watch.bats` の reference の検査の並びに、spec の Scenario「reference に切れた見張りの再開の節がある」「再開の節は主に聞かずに最初のターンで next を実行すると書く」「決着済みの判定が書かれている」「決着済みの判定の守備範囲が書かれている」「再開の節と 2 が書き分けられている」「develop の SKILL.md は節を指すだけ」を文面で確かめるテストを足す（節 9 の範囲を切り出して語を確かめる。`--paginate` と守備範囲の段落の語があること。2 の範囲に 9 を指す文があること。SKILL.md の行に `stopped`・`killed`・`ci-watch.md` があり、`CI 見張り終了:` の判定の文を写していないこと）。確かめ方: `bats plugins/dev-workflow/tests/ci-watch.bats` が全件通り、足したテストが 2.1〜2.3 を戻すと落ちる。触る範囲: plugins/dev-workflow/tests/ci-watch.bats:444-447（job-timeout のテストのあと、「pr-review-gate / develop / gate-runner」の見出しの前）

## 3. 実機の再現（受け入れ条件）

- [ ] 3.1 受け入れ条件の再現を行う。この PR（または検証用の Draft PR）で CI が走っている間に、tmux の中の対話の `claude`（`--plugin-dir` でこの worktree の `plugins/dev-workflow` を読ませる）に `references/ci-watch.md` の 2・3 どおり `CI 見張り開始:` を投稿させて `ci-watch.sh wait` を背景で起動させ、`claude` のプロセスを `kill -9` で落とし、`claude --resume <セッション ID>` で起動し直して何も入力しない。確かめ方: 会話ログで、通知の行のあとに `ci-watch.sh next <owner/repo> <PR番号>` の Bash 呼び出しが入力なしに続くこと。手順・時刻・`claude --version` の版・該当する会話ログの行を issue #1085 にコメントで残す。1.1 の結果で受け入れ条件を縮めた場合は、縮めた条件（起動し直したあと最初のターンを親の返事か主の入力で起こす）で確かめる。触る範囲: なし（検証用のセッションと PR のコメントだけ）
- [ ] 3.2 決着済みの再現を行う。3.1 と同じ手順で、起動し直す前に PR に `CI 見張り終了:` のコメントを投稿しておく。確かめ方: 会話ログで、起動し直したセッションが `ci-watch.sh next` を実行しないこと。issue #1085 にコメントで残す。触る範囲: なし

## 4. 変更の記録

- [ ] 4.1 `plugins/dev-workflow/changes/1085.md` に、何を変えたか（ci-watch.md の 9 と 2 の書き分け・SKILL.md の参照）、hook を足さなかった理由、親の検知を #1084 に残した理由を書く。確かめ方: ファイルがあり、既存の `changes/*.md` と同じ形であること。触る範囲: plugins/dev-workflow/changes/1085.md（新規）
