行番号は仕様づくりの時点（origin/main 81172a7f）の値で、前のタスクの編集でずれる。編集の前に該当範囲を読んで確かめる。テストを先に書き、落ちることを見てから実装する。

## 1. テストのスタブを広げる

- [ ] 1.1 `orca` のスタブに `worktree rm`・`terminal close` を足し、`worktree set` に渡された `--workspace-status` を記録できるようにする。`worktree list` の返り値を呼び出しごとに切り替えられるようにする（2 回目のポーリングから `completed` になる場合のため）。`git` のスタブに `-C <パス> status --porcelain`・`-C <パス> rev-parse HEAD`・`rev-parse --verify --quiet refs/heads/<ブランチ>`・`branch -D` を足す。`gh` のスタブに `pr list` の分岐を足す（今の `$2` から issue 番号を取る処理と分ける）。ファイル冒頭のスタブの説明も直す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:6-17（冒頭の説明）、plugins/dev-workflow/tests/epic-dispatch.bats:43-139（`make_stub`）
- [ ] 1.2 条件をすべて満たす子の一覧（`list_json`）と、今のワークツリー（`current_json` に `id` と `linkedIssue`）を置く補助関数を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:23-40（`setup`）、plugins/dev-workflow/tests/epic-dispatch.bats:141-163（補助関数）

## 2. mark

- [ ] 2.1 `mark` のテストを書く（delta spec の Scenario 7 件: 完了の印・確認待ちの印・別の issue・Orca 管理外と `orca` なし・`EPIC_DISPATCH_PARENT_EPIC` 付き・`set` の失敗・引数の誤り）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:556-558（`# --- wait ---` の前に `# --- mark ---` の節を足す）
- [ ] 2.2 `cmd_mark` を実装し、`usage` と末尾の振り分けに足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:47-55（`usage`）、plugins/dev-workflow/scripts/epic-dispatch.sh:204-206（`cmd_launch` のうしろに新規）、plugins/dev-workflow/scripts/epic-dispatch.sh:261-268（振り分け）

## 3. wait の拡張

- [ ] 3.1 #526 の直し: 「gh's stderr is shown right before the error line」のテストに、stderr が `(poll 3)` を含むことと `mock failure` の行がちょうど 1 行であることの確認を足す。`epic-dispatch.sh` の `: > "$errf"` を一時的に消すとこのテストが落ちることを手で確かめ、戻す（確かめた結果を PR に書く）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:630-636
- [ ] 3.2 `--watch-done` のテストを書く（delta spec の Scenario 6 件: issue が open のまま印を検知・`closed` と `done` の 2 行・位置引数なし・`--watch-done` なしでは `orca` を呼ばない・別の repo と archive 済みは数えない・一覧の失敗 3 回で `error workspaces`）。`--watch-done` の値が数字でないときの拒否も足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:678-695（`wait` の節の末尾に足す）
- [ ] 3.3 `cmd_wait` に `--watch-done` を実装する。既存の `wait` のテストがそのまま通ることを確かめる。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:206-259（`cmd_wait`）

## 4. reap

- [ ] 4.1 `reap` のテストを書く（delta spec の Scenario 9 件: 全条件を満たす子の呼び出し順と `--force` なし・条件を外れた 5 通り・PR なしと PR を調べられない・`gone`・ブランチの先端の一致と不一致・ブランチが残っていない・close の失敗・複数の子・一覧の失敗）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:695-697（`# --- SKILL.md ---` の前に `# --- reap ---` の節を足す）
- [ ] 4.2 `cmd_reap` を実装し、`usage` と末尾の振り分けに足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:47-55（`usage`）、plugins/dev-workflow/scripts/epic-dispatch.sh:259-261（`cmd_wait` のうしろに新規）、plugins/dev-workflow/scripts/epic-dispatch.sh:261-268（振り分け）
- [ ] 4.3 スクリプト冒頭の説明に `mark`・`reap`・`wait --watch-done` を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-44

## 5. develop の手順書

- [ ] 5.1 SKILL.md の記述を確かめるテストを書く（「ループの終わり」の節があり片付けを聞かないこと・`mark` の呼び方と `done` / `waiting` の使い分けが書かれていること、Orca 経路に `--watch-done`・`reap`・`子 #N のワークツリーを残した`・`not-done`・再開時の `reap` が書かれていること、`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` が 0 行、`grep -rlw orca plugins/dev-workflow --include='*.sh'` が `epic-dispatch.sh` の 1 行だけ）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:697-773（`# --- SKILL.md ---` の節の末尾に足す）
- [ ] 5.2 SKILL.md に「ループの終わり」の節を足す（delta spec「develop のループの終わりは片付けを聞かず、ワークスペースに印を付ける」のとおり）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:169-171（「1 ループ」の節の末尾と「PR トークン上限」の間に新規）
- [ ] 5.3 SKILL.md「エピックの扱い」の Orca 経路を直す（delta spec「Orca 経路の本体は印が付いた子のワークスペースを片付ける」のとおり）。あわせて `orca terminal read` を「stderr に出た確認のコマンド」に言い換える。既存の SKILL.md のテスト（`# --- SKILL.md ---` の節）が通ることを確かめる。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:303-311（Orca 経路の手順 1〜5 とそのうしろの段落）
- [ ] 5.4 #459 に、質問の出どころを調べた結果をコメントする（検索したコマンドと、該当する指示が手順書・`commands/develop.md`・pr-review-gate・worktree プラグインの hooks に無かったこと、直した箇所のファイル:行）。触る範囲: なし（issue へのコメント）

## 6. README と変更の記録

- [ ] 6.1 ルートの README のエピックの行で、「それ以外は」を「それ以外と unmanned は」に置き換え（#472）、`scripts/epic-dispatch.sh` を `plugins/dev-workflow/scripts/epic-dispatch.sh` に置き換える（#473）。Orca 経路では子が完了の印を付けたワークツリーを親が片付けることを 1 文で足す。触る範囲: README.md:28
- [ ] 6.2 dev-workflow の README のエピックの行で、「それ以外は」を「それ以外と unmanned は」に置き換え（#472）、片付けの動きを 1 文で足す。触る範囲: plugins/dev-workflow/README.md:15
- [ ] 6.3 変更の記録を書く（版は上げない）。触る範囲: plugins/dev-workflow/changes/805.md（新規）

## 7. 確認

- [ ] 7.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats` と `bash scripts/test.sh` が exit 0（常時注入の予算テスト `tests/injection-budget.bats` を含む）。`openspec validate epic-reap-done-children --strict` が exit 0。触る範囲: なし
- [ ] 7.2 PR 本文に貼る検索の結果を取る: `grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop`（0 行）と `grep -rnw orca plugins/dev-workflow --include='*.sh'`（`epic-dispatch.sh` だけ）。触る範囲: なし
- [ ] 7.3 実機の確認（Orca 経路のエピックで、子が完了の印を付けたワークツリーが Orca の UI・`git worktree list`・`git branch` から消えること、確認待ちの印の子が残ること）は、マージ前の `claude --plugin-dir` か、マージ後の最初の Orca 経路のエピックで行い、結果を PR に貼る。この工程のワークツリーはサブエージェント方式で動いているので、W は実機で流せない。W は (3a) の return にその旨を書き、誰がいつ行うかは本体が決める。触る範囲: なし
