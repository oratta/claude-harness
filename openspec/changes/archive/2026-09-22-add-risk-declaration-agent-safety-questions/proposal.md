## Why

pr-review-gate のリスク宣言は、いまプロダクトのユーザーへの影響・データ喪失・課金/法務・外部公開面の変化の 4 観点しか問わない。flatmate の自走型運用（genetta-inc/flatmate#837）では聖域 PR（行動ルールの変更）をロボットがマージするので、資格情報に触れる変更・安全ゲートを弱める変更・エージェントの権限を広げる変更が、この 4 観点のどれにも当たらずに「リスクなし」で main に入る。これをオーナーの判断待ちに止める問いが要る（oratta/claude-harness#373）。

## What Changes

- リスク宣言の判定条件に 3 観点を足し、7 観点にする
  - 資格情報: ID・パスワード・API の鍵・トークンの取得・保管・利用に触れるか
  - 安全ゲートの弱体化: レビュー必須・投稿前チェック（hook 等）・auto-merge の判定条件・permission の deny など、止め具を外す・緩める変更を含むか
  - エージェント権限の拡張: 新しい権限・新しい外部サービス・新しい書き込み先など、エージェントにできることを増やすか
- 「リスクなし」の定型文を、7 観点すべてが「無い」ことを言う文に書き換える（行頭の `リスクなし — ` は維持）
- 新 3 観点のどれかに当たれば、既存の「主のリスク許容が必要」と同じ経路（手順 6、`needs-approval` を付けて主の許容待ち）に流すことを手順書上で明記する
- 「主のリスク許容が必要」の雛形に、当たった観点を書く行を足す
- コメントの 1 行目・2 行目の規約（`## リスク宣言` 見出しと `対象 HEAD: <40 桁>`）は変えない
- dev-workflow の plugin.json と marketplace.json の該当プラグイン行を 2.13.23 に上げる（並行 PR #378 が 2.13.22 を使用中のため事前割当）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: リスク宣言の判定観点を 7 つに定め、新 3 観点のどれかに当たる PR を主のリスク許容待ちにする要件を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 手順 3（リスク分類表・「リスクなし」定型文・許容が必要な場合の雛形）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（新観点と定型文・1 行目規約の維持を確かめるテストを足す）
- `plugins/dev-workflow/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` のバージョン、`plugins/dev-workflow/CHANGELOG.md`
- auto-merge テンプレート（`plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml`）は `対象 HEAD:` 行とラベルだけを照合し、宣言本文の語句を見ていないので変更しない
- harness のように行動ルールそのものが製品のリポでは、新観点に当たる PR が増え、主への確認が増える
