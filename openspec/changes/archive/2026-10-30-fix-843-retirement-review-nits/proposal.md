# Proposal

## Why

PR #841 の解散は完了しているが、archive の完了状態・説明、現行 spec の例示・注記、README の案内に 8 件のレビュー nit が残っている。issue #843 の受け入れ条件に従い、記録を実施結果に合わせ、README の表記ゆれを撤去検査が見逃す穴を塞ぐ。

## What Changes

- P1-F1: archive の tasks.md の 4.1〜4.5 を完了済みにする。
- P1-F2: archive の proposal.md の 2 か所を、repo-root-cleanup の「2 要件を外し、cooking 残骸掃除の要件から skill-pack の言及を外す」に直す。
- P1-F3: archive の design.md の telegram 切り替えを、README と同じ uninstall・残存設定の削除・公式プラグイン導入の 3 手順に直す。
- P1-F4 / P3-F1: README に、telegram は元から all に無かったことと、uninstall で個人・プロジェクトの distilled スキルが消えないことを追記する。
- P2-F1 / P5-F1: 現行 spec 2 本の古くなった例示・括弧書きだけを削除する。要件名、MUST / MUST NOT / SHALL の意味、Scenario は維持する。
- P10-F1: bats の README 一覧表の検査を awk に替え、空白とバッククォートの有無に依存せず対象プラグインの行を検出する。解散済み一覧は引き続き検査対象外とする。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `skill-pack-telegram-e2s-retirement`: 「3 プラグインへの参照を掃除する」の守備範囲から、現状に合わない dev-workflow README の例示だけを外す。要件の意味は変えない。
- `retirement-handoff-docs`: 「`post-merge-steps.md` MUST contain user-facing cleanup instructions」の、解散済み skill-pack の編集慣習を参照する括弧書きだけを外す。必要なコマンドと設定削除の案内は維持する。

## Impact

記録先は oratta/claude-harness#843。実装対象は同 issue で許可された次の 7 ファイルに限る。

- `openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/{tasks,proposal,design}.md`
- `openspec/specs/skill-pack-telegram-e2s-retirement/spec.md`
- `openspec/specs/retirement-handoff-docs/spec.md`
- `README.md`
- `tests/skill-pack-telegram-e2s-retirement.bats`

本 change の artifact は上記とは別の計画成果物である。プラグインの実装・version・変更記録、marketplace 登録、注入予算は変更しない。archive の過去の delta spec は書き換えない。
