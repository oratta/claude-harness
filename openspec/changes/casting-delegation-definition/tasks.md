## 1. テスト先行（Red）

- [ ] 1.1 `plugins/casting/tests/casting-delegation.bats` を新設: 定義正本（2 プリミティブ・正本の所在・ロール＝組み合わせ名・論点の定義）、雛形 delegation.md（catalog_version・`## 委任`・2 表見出し）、policy-interview コマンド（name・slug 解決・1 問ずつ・templates/policy.md・既存更新・配役表更新案内）、policy 雛形（前提とする外部規約・把握度 3 語）、rule（「許可ツール」・正本パス・30 行以内）、plugin.json の commands 登録、injection.md のポインタを assert し Red を確認する
- [ ] 1.2 `casting-init.bats` に delegation.md の初回生成（雛形と diff 一致）と再実行時の非上書きを足し Red を確認する
- [ ] 1.3 `casting-check.bats` に、許可ツール表を含む delegation.md を置いた fixture で malformed-row が報告されないことを足す

## 2. 実装（Green）

- [ ] 2.1 `plugins/casting/catalog/delegation.md` を書く（定義・宣言書式・置き場・正本の優先順・ロールの位置づけ・論点の定義）
- [ ] 2.2 `plugins/casting/templates/delegation.md` を書く（front matter・`## 委任`・許可ツール表・任された観点表・書き方説明。コードスパンにプラグイン内相対パスを書かない）
- [ ] 2.3 `plugins/casting/commands/policy-interview.md` を書く（slug 解決・1 問ずつ自由回答の質問順・生成/更新手順・例外規定・完了報告）
- [ ] 2.4 `plugins/casting/templates/policy.md` に「前提とする外部規約（全文未把握でよい）」節を足す
- [ ] 2.5 `plugins/casting/commands/init.md` の生成スクリプトに delegation.md の非上書きコピーを足す
- [ ] 2.6 `rules/perspective-casting.md` 手順③に許可ツールの確認を 1 文足し、正本に delegation.md を 1 行足す（30 行以内）
- [ ] 2.7 `plugins/casting/skills/casting/SKILL.md`・`catalog/injection.md`・`README.md`・`.claude-plugin/plugin.json`（0.4.0・commands 追加）・`.claude-plugin/marketplace.json` の説明を更新する

## 3. 整合・検証

- [ ] 3.1 `openspec validate casting-delegation-definition --strict` を通す
- [ ] 3.2 `bash scripts/lint.sh` と `bash scripts/test.sh` がともに exit 0（exit code を PR に添付）
