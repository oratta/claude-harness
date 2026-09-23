## 1. 常設の静的スコープ検査（TDD の Red をここで立てる）

- [x] 1.1 `tests/bats-assertion-guard.bats` に、spec のスコープ検査コマンド（`git ls-files '*.bats' ':(exclude)_longruns/' | xargs grep -nE '^[[:space:]]*! ' | grep -vE '\|\| return 1[[:space:]]*(#.*)?$'`）を実行し出力が空であることを確認するテストを追加する
- [x] 1.2 このテストを実行し、ガード適用前は Red（166 件前後ヒットする）であることを確認する

## 2. 実行時の実演テスト（バージョン非依存）

- [x] 2.1 同じファイルに、途中に `! true`（または相当する、常に成功するコマンドを否定して「アサーション違反」を模する否定検査。`! false` は否定すると常に成功側に転ぶため不採用）を `|| return 1` 付きで置いた fixture テストを子プロセスの bats で起動し、実行した bash のバージョンに関わらず `not ok` になることを確認するテストを書く（`printf`/`echo` で組み立て、ソース上に行頭 `! ` の行を出現させない。design.md「採用4」。あわせてヒアドキュメントに行頭 `@test` を書かず、既存の `write_guarded_fixture` / `write_guardless_fixture` と同じく `echo`/`printf` で組み立てる。CI の bats 1.10 が行頭 `@test` を素朴に数えテスト数が狂う事故が #284 で実際に起きたため）
- [x] 2.2 同様に、ガード無しの fixture テストを子プロセスの bats で起動し、実行した bash のバージョンに関わらず `ok`（素通り）になることを確認するテストを書く（`skip` は使わない。ヒアドキュメントの行頭 `@test` 回避は 2.1 と同じ）

## 3. 対象ファイルへのガード適用（単独文の `! cmd` は最後の文も含め全部）

- [x] 3.1 `plugins/casting/tests/casting-consultation.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.2 `plugins/daily-report/tests/llm-log-compactor.bats` / `skill-phase-control.bats` / `voice-compactor.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.3 `plugins/dev-workflow/tests/account-selector.bats` / `agent-model-guard.bats` / `automerge-templates.bats` / `context-tripwire.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.4 `plugins/dev-workflow/tests/develop-command.bats` / `develop-roles.bats` / `develop-skill.bats` / `issueify-skill.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.5 `plugins/dev-workflow/tests/model-escalation-policy.bats` / `pr-body-format.bats` / `pr-review-gate-skill.bats` / `pr-review-gate-spec-declaration.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.6 `plugins/dev-workflow/tests/push-guard-setup.bats` / `retirement.bats` / `shared-references.bats` / `spec-decision-and-review.bats` / `spec-touch-check.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.7 `plugins/dev-workflow/tests/subagent-context.bats` / `subagent-waiting.bats` / `tripwire-hook.bats` / `usage-probe-multi-account.bats` / `usage-probe.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.8 `plugins/infra/tests/infra-fixes.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.9 `plugins/statusline/tests/statusline-multi-account.bats` / `statusline.bats` の単独文 `! cmd`（`! [[ ... ]]` 3箇所を含む）に `|| return 1` を付ける
- [x] 3.10 `plugins/weekly-report/tests/command-hygiene.bats` / `skill-jsonl-direct.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.11 `plugins/worktree/tests/skill-safety.bats` の単独文 `! cmd` に `|| return 1` を付ける
- [x] 3.12 `tests/always-on-injection-scope.bats` / `tests/test-sh-residual-guard.bats` の単独文 `! cmd` に `|| return 1` を付ける

## 4. 検証

- [ ] 4.1 タスク 1.1 のスコープ検査テストが Green（出力 0 行）になったことを確認する
- [ ] 4.2 タスク 2.1 / 2.2 の実演テストが green になったことを確認する
- [ ] 4.2a 書き換えた個々の検査が実際に退行を捕まえるかを、代表的な書き方ごとに変形テストで確かめる（issue #283 コメント https://github.com/oratta/claude-harness/issues/283#issuecomment-5624508260 の指摘に対応）。作業ツリーを汚さない形（一時コピー等）で、対象ファイルや出力を一時的に書き換えて否定条件を成り立たせ、ガード付きなら `not ok`・ガードを外すと `ok` になることを確認する。対象:
  - `plugins/dev-workflow/tests/context-tripwire.bats` のテスト `implementation: shlex import and GIT_* constants are gone (window fully closed)`（issue 本文が挙げた `! grep -q` 3行。行番号は変わりうるためテスト名で指す）
  - `plugins/statusline/tests/statusline-multi-account.bats:215,216,303`（`! [[ ]]` 形）
  - パイプライン形（`! echo "$x" | grep -Eq '...'` など、対象166行に含まれる例を1件）
  - `for` ループ内の形（`plugins/dev-workflow/tests/tripwire-hook.bats:76-78`、`tests/always-on-injection-scope.bats:134` 付近）
  各例について確認結果（対象ファイル・確認コマンド・ok/not ok の切り替わり）を PR 本文に記録する
- [ ] 4.3 `bash scripts/test.sh` を実行し、全件 green（exit 0）であることを確認する。ガードを付けた結果として落ちるテストが出たら、この PR 内で実装側の欠陥を直し green にする（別 issue への先送りはしない。理由は proposal.md「Impact」）

## 5. 事務手続き

- [ ] 5.1 触ったプラグイン（`dev-workflow` / `statusline` / `casting` / `daily-report` / `infra` / `weekly-report` / `worktree`）の `plugin.json` の patch バージョンを上げる
- [ ] 5.2 `.claude-plugin/marketplace.json` を同期する
- [ ] 5.3 `plugins/dev-workflow/CHANGELOG.md`（および該当する他プラグインの CHANGELOG があれば）に本変更を追記する
