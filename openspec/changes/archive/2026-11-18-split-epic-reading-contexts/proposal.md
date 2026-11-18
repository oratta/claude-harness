# Proposal

## Why

エピックの親と子は `epic.md` 約 5 万字を共に読み、子にも親の起動・片付け・見張りが入り、親にも停止時だけの処理が開始時から入る。同じ委任判定・時間分類・声かけの規則が複数箇所にあり、修正が食い違うため、#1682 の方針に従って読む場面と正本を分ける（#1684）。

## What Changes

- `epic.md` を入口にし、親の通常進行・停止・委任・マージ待ち・別リポジトリ・サブエージェント方式と共有の声かけ規則を必要時に読む構成にする。
- 注意書きの信頼条件と nested の扱いは入口、子の停止と受信は `epic-child-stop.md` に残す。親子の委任判定は共有正本を参照する。
- 親の時間分類は `reply-after-idle.md` に集約する。繰り返す報告の書き分け規定と経緯を整理し、子の例は既存の親の判断基準を参照する。
- ファイル位置に固定された Bats を移動で落ちない検査へ変え、場面別のファイル集合とバイト予算を検査する。
- 現行 specs の移動する節・手順への参照を更新する。判定条件、入力・出力・添え書き・権限・マージ条件は変えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: エピックの場面別読込、共有正本、移設先の案内と既存要件の参照。
- `dev-workflow-epic-state`: 状態管理・片付け・サブエージェント方式の手順書の参照。
- `dev-workflow-pr-token-budget`: PR トークン上限の子を親が扱う節の参照。
- `destructive-git-hook`: 別セッションの子の停止検知を説明する節の参照。
- `owner-question-style`: 親の報告と子の停止の移設先、繰り返す書き分けの参照。
- `harness-public-private-split`: 公開しない起動部品の説明が移るファイルの参照。

## Impact

主な実装対象は `plugins/dev-workflow/skills/develop/references/`、その参照元、文言を検査する既存 Bats、新しい `tests/develop-epic-scene-budget.{txt,bats}`。仕様 delta は上記 6 capability に属するが、独立した機能追加ではなく同じ手順書移設への追随であり、単一 change・単一 PR とする。

`SKILL.md` は epic の参照先の付け替えだけ。#1685 の節の移動・削除、#1686 のスクリプト化と出力語の説明の削除、#1687 のゲート本文の整理を含めない。ゲート配下は必要な参照パスだけ変え、`tests/injection-budget.txt` は変更しない。
