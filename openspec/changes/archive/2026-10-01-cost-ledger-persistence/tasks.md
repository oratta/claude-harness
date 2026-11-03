## 1. テスト（Red）

- [x] 1.1 `plugins/cost-ledger/tests/ledger.bats` を作り、`helper.bash` の合成ログで台帳・控えファイルを `$BATS_TEST_TMPDIR` に置く（実際の利用者の台帳と会話ログには触れない）。setup で `export LC_ALL=C.UTF-8`
- [x] 1.2 spec の Scenario ごとにテストを書く（未設定・リポジトリ配下・事実と同じ行・2 回実行・増分・控え消失・ファイル間重複・書きかけ末尾・hook の未設定/追記/失敗/同時実行・hooks.json の登録・会話ログ退避後の一致・最後の追記以降の行）

## 2. 実装（Green）

- [x] 2.1 `cost_ledger.py` に台帳の場所の解決とリポジトリ配下の拒否、`ledger_sync()`（ロック・控え・差分読み・重複排除・追記）、`iter_ledger_facts()` を足す
- [x] 2.2 集計系サブコマンドの事実の入口を 1 か所（`load_facts()`）にまとめ、`COST_LEDGER_PATH` があれば追記してから台帳を読む
- [x] 2.3 `ledger-sync` サブコマンドを足す
- [x] 2.4 `scripts/ledger-hook.sh` を書き、`hooks.json` の `Stop` に登録する（timeout 120）

## 3. 文書

- [x] 3.1 `commands/cost.md`・`README.md`・`plugin.json` の description に台帳を書く（未設定なら利用者に聞く）
- [x] 3.2 `plugins/cost-ledger/changes/274.md`

## 4. 確認

- [x] 4.1 実環境の会話ログ（読み取りのみ）と一時ディレクトリの台帳で、差分追記の時間を `time` で測る
- [x] 4.2 会話ログを一時ディレクトリへ複製して台帳へ取り込み、複製を退避したあとの `/cost <PR番号>` が退避前と一致することを確かめる
- [x] 4.3 `bash scripts/test.sh`
