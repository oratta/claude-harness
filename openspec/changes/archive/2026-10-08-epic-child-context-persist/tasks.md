## 1. テスト（先に書いて落ちることを確かめる）

- [x] 1.1 bats の `gh` スタブに `issue comment` の分岐を足す（`gh issue comment <N> --body <本文>` の本文を `$STUB_CFG/comment_<N>` に追記し、`comment_exit` で終了コードを切り替える。今は `${2##*/}` が `comment` になり `gh_comment` を読みに行く）。冒頭のスタブの説明にも足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1-23（冒頭の説明）、plugins/dev-workflow/tests/epic-dispatch.bats:148-162（gh スタブ）
- [x] 1.2 注意書きのコメントの bats を足す（spec の Scenario「--note があれば子ごとに 1 回注意書きをコメントする」「--note が無ければコメントしない」「skipped の子と worktree create に失敗した子にはコメントしない」「端末を作れなかった子にもコメントは残る」「コメントに失敗しても起動の結果は変えない」「worktree create の JSON に path が無い子にもコメントは残る」。順序は `$STUB_LOG` の行番号で比べる）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:390-396（既存の --note のテストの直後）
- [x] 1.3 親子関係の判定の bats を足す（spec の Scenario「環境変数が無くても、親ワークツリーに issue があれば nested」「子が 1 件でも…」「親ワークツリーに issue が無ければ今までどおり」「親も環境変数も無ければ今までどおりで一覧を読まない」「一覧を読めなければ子ではないとして扱う」「環境変数があるときは nested の stderr に環境変数の番号を出す」「親ワークツリーに issue があれば launch は子ワークツリーを作らない」）。`current_json` に `id`・`parentWorktreeId` を持たせ、`list_json` に親の 1 件を置く。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:224-275（route）、plugins/dev-workflow/tests/epic-dispatch.bats:352-370（launch の EPIC_DISPATCH_PARENT_EPIC のテストの近く）
- [x] 1.4 案内の bats を足す（spec の Scenario「作り直しの案内の前に既存端末の確認を出す」「送り直しの案内のハンドルは引用符で囲まれる」）。既存の送り直しのテストが `--terminal term-11` を引用符なしで照合していれば、引用符付きに直す（`grep -n 'terminal term-' plugins/dev-workflow/tests/epic-dispatch.bats` で探す）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（送り直し・作り直しのテスト。行は grep で特定）
- [x] 1.5 SKILL.md の記述の bats を足す（spec の Scenario「SKILL.md に注意書きのコメントと起動し直したセッションの扱いが書かれている」「SKILL.md に端末を作れなかった子の再開手順が書かれている」。既存の `section 'エピックの扱い'` を使う）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1212-1240（skill のテスト群）
- [x] 1.6 `bats plugins/dev-workflow/tests/epic-dispatch.bats` で足したテストが落ち、既存のテストが通ることを確かめる

## 2. epic-dispatch.sh

- [x] 2.1 エピックの子の判定の関数（仮名 `epic_parent`。親エピックの番号を stdout に出すか、子でなければ空。`orca worktree current --json` の出力を引数か変数で受け取り、呼び出しを 1 回に保つ）を足し、`route` で子の件数の判定より先に使う。`nested` のとき stderr に `parent epic: #<N>`、一覧を読めないとき stderr に `could not read the parent worktree`。`orca worktree current` は `--json` 付きの 1 回にする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:79-102（is_num・check_children・cmd_route）
- [x] 2.2 `launch` の拒否に親子関係の判定を足す（`orca worktree current --json` の直後、`git rev-parse` より前。stderr に親エピックの番号と `child epics are not expanded here`）。環境変数による拒否（150-153 行）はそのまま。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:150-164（cmd_launch の前半）
- [x] 2.3 `launch --note` の注意書きのコメント投稿を足す（`orca worktree create` が exit 0 のあと、端末を作る前。本文は `親エピックからの注意書き: #<epic>`・空行・`<text>`。失敗したら stderr に `note not posted to #<N>` と `gh issue comment <N> --body '<本文>'`（`shq` で囲む）。stdout と exit code は変えない）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:184-198（cmd_launch のループ）
- [x] 2.4 #487: `resend_hint` のハンドルを `shq` に通す（`send` と `read` の両方）。#498: `recreate_hint` の最初の echo の直後に `check that no terminal is already running claude there before creating one: orca terminal list --worktree path:<子> --json` を出す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:107-127（resend_hint・recreate_hint）
- [x] 2.5 冒頭コメントを直す: `route` の説明に親子関係の判定と stderr の `parent epic:` を、`launch` の説明に注意書きのコメントと親子関係による拒否を足し、#532 の「route は子 0 件でも subagent」を「route は子 0 件でも subagent（エピックの子のセッションなら nested）」にする。正本の要件名に、この change の要件名を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:11-32（route・launch の説明）、plugins/dev-workflow/scripts/epic-dispatch.sh:58-64（引数の誤りと正本）
- [x] 2.6 `bats plugins/dev-workflow/tests/epic-dispatch.bats` が全部通ることを確かめる

## 3. develop の SKILL.md

- [x] 3.1 「`nested` を受けたセッション」の段落を直す: 子であることは端末に付けた環境変数と子のワークツリーの親子関係のどちらからでも判定されるので起動し直したセッションでも `nested` になること、親エピックの番号は `route` の stderr の `parent epic: #<N>` から読むこと、`launch` の拒否は stderr の `child epics are not expanded here` で見分けること。`orca` のコマンドは書かない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:309（`nested` を受けたセッション）
- [x] 3.2 「Orca 経路」の段落と手順 1 に、`launch` が `--note` を子 issue に `親エピックからの注意書き:` で始まるコメントとして残すこと、子のセッションの本体（起動し直したセッションを含む）は記録先にこの行で始まるコメントがあればすべて従い W・R1・G に渡す関連コメントに必ず含めること、stderr に `note not posted to #<N>` があれば本体がその子 issue に stderr の本文を投稿することを書く。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:311-313（Orca 経路・手順 1）
- [x] 3.3 #499: 手順 6 の「送り直し、動き出したのを確かめてから再開する」の直後に、端末を作れなかった `failed` の子は stderr に出た確認のコマンドで既存の端末が無いことを確かめ、stderr の作り直しのコマンドで端末を作り、返ったハンドルに送信のコマンドを送って動き出したのを確かめてから再開する、を足す（#499 の提案文の `orca terminal create` は「stderr に出た作り直しのコマンド」と書き換える）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:318（手順 6）、plugins/dev-workflow/skills/develop/SKILL.md:323（作り直しのコマンドが出る旨の文）
- [x] 3.4 `grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` が 0 行であることを確かめる

## 4. 記録と全体の確認

- [x] 4.1 変更の記録を書く（形式は既存の `plugins/dev-workflow/changes/805.md` に合わせる。#532・#487・#498・#499 を合わせて閉じたことも書く。版は上げない）。触る範囲: plugins/dev-workflow/changes/809.md（新規）
- [x] 4.2 `bash scripts/test.sh` が exit 0（常時注入の予算テストを含む。`description` と rules は増やさない）
- [x] 4.3 `openspec validate epic-child-context-persist --strict` が exit 0
- [ ] 4.4 実機: Orca 経路で `launch --note` で起動した子のセッションを閉じ、同じワークツリーで `/develop #N` だけで起動し直したとき、本体が `親エピックからの注意書き:` のコメントを読み、`route` が `nested`（stderr に `parent epic: #<エピック>`）を返すことを確かめ、結果を PR に貼る（W のサブエージェントでは流せない。本体かオーナーが行う）。子が葉の issue なら本体は `route` を呼ばないので、子ワークツリーで `scripts/epic-dispatch.sh route 1 2` を手で打つか sub-issue を持つ子で確かめる。注意書きが読まれた証拠は、起動し直した子の開始コメントか会話ログの記録を貼る。PR ゲートの動作確認で扱う（PR #834 の動作確認の見出し）
