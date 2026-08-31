## ADDED Requirements

### Requirement: 解散する 3 プラグインのディレクトリは git 追跡の削除として取り除く
`plugins/loops/`・`plugins/longrun/`・`plugins/lr/` はリポジトリから削除されていなければならない（MUST）。削除は git 履歴に残る tracked removal であり（`git log --diff-filter=D` で追える）、untracked や ignore による見えない状態にしてはならない（MUST NOT）。

#### Scenario: 3 ディレクトリが存在しない
- **WHEN** `plugins/` を一覧する
- **THEN** `plugins/loops/`・`plugins/longrun/`・`plugins/lr/` のいずれも存在しない

#### Scenario: 削除が git 履歴に残っている
- **WHEN** `git log --diff-filter=D --oneline -- plugins/loops plugins/longrun plugins/lr` を実行する
- **THEN** 3 ディレクトリ配下のファイル削除がコミットとして現れる

### Requirement: marketplace.json から 3 プラグインを外す
`.claude-plugin/marketplace.json` の `plugins[]` に `name` が `loops`・`longrun`・`lr` のエントリが存在してはならず（MUST NOT）、`bundles[]` の `all` の `plugins[]` にも 3 名が含まれてはならない（MUST NOT）。残るエントリの `version` と `description` は本 change で意図して更新したもの（dev-workflow と参照を直したプラグイン）以外は変えない。

#### Scenario: plugins[] と bundle から 3 名が消えている
- **WHEN** `.claude-plugin/marketplace.json` をパースする
- **THEN** `plugins[].name` にも `bundles[] | select(.name=="all") | .plugins[]` にも `loops`・`longrun`・`lr` が現れない

#### Scenario: plugins/ 配下と marketplace の登録が一致する
- **WHEN** `plugins/` 直下のディレクトリ名一覧と `plugins[].name` の一覧を比較する
- **THEN** 両者は完全一致する（片側だけにある名前が無い）

### Requirement: 解散プラグインへの参照を掃除する
`plugins/`・`rules/`・`docs/`・`README.md`・`.claude-plugin/`・`scripts/` 配下のファイルは、`loops:`（スラッシュコマンド・スキル参照）・`/lr:`・`longrun`・`plugins/loops/`・`plugins/longrun/` の文字列を含んではならない（MUST NOT）。例外は次の 4 種に限る: (a) `plugins/dev-workflow/CHANGELOG.md` の解散記録と新旧パス対応表、(b) `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md` の「旧 longrun の Build Contract レビューを置き直した」という由来説明、(c) `plugins/product-handover/CHANGELOG.md` の「loops の解散は #205」という説明文、(d) ルートの過去実行アーカイブ `_longruns/` を指すパス・除外指定（`scripts/test.sh`・`scripts/lint.sh`・`tests/shell-multibyte-expansion.bats`・`plugins/product-handover/tests/plugin-structure.bats`・`plugins/worktree/tests/helper.bash`）。

#### Scenario: 許容リスト外のヒットが 0 件
- **WHEN** リポジトリルートで `grep -rn "loops:\|/lr:\|longrun" plugins rules docs README.md .claude-plugin scripts` を実行し、上の 4 種の例外行を除く
- **THEN** 残るヒットは 0 件である

#### Scenario: 旧 reference パスの参照が残っていない
- **WHEN** `grep -rn "loops/references/\|longrun/references/" plugins rules docs README.md` を実行する
- **THEN** ヒットは 0 件である（自己検証・PR 本文の型・モデルティアの参照はすべて `plugins/dev-workflow/references/` を指す）

### Requirement: 解散した capability の spec を正本の置き場から消す
`openspec/specs/` 配下の `loops-*`・`longrun-*`・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires` の各ディレクトリは存在してはならない（MUST NOT）。これらは解散プラグインの振る舞いだけを規定していた spec であり、存在しない機能の仕様を「現行仕様の正本」に残さない。過去の一回性作業を記録した spec（`marketplace-final-sync`・`retirement-handoff-docs`・`llm-log-relocation`・`repo-root-cleanup`・`plugin-retirement-cleanup`）は歴史記述として残す。

#### Scenario: 解散 capability の spec ディレクトリが無い
- **WHEN** `ls -d openspec/specs/loops-* openspec/specs/longrun-* openspec/specs/workflow-exec openspec/specs/workflow-tool-reference openspec/specs/workflow-run-control openspec/specs/legacy-command-removal openspec/specs/loop-dev-agent-tripwires` を実行する
- **THEN** いずれも存在しない

#### Scenario: 残る spec は正本の形式を保つ
- **WHEN** `tests/openspec-specs-format.bats` を実行する
- **THEN** 全件 pass する（delta 見出しの残留・Purpose/Requirements 欠落・不正な題名が 0 件）

### Requirement: アンインストール手順と契約の移設先を CHANGELOG に書く
`plugins/dev-workflow/CHANGELOG.md` は、dev-workflow 2.1.0 の項に (1) `/plugin uninstall loops@oratta-claude-harness`・`/plugin uninstall longrun@oratta-claude-harness`・`/plugin uninstall lr@oratta-claude-harness` と `/reload-plugins` の実行、(2) 各プロジェクトの `settings.local.json` の `enabledPlugins` から 3 名のキーを外すこと、(3) 契約の新旧パス対応表（self-verification / pr-body-format / model-tiers / issueify と、廃止した review-queue・feature-list-format・`/lr:e`・`/lr:p` の後継）、(4) flatmate 側で追従が必要な箇所（`docs/agent-loop.md` の正本宣言後の自立・`docs/burn-mode.md` の review-queue 参照・issue テンプレの参照パス）と対応 issue へのリンク、を含まなければならない（MUST）。

#### Scenario: uninstall 3 行と reload が書かれている
- **WHEN** `plugins/dev-workflow/CHANGELOG.md` を読む
- **THEN** `/plugin uninstall loops@oratta-claude-harness`・`/plugin uninstall longrun@oratta-claude-harness`・`/plugin uninstall lr@oratta-claude-harness`・`/reload-plugins` の 4 文字列がすべて含まれる

#### Scenario: 新旧パス対応表がある
- **WHEN** CHANGELOG の 2.1.0 の項を読む
- **THEN** `plugins/dev-workflow/references/self-verification.md`・`pr-body-format.md`・`model-tiers.md`・`skills/issueify/SKILL.md` の新パスと、review-queue・feature-list-format・`/lr:e`・`/lr:p` それぞれの後継（または廃止理由）が表で示されている

### Requirement: 憲法の正本は flatmate 側と宣言する
harness は loop-dev-agent の憲法テンプレートを配布せず、各リポに配備済みの `docs/agent-loop.md`（flatmate が保守）を正本とする旨を `plugins/dev-workflow/README.md` と `templates/escalation-tripwires.md` の導入手順に書かなければならない（MUST）。harness 側からの再生成や逆同期の手順を持ってはならない（MUST NOT）。

#### Scenario: README が憲法の正本を flatmate 側と述べている
- **WHEN** `plugins/dev-workflow/README.md` の loop-dev-agent との関係の節を読む
- **THEN** 憲法（`docs/agent-loop.md`）は各リポ側（flatmate の保守）が正本で、harness にテンプレートは無いことが書かれている

#### Scenario: ルート README に解散の記録がある
- **WHEN** ルート `README.md` を読む
- **THEN** loops / longrun / lr のインストール手順・コマンド表は無く、「解散済み」の短い記録と `plugins/dev-workflow/CHANGELOG.md` への誘導だけがある

### Requirement: 参照を直したプラグインの version を上げる
本 change でファイルを変更したプラグイン（dev-workflow、および自己検証の参照パス等を直した casting・experience-to-skill・skill-pack・infra・weekly-report・daily-report・worktree）の `plugin.json` の `version` は変更前より大きくし、`.claude-plugin/marketplace.json` の対応エントリと一致させなければならない（MUST）。dev-workflow は 2.0.0 から 2.1.0 に上げる（新スキル issueify と references の追加は後方互換の機能追加）。

#### Scenario: dev-workflow が 2.1.0 で marketplace と一致する
- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` と marketplace.json の dev-workflow エントリを読む
- **THEN** 両者とも `2.1.0` である

#### Scenario: 全プラグインの version が marketplace と一致する
- **WHEN** `plugins/*/.claude-plugin/plugin.json` の version と marketplace.json の各エントリを機械照合する
- **THEN** 不一致が 0 件である
