## 1. decision-criteria.md の改訂（v0 の中心）

- [x] 1.1 Step B の判定基準を「設計判断・トレードオフの有無」一次基準に改訂する（機械的振る舞い変更の spec 省略条件、テスト必須不変、unmanned の安全側維持を含む）
- [x] 1.2 実行戦略の判定表を追加する: 4象限モデルの説明、決定論的シグナルと収集コマンド例、シグナル×判断分布×残量モード → solo / delegate+verify / workflow 型 の対応表、モード不変ルール2本
- [x] 1.3 残量モード `FABLE_BUDGET_MODE`（abundant / conserve / reserve、未設定=conserve）の定義と各モードの効果（solo 推奨モデル・委譲閾値・reserve の自動実行 Fable 禁止と Opus 上限）を記載する

## 2. トリップワイヤーテンプレートの新設

- [x] 2.1 `plugins/dev-workflow/templates/escalation-tripwires.md` を作成する: トリップワイヤー3本（規模超過/失敗ループ/仕様の発明）を行為ベースの数値条件で定義し、発火時アクションは全てスキル呼び出し名で表現、閾値が運用調整前提であることと成果引き継ぎの指示を含める
- [x] 2.2 テンプレート冒頭に導入手順（interactive: グローバルルール or プロジェクト CLAUDE.md へコピー / unmanned: 憲法組み込みは別 change）を記載する

## 3. SKILL.md の Step D 分岐

- [x] 3.1 Step B の記述を decision-criteria.md の改訂（設計判断重心）と整合させる
- [x] 3.2 Step D に実行戦略別の3分岐（solo / delegate+verify / workflow 型）と各分岐の実行主体・verify 主体・TDD 維持を定義する
- [x] 3.3 昇格ルール（失敗シグナルで1段昇格、reserve 時の unmanned Opus 上限と needs-approval 返し）を Step D に記載し、トリップワイヤーテンプレートへの参照を張る

## 4. 検証とリリース

- [x] 4.1 スキル/テンプレートの整合検査: テンプレートに Workflow ツール直接操作が無いこと、SKILL.md と decision-criteria.md の相互参照が正しいこと、全 spec シナリオが文書上で充足されていることを確認する
- [x] 4.2 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げる
- [x] 4.3 commit / push で Draft PR #29 を更新する
