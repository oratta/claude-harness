## Why

公開版に残る dev-workflow の部品のうち、Orca 経路を除く行に、flatmate を正本・配布元・設置元として名指しする記述と、オーナーの開発環境（`CLAUDE_HARNESS_DEV_DIR`・daily-report と Obsidian の vault・agents 保管庫）を前提にした記述、検査の入力のオーナーのプロジェクト名（moko）が残っている。`docs/public-private-split.md` の固有記述の一覧で「担い手なし」の行で、客の環境では指す先が無い（issue #1168、エピック #1127 の子。#1168 を割った 2 つの change の 2 つ目。もう 1 つは `public-names-non-devworkflow`）。

## What Changes

一覧の dev-workflow の「担い手なし」の行のうち Orca 経路を除く行を、行ごとに「直す／個人版へ移す部品を指す行は個人版の有無に依らない書き方に直す／載せない行の基準に当たると理由を書いて外す」から選んで片付ける（選び方は design D1）。

- flatmate を正本・配布元として名指しする行（`README.md:137`・develop `SKILL.md` の 337・400・541・`pr-body-format.md:110`・`issueify/SKILL.md:41`・`push-guard-setup/SKILL.md:23`・`escalation-tripwires.md:16`・`pr-state.sh:2`・`memory-refresh/SKILL.md` の 76・94）: flatmate の名を外し、「利用者のリポジトリ」「憲法の正本を持つリポジトリ」のような一般の言い方にする
- `CLAUDE_HARNESS_DEV_DIR`・daily-report と Obsidian の vault・agents 保管庫の行（`ci-watch.md:95`・`memory-refresh/SKILL.md:82`・`self-verification.md:41`・`templates/auto-merge/docs/auto-merge.md:273`）: 条件つきの書き方か一般の言い方に直す
- 検査の入力のオーナーのプロジェクト名（`templates/auto-merge/scripts/test-auto-merge-workflow.sh` の 87・148）: `example` に置き換える
- Orca 経路の行の担い手を #1177 に付け替える。#1123 の結果で Orca は差し替え可能な起動部品の 1 つになったので、書き方は「Orca を使う場合」に直すが、同じ節を #1123 の change 3b が書き直し中のため、#1177 で 3b の後に行う。この change は一覧の「直す issue」の欄を「担い手なし」から「#1177」に変えるだけで、Orca の行の本文は触らない
- 一覧に載っていない候補語の当たり（約 137 件のうち dev-workflow 分）を、載せない行の基準に当たるかで 1 件ずつ判定し、当たらない行は直す。Orca の語の当たりは #1177 に回す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `harness-public-private-split`: dev-workflow の公開版の部品（Orca 経路を除く）が決めた固有名を持たないことを求める要件と、Orca 経路の行の担い手を #1177 とする要件を足す

## Impact

- 上記の dev-workflow のファイル（Markdown・`pr-state.sh`・auto-merge のテンプレート）と `docs/public-private-split.md`（一覧の行の削除と Orca の行の担い手の付け替え）
- `tests/public-private-split.bats`、dev-workflow の bats（文面を読むテストが直した文を固定していれば、新しい文に合わせる）
- 変更の記録 `plugins/dev-workflow/changes/1168.md`
- `plugins/dev-workflow/skills/develop/SKILL.md` は Orca 経路の節を #1123 の change 3b が書き直し中。この change は 337・400・541 の flatmate の行だけを触り、節をまたがない（衝突しにくいが、マージ前に `git fetch` して重なりを確かめる）
