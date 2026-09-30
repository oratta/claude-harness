## 1. テスト（先に書いて落ちることを確かめる）

- [x] 1.1 `test_codex_worker.py` のフィクスチャに、別の email・account_id を持つ認証情報へ `auth.json` を置き換える手段と、同じ email・account_id のまま token だけを替える手段を足す
- [x] 1.2 ターン待機中に同じアカウントの token だけが変わるケースのテストを足し、`status` が `completed`、`error_kind` が `auth_profile_changed` でないこと、`account/read` が変化後に 1 回呼ばれたことを確かめる
- [x] 1.3 ターン待機中に `auth.json` が一時的に壊れた JSON になり、5 秒以内に同じアカウントの内容へ戻るケースのテストを足し、止まらないことを確かめる
- [x] 1.4 壊れた状態が 5 秒を超えて続くケースのテストを足し、`interrupted` と `auth_profile_changed` で止まることを確かめる
- [x] 1.5 識別子は同じだが、変化後の `account/read` が別の email を返すケースのテストを足し、`auth_profile_changed` で止まることを確かめる
- [x] 1.6 読めない状態が 5 秒を超えて中断を決めた後にファイルが同じアカウントの内容へ戻るケース、account/read の不一致で中断を決めた後に一致する内容へ戻るケースのテストを足し、どちらも `error_kind` が `auth_profile_changed` のままで、中断を決めた後に account/read が呼ばれないことを確かめる
- [x] 1.7 停止の合図（SIGTERM）の後に `auth.json` の中身が変わっても account/read が呼ばれず、`error_kind` が `auth_profile_changed` にならないことを確かめる
- [x] 1.8 既存の `test_changed_auth_never_starts_server` と `test_source_auth_change_interrupts_the_running_turn` の書き換え内容を、別アカウントの認証情報への置き換えに直す（期待値は変えない）

## 2. 実装

- [x] 2.1 `runtime_identity_matches` の比較対象から `auth_hash` を外し、`identity` と `account_id_hash` だけを比べる
- [x] 2.2 待機ループで、確認済みの `auth_hash` と違う中身を読んだら `account/read`（`refreshToken: false`）を 1 回呼び、email のハッシュが開始時と同じなら確認済みの値を更新し、違う・取得できないなら `auth_profile_changed` で中断する
- [x] 2.3 待機ループで `auth.json` が読めないときは止めずに次の周で読み直し、読めない状態が 5 秒を超えて続いたら `auth_profile_changed` で中断する。5 秒は名前付き定数にする。runtime symlink の検査とターン開始前の照合は今までどおり厳格にする
- [x] 2.4 一度 `auth_profile_changed` と決めたら値を保持し、以降の周では照合も account/read も呼ばない。停止の合図が出た後も account/read を呼ばない

## 3. ドキュメントと仕様

- [x] 3.1 `CODEX-WORKER.md` の「通常の token refresh でも止まる保守的制約」の記述を消し、email と account_id を比べて止めること、中身の変化では account/read で確かめること、読めない状態の猶予を書く
- [x] 3.2 `plugins/dev-workflow` の plugin.json version を上げ、CHANGELOG に追記する（#380 が先にマージされていれば origin/main を取り込んでから次の版を取る）

## 4. 確認

- [x] 4.1 `python3 -m pytest plugins/dev-workflow/tests/test_codex_worker.py` が exit 0（pytest がこの環境に無いため `python3 -m unittest test_codex_worker` で代えた。49 件 OK）
- [x] 4.2 `bash scripts/test.sh` の全件実行が exit 0（別セッションと同時に走って残留プロセス検査だけで落ちたら単独で再実行して判定する）
- [x] 4.3 `openspec validate codex-worker-same-account-refresh --strict` が exit 0
