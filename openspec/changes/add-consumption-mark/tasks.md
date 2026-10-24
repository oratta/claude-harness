## 1. SKILL.md に印の規約を書く

- [ ] 1.1 「PR トークン上限」節に、印の形・工程名の語彙（1 か所で列挙）・試行と引継ぎの数え方・アカウントの書き方・時刻を書かないことを書く。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:215-221`（「紐付けの規約」の前）
- [ ] 1.2 「紐付けの規約」に、description の `#N` と同じ文字列の中へ印を入れることを足す。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:219`
- [ ] 1.3 「Codex の消費の記録」に、コメントの 2 行目に印を書くことを足す（1 行目の形は不変。G の full レビュー分は工程 `impl-review`。G 自身の `gate-<段>` は本体が起こした段（G の名前）から決め、Gate Result の `段:` は使わない。G の試行は段をやり直した回数で名前の `<n>`（起動回数）ではない。手渡しは試行を変えず `引継ぎ=` を増やす）。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:221`
- [ ] 1.5 再開される W の扱いを書く: description の印は `アカウント=`（と `引継ぎ=`）だけで `工程=` `試行=` を書かず、再開のたびに指示文の先頭へその再開の工程・試行の印を 1 行置く。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:95-205`（1 ループの W の spawn と再開の指示）、`:219`
- [ ] 1.4 「Role profile の選択」節の develop 開始コメントの記述に、起動アカウントの印（`工程=` `試行=` は省いてよい）を足す。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:22`

## 2. 検査

- [ ] 2.1 印の形・置き場 3 か所・工程名 11 語・時刻を書かないこと・再開される W の description に `工程=` `試行=` を書かず再開の指示文の先頭に印を置くこと・G の工程を名前の段から決めること・G が要求したレビュアーを `impl-review` とすること・G の試行は名前の `<n>` でなく手渡しで増やさないことを検査する bats を足す。触る範囲: `plugins/dev-workflow/tests/develop-skill.bats`（「token budget:」の既存テスト 555 行付近の後）
- [ ] 2.2 `scripts/test.sh` が exit 0 であることを確かめる

## 3. 実機確認（マージ前）

- [ ] 3.1 `claude --plugin-dir <この worktree の plugins/dev-workflow>` で、小さな検証用 issue を記録先に develop を 1 回回し、flatmate の `scripts/burn_consumption.py <記録先>`（flatmate main に入っている）の出力に `stage`・`attempt`・`account` が欠測でない行が 1 行以上あることを確かめ、結果を PR の動作確認ポイントと #1158 に書く。既定の W の行は工程・試行が欠測になるのが正しい。確認できない事情があるときだけ、理由と実行する人・時期を PR 本文に書いて後ろ倒しにする

## 4. 変更の記録

- [ ] 4.1 `plugins/dev-workflow/changes/1158.md` を書く（時刻を範囲外にした理由と後続、実機確認の扱いと、再開される W の工程・試行が欠測になることを含む）。触る範囲: `plugins/dev-workflow/changes/1158.md`（新規）
