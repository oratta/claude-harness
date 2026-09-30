## ADDED Requirements

### Requirement: Discord 改造版プラグインのディレクトリは git 追跡の削除として取り除く
`plugins/discord/` はリポジトリに存在してはならない（MUST NOT）。削除は git の履歴に残る追跡削除として行い、`git log` から復元できなければならない（MUST）。

#### Scenario: ディレクトリが無い
- **WHEN** `git ls-files plugins/discord | wc -l` を実行する
- **THEN** 出力は `0` である
- **AND** `plugins/discord` はファイルシステム上にも存在しない

### Requirement: marketplace.json から discord のエントリを外す
`.claude-plugin/marketplace.json` の `plugins[]` は `name` が `discord` のエントリを持ってはならない（MUST NOT）。`bundles[]` のどの `plugins[]` にも `discord` を含めてはならない（MUST NOT）。他のプラグインのエントリ（`version`・`description` を含む）は変えてはならない（MUST NOT）。

#### Scenario: plugins[] に discord が無い
- **WHEN** `jq -e '[.plugins[].name] | index("discord") == null' .claude-plugin/marketplace.json` を実行する
- **THEN** exit 0 で終わる

#### Scenario: どのバンドルにも discord が無い
- **WHEN** `jq -e '[.bundles[]?.plugins[]?] | index("discord") == null' .claude-plugin/marketplace.json` を実行する
- **THEN** exit 0 で終わる

#### Scenario: 整合テストが通る
- **WHEN** `bats tests/marketplace-sync.bats` を実行する
- **THEN** 全件 pass する（削除したプラグインは version bump 検査の対象外）

### Requirement: CI は Discord のテストのための bun を導入しない
`.github/workflows/ci.yml` は bun を導入するステップ（`oven-sh/setup-bun`）を持ってはならない（MUST NOT）。bun を使うテストは Discord の動的ハーネスだけだったため、節ごと取り除く。サードパーティ製 action をコミット SHA で固定する方針のコメント（issue #138）は、今後の追加に備えて残さなければならない（MUST）。ただし例示に撤去済みの action 名を使ってはならない（MUST NOT）。

#### Scenario: ci.yml に discord と setup-bun の記述が無い
- **WHEN** `grep -n -i -e discord -e setup-bun .github/workflows/ci.yml` を実行する
- **THEN** 一致は 0 件である

#### Scenario: SHA 固定の方針コメントは残る
- **WHEN** `.github/workflows/ci.yml` を読む
- **THEN** サードパーティ製 action はコミット SHA で固定する旨と issue #138 への言及が残っている

### Requirement: 廃止した capability の spec を正本の置き場から消す
`openspec/specs/discord-reaction-delivery/` は存在してはならない（MUST NOT）。この capability は Discord 改造版プラグインの振る舞いだけを規定しており、正本は flatmate 側に移る（genetta-inc/flatmate#861）。残る spec は正本の形式を保たなければならない（MUST）。

#### Scenario: spec ディレクトリが無い
- **WHEN** `ls -d openspec/specs/discord-reaction-delivery` を実行する
- **THEN** 存在しない

#### Scenario: 残る spec は正本の形式を保つ
- **WHEN** `bats tests/openspec-specs-format.bats` を実行する
- **THEN** 全件 pass する

### Requirement: Discord 改造版への参照を掃除する
`plugins/discord`・`discord@oratta-claude-harness`・`discord-reaction-delivery` の 3 文字列は、次の許容場所を除く git 追跡ファイルに現れてはならない（MUST NOT）。許容場所は (a) 過去の記録である `openspec/changes/archive/` と `_longruns/`、(b) 作業中の change ディレクトリ `openspec/changes/remove-discord-plugin/`、(c) 移設の記録と切り替え手順を書くルート `README.md`、(d) この撤去を検査する bats 自身、(e) archive で生成されるこの撤去の capability の正本 `openspec/specs/discord-plugin-retirement/`、とする。ユーザーへの連絡手段としての一般名詞「Discord」（dev-workflow・casting・telegram の文中）は対象外で、書き換えてはならない（MUST NOT）。

#### Scenario: 許容場所の外に参照が無い
- **WHEN** 3 文字列を `git grep` で探し、許容場所 (a)〜(e) の一致を除く
- **THEN** 一致は 0 件である

### Requirement: 移設の記録と切り替え手順をルート README に書く
ルート `README.md` のプラグイン一覧は `discord` の行を持ってはならない（MUST NOT）。「解散済みプラグイン」の節には、Discord 改造版が flatmate に移ったこと（genetta-inc/flatmate#851 へのリンク）と、install 済みの環境での切り替え手順として (1) `claude plugin uninstall discord@oratta-claude-harness` の実行、(2) `enabledPlugins` の `discord@oratta-claude-harness` を `discord@flatmate` に置き換えること、(3) 住人の `CHANNEL_PLUGINS` を `plugin:discord@flatmate` にすること、を書かなければならない（MUST）。flatmate 側の marketplace 登録手順は flatmate が正本なので、README に写さずリンクで誘導する（MUST）。

#### Scenario: プラグイン一覧に discord の行が無い
- **WHEN** ルート `README.md` のプラグイン一覧の表を読む
- **THEN** 1 列目がプラグイン名 discord の行は無い

#### Scenario: 切り替え手順が書かれている
- **WHEN** ルート `README.md` を読む
- **THEN** `genetta-inc/flatmate/issues/851`・`claude plugin uninstall discord@oratta-claude-harness`・`discord@flatmate`・`plugin:discord@flatmate` の 4 文字列がすべて含まれる
