## Why

マルチアカウントの起動時選択の入口 `cld` / `cld-account` は、README の zsh function を各端末の `~/.zshrc` に貼る方式で、機能の本体（`select-account.sh` 等）だけが harness にある。端末を増やすたびに手で写す必要があり、harness を直しても各端末の `.zshrc` に届かない。`epic-dispatch.sh` の子セッション起動の既定も「ログイン zsh に定義された `cld`」なので、写し漏れがあるとエピックの起動まで止まる（#1232）。

## What Changes

- `plugins/dev-workflow/bin/cld` と `bin/cld-account` を実行ファイルとして置く（今の関数と同じ挙動: probe を best-effort で実行 → `select-account.sh` で選択 → 選択値が空なら `env -u`、非空なら設定して `claude` を起動。selector が非 0 なら同じ status で終わり `claude` を起動しない）
- 個人の既定フラグは環境変数 `CLD_DEFAULT_ARGS` で渡す（コードに埋めない）。`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` は外から渡された値を上書きしない
- README「Claude アカウントの起動時選択」の貼り付け例を、PATH の 1 行と環境変数の 1 行だけに置き換える（#501 の食い違いもここで解消）
- `epic-dispatch.sh` の起動コマンドの既定を、ログイン zsh の関数 `cld` ではなく `bin/cld` の絶対パスにする。`EPIC_DISPATCH_CLAUDE_CMD` の指定は今までどおり優先する
- **BREAKING（利用者の作業）**: 既存端末の `.zshrc` の関数定義は削除し、PATH と環境変数の行に置き換える（関数が残っていても動くが、関数が PATH の実行ファイルに勝つので古い挙動が続く）

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `usage-account-registry`: 要件「shell function から選択したアカウントで Claude を起動する」を、実行ファイル `bin/cld` / `bin/cld-account` と `CLD_DEFAULT_ARGS` の契約に変える
- `dev-workflow-develop`: `epic-dispatch.sh` の起動コマンドの既定を `bin/cld` の絶対パスにする要件を足す

## Impact

- 新規: `plugins/dev-workflow/bin/cld`、`plugins/dev-workflow/bin/cld-account`
- 変更: `plugins/dev-workflow/scripts/epic-dispatch.sh`（444 行目の既定、52 行目のコメント）、`plugins/dev-workflow/README.md`（15 行目と「Claude アカウントの起動時選択」節）、`plugins/dev-workflow/skills/develop/references/epic.md`（136・140 行目の `cld` の説明）、`plugins/dev-workflow/skills/develop/SKILL.md`（`cld` の既定の説明箇所）、`plugins/dev-workflow/tests/account-selector.bats`（README の関数を取り出すテストを実行ファイルのテストに変える）、`plugins/dev-workflow/tests/epic-dispatch.bats`（既定の語の照合）、`plugins/dev-workflow/changes/1232.md`
- README の導入手順は #1232〜#1236 の子が同じ箇所に書き足す。この change は #1232 の分だけを書き、先にマージされた子と衝突したら origin/main に追従して両方の記述を残す
