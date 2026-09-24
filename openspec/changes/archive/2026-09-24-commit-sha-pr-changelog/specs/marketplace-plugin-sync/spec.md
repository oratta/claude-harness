## ADDED Requirements

### Requirement: plugin.json と plugins[] は version を持たず、全ディレクトリが登録されている

全 `plugins/*/.claude-plugin/plugin.json` は `version` フィールドを持ってはならない（MUST NOT）。`.claude-plugin/marketplace.json` の `plugins[]` のどのエントリも `version` フィールドを持ってはならない（MUST NOT）。どちらか片方でも残るとその値が版として固定され、上げない限り利用者に更新が届かなくなるため、両方を検査する。検査は `origin/main` を要さず、CI（`actions/checkout` の既定の浅い clone）でも常に走らなければならない（MUST。版を上げる古い PR が後からマージされて `version` が復活するのを CI で落とすため）。逆方向に、`plugins/` 直下の全ディレクトリ名が `plugins[].name` に登録されていなければならない（MUST。プラグインを削除するとき plugin.json だけ消して他のファイルを残す事故を検出する）。

守備範囲: この検査が見る入力の出どころは、全 `plugins/*/.claude-plugin/plugin.json` のトップレベルと `marketplace.json` の `plugins[]` 各エントリのトップレベルで、想定する経路は、版を上げていた古い PR が後からマージされて `version` が戻ることである。拾う誤りは `version` キーの存在で、値が何であるか（semver か、空文字か）は問わない。通すことを許す入力は、SKILL.md の frontmatter の `version`、`plugins/telegram/package.json` の `version`、`catalog_version` のような別のキー、manifest のトップレベル以外に現れる `version` という文字列で、これらは Claude Code の版の決定に使われないので検査しない。manifest 以外の経路（たとえば別の設定ファイルから版を固定する仕組みが将来足された場合）の穴は別途判断し、ここで塞ぎ切ることをこの要件の完了条件にしない。

#### Scenario: plugin.json に version が再導入されたのを検出する

- **WHEN** いずれかの `plugins/<name>/.claude-plugin/plugin.json` に `version` キーがある
- **THEN** テストはプラグイン名とその値を出力して fail する

#### Scenario: marketplace.json のエントリに version が再導入されたのを検出する

- **WHEN** `marketplace.json` の `plugins[]` のいずれかのエントリに `version` キーがある
- **THEN** テストはエントリ名とその値を出力して fail する

#### Scenario: origin/main の無い浅い clone でも走る

- **WHEN** `origin/main` の ref が無い環境で `bats tests/marketplace-sync.bats` を実行する
- **THEN** version の不在の検査は skip されずに走る

#### Scenario: 未登録ディレクトリを検出する

- **WHEN** `plugins/` 直下に marketplace 未登録のディレクトリがある（または登録済みなのにディレクトリが無い）
- **THEN** テストは差分を出力して fail する

## MODIFIED Requirements

### Requirement: marketplace.json と plugins/ の整合ガードはリポジトリ直下のテストが持つ
`plugins/` 配下と `.claude-plugin/marketplace.json` の整合を検査するテストは、特定プラグインの tests/ ではなくリポジトリ直下の `tests/marketplace-sync.bats` に置かなければならない（MUST）。テストは `bats` と `jq`・`git`・`find` だけで書き、他プラグインのテストヘルパに依存してはならない（MUST NOT）。旧 `plugins/loops/tests/integration.bats` に同居していた S130 / S130b / S131 / S132 / S133 / S139 を引き継ぐ。S130 と S131 は issue #447 で「version を持たない」検査に置き換えた。

#### Scenario: ルートのテストとして実在し scripts/test.sh に拾われる
- **WHEN** `bash scripts/test.sh tests` を実行する
- **THEN** `tests/marketplace-sync.bats` が対象に含まれ、全件 pass する

### Requirement: トップレベル version を持たず、全 JSON がパースでき、無関係な PR が衝突しない
`.claude-plugin/marketplace.json` はトップレベルの `version` フィールドを持ってはならない（MUST NOT。issue #140 で廃止済み。再導入を防ぐ）。`marketplace.json` と全 `plugins/*/.claude-plugin/plugin.json` は `jq empty` を通らなければならない（MUST）。互いに無関係なプラグインのエントリだけを変更する 2 本のブランチは、片方をマージした後もう片方がクリーンにマージできなければならない（MUST）。

#### Scenario: トップレベル version の再導入を検出する
- **WHEN** marketplace.json に `version` キーが追加される
- **THEN** テストは issue #140 を示して fail する

#### Scenario: 別エントリを書き換えた 2 ブランチがクリーンにマージできる
- **WHEN** 実リポの marketplace.json を scratch リポに置き、先頭と末尾のエントリの `description` をそれぞれ別ブランチで書き換え、片方をマージした後もう片方をマージする
- **THEN** 衝突せず、両エントリの書き換えが残り、JSON としてパースできる

## REMOVED Requirements

### Requirement: 全エントリの version が plugin.json と一致し、全ディレクトリが登録されている
**Reason**: issue #447 で plugin.json と marketplace.json の両方から `version` を撤去し、一致させる値が無くなった
**Migration**: 「plugin.json と plugins[] は version を持たず、全ディレクトリが登録されている」に置き換える。ディレクトリ登録の検査（S130b）はそちらに引き継ぐ

### Requirement: 変更したプラグインは merge-base より version が上がっている
**Reason**: 版を人が上げる運用をやめ、Claude Code が commit SHA から版を決める方式に移った（issue #447）。並行 PR が同じ版の行を書き換えて衝突し続けたのが理由
**Migration**: 版は上げない。変更の記録は `plugins/<name>/changes/<番号>.md` に書く（capability `plugin-release-convention`）
