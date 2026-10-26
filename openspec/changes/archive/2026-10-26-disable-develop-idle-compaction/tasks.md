# Tasks

行番号は origin/main `1b203ef5` を取り込んだ merge commit `c4ebb9ef` の時点。編集前に当該範囲を読む。R1 の APPROVE 前は実装・実設定変更へ進まない。spec 段では以下はすべて未実施。主の実機確認が必要なマージ後の作業は末尾に分ける。

## 1. 設定部品と入口

- [x] 1.1 `--check/--apply <worktree>` のテストを先に追加し、未実装による失敗を確認する。正常な JSON の単一キー更新、無い設定、false 済みの byte/mtime 不変、permissions/hooks/未知キー保存、ホーム・共有設定が不変、JSON 破損・非 object・重複キー・読めない設定・不正 worktree・symlink の無変更失敗、exit 0/1/2 を fixture で確かめる。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats（新規）
- [x] 1.2 専用部品を実装し、1.1 の Bats が全件通ることを確かめる。設定の atomic な置換、false 済み無書き込み、対象パスと原因だけのエラーを含め、CLI の出力を「live 反映済み」としない。触る範囲: plugins/dev-workflow/scripts/develop-idle-compaction.py（新規）、plugins/dev-workflow/tests/develop-idle-compaction.bats（新規）
- [x] 1.3 SKILL.md の開始手順に共通の check・apply・反映確認の案内を追加する。この PR で主が継続適用を一度承認した範囲として、新しい worktree でも操作承認を確認・質問せず当該キーだけ適用する。他キー・別ファイル・symlink 先は範囲外として従来の聖域承認を要し、部品は symlink を追わない。親子・モードの判定で省略せず、新セッションの引き継ぎでも実施すること、worktree に設定が残ること、未反映なら記録から再起動すること、通常 compact を維持することを文書テストで確認し、`bats plugins/dev-workflow/tests/develop-skill.bats` を通す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:20-28、plugins/dev-workflow/skills/develop/SKILL.md:78-115、plugins/dev-workflow/tests/develop-skill.bats:1-55（テスト追記）

## 2. 待機・再開の規則と変更記録

- [x] 2.1 main / #1379 を取り込んだ規則を読み、reply-after-idle.md の親だけの閾値・compact 後継続・監視継続を根拠にした表を改める。共通 idle 無効化と親の時間分類最優先・60 分以上の再起動・記録復元を書き、子の端末・会話量の条件は維持する。親の待ちの費用の節も改め、約 54 分の idle compact 回避を現行の理由から外し、キャッシュ維持・TTL による 3000 / 21600 秒・超過中と固定 TTL の説明を保持する。既存の該当文書テストを先に更新して期待どおり失敗することを確認し、変更後に通す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:1-109、plugins/dev-workflow/tests/epic-dispatch.bats:4041-4144、plugins/dev-workflow/tests/develop-skill.bats:1460-1477
- [x] 2.2 epic.md の「親の閾値の付け方」を共通開始手順への案内に変え、子の既存 --settings の説明は維持する。手順 3〜8 / 主の返事の前に時間分類を置き、手順 5 は 60 分未満の純粋な timeout に限り同じ wait の掛け直し・追加 --timeout 無し・子再調査と報告無しを維持する。60 分以上では timeout / 通知 / 返事より再起動を優先し、未処理出力・主の元発言の識別情報を記録して同じ worktree の新セッションへ渡す。手順 7 で復元し、元発言の真正性と対象の確認後に返事→通知→純粋な timeout の順で扱う。stopped-seen の pending-owner 復元、送信済み判断の再送防止、片付け待ちだけの timeout の条件 (d) と終了直前確認も保持する。発言一覧は短い timeout だけ報告不要とし、長時間後の再開案内は除外しない。状態表・child-log 確認の規定（48・57 行）には、60 分以上経過した旧親の引き継ぎ・再開案内（記録失敗時の停止報告を含む）に限り両方を省略する例外を明記する。新親は手順 7 で復元後、別セッション方式では child-log による子の会話ログ末尾の確認→その結果を反映した状態表の報告の順で行うと書き、表は区切りより下に置く。通常の報告や 60 分未満の通知・返事の処理後の報告へ例外を広げず、未起動・unreadable の子、ログ優先、サブエージェント方式の既存の扱いを保つ。develop-skill.bats の再開手順・発言一覧のテストと epic-dispatch.bats の既存の状態表・会話ログ確認の文書テストを先に更新・追加し、例外の対象と記録失敗時の省略、新親の復元→ログ確認→状態表の順、通常報告の義務の維持に加え、短い timeout、5m の長い timeout、スリープ、60 分以上の各通知、主の返事と通知の重複、起床リクエスト時刻との区別、片付け待ちだけの timeout、引き継ぎ記録失敗を確かめる。既存の TTL 選択・起動の回帰テストを含め、`bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats` を通す。epic-dispatch.sh の実装は変更しない。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:46-101（特に状態表・child-log 確認の規定と手順 5・7）、plugins/dev-workflow/skills/develop/references/epic.md:128-134、plugins/dev-workflow/tests/develop-skill.bats:1404-1477、plugins/dev-workflow/tests/epic-dispatch.bats:4041-4144、plugins/dev-workflow/tests/epic-dispatch.bats:6632-6655（状態表・会話ログ確認の文書テスト）
- [x] 2.3 changes/1385.md に採用理由、単一キーの継続適用を PR で一度承認する扱い、範囲外の従来の聖域承認、同 worktree の他セッションへの持続、未反映時の再起動、通常 compact 維持、長時間後の優先順位、戻し方、マージ後に主が行う確認を記録する。design.md の実機チェックリストを #1385 に投稿し、親・子の 60 分検証は未実施と明示する。成果物と issue コメントを読み合わせる。触る範囲: plugins/dev-workflow/changes/1385.md（新規）

## 3. 統合検証

- [x] 3.1 `bats plugins/dev-workflow/tests/develop-idle-compaction.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats tests/injection-budget.bats` をすべて exit 0 にする。予算値は変更せず、失敗があれば該当差分を直す。`openspec validate disable-develop-idle-compaction --type change --strict` と `git diff --check` も exit 0 にする。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats（新規）、plugins/dev-workflow/tests/develop-skill.bats:1-55、plugins/dev-workflow/tests/develop-skill.bats:1404-1477、plugins/dev-workflow/tests/epic-dispatch.bats:4041-4144、plugins/dev-workflow/tests/epic-dispatch.bats:6632-6655（状態表・会話ログ確認の文書テスト）、tests/injection-budget.bats:1-45（実行のみ）

## Workflow follow-up

- 仕様段階の Draft PR の本文に継続適用の範囲と承認待ちを明記する。通常の実装検証・レビューのあと、coordinator の指示に従って archive・PR の仕上げへ渡す。正式なリスク宣言にも「develop 開始時、現在の worktree の .claude/settings.local.json の idleCompaction だけを false にする。他の設定値は保持し、ホーム・共有設定には書かない」と継続適用・他セッションへの持続・範囲外（他キー・別ファイル・symlink 先）の聖域承認を記す。主のマージ承認（リスク宣言の許容）をこの範囲の一度の承認として記録し、以後の develop 開始で聞かない。現時点では承認待ち。現在の spec worker は実装・archive・merge をしない。
- マージ・plugin 更新後、主（oratta）が design.md のチェックリストどおりに親・子と単発の実効 off を確認し、親・子をそれぞれ条件の成立した状態で 60 分以上放置して新規 compact_boundary が 0 件である結果を #1385 に記録する。通常の上限近くでの自動 compact の実機結果は別区間で記録する。未実施中は issue の実機受け入れ条件を合格にしない。
- 実装担当は #1264 に #1385 でアイドル閾値の再集計が不要になった旨を記録し、主が #1385 の実機結果を確認した後に不要として閉じる。現時点では閉じない。
