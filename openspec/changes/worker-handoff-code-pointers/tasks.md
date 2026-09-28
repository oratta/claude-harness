## 1. テストを先に書く（Red）

- [ ] 1.1 `develop-roles.bats` に worker.md の検査を足す: 「コンテキスト上限と手渡し」の節に `読んだコードの要点`・`20 行`・`ファイル:行` の形・「編集前に該当範囲を自分で読んで確かめる」旨があること／「(3a) の return に書くこと」と「昇格トリップワイヤー」の節に `読んだコードの要点` があること／「仕様化する場合（(1) の終わり）」の節に `触る範囲:` と行番号がずれうる旨があること／仕様化しない場合の段落に `触る範囲:` を return に書く旨があること。触る範囲: plugins/dev-workflow/tests/develop-roles.bats:161-169（既存の「worker: the context cap section ...」の直後に足す。`section()` は 28 行目）
- [ ] 1.2 `handoff-declaration.bats` に decision-criteria.md の検査を足す: `cap_sec` の成果一覧 2 箇所（`工程完了:` の説明と「通知を受けたら」）がどちらも `読んだコードの要点` を含み、`worker.md` を参照し、`20 行` を含まないこと。否定は `!` で書かず `if ...; then return 1; fi` の形にする。触る範囲: plugins/dev-workflow/tests/handoff-declaration.bats:113-130（criteria 系の末尾に足す。`cap_sec` は 31 行目）
- [ ] 1.3 `bats plugins/dev-workflow/tests/develop-roles.bats plugins/dev-workflow/tests/handoff-declaration.bats` で新しい検査だけが落ちることを確かめる。触る範囲: なし（実行のみ）

## 2. worker.md（Green）

- [ ] 2.1 「コンテキスト上限と手渡し」の節の「工程の終わりに必ず return する」の成果一覧に `読んだコードの要点` を足し、書式（1 行 1 件 `<リポジトリ相対パス>:<開始行>-<終了行> — <分かったこと>`、上限 20 行、超えたら次の工程で読む必要が高いものを残す）を書く。「手渡しで起こされたら」の箇条に、前任の要点は読む場所の案内で、編集前に該当範囲を自分で読んで確かめると足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker.md:174-178
- [ ] 2.2 「(3a) の return に書くこと」の「編集したファイルの一覧・…・残作業」の箇条に `読んだコードの要点` を足す（書式は 2.1 の節を指す）。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker.md:118-124
- [ ] 2.3 「昇格トリップワイヤー」の冒頭の成果の列挙に `読んだコードの要点` を足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker.md:161
- [ ] 2.4 「仕様化する場合（(1) の終わり）」に、`tasks.md` の各タスクへ `触る範囲: <パス>:<開始行>-<終了行>`（複数は並べる、新規は `<パス>（新規）`）を書くこと、行番号は着手時点の値で前のタスクの編集でずれうること、実装の担い手は編集前に該当範囲を読むことを足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker.md:85-89
- [ ] 2.5 仕様化判断の節の「仕様化しないと判定した場合は…」の段落に、作業項目ごとの `触る範囲:` を (1) の return に書くことを足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker.md:64

## 3. decision-criteria.md（Green）

- [ ] 3.1 「コンテキスト上限（サブエージェントの手渡し）」の成果一覧 2 箇所に `読んだコードの要点` を足し、W の書式は `references/roles/worker.md`「コンテキスト上限と手渡し」を指す（上限行数は書かない）。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:122、plugins/dev-workflow/skills/develop/references/decision-criteria.md:136

## 4. 記録と検査

- [ ] 4.1 変更の記録を書く（何を変えたか、決定 1〜6 の要点、受け入れたリスク、受け入れ条件 3 は事後計測で子 issue に移すこと）。触る範囲: plugins/dev-workflow/changes/555.md（新規）
- [ ] 4.2 `.github/workflows/*.yml` の `pull_request` / `push` のジョブの `run:` から検査コマンドを集めて全部実行する（少なくとも `./scripts/test.sh` と `./scripts/lint.sh` が exit 0）。触る範囲: .github/workflows/（読むだけ）
- [ ] 4.3 `openspec validate worker-handoff-code-pointers --strict` が exit 0。触る範囲: なし（実行のみ）

## 5. PR 本文に載せる計測（(3b) で行う。本体の手渡しの判断に依存）

- [ ] 5.1 受け入れ条件 2: 本体が (3a) を手渡しで始めた場合、#555 の W のトランスクリプトだけをシンボリックリンクで入れた一時ディレクトリを `--projects` に渡して `plugins/dev-workflow/scripts/subagent-context-audit.sh --by-role --refresh --cache <一時ファイル>` を実行し、`W.reread_pct` と W の件数を PR 本文に書く（編集対象そのものを読むので高く出やすく、合否に使わない旨を添える）。交代が起きなかった場合は「交代なし、事後計測の 1 本目で代える」と書く。触る範囲: なし（実行と PR 本文）
- [ ] 5.2 受け入れ条件 3: エピック #511 の下に「マージ後に develop で通した PR 5 本の `W.reread_pct` を測り #511 にコメントする」子 issue を作り、PR 本文の受け入れ条件 3 の行にその URL を書く（チェックは付けない）。PR は `Closes #555`。触る範囲: なし（issue 作成と PR 本文）
