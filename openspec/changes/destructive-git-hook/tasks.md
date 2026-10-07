## 1. テストを先に書く

- [ ] 1.1 `plugins/dev-workflow/tests/git-destructive-guard.bats` を新規に作り、spec の各 Scenario（対象 9 種・連結と置換と大域オプション・対象外・モード別の ask / deny・`DEV_WORKFLOW_GIT_GUARD_FORCE`・拒否理由の中身・off・読めない入力・引用符の不整合・hooks.json の登録と `if` が無いこと）を 1 件以上ずつ書く。テスト名は ASCII のみ。payload は `run "$SCRIPT" <<<"$json"` で stdin に渡す。この時点で全件落ちることを確かめる 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（新規）、書き方の手本 plugins/dev-workflow/tests/agent-model-guard.bats:1-40

## 2. hook スクリプト

- [ ] 2.1 `plugins/dev-workflow/scripts/git-destructive-guard.sh` を新規に作る（実行権限付き）。先頭のコメントに理由（規範の正本は `rules/destructive-git-guard.md`、判定はここに一本化、`if` を使わない理由）を書く。`DEV_WORKFLOW_GIT_GUARD=off`・python3 不在で exit 0、stdin を一度読んで `git` の文字列が無ければ python3 を起動せず exit 0、ある場合は python3 に渡して判定する（payload を引数や環境変数に載せない） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）、形の手本 plugins/dev-workflow/scripts/agent-model-guard.sh:1-60
- [ ] 2.2 コマンド文字列の分解（design.md「コマンド文字列の分解」）と 9 種の判定、`permission_mode` による ask / deny、`DEV_WORKFLOW_GIT_GUARD_FORCE`、拒否理由を実装し、1.1 の bats を全件通す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）
- [ ] 2.3 `plugins/dev-workflow/hooks/hooks.json` の PreToolUse に `matcher: "Bash"` のエントリを足し、command を `"\"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh\""` にする（`if` は付けない）。`bash scripts/lint.sh` の `claude plugin validate` が通ることを確かめる 触る範囲: plugins/dev-workflow/hooks/hooks.json:24-43（PreToolUse）

## 3. 実機確認（ask / deny の確定）

- [ ] 3.1 design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の手順で、scratchpad の使い捨てリポジトリを相手に `claude -p --plugin-dir plugins/dev-workflow` を `--dangerously-skip-permissions` 付きと無しの 2 通り走らせ、`DEV_WORKFLOW_GIT_GUARD_FORCE=ask` での結果（出力・書き換えが残ったか）を控える。続けて `FORCE` 無し（既定の対応）でも 2 通り走らせ、どちらも書き換えが残る（止まる）ことを確かめる。結果で判定条件どおりに対応を確定し、変わるなら 2.2 と bats を直す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）、plugins/dev-workflow/tests/git-destructive-guard.bats（新規）
- [ ] 3.2 Claude Code の入力欄の `!` で打った git コマンドが PreToolUse hook を通るかを確かめる（対話セッションが要るなら return の `画面確認:` に載せて主に頼む）。通る（止められる）なら拒否理由から `!` の案内を外し、bats を直す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）、plugins/dev-workflow/tests/git-destructive-guard.bats（新規）

## 4. ルール本文と予算

- [ ] 4.1 `rules/destructive-git-guard.md` に hook との分担（一覧の操作は hook が実行前に止める。止まったら言い換えて再実行せず主に聞く／hook で止まらないもの: push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）を足す。一覧と `tests/always-on-injection-scope.bats` の目印は残し、経緯の括弧書きなど読まれなくても挙動が変わらない文を削って増分を抑える。外した文は PR 本文の移設表に分類を書く（`always-on-injection-scope` の要件） 触る範囲: rules/destructive-git-guard.md:1-21
- [ ] 4.2 `rules/README.md` の destructive-git-guard の行を分担に合わせて直す 触る範囲: rules/README.md:35
- [ ] 4.3 `bats tests/injection-budget.bats` で実測を見て、`tests/injection-budget.txt` を動かす必要があれば実測に合わせて直す。PR 本文に、何を足して何を削ったか・なぜその値か を書く 触る範囲: tests/injection-budget.txt:1

## 5. 記録と全体テスト

- [ ] 5.1 `plugins/dev-workflow/changes/710.md` に変更の記録を書く（何を足したか、ask / deny の確定結果、ルールの一覧を残した理由） 触る範囲: plugins/dev-workflow/changes/710.md（新規）
- [ ] 5.2 `scripts/test.sh` が exit 0（injection-budget と always-on-injection-scope を含む）。`openspec validate destructive-git-hook --strict` が通る 触る範囲: なし（実行のみ）
