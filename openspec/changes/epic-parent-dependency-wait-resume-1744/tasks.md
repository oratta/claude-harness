# Tasks

行番号は仕様化時点（merge commit 後の oratta/issue-1744）の案内。実装前に該当箇所を読む。子フック `epic-child-state.sh` と `epic-child-stop.md` は #1775 の範囲で変えない。親向け手順書の一般の書き換えは #1760 の範囲で戻さない。編集対象は `epic-dispatch.sh`・`epic-dispatch.bats`・`epic-stop-from-log-scenario.bats`・`epic-child-state.bats`・`changes/1744.md` の 5 ファイルを上限とし、超えるなら手を止めて本体に返す。

## 1. 停止対象の述語と受領

- [ ] 1.1 `WAIT_TURN_DEFS` に `owner_question`（主の返事待ち）と `dependency_stop`（作業報告かつ `turn_state.dependency_wait == true`）を置き、`target` を共通部分かつどちらかにする。共通部分には「`turn_state.dependency_wait` が欠落か boolean」を足し、存在する非 boolean（`"true"`・`1`・`null`・配列・オブジェクト）は value によらず（`主の返事待ち` でも）停止対象から外す。欠落・`false` は除外しない（返事待ちは通り、作業報告は依存待ちでない）。既存の親用の記録検査（記録全体を読めるか）には型検査を足さない（design 1）。`detect_stopped`・`wait_received`・`resume_moved` は `target` を共有したまま、依存待ちの停止も同じ排他更新で受領する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1718-1742（WAIT_TURN_DEFS）、plugins/dev-workflow/scripts/epic-dispatch.sh:1744-1827（wait_received / resume_moved / detect_stopped）
- [ ] 1.2 `resolve_stopped` で、受領した組の記録が `dependency_stop` なら止まりの JSON の有無によらず判断役を呼ばず 1 を返す。返事待ちの停止に対する既存のマーカーの分岐は残す。`stop_to_resumed` の `expected` 付きの条件に `owner_question` を足す（design 2）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1427-1446（resolve_stopped の入口と依存待ちの分岐）、plugins/dev-workflow/scripts/epic-dispatch.sh:1700-1712（stop_to_resumed）
- [ ] 1.3 `rejudge_changed` は受領済みの組が `owner_question` の子だけを判断し直し、`keepalive_child` の候補も `owner_question` に限る（判定結果は `skipped not-stopped`）（design 2）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1905-1933（rejudge_changed）、plugins/dev-workflow/scripts/epic-dispatch.sh:1642-1678（keepalive_child）

## 2. pending-owner と reply の再確認

- [ ] 2.1 `cmd_pending_owner` で、stopped-seen の記録の受領した組が今も `target` かつ `dependency_stop` なら、`log_moved` を見ずに既存の形（`pending <N>` / `pending <N> <uuid>`）で出す。それ以外は既存どおり（design 3）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:2165-2184（cmd_pending_owner）
- [ ] 2.2 `deliver_reply` で `as == parent` かつ記録の `stop_turn` が null でないとき、`expected` が無ければ `stop_turn` を使い、`stop` の確認直後と起動部品の直前の 2 か所で `wait_received` を通す。通らなければ `skipped <N> not-stopped`（戻り値 2）。ログは読まない。`--as owner` と `stop_turn` の無い記録は変えない（design 4）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1008-1070（deliver_reply）

## 3. 必須テスト（裁定の 4 の一覧）

- [ ] 3.1 P3-F1 の再現テストを復旧テストに変える。実フック（UserPromptSubmit → Stop）→ 依存登録・確認・`子の停止: 依存待ち` コメントの保存 → 終了状態の保存（`dependency_wait: true`）→ 最初の `wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11` が `stopped 11` / exit 0 → `pending-owner 11` の出力に子 11 → 前提 22 の `closed` を既存の wait の閉じる通知で受ける → 依存の再確認（`blocked_by` の `state_reason` が completed）→ `reply --relaunch --as parent 400 11 '<続行指示>'` が `relaunched 11` / exit 0。起動指示に `/develop #11` と続行指示があることまで確かめる。judge は 0 回。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9727-9774（P3-F1 の再現テスト）
- [ ] 3.2 同じ子 11 への二度目の wait が `stopped` を返さない（同世代の二重受領の禁止）ことと、依存先の `closed` 通知と `pending-owner` による復元を確かめる。親のログ読取失敗（会話ログ無し・読めない・止まりの JSON 無し）でも依存待ちは `stopped 11` で judge は 0 回。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9413-9485（依存待ちの既存の再起動テスト）、plugins/dev-workflow/tests/epic-dispatch.bats:5546-5600（pending-owner）
- [ ] 3.3 依存未解消（前提が open）・見送り（`not_planned`）・依存の読取失敗では再起動しない（`reply` を呼ばないか、呼んだ結果の `failed` / `skipped` を復旧成功にしない）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9384-9530（依存待ちのテスト群）
- [ ] 3.4 owner の 2 状態（主の返事待ち・作業報告）に、依存待ちのマーカー・`dependency_wait: true`・150,001 トークン相当・3600 秒以上の経過を組み合わせても、判断・送信・close・起動が 0 回。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9598-9610（wait intervention: owner turns）
- [ ] 3.5 受領後、または `reply` の入口の確認を通ったあと送信直前に owner の新入力が保存された場合、ログが読めなくても `reply --relaunch --as parent` は `skipped 11 not-stopped` で orca terminal send・close・create が 0 回。古い停止コメントと `dependency_wait` から `pending-owner` が依存待ちとして復活させない。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4549-4600（reply の既存テスト）、plugins/dev-workflow/tests/epic-dispatch.bats:9687-9705（受領の排他テスト）
- [ ] 3.6 停止にしないもの: 通常の作業報告（`dependency_wait` 無し）、`dependency_wait` が `false`・`"true"`・`1`・`null`・配列・オブジェクト、引用／フェンス内のマーカー（フックが項目を付けない）、世代／セッションの不一致。判断役・送信・端末操作が 0 回。返事待ちの側も確かめる: parent の `主の返事待ち` で `dependency_wait` が `"true"`・`1`・`null`・配列・オブジェクトなら、`wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11` で停止対象にならず（`stopped` を返さない）、判断役・送信・端末操作が 0 回（既存の親用の記録検査では拒まれず記録は読める）。欠落・`false` なら、`--resolve` なしの `wait --interval 0 --timeout 0 --watch-stopped 11` で従来どおり `stopped 11` / exit 0（`--resolve` 付きでは判断が通して送信に成功すると stopped に含めない既存要件があるため、通る側の確認は `--resolve` なしで行う）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9486-9597（マーカーの構文テスト）、plugins/dev-workflow/tests/epic-child-state.bats:462-475（markers cannot promote）
- [ ] 3.7 新入力・Stop 差し戻しで古い `dependency_wait` が無効化され（実フック）、親の再開（`pending-owner` と wait）では有効な依存待ちだけが復元される。依存待ちの子に声かけを送らず、長い待ちの判断し直しにも渡さない。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:642-658（next input clears it）、plugins/dev-workflow/tests/epic-child-state.bats:696-714（an owner-sent work report with the field stays excluded。sender が owner なので timeout の期待のまま。parent の組で受領する対の例を足す）、plugins/dev-workflow/tests/epic-dispatch.bats:9629-9652（keepalive cannot bypass / material changes cannot rejudge）
- [ ] 3.8 移行条件: `dependency_wait` の無い parent の作業報告で、ログが成功時の依存待ちの末尾形式・子 issue に依存待ちコメントと `blocked_by` がある子を、wait も pending-owner も依存待ちとして返さず、judge・送信・端末操作が 0 回。旧期待値（ログだけの停止）を残すテストがあれば状態記録の契約に合わせる。触る範囲: plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats:1-197

## 4. 記録と検証

- [ ] 4.1 `plugins/dev-workflow/changes/1744.md` に、依存待ちの停止の受領・抑止・pending-owner・reply の再確認と移行条件、change 名 `epic-parent-dependency-wait-resume-1744` を追記する。version は上げない。触る範囲: plugins/dev-workflow/changes/1744.md:1-12
- [ ] 4.2 次の確認コマンドを実行し、いずれも exit 0 を確かめる。失敗を直したら当該テストと回帰を再実行し、結果を記録する。`openspec validate --all --strict` の既知の exit 1 は別に残し、対象 change の成功で全体の成功としない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1008-2184、plugins/dev-workflow/tests/epic-dispatch.bats:1-9935

```sh
bats --filter 'dependency wait' plugins/dev-workflow/tests/epic-dispatch.bats
scripts/test.sh epic-child-state epic-dispatch epic-stop-from-log-scenario
scripts/test.sh develop-skill develop-epic-scene-budget openspec-specs-format
bash -n plugins/dev-workflow/scripts/epic-child-state.sh
bash -n plugins/dev-workflow/scripts/epic-dispatch.sh
scripts/lint.sh epic-child-state.sh epic-dispatch.sh
openspec validate epic-parent-dependency-wait-resume-1744 --type change --strict
git diff --check
```
