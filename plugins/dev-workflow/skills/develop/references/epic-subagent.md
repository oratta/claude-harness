# サブエージェント方式（develop）

route=subagent・unmanned・channelの親が子を起こすときに読む。先に `references/epic-loop.md` の「エピックである子を外す」と「主への報告」を読む。いつでも使える。kept 後に消す本体 worktree は無い。別方式なので状態を記録しない。`launch`・`mark`・`adopt`・`clear` を呼ばず、エピックの状態ディレクトリを作らない。PR トークン上限を親の権限に照らすときだけ `references/epic-stop.md`「PR トークン上限の子」を読む。

**サブエージェント方式**: 別のリポジトリの子は W に渡さない（W は親のリポジトリに worktree を作るので、別のリポジトリの issue を親のリポジトリの PR として実装してしまう）。エピックに `子 <owner>/<repo>#N は別のリポジトリなので別セッション方式でだけ起動する` と 1 行コメントし、その子と、その子を前提にする子を起こさずに、主に報告する。以下は同じリポジトリの子の手順。blocked されていない子から**SKILL.md の「1 ループ」を子ごとに並列**で起こす。worktree は子ごとで、本体が W を `isolation: "worktree"` で spawn して用意する（W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメント（`子 #N マージ → 残り k 件`）し、依存が解けた子を次に起こす。同時に動く W の数は別セッション方式と同じ上限で抑える。枠の占有・返却・手渡し・再開優先順は、起動や再開の前に `references/epic-worker-slots.md` を読んで従う。
