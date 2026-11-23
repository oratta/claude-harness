# Design

## Context

背景と範囲は proposal.md を参照。前提は二つある。

- #1744 の先の change（archive の `epic-wait-recorded-turn-state-1744`）で、親の停止の正本は子の状態記録になった。`epic-dispatch.sh` の jq 述語 `WAIT_TURN_DEFS` の `target` が、有効な組・送り手が owner でない・`value == "主の返事待ち"` を判定し、`detect_stopped`・`wait_received`・`resume_moved`・`stop_to_resumed` と、判断役・判断し直し・声かけ・自動送信の直前の再確認がこれを共有している。
- #1775（PR #1780）で、子の Stop フックが成功した依存待ちの作業報告だけに `turn_state.dependency_wait: true` を保存するようになった（`dev-workflow-epic-state` の「子は検査済みの依存待ちの作業報告だけに依存待ち情報を保存する」「依存待ち情報は終了状態と一緒に無効化し排他更新する」）。新しい通常入力と Stop の差し戻しで、この項目は `turn_state` ごと消える。

現状の親は `target` が作業報告を全部外すので、依存待ちの子を受領しない。`resolve_stopped` には依存待ちの分岐があるが、会話ログから書いた止まりの JSON の `dependency_wait` を見ているため、ログが読めないと判断役へ流れる。`pending-owner` はログが進んだ子を出さない。`deliver_reply` は wait 経由（`expected` 付き）のときだけ受領した組を確かめ、明示的な `reply` は記録の `stop` とログしか見ない。

## Goals / Non-Goals

**Goals:** 依存待ちの停止を状態記録だけで受領し、既存の依存照合（`epic-loop.md` の「依存待ちの照合」）と `reply --relaunch --as parent` の再起動につなぐ。判断役・判断し直し・声かけ・自動の戻しには渡さない。受領後に主が入力した子を古い停止から起こさない。

**Non-Goals:** 子フック・子の終了手順・`dependency_wait` の型と生成条件の変更（#1775 の範囲）。親向け手順書の一般の書き換え（#1760 の範囲）。`reply --as owner` と `stop_turn` の無い記録への新しい制限。依存の登録・解消を自動で確かめる新しい部品。旧フックの子の移行のための自動入力。

## Decisions

### 1. 停止対象の述語を二つの種類に分ける（裁定の 2）

`WAIT_TURN_DEFS` に、共通部分（有効な組・owner でない・status が done でない・summary と時刻の型）を持つ述語と、種類を表す二つの述語を置く。

- `owner_question`: `turn_state.value == "主の返事待ち"`
- `dependency_stop`: `turn_state.value == "作業報告"` かつ `turn_state.dependency_wait == true`（jq の `== true` で、`"true"`・`1`・`null` などは偽）

`target` は共通部分かつ（`owner_question` または `dependency_stop`）とする。受領・二重受領の防止・再開の記録・`wait_received` は `target` のまま共有するので、依存待ちの停止にも同じ世代・セッションの排他更新が掛かる。

親の側で `dependency_wait` を型不正として記録全体を拒むことはしない（`dev-workflow-epic-state` が既存の親用の記録検査に型検査を足すことを禁じている）。boolean の `true` でなければ依存待ちでないとして扱うだけにする。

採らなかった案: 依存待ちを `主の返事待ち` と書かせる案と、親がログやコメントから停止に格上げする案は、裁定で退けられた（返事待ちと混ざり判断役・声かけに流れる／旧ログの補完で owner のターンに介入しうる）。

### 2. 依存待ちの停止は種類で抑止を決め、ログに依存させない

- `resolve_stopped`: `wait_received` で受領した組を得たあと、記録が `dependency_stop` なら判断役を呼ばず 1 を返す（停止を保ったまま `stopped` に残す）。止まりの JSON の有無は見ない。返事待ちの停止に対する既存のマーカーの分岐（止まりの JSON の `dependency_wait`）は残す
- `rejudge_changed`: 受領済みの組が `owner_question` のときだけ判断し直す
- `keepalive_child`: 候補を `owner_question` に限る（判定結果は既存の `skipped not-stopped`）
- `stop_to_resumed` の `expected` 付き（自動判断の「問いではない」の戻し）: 条件に `owner_question` を足す。`resolve_stopped` の早い戻りで通常は届かないが、述語の取り違えへの二重の止めにする。親の明示的な `dismiss` は変えない

種類の判定は記録の `turn_state` だけから行う。

### 3. pending-owner は受領済みで有効な依存待ちをログによらず出す

`cmd_pending_owner` の各子で、`stop` が stopped-seen の記録について、受領した組が今も `target` かつ `dependency_stop` なら（`wait_received` と種類の判定）、`log_moved` を見ずに既存の形で出す。それ以外の子は既存どおり。出力に新しい語を足さない（親は `pending` の子を既存の手順で先に依存照合する）。

採らなかった案: `pending <N> dependency` のような新しい語を足す案。`--help` の固定の語の一覧と親の手順書の両方に波及し、親の照合はコメントと `blocked_by` で行う既存の手順で足りるため採らない。

### 4. reply --as parent の 2 点の再確認（裁定の 4 の deliver_reply）

`deliver_reply` で `as == parent` かつ記録の `stop_turn` が null でないとき、`expected` が渡されていなければ記録の `stop_turn` を `expected` とし、(a) `stop` の確認の直後に `wait_received "$rec" "$expected"`、(b) 既存の起動部品の直前の確認（今は `expected` があるときだけ）を、どちらも通す。通らなければ `skipped <N> not-stopped`（戻り値 2、`cmd_reply` は exit 0）。この確認は状態記録だけを読むので、ログが読めない場合も効く。既存のログによる `log_moved` の確認は、`expected` が無い経路のまま残す（追加の見送り理由であり、この確認の代わりにしない）。

`stop_turn` の無い記録（旧版の受領・未受領の印）と `--as owner` は今の動きを変えない。手動の中継（主の返事）は主の判断で送るもので、裁定の対象が `--as parent` に限られるため。

### 5. 移行条件（裁定の 3）

旧フックの子が残した `dependency_wait` の無い作業報告は、述語 1 で停止対象にならない。親に補完の経路（ログの再読・コメントからの格上げ）を作らない。旧フックの子は、主が手で起こすか、更新済みのフックで次のターンを終えるまで依存待ちとして受け取られない。この移行のために owner の子へ自動で入力しない。

## Risks / Trade-offs

- 旧フックの子の依存待ちは自動では再開されない → 移行期間の取りこぼし。親の手順書の既存の依存照合（コメントと `blocked_by`）と主の判断で拾う。発生は #1775 マージ前に起動した子に限られる
- `reply --as parent` の制限が強まり、受領後に主が入力した子へ親が送れなくなる → 意図した動き。主の入力を古い判断で上書きしないための止めで、送るなら主の手で行う
- 述語の分割で既存の返事待ちの判定を壊すおそれ → 既存の wait / resolve / keepalive / rejudge のテストを全件回して確かめる

## Migration Plan

main に #1775 が入った状態で、この change を #1744 / PR #1769 に実装する。#1769 のマージ前条件は、tasks の必須テストがすべて通ること。戻すときは PR を revert する（子フックの側は #1775 のまま残っても、親が `dependency_wait` を読まないだけで互換）。

## Open Questions

なし
