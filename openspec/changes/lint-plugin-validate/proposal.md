## Why

`scripts/lint.sh` は shellcheck だけを走らせていて、Claude Code 本体の検証（`claude plugin validate`）を通していない。そのため plugin.json や hooks.json の書き間違い（予約名、宣言していない設定値、壊れたパス）は、install して初めて分かる。Claude Code 2.1.280 以降は予約名を真似たマーケットプレイスの読み込みが止まり、2.1.281 で `${user_config.*}` の宣言漏れと `.mcp.json` の欠落の検査が増えたので、PR の段階で同じ検証に通しておく（issue #716、親エピック #717）。

2026-10-07 時点（claude 2.1.292）では、13 プラグインとリポジトリ直下のすべてがエラー 0 で、警告は「version 未記載」（意図どおり。版は commit SHA で決める運用）と「hooks.json の `${CLAUDE_PLUGIN_ROOT}` が引用符なし」（4 プラグイン・13 箇所）の 2 種類だけである。後者は、展開後のパスに空白があるとコマンドが複数の語に割れて失敗するという指摘で、直せる。

## What Changes

- `scripts/lint.sh` が、shellcheck のあとに、リポジトリ直下と各プラグイン（`plugins/<name>`）へ `claude plugin validate` を走らせる。`--strict` は付けない（警告では落とさない）。どれか 1 つでも非 0 なら `scripts/lint.sh` も非 0 で終わる
- `claude` コマンドが無い環境（CI）では、検証を飛ばしたことと理由を出して、shellcheck の結果だけで終了コードを決める
- フィルタ引数付きで呼ばれたとき（`scripts/lint.sh worktree`）は、shellcheck と同じ部分一致で検証対象のプラグインを絞る。リポジトリ直下の検証はフィルタ無しのときだけ走らせる
- 4 プラグイン（capability-registry / cost-ledger / dev-workflow / worktree）の `hooks/hooks.json` の command を、`${CLAUDE_PLUGIN_ROOT}` を含むパス全体を二重引用符で囲んだ形にする（13 箇所）。変えるのは引用符だけで、整形・並べ替え・他の値の変更はしない
- command の文字列を完全一致で検査している既存テスト 4 本を、引用符付きの値に合わせる

## Capabilities

### New Capabilities
- `lint-plugin-validate`: `scripts/lint.sh` が公式の検証（`claude plugin validate`）をリポジトリ直下と各プラグインに走らせること、`claude` が無い環境での扱い、フィルタ引数との関係、hooks.json の command で `${CLAUDE_PLUGIN_ROOT}` を引用符で囲むこと

### Modified Capabilities
- `dev-workflow-execution-strategy`: 要件「model 未指定の Agent spawn は hook が拒否する」の Scenario「hooks.json に配線されている」が command の値を引用符なしの文字列で固定しているので、引用符付きの値に直す（要件の本文と他の Scenario は変えない）

## Impact

- `scripts/lint.sh`（検証の追加。冒頭の説明コメントも合わせる）
- `plugins/{capability-registry,cost-ledger,dev-workflow,worktree}/hooks/hooks.json`（聖域。引用符だけ）
- 既存テスト: `plugins/dev-workflow/tests/subagent-stop-guard.bats`、`plugins/worktree/tests/session-proc-cleanup.bats`、`plugins/cost-ledger/tests/gate-report.bats`、`plugins/cost-ledger/tests/ledger.bats`（command の完全一致の期待値）
- 新規テスト: `tests/lint-plugin-validate.bats`
- 変更の記録: `plugins/{capability-registry,cost-ledger,dev-workflow,worktree}/changes/716.md`
- CI（`.github/workflows/ci.yml`）は変えない。CI のランナーには `claude` が無いので、検証は飛ばされ、これまでどおり shellcheck だけが合否を決める。公式の検証が効くのは `claude` のある開発機で `scripts/lint.sh` を走らせたときである
- 同じ hooks.json を後続の issue #710・#714・#715・#591 が触る。この変更は引用符の 2 文字ずつしか足さないので、行の並びは変わらない
