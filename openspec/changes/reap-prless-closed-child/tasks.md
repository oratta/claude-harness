## 1. テストを先に書く

- [ ] 1.1 git のスタブの `-C` の分岐に `merge-base --is-ancestor` を足す（引数をログに残し、終了コードを `$STUB_CFG/ancestor_exit`（既定 0）から取る）。gh のスタブの `pr list` で、引数に `--state all` があれば `$STUB_CFG/pr_all_out` を出し `$STUB_CFG/pr_all_exit`（既定 0）で終わる分岐を `--search` の分岐の隣に足す（`--state all` が無い呼び出しの動きは変えない）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:173-184（make_stub の git）、plugins/dev-workflow/tests/epic-dispatch.bats:215-224（make_stub の gh の pr list）
- [ ] 1.2 PR の無い子の環境を作る補助（`reap_prless_ready`: `reap_ready` のうえで `pr_out` を空にし、`gh_seq 11 closed`）を `reap_ready` の隣に足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:299-305（reap_ready）
- [ ] 1.3 spec の ADDED 要件「epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける」の 7 つの Scenario を reap のテスト群の末尾に足す（片付ける／main の先端の PR が検索に出ても片付ける／PR がある子は従来の理由／issue が開いている・状態を読めない・`--state all` の失敗／`unmerged-commits` と `git-failed`／`EPIC_DISPATCH_BASE=develop`／マージ済み PR で一致した子には新しい確認を呼ばない）。既存の reap のテスト（`no-merged-pr`・`head-mismatch` を期待するもの）は、issue の状態のスタブが無いと状態が空になり従来の理由が出るので、そのまま通ることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1569-1919（reap のテスト群。末尾は「reap: no children or a non-numeric child is rejected」の後）
- [ ] 1.4 SKILL.md の「ループの終わり」に `unmerged-commits` と片付けの条件があることを確かめるテストを、既存の「skill: the end of a loop never asks about worktree cleanup and marks the workspace last」の隣に足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2029-2055
- [ ] 1.5 `bats plugins/dev-workflow/tests/epic-dispatch.bats` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. reap に PR の無い子の経路を足す

- [ ] 2.1 `cmd_reap` の確認 7 で一致しなかった分岐（`no-merged-pr` / `head-mismatch` を出している箇所）で、従来の理由を変数に取り、HEAD が空でなければ spec の 1〜3（`gh pr list --head <ブランチ> --state all`・`gh api repos/{owner}/{repo}/issues/<N> --jq .state`・`git -C <パス> merge-base --is-ancestor <HEAD> refs/remotes/origin/${EPIC_DISPATCH_BASE:-main}`）を順に確かめる。3 つとも通れば `continue` せずに既存の close → rm → ブランチ削除へ進む。`gh`・`git` 自身の出力は stderr に流す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:738-753（cmd_reap の確認 7）、plugins/dev-workflow/scripts/epic-dispatch.sh:711（local の宣言）
- [ ] 2.2 冒頭のコメントの reap の説明に、PR の無い子の経路と新しい理由（`unmerged-commits`・`issue-lookup-failed`）、`EPIC_DISPATCH_BASE` を読むことを足す。usage の行は変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:92-100（冒頭コメントの reap）
- [ ] 2.3 1 のテストが全部通ることを確かめる

## 3. SKILL.md と変更の記録

- [ ] 3.1 SKILL.md「ループの終わり」の PR を伴わない記録先 issue の項の末尾に、親の `reap` が片付ける条件（そのブランチに PR が無い・issue が閉じている・HEAD が `origin/main` に含まれる）と、commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることを 1 文足す。「エピックの扱い」手順 3 と他の節は触らない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:207（ループの終わり）
- [ ] 3.2 変更の記録を書く（何が変わったか・新しい kept の理由・`state_reason` を見ないこと・戻し方）。触る範囲: plugins/dev-workflow/changes/1045.md（新規）
- [ ] 3.3 `bats plugins/dev-workflow/tests/` と `openspec validate reap-prless-closed-child --type change --strict` を通す
