## ADDED Requirements

### Requirement: marketplace.json と plugins/ の整合ガードはリポジトリ直下のテストが持つ
`plugins/` 配下と `.claude-plugin/marketplace.json` の整合を検査するテストは、特定プラグインの tests/ ではなくリポジトリ直下の `tests/marketplace-sync.bats` に置かなければならない（MUST）。テストは `bats` と `jq`・`git`・`find` だけで書き、他プラグインのテストヘルパに依存してはならない（MUST NOT）。旧 `plugins/loops/tests/integration.bats` に同居していた S130 / S130b / S131 / S132 / S133 / S139 を引き継ぐ。

#### Scenario: ルートのテストとして実在し scripts/test.sh に拾われる
- **WHEN** `bash scripts/test.sh tests` を実行する
- **THEN** `tests/marketplace-sync.bats` が対象に含まれ、全件 pass する

### Requirement: 全エントリの version が plugin.json と一致し、全ディレクトリが登録されている
`.claude-plugin/marketplace.json` の `plugins[]` の各エントリについて `version` が `plugins/<name>/.claude-plugin/plugin.json` の `version` と一致しなければならない（MUST）。逆方向に、`plugins/` 直下の全ディレクトリ名が `plugins[].name` に登録されていなければならない（MUST。プラグインを削除するとき plugin.json だけ消して他のファイルを残す事故を検出する）。

#### Scenario: version 不一致を検出する
- **WHEN** あるエントリの `version` と対応する plugin.json の `version` が異なる
- **THEN** テストは不一致のプラグイン名と両方の値を出力して fail する

#### Scenario: 未登録ディレクトリを検出する
- **WHEN** `plugins/` 直下に marketplace 未登録のディレクトリがある（または登録済みなのにディレクトリが無い）
- **THEN** テストは差分を出力して fail する

### Requirement: 変更したプラグインは merge-base より version が上がっている
`origin/main` との merge-base から HEAD までに `plugins/<name>/` 配下のファイルが変更されたプラグインは、`plugin.json` の `version` が merge-base 時点より大きくなければならない（MUST）。merge-base 時点に存在しなかった新規プラグイン、および HEAD で plugin.json が存在しない（削除された）プラグインは対象外とする。`origin/main` が無い環境では skip する。

#### Scenario: 変更したのに bump していない
- **WHEN** merge-base 以降にファイルを変更したプラグインの version が merge-base 時点と同じ
- **THEN** テストはプラグイン名と現在の version を出力して fail する

#### Scenario: 削除したプラグインを bump 忘れと誤検出しない
- **WHEN** merge-base 以降に `plugins/<name>/` を丸ごと削除した
- **THEN** テストはそのプラグインを対象外として pass する（marketplace 側の齟齬は前の要件が検出する）

### Requirement: トップレベル version を持たず、全 JSON がパースでき、無関係な PR が衝突しない
`.claude-plugin/marketplace.json` はトップレベルの `version` フィールドを持ってはならない（MUST NOT。issue #140 で廃止済み。再導入を防ぐ）。`marketplace.json` と全 `plugins/*/.claude-plugin/plugin.json` は `jq empty` を通らなければならない（MUST）。互いに無関係なプラグインのエントリだけを変更する 2 本のブランチは、片方をマージした後もう片方がクリーンにマージできなければならない（MUST）。

#### Scenario: トップレベル version の再導入を検出する
- **WHEN** marketplace.json に `version` キーが追加される
- **THEN** テストは issue #140 を示して fail する

#### Scenario: 別エントリを bump した 2 ブランチがクリーンにマージできる
- **WHEN** 実リポの marketplace.json を scratch リポに置き、先頭と末尾のエントリをそれぞれ別ブランチで bump し、片方をマージした後もう片方をマージする
- **THEN** 衝突せず、両エントリの bump が残り、JSON としてパースできる
