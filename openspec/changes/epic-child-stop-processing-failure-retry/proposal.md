# Proposal

## Why

別セッション方式の子の Stop フックは、入力情報の欠落・残存ロック・会話ログの読み取り失敗でも再停止のたびに block を返す。子が自分では直せない失敗で停止と差し戻しを繰り返し、無人の子がトークンを消費し続けるおそれを防ぐ（#1754、エピック #1732）。

## What Changes

- 処理失敗による初回 Stop の block は保ち、`stop_hook_active` が JSON の真偽値 `true` の再停止では、失敗理由と記録パスを stderr に出して停止を通す。
- 状態行の欠落・形式不備と処理失敗を分ける。状態行の不備だけで、同じ入力の既存状態の無効化が成功する場合は、従来どおり再停止でも block し続ける。保存・無効化自体が失敗した場合は処理失敗の契約を優先する。
- 状態の保存成功を捏造せず、既存の世代照合・原子的更新・既存 Stop ガードの契約を保つ。
- 初回と再停止の対、形式不備の継続拒否、復旧後の保存を Bats で検証し、変更記録を残す。版は上げない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: 現在ターンを確認できない処理失敗と保存・無効化失敗について、再停止時の診断と停止許可を定める。

## Impact

- `plugins/dev-workflow/scripts/epic-child-state.sh` の失敗経路と Stop の結果合成。
- `plugins/dev-workflow/tests/epic-child-state.bats` の回帰テスト。
- `plugins/dev-workflow/changes/1754.md` の変更記録（実装段で作成）。
- 依存追加、記録 schema の変更、親の状態判定や起動部品の変更はない。
