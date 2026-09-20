## Why

Issue #320: Codex worker の書き込み先が cwd のみに制限され、テスト用 TMPDIR を worktree 内へ移すと「Git 管理外」の前提が壊れる。ジョブ専用の一時領域だけを許可し、Codex implement role 自身で全件テストを完走できるようにする。

## What Changes

- workspace-write role のジョブに、Git 管理外の専用一時ディレクトリを一つ割り当て、子プロセスの TMPDIR と追加 writableRoot にする。
- ジョブ単位の所有者一致・0700、同一 run 内を含む別ジョブへの割り当て・再利用の禁止、確認済み終了後の ack を待たない削除を契約にする。停止未確認の unknown は所有を保持し、運用回復が未実装のため最終的な自動削除までは保証しない。
- /tmp 全体・呼び出し元 TMPDIR の追加許可、network、approval、read-only role の緩和は禁止する。
- fake 回帰試験と実 Codex の全件テスト・境界プローブを分けて記録する。

## Capabilities

### New Capabilities

- `codex-worker`: 未同期の `add-codex-worker/specs/codex-worker/spec.md` にある基盤契約へ、一時領域に関する ADDED Requirements だけを追加する。main specs にはこの capability がまだ無いので New に記載するが、基盤機能を再定義しない。

### Modified Capabilities

なし。`codex-develop-continuation` の run 復元・品質工程・coordinator 境界は据え置く。

## Impact

対象は `codex-worker.py`、`test_codex_worker.py`、`CODEX-WORKER.md`、dev-workflow の `plugin.json`、および `scripts/test.sh` と `tests/test-sh-residual-guard.bats`（砂場でプロセス一覧が取れないときに残留プロセス検査を諦める変更。全件テスト完走の前提としてオーナー判断で追加）。常時注入ファイル・予算は変更しない。既存 `add-codex-worker` の未完タスク、burn、send、unknown 自動復旧は引き取らない。

Step B は設計判断・観測可能な変更・利用者向け docs 更新に該当する。Step C は単一 change：5 つの受け入れ条件はすべて「専用一時領域の許可と寿命」という一つの設計判断に従属し、独立してマージする機能ではない。記録先は https://github.com/oratta/claude-harness/issues/320 。仕様化判断コメントは coordinator が代理投稿する。
