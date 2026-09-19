# 手動Codex開発の検証記録

## 検証した版と範囲

- 最新機能HEAD: `7f438095930ca7127c58fd5b1fb4bbde45f21c06`。worker-state既定値とrun-dir規則を追加した版。
- 実モデル最終レビューの実行版: `415b750`（#706 `4b25e8b` の最終回答抽出修正を統合）。最初の3工程は#706 `f8981a6`ベース。
- coordinatorは親CodexがCLIを操作した。**Claude自身がslash commandから全工程を自律実行した試験ではない。** GitHub投稿、finish/archive/Gの本番ゲートは未実走。
- 隔離ローカルgit worktreeで4工程を実行。モデルは `gpt-6-astra`。グローバルpluginは変更せず、PR mergeもしていない。

## 実モデルで確認したこと

| 工程 | 結果 | 別thread | totalTokens |
|---|---|---|---:|
| 仕様作成 | completed、仕様を親がcommit | `01a0ad22-ea09-7f61-b33a-72ccfe576cf4` | 204450 |
| 独立仕様レビュー | completed、APPROVE、ack/accept成功 | `01a0ad24-c360-7af1-8780-5d65afe535c1` | 118727 |
| 実装/テスト | completed、親commit後check成功 | `01a0ad25-81ea-71d3-ba57-247aebdc38e9` | 193471 |
| 独立実装レビュー | 修正後workerでcompleted、APPROVE、ack/accept成功 | `01a0ad2a-81a3-7371-b96e-8f8deb39585d` | 289324 |

全4工程error_kindはnull。レビューは別fresh thread/read-only role。仕様commitは `c170e07a00bc7af2dc17662993a0c6e5a47a136e`、実装commitは `585004d7c3657651149abc2bbd27de6378e4cf48`。run.jsonには両承認のHEAD/job_id/仕様hashが記録された。親のcheckは実装HEADで `python3 -m unittest -v` exit 0、6テスト（親による集計で49 subcases）、unchanged=true。

ローカル証拠は `/tmp/flatmate-burn-epic/manual-e2e-paths.json` が指すrootの `spec-result.json`, `spec-review-result.json`, `implement-result.json`, `review-result.json` とrun/run.json。これら一時ファイルを永続成果物とはみなさず、本記録に主要結果を保存する。

合計は **805972 totalTokens**（input 799622、output 6350、cachedInput 680192）。cachedInputはinputの内数で、再加算しない。これはApp Server通知によるトークン計数であり、現在のcontextサイズ、課金額、リミット消費%ではない。**Claude coordinatorの消費は未計測**であり、Claude対Codexの消費比をこの試験から推定できない。

## 回帰と独立レビュー

- worker隔離20件＋手動入口13件＝33件成功。
- 既存develop-command/skill/roles、marketplace-sync、injection-budget Bats計177件成功（`c466288`時点）。その後の承認・保存先修正は上記33件で確認した。
- OpenSpec strict / git diff --check成功。
- 独立実装レビューで再現された2件は親による再レビューでCLOSED: commentaryのAPPROVEが最終REQUEST_CHANGESを上書きする問題、error_kind付きcompletedを承認する問題。
- 修正は最終回答の一意な抽出と、入口側の一意なAPPROVE＋error_kind空の検証。矛盾/重複判定、認証変更/未対応要求エラーを回帰fixtureで拒否する。

## 手動で起動する入口

このマシンの既定worker台帳 `$HOME/.local/state/claude-harness-codex/jobs` には、親が `current` を登録済み。既存CODEX_HOMEを参照し、秘密をコピーしていない。他マシンでは `docs/codex-develop.md` のregisterを実施する。

```sh
claude --plugin-dir /absolute/path/to/codex-develop-707/plugins/dev-workflow
```

Claudeの会話で:

```text
/dev-workflow:develop --executor codex --account current --model gpt-6-astra <issue URLまたは依頼>
```

別worker台帳なら `--worker-state DIR` を指定する。新規runは `$HOME/.local/state/claude-harness-codex/runs/<UUID>` に作られ、本体が返された絶対pathを保存する。再開時は `--run-dir <保存path>` を指定する。詳細なphase/check/accept/差戻し/archive操作は `plugins/dev-workflow/docs/codex-develop.md` が入口。

手動入口を用意し、共通workerを通した主要4工程を実証した段階。Claude slashによる一件の公開PR完走や、全hook保証・全account配分・burn接続まで検証済みとは扱わない。

## 訂正: executor指定による品質ワークフロー分岐を撤去

上記の実測・テストは当時の履歴として残す。旧版ではCodex入口が独自に仕様必須、承認hash/check/archive状態を管理しており、既存developの「仕様化判断: しない」経路を塞いでいた。この挙動は要件に反するため撤去する。`--spec-path` / `--required-check` / `accept-review` / `check` / `relocate-spec` は現行入口に存在しない。

現行adapterは役割の起動・回収・中断・実行先固定とownershipのtransportのみを担当する。仕様要否、レビュー、検証、順序は通常のdevelop正本が一元管理する。旧33テストと旧4工程の記録を、訂正後の独自ゲート存在や現行通し検証の根拠には使わない。workerの最終回答抽出、認証・ownership・read-only・unknownの安全境界は維持する。訂正後のテスト結果は親タスクが追記する。

訂正後は親タスクがworker20件＋adapter10件＝30件の成功を確認。旧runの品質フィールドを無視して再開でき、pendingは受領後のみ次へ進む。仕様不要経路もadapterによる追加条件なしで既存developへ接続する。実モデル4工程の追加再実行はしていない。

追加レビューで旧版pendingの送信前失敗からの復旧経路を補った。`retry` は保存requestのidentity一致を検証し同じrequestを再送する。独自品質metadataは無視する一方、pending/ownershipは維持する。親タスクでworker20＋adapter12＝32件の最終検証が成功（exit 0）。既存Bats177件、OpenSpec strict、diff checkも成功。独立レビューで旧pendingの同一ID・payload再送を再現確認しCLOSED。adapter→実worker→模擬App Serverの仕様なし実装/read-onlyレビュー回収も成功。今回の検証では実モデルを呼んでいない。

## 継続設定の復元（issue #315）

2026-09-19、基点 HEAD `cec253f0098b480538802e02618c73965aec5aad` の作業差分で検証した。正本は `openspec/changes/codex-develop-continuation-state/specs/codex-develop-continuation/spec.md`。

`codex-develop.py` の `restore_continuation` は coordinator が取得したコメントを受け取り、issue が存在すればそのコメントだけ、存在しなければ Draft PR のコメントだけを解析し、最新候補を保存済み run と照合する。`issue_comments=None` は issue 不在、空リストは issue にコメントがない状態であり、後者では PR に fallback しない。取得・保存・復元後の dispatch は coordinator の責務のまま。

`plugins/dev-workflow/tests/test_codex_develop.py` に以下の fixture を追加した。

| テスト名 | spec シナリオと確認内容 |
|---|---|
| `test_duplicate_keys_in_latest_record_stop_without_using_older_record` | 「記録形式と重複候補を fixture で判定する」: 6 キー内の重複と追加の重複キーを拒否し、古い正常記録へ戻らない |
| `test_restore_uses_only_issue_or_draft_pr_selected_source` | 同シナリオ: issue 優先、issue 不在なら Draft PR、未選択側の新しい不正記録を無視、選択側が空・不正なら停止。古い正常候補も無視 |
| `test_initial_record_restores_same_run_and_dispatch_identity` | 「初回設定から追加依頼を復元する」「追加依頼でも担当を変更しない」: 実 init → 記録 → 復元 → 実 dispatch を接続し、run/account/model/worker-state/cwd と追加依頼を確認。外部 worker transport のみ mock |
| `test_run_json_mismatch_stops_before_delegation` | 「記録が不一致または曖昧」: run.json の account/model/worker-state/cwd 各不一致とファイル不在で停止し、worker 呼び出し・request 作成がないことを確認 |

実行結果:

- Red: `TMPDIR="$PWD/.tmp-bats" python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_develop.py -k ContinuationRecord -v` → exit 1。8 テスト中 3 メソッドで未実装の `restore_continuation` によるエラー（subtest を含む errors=7）。重複キーの拒否は既存実装で成功。
- 実装後: `TMPDIR="$PWD/.tmp-bats" python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_develop.py -v` → exit 1。20 件中 19 成功、1 失敗。継続テスト 8 件（追加 4 件を含む）は全件成功。
- 残る失敗は `test_no_spec_assignment_reaches_actual_worker_and_preserves_review_result`。診断で terminal の `error_kind=unsupported_project_config`、`status=failed` を確認した。fixture は HOME を一時ディレクトリに置き換えるが、今回の TMPDIR は実ユーザーのホーム配下にあり、その祖先の `~/.codex/config.toml` を worker が project config として拒否する。前回と同じ分類 (b) の環境依存失敗で、修正対象外。
- `OPENSPEC_TELEMETRY=0 openspec validate codex-develop-continuation-state --strict` → exit 0。
- `scripts/test.sh` は coordinator の別環境での結果を後から受領するため、この工程では実行していない。

未了: issue #315 / tasks 2.3 の、追加依頼を含む公開 PR の finish/G までの実測。coordinator が実行コマンド、exit code、対象 HEAD、同一 executor/account/model/run-dir/worker-state/cwd の委譲記録、finish/G 結果と証跡 URL を追記する。上記 fixture と transport の成功は公開 PR 完走・品質承認の証拠ではなく、change 全体の検証完了とは扱わない。
