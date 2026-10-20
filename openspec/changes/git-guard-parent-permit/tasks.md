## 1. hook: 拒否の記録・許可の照合・自己許可の拒否

- [ ] 1.1 `<base>`（`${TMPDIR:-/tmp}/dev-workflow-git-guard/`）と `<key>`（session_id・agent_id・cwd・command を NUL でつないだ sha256）を求める関数を足し、`count_child_deny` と同じ置き場所の決め方にそろえる 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:730-762（`count_child_deny` の周り）
- [ ] 1.2 子の呼び出しで、単純コマンドの先頭（または `bash` / `sh` / `zsh` / `dash` / `ksh` / `source` / `.` の最初のオプションでない引数）の basename が `git-guard-permit.sh` のものを種類 `permit-self` として拾い、LABELS / ORDER に表示を足す。主の呼び出しではこの種類を捨てる（何も出さない） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:70-90（LABELS・ORDER・SHELLS）、plugins/dev-workflow/scripts/git-destructive-guard.sh:574-603（`judge_simple`）、plugins/dev-workflow/scripts/git-destructive-guard.sh:720-728（判定結果の受け取り）
- [ ] 1.3 子の呼び出しで、`permit-self` を含まないときは `permits/<key>.json` を `rename` で取って読み、4 つの値が一致し期限内なら `allow`（回数を数えず、記録を書かない）。取った許可は必ず消す。使ったら `permit-log.jsonl` に `use`、期限切れなら `expired` を追記する（失敗しても判定を変えない） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:763-775（decision を決める所）
- [ ] 1.4 子に `deny` を返すとき `denied/<key>.json` に記録を書き、書けたら子への理由文に記録のパスと「親に返す報告にこのパスを書く」を足す（`git-guard-permit.sh` の名前は書かない）。`allow` の理由文を足す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:777-812（理由文と出力）
- [ ] 1.5 冒頭のコメント（返す値・置き場所）に許可と記録を書き足す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:18-34

## 2. 許可を書くスクリプト

- [ ] 2.1 `git-guard-permit.sh <拒否の記録のパス> <理由>` を作る。bash から `python3 -I -c` で本体を動かす（`git-destructive-guard.sh` の PY_SRC の読み方と同じ。`/dev/fd/3` を使わない）。使い方の誤りは exit 2 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 2.2 記録の置き場所（`<base>/denied/<key>.json` で、中身から計算し直した key がファイル名と一致）・理由が空でないことを確かめる。`<base>` は記録のパスの 2 つ上（TMPDIR を見ない） 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 2.3 コマンドの文字の制限・単純コマンドの制限（`cd` 引数 1 つ／`git` は `-C` だけ・許したサブコマンドだけ）・作業ディレクトリの追跡を書く 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 2.4 `.git` を辿って作業ツリーの最上位・git ディレクトリ・共通の git ディレクトリを求め、realpath がすべて記録の session_id の scratchpad（`claude-<uid>/<slug>/<session_id>/scratchpad`）の中にあること、config に `worktree` キーと `[include` / `[includeIf` が無いことを確かめる。git を実行しない 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 2.5 `permit-log.jsonl` に `permit` を追記（失敗したら許可を書かず exit 1）→ 許可を一時ファイルから `rename` で `permits/<key>.json` に置く（期限 15 分）→ 回数のファイル `<base>/<sha256(session_id + NUL + agent_id)>` を消す → stdout に要約を書く 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）

## 3. bats

- [ ] 3.1 scratchpad の形（`$BATS_TEST_TMPDIR/claude-$(id -u)/slug/<session_id>/scratchpad/repo`）に git repo を作るヘルパーと、`cwd` を payload に入れるヘルパーを足す（既存の `payload` / `call` の引数の並びは変えず、cwd 付きの別のヘルパーにする） 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:7-60（setup とヘルパー）
- [ ] 3.2 受け入れ条件のテスト: 一致する許可で `allow`／許可が無い・コマンドが 1 文字違う・別の agent_id・別の cwd・使用済み・期限切れで `deny`／主の呼び出しは `ask` のまま許可を消さない 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節を足す。既存の child count の節は plugins/dev-workflow/tests/git-destructive-guard.bats:585-745）
- [ ] 3.3 スクリプトが許可を書かないテスト: cwd が外・`cd` で外へ・`-C` で外・`.git` が外を指す・別セッションの scratchpad・`$` / 引用符 / リダイレクト / `rm` / `push` / 代入を含む・記録を写した / 書き換えた・理由が空、のそれぞれで 0 以外・`permits/` が空 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 3.4 数え直しのテスト: 拒否 1 回 → 許可 → `allow` → 別の操作の拒否が `continue` なし・「直ちに作業を終えて親に返す」なし 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 3.5 拒否の記録・子への理由文（記録のパスを含み、`git-guard-permit.sh` を含まない）・自己許可の拒否（子は deny、主と `cat` は無出力）・TMPDIR が違ってもスクリプトが記録の場所に書く・`permit-log.jsonl` に permit → use の順で残る、のテスト。既存の「子への理由」のテストに `git-guard-permit.sh` を含まない検査を足す 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:614-657（子への理由の既存テスト）、plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 3.6 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` と `bats tests/injection-budget.bats` が通ることを確かめる 触る範囲: なし（実行のみ）

## 4. 実機確認と記録

- [ ] 4.1 `claude -p --plugin-dir` で、子が scratchpad に作った repo で `git checkout -- .` を打って拒否され、親が `git-guard-permit.sh` で許可を書き、SendMessage で再開した子の同じコマンドが確認画面も拒否も無く実行されること、scratchpad の外の repo を対象にした記録には許可が書けないことを確かめる。scratchpad の検証用 repo は git の破壊的操作で戻さず作り直す 触る範囲: なし（実機確認）
- [ ] 4.2 変更の記録 `plugins/dev-workflow/changes/1133.md` を書く（何が変わったか・範囲外（#1134・#1135・#1117）・受け入れること・戻し方） 触る範囲: plugins/dev-workflow/changes/1133.md（新規）
