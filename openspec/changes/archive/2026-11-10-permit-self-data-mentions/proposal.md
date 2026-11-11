# Proposal

## Why

git ガードは、子のコマンド文字列のどこかに許可を書くスクリプトの名前（`git-guard-permit`）があれば、書き方を読み分けずに `permit-self` として拒否し、2 回目で子を打ち切る。git ガードや許可の仕組みを直す作業者（W）は、その名前を grep のパターンに入れたり、名前を含む spec をヒアドキュメントで書いたりする用事があり、#1165・#1163・#1610 の作業でこの拒否に当たって作業を打ち切られた（issue #1166）。エピック #1476（git ガードが偽造を通さず、正当な作業を止めない）の子として、偽造の経路を開かずに、名前を文字列として書くだけのコマンドを通す。

## What Changes

- 子のコマンドを、破壊的 git 操作の判定と同じ字句読みで読み、`$(...)` とバッククォートの中を含むすべての単純コマンドの先頭の語が、読むか表示するだけのコマンドの一覧（`grep`・`egrep`・`fgrep`・`cat`・`head`・`tail`・`wc`・`ls`・`echo`）に入るときは、名前があっても `permit-self` にしない（何も出さずに通す）
- それ以外（一覧に無いコマンドが 1 つでもある・先頭の語にパスや前置きや変数の代入が付く・字句読みで読み切れない）は、今までどおり名前があれば `permit-self` で拒否する。`bash <許可スクリプトのパス>` や直接の実行は今までどおり拒否する
- 拒否したときの回数・拒否の記録・理由文・許可を使わない扱いは変えない（`permit-self` は打ち切りの数え方に含めたまま）
- **BREAKING**（子の振る舞い）: 子が `cat <許可スクリプトのパス>` のように読むだけのコマンドを打っても止まらなくなる（今の spec は読むだけのものも止めると書いている）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 要件「子は許可を書くスクリプトを呼べない」を、名前があれば止める規則から、読むか表示するだけのコマンドだけでできたコマンドは止めない規則に直す（守備範囲とシナリオを含む）

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（`self_permit` の判定と、その判定のための読み分け。字句読みの関数（`join_words`〜`judge`）には触らない）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（`permit-self` の既存テストの `cat` の行の移し替え、文字列としての出現を通すテスト、実行される位置を止め続けるテスト、`cat` で 2 つの置き場所の名前と許可スクリプトの名前を並べたテストのコマンドの差し替え）
- `plugins/dev-workflow/changes/<PR 番号>.md`（変更の記録）
- 親の手順（`skills/develop/SKILL.md`）・許可を書くスクリプト・rm ガード・Write / Edit の hook は変えない
