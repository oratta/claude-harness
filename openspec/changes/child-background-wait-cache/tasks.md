# Tasks

## 1. 本体の長い待ちの契約と検査

- [ ] 1.1 `child-background-wait.md` に再開可能性による分岐、TTL / 時刻の根拠、45 分の有限タイマーの雛形、実作業保持、ID 照合と取消、5m / unknown / スリープ時の限界を書く。CI・停止・予約文・Codex は design の既存正本を参照する。本体のターン終了と依存待ちでのセッション終了を区別する。同時に `child-background-wait.bats` を新設し、正常 / 失敗の sleep スタブで雛形を実行して、60 秒を 45 回、一度だけの通知、途中失敗では非ゼロかつ成功通知なしを確認する。`bats plugins/dev-workflow/tests/child-background-wait.bats` が合格すること。触る範囲: plugins/dev-workflow/skills/develop/references/child-background-wait.md（新規）、plugins/dev-workflow/tests/child-background-wait.bats（新規）
- [ ] 1.2 SKILL.md に nested の本体が agent・CI・Monitor・Codex の待ちに入る前に新 reference を読む条件付き入口を置く。`child-background-wait.bats` に入口のリンク解決と、外部依存への移行失敗・実行中作業・既存の短い期限・通知競合・取消後の遅延通知・TTL 5m/unknown の各契約が正本に記述される検査を加え、同テストを通す。既存の CI の timeout や停止済み子の受信契約をコピーしない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:202-204（子の入口）、plugins/dev-workflow/tests/child-background-wait.bats（新規）
- [ ] 1.3 `changes/1743.md` に選んだ扱い・費用比較コメントの URL・維持費用の限界・マージ後の実機確認項目を残す。版番号や rules / description を変えず、記録と PR から未検証の項目が分かることを確認する。触る範囲: plugins/dev-workflow/changes/1743.md（新規）

## 2. 統合確認

- [ ] 2.1 `bats plugins/dev-workflow/tests/child-background-wait.bats plugins/dev-workflow/tests/epic-child-no-ask-tool.bats plugins/dev-workflow/tests/ci-watch-entry.bats plugins/dev-workflow/tests/subagent-waiting.bats tests/develop-startup-budget.bats tests/injection-budget.bats` と `openspec validate child-background-wait-cache --type change --strict` を実行し、成功を記録する。既存の待ち契約や注入予算が落ちたら理由を調べ、予算を自動で広げない。触る範囲: plugins/dev-workflow/tests/child-background-wait.bats（新規）、plugins/dev-workflow/skills/develop/references/child-background-wait.md（新規）、plugins/dev-workflow/skills/develop/SKILL.md:202-204

## Workflow follow-up

- R1 の APPROVE が記録先に投稿されるまで実装しない。
- archive・仕様宣言・独立 PR レビュー・ゲートは本体が割り当てる後続工程で行う。
- #1743 条件 3 はマージ後の実子で実施する。会話量・モデル・TTL・60 分以上の待ち・通知の時刻と `cache_read_input_tokens`、または停止と再起動の証拠を issue に残す。タイマーの輸送や Bats 合格を実機確認に代えない。
