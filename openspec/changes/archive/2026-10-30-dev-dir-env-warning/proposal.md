## Why

開発用 clone の場所を決める環境変数 `CLAUDE_HARNESS_DEV_DIR` が未設定でも、利用者はそれに気づけない。気づくのは worktree を切ろうとして失敗した時点になる（#1234、エピック #1237 の子）。

## What Changes

- worktree プラグインに SessionStart フックを 1 本足す。harness のリポジトリ（開発用 clone とその worktree）でセッションを始め、かつ変数が未設定か空のときだけ、1 行の警告を出す。セッションは止めない
- README の「ローカル開発」の節に、この変数の意味と入れ方を書く
- セットアップ用コマンド（値を聞いて settings.json に書く）は作らない。settings.json を書き換える部品が増えるのに対し、入れ方は README の数行で足りるため

## Capabilities

### New Capabilities
- `worktree-dev-dir-env-warning`: 開発用 clone の場所の変数が未設定のとき、harness の作業の前にだけ警告する

## Impact

- `plugins/worktree/hooks/hooks.json`・`plugins/worktree/scripts/`（新規 1 本）・`plugins/worktree/tests/`・`README.md`・`plugins/worktree/changes/1234.md`
- 常時注入の予算（`tests/injection-budget.bats`）には触れない見込み（フックの出力は未設定時の 1 行だけで、固定の注入ではない）
