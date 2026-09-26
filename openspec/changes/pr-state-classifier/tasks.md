## 1. 事実の確認

- [ ] 1.1 Actions のジョブ ID とチェックラン ID が同じかを実物で確かめる: 落ちたチェックのある既存 PR（oratta/claude-harness か genetta-inc/flatmate）で `gh pr view --json statusCheckRollup` の `detailsUrl` の `/job/<id>` を取り、`gh api repos/<o>/<r>/check-runs/<id>` が同じジョブのチェックランを返すこと・`.../annotations` が取れることを確かめる。違っていたら design.md の Risks の代替（`actions/jobs/<id>` の `check_run_url` 経由）に切り替え、design.md に結果を書く

## 2. テストを先に書く（Red）

- [ ] 2.1 `plugins/dev-workflow/tests/pr-state.bats` を新設し、`observe` の分類のケースを flatmate の `scripts/test-pending-pr-merge-wait.sh` (K)(N) から移す（コンフリクト・実行中・URL の無い未確定・成功と中立・失敗の名前と run ID・Actions 以外の失敗・知らない結論・名前のタブ改行カンマ・読めない入力）
- [ ] 2.2 `observe` の仕分けのケースを足す（通信切れの annotation・`--unrelated`・本当の失敗が混ざる・手がかりなし・run ID なし・`--hints` が読めない）
- [ ] 2.3 `decide` のケースを足す（同じ HEAD で 2 回落ちてもやり直しは 1 回・HEAD が変わればやり直しの権利が戻る・直す 2 回と 3 回目の escalate とその後の none・同じ状態の再観測・flatmate#899 の再現・HEAD が変わったあとの wait・状態名と HEAD を消した状態・知らないキーの引き継ぎ・ready・読めない前回の状態）
- [ ] 2.4 `annotations` のケースを PATH 先頭の `gh` の偽物で足す（落ちたジョブだけ呼ぶ・1 件の失敗で止まらない・落ちたチェックが無ければ呼ばない・出力を `observe --hints` に渡せる）。`observe` / `decide` のケースでは `gh` の偽物が呼ばれないことも確かめる
- [ ] 2.5 `bats plugins/dev-workflow/tests/pr-state.bats` で新しいテストが落ちることを確かめる

## 3. 実装（Green）

- [ ] 3.1 `plugins/dev-workflow/scripts/pr-state.sh` を新設する。jq の定義（`verdict` / `observe` / `decide`）を 1 つの文字列に置き、`observe` / `decide` / `annotations` のサブコマンドで包む。通信切れの文言は定数 1 か所に置く。先頭コメントに呼び出し方（design.md の 3 行の例）・入出力・状態のキー・一手の名前を書く
- [ ] 3.2 `bats plugins/dev-workflow/tests/pr-state.bats` が全件通ることを確かめる

## 4. 記録と全体の確認

- [ ] 4.1 `plugins/dev-workflow/changes/521.md` に変更記録を書く（既存の changes/ の書式。flatmate の pr-watch から見て変わる 2 点＝手がかりの無い失敗はやり直さない・一手の名前、を含める）
- [ ] 4.2 `scripts/test.sh` を全件フォアグラウンドで流して通ることを確かめる（`statusline-multi-account.bats` の単発失敗は単独再実行で判定）
- [ ] 4.3 `scripts/lint.sh` が exit 0 になることを確かめる
- [ ] 4.4 `openspec validate pr-state-classifier --strict` が通ることを確かめる
