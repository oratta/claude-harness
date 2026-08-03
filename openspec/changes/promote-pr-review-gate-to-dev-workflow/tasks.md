# Tasks: promote-pr-review-gate-to-dev-workflow

## 1. テスト先行（TDD Red）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` を作成する — スキルの存在・frontmatter・6 手順の見出し・#240 収束ルール（2 周キャップ / 真正性確認 / 差分限定 / blocking 限定 / 並行動作確認）の存在・flatmate 固有文字列（`genetta-inc/flatmate` 直書き、無条件の `pending-mirror.sh` 参照）の不在・plugin.json への登録と version bump を assert
- [ ] 1.2 `plugins/dev-workflow/tests/automerge-templates.bats` を作成する — テンプレート 4 ファイルの存在・マーカー対の存在・安全不変条件（素の pull_request 不在 / checkout 不在 / gh pr merge 不在 / sha ピン / fail-closed 分岐）・README の差し替え 3 点の記載・`genetta-inc/flatmate` 直書きの不在を assert
- [ ] 1.3 bats を実行して全件 Red（対象ファイル未作成による fail）を確認する

## 2. pr-review-gate スキルの移植

- [ ] 2.1 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` を作成する — flatmate 版の 6 手順・ラベル体系・fail-closed を維持しつつ、冒頭に理由集約（HEAD SHA / stale passed）で減量し、flatmate 固有参照を「存在すれば従う・無ければ縮退」の条件分岐に置換、auto-merge 未配備リポの縮退動作を明記
- [ ] 2.2 #240 収束ルールを織り込む — 手順 2 に 2 周キャップ・差分限定再レビュー・blocking 定義の限定、手順 5 に許容リンクの真正性確認（`gh api` での author 実測と確認記録の書式）、手順 6 に「承認待ちの間に手順 4 を並行」の一文

## 3. auto-merge テンプレートの配置

- [ ] 3.1 `plugins/dev-workflow/templates/auto-merge/auto-merge.yml` と `revert-pr.yml` を配置する — flatmate 実物からマーカー・安全不変条件を維持したまま、コメント内の flatmate 固有記述（issue 番号・リポ URL）をリポ非依存に調整
- [ ] 3.2 `test-auto-merge-workflow.sh` を配置する — ROOT を環境変数等で上書き可能にする最小改修を加え、展開先リポでそのまま CI に載せられる形にする
- [ ] 3.3 `README.md` を作成する — 差し替え必須 3 点（聖域パス / REQUIRED_CHECKS / AUTOMERGE_PAT）、展開手順、緊急停止（AUTOMERGE_PAUSED）と巻き戻し（revert-pr.yml）の運用、マージされないときの調べ方を `<owner>/<repo>` プレースホルダで記載

## 4. プラグイン登録と検証（Green）

- [ ] 4.1 `plugin.json` の skills 配列に `./skills/pr-review-gate` を追加し、version を 1.6.2 → 1.7.0 に bump、description に pr-review-gate の一文を追加
- [ ] 4.2 `plugins/dev-workflow/README.md` に pr-review-gate スキルと auto-merge テンプレートの節を追記
- [ ] 4.3 bats 全件 Green と shellcheck 通過を確認する（exit code を記録）
- [ ] 4.4 テンプレート同梱の test-auto-merge-workflow.sh を ROOT 上書きでテンプレート dir に対して実行し、判定ロジックの自己検証が pass することを確認する
