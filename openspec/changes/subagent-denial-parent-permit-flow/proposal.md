## Why

#1133 で、親が子の拒否されたコマンドを 1 回だけ通す許可を書く仕組み（`git-guard-permit.sh`・拒否の記録・一時領域の判定）が入ったが、develop の本体の手順には「拒否の報告を受けたとき何を確かめ、いつ許可を書き、どう再開し、どこから先をオーナーに上げるか」が無い。仕組みがあっても本体が使わなければ、子が自分の scratchpad に作った検証用 repo を戻すだけの操作でもオーナーが画面を押すまでエピックが止まる（エピック #1137）。また、子が拒否されて返す報告に何を書かせるかが「何を・なぜ」としか決まっておらず、本体が許可を書くか決める材料（対象のパス・自分で作ったか）が報告に載らないことがある。

守るもの: 一時領域の外への破壊的な操作と、子が作ったと確かめられないものへの操作は、親の判断にかかわらずオーナーが決める。守らないもの: 親が判断を誤って、一時領域の中の別のファイルを戻させること（#1133 と同じ線）。

## What Changes

- 子への拒否理由（hook の文面）が求める報告を、4 項目に決める: 打ちたかったコマンドの全文／対象のパス／その対象を自分で作ったか（作ったなら作ったコマンド）／なぜ要るか。拒否の記録のパスは今までどおり載せる
- `agents/reviewer.md`・`worker.md`・`gate-runner.md` の本文に、拒否されたら報告に同じ 4 項目を書くことを足す（戻し方「作り直す」は残す）
- develop の SKILL.md の「W が `(Subagent completed but returned no output.)` だけを返したとき」の段落（#1117）を、拒否の報告の扱いまで含む形に直す。報告を求めるときの項目を 4 項目にそろえ、「打ち切られたら同じ指示で起こし直さず主に上げる」に、許可を書いて再開する分岐を足す
- SKILL.md に、拒否の報告を受けた本体の手順を足す。許可を書くのは、対象が自分のセッションの scratchpad の中にあり、その W が自分で作ったと作った手順つきで報告し、要る理由が検証用 repo を戻すことに収まるときだけ。書けたら同じ W を SendMessage で再開し、書けなかった・条件を満たさない・再開後に同じ拒否が再び来たときはオーナーに上げる。再開しない役（R1・G・レビュアー）の拒否の報告は、許可が子の `agent_id` に結び付いて使えないので、オーナーに上げる
- 文面の bats（SKILL.md の段落・agents の定義・hook の拒否理由）を足す
- 実機確認（実装段）: W に scratchpad の検証用 repo を `git checkout --` で戻させ、拒否 → 親が許可 → 再開で実行されるまでを、人が確認画面を押さずに通ることを確かめて PR に記録する

範囲外: 許可の仕組みそのもの（#1133。作り直さない）、Claude Code 本体の rm の確認画面への親の許可（#1134）、`rules/destructive-git-guard.md` の変更。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 子への拒否理由の報告項目を 4 項目に決める。子の定義（3 つの agents）に同じ報告の書き方を足す
- `dev-workflow-develop`: 空の return の要件に、報告の 4 項目と、許可を書いて再開する分岐を足す。拒否の報告を受けた本体の手順（許可を書く条件・再開・オーナーに上げる条件・再開しない役）を新しい要件にする

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（#1117 の段落の改訂と、拒否の報告の手順）
- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（子への理由文のうち報告項目の文）
- `plugins/dev-workflow/agents/reviewer.md`・`worker.md`・`gate-runner.md`
- `plugins/dev-workflow/tests/develop-skill.bats`・`git-destructive-guard.bats`
- `openspec/specs/destructive-git-hook/spec.md`・`openspec/specs/dev-workflow-develop/spec.md`（archive 時に delta を反映）
- `plugins/dev-workflow/changes/1135.md`（変更の記録）
