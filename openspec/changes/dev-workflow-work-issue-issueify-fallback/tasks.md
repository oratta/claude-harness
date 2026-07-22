## 1. テスト先行（Red）

- [x] 1.1 `plugins/dev-workflow/tests/work-issue-command.bats` を新規作成する。検証項目: (a) work-issue.md に issueify への言及がある (b) 5分岐（番号存在/番号不存在→typo確認/自然文マッチ/マッチなし→issueify/引数なし→新規選択肢）の記述がある (c) fail-soft（`gh issue create` への縮退）の記述がある (d) 複数分割時「着手1件選択」の記述がある (e) 承認ゲートの記述がある (f) plugin.json の version が 1.4.0
- [x] 1.2 `bats plugins/dev-workflow/tests/work-issue-command.bats` を実行し、失敗（Red）を確認する

## 2. 実装（Green)

- [x] 2.1 `plugins/dev-workflow/commands/work-issue.md` の「引数の解釈」を5分岐に拡張し、「issue が特定できない場合（issueify フォールバック）」節を追加する（path-discovery、fail-soft 最小手順、複数分割時の着手1件選択、承認ゲート維持）
- [x] 2.2 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 1.4.0 に上げる
- [x] 2.3 `bats plugins/dev-workflow/tests/work-issue-command.bats` を実行し、全件成功（Green）を確認する

## 3. 検証

- [x] 3.1 `openspec validate dev-workflow-work-issue-issueify-fallback` が exit 0
- [x] 3.2 既存テスト（`bats plugins/dev-workflow/tests/`）に回帰がないことを確認する
