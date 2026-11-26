## 1. テストを先に書く

- [x] 1.1 git のスタブの `-C` の分岐に `merge-base --is-ancestor` を足す（終了コードを `$STUB_CFG/ancestor_exit`（既定 0）から取る。呼び出しはスタブのログに残る）。`-C` の無い分岐に `ls-remote`（`$STUB_CFG/lsremote_out` を出し、既定は 40 桁の commit ID と `refs/heads/<base>` の 1 行。`$STUB_CFG/lsremote_exit` で終わる）と `cat-file -e`（呼ばれた回数を数え、`$STUB_CFG/catfile_exit_<回数>` があればその値、無ければ `$STUB_CFG/catfile_exit`（既定 0）で終わる）を足す。`fetch` は既存の `fetch_exit` の分岐を使う。gh のスタブの `pr list` で、引数に `--state all` があれば `$STUB_CFG/pr_all_out` を出し `$STUB_CFG/pr_all_exit`（既定 0）で終わる分岐を `--search` の分岐の隣に足す（`--state all` が無い呼び出しの動きは変えない）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:173-184（make_stub の git）、plugins/dev-workflow/tests/epic-dispatch.bats:215-224（make_stub の gh の pr list）
- [x] 1.2 PR の無い子の環境を作る補助（`reap_prless_ready`: `reap_ready` のうえで `pr_out` を空にし、`gh_seq 11 closed`）を `reap_ready` の隣に足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:299-305（reap_ready）
- [x] 1.3 spec の ADDED 要件「epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける」の 10 個の Scenario を reap のテスト群の末尾に足す（片付ける（merge-base の相手が ls-remote の先端で、fetch を呼ばない）／main の先端の PR が検索に出ても片付ける／PR がある子は従来の理由／issue が開いている・状態を読めない・`--state all` の失敗／`unmerged-commits` と `git-failed`／base が巻き戻されていれば残す／base を読めない 4 通りは `base-lookup-failed`／先端が手元に無ければ ls-remote と fetch を 1 回ずつだけ呼ぶ（子 2 件）／`EPIC_DISPATCH_BASE=develop`／マージ済み PR で一致した子には新しい確認を呼ばない）。既存の reap のテスト（`no-merged-pr`・`head-mismatch` を期待するもの）は、issue の状態のスタブが無いと状態が空になり従来の理由が出るので、そのまま通ることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1569-1919（reap のテスト群。末尾は「reap: no children or a non-numeric child is rejected」の後）
- [x] 1.4 SKILL.md の「ループの終わり」に `unmerged-commits` と片付けの条件があることを確かめるテストを、既存の「skill: the end of a loop never asks about worktree cleanup and marks the workspace last」の隣に足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2029-2055
- [x] 1.5 `bats plugins/dev-workflow/tests/epic-dispatch.bats` で、足したテストが落ち、既存のテストが通ることを確かめる

## 2. reap に PR の無い子の経路を足す

- [x] 2.1 `cmd_reap` の確認 7 で一致しなかった分岐（`no-merged-pr` / `head-mismatch` を出している箇所）で、従来の理由を変数に取り、HEAD が空でなければ spec の 1〜5（`gh pr list --head <ブランチ> --state all`・`gh api repos/{owner}/{repo}/issues/<N> --jq .state`・`git ls-remote origin refs/heads/${EPIC_DISPATCH_BASE:-main}`・`git cat-file -e`（無ければ `git fetch origin <base>` のあともう 1 回）・`git -C <パス> merge-base --is-ancestor <HEAD> <base の先端>`）を順に確かめる。ls-remote の結果と fetch を呼んだかは、子のループの外の変数に持って reap 1 回の中で使い回す。手元の追跡参照 `refs/remotes/origin/<base>` は使わない。5 つとも通れば `continue` せずに既存の close → rm → ブランチ削除へ進む。`gh`・`git` 自身の出力は stderr に流す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:738-753（cmd_reap の確認 7）、plugins/dev-workflow/scripts/epic-dispatch.sh:711（local の宣言）
- [x] 2.2 冒頭のコメントの reap の説明に、PR の無い子の経路と新しい理由（`unmerged-commits`・`issue-lookup-failed`・`base-lookup-failed`）、`EPIC_DISPATCH_BASE` を読むこと、判定の相手が ls-remote で取ったリモートの今の先端であることを足す。usage の行は変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:92-100（冒頭コメントの reap）
- [x] 2.3 1 のテストが全部通ることを確かめる

## 3. SKILL.md と変更の記録

- [x] 3.1 SKILL.md「ループの終わり」の PR を伴わない記録先 issue の項の末尾に、親の `reap` が片付ける条件（そのブランチに PR が無い・issue が閉じている・HEAD がリモートの今の main に含まれる）と、commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることを 1 文足す。「エピックの扱い」手順 3 と他の節は触らない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:207（ループの終わり）
- [x] 3.2 変更の記録を書く（何が変わったか・新しい kept の理由・`state_reason` を見ないこと・戻し方）。触る範囲: plugins/dev-workflow/changes/1045.md（新規）
- [x] 3.3 `bats plugins/dev-workflow/tests/` と `openspec validate reap-prless-closed-child --type change --strict` を通す
