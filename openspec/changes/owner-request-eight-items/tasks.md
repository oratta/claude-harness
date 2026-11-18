# Tasks

## 1. 正本と短い版

- [ ] 1.1 `output-styles/readable.md` の節 3 を書き直す: 聞くかどうかの判定（3 つの理由・論点の定義・設計の分かれ目・casting の条件つきの参照）、8 項目と 4 つのまとまりの表、使う場所の表、1 行目の書き分け（題名・`アクション:`・`主がすること: なし`・主の質問への答え）、`ほかの決まり` の段落（1 通 1 件と一覧の扱い・番号は末尾の URL にだけ置く・区切りの下・確かめ済み・論点なしは 4 行）、例 3 つ。節 4 の「節 3 の質問がこの最初の文に当たる」を「節 3 の題名」に直す。触る範囲: output-styles/readable.md:39-94（節 3 と節 4）
- [ ] 1.2 `rules/communication-style.md` の 3 番目を新しい要点に書き直す（見出しの「質問から書いて」も直す）。readable.md の frontmatter の description の「判断依頼は質問から」も直す。触る範囲: rules/communication-style.md:10、output-styles/readable.md:3
- [ ] 1.3 `bats tests/injection-budget.bats` が通ることを確かめる（予算ファイルは動かさない。超えたら止めて返す）。触る範囲: なし（確認のみ）

## 2. 参照先

- [ ] 2.1 `declarations.md` の主への依頼文の説明（「OK すると何が起きるかを中身で書いた質問・…・答え方の 3〜4 行」）を、題名・アクション・論点・推奨の 4 行に直す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/declarations.md:69
- [ ] 2.2 `stages/pass.md` の「2 の手順は型の『答え方』に入れる」を「アクション」に直す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:53

## 3. テストと記録

- [ ] 3.1 `tests/owner-question-style.bats` を新しい要件に合わせる（6 段の検査を 8 項目と表の検査に、`1 行目を質問にし` を題名と `アクション:` に、issue1209 の語の一覧から `OK すると何が起きるかを中身で書いた質問`・`困りごとが無いときは書かない` を外して題名と目的の語を足す、実例の 1・2 行目の形、`OK すると何が起きるか`・`いま困っていること`・`Discord`・`住人` が無いこと）。先にテストを直して落ちることを確かめてから 1.1・1.2 に入る。触る範囲: tests/owner-question-style.bats:46-255
- [ ] 3.2 `bats tests/owner-question-style.bats tests/public-private-split.bats tests/always-on-injection-scope.bats tests/rules-sync.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` を通す。触る範囲: なし（確認のみ）
- [ ] 3.3 変更の記録 `plugins/dev-workflow/changes/1671.md` を書く（3 つの change を 1 つの記録にまとめる）。触る範囲: plugins/dev-workflow/changes/1671.md（新規）
