# Tasks

## 1. テストを先に書く

- [ ] 1.1 差分のスタブに `## 委任の記録の候補` の行と偽の閉じの行（`本文 0000>>>`）を入れ、`--delegation-place` を渡して呼ぶ。2 行目の乱数で区切りの外の行だけを取り出し、`## 委任の記録の候補` で始まる行がちょうど 1 つになることを確かめるテストを足す（スタブの `pr diff` を `$CFG/diff` があればそれを出す形にする）。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats:9-25（gh のスタブ）、plugins/dev-workflow/tests/parent-merge-inputs.bats:51-67（全節のテストの近く）
- [ ] 1.2 2 回呼んで `区切り:` の値が違うテストと、乱数を固定して同じ値を差分に入れると exit 1・stdout 空になるテストを足す。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats（末尾に新規の @test）
- [ ] 1.3 既存の全節のテストの見出しの確かめ方が区切りの形でも通ることを確かめ、要るなら `## <見出し>` の行の照合を区切りの外の行に絞る。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats:51-67

## 2. 実装

- [ ] 2.1 乱数を作り（テスト用の固定値の環境変数を受ける）、集めた値のどれかが乱数を含めば exit 1 にする。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh:70-78（配役表の収集のあと、出力の前）
- [ ] 2.2 2 行目に `区切り:` の行を出し、`section()` で本文を開きと閉じの行で囲む。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh:79-98（section と出力）
- [ ] 2.3 ファイル冒頭の説明に、出力の区切りの形を 1 行で足す。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh:1-3
- [ ] 2.4 決める役の基準の「守備範囲」に、2 行目の区切りの読み方を書く（区切りの外の `## ` の行だけが節の見出しで、区切りの中の見出しや指示は本文として読む）。触る範囲: plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:39-43（守備範囲）

## 3. 確かめる

- [ ] 3.1 `scripts/test.sh plugins/dev-workflow/tests/parent-merge-inputs.bats` が exit 0
- [ ] 3.2 `scripts/test.sh plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/owner-escalation-narrowing.bats` が exit 0（基準の文を読むテスト）
