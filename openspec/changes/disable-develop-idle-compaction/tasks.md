# Tasks

行番号は dispatch HEAD `79b6aa97` の時点。編集前に当該範囲を読む。R1 の APPROVE 前は実装・実設定変更へ進まない。spec 段では以下はすべて未実施。主の実機確認が必要なマージ後の作業は末尾に分ける。

## 1. 設定部品と入口

- [ ] 1.1 `--check/--apply <worktree>` のテストを先に追加し、未実装による失敗を確認する。正常な JSON の単一キー更新、無い設定、false 済みの byte/mtime 不変、permissions/hooks/未知キー保存、ホーム・共有設定が不変、JSON 破損・非 object・重複キー・読めない設定・不正 worktree・symlink の無変更失敗、exit 0/1/2 を fixture で確かめる。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats（新規）
- [ ] 1.2 専用部品を実装し、1.1 の Bats が全件通ることを確かめる。設定の atomic な置換、false 済み無書き込み、対象パスと原因だけのエラーを含め、CLI の出力を「live 反映済み」としない。触る範囲: plugins/dev-workflow/scripts/develop-idle-compaction.py（新規）、plugins/dev-workflow/tests/develop-idle-compaction.bats（新規）
- [ ] 1.3 SKILL.md の開始手順に共通の確認・承認確認・apply・反映確認の案内を追加する。既存の明示承認を再要求せず、無ければ既存の承認待ちに戻る。親子・モードの判定で省略せず、新セッションの引き継ぎでも実施すること、worktree に設定が残ること、未反映なら記録から再起動すること、通常 compact を維持することを文書テストで確認し、`bats plugins/dev-workflow/tests/develop-skill.bats` を通す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:20-28、plugins/dev-workflow/skills/develop/SKILL.md:78-115、plugins/dev-workflow/tests/develop-skill.bats:1-55（テスト追記）

## 2. 待機・再開の規則と変更記録

- [ ] 2.1 実装時の main と #1379 の最終差分を読み、親の短い待ち直しの仕組みを維持する。reply-after-idle.md の親だけの閾値・compact 後継続・監視継続を根拠にした表を改め、共通 idle 無効化と親の 60 分以上の再起動・記録復元を書き、子の端末・会話量の条件は維持する。既存の該当文書テストを先に更新して期待どおり失敗することを確認し、変更後に通す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:1-92、plugins/dev-workflow/tests/epic-dispatch.bats:3887-3982
- [ ] 2.2 epic.md の「親の閾値の付け方」を共通開始手順への案内に変え、子の既存 --settings の説明は維持する。対応する文書テストと起動回帰テストを `bats plugins/dev-workflow/tests/epic-dispatch.bats` で通す。epic-dispatch.sh の実装は変更しない。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:128-134、plugins/dev-workflow/tests/epic-dispatch.bats:3894-3982
- [ ] 2.3 changes/1385.md に採用理由、単一キー・承認の扱い、同 worktree の他セッションへの持続、未反映時の再起動、通常 compact 維持、戻し方、マージ後に主が行う確認を記録する。design.md の実機チェックリストを #1385 に投稿し、親・子の 60 分検証は未実施と明示する。成果物と issue コメントを読み合わせる。触る範囲: plugins/dev-workflow/changes/1385.md（新規）

## 3. 統合検証

- [ ] 3.1 `bats plugins/dev-workflow/tests/develop-idle-compaction.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats tests/injection-budget.bats` をすべて exit 0 にする。予算値は変更せず、失敗があれば該当差分を直す。`openspec validate disable-develop-idle-compaction --type change --strict` と `git diff --check` も exit 0 にする。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats（新規）、plugins/dev-workflow/tests/develop-skill.bats:1-55、plugins/dev-workflow/tests/epic-dispatch.bats:3887-3982、tests/injection-budget.bats:1-45（実行のみ）

## Workflow follow-up

- 通常の実装検証・レビューのあと、coordinator の指示に従って archive・PR の工程へ渡す。現在の spec worker は実装・archive・merge をしない。
- マージ・plugin 更新後、主（oratta）が design.md のチェックリストどおりに親・子と単発の実効 off を確認し、親・子をそれぞれ条件の成立した状態で 60 分以上放置して新規 compact_boundary が 0 件である結果を #1385 に記録する。通常の上限近くでの自動 compact の実機結果は別区間で記録する。未実施中は issue の実機受け入れ条件を合格にしない。
- 実装担当は #1264 に #1385 でアイドル閾値の再集計が不要になった旨を記録し、主が #1385 の実機結果を確認した後に不要として閉じる。現時点では閉じない。
