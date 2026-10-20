## 1. 共通の判定ファイル

- [ ] 1.1 `git-guard-scratchpad.py` を作り、`<base>`（呼び出し側が渡す）と `<key>`（session_id・agent_id・cwd・command を NUL でつないだ sha256）・回数ファイルの名前（sha256(session_id + NUL + agent_id)。`count_child_deny` と同じ）・`permit-log.jsonl` への 1 行の追記を関数にする。hook はこのファイルを子の呼び出しで破壊的操作（`permit-self` を含む）を見つけたときに読み、主の呼び出しと破壊的操作の無い呼び出しでは読まない。読めないときは `<key>` を出せないので、許可を探さず拒否の記録も書かず `deny` だけを返す 触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py（新規）、plugins/dev-workflow/scripts/git-destructive-guard.sh:737-762（`count_child_deny` の名前の決め方を合わせる）
- [ ] 1.2 一時領域の判定 `check(session_id, cwd, command)` を書く: 文字の制限（改行は LF だけ、CR を拒む）・単純コマンドの制限（`cd` 引数 1 つ／`git` は `-C` だけを複数置けて左から適用・許したサブコマンドは checkout・restore・reset・clean・branch・switch・status・add・commit・rev-parse）・作業ディレクトリの追跡・`.git` を辿った作業ツリー / git ディレクトリ / 共通の git ディレクトリの realpath が `claude-<uid>/<slug>/<session_id>/scratchpad` の中（scratchpad そのものを含む）・config と config.worktree の `worktree` キーと `[include` / `[includeIf`（大文字小文字を区別しない）。git を実行しない。満たさない理由を文字列で返す 触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py（新規）
- [ ] 1.3 呼び出し側の読み方を決めて書く: bash が `$(dirname "$0")/git-guard-scratchpad.py` のパスを引数で渡し、`python3 -I -c` の本体がその中身を読んで `exec` で取り込む 触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py（新規）

## 2. hook: 拒否の記録・許可の照合・自己許可の拒否

- [ ] 2.1 子の呼び出しで、単純コマンドの先頭（または `bash` / `sh` / `zsh` / `dash` / `ksh` / `source` / `.` の最初のオプションでない引数）の basename が `git-guard-permit.sh` のものを種類 `permit-self` として拾い、LABELS / ORDER に表示を足す。主の呼び出しではこの種類を捨てる（何も出さない） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:70-90（LABELS・ORDER・SHELLS）、plugins/dev-workflow/scripts/git-destructive-guard.sh:574-603（`judge_simple`）、plugins/dev-workflow/scripts/git-destructive-guard.sh:720-728（判定結果の受け取り）
- [ ] 2.2 子の呼び出しで、`permit-self` を含まないときは `permits/<key>.json` を `rename` で取って読み、4 つの値が一致し期限内なら、共通ファイルを読み込んで payload の session_id・cwd・command に一時領域の判定をかける。満たせば `allow`（回数を数えず、記録を書かない）、満たさない・共通ファイルを読めないなら `deny`（回数を数え、理由に「許可はあるが行き先を確かめられない」）。取った許可は必ず消す。使ったら `permit-log.jsonl` に `use`、期限切れなら `expired`、使う時点の一時領域の判定で `deny` にしたら `rejected` を追記する（失敗しても判定を変えない）。共通ファイルを読めないときは許可を探さない 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:763-775（decision を決める所）、plugins/dev-workflow/scripts/git-destructive-guard.sh:806-819（python3 の呼び出しに共通ファイルのパスを渡す）
- [ ] 2.3 子に `deny` を返すとき `denied/<key>.json` に記録を書き、書けたら子への理由文に記録のパスと「親に返す報告にこのパスを書く」を足す（`git-guard-permit.sh` の名前は書かない）。`allow` の理由文を足す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:777-812（理由文と出力）
- [ ] 2.4 冒頭のコメント（返す値・置き場所・共通ファイル）に許可と記録を書き足す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:18-34

## 3. 許可を書くスクリプト

- [ ] 3.1 `git-guard-permit.sh <拒否の記録のパス> <理由>` を作る。bash から `python3 -I -c` で本体を動かす（`git-destructive-guard.sh` の PY_SRC の読み方と同じ。`/dev/fd/3` を使わない）。共通ファイルのパスを引数で渡す。使い方の誤りは exit 2 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 3.2 記録の置き場所（`<base>/denied/<key>.json` で、`basename(<base>)` が `dev-workflow-git-guard`、中身から計算し直した key がファイル名と一致）・理由が空でないことを確かめる。`<base>` は記録のパスの 2 つ上（TMPDIR を見ない） 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 3.3 共通ファイルの一時領域の判定を記録の session_id・cwd・command で呼び、満たさなければ理由を stderr に書いて exit 1 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）
- [ ] 3.4 `permit-log.jsonl` に `permit` を追記（失敗したら許可を書かず exit 1）→ 許可を一時ファイルから `rename` で `permits/<key>.json` に置く（期限 15 分）→ 回数のファイルを消す → stdout に要約を書く 触る範囲: plugins/dev-workflow/scripts/git-guard-permit.sh（新規）

## 4. bats

- [ ] 4.1 scratchpad の形（`$BATS_TEST_TMPDIR/claude-$(id -u)/slug/<session_id>/scratchpad/repo`）に git repo を作るヘルパーと、`cwd` を payload に入れるヘルパーを足す（既存の `payload` / `call` の引数の並びは変えず、cwd 付きの別のヘルパーにする） 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:7-60（setup とヘルパー）
- [ ] 4.2 受け入れ条件のテスト: 一致する許可で `allow`／許可が無い・コマンドが 1 文字違う・別の agent_id・別の cwd・使用済み・期限切れで `deny`／主の呼び出しは `ask` のまま許可を消さない。「一致しない呼び出しには許可を使わない」は同じ子で続けて拒否されるので 2 件目以降に `continue: false` が付く。このテストでは `continue` の有無を検査しない 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節を足す。既存の child count の節は plugins/dev-workflow/tests/git-destructive-guard.bats:658-745）
- [ ] 4.3 スクリプトが許可を書かないテスト: cwd が外・`cd` で外へ・`-C` で外・`.git` が外を指す・別セッションの scratchpad・`[Core] WorkTree` の大文字混じり・`$` / 引用符 / リダイレクト / `rm` / `push` / `init` / 代入 / CR を含む・記録を `denied/` の外に写した / `dev-workflow-git-guard` でない名前の下に写した / 書き換えた・理由が空、のそれぞれで 0 以外・`permits/` が空 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 4.4 hook 側の拒否のテスト: 許可を書いたあと repo の `.git` を外の git ディレクトリへの symlink に差し替えると `deny` で理由に「許可はあるが行き先を確かめられない」・許可ファイルが消える／スクリプトを使わずに外の repo の cwd で一致する許可を `permits/` に直接書くと `deny` で同じ理由 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 4.5 数え直しのテスト: 拒否 1 回 → 許可 → `allow` → 別の操作の拒否が `continue` なし・「直ちに作業を終えて親に返す」なし 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 4.6 拒否の記録・子への理由文（記録のパスを含み、`git-guard-permit.sh` を含まない）・自己許可の拒否（子は deny、主と `cat` は無出力）・TMPDIR が違ってもスクリプトが記録の場所に書く・`permit-log.jsonl` に permit → use の順で残る、のテスト。既存の「子への理由」のテストに `git-guard-permit.sh` を含まない検査を足す 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:614-657（子への理由の既存テスト）、plugins/dev-workflow/tests/git-destructive-guard.bats（末尾に新しい節）
- [ ] 4.7 `bats plugins/dev-workflow/tests/git-destructive-guard.bats` と `bats tests/injection-budget.bats` が通ることを確かめる 触る範囲: なし（実行のみ）

## 5. 実機確認と記録

- [ ] 5.1 `claude -p --plugin-dir` で、子に scratchpad の中に repo を作らせ、`git -C <その repo の絶対パス> checkout -- <ファイル>` を打たせて拒否され、親が `git-guard-permit.sh` で許可を書き、SendMessage で再開した子の同じコマンドが確認画面も拒否も無く実行されることを確かめる。scratchpad の外の repo を対象にした記録には許可が書けないことも確かめる。scratchpad の検証用 repo は git の破壊的操作で戻さず作り直す 触る範囲: なし（実機確認）
- [ ] 5.2 同じ実機確認で、子が前の Bash 呼び出しで `cd` したあとの次の呼び出しの payload の `cwd` が何になるかを拒否の記録で 1 回見て、5.1 の結果と合わせて PR 本文に書く 触る範囲: なし（実機確認）
- [ ] 5.3 変更の記録 `plugins/dev-workflow/changes/1133.md` を書く（何が変わったか・範囲外（#1134・#1135・#1117）・受け入れること・戻し方） 触る範囲: plugins/dev-workflow/changes/1133.md（新規）
