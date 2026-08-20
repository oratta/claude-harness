# Tasks: fmtoken-explicit-name-and-register

## 1. fmtoken.sh の経路追加

- [x] 1.1 `--name <item>` の明示名参照を追加する（プロジェクト導出スキップ・origin remote 不要・`--check` 併用可・未登録は exit 44 で `--register` 経路を案内）
- [x] 1.2 `--register <item>` を追加する（値は stdin・rw SA の解決順 env → 600 ファイル → Keychain・ro トークン非流用・命名規約検証 exit 46・上書き拒否 exit 47）
- [x] 1.3 命名規約の機械検証 `validate_item_name` を追加する（`<prefix>--<service>`、prefix 小文字、`--` はちょうど 1 回）

## 2. ドキュメント同期

- [x] 2.1 `1password.md` の「アイテム登録」節を CLI 代行正規手順（ro/rw 役割分担）に改訂し、「人間セッション代行のみ」の記述を撤去する
- [x] 2.2 `SKILL.md` の原則 2・索引表 1Password 行・資格情報の階層表を同期する
- [x] 2.3 openspec 正本 `capability-registry-fmtoken/spec.md` に要件を反映する

## 3. テストとバージョン

- [x] 3.1 `tests/fmtoken.bats` の op スタブに `item create` を追加し、両命名規約の参照・登録・エラー経路（43/44/46/47）のテストを追加する（全 30 件パスを確認）
- [x] 3.2 plugin.json / SKILL.md frontmatter を 1.7.0 に、marketplace.json のエントリと top-level version を bump する
