# Tasks

実装予定は proposal の 5 ファイルに限る。OpenSpec artifact・主仕様の同期・`plugins/dev-workflow/changes/1808.md` の追記は仕様記録で、5 ファイルとは別に数える。行番号は HEAD `3de539440938dc90060c0b4746eb48b1e9926a44` 時点の案内で、編集前に該当箇所を読み直す。共通処理・表・利用手順・累計経路は編集しない。一時 fixture と出力の捕捉先は `mktemp -d` の repo 外に作る。以下は仕様レビューの APPROVE 後に実施する。段 A 以外のゲート指摘 18 件は対象外。

## 1. 共通 API 欠損を resolver_unavailable に収める

- [ ] 1.1 `subagent-context.sh` で、ロード時の try に `resolve = resolver.resolve_thresholds` の取得と callable 確認を含め、呼出しを `resolve(model, env)` に変える。API 欠損・非 callable・呼出しの通常例外・必須結果の欠損・診断準備の例外を `resolver_unavailable` にし、`invalid_table` / `invalid_override` の分類を維持する。CLI は stderr に呼出元名・コード・理由、stdout に `error` 文字列の 1 行 JSON、exit 1。捕捉は resolver との境界に限る。先に `subagent-context.bats` へ、①関数欠損 ②非 callable ③呼出し時 `RuntimeError` ④必須キー欠損の戻り値のテストを足して落ちることを確認する（有効な `--cap` 指定でも error JSON・exit 1、`resolver_unavailable`・原因あり・traceback なし）。既存の表破損・不正 env のテストも維持する。触る範囲: plugins/dev-workflow/scripts/subagent-context.sh:164-185（ロードと解決）、plugins/dev-workflow/tests/subagent-context.bats（失敗系のテスト群）
- [ ] 1.2 `context-tripwire.sh` に同じ変更を行う。hook は stderr に呼出元名・コード・理由、stdout 空、exit 0。先に `context-tripwire.bats` へ、同じ 4 種を PreToolUse・PostToolUse の両方で検査するテストを足す。触る範囲: plugins/dev-workflow/scripts/context-tripwire.sh:185-227（ロードと解決）、plugins/dev-workflow/tests/context-tripwire.bats（失敗系のテスト群）

## 2. hook の再検証通知を additionalContext で本人に届ける

- [ ] 2.1 先に `context-tripwire.bats` へ、stdout を JSON として解析するテストを足す。対象は未知モデルと既知モデルの根拠違いで、両イベントの閾値内（通知だけの JSON）、cap 超の PostToolUse（既存 NOTIFY 本文の保持＋別段落）、hard 超の PreToolUse（既存 deny と理由の保持＋`additionalContext` 追加）、`hard <= cap` の PreToolUse（拒否なし・診断だけの JSON）、環境上書き、同じログでの再呼出し（毎回出る・状態ファイルなし）、配布先の手順パス（stderr と `additionalContext` の双方）。診断だけの出力に `permissionDecision`・`decision`・`continue`・`systemMessage` と締め指示が無いこと、再検証不要な既知モデルの閾値内が stdout 空であること、解除・計測不能・解決失敗・正数条件違反が stdout 空であることも検査する。触る範囲: plugins/dev-workflow/tests/context-tripwire.bats（診断・境界のテスト群）
- [ ] 2.2 `context-tripwire.sh` を、利用する文脈指標の `revalidation_required` があるとき stderr 診断に加えて再検証通知を `additionalContext` に入れる形に直す。通知文は要求モデル・根拠モデル・対象指標・手順の絶対パスを含み、「根拠モデルと異なるため、案内した手順でしきい値を再検証する必要がある」と明示する。出力は上の design の表のとおり。`2.1` のテストが通ることと `bats plugins/dev-workflow/tests/context-tripwire.bats` 全体（Unicode キー・探索・worktree・Bash 全拒否・5MB / 100ms を含む）で確認する。触る範囲: plugins/dev-workflow/scripts/context-tripwire.sh:185-300（診断の組み立てと出力）
- [ ] 2.3 CLI の出力が変わらないこと（stderr 診断と測定 JSON）を `subagent-context.bats` の未知モデル・根拠違い・上書き・再呼出しの既存テストで確認し、stdout に通知フィールドが混ざらない検査を足す。触る範囲: plugins/dev-workflow/tests/subagent-context.bats（診断のテスト群）

## 3. 文書を同期して確認する

- [ ] 3.1 `decision-criteria.md` の文脈計測の説明を、CLI は stderr と測定 JSON、hook は本人への `additionalContext`（stderr にも出す）と分かる形へ直す。「stdout は従来の JSON だけに保つ」を、再検証通知が無い場合の記述と通知 JSON の存在が分かる文にする。数値・停止の意味・手渡し権限は変えない。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:38-42（コンテキスト上限の節）
- [ ] 3.2 次を実行して exit 0 を確認する（実機の配送観測は完了条件にしない）。`bats plugins/dev-workflow/tests/subagent-context.bats plugins/dev-workflow/tests/context-tripwire.bats`、`python3 -B -m unittest discover -s plugins/dev-workflow/tests -p 'test_token_thresholds.py'`、`shellcheck --severity=warning plugins/dev-workflow/scripts/subagent-context.sh plugins/dev-workflow/scripts/context-tripwire.sh`、`bats tests/openspec-specs-format.bats tests/injection-budget.bats tests/hook-python-isolation.bats`、`openspec validate fix-context-threshold-notification --type change --strict`。触る範囲: 上記 5 ファイルの照合

## Workflow follow-up

- 本 spec phase は artifact の validate・commit・push までで return する。仕様化判断は #1800 に投稿済み。
- 仕様レビュー（観点: AC3 の到達先、診断だけでは締め・拒否しないこと、stdout 例外と fail-open の整合）の APPROVE 後に、別 phase で実装・verify を行う。
- 実装後に、`plugins/dev-workflow/changes/1808.md` へ今回の修正を追記し、仕様の主仕様への同期と archive は後工程で行う（実装 5 ファイルとは別の仕様記録）。
