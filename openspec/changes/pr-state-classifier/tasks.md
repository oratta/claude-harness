## 1. 事実の確認

- [ ] 1.1 Actions のジョブ ID とチェックラン ID が同じかを実物で確かめる: 落ちたチェックのある既存 PR（oratta/claude-harness か genetta-inc/flatmate）で `gh pr view --json statusCheckRollup` の `detailsUrl` の `/job/<id>` を取り、`gh api repos/<o>/<r>/check-runs/<id>` が同じジョブのチェックランを返すこと・`.../annotations` が取れることを確かめる。違っていたら design.md の Risks の代替（`actions/jobs/<id>` の `check_run_url` 経由）に切り替え、design.md に結果を書く

## 2. テストを先に書く（Red）

- [ ] 2.1 `plugins/dev-workflow/tests/pr-state.bats` を新設し、`observe` の分類のケースを flatmate の `scripts/test-pending-pr-merge-wait.sh` (K)(N) から移す（コンフリクト・実行中・URL の無い未確定・成功と中立・失敗の名前と run ID・Actions 以外の失敗・知らない結論・名前のタブ改行カンマ・読めない入力）。flatmate のケースの移し方は次のとおり（受け入れ条件 1 の「全部通る」はこの対応で読む）:
  - 期待値をそのまま移す: K2〜K5（コンフリクト・失敗・未確定・成功と中立の分類）、Na1〜Na3（コンフリクトで fix、同じ状態の 2 回目は none で fixes 1 のまま）、Nb1・Nb2（実行中と URL の無い未確定は wait）、Nc1〜Nc3（ready）、Nd1〜Nd3（HEAD を変えて fix → fix → escalate → none）、Ng1（Actions 以外の失敗は rerun せず fix）、Nj1・Nj2（state と head を消した状態で同じ HEAD がまた止まれば fix で fixes 2）、Nl1〜Nl3（2 回失敗後の 3 回目は escalate、4 回目は none）
  - 期待値を変えて移す: Ne1（手がかりの無い Actions の失敗の 1 回目は rerun → fix）、Ne2（同じ HEAD の 2 回目は fix → none。同じ観測で通信切れの手がかりを付けたケースを別に置き、rerun → fix を確かめる）、Nf1・Nf2 の decide 部分（手がかり無しの 1 回目は rerun → fix。再実行の失敗の扱いは呼び出し側なので移さない）
  - 移さない（呼び出し側の責務）: A〜J・L・M（あなた待ち・ミラー・DB・ロック）、Nd4・Nd5（閉じた PR の状態の消去）、Nh・Ni（gh の認証切れと失敗）、Nj3・Nj4（走査対象と done の検証）、Nk1（LLM を呼ばない）
- [ ] 2.2 `observe` の仕分けのケースを足す（通信切れの annotation・`--unrelated`・本当の失敗が混ざる・同名チェックの通信切れを別のジョブに移さない・手がかりなし・run ID なし・`--hints` が読めない）
- [ ] 2.3 `decide` のケースを足す（同じ HEAD で 2 回落ちてもやり直しは 1 回・HEAD が変わればやり直しの権利が戻り fixes は戻らない・ci-fail で HEAD を変えて直す 2 回と 3 回目の escalate・直す 2 回と 3 回目の escalate とその後の none・同じ状態の再観測・flatmate#899 の再現・HEAD が変わったあとの wait・状態名と HEAD を消した状態・知らないキーの引き継ぎ・ready・読めない前回の状態）
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
