## 1. 検査を先に直す（TDD）

- [ ] 1.1 `ALLOWED` から「保留（#1123 の後）」を外す。触る範囲: tests/public-private-split.bats:35（`check_split` の中の `ALLOWED`）
- [ ] 1.2 「epic-launch-orca.sh is a pending part, so a listing row pointing at it fails」を、一覧に `plugins/dev-workflow/scripts/epic-launch-orca.sh:2` を指す行（担い手 #1129）を足しても「公開版に決まる部品に属さない」の文言が出ないことを確かめる検査に置き換える（終了コードは担い手の検査など他の理由で落ちうるので、出力に属さないの文言が無いことだけを見る）。触る範囲: tests/public-private-split.bats:676-686
- [ ] 1.3 表の `plugins/dev-workflow/scripts/stop-judge.sh` の行の分類を「保留（#1123 の後）」に書き換えると、決めた値以外の分類として落ちる検査を足す（`edit_doc` を使う）。触る範囲: tests/public-private-split.bats:369-376 の近く（新規の @test）
- [ ] 1.4 `stop-judge.sh` に `moko` を足した作業コピーで `devwf_unlisted` が当たりを返す検査を足す（`devwf_public_files` が確定した部品を含むことの固定）。作業コピーは既存の検査と同じく一時の場所に作り、実ファイルを書き換えない。触る範囲: tests/public-private-split.bats:558-600 の近く（新規の @test）
- [ ] 1.5 確定した 5 行（`epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md`）のパスを固定の文字列で持ち、表にちょうど 1 行ずつあって分類が「公開版」であることを確かめる検査を足す。あわせて、そのうち 1 行（例: `parent-merge-criteria.md`）の分類を `edit_doc` で「個人版」に書き換えると、その部品のパスを挙げて落ちる検査を足す。触る範囲: tests/public-private-split.bats:26-290（`check_split` の中に確定した行の照合を足すか、別の関数として足す）、tests/public-private-split.bats:676 の近く（新規の @test）
- [ ] 1.6 `bats tests/public-private-split.bats` を回し、1.2・1.3・1.5 が文書の修正前の状態で期待どおり落ちることを確かめる（1.4 は修正前から通ってよい）

## 2. 仕分けの文書を確定する

- [ ] 2.1 「分類の値」から「保留（#1123 の後）」の項目を消し、値を 3 つにする。触る範囲: docs/public-private-split.md:15-22
- [ ] 2.2 節「保留の行の確定」を、#1129 で 5 行を公開版に確定した記録に書き換える（何を見て決めたか: 起動部品が Orca と tmux から選ぶ形になり Orca が無い環境でもエピックを回せる・`epic-launch-orca.sh` は差し替えの部品の 1 つ・残り 3 行は `epic-dispatch.sh` と同じ側。決めた issue の URL https://github.com/oratta/claude-harness/issues/1129 ）。触る範囲: docs/public-private-split.md:38-40
- [ ] 2.3 表の 5 行の分類を「公開版」にし、理由の欄を確定した理由に書き換える。dev-workflow（分割）の行の理由の「エピック実行の Orca 経路は #1123 の後に決め」を確定後の文に直す。触る範囲: docs/public-private-split.md:71、docs/public-private-split.md:74-78
- [ ] 2.4 「載せない行の基準」の「差し替え可能な起動部品の 1 つとして Orca を並べた行」の太字の後ろの前提の文（「この項目は `epic-launch-orca.sh` が公開版に決まる前提で当てる。…一覧に戻し、担い手を #1129 にする」）を、#1129 で公開版に確定したので外した行は戻さない、に書き換える。触る範囲: docs/public-private-split.md:163
- [ ] 2.5 「載せない行の基準」に項目「Orca の起動部品の中の行と、起動部品を呼ぶ側で Orca の部品を選んだときの振る舞いを書いた行」を足す（当たる範囲と当たらない例を design の決定 3 のとおりに書く）。触る範囲: docs/public-private-split.md:163-164 の間
- [ ] 2.6 「個人版や保留の部品の中の行」を「個人版の部品の中の行」にし、例を個人版の部品（`plugins/dev-workflow/docs/auto-merge-deployments.md` など）に替える。触る範囲: docs/public-private-split.md:165
- [ ] 2.7 節「起動部品の 1 つとして一覧から外した行」の冒頭の文を、#1129 で `epic-launch-orca.sh` が公開版に確定したので一覧に戻さない、に直す（表は場所の記録として残す）。触る範囲: docs/public-private-split.md:167-170
- [ ] 2.8 文書の冒頭と「固有記述の一覧」の経緯の段落で、保留の扱いに触れている文があれば確定後の文に直す（`grep -n 保留 docs/public-private-split.md` が 2.2 の節の記録の中だけになることを確かめる）。触る範囲: docs/public-private-split.md:1-6、docs/public-private-split.md:140-145

## 3. 公開版に確定した部品の Orca だけを前提にした書き出しを直す

- [ ] 3.1 冒頭の「Orca 経路のエピックで」を「別セッション方式（起動部品は Orca か tmux）のエピックで」に、「develop の SKILL.md の Orca 経路の手順 8」を「develop の SKILL.md の別セッション方式の手順 8」に直す。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:3
- [ ] 3.2 冒頭の「Orca 経路のエピックで」を同じ書き方に直す。触る範囲: plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:3
- [ ] 3.3 5 本を候補語（文書「候補語」の節の語）で `grep -n` し、当たった行がすべて「載せない行の基準」のどれか（Orca の起動部品の中の行・起動部品を並べた行・出典や経緯としてだけ名前を挙げる行）で説明できることを確かめ、判定の表を作業メモとして PR 本文に載せる。説明できない行があれば一覧に載せるか直す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh、plugins/dev-workflow/scripts/epic-launch-orca.sh、plugins/dev-workflow/scripts/stop-judge.sh、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md、plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md（読むだけ。3.1・3.2 以外は編集しない）

## 4. 記録と検証

- [ ] 4.1 変更の記録を書く（確定した 5 行と理由・消した分類の値・足した載せない行の基準・直した 2 行・検査の変更）。触る範囲: plugins/dev-workflow/changes/1129.md（新規）
- [ ] 4.2 `bats tests/public-private-split.bats` が全件通る
- [ ] 4.3 `bash scripts/test.sh` が通る（他の検査に `保留（#1123 の後）` や `parent-pass-criteria.md:3` の文言を固定したものが無いことの確認を兼ねる。落ちたら該当の検査を読んで直す）
- [ ] 4.4 `openspec validate confirm-epic-launch-split-rows --strict` が通る
