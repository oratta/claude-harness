# Tasks

## 1. 聖域の検査を先に足す（red）

- [ ] 1.1 `scripts/test-auto-merge-workflow.sh` の SACRED の must-match に `plugins/dev-workflow/scripts/git-destructive-guard.sh`・`plugins/dev-workflow/scripts/git-guard-scratchpad.py`・`plugins/capability-registry/scripts/secret-guard.py`・`plugins/worktree/scripts/wt-create-hook.sh` を、must-not-match に `plugins/dev-workflow/scripts/ci-watch.sh`・`plugins/dev-workflow/scripts/epic-dispatch.sh` を足す。MERGE_CONDITION の must-not-match に `plugins/dev-workflow/scripts/git-destructive-guard.sh` を足す。冒頭の検査一覧のコメント（(1) の説明）に hooks.json との突き合わせを 1 行足す。検証: `sh scripts/test-auto-merge-workflow.sh` で must-match の 4 件が FAIL（red）になり、ほかは PASS のままであること。触る範囲: scripts/test-auto-merge-workflow.sh:9-12、scripts/test-auto-merge-workflow.sh:86-137（(1) 聖域パス判定）、scripts/test-auto-merge-workflow.sh:170-187（(1-a) の一致してはならないパス）
- [ ] 1.2 同じスクリプトに、全 `$ROOT/plugins/*/hooks/hooks.json` の `"command":` の行から `${CLAUDE_PLUGIN_ROOT}/` に続く相対パスを grep / sed で取り出し、`plugins/<name>/<相対パス>` が `SACRED` に一致するかを確かめる検査を (1-a) の後ろに新しい小節として足す（jq は使わない）。一致しないパス、`${CLAUDE_PLUGIN_ROOT}/` で始まる 1 本のパスとして読めない `command`、hooks.json が 1 つも無い／`command` を 1 件も拾えない場合はそれぞれ `ng`。全件一致なら件数を添えて `ok`。検証: 今の SACRED のままでは 24 本が未一致で FAIL になること（red）。触る範囲: scripts/test-auto-merge-workflow.sh:188-189（(1-a) の終わりと (1-b) の間に新しい小節）
- [ ] 1.3 同じスクリプトの (5) 運用ドキュメントの token に `hooks.json` を足す。触る範囲: scripts/test-auto-merge-workflow.sh:775-789

## 2. 聖域の定義と運用ガイドを直す（green）

- [ ] 2.1 `.github/workflows/auto-merge.yml` の `SACRED` に、プラグインごとに `^plugins/<name>/scripts/(<ファイル名>|...)$` の形で、hooks.json が直接指す 24 本（capability-registry: browser-guard.sh・secret-guard.sh／cost-ledger: backfill.sh・gate-report.sh・ledger-hook.sh／statusline: statusline-update-hook.sh／dev-workflow: session-tripwires.sh・team-mode-warning.sh・develop-compact-reread.sh・prompt-tripwires-refresh.sh・unclear-reply-rephrase.sh・agent-model-guard.sh・context-tripwire.sh・git-destructive-guard.sh・rm-permission-guard.sh・subagent-start-context.sh・subagent-stop-guard.sh・model-switch-recache-notice.sh・owner-message-number-check.sh／worktree: wt-create-hook.sh・wt-setup-guard.sh・session-proc-mark.sh・dev-dir-env-check.sh・session-proc-end.sh）と補助 3 本（dev-workflow: git-guard-scratchpad.py・usage_view.py／capability-registry: secret-guard.py）を足す。編集前に hooks.json から一覧を取り直し、食い違えば hooks.json を正とする。上の説明コメントの claude-harness 固有の聖域の一覧に hook のスクリプトの行を足し、「個別ファイル名を列挙しない」方針の例外であること・hooks.json との突き合わせを CI が検査すること・補助ファイルは手で選び検査が拾わないことを書く。`MERGE_CONDITION` は変えない。検証: `sh scripts/test-auto-merge-workflow.sh` が exit 0（1.1・1.2 の検査が green）。触る範囲: .github/workflows/auto-merge.yml:161-176（`# >>> sacred-paths` とその上のコメント）
- [ ] 2.2 `docs/auto-merge.md` の聖域パスの表に「hooks.json が呼ぶスクリプトと、許可を判定する hook が直接読み込む補助 3 本（ファイル名ちょうど）」の行を足し、表の後ろに hooks.json との突き合わせを CI が検査すること、残る限界（補助ファイルは 1 段だけで手で選ぶので CI は直接呼ばれる分しか拾わない・補助がさらに読み込むものと hook が実行しない親が許可を書くスクリプトは聖域に入らない）を書く。マージ条件の表の後ろの「ほかの聖域」の列挙に hook のスクリプトを足す（親の判断の印で外せる側）。検証: 1.3 の token の検査が PASS。触る範囲: docs/auto-merge.md:103-123（聖域パスの表とその後ろの段落）、docs/auto-merge.md:200-201
- [ ] 2.3 変更の記録を書く（何が聖域に入ったか・CI の検査・残る限界・`MERGE_CONDITION` と原本は変えていないこと・戻し方）。触る範囲: plugins/dev-workflow/changes/1163.md（新規）

## 3. verify

- [ ] 3.1 `sh scripts/test-auto-merge-workflow.sh` と `bats plugins/dev-workflow/tests/automerge-templates.bats` が exit 0。`openspec validate automerge-sacred-hook-scripts --type change --strict` が exit 0。触る範囲: scripts/test-auto-merge-workflow.sh、plugins/dev-workflow/tests/automerge-templates.bats
- [ ] 3.2 漏れの検査が効くことを scratchpad の複製で確かめる: `.github/workflows/`・`docs/auto-merge.md`・`scripts/`・`plugins/*/hooks/` を scratchpad の新しいディレクトリに複製し、どれかの hooks.json に `SACRED` に無いスクリプトを指す `command` を足して `AUTOMERGE_TEST_ROOT=<複製> sh scripts/test-auto-merge-workflow.sh` を実行し、そのパスを挙げて exit 1 になること。同じく `command` を読めない形にしたときも exit 1 になること。複製は git の操作で戻さず、作り直す。触る範囲: scripts/test-auto-merge-workflow.sh（新しい小節）
- [ ] 3.3 差分を読み、`MERGE_CONDITION`・原本 `plugins/dev-workflow/templates/auto-merge/`・hook のスクリプト自体・エピック #1476 の他の子の範囲に変更が無いことを確かめる。`git diff --check` が空。触る範囲: git diff 全体

## Workflow follow-up

- R1 の APPROVE を記録先 issue #1163 で確認してから実装へ進む。この工程は artifact だけを commit・push する。
- finish の工程で delta を archive し、`openspec/specs/dev-workflow-automerge-templates/spec.md` に新しい要件として反映する。既存の要件は書き換えない。
- この PR は `.github/workflows/` を変えるので自動マージの処理が `human-merge` を付け、親の判断でも外れない。W は Ready にしない。
