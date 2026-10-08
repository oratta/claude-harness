## MODIFIED Requirements

### Requirement: plugin.json と plugins[] は version を持たず、全ディレクトリが登録されている

全 `plugins/*/.claude-plugin/plugin.json` は `version` フィールドを持ってはならない（MUST NOT）。`.claude-plugin/marketplace.json` の `plugins[]` のどのエントリも `version` フィールドを持ってはならない（MUST NOT）。どちらか片方でも残るとその値が版として固定され、上げない限り利用者に更新が届かなくなるため、両方を検査する。検査は `origin/main` を要さず、CI（`actions/checkout` の既定の浅い clone）でも常に走らなければならない（MUST。版を上げる古い PR が後からマージされて `version` が復活するのを CI で落とすため）。逆方向に、`plugins/` 直下の全ディレクトリ名が `plugins[].name` に登録されていなければならない（MUST。プラグインを削除するとき plugin.json だけ消して他のファイルを残す事故を検出する）。

守備範囲: この検査が見る入力の出どころは、全 `plugins/*/.claude-plugin/plugin.json` のトップレベルと `marketplace.json` の `plugins[]` 各エントリのトップレベルで、想定する経路は、版を上げていた古い PR が後からマージされて `version` が戻ることである。拾う誤りは `version` キーの存在で、値が何であるか（semver か、空文字か）は問わない。通すことを許す入力は、SKILL.md の frontmatter の `version`、プラグイン直下の `package.json` の `version`、`catalog_version` のような別のキー、manifest のトップレベル以外に現れる `version` という文字列で、これらは Claude Code の版の決定に使われないので検査しない。manifest 以外の経路（たとえば別の設定ファイルから版を固定する仕組みが将来足された場合）の穴は別途判断し、ここで塞ぎ切ることをこの要件の完了条件にしない。

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
