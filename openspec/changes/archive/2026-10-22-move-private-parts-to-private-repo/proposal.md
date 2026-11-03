## Why

エピック #1127 の方針（公開版は今の `oratta/claude-harness` を使い続け、オーナーに固有の部品を private の個人版へ移す）に沿って、#1128 の仕分けの表で「個人版」に決めた部品が、まだ公開版のリポジトリに残っている。前半の change `confirm-epic-launch-split-rows` で保留の 5 行が公開版に確定し、移す範囲が決まった。主から個人版のリポジトリ `oratta/claude-harness-oratta`（private）の作成と最初の commit の main への直接 push の承認も得た（https://github.com/oratta/claude-harness/issues/1129#issuecomment-6333407804 ）ので、部品を写して公開版から消す。

## What Changes

- 個人版のリポジトリ `oratta/claude-harness-oratta` を作り、marketplace `claude-harness-oratta` として次を写す: プラグイン `weekly-report`・`daily-report`（同じ名前）、新しいプラグイン `capability-registry-oratta`（`fmtoken.sh`・`1password.md`・`tests/fmtoken.bats` と、capability-registry の SKILL.md の「表記規約」「資格情報の階層」の 2 節）、`rules/plugin-editing.md`、`plugins/dev-workflow/docs/auto-merge-deployments.md`、`openspec/specs/` の 4 本（`capability-registry-fmtoken`・`weekly-report-jsonl-direct`・`report-command-hygiene`・`report-noninteractive-mode`）。履歴は運ばず、最初の commit に写し元の公開版の commit SHA を書く
- 個人版に、公開版の作業ツリーに個人版の固有名が残っていないかを調べる `scripts/check-public-leak.sh` と、その辞書を置く（公開版の辞書には足さない）
- オーナーが各 PC で個人版へ切り替えた後に、公開版から上の部品を消す。**BREAKING**: 公開版の marketplace から `weekly-report`・`daily-report` が消え、bundle `all` からも外れる。公開版の `rules/` から `plugin-editing.md` が消える。capability-registry から `fmtoken.sh`・`1password.md` と SKILL.md の 2 節が消える
- 公開版に残る参照（README・CONTRIBUTING・CLAUDE.md・AGENTS.md・`docs/worktree-recovery.md`・dev-workflow の README・auto-merge テンプレの README・自己検証の対象スキル一覧）を、消した部品に依らない書き方か「個人版が入っていれば」の書き方に直す
- 仕分けの文書の表から移した部品の行を外し、新しい節「個人版に移した部品」に移した先と写し元の SHA を記録する。検査を、移した部品が公開版に無いことを確かめる形に直す
- 常時注入の量が減るので `tests/injection-budget.txt` を実測に合わせて下げる
- 公開版の消す PR は、オーナーが全 PC で切り替えを終えるまで Draft のままにする

## Capabilities

### New Capabilities

なし（個人版のリポジトリに置く仕組みは公開版の仕様に載せない。個人版に移る 4 本の仕様は個人版のリポジトリの `openspec/specs/` に置く）

### Modified Capabilities

- `harness-public-private-split`: 個人版に移した部品を移した記録に載せ、公開版に残さない要件を足す。dev-workflow 以外と dev-workflow の固有名の検索の対象から、個人版のファイルと節を除く決まりを外す（除く物が公開版に無くなるため）
- `always-on-injection-scope`: 常時注入に残す指示の列挙から `rules/plugin-editing.md` の項目を外す（公開版から消えるため）
- `plugin-release-convention`: 版上げの指示が無いことを確かめる対象から `rules/plugin-editing.md` を外す
- `dev-workflow-shared-references`: 自己検証の対象スキルを 6 から 4 に、参照元を 7 か所から 5 か所にする（`daily-report`・`weekly-report` が公開版から消えるため）
- `skill-verification-sections`: 「## 自己検証」節を持つ対象スキルを 6 から 4 にする

`capability-registry-fmtoken`・`weekly-report-jsonl-direct`・`report-command-hygiene`・`report-noninteractive-mode` の 4 本は、delta で消さず archive の直前に `git rm -r` で正本の置き場から外す（全要件の REMOVED は archive が止まるため。前例は `openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/tasks.md`）。

## Impact

- 公開版で消すもの: `plugins/weekly-report/`・`plugins/daily-report/`・`rules/plugin-editing.md`・`plugins/dev-workflow/docs/auto-merge-deployments.md`・`plugins/capability-registry/scripts/fmtoken.sh`・`plugins/capability-registry/skills/capability-registry/1password.md`・`plugins/capability-registry/tests/fmtoken.bats`・SKILL.md の 2 節・`openspec/specs/` の 4 本
- 公開版で直すもの: `.claude-plugin/marketplace.json`・`README.md`・`CONTRIBUTING.md`・`CLAUDE.md`・`AGENTS.md`（聖域。主の承認が要る）・`docs/worktree-recovery.md`・`docs/public-private-split.md`・`plugins/dev-workflow/README.md`・`plugins/dev-workflow/templates/auto-merge/README.md`・`plugins/dev-workflow/references/self-verification.md`・`tests/injection-budget.txt`（聖域）・関係する bats
- オーナーの環境: 各 PC で個人版の marketplace を足し、プラグインを入れ替え、`~/.claude/rules/plugin-editing.md` を個人版の clone に張り替える。週報の定期実行（LaunchAgent `com.oratta.weekly-report`）はコマンド名 `/weekly-report` で呼ぶので入れ替え後も動く
- 公開版を使う第三者: `weekly-report`・`daily-report` を入れていた場合は marketplace から消える（オーナーの業務専用の部品で、他の利用者は想定していない）
- 後続: #1130 が、各 PC で手で行う切り替えの手順を仕組みに置き換える
