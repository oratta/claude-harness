## 1. テストを先に書く（Red）

- [x] 1.1 `plugins/dev-workflow/tests/develop-skill.bats` の「loop: W's second run covers ... PR Ready ...」と「loop: stage 3 splits ...」の (3b) の `Ready` 検査を、(3b) が Draft のまま G に渡すこと（`Draft` を含み、W が Ready に切り替える記述が無いこと）の検査に置き換える。関連するコメント行（PR Ready の二重実行の説明）も直す
- [x] 1.2 `plugins/dev-workflow/tests/develop-roles.bats` に、worker.md の (3b) が Draft のまま G に渡す（issue 記録先なら `gh pr create --draft`）ことと、`gh pr ready` を W の作業として書いていないことの検査を足す
- [x] 1.3 `plugins/dev-workflow/tests/develop-roles.bats` に、gate-runner.md の手順要約に Ready 化（Draft なら）があり、passed の return に Ready 化の結果欄があることの検査を足す
- [x] 1.4 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、手順 5 で `needs-approval` が無いことの確認 → `.draft` の取得 → `gh pr ready` → `agent-review:passed` の POST が行順で並ぶこと、順序の理由（labeled が draft でスキップ・日次まで拾われない）があること、実測確認の表に `draft` の行があることの検査を足す
- [x] 1.5 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、手順 1 の stale passed 除去に `gh pr ready --undo` が「Draft でなければ」の条件付きであり、passed が無かった場合は戻さないことの検査を足す
- [x] 1.6 否定の検査は `!` を先頭に付けず、既存の `refute` などの書き方に合わせる。`bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/develop-roles.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` で新しい検査が落ちることを確認する

## 2. 文書を直す（Green）

- [x] 2.1 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の (3b) の手順 2 を「PR を Draft のまま用意する（記録先が Draft PR ならそのまま。issue が記録先なら `gh pr create --draft`、本文に `Closes #<issue>`。unmanned は従来どおり `agent-review:pending` を付ける）。Ready 化は G が pr-review-gate 手順 5 で行う」に書き換える
- [x] 2.2 `plugins/dev-workflow/skills/develop/SKILL.md` の 1 ループの (3b) を「archive → PR を Draft のまま用意（無ければ Draft で作成）→ 仕様宣言」に、(4) に「合格処理で Draft なら Ready にしてから passed」を書き足す
- [x] 2.3 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の手順 5 に、ラベル一覧の GET → `needs-approval` が無いことの確認 → `.draft` の取得 → 「Draft なら `gh pr ready`」→ passed の POST の行順で置き、順序の理由を 1〜2 文で書く。実測確認の表に `draft` が `false` の行を足す
- [x] 2.4 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の手順 1 の stale passed 除去に、「passed を外したら、PR が Draft でなければ `gh pr ready --undo`」を足す（passed が無ければ戻さない）
- [x] 2.5 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` のやることの手順要約に Ready 化を入れ、passed の return 書式に「Ready 化: 実施した | 対象外（元から非 Draft）」の欄を足す
- [x] 2.6 `grep -n "Ready" plugins/dev-workflow/skills/develop/SKILL.md plugins/dev-workflow/skills/develop/references/roles/worker.md` の出力が、W が Ready にしないこと、または G が手順 5 で行うことを述べる行だけであることを確認する

## 3. バージョンと記録

- [x] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow エントリを同じ値に上げる（着手時点の origin/main の値と並行 PR の割り当てを確認してから決める）。pr-review-gate SKILL.md の frontmatter `version` を上げるかは既存履歴に合わせる
- [x] 3.2 `plugins/dev-workflow/CHANGELOG.md` に項目を足す（順序を issue 本文の「passed → Ready」から「Ready → passed」に変えた理由を含める）

## 4. 検証

- [x] 4.1 `bash scripts/test.sh` を全件実行し、exit code 0 を確認する
- [x] 4.2 `openspec validate develop-pr-draft-until-gate --strict` が通ることを確認する
