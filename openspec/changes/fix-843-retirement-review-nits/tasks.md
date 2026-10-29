# Tasks

行番号は起点 `28e65758` 時点。編集前に該当範囲を読み直す。実装前に issue #843 の最新の仕様化判断と R1 の APPROVE を確認する。7 ファイルの既知の対象数は coordinator に報告し、実装開始・分割の判断を待つ。

## 1. archive の実施結果と説明を訂正する

- [ ] 1.1 P1-F1: 4.1〜4.5 を `- [x]` にする。`git grep -n -F -- '- [ ]' -- openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/tasks.md` が exit 1 / 出力 0 件となり、該当 5 項目が完了済みであることを確認する。触る範囲: openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/tasks.md:35-39
- [ ] 1.2 P1-F2: proposal の 2 か所を「2 要件を外し、cooking 残骸掃除の要件から skill-pack の言及を外す」に直す。`git grep -n -F '3 要件' -- openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/proposal.md` が exit 1 / 出力 0 件で、2 REMOVED + 1 MODIFIED と一致することを確認する。触る範囲: openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/proposal.md:16-29
- [ ] 1.3 P1-F3: telegram 切り替えを uninstall → 残る旧 enabledPlugins の削除 → 公式プラグイン導入の 3 手順に直し、README の手順 1〜3 と照合する。archive の過去の delta spec が未変更であることも diff で確認する。触る範囲: openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/design.md:35-37、README.md:144-148（照合のみ）

## 2. 現行 spec の例示と注記だけを直す

- [ ] 2.1 P2-F1: 守備範囲から dev-workflow README の例示を外す。`git grep -n -F 'plugins/dev-workflow/README.md' -- openspec/specs/skill-pack-telegram-e2s-retirement/spec.md` が exit 1 / 出力 0 件となること、変更が本 change の MODIFIED delta に一致し、要件名・規範文・Scenario が維持されることを diff で確認する。archive 内の同文は変更しない。触る範囲: openspec/specs/skill-pack-telegram-e2s-retirement/spec.md:29-36
- [ ] 2.2 P5-F1: skill-pack の編集慣習を参照する括弧書きだけを削除する。当該括弧書きが無く、enabledPlugins 削除指示と Scenario は残り、本 change の MODIFIED delta に一致することを確認する。`bats tests/openspec-specs-format.bats` が exit 0 となることを確認する。触る範囲: openspec/specs/retirement-handoff-docs/spec.md:20-32

## 3. README の案内と一覧表の回帰検査を直す

- [ ] 3.1 P1-F4 / P3-F1: README に telegram は元から all に無かったこと、および `~/.claude/skills/distilled/e2s-*/SKILL.md` と `<repo>/.claude/skills/distilled/` は uninstall で消えない旨を追記する。既存の理由・代替・3 手順を保持し、追加した両注記を目視確認する。既存の README 案内テスト（`bats --filter 'README records the retirement' tests/skill-pack-telegram-e2s-retirement.bats`）が exit 0 となることを確認する。触る範囲: README.md:136-148
- [ ] 3.2 P10-F1: テスト 6 を awk 版へ修正し、解散済み節より前の表の第 1 列で空白・バッククォートを正規化して対象 3 名を比較する。正常系の `bats --filter 'README plugin table has no row for the three plugins' tests/skill-pack-telegram-e2s-retirement.bats` が exit 0 となることを確認する。指定 scratchpad 内に README と修正済み bats のコピーを作り、同じ filter で、3 名それぞれの空白・バッククォートなしの行（`|telegram|` を含む）およびそれらを付けた行を解散済み節より前に置くと非 0、解散済み節にだけ置くと exit 0 となる回帰検証を作成・実行する。実 repo を fixture として書き換えず、awk エラーも検査失敗になることを確認する。触る範囲: tests/skill-pack-telegram-e2s-retirement.bats:51-57

## 4. 実装段の統合確認

- [ ] 4.1 `openspec validate fix-843-retirement-review-nits --type change --strict` と `git diff --check` が exit 0 で、実装差分が許可された 7 ファイルだけであることを確認する。`bats tests/skill-pack-telegram-e2s-retirement.bats` を実行し、archive 前に参照検査だけが落ちる場合は、一致が追跡済みの本 change の delta spec だけであることを確認して記録する。それ以外の失敗は解消する。触る範囲: README.md:136-148、tests/skill-pack-telegram-e2s-retirement.bats:18-66、openspec/specs/skill-pack-telegram-e2s-retirement/spec.md:29-36、openspec/specs/retirement-handoff-docs/spec.md:20-32、openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/tasks.md:35-39、openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/proposal.md:16-29、openspec/changes/archive/2026-10-08-retire-skill-pack-telegram-e2s/design.md:35-37（確認のみ）

## Workflow follow-up

- finish 段で本 change を archive し、delta と現行 spec の 2 か所の修正が一致することを確認する。
- archive 後に `bats tests/skill-pack-telegram-e2s-retirement.bats` と `bats tests/openspec-specs-format.bats` が exit 0 となり、issue #843 の受け入れ条件 1〜5 がすべて満たされることを確認する。ここまで終える前に全件成功とは記録しない。
- プラグイン version・plugins 配下・注入予算は変更しない。merge / auto-merge は実行しない。
