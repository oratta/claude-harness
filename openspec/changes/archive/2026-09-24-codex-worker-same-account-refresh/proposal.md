## Why

Codex worker（`plugins/dev-workflow/scripts/codex-worker.py`）は、ターンの待機中に元 CODEX_HOME の `auth.json` のバイト列が 1 バイトでも変わると `auth_profile_changed` で止まる。token の自動更新は同じアカウントのまま `auth.json` を書き換えるので、長い工程ほど途中で止まり、工程を最初からやり直すことになる。エピック #345 の #342 の開発中（PR #348）に 1 回起きた（メールアドレスは同じだった）。`CODEX-WORKER.md` はこれを「通常の token refresh でも止まる保守的制約」として受け入れている。止めたいのは別アカウントへの切り替えであって token の更新ではないので、ファイルの中身ではなくアカウントの識別子で判定する（記録先: issue #426、エピック #345）。

## What Changes

- 実行中の認証情報の照合を、`auth.json` 全体のハッシュ比較から、識別子の比較に改める。比べるのは ID token の email（正規化後のハッシュ）と `tokens.account_id`（ハッシュ）の 2 つで、どちらかが開始時と違えば従来どおり `auth_profile_changed` で止める。
- 識別子が同じまま `auth.json` の中身だけが変わったときは、その変化 1 回につき `account/read`（`refreshToken: false`）を 1 回呼び、app-server が返す実行中アカウントの email が開始時と同じなら続行する。違う・取得できないときは `auth_profile_changed` で止める。
- ターンの待機中に `auth.json` が読めない（書き換え途中の JSON、id_token 欠落など）ときは、その時点では止めずに次の確認で読み直す。読めない状態が 5 秒を超えて続いたら `auth_profile_changed` で止める。
- runtime の認証 symlink が差し替えられたときの `runtime_auth_link_changed` 停止、ターン開始前の照合、`server_identity_mismatch` は変えない。
- `CODEX-WORKER.md` の「通常の token refresh でも止まる保守的制約」の記述を消し、何を比べて止めるかを書く。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `codex-worker`: 「前景実行はアカウントを依頼された CODEX_HOME で固定する」要件に、実行中の照合を識別子で行うこと、同じアカウントの token 更新では止めないこと、別アカウントへの切り替えと読めない状態の継続では止めることを足す。

## Impact

- `plugins/dev-workflow/scripts/codex-worker.py`（`auth_info` / `runtime_identity_matches` / `run_turn` の待機ループ）
- `plugins/dev-workflow/tests/test_codex_worker.py`（同じアカウントの token 更新・別アカウントへの切り替え・書き換え途中の読み取りのテスト。既存の `auth_profile_changed` テスト 2 件は、書き換え内容を「末尾に空白を足す」から「別アカウントの認証情報に替える」へ直す）
- `plugins/dev-workflow/scripts/CODEX-WORKER.md`
- `openspec/specs/codex-worker/spec.md`
- `plugins/dev-workflow` の plugin.json version と CHANGELOG（#380 と並行のため、先にマージされた側に合わせて取り直す）
- 範囲外: ID token の署名検証、複数 workspace の完全識別、認証の自動切り替え
