## 1. 実装の前の実機確認

- [x] 1.1 `claude -p --permission-mode bypassPermissions` に PermissionRequest の入力を書き出す hook を置き、サブエージェントに確認画面が出るコマンドを打たせて、子の入力の `permission_mode` が `bypassPermissions` かを確かめる（「Dangerous rm operation not ruled out」の再現形を探す。2.1.321 では `$(printf ...)` と逆引用符・改行・行継続・`$'...'`・ノーブレークスペース・長い本文の 6 形と、子の `cd <dir>; rm -f tbl/*` では確認が出なかった）。次のどちらかなら、2 以降の実装に進まず本体に return する: 子の入力の `permission_mode` が `bypassPermissions` でない（判定の条件が変わるので仕様に戻す）／子に確認画面を出せず、子の入力を取れない（判定の前提が未検証。試した形・版・取れた入力を return に書く）。触る範囲: scratchpad（repo の外）

## 2. hook の判定

- [x] 2.1 冒頭のコメント「答える範囲」を、rm の入口の形に当たらない子の呼び出しは `permission_mode` が `bypassPermissions` なら deny、それ以外は何も出さない形に直す。触る範囲: plugins/dev-workflow/scripts/rm-permission-guard.sh:2-16（冒頭のコメント）
- [x] 2.2 rm の入口の判定（共通ファイルの `is_rm_command`、読めないときの簡易判定）で rm でないと分かった直後に、`permission_mode` がちょうど `bypassPermissions` なら、許可も記録も使わずに deny と打ち直し方の message を返し、それ以外は今までどおり exit 0 する（条件は spec の要件「子の rm でない確認画面は、権限確認を省くモードでは拒否する」「確認を求めるモードの子と主の rm でない確認には答えない」、message の中身は「子の rm でない確認への拒否の理由に、打ち直し方と親に返る条件を書く」）。`emit` は rm の判定より後で定義されているので、置き場所に気をつける。触る範囲: plugins/dev-workflow/scripts/rm-permission-guard.sh:55-81（入口の判定と `emit`）

## 3. テスト

- [x] 3.1 payload を作る `call` に `permission_mode` を渡せるようにする（今の既定 `default` は変えない）。触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats:33-44（`call`）
- [x] 3.2 既存の「主の呼び出しと rm でない確認には何も返さない」テストが `default` のまま通ることを確かめる。触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats:134-147
- [x] 3.3 新しい要件のシナリオのテストを足す: bypassPermissions の子の rm でない確認の deny と message・記録を作らないこと／判定のファイルが無いときも deny／`default`・`acceptEdits`・`plan`・無いの子と主には何も返さない／bypassPermissions の子の rm は許可あり allow・許可なし rm の deny のまま。触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats:147-160（「a broken payload gets no output」の前後に足す）、plugins/dev-workflow/tests/rm-permission-guard.bats:222-236（判定のファイルが無い場所に hook を置く既存テストの作り方を参考にする）
- [x] 3.4 `bats plugins/dev-workflow/tests/rm-permission-guard.bats plugins/dev-workflow/tests/hook-python-invocation.bats` が通ることを確かめる（hook-python-invocation は rm の入力で呼んでいるので変えなくてよいはず）。触る範囲: plugins/dev-workflow/tests/hook-python-invocation.bats:32-37,90（読むだけ）

## 4. 記録と実機確認

- [x] 4.1 変更の記録を書く（何を変えたか・bypassPermissions に絞った理由・範囲外・戻し方）。触る範囲: plugins/dev-workflow/changes/1610.md（新規。書き方は plugins/dev-workflow/changes/1134.md:1-12）
- [x] 4.2 tmux の対話セッションで `claude --dangerously-skip-permissions --plugin-dir <worktree>/plugins/dev-workflow` を動かし（Claude Code 2.1.321 の `claude -p` では子の PermissionRequest が呼ばれないため、対話セッションで確かめる。手順の変更は主の判断として記録先に記録済み: https://github.com/oratta/claude-harness/issues/1610#issuecomment-6756881007 ）、サブエージェントに 1.1 で見つけた形を打たせ、確認画面が出ずに拒否され、理由が子に返ることを確かめる。試したコマンド・結果・Claude Code の版を PR に記録する。どの形でも確認画面を出せなければ、実機確認は未検証として本体に return する（試した形・版・hook を直接呼んだ結果を書く。これを受け入れ条件の達成とは扱わない）。受け入れ条件を変えるときは、主の判断結果を記録先に記録してから変える。触る範囲: scratchpad（repo の外）
