## 1. テストを先に書く（Red）

- [ ] 1.1 `review-partitions.bats` を新しく作り、`review-partitions.sh` を標準入力のフィクスチャで検査する: 合計ちょうど 600 行で `合計: 600 行`・`区画: なし`・区画の見出し無し／200・150・100・200 行で `区画: 2`、区画 1/2 が先頭 2 ファイル（350 行）・区画 2/2 が残り（300 行）／100・500・100 行で 500 行のファイルが単独の区画・区画数 3／変更行 0 のファイルが今の区画に入る／空入力で `合計: 0 行`・`区画: なし`。触る範囲: plugins/dev-workflow/tests/review-partitions.bats（新規。書き方は plugins/dev-workflow/tests/review-hit-set.bats:1-40 の setup に合わせる）
- [ ] 1.2 `pr-review-gate-skill.bats` に検査を足す: `stages/prepare.md` の 2-0 に `区画` と `600` と `400` と `review-partitions.sh` があり、`レビュー重量:` コメントに区画を載せること、`needs-reviewer` の payload に `区画:` の欄があること／`stages/reviewer-brief.md` のレビュアー向け指示ブロックに `P<k>-`・`区画の対象外:`・区画のファイルの全ハンク・文字どおり `<rev>`・テスト・lint の再実行は区画 1 だけ、があること／`stages/review-run.md` の Task サブエージェントの行に区画ごとに起こすこと、Codex CLI の行（または同じ表の直後）に区画に分けないことがあること。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:765-790（#355 の三表の検査の近く。`reviewer_block` はこのファイルの既存ヘルパー）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:974（末尾に足してもよい）
- [ ] 1.3 `develop-roles.bats` に検査を足す: `gate-runner.md`「一周目の三表を機械照合する」に `区画`・`和集合`・`レビュー重量:` の区画の数を先に確かめること・区画ごとに `review-hit-set.py` に渡すことがあり、補足済み回数を PR で 1 つだけ数えることがあること／「補足レビュー結果の受領」に和集合で再照合することがあること。触る範囲: plugins/dev-workflow/tests/develop-roles.bats:643-700（#355 の検査の直後。`section()` は 29 行目）
- [ ] 1.4 `develop-adapter-review-routing.bats` に検査を足す: SKILL.md の (4) の needs-reviewer に、executor が claude で区画があれば区画ごとに並列に起こすこと・`Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)`・executor が codex なら区画を使わないこと・全区画の要約が揃ってから照合と振り分けの G を 1 体起こすこと・補足は残差のある区画だけ、があること。触る範囲: plugins/dev-workflow/tests/develop-adapter-review-routing.bats:184-198（`step4` ヘルパーを使う #385 の検査の直後）
- [ ] 1.5 `bats` で新しい検査だけが落ちることを確かめる（`review-partitions.bats` はスクリプトが無いので全件落ちる）。触る範囲: なし（実行のみ）

## 2. 区画を計算するスクリプト（Green）

- [ ] 2.1 `review-partitions.sh` を書く（POSIX sh と awk。標準入力の `<追加＋削除>\t<パス>` を読み、design 決定 1 の規則と出力形式で出す。600 行以下は `区画: なし`、それを超えたら 400 行まで詰める、400 行超の 1 ファイルは単独、0 行のファイルは今の区画）。先頭のコメントに入力の作り方（`gh api repos/$R/pulls/$N/files --paginate --jq '.[] | "\(.additions + .deletions)\t\(.filename)"'`）を書く。実行権限を付ける。触る範囲: plugins/dev-workflow/scripts/review-partitions.sh（新規。書き方は plugins/dev-workflow/scripts/risk-carryover-check.sh の冒頭コメントに合わせる）

## 3. pr-review-gate の段のファイル（Green）

- [ ] 3.1 `stages/prepare.md` の 2-0 に「区画の判定（一周目のレビューだけ）」を足す: 600 行を超えたら区画に分けること、区画の決め方（ファイル単位・400 行以下を目安・1 ファイルで超えるものは単独）、`review-partitions.sh` の呼び方、区画に分けるのは Claude のレビュアーだけで Codex には差分全体を渡すこと、結果を `レビュー重量:` コメントの 3 行目以降に載せること（例のコメントも 3 行目以降を足した形にする）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md:47-75（2-0）
- [ ] 3.2 同じ `stages/prepare.md` の「needs-reviewer の return」の payload に `- 区画: <なし | review-partitions.sh の出力の区画の一覧>` の欄を足し、本文に「executor が claude のときだけ区画ごとに起こす（develop の SKILL.md の (4) の ③）」を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md:83-103
- [ ] 3.3 `stages/reviewer-brief.md` のレビュアー向け指示ブロック（`text` ブロックの中）に「区画を渡されたとき」の段落を足す（design 決定 3〜6: 読む範囲、`P<k>-`、`区画の対象外: <受け入れ条件 ID>`、区画のファイルの全ハンク、文字どおり `<rev>`、テスト・lint の再実行は区画 1 だけ）。ブロックの外の入口に、起こす側は区画ごとに 1 体を起こし、固定 HEAD・受け入れ条件の全文・区画の番号と総数・区画のファイル一覧・指示ブロックを渡すことを足す。既存の「すべての受け入れ条件を 1 項目以上で被覆する」「全ハンクを 1 回以上被覆する」は、区画のときは全区画の和集合で満たすと書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:7-9（入口）、plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:19-30（指示ブロックの三表の段落）
- [ ] 3.4 `stages/review-run.md` の従来モードの優先順の表で、Task サブエージェントの行に「差分が 600 行を超えたら `stages/prepare.md` 2-0 の区画ごとに起こす」を足し、表の直後に Codex CLI には区画に分けず差分全体を渡すことと、その理由（150,000 の上限は Claude のサブエージェントの hook の上限で Codex には掛からない。欠けたら G の機械照合が fail-closed で止める）を 1〜2 文で足す。「Codex の呼び出し規約」の exec のレビュー指示の箇条は変えない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md:17-24

## 4. develop（Green）

- [ ] 4.1 `develop/SKILL.md` の (4) の needs-reviewer の ③④ に、executor が claude で payload に区画があれば区画ごとに 1 体ずつ並列に起こす（`description` は `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)`）、executor が codex なら区画を使わず差分全体を 1 つの request に渡す、全区画の要約が揃ってから照合と振り分けの G を 1 体だけ起こして全区画の要約を渡す、補足要求では残差のある区画だけに補足のレビュアーを起こしてその区画の元の三表と残差を渡す、を足す。既存の文（`codex-develop.py request --phase review`、`投稿に成功するまでレビュアーを起動しない`、`executor / model・dispatch 記録のコメント URL を G に渡す`、`Claude の G は照合と振り分けの G を新しく起こし`、`Codex の G は新しい phase gate`）は文字どおり残す（`develop-adapter-review-routing.bats:184-198` が見ている）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:130-140
- [ ] 4.2 `gate-runner.md`「一周目の三表を機械照合する」に、区画に分けたレビューの照合を足す: `レビュー重量:` コメントの区画の数と受け取った三表の区画の数を先に比べて足りない区画を残差にする、受け入れ条件の被覆とハンク被覆は全区画の和集合で集合比較する、各区画の照合表をそれぞれ `review-hit-set.py` に渡す、補足要求では残差のある区画ごとに元の三表と残差を分けて載せ、補足済み回数は PR で 1 つだけ数える。「補足レビュー結果の受領」に、同じ和集合で再照合することを足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:37-49

## 5. 記録と検査

- [ ] 5.1 変更の記録を書く（何を変えたか、design の決定 1〜8 の要点、受け入れたリスク、受け入れ条件 5 は事後計測で子 issue に移すこと）。触る範囲: plugins/dev-workflow/changes/514.md（新規。書き方は plugins/dev-workflow/changes/555.md に合わせる）
- [ ] 5.2 `.github/workflows/*.yml` の `pull_request` / `push` のジョブの `run:` から検査コマンドを集めて全部実行する（少なくとも `./scripts/test.sh` と `./scripts/lint.sh` が exit 0。新しい `review-partitions.sh` も shellcheck の対象になる）。触る範囲: .github/workflows/ci.yml（読むだけ）
- [ ] 5.3 `openspec validate reviewer-diff-partitions --strict` が exit 0。触る範囲: なし（実行のみ）
- [ ] 5.4 受け入れ条件 5（記録だけ）: エピック #511 の下に子 issue を作り、「マージ後に develop で通した PR 5 本で、G とレビュアーのコンテキスト上限による交代の件数と、600 行を超えた PR のレビュアーの最大コンテキストを数え、エピック #511 にコメントする（着手前は差分 600 行超の 1 周目レビュアーの上限超えが 28 体中 20 体・71%。合否に使わず記録する）。数え方は #514 本文の受け入れ条件 5 のとおり」を引き継ぐ。PR 本文の受け入れ条件 5 の行にその URL を書く（チェックは付けない）。PR は `Closes #514`。触る範囲: なし（issue 作成と PR 本文。(3b) で行う）
