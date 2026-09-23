## 1. 常設の静的スコープ検査（TDD の Red をここで立てる）

- [ ] 1.1 `tests/bats-assertion-guard.bats` に、spec のスコープ検査コマンド（`git ls-files '*.bats' ':(exclude)_longruns/' | xargs grep -nE '^[[:space:]]*! ' | grep -vE '\|\| return 1[[:space:]]*(#.*)?$'`）を実行し出力が空であることを確認するテストを追加する
- [ ] 1.2 このテストを実行し、ガード適用前は Red（166 件前後ヒットする）であることを確認する

## 2. 実行時の実演テスト（バージョン非依存）

- [ ] 2.1 同じファイルに、途中に `! false`（または相当する必ず失敗する否定検査）を `|| return 1` 付きで置いた fixture テストを子プロセスの bats で起動し、実行した bash のバージョンに関わらず `not ok` になることを確認するテストを書く（`printf`/`echo` で組み立て、ソース上に行頭 `! ` の行を出現させない。design.md「採用4」）
- [ ] 2.2 同様に、ガード無しの fixture テストを子プロセスの bats で起動し、実行した bash のバージョンに関わらず `ok`（素通り）になることを確認するテストを書く（`skip` は使わない）

## 3. 対象ファイルへのガード適用（単独文の `! cmd` は最後の文も含め全部）

- [ ] 3.1 `plugins/casting/tests/casting-consultation.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.2 `plugins/daily-report/tests/llm-log-compactor.bats` / `skill-phase-control.bats` / `voice-compactor.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.3 `plugins/dev-workflow/tests/account-selector.bats` / `agent-model-guard.bats` / `automerge-templates.bats` / `context-tripwire.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.4 `plugins/dev-workflow/tests/develop-command.bats` / `develop-roles.bats` / `develop-skill.bats` / `issueify-skill.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.5 `plugins/dev-workflow/tests/model-escalation-policy.bats` / `pr-body-format.bats` / `pr-review-gate-skill.bats` / `pr-review-gate-spec-declaration.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.6 `plugins/dev-workflow/tests/push-guard-setup.bats` / `retirement.bats` / `shared-references.bats` / `spec-decision-and-review.bats` / `spec-touch-check.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.7 `plugins/dev-workflow/tests/subagent-context.bats` / `subagent-waiting.bats` / `tripwire-hook.bats` / `usage-probe-multi-account.bats` / `usage-probe.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.8 `plugins/infra/tests/infra-fixes.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.9 `plugins/statusline/tests/statusline-multi-account.bats` / `statusline.bats` の単独文 `! cmd`（`! [[ ... ]]` 3箇所を含む）に `|| return 1` を付ける
- [ ] 3.10 `plugins/weekly-report/tests/command-hygiene.bats` / `skill-jsonl-direct.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.11 `plugins/worktree/tests/skill-safety.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [ ] 3.12 `tests/always-on-injection-scope.bats` / `tests/test-sh-residual-guard.bats` の単独文 `! cmd` に `|| return 1` を付ける

## 4. 検証

- [ ] 4.1 タスク 1.1 のスコープ検査テストが Green（出力 0 行）になったことを確認する
- [ ] 4.2 タスク 2.1 / 2.2 の実演テストが green になったことを確認する
- [ ] 4.3 `bash scripts/test.sh` を実行し、全件 green（exit 0）であることを確認する。ガードを付けた結果として落ちるテストが出たら、その内容を記録して別途 issue を切る（本 change の受け入れ条件は変えない）

## 5. 事務手続き

- [ ] 5.1 触ったプラグイン（`dev-workflow` / `statusline` / `casting` / `daily-report` / `infra` / `weekly-report` / `worktree`）の `plugin.json` の patch バージョンを上げる
- [ ] 5.2 `.claude-plugin/marketplace.json` を同期する
- [ ] 5.3 `plugins/dev-workflow/CHANGELOG.md`（および該当する他プラグインの CHANGELOG があれば）に本変更を追記する
