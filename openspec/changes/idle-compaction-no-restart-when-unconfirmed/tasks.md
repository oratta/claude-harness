## 1. 手順書

- [ ] 1.1 `reply-after-idle.md`「開始時の設定」の機械確認の節を直す。起動後の apply だけなどで live の off を確かめられないときは、interactive / unmanned とも再起動を求めず止まらずに進み「未確認」と記録する。on 判明時の再起動と開始停止・exit 1 の開始停止・「live で off」と報告しない文面は残す。親の 60 分待ち後の再起動は変えない。25 行目の「または機械確認で off を確かめられなかった場合」を消し、「初回の実機検証」「主に聞かず進む」の語は残す。矛盾する上書き指定は on 判明として扱うと書く。「未確認」は develop 開始コメントに記録すると書く。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:21-27

## 2. テスト

- [ ] 2.1 `develop-idle-compaction.bats` の「開始時の設定」の検査を新しい文面に合わせ、該当の文に当たる形で次を検査する: (a) 未確認のときは interactive / unmanned とも再起動を求めず止まらずに進み「未確認」と記録する、(b) on 判明時は再起動し、なお off を確認できなければ開始を止める、(c) check exit 1 / apply 失敗は開始を止める、(d) 機械確認の範囲を超えて「live で off」と報告しない。既存の '初回の実機検証' '主に聞かず進む' の検査（146 行目〜）は main spec に残ることを保つ。'unmanned は停止' など消える語は新文面に合わせる。触る範囲: plugins/dev-workflow/tests/develop-idle-compaction.bats:146-165
- [ ] 2.2 `develop-skill.bats` の「開始時の設定」節の語の検査を新しい文面に合わせる（'再起動' '開始を止め' '/config' は残る）。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:1527-1533

## 3. 記録

- [ ] 3.1 `plugins/dev-workflow/changes/1497.md`（新規）に変更内容と、1385.md の実機チェックリストは変えない旨を書く。触る範囲: plugins/dev-workflow/changes/1497.md（新規）
