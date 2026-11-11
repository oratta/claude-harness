# Proposal

## Why

issue #1155 の指摘 2 を確かめた結果、git ガードと rm ガードが拒否の記録・回数・許可を置くフォルダ `<base>`（`${TMPDIR:-/tmp}/dev-workflow-git-guard`）と、その中のファイルを、symlink でも・他人の持ち物でも・誰でも書けるモードでも、確かめずに使っていた。TMPDIR が未設定で `<base>` が `/tmp` の下になる環境では、同じ機械の別のユーザーが `<base>` を先に作るか symlink を置くと、許可を偽造でき（scratchpad の中だけ）、被害者が書けるファイルを上書き・追記させられる（確かめた手順は https://github.com/oratta/claude-harness/issues/1155#issuecomment-6753479349 ）。

## What Changes

- `<base>` と、その下の `denied/`・`permits/` を使う前に、symlink でない・ディレクトリ・自分の uid の持ち物・グループと他者に書き込み権が無い、を確かめる。無ければ所有者だけが使えるモード（0700）で作る
- 確かめられないとき、子の呼び出しには許可を使わず、拒否の記録も回数も書かずに `deny` だけを返す。この `deny` は打ち切りの回数に数えない。理由文には `<base>` を使えなかったことと、その場所・理由を書く
- 主の呼び出しは今までどおり `<base>` を見ない（作りも確かめもしない）。`<base>` の状態で `ask` / `deny` は変わらない
- 許可を書くスクリプトは、記録の場所から求めた `<base>` を同じ規則で確かめ、満たさなければ許可を書かずに 0 以外で終わる（親は今までどおりオーナーに上げる）
- `<base>` の中のファイル（回数・拒否の記録・許可・`permit-log.jsonl`・一時ファイル）は symlink を辿らずに開き、新しく作るものは予測できない名前で排他的に、所有者だけが読めるモードで作る
- 判定のファイル（`git-guard-scratchpad.py`）を読めないときは、git ガードは `<base>` を確かめられないので、子の拒否を回数に数えない（今までは数えていた）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: `<base>` を確かめてから使う要件を足し、要件「同じ子への拒否の繰り返しを打ち切る」と「子への拒否を記録し、親が 1 回だけ通せるようにする」の回数を数える条件を直す
- `rm-permission-hook`: rm ガードも同じ規則で `<base>` を確かめてから使う要件を足す

## Impact

- `plugins/dev-workflow/scripts/git-guard-scratchpad.py`（`<base>` を確かめる処理と、ファイルの開き方を 1 か所に置く）
- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（回数・記録・許可の扱い）
- `plugins/dev-workflow/scripts/rm-permission-guard.sh`（記録・許可の扱い）
- `plugins/dev-workflow/scripts/git-guard-permit.sh`（許可を書く前の確かめ）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`・`plugins/dev-workflow/tests/rm-permission-guard.bats`
- hook が実行するスクリプトを変えるので、PR は自動マージに乗せず主のマージ待ちにする（エピック #1476 の注意書き）
- 同じ uid の子が `permits/` に書く形（指摘 1）はこの change の範囲外（別の change で扱う）
