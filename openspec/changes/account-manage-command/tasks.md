行番号は仕様づくりの時点（HEAD 7225146d）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。テストは実装より先に書き、落ちることを見てから実装する。

## 1. テスト（先に書く）

- [ ] 1.1 `accounts-command.bats` を新規に作り、spec の Scenario を 1 件ずつテストにする（空の登録簿への追加、既存 id の追加は exit 2 かつ登録簿不変かつディレクトリ不作成、`enabled` 無し → off → on で他の欄と順序が不変、存在しない id の on / off は exit 2 かつ不変、一覧のオフ表示、壊れた登録簿は exit 1 かつ不変、`.bak` が実行前と同一、`CLAUDE_ACCOUNTS_HOME` が相対パスなら exit 2、未知のサブコマンドと引数欠落は exit 2、`accounts-init.sh` の既存 bats が通ること、空白を含む基点でログインコマンドが評価後に `securestorage` と一致すること、`accounts` が配列でない登録簿は exit 1 かつ不変）。登録簿は `CLAUDE_ACCOUNTS_FILE`、基点は `CLAUDE_ACCOUNTS_HOME` を一時ディレクトリに向ける。足場は `account-selector.bats` の `setup` / `teardown` に倣う。触る範囲: plugins/dev-workflow/tests/accounts-command.bats（新規）、plugins/dev-workflow/tests/account-selector.bats:9-34（setup と write_registry の書き方の参照）
- [ ] 1.2 `account-selector.bats` の `enabled:` の並びの末尾に、`accounts.sh off b` で書き換えた登録簿で `select-account.sh` を実行し、`b` が選ばれず `margins` に `b:off` が出るテストを 1 件足す。触る範囲: plugins/dev-workflow/tests/account-selector.bats:390-407（`enabled: an off slot is not selected...` のテストを雛形にする）、末尾に追加

## 2. スクリプト

- [ ] 2.1 `plugins/dev-workflow/scripts/accounts.sh` を新規に作る。冒頭のコメントに、正本が `openspec/specs/usage-account-registry`、`accounts-init.sh` との使い分け、`.bak` の 1 世代を書く。引数処理（`require_value` 相当、id と label の検査）は `accounts-init.sh` に倣う。書き込みは python3 の `mkstemp` ＋ `os.replace`、書く前に `.bak` へコピー。触る範囲: plugins/dev-workflow/scripts/accounts.sh（新規）、plugins/dev-workflow/scripts/accounts-init.sh:26-62（引数処理と検査）、plugins/dev-workflow/scripts/accounts-init.sh:64-124（python の読み書き）
- [ ] 2.2 実行権限を付ける（`chmod +x`。`accounts-init.sh` と同じ）。触る範囲: なし
- [ ] 2.3 `bats plugins/dev-workflow/tests/accounts-command.bats plugins/dev-workflow/tests/account-selector.bats plugins/dev-workflow/tests/usage-probe-multi-account.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 3. docs

手編集の案内は、次の 4 か所に残っている（着手前に洗い出した。実装時にも `grep -nE` で再確認する）。どれも「1 文の置換」ではなく、その操作案内の全体（文・コード例・戻し方）をコマンドの手順に改める。

- plugins/dev-workflow/README.md:82 — 「`accounts.json` のそのスロットに `"enabled": false` を足す」「`enabled` の行を消すか `true` にする」「切り替えは当面 `accounts.json` を手で書き換える」
- plugins/statusline/README.md:117-119 — 「パスを手で書き写さずこのスクリプトを使うこと」「手で書いてもよい」の登録手順（`add` を主手順にし、`accounts-init.sh` は居るシェルの環境から登録する手段として残す。できあがりの形の例は参照として残すが「手で書いてもよい」は消す）
- plugins/statusline/README.md:142-145 — 「使っていないアカウントをオフにする」の「`"enabled": false` を足す」とその JSON 片
- plugins/statusline/README.md:156 — 「`enabled` の行を消すか `true` にする」「切り替えは当面 `accounts.json` を手で書き換える」

残す: plugins/statusline/README.md:136 のフィールド表の `enabled` の行（形の参照であって操作の案内ではない）。

- [ ] 3.1 `plugins/dev-workflow/README.md:82` の段落を、`accounts.sh list|add|off|on` の使い方（各コマンドの例、`CLAUDE_ACCOUNTS_HOME`、`.bak`）と、オフ・オンの動作の説明（自動選択・`cld-account`・縮退）に改める。戻し方は `accounts.sh on <id>`。最初の `add` では既定アカウントのスロットができないので、既定アカウントも並べるなら `accounts-init.sh` を使う旨を 1 文足す。触る範囲: plugins/dev-workflow/README.md:82
- [ ] 3.2 `plugins/statusline/README.md` の「レジストリの作り方」（`:102-119`）を、新しいアカウントは `accounts.sh add <id>` ＋ログインコマンド、既定アカウントや居るシェルの登録は `accounts-init.sh` の手順に改める。触る範囲: plugins/statusline/README.md:102-119
- [ ] 3.3 `plugins/statusline/README.md` の「使っていないアカウントをオフにする」（`:140-156`）を、`accounts.sh off <id>` / `on <id>` の手順に改める。JSON 片（`:144-146`）は消し、戻し方は `accounts.sh on <id>`。`accounts-init.sh` で登録し直しても `enabled` は消えない旨の括弧と、ライブ値で描く場合の説明は残す。触る範囲: plugins/statusline/README.md:140-156
- [ ] 3.4 次の検査が、どれも 0 件であることを確かめる。(a) issue 本文の条件 `grep -n "accounts.json を手で" plugins/dev-workflow/README.md plugins/statusline/README.md`（今も 0 件で、検査としては弱いので (b) を主にする）。(b) `grep -nE '手で書き換える|手で書いてもよい|のそのスロット(に|へ)|enabled` の行を消す|"enabled": false \}' plugins/dev-workflow/README.md plugins/statusline/README.md`。(c) 目視として、上の 4 か所を README で読み直し、`accounts.json` を手で編集させる記述が残っていないことを確かめ、結果（読んだ行番号）を return に書く。触る範囲: なし（実行のみ）
- [ ] 3.5 `plugins/dev-workflow/changes/977.md` を書く。何が変わるか、コマンド名と「別スクリプトにした」理由（design D1・D2）、`accounts-init.sh` との差（`accounts` が配列でない登録簿の扱い。design D5）、戻し方。`version` は上げない。触る範囲: plugins/dev-workflow/changes/977.md（新規）、書式の参照は plugins/dev-workflow/changes/976.md
