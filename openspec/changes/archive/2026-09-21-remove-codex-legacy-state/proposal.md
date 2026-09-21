## Why

#340 で Codex 委譲は呼び出し元と生死を共にする前景実行へ移り、#342 で role ごとの provider routing もその経路で完走した。旧台帳、run-dir、pending、継続記録を残すと、使われない状態管理と CLI・文書・仕様だけが二重に維持されるため、記録先と worktree を唯一の継続状態に揃える。

## What Changes

- **BREAKING** `codex-worker.py` を前景 `run` 専用に縮小し、切り離し起動、SQLite 台帳、所有権、account slot、cwd lock、heartbeat と `register` / `submit` / `status` / `result` / `cancel` / `ack` / `send` / `reap` を廃止する。
- **BREAKING** `codex-develop.py` を前景 `request` 専用に縮小し、run-dir、`run.json`、pending、`init` / `dispatch` / `retry` と継続記録 v1/v2 の生成・復元を廃止する。
- account 登録は永続 registry や独立 `register` コマンドに移さず、呼び出し側が委譲ごとに渡す `--account-home NAME=PATH` / `--account-home-file PATH` の対応表へ一本化する。
- 前景経路が依存する CODEX_HOME の固定、認証照合、model / effort の二段階検証、role ごとの sandbox、read-only role、開始前の quota 確認、親・signal と連動する停止、1 行 JSON 結果を維持する。
- 関連文書を前景経路だけに縮小し、既存状態ディレクトリをコードから自動削除せず、利用者が安全を確認した後の手動削除条件と手順を記載する。
- `codex-worker-concurrency` と `codex-develop-continuation` capability を廃止し、`codex-worker` と `manual-codex-develop` から旧経路だけの要件を除く。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `codex-worker`: 前景 `run` だけを実行基盤として残し、台帳経路・永続 account registry・ownership に関する要件を除く。
- `manual-codex-develop`: `request` と role routing を残し、run / pending / retry / ack を前提とする旧 transport 要件を除く。

### Removed Capabilities（main spec を直接削除。delta では表現できない）

- `codex-worker-concurrency`: 台帳の account slot、cwd 排他、reap の capability 全体を廃止し、archive 前に main spec を直接削除する。
- `codex-develop-continuation`: run-dir と継続記録 v1/v2 の capability 全体を廃止し、archive 前に main spec を直接削除する。

## Impact

- 実装: `plugins/dev-workflow/scripts/codex-worker.py`、`plugins/dev-workflow/scripts/codex-develop.py`
- 文書: `plugins/dev-workflow/scripts/CODEX-WORKER.md`、`plugins/dev-workflow/docs/codex-develop.md`、`plugins/dev-workflow/references/codex-develop.md`、`plugins/dev-workflow/commands/develop.md`、`plugins/dev-workflow/skills/develop/SKILL.md`
- テスト: `plugins/dev-workflow/tests/test_codex_worker.py`、`plugins/dev-workflow/tests/test_codex_develop.py`、`plugins/dev-workflow/tests/handoff-declaration.bats` と注入予算の回帰確認
- 仕様: 上記 4 capability。実装完了後の archive で main specs を縮小・廃止する。
- 運用: dev-workflow 2.13.15 で破壊的 CLI 削除を配布する。既存の `~/.local/state/claude-harness-codex/` は自動移行も自動削除も行わない。
