## ADDED Requirements

### Requirement: 3 プラグインのディレクトリは git 追跡の削除として取り除く
`plugins/skill-pack/`・`plugins/telegram/`・`plugins/experience-to-skill/` はリポジトリに存在してはならない（MUST NOT）。削除は git の履歴に残る追跡削除として行い、`git log` から復元できなければならない（MUST）。

#### Scenario: ディレクトリが無い
- **WHEN** `git ls-files plugins/skill-pack plugins/telegram plugins/experience-to-skill | wc -l` を実行する
- **THEN** 出力は `0` である
- **AND** 3 つのディレクトリはファイルシステム上にも存在しない

### Requirement: marketplace.json から 3 プラグインのエントリを外す
`.claude-plugin/marketplace.json` の `plugins[]` は `name` が `skill-pack`・`telegram`・`experience-to-skill` のエントリを持ってはならない（MUST NOT）。`bundles[]` のどの `plugins[]` にもこの 3 つを含めてはならない（MUST NOT）。他のプラグインのエントリ（`description` を含む）は変えてはならない（MUST NOT）。`bundles` の `all` に入っていないプラグインがある件（#708）は、この要件の対象外とする。

#### Scenario: plugins[] に 3 つが無い
- **WHEN** `jq -e '[.plugins[].name] | (index("skill-pack") == null) and (index("telegram") == null) and (index("experience-to-skill") == null)' .claude-plugin/marketplace.json` を実行する
- **THEN** exit 0 で終わる

#### Scenario: どのバンドルにも 3 つが無い
- **WHEN** `jq -e '[.bundles[]?.plugins[]?] | (index("skill-pack") == null) and (index("telegram") == null) and (index("experience-to-skill") == null)' .claude-plugin/marketplace.json` を実行する
- **THEN** exit 0 で終わる

#### Scenario: 整合テストが通る
- **WHEN** `bats tests/marketplace-sync.bats` を実行する
- **THEN** 全件 pass する

### Requirement: 3 プラグインへの参照を掃除する
`plugins/skill-pack`・`plugins/telegram`・`plugins/experience-to-skill`・`skill-pack@oratta-claude-harness`・`telegram@oratta-claude-harness`・`experience-to-skill@oratta-claude-harness`・`experience-to-skill-jsonl-distillation` の 7 文字列は、次の許容場所を除く git 追跡ファイルに現れてはならない（MUST NOT）。許容場所は (a) 過去の記録である `openspec/changes/archive/` と `_longruns/`、(b) 作業中の change ディレクトリ `openspec/changes/retire-skill-pack-telegram-e2s/`、(c) 解散の記録と切り替え手順を書くルート `README.md`、(d) この解散を検査する bats 自身、(e) archive で生成されるこの解散の capability の正本 `openspec/specs/skill-pack-telegram-e2s-retirement/`、とする。許容場所はパスの列挙で書き、文字列の一致で許容してはならない（MUST NOT）。

#### Scenario: 許容場所の外に参照が無い
- **WHEN** 7 文字列を `git grep` で探し、許容場所 (a)〜(e) の一致を除く
- **THEN** 一致は 0 件である

### Requirement: 解散の記録と切り替え手順をルート README に書く
ルート `README.md` のプラグイン一覧は `skill-pack`・`telegram`・`experience-to-skill` の行を持ってはならない（MUST NOT）。「解散済みプラグイン」の節には、3 プラグインを解散したことと、それぞれの理由および代替、install 済みの環境での手順として `claude plugin uninstall <name>@oratta-claude-harness`（3 つ分）を書かなければならない（MUST）。代替は、skill-pack が Claude Code 本体の `/skills` 画面・`skillOverrides`・`claude plugin enable|disable --scope`、telegram が公式 `telegram@claude-plugins-official`、experience-to-skill が公式の skill-creator スキルである。telegram は「利用者のリアクションをセッションへ届ける機能は不要と判断した」ことも書かなければならない（MUST）。

#### Scenario: プラグイン一覧に 3 つの行が無い
- **WHEN** ルート `README.md` のプラグイン一覧の表を読む
- **THEN** 1 列目が `skill-pack`・`telegram`・`experience-to-skill` の行は無い

#### Scenario: 切り替え手順と代替が書かれている
- **WHEN** ルート `README.md` を読む
- **THEN** `claude plugin uninstall skill-pack@oratta-claude-harness`・`claude plugin uninstall telegram@oratta-claude-harness`・`claude plugin uninstall experience-to-skill@oratta-claude-harness`・`telegram@claude-plugins-official`・`skillOverrides`・`skill-creator` の 6 文字列がすべて含まれる

### Requirement: 廃止した capability の spec を正本の置き場から消す
`openspec/specs/experience-to-skill-jsonl-distillation/` は存在してはならない（MUST NOT）。この capability は experience-to-skill プラグインの振る舞いだけを規定していた。残る spec は正本の形式を保たなければならない（MUST）。

#### Scenario: spec ディレクトリが無い
- **WHEN** `ls -d openspec/specs/experience-to-skill-jsonl-distillation` を実行する
- **THEN** 存在しない

#### Scenario: 残る spec は正本の形式を保つ
- **WHEN** `bats tests/openspec-specs-format.bats` を実行する
- **THEN** 全件 pass する
