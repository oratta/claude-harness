# Proposal

## Why

エピック #1682 の子 #1693 は別 issue #1713 の完了待ちで終わり、依存が解けても `reply --relaunch` が `not-stopped` で送れなかった。#1717 本文と 2026-11-20 のオーナー補足に従い、途中で分かった待ちを既存の依存と再起動へ接続し、待つだけの子セッションを動かし続けない。

## What Changes

- 子が作業途中で見つけた待ちを `dependencies/blocked_by` に登録し、再開に要る状態を issue に残してターンを終える手順を追加する。
- 親の判断は「あとで親から連絡するので待機」を返さず、依存の登録と終了を返す。
- 親の既存の依存再評価（epic-loop.md 手順 4・7）に、既に起動した依存待ちの子は `reply --relaunch --as parent`、未起動の子は `launch` とする接続を加える。
- 既存の再起動操作は維持する。通常の `wait --resolve` で依存待ちの停止が「問いではない」として `resumed` へ消される箇所だけを最小限直す。
- 依存待ちの終了記録・会話ログから依存解消後の再起動までを bats で再現する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 作業途中で判明した依存待ちの子の終了、停止状態の保持、親の依存再評価と既存操作による再起動を定める。

## Impact

実装対象は `epic-child-stop.md`、`parent-pass-criteria.md`、`epic-loop.md`、必要最小限の `epic-dispatch.sh`、既存の `epic-dispatch.bats`。新しい起動サブコマンド、状態 schema、親の依存監視サービスは作らない。主の承認待ち、自分の PR のマージ待ち、CI の既存の停止規則は維持する。仕様以外の実装と変更記録は R1 後の工程で行う。
