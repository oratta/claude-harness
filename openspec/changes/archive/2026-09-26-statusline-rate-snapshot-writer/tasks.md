## 1. Writer 契約のテストを先に追加する

- [x] 1.1 flatmate の writer テスト A〜I と integration test の writer ケースを参照し、全キー、帰属、時刻継承・更新、欠損入力、host 正規化、原子的置換を `plugins/statusline/tests/` の bats / pytest に追加して Red を確認する
- [x] 1.2 環境変数・設定ファイル・空文字 override・共有失敗・ローカルとの本文一致をテストに追加して Red を確認する
- [x] 1.3 既存 snapshot fixture に必要な `session_id` を加え、5 キー固定の期待値を新形式へ更新する。表示の既存アサーションは維持する

## 2. Writer を実装する

- [x] 2.1 `plugins/statusline/scripts/statusline.sh` に保存先印、入力 `session_id`、有効な `account_id`、`host`、`obs_sig` と観測・書込時刻を組み立てる処理を追加する
- [x] 2.2 ローカルと共有への原子的書込、共有先解決、失敗時の表示とローカルへの影響抑止を実装し、追加テストを Green にする

## 3. 説明と検証

- [x] 3.1 `plugins/statusline/README.md` に writer 形式と共有設定、および非既定の writer 保存先を使う場合は reader 側の `RATE_GUARD_SNAPSHOT` を同じファイルに合わせる必要を説明し、`plugins/statusline/changes/517.md` に版を上げず変更記録を残す
- [x] 3.2 `usage-session-records` の MODIFIED delta で既存の snapshot 形状固定を `rate-snapshot` の writer 契約への参照に改め、セッション記録と実効値の要件を維持する
- [x] 3.3 `bats plugins/statusline/tests/`、`python3 -m pytest plugins/statusline/tests/`、`openspec validate --all` を実行して全て exit 0 を確認し、描画出力の既存テストが通ることを確認する
