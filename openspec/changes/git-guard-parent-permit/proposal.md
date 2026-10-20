## Why

#1108 でサブエージェント（子）の破壊的 git 操作は拒否されて親に返るようになったが、親が代わりに打っても主の確認画面が出るので、子が自分の一時領域（セッションの scratchpad）に作った検証用 repo を戻すだけの操作でも、主が画面を押すまでエピック全体が止まる。オーナーの要望（2026-10-20、エピック #1137）は「本当に止めるべきものは人が許可し、子が自分で作った一時領域の削除・リセットは親が見て許可する」こと。守るものは、一時領域の外への破壊的な操作には親の判断にかかわらず人の許可が要ること（親の判断が誤っても、消えるのは一時領域の中だけに限る）。

## What Changes

- 子への拒否のたびに、hook が「拒否の記録」（session_id・agent_id・cwd・コマンドの全文・当たった種類）を一時ディレクトリに書き、子への拒否理由にその記録のパスを載せる（子は報告に書いて親に渡す）
- 親が使う許可を書くスクリプト `plugins/dev-workflow/scripts/git-guard-permit.sh` を新設する。拒否の記録と理由を受け取り、コマンドが `cd` と `git` だけでできていて、触る repo（作業ツリー・git ディレクトリ・共通の git ディレクトリ）がすべてそのセッションの scratchpad の中にあることを機械的に確かめてから、1 回限り・15 分で切れる許可を書く。確かめられなければ許可を書かずに 0 以外で終わる
- `git-destructive-guard.sh` は、子の呼び出しに session_id・agent_id・cwd・コマンドの全文が一致する期限内の許可があり、かつ使う時点でもスクリプトと同じ一時領域の判定を満たせば、その許可を消費して `allow` を返す。判定は `plugins/dev-workflow/scripts/git-guard-scratchpad.py` の 1 か所に置き、hook とスクリプトの両方が読む（許可ファイルは親の同意だけを担い、一時領域の外へ通さないことは hook が担う）。無ければ今までどおり `deny`。主の呼び出しは今までどおり（許可を見ない）
- 子が許可を書くスクリプトを自分で呼んだら `deny` を返す（子の自己許可を止める）
- 許可を書いたとき、その子への拒否の回数を 0 に戻す（許可のあとの別の拒否は 1 回目として扱い、`continue: false` で打ち切らない）
- 許可を書いたこと・使ったことを一時ディレクトリの記録ファイルに 1 行ずつ残す（何を・どこを・なぜ・いつ）
- **BREAKING（spec の上で）**: 要件「子の定義に検証用 repo の戻し方を書く」の「scratchpad 内の repo への破壊的操作を hook が許可する仕組みを足してはならない」を改める。hook が場所だけを見て通すことは引き続き禁止し、親が書いた許可があるときだけ通す

範囲外: Claude Code 本体の rm の確認画面への親の許可（#1134）、develop の手順書に「拒否されて返った子を親が許可して再開する手順」を書くこと（#1135）、2 回目の拒否で打ち切られた子の空の return の扱い（#1117）。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 子の呼び出しへの判定に「親が書いた許可があれば allow」を足し、拒否の記録・許可を書くスクリプト・一時領域の判定・回数の数え直しを要件にする。子への拒否理由に拒否の記録のパスを足す。scratchpad 内への操作を hook が許可してはならないという禁止を、親の許可を経由する形に改める

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（判定の後ろに許可の照合・拒否の記録・自己許可の拒否を足す）
- `plugins/dev-workflow/scripts/git-guard-permit.sh`（新規）
- `plugins/dev-workflow/scripts/git-guard-scratchpad.py`（新規。一時領域の判定・`<base>` と `<key>`・記録の追記を hook とスクリプトで共用する）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（許可の照合・許可を書けない場合・回数の数え直しのテスト）
- `openspec/specs/destructive-git-hook/spec.md`（archive 時に delta を反映）
- `plugins/dev-workflow/changes/1133.md`（変更の記録）
- hooks.json・rules/destructive-git-guard.md・develop の SKILL.md は変えない（親が許可を書く手順を develop に書くのは #1135）
