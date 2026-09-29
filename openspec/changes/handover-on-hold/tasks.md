## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/` の develop の役割の bats に、`skills/develop/SKILL.md` が `引き継ぎ: 主の返事待ち` の書式（1 行目の完全一致・項目名 11 個（ラベルの付け先を含む）・W の名前を書かない）と新しいセッションでの再開手順 6 項目（手渡し不要のときの初回 W の起動を含む）を持つ検査を足す
- [ ] 1.2 同じ bats に、前任 W の手渡し可否・ラベルの付け先・実行先の続け方・守備範囲の段落の検査と、3 つの場面（pr-review-gate の保留・PR トークン上限の exit 2・2 周キャップ超え）が同じ書式を指す検査と、`commands/develop.md` の再開分岐（ラベルの有無によらず引き継ぎがあれば再開手順へ進む）の検査を足す
- [ ] 1.3 pr-review-gate の bats に、`stages/hold.md` 手順 6 の案内があり引き継ぎの項目一覧が無い検査を足す

## 2. 実装（Green）

- [ ] 2.1 `skills/develop/SKILL.md` に引き継ぎのコメントの書式と、保留の行・PR トークン上限 exit 2・2 周キャップ超えからの参照を足す
- [ ] 2.2 `skills/develop/SKILL.md` に新しいセッションでの再開手順を足す
- [ ] 2.3 `commands/develop.md` の引数の解釈に引き継ぎのある記録先の分岐を足す
- [ ] 2.4 `skills/pr-review-gate/stages/hold.md` 手順 6 の依頼文に案内を足す

## 3. 検証

- [ ] 3.1 `./scripts/test.sh` と `./scripts/lint.sh` が exit 0
- [ ] 3.2 `openspec validate handover-on-hold --strict` が exit 0
- [ ] 3.3 `plugins/dev-workflow/changes/515.md` に変更の記録を書く

## 4. 実機の記録（PR 本文・マージ後）

- [ ] 4.1 保留で止めた PR を新しいセッションの `/develop <記録先>` で再開し、ゲートの合格まで進めたことを PR 本文に記録する（受け入れ条件 2）
- [ ] 4.2 `--cap` に小さい値を渡した記録先で本体を止め、引き継ぎのコメントの URL を PR 本文に記録する（受け入れ条件 3）
- [ ] 4.3 マージ後に develop で通した PR 5 本の書き直し代を計測し、エピック #511 にコメントする（受け入れ条件 4。マージ条件にしない）
