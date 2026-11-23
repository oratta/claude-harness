## MODIFIED Requirements

### Requirement: wait は子の状態の記録だけで止まった子を検知する

`wait --watch-stopped` は、閉じていない位置引数の子で `status != done` の記録について、`dev-workflow-epic-state` の「有効な終了状態は入力との世代とセッションの一致で決まる」を満たし、`turn_input.sender` が `parent` または `startup` で、次のどちらかに当たるときだけ停止の対象にしなければならない（MUST）。①`turn_state.value` が `主の返事待ち`（以下、返事待ちの停止）。②`turn_state.value` が `作業報告` で、かつ `turn_state.dependency_wait` が JSON の `true`（以下、依存待ちの停止。項目の生成条件と型は `dev-workflow-epic-state` の「終了状態は3値と中身と保存時刻を同じ世代で持つ」（任意の boolean の型）・「子は検査済みの依存待ちの作業報告だけに依存待ち情報を保存する」・「依存待ち情報は終了状態と一緒に無効化し排他更新する」に従い、ここでは規定し直さない）。欠落・null・型不正・不一致・owner・通常の作業報告（`dependency_wait` が無い、`false`、または boolean でない）・完了は対象外とする（MUST）。`turn_state` に `dependency_wait` が存在して boolean でない記録は、value が `主の返事待ち` でも対象外とする（MUST）。記録全体を読めるかの既存の親用の記録検査はこの型を見ず、ここでの除外は停止対象として有効かの判定だけで行う。`dependency_wait` の欠落と `false` は返事待ちの停止を妨げない（MUST NOT）。`dependency_wait` の欠落を依存待ちの証拠にしてはならない（MUST NOT）。印、会話ログ、依存待ちのマーカー、停止コメント、質問ツール、経過時間から対象に格上げしてはならない（MUST NOT）。この条件は既存の印・ログ・依存待ちによる停止規定に優先する。owner のターンの返事待ちを時間で主に知らせる `owner-away` は停止の対象ではなく、`dev-workflow-epic-state` の「主が打った返事待ちは時間がたったら親が主に知らせる」に従う（`stopped` は返さない）。

判定の守備範囲は要件「wait の状態記録による判定の守備範囲を限る」に従う。

#### Scenario: 親の入力または起動指示から始まった返事待ちを返す
- **WHEN** 子 11 が open、status が running で、型・世代・セッションが正しい組の sender が parent または startup、value が主の返事待ちであり、まだ受けていない状態で `wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stop を stopped-seen に記録し、stdout は `stopped 11`、exit 0 となる。会話ログの終端やアイドル時間は検知条件にしない

#### Scenario: 親の入力から始まった依存待ちの作業報告を返す
- **WHEN** 子 11 が open、status が running で、型・世代・セッションが正しい組の sender が parent または startup、value が作業報告、`dependency_wait` が `true` であり、まだ受けていない状態で `wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stop を stopped-seen に記録して受領した組を残し、stdout は `stopped 11`、exit 0 となる。会話ログが無い・読めない場合も同じである

#### Scenario: 返事待ちは dependency_wait の欠落と false で通す
- **WHEN** 子 11 が open、status が running で、型・世代・セッションが正しい組の sender が parent、value が主の返事待ちであり、`dependency_wait` が欠落または `false` で、まだ受けていない状態で `wait --interval 0 --timeout 0 --watch-stopped 11` を実行する（`--resolve` なし）
- **THEN** stop を stopped-seen に記録し、stdout は `stopped 11`、exit 0 となる

#### Scenario: 返事待ちでも dependency_wait が boolean でなければ除外する
- **WHEN** 子 11 が open、status が running で、型・世代・セッションが正しい組の sender が parent、value が主の返事待ちであり、`dependency_wait` が `"true"`・`1`・`null`・配列・オブジェクトのいずれかで、まだ受けていない状態で `wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11` を実行する
- **THEN** 記録は読めるが停止対象にせず、stdout に `stopped 11` は出ず、判断役・子への送信・端末終了・再起動を呼ばない

#### Scenario: 主が子のタブで話しているターンには介入しない
- **WHEN** sender が owner の有効な組で、value が主の返事待ちまたは作業報告であり（作業報告には `dependency_wait: true` と依存待ちのマーカーを持つものを含む。主の返事待ちは `turn_state.recorded_at` が `EPIC_DISPATCH_OWNER_AWAY_SEC` の既定 3600 秒に満たない）、会話量が 150,001 トークン、最後の活動が 3600 秒以上前で、古い stopped または stopped-seen の印も残る状態で `wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11` を実行する
- **THEN** stdout に `stopped 11` は出ず、判断役・子への送信・orca terminal close・再起動を呼ばない。子 11 が open の単発確認は、既存どおり stdout `timeout 11`、exit 2 で終わる。

#### Scenario: 閾値を過ぎた主の返事待ちは stopped ではなく owner-away を返す
- **WHEN** 上の owner の返事待ちの `recorded_at` が既定 3600 秒以上前で、同じ条件で `wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11` を実行する
- **THEN** stdout は `owner-away 11`、exit 0 で、`stopped 11` は出ず、判断役・子への送信・orca terminal close・再起動を呼ばない

#### Scenario: 作業報告と完了は親の判断に渡さない
- **WHEN** sender が parent または startup で、value が `dependency_wait` を持たない作業報告、`dependency_wait` が `false` か boolean でない作業報告、または完了であり、会話ログに問いや依存待ちマーカーがある
- **THEN** 停止にせず、--resolve の判断役・送信・端末終了・再起動を呼ばない。value が完了であることだけを理由に status を done に変更しない

#### Scenario: 状態記録のない古い子を返さない
- **WHEN** turn_input / turn_state が無い子のログが質問または依存待ちマーカーで終わり、turn_duration と古い stopped の印がある
- **THEN** wait は stopped を返さず --resolve の判断役も呼ばない。印や会話ログだけへの代替経路を使わない

#### Scenario: 不完全または不正な状態を採用しない
- **WHEN** turn_state が null、片方が欠ける、generation が文字列、session_id が空、sender や value が未定義、summary や時刻の型が不正、または generation / session_id が不一致の組を読む
- **THEN** いずれも有効な終了状態として扱わず、stopped の返却・自動判断・送信・端末終了・再起動を行わない。`dependency_wait: true` を持っていても同じである

#### Scenario: 会話ログが読めなくても状態によって検知する
- **WHEN** 親が送った入力に対する有効な主の返事待ち、または有効な依存待ちの作業報告が記録済みで、会話ログが無いまたは読めない
- **THEN** wait は停止として返せる。ログの読取不能を理由に状態の記録の判定を覆さない
