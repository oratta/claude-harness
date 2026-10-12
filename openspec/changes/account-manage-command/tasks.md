行番号は仕様づくりの時点（HEAD 7225146d）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。テストは実装より先に書き、落ちることを見てから実装する。

## 1. テスト（先に書く）

- [ ] 1.1 `accounts-command.bats` を新規に作り、spec の Scenario を 1 件ずつテストにする（空の登録簿への追加、既存 id の追加は exit 2 かつ登録簿不変かつディレクトリ不作成、`enabled` 無し → off → on で他の欄と順序が不変、存在しない id の on / off は exit 2 かつ不変、一覧のオフ表示、壊れた登録簿は exit 1 かつ不変、`.bak` が実行前と同一、`CLAUDE_ACCOUNTS_HOME` が相対パスなら exit 2、未知のサブコマンドと引数欠落は exit 2、`accounts-init.sh` の既存 bats が通ること）。登録簿は `CLAUDE_ACCOUNTS_FILE`、基点は `CLAUDE_ACCOUNTS_HOME` を一時ディレクトリに向ける。足場は `account-selector.bats` の `setup` / `teardown` に倣う。触る範囲: plugins/dev-workflow/tests/accounts-command.bats（新規）、plugins/dev-workflow/tests/account-selector.bats:9-34（setup と write_registry の書き方の参照）
- [ ] 1.2 `account-selector.bats` の `enabled:` の並びの末尾に、`accounts.sh off b` で書き換えた登録簿で `select-account.sh` を実行し、`b` が選ばれず `margins` に `b:off` が出るテストを 1 件足す。触る範囲: plugins/dev-workflow/tests/account-selector.bats:390-407（`enabled: an off slot is not selected...` のテストを雛形にする）、末尾に追加

## 2. スクリプト

- [ ] 2.1 `plugins/dev-workflow/scripts/accounts.sh` を新規に作る。冒頭のコメントに、正本が `openspec/specs/usage-account-registry`、`accounts-init.sh` との使い分け、`.bak` の 1 世代を書く。引数処理（`require_value` 相当、id と label の検査）は `accounts-init.sh` に倣う。書き込みは python3 の `mkstemp` ＋ `os.replace`、書く前に `.bak` へコピー。触る範囲: plugins/dev-workflow/scripts/accounts.sh（新規）、plugins/dev-workflow/scripts/accounts-init.sh:26-62（引数処理と検査）、plugins/dev-workflow/scripts/accounts-init.sh:64-124（python の読み書き）
- [ ] 2.2 実行権限を付ける（`chmod +x`。`accounts-init.sh` と同じ）。触る範囲: なし
- [ ] 2.3 `bats plugins/dev-workflow/tests/accounts-command.bats plugins/dev-workflow/tests/account-selector.bats plugins/dev-workflow/tests/usage-probe-multi-account.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 3. docs

- [ ] 3.1 `plugins/dev-workflow/README.md` の「Claude アカウントの起動時選択」の末尾の文「切り替えは当面 `accounts.json` を手で書き換える。」を、`accounts.sh list|add|on|off` の使い方（コマンド例を含む）に置き換える。最初の `add` では既定アカウントのスロットができないので、既定アカウントも並べるなら `accounts-init.sh` を使う旨を 1 文足す。触る範囲: plugins/dev-workflow/README.md:82
- [ ] 3.2 `plugins/statusline/README.md` の「レジストリの作り方」に `accounts.sh add` の手順を足し、「切り替えは当面 `accounts.json` を手で書き換える」を `accounts.sh on|off` の案内に置き換える（`accounts-init.sh` で登録し直しても `enabled` が消えない旨の括弧は残す）。触る範囲: plugins/statusline/README.md:102-115、plugins/statusline/README.md:156
- [ ] 3.3 `grep -n "手で書き換える" plugins/dev-workflow/README.md plugins/statusline/README.md` が 0 件になることを確かめる（issue の成果物条件の `accounts.json を手で` は、README の表記が `` `accounts.json` を手で`` と間にバッククォートを挟むため、現状でも 0 件で検査にならない。そのため実際の文言「手で書き換える」で確かめる）。触る範囲: なし（実行のみ）
- [ ] 3.4 `plugins/dev-workflow/changes/977.md` を書く。何が変わるか、コマンド名と「別スクリプトにした」理由（design D1・D2）、戻し方。`version` は上げない。触る範囲: plugins/dev-workflow/changes/977.md（新規）、書式の参照は plugins/dev-workflow/changes/976.md
