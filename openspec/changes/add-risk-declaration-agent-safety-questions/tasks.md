## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、手順 3 の範囲（`### 3. リスク宣言` から `#### 3-b.` の前まで）について次を確かめるテストを足す: 「リスクなし — 」行に 7 観点（既存 4 ＋ 資格情報・安全ゲートの弱体化・エージェント権限の拡張）がすべて現れる／新 3 観点の定義（取得・保管・利用、厳しくする変更は当たらない、新しい権限・外部サービス・書き込み先）がある／新観点に当たると手順 6・`needs-approval` に流れる記述がある／許容雛形に `該当する観点:` 行がある／2 つの雛形の 1 行目 `## リスク宣言`・2 行目 `対象 HEAD:` が維持されている
- [ ] 1.2 追加テストが落ちることを確認する

## 2. SKILL.md 手順 3 を直す（Green）

- [ ] 2.1 リスク分類表の「リスクなし」「主のリスク許容が必要」の条件列を 7 観点にし、表の下に新 3 観点の線引きを書く（新観点も手順 6 で `needs-approval` を付けることを明記）
- [ ] 2.2 「リスクなし」の定型文を 7 観点を述べる文にする（行頭 `リスクなし — ` と 1〜2 行目は維持）
- [ ] 2.3 許容が必要な場合の雛形に `- 該当する観点: <7 観点のうち当たったもの>` を足す
- [ ] 2.4 `plugins/dev-workflow/README.md` などに 4 観点を列挙した記述が残っていないか grep し、あれば揃える

## 3. バージョンと記録

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow 行を 2.13.23 にする
- [ ] 3.2 `plugins/dev-workflow/CHANGELOG.md` に 2.13.23 の項を足す

## 4. 検証

- [ ] 4.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` と `scripts/test.sh` 全件を実行し exit 0 を確認する
- [ ] 4.2 `openspec validate add-risk-declaration-agent-safety-questions --strict` が通ることを確認する
