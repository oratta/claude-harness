## Why

#1219〜#1222 で、develop の SKILL.md の節を `references/` 配下のファイルへ移した（エピックの 2 節と 4 小節 → `epic.md`・`epic-child-stop.md`、保留の引き継ぎ → `handover.md`、channel の 3 小節 → `channel.md`、直し方の判定 → `fix-check.md`）。openspec の spec には、移した節を「SKILL.md の節」として規定の置き場所に名指ししている記述が残っており、実物と合わない。spec を読んだ人や検査が、SKILL.md を探して存在しない中身にたどり着けない。

## What Changes

- 移した節を SKILL.md の節として名指ししている要件・シナリオの文を、移設先のファイルを指す形に直す（要件の名前・シナリオの意図・守備範囲は変えない）。
  - エピックの扱い（条件・作り方・回し方・Orca 経路の手順・完了条件）→ `skills/develop/references/epic.md`
  - エピックの子が主の返事を待って止まるとき → `skills/develop/references/epic-child-stop.md`
  - 保留で止まるときの引き継ぎ・新しいセッションでの再開 → `skills/develop/references/handover.md`
  - レビューの周を主に聞かずに続ける（直し方の判定）→ `skills/develop/references/fix-check.md`
  - channel の読み替えの規則と対象の列挙 → `skills/develop/references/channel.md`（読み替えの対象の列挙の網羅検査は SKILL.md に加えて channel.md も除く。対象は channel.md の列挙どおり 10 個にそろえる）
- SKILL.md に今も中身がある節（ループの終わり・PR トークン上限・モデル・実行モード・1 ループの (4)・保留の行）を名指す記述は直さない。
- 要件の見出し（名前）は変えない。名前に「SKILL.md」を含む 2 件（`SKILL.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ`・`別のリポジトリの子を含むエピックの回し方を SKILL.md に書く`）は、名前の変更が要件名を参照する他の記述に波及するため、別の変更に回す。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: エピック・引き継ぎ・直し方の判定・channel の読み替えの置き場所を、移設先のファイルを指す形に直す
- `dev-workflow-ci-watch`: エピックの子の停止の記録の置き場所を `epic-child-stop.md` に直す
- `dev-workflow-pr-review-gate`: 直し方の判定の正本の場所を `fix-check.md` に直す
- `harness-public-private-split`: 「部品ごとの欄」の置き場所を `epic.md` に直す
- `owner-question-style`: 正本を参照する各所の一覧に、移設先の 3 ファイルを足す

## Impact

`openspec/specs/` の 5 つの spec の文言だけ。`plugins/` 配下のスキル・コマンド・スクリプト・テストは変えない（commands/develop.md の記述などは別の子が直す）。
