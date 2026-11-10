# Proposal

## Why

issue #1155 の指摘 1 を確かめた結果、子のサブエージェントは、拒否の記録の 4 つの値（`session_id`・`agent_id`・`cwd`・`command`）に期限を足したものを `<base>/permits/<key>.json`（`<base>` は `${TMPDIR:-/tmp}/dev-workflow-git-guard`）に自分で書くだけで、親の同意を経ずに破壊的 git 操作のガードを抜けられた（通るのは使う時点の一時領域の判定を満たす scratchpad の中の repo への操作だけ。確かめた手順は https://github.com/oratta/claude-harness/issues/1155#issuecomment-6753478890 ）。今の hook は Bash のコマンドの中の書き込みを見ず、Write / Edit ツールの書き込みは見もしない。主は、分かりやすい 2 つの書き方だけを止め、残りは通ると仕様に書く、と決めた（https://github.com/oratta/claude-harness/issues/1155#issuecomment-6759579861 ）。

## What Changes

- 子が Write / Edit / NotebookEdit ツールで `<base>` の中（パスの部品に `dev-workflow-git-guard` を含む場所）にファイルを書こうとしたら、新しい PreToolUse hook が `deny` を返す。主の呼び出しは止めない
- 子の Bash のコマンド文字列に `dev-workflow-git-guard` と `permits` の両方が含まれていたら、git ガードが書き方を読み分けずに `deny` を返す（当たった種類は「許可の置き場所を名指しするコマンド」）。主の呼び出しは止めない
- この 2 つの拒否は、子への拒否の回数に数えない（打ち切りの対象にしない）。拒否の記録も書かず、置かれた許可も使わない（同じコマンドに破壊的 git 操作か許可を書くスクリプトの名前もあるときは、そちらの分として今までどおり数える）
- 残りの偽造（変数で組み立てたパス、スクリプトファイルの中から書くもの、`permits` の名前を書かずに置き場所へ移ってから書くもの、Write / Edit / NotebookEdit 以外のツール）は通ると、spec の守備範囲に書く
- 子が読めない秘密で許可に印（HMAC）を付ける案は、子・hook・親が同じ uid で動くので使えない、と design に書く

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 要件「子は許可の置き場所に書けない（分かりやすい 2 つの書き方）」を足し、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」と「子は許可を書くスクリプトを呼べない」の守備範囲の、`permits/` に直接書いた許可を通すことを許す文を直す

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（Bash の 2 つの名前の判定・回数と記録と許可の扱い・子への理由文）
- `plugins/dev-workflow/scripts/git-guard-base-write-guard.sh`（新規。Write / Edit / NotebookEdit の hook）
- `plugins/dev-workflow/hooks/hooks.json`（新しい hook の配線。git ガードの Bash のエントリは PreToolUse の末尾のまま）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`、`plugins/dev-workflow/tests/git-guard-base-write-guard.bats`（新規）、`plugins/dev-workflow/tests/hook-python-invocation.bats`（新しい hook が python3 を呼ぶなら）
- 親の手順（`skills/develop/SKILL.md` の許可の書き方）と、許可を書くスクリプト・rm ガードは変えない
