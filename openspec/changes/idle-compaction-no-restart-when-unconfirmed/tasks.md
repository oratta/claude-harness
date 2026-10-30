## 1. 手順書

- [ ] 1.1 `reply-after-idle.md`「開始時の設定」の機械確認の節を直す。起動後の apply だけなどで live の off を確かめられないときは、interactive / unmanned とも再起動を求めず止まらずに進み「未確認」と記録する。on 判明時の再起動と開始停止・exit 1 の開始停止・「live で off」と報告しない文面は残す。親の 60 分待ち後の再起動は変えない。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:22-42

## 2. テスト

- [ ] 2.1 `develop-idle-compaction.bats` の「開始時の設定」の語の検査（'unmanned は停止' など）を新しい文面に合わせ、「未確認」と「再起動を求めず」が入ることを検査する。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats:150-165
- [ ] 2.2 `develop-skill.bats` の「開始時の設定」節の語の検査を新しい文面に合わせる（'再起動' '開始を止め' '/config' は残る）。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1527-1533

## 3. 記録

- [ ] 3.1 `plugins/dev-workflow/changes/1497.md`（新規）に変更内容と、1385.md の実機チェックリストは変えない旨を書く。触る範囲: plugins/dev-workflow/changes/1497.md（新規）
