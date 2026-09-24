## 1. review-hit-set.py の行単位違反を蓄積に変える

- [ ] 1.1 失敗するテストを先に書く（Red）: `plugins/dev-workflow/tests/review-hit-set.bats` に「補助表に複数種類の違反が同時にある」ケースを追加する。既存の単発違反テスト（`a rewritten-rows entry pointing at a fixed row is a contract violation` 等 4 件）と「表の構造エラーは即時停止する」ケース（見出し欠落・列数不一致を含む入力を新規に作る）も追加・確認し、複数違反が 1 回の実行でまとめて `contract:` として report される（出力に複数の `contract:` 行が含まれる）ことを assert する
- [ ] 1.2 `parse_rewritten`（review-hit-set.py:144-166 付近）を、補助表の 3 条件（対応先が扱い「該当しない」の行をちょうど 1 つ指さない・重複・書き換え無し）で即時 `raise ContractError` する代わりに、違反を `violations` リストへ蓄積して全行の検査を続けるよう書き換える。戻り値を `(rewritten, violations)` のタプルに変える
- [ ] 1.3 `main`（review-hit-set.py:297-302 付近）の `--head` 検査ループを、扱い欄の値チェックで即時 `raise ContractError` する代わりに違反を `report` に蓄積し、残りの行の検査を続けるよう書き換える。`parse_rewritten` から返る `violations` も `report` に連結する
- [ ] 1.4 蓄積した違反の出力形式を `contract: <理由>: <path>:<line>` に統一する（既存の `ContractError` のメッセージ文言をそのまま理由として使い、末尾に `<path>:<line>` を付ける）。表の構造エラー（見出し欠落・列数不一致・必須フィールド欠落・SHA 形式不正・検索コマンド構文違反）は `ContractError` の即時 raise・stderr 出力のまま変えない
- [ ] 1.5 テストを通す最小実装にする（Green）。`plugins/dev-workflow/tests/review-hit-set.bats` をこのファイル単体で実行し、全件 pass することを確認する
- [ ] 1.6 リファクタ（Refactor）: `parse_rewritten` と `main` の検査ループの重複があれば整理する。振る舞いは変えない

## 2. 仕様の同期と全体検証

- [ ] 2.1 `openspec/specs/dev-workflow-pr-review-gate/spec.md` に本 change の delta spec（`specs/dev-workflow-pr-review-gate/spec.md`）を反映する（archive 時点で行う。ここでは delta の内容が実装と一致していることだけ確認する）
- [ ] 2.2 `scripts/test.sh` を push 前にフルで実行し、exit code と失敗件数をターン内に表示する
