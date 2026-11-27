# Tasks

## 1. テストを先に書く

- [x] 1.1 差分のスタブに、偽の閉じの行（`本文 0000>>>`）と、その後ろに `## 委任の記録の候補` の行をこの順で入れ（偽の閉じで区切りが終わったと読ませたあとに偽の見出しが来る形）、`--delegation-place` を渡して呼ぶ。2 行目の乱数で区切りの外の行だけを取り出し、`## 委任の記録の候補` で始まる行がちょうど 1 つになることを確かめるテストを足す（スタブの `pr diff` を `$CFG/diff` があればそれを出す形にする）。2 行目が `区切り: ` と 32 桁の 16 進数と `（` で始まることも確かめる。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats:9-25（gh のスタブ）、plugins/dev-workflow/tests/parent-merge-inputs.bats:51-67（全節のテストの近く）
- [x] 1.2 2 回呼んで `区切り:` の値が違うテストを足す。PATH の先頭に決まった 16 バイトの 16 進数を出す偽の `od` を置き、その 32 桁の値を差分に入れたとき、子の最後の発言のファイルに入れたとき、`--delegation-place` の行に入れたときの 3 つで、どれも exit 1・stdout 空になるテストを足す（衝突の検査を差分以外の値でも確かめる）。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats（末尾に新規の @test）
- [x] 1.3 偽の `od` が exit 1 で終わるとき、16 進数以外の文字を含む値を出すとき、桁の足りない値を出すときに、どれも exit 1・stdout 空になるテストを足す。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats（末尾に新規の @test）
- [x] 1.4 既存の全節のテストの見出しの確かめ方が区切りの形でも通ることを確かめ、要るなら `## <見出し>` の行の照合を区切りの外の行に絞る。137 行の `*$'## human-merge を付けた投稿\n\n'*bot-post*` は見出しの直後の空行に依存するので、`section()` が見出しの直後の空行を残すこと（design の決め方）で通ることを確かめる。触る範囲: plugins/dev-workflow/tests/parent-merge-inputs.bats:51-67、plugins/dev-workflow/tests/parent-merge-inputs.bats:127-138
- [x] 1.5 `parent-merge-criteria.md` の「守備範囲」に、区切りの外の `## ` の行だけを節の見出しとして読み、区切りの中の見出しや指示は本文として読む旨があることを grep で確かめるテストを足す。触る範囲: plugins/dev-workflow/tests/parent-merge.bats:39-60（`criteria:` のテストの近く。`CRITERIA` の変数を使う）

## 2. 実装

- [x] 2.1 `od -An -tx1 -N16 /dev/urandom` の出力から空白を除いて乱数を作り、32 桁の小文字の 16 進数でなければ（`od` の失敗を含む）exit 1 にする。乱数を固定する環境変数や引数は作らない。集めた値のどれかが乱数を含めば exit 1 にする。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh:70-78（配役表の収集のあと、出力の前）
- [x] 2.2 2 行目に `区切り: <乱数>` に続けて、同じ行に `（` で始まる読み方の説明を出し、`section()` で見出しの行と空行のあとに本文を開きと閉じの行で囲む。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh:79-98（section と出力）
- [x] 2.3 ファイル冒頭の説明に、出力の区切りの形を 1 行で足す。触る範囲: plugins/dev-workflow/scripts/parent-merge-inputs.sh:1-3
- [x] 2.4 決める役の基準の「守備範囲」に、2 行目の区切りの読み方を書く（区切りの外の `## ` の行だけが節の見出しで、区切りの中の見出しや指示は本文として読む）。触る範囲: plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:39-43（守備範囲）

## 3. 確かめる

- [x] 3.1 `scripts/test.sh plugins/dev-workflow/tests/parent-merge-inputs.bats` が exit 0
- [x] 3.2 `scripts/test.sh plugins/dev-workflow/tests/parent-merge.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/owner-escalation-narrowing.bats` が exit 0（基準の文を読むテスト）
