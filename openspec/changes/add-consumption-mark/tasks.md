## 1. SKILL.md に印の規約を書く

- [ ] 1.1 「PR トークン上限」節に、印の形・工程名の語彙（1 か所で列挙）・試行と引継ぎの数え方・アカウントの書き方・時刻を書かないことを書く。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:215-221`（「紐付けの規約」の前）
- [ ] 1.2 「紐付けの規約」に、description の `#N` と同じ文字列の中へ印を入れることを足す。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:219`
- [ ] 1.3 「Codex の消費の記録」に、コメントの 2 行目に印を書くことを足す（1 行目の形は不変。G の full レビュー分は G の return の工程を使う）。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:221`
- [ ] 1.4 「Role profile の選択」節の develop 開始コメントの記述に、起動アカウントの印（`工程=` `試行=` は省いてよい）を足す。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:22`

## 2. 検査

- [ ] 2.1 印の形・置き場 3 か所・工程名 11 語・時刻を書かないことを検査する bats を足す。触る範囲: `plugins/dev-workflow/tests/develop-skill.bats`（「token budget:」の既存テスト 555 行付近の後）
- [ ] 2.2 `scripts/test.sh` が exit 0 であることを確かめる

## 3. 変更の記録

- [ ] 3.1 `plugins/dev-workflow/changes/1158.md` を書く（時刻を範囲外にした理由と後続、マージ後の確認の扱いを含む）。触る範囲: `plugins/dev-workflow/changes/1158.md`（新規）
