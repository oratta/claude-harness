## 1. テストを先に書く

- [x] 1.1 `plugins/dev-workflow/tests/git-destructive-guard.bats` を新規に作り、spec の各 Scenario（対象 9 種・連結と置換と大域オプションとまとめた短いオプション・対象外（dry-run と `-mn` を含む）・モード別の ask / deny・`DEV_WORKFLOW_GIT_GUARD_FORCE`・拒否理由の中身・off・読めない入力・引用符の不整合・hooks.json の登録（末尾が Bash で `if` 無し、先頭は Agent のまま））を 1 件以上ずつ書く。テスト名は ASCII のみ。payload は `run "$SCRIPT" <<<"$json"` で stdin に渡す。この時点で全件落ちることを確かめる 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（新規）、書き方の手本 plugins/dev-workflow/tests/agent-model-guard.bats:1-40

## 2. hook スクリプト

- [x] 2.1 `plugins/dev-workflow/scripts/git-destructive-guard.sh` を新規に作る（実行権限付き）。先頭のコメントに、規範の正本は `rules/destructive-git-guard.md`、判定はここに一本化して `if` を使わない理由、セキュリティ境界ではなくルールを読み飛ばした Claude を止めるのが目的であること（通すことを許す入力の正本は spec の「守備範囲:」）を書く。`DEV_WORKFLOW_GIT_GUARD=off`・python3 不在で exit 0、stdin を一度読んで payload 全体に `git` の文字列が無ければ python3 を起動せず exit 0（`context-tripwire.sh` の早期 exit と同じ形）、ある場合は python3 に渡して判定する（payload を引数や環境変数に載せない） 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）、形の手本 plugins/dev-workflow/scripts/agent-model-guard.sh:1-60、早期 exit の手本 plugins/dev-workflow/scripts/context-tripwire.sh:36-48
- [x] 2.2 コマンド文字列の分解（design.md「コマンド文字列の分解」）と 9 種の判定（dry-run の除外、まとめた短いオプションの扱いを含む）、`permission_mode` による ask / deny、`DEV_WORKFLOW_GIT_GUARD_FORCE`、拒否理由を実装し、1.1 の bats を全件通す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）
- [x] 2.3 `plugins/dev-workflow/hooks/hooks.json` の PreToolUse 配列の**末尾**に `matcher: "Bash"` のエントリを足し、command を `"\"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh\""` にする（`if` は付けない。末尾に足すのは `tripwire-hook.bats` が `PreToolUse[0]` を Agent のエントリと前提にしているため）。`bash scripts/lint.sh` の `claude plugin validate` と `bats plugins/dev-workflow/tests/tripwire-hook.bats` が通ることを確かめる 触る範囲: plugins/dev-workflow/hooks/hooks.json:24-43（PreToolUse）、前提の確認 plugins/dev-workflow/tests/tripwire-hook.bats:243-250

## 3. 実機確認（ask / deny の確定）

- [x] 3.1 design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の手順で、scratchpad の使い捨てリポジトリを相手に `claude -p --plugin-dir plugins/dev-workflow` を走らせる。順序: ①対照実験として `DEV_WORKFLOW_GIT_GUARD=off` で、`--dangerously-skip-permissions` 付きと、`--allowedTools "Bash"` 付き（付けない側）の 2 通りを走らせ、どちらも書き換えが消えることを確かめる（消えなければ頼み方を変えてやり直し、hook の結論を出さない）。②`DEV_WORKFLOW_GIT_GUARD_FORCE=ask` で同じ 2 通り。③`FORCE` 無し（既定の対応）で同じ 2 通りを走らせ、どちらも書き換えが残る（止まる）ことを確かめる。各回の出力と書き換えが残ったかを控え、PR 本文に貼る。結果で判定条件どおりに対応を確定し、変わるならスクリプト・bats・spec.md・design.md を同じ commit で直す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）、plugins/dev-workflow/tests/git-destructive-guard.bats（新規）、openspec/changes/destructive-git-hook/specs/destructive-git-hook/spec.md（要件「確認画面が出るモードでだけ ask を返す」）、openspec/changes/destructive-git-hook/design.md（「`ask` と `deny` は payload の `permission_mode` で切り替える」）
- [ ] 3.2 Claude Code の入力欄の `!` で打った git コマンドが PreToolUse hook を通るかを確かめる（対話セッションが要るなら return の `画面確認:` に載せて主に頼む）。通る（止められる）なら拒否理由とルール本文と wt-clean の案内から `!` を外し、スクリプト・bats・spec.md・design.md を直す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（新規）、plugins/dev-workflow/tests/git-destructive-guard.bats（新規）、openspec/changes/destructive-git-hook/specs/destructive-git-hook/spec.md（要件「拒否理由は承認の取り方を案内する」）、openspec/changes/destructive-git-hook/design.md（「承認済みの操作は主が自分で実行する」）

## 4. ルール本文・wt-clean・予算

- [x] 4.1 `rules/destructive-git-guard.md` に hook との分担を足す（一覧の操作は hook が実行前に止める。止まったら言い換えて再実行せず主に聞き、拒否されたセッションでは承認後も主が自分で実行する／hook で止まらないもの: push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）。既存の文は 1 つも外さず、目印「例外なく事前承認」を含む文は変えない 触る範囲: rules/destructive-git-guard.md:1-21
- [x] 4.2 `rules/README.md` の destructive-git-guard の行を分担に合わせて直す 触る範囲: rules/README.md:35
- [x] 4.3 `plugins/worktree/skills/wt-clean/SKILL.md` に案内を 2 か所足す。①squash 済みのブランチ削除に `git branch -D` を使う規則の段落の直後に、dev-workflow の hook に `git branch -D` を拒否されたら（どの Step でも）言い換えて再実行せず、worktree の削除までで止めてブランチを `HELD` に入れ、完了レポートに主が打つコマンド（`git -C <メインリポ> branch -D <ブランチ>`）を載せること。②cron への載せ方の節に、ジョブの環境に `DEV_WORKFLOW_GIT_GUARD=off` を入れること（入れなければ squash 済みブランチの削除が拒否され、完了レポートの保留に載る）と、このジョブでは hook が全部外れるので、wt-clean の禁則（worktree 内で `git reset --hard` / `git clean -fd` を実行しない）が唯一の歯止めになること。`plugins/worktree/tests/skill-safety.bats` に両方の文面の検査を足す 触る範囲: plugins/worktree/skills/wt-clean/SKILL.md:550（squash 済みの扱い）、plugins/worktree/skills/wt-clean/SKILL.md:1268-1274（cron への載せ方）、plugins/worktree/tests/skill-safety.bats（末尾に追加）
- [x] 4.4 `bats tests/injection-budget.bats` で実測を見て、`tests/injection-budget.txt` を実測に合わせて上げる。PR 本文に増分と理由（hook との分担を書かないと、拒否されたときの言い換え再実行か、hook の穴を知らずに安心するかが起きる。既存の文は移設の手間に見合わないので外していない）を書く 触る範囲: tests/injection-budget.txt:1（実測は変更前 39,291 → 変更後 39,908 バイトで予算 40,260 の内に収まったため、予算ファイルは動かしていない）

## 5. 記録と全体テスト

- [x] 5.1 `plugins/dev-workflow/changes/710.md` に変更の記録を書く（何を足したか、ask / deny の確定結果、ルールの文を外さなかった理由、wt-clean をこの change で扱った理由）。`plugins/worktree/changes/710.md` に wt-clean の案内を足したことを書く 触る範囲: plugins/dev-workflow/changes/710.md（新規）、plugins/worktree/changes/710.md（新規）
- [ ] 5.2 `scripts/test.sh` が exit 0（injection-budget・always-on-injection-scope・tripwire-hook・skill-safety を含む）。`openspec validate destructive-git-hook --strict` が通る 触る範囲: なし（実行のみ）
