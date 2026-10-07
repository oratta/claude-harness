## Why

`scripts/lint.sh` は shellcheck だけを走らせていて、Claude Code 本体の検証（`claude plugin validate`）を通していない。そのため plugin.json や hooks.json の書き間違い（予約名、宣言していない設定値、壊れたパス）は、install して初めて分かる。Claude Code 2.1.280 以降は予約名を真似たマーケットプレイスの読み込みが止まり、2.1.281 で `${user_config.*}` の宣言漏れと `.mcp.json` の欠落の検査が増えたので、PR の段階で同じ検証に通しておく（issue #716、親エピック #717）。

2026-10-07 時点（claude 2.1.292）では、13 プラグインとリポジトリ直下のすべてがエラー 0 で、警告は「version 未記載」（意図どおり。版は commit SHA で決める運用）と「hooks.json の `${CLAUDE_PLUGIN_ROOT}` が引用符なし」（4 プラグイン・13 箇所）の 2 種類だけである。後者は、展開後のパスに空白があるとコマンドが複数の語に割れて失敗するという指摘で、直せる。

## What Changes

- `scripts/lint.sh` が、shellcheck のあとに、リポジトリ直下と各プラグイン（`plugins/<name>`）へ `claude plugin validate` を走らせる。`--strict` は付けない（警告では落とさない）。どれか 1 つでも非 0 なら `scripts/lint.sh` も非 0 で終わる
- `claude` コマンドが無い環境（CI）では、検証を飛ばしたことと理由を出して、shellcheck の結果だけで終了コードを決める
- フィルタ引数付きで呼ばれたとき（`scripts/lint.sh worktree`）は、shellcheck と同じ部分一致で検証対象のプラグインを絞る。リポジトリ直下の検証はフィルタ無しのときだけ走らせる
- 4 プラグイン（capability-registry / cost-ledger / dev-workflow / worktree）の `hooks/hooks.json` の command を、`${CLAUDE_PLUGIN_ROOT}` を含むパス全体を二重引用符で囲んだ形にする（13 箇所）。変えるのは引用符だけで、整形・並べ替え・他の値の変更はしない
- command の文字列を完全一致で検査している既存テスト 4 本を、引用符付きの値に合わせる
- 仕様 `dev-workflow-execution-strategy` の要件「model 未指定の Agent spawn は hook が拒否する」の記述を、`plugins/dev-workflow/scripts/agent-model-guard.sh` の実際の動きに合わせて書き直す（hook の動作は変えない。詳しくは下の Modified Capabilities）

## Capabilities

### New Capabilities
- `lint-plugin-validate`: `scripts/lint.sh` が公式の検証（`claude plugin validate`）をリポジトリ直下と各プラグインに走らせること、`claude` が無い環境での扱い、フィルタ引数との関係、hooks.json の command で `${CLAUDE_PLUGIN_ROOT}` を引用符で囲むこと

### Modified Capabilities
- `dev-workflow-execution-strategy`: 要件「model 未指定の Agent spawn は hook が拒否する」を次のとおり変える。本番の仕様の本文が `agent-model-guard.sh` の実際の動き（fork の共有枠判定だけがセッション記録と snapshot を読み、読めないときに通すのも fork に限る）と食い違っていたため、主の判断（仕様と実物の乖離は不可。issue #716 のコメント）で実装に合わせた。hook の動作は変えない
  - Scenario「hooks.json に配線されている」: command の値を引用符なしの文字列で固定しているので、引用符付きの値に直す
  - 本文 3 段落: fork の共有枠モードの出どころを「usage snapshot の `weekly_all_pct`」から「`usage_view.py` が求める active スロットの実効値（セッション記録と snapshot を突き合わせた値）」に直す／Fable 判定が参照してはならない残量にセッション記録を加える／「snapshot が読めないときは fail-open」を、入力が読めないときの fail-open と、fork の共有枠判定に限った fail-open（セッション記録と snapshot のどちらからも値が求まらないとき `ok` とみなす）に分ける
  - 守備範囲の段落を足す（入力の出どころ・拾う誤り・通してよい例・fail-open の条件）
  - Scenario「fork は共有枠モードで決まり model を渡しても変わらない」: 許可される前提を「snapshot 無し」から「セッション記録も snapshot も無い」に直す
  - Scenario を 2 本足す: 「snapshot が無くてもセッション記録から fork を止める」「snapshot もセッション記録も無くても model 無しは拒否される」
  - 上に挙げた以外の Scenario は変えない

## Impact

- `scripts/lint.sh`（検証の追加。冒頭の説明コメントも合わせる）
- `plugins/{capability-registry,cost-ledger,dev-workflow,worktree}/hooks/hooks.json`（聖域。引用符だけ）
- 既存テスト: `plugins/dev-workflow/tests/subagent-stop-guard.bats`、`plugins/worktree/tests/session-proc-cleanup.bats`、`plugins/cost-ledger/tests/gate-report.bats`、`plugins/cost-ledger/tests/ledger.bats`（command の完全一致の期待値）
- 新規テスト: `tests/lint-plugin-validate.bats`
- 仕様: `openspec/specs/dev-workflow-execution-strategy/spec.md` の上記の要件（archive で置き換わる）。`agent-model-guard.sh` と `plugins/dev-workflow/tests/agent-model-guard.bats` は変えない（書き直した記述と足した Scenario は、既存のテストで確かめられている）
- 変更の記録: `plugins/{capability-registry,cost-ledger,dev-workflow,worktree}/changes/716.md`
- CI（`.github/workflows/ci.yml`）は変えない。CI のランナーには `claude` が無いので、検証は飛ばされ、これまでどおり shellcheck だけが合否を決める。公式の検証が効くのは `claude` のある開発機で `scripts/lint.sh` を走らせたときである
- 同じ hooks.json を後続の issue #710・#714・#715・#591 が触る。この変更は引用符の 2 文字ずつしか足さないので、行の並びは変わらない
