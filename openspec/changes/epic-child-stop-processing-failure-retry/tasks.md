# Tasks

## 1. 処理失敗の再停止を通し、形式不備の差し戻しを保つ

- [x] 1.1 Stop の処理失敗を状態行の形式不備から分け、真偽値 `stop_hook_active: true` の処理失敗だけ理由・パスを stderr に出して stdout 空・exit 0 で通す。初回の block、入力フックの exit 2、既存ガードの呼び出しと対象外への転送を維持する。`bash -n plugins/dev-workflow/scripts/epic-child-state.sh` と 1.2・1.3 の Bats で検証する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:175-237（fail / block / Stop 結果の合成）、plugins/dev-workflow/scripts/epic-child-state.sh:119-164（Python の処理失敗と形式不備）
- [x] 1.2 入力情報なし・拡張型不正・ログの欠落または不正 JSON・最終発言との対応不明・複数一致・設定不正・予約文の読み取り失敗について、初回 block と再停止を対にした回帰テストを書く。再停止の繰り返しも stdout 空・stderr の理由とパス・exit 0 を分離取得して確認し、`turn_state` の捏造や世代・親項目の破壊がないことを確かめる。未指定・false・文字列 `"true"` が免除されないこと、一般セッションのガード出力が保たれることも含める。`bats plugins/dev-workflow/tests/epic-child-state.bats` を通す。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:19-29（payload / helper）、plugins/dev-workflow/tests/epic-child-state.bats:127-149（処理失敗）、plugins/dev-workflow/tests/epic-child-state.bats:262-293（既存ガードの転送）、plugins/dev-workflow/tests/epic-child-state.bats:295-342（型不正・対応不明）
- [x] 1.3 保存と拒否状態の無効化それぞれで、残存ロック・置き換え失敗の初回 block と再停止許可を試験する。元の JSON・親項目・残存ロックの保持、ロック待ち上限、状態行の欠落・形式不備で無効化成功なら再停止でも block、無効化失敗なら処理失敗を優先して再停止を通すこと、復旧後は同じ世代で保存できること、世代が変わる競合では新入力を保つことを確認する。`bats plugins/dev-workflow/tests/epic-child-state.bats` を通す。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:58-101（形式不備と修正後保存）、plugins/dev-workflow/tests/epic-child-state.bats:211-260（世代競合・原子的置き換え失敗）、plugins/dev-workflow/tests/epic-child-state.bats:384-410（ロック待ち上限）
- [x] 1.4 `plugins/dev-workflow/changes/1754.md` に、処理失敗の再停止許可と stderr 診断、形式不備の継続差し戻しを記録する。版は上げず、差分で記録の存在と記載内容を確認する。触る範囲: plugins/dev-workflow/changes/1754.md（新規）

## Workflow follow-up

- R1 の APPROVE が記録先にあることを確認してから実装段へ進む。
- 実装後のレビューと所定の verify を経て、終了工程でこの change を archive する。main spec の要件名と既存シナリオを保ち、保存・無効化失敗の文と再停止の例外が矛盾しないことを確かめる。
