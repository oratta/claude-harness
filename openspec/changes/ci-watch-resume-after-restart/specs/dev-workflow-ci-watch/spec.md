## ADDED Requirements

### Requirement: 起動し直したセッションは切れた見張りを主の入力なしに next から再開する

`plugins/dev-workflow/references/ci-watch.md` は、セッションが落ちて見張りの待ちが切れたあと、起動し直したセッションがその背景タスクについて `stopped` または `killed` の通知を受けたときの手順を、独立した節として書かなければならない（MUST）。対象は、このセッションの会話で `run_in_background` で起動した `ci-watch.sh wait <owner/repo> <PR番号>`（`--until-merged` 付きも含む）で、通知の task id / tool-use id から会話の中のその起動のコマンドを確かめて PR を特定する。このセッションが自分で TaskStop で止めた待ちの `killed` は対象外とする（MUST）。再開すると決まったら、主やオーナーに再開してよいかを聞かずに同じターンで `ci-watch.sh next <owner/repo> <PR番号>` を `--unrelated` なしで実行し、その出力を 6 の表どおりに処理する（MUST）。

#### Scenario: reference に切れた見張りの再開の節がある
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` を読む
- **THEN** `stopped` と `killed` の通知を受けたときの節があり、対象が自分の会話で起動した `ci-watch.sh wait` であること、TaskStop で自分が止めた待ちは対象外であること、主の入力を待たずに `ci-watch.sh next` を実行することが書かれている

#### Scenario: 起動し直したセッションが主の入力なしに next を実行する
- **WHEN** 見張りの `ci-watch.sh wait` を背景で起動したセッションを、待ちの途中で落として起動し直し、`stopped` または `killed` の通知が届く。PR は open で、`CI 見張り開始:` のあとに `CI 見張り終了:` が無い
- **THEN** そのセッションは主の入力なしに `ci-watch.sh next <owner/repo> <PR番号>` を実行する（実機の再現の手順と実行ログで確かめる）

### Requirement: 決着済みの見張りは起動し直しても再開しない

`references/ci-watch.md` の再開の節は、再開の前に PR の状態とコメントを確かめ、PR が open で、1 行目が `CI 見張り開始:` の最新のコメントのあとに 1 行目が `CI 見張り終了:` のコメントが無いときだけ再開すると書かなければならない（MUST）。終了のコメントがあれば何もしない（MUST NOT 再開）。PR が merged / closed なら再開せず、`CI 見張り終了:` のコメント（終えた理由を 1 行添える）を投稿して、merged ならマージを報告し、closed なら見張りを終える（MUST）。

#### Scenario: 決着済みの判定が書かれている
- **WHEN** reference の再開の節を読む
- **THEN** PR が open で最新の `CI 見張り開始:` のあとに `CI 見張り終了:` が無いときだけ再開し、終了のコメントがあれば何もせず、PR が merged / closed なら `CI 見張り終了:` を投稿して終えることが書かれている

#### Scenario: 起動し直しても決着済みなら next を実行しない
- **WHEN** 見張りの途中で落としたセッションを起動し直す前に、PR に `CI 見張り終了:` のコメントを投稿しておく
- **THEN** 起動し直したセッションは `ci-watch.sh next` を実行しない（実機の再現の手順と実行ログで確かめる）

### Requirement: 起動し直しの再開は同じ見張りの続きとして扱う

`references/ci-watch.md` の再開の節は、自分の会話で始めた見張りの続きなので、2 の開始の判定（ほかのセッションが見張り中かの確認）と `CI 見張り開始:` の投稿をしないと書かなければならない（MUST）。2 の「前のセッションが閉じて終了のコメントが残らなかったとき、オーナーの指示で再開する」規則は、通知を受けていない別のセッションが始める・引き継ぐ場合のものとして残し、2 の中から再開の節を指す（MUST）。

#### Scenario: 再開の節と 2 が書き分けられている
- **WHEN** reference の再開の節と 2 を読む
- **THEN** 再開の節には 2 の開始の判定と `CI 見張り開始:` の投稿をしないことが書かれ、2 には、通知を受けた起動し直しのセッションは再開の節に従うと書かれている

### Requirement: 再開の発火点は reference の手順に置き、develop は節を指すだけにする

切れた見張りの再開は SessionStart hook ではなく `references/ci-watch.md` の手順として置く（MUST）。develop の `SKILL.md` は CI の見張りの行から再開の節を指すだけで、再開の条件や手順を言い換えて再掲しない（MUST）。

#### Scenario: develop の SKILL.md は節を指すだけ
- **WHEN** `plugins/dev-workflow/skills/develop/SKILL.md` の CI の見張りの行を読む
- **THEN** 見張りの背景タスクの `stopped` / `killed` の通知を受けたときは `references/ci-watch.md` の再開の節に従うことが書かれ、`CI 見張り終了:` による決着済みの判定は写されていない
