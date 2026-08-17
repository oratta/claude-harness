## 1. テスト先行（Red）

- [ ] 1.1 `plugins/casting/tests/casting-check.bats` を作成する。フィクスチャは `plugins/casting/tests/fixtures/` に置き、①正常（exit 0）②未知語彙③カタログ外判例④同一観点「論点じゃなかった」2件⑤catalog_version 不一致 の5ケースを検証する（Red 確認）
- [ ] 1.2 `plugins/casting/tests/casting-init.bats` を作成する。一時 git repo で①初回生成（project.md / precedents.md / .gitignore 追記）②再実行で非上書き・gitignore 非重複 を検証する（Red 確認）

## 2. カタログとプラグイン本体（Green）

- [ ] 2.1 `plugins/casting/catalog/catalog.md` を作成する。front matter `version: 1`、列定義・14観点（oratta/claude-harness#112 の表を転記）・横断軸2・変更手続き2ルート・変更記録節
- [ ] 2.2 `plugins/casting/templates/project.md`（catalog_version front matter＋カタログ既定の担い手をコピーした5列表）と `templates/precedents.md`（4フィールドの記入例つき）を作成する
- [ ] 2.3 `plugins/casting/scripts/casting-check.sh` を実装する（4検出項目。日本語照合は LC_ALL=C の grep -F、awk の文字列比較禁止）
- [ ] 2.4 `plugins/casting/commands/init.md` を作成する（雛形からの生成・既存非上書き・gitignore 冪等追記の手順）
- [ ] 2.5 `plugins/casting/skills/casting/SKILL.md` を作成する（3層の置き場と上書き順・セッション宣言形式・配役表の作り方・判例の書き方・変更手続き）
- [ ] 2.6 `plugins/casting/.claude-plugin/plugin.json` と `plugins/casting/README.md` を作成する
- [ ] 2.7 bats を実行して Green を確認する（exit code を表示）

## 3. 常時ロード層と登録

- [ ] 3.1 `rules/perspective-casting.md` を作成する（返信前チェック5手順＋正本ポインタ、30行以内）
- [ ] 3.2 `rules/README.md` の一覧に追記する
- [ ] 3.3 `.claude-plugin/marketplace.json` に casting プラグインを追加し、トップレベル version を上げる

## 4. 検証

- [ ] 4.1 `bats plugins/casting/tests/` を実行して全 green（exit code 表示）
- [ ] 4.2 `openspec validate casting-plugin` を通す
- [ ] 4.3 issue #112 の受け入れ条件を1件ずつ突き合わせて確認する
