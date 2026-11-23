# Tasks

## 1. 上限と費用の手順・契約テスト

- [x] 1.1 手順2で最初のタイマーを置いた時刻を保持し、手順3の再設置条件に初回から12時間未満を追加する。同じ待ちの再設置で基点を更新しないこと、12時間以上では元作業と実行IDを保持して完了通知を待ち、届いたときに一度の書き直しを受け入れることを記す。初回基点・更新禁止・上限未満の再設置・上限到達/超過後の再設置禁止・元作業保持を検査する契約テストを追加し、`bats plugins/dev-workflow/tests/child-background-wait.bats` が通ることを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/child-background-wait.md:20-49、plugins/dev-workflow/tests/child-background-wait.bats:63-86
- [x] 1.2 spec段で投稿した12時間上限の費用比較コメントを #1743 で確認し、手順書末尾と変更記録にリンクする。会話20万の旧会話部分は12時間約 $1.32 と一度の1h書き直し $1.60、24時間無上限約 $2.52 は旧方針と区別し、新規入力・出力・工具往復・上限後の書き直しを含む総費用や実機成功の保証にしない。変更記録を検査する既存テストを更新し、費用記述の追加検査とともに `bats plugins/dev-workflow/tests/child-background-wait.bats` を通す。触る範囲: plugins/dev-workflow/skills/develop/references/child-background-wait.md:60-60、plugins/dev-workflow/changes/1743.md:5-21、plugins/dev-workflow/tests/child-background-wait.bats:115-123

## 2. 統合確認

- [x] 2.1 `bats tests/develop-startup-budget.bats tests/injection-budget.bats` を実行して起動時・常時注入の予算内であることを確認する。`git diff` で `SKILL.md` と予算ファイルが変更されていないことも確認する。触る範囲: tests/develop-startup-budget.bats:1-33（参照のみ）、tests/injection-budget.bats:1-41（参照のみ）
- [x] 2.2 `openspec validate child-background-wait-12h-cap --type change --strict` と `git diff --check` を通し、変更対象が上限・費用・契約テストに閉じることを確認する。触る範囲: openspec/changes/child-background-wait-12h-cap/specs/dev-workflow-child-background-wait/spec.md（本changeの仕様差分、参照のみ）、plugins/dev-workflow/skills/develop/references/child-background-wait.md:20-60、plugins/dev-workflow/tests/child-background-wait.bats:63-123、plugins/dev-workflow/changes/1743.md:5-21

## Workflow follow-up

- R1のAPPROVEを #1743 で確認してからimplement段へ進む。このspec段では手順書・テスト・変更記録を編集しない。
- finish段で通常の手順に従いarchiveと仕様宣言を行う。このchangeは既存のarchive済みchangeを変更せず、新規changeとして扱う。
- マージ後の実子の60分超の待ちの観測は #1743 の既存受け入れ条件に従い別途記録する。静的検証を実機の維持・削減成功としない。
