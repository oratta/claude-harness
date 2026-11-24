# Tasks

## 1. 作業待ち記録と子の待ち方

- [x] 1.1 Stop フックに直前の明示行の解析と `turn_state.background_wait={id,started_at}` の保存・型検査を追加する。既存の3状態・dependency_wait・排他更新・新入力の無効化・遅い Stop・予約文除外は保つ。正しい行、引用/コード/本文途中、書式不正、依存待ちとの併存、旧記録、新入力、marker 無しの通常終了を Bats で確認し `bats plugins/dev-workflow/tests/epic-child-state.bats` を exit 0 にする。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:10-211（状態の解析・拡張検査・保存計画）、plugins/dev-workflow/scripts/epic-child-state.sh:265-302（排他更新）、plugins/dev-workflow/tests/epic-child-state.bats:1-1090
- [x] 1.2 子の専用手順に、状態記録による Orca 経路確認・通常の準備ターンでだけ自己タイマーを取消して外部用 marker を出す手順・同じ未回収作業の待ち ID と初回開始の保持を記す。Orca の新規自己タイマー0個、tmux の既存自己通知、worker の既存待機、取消失敗時の非公開と元作業保持に加え、直近の入力の送り手が owner のときは外部用 marker を出さず親の送信0回・自己通知は既存条件どおり（TTL 1h・最近の成功リクエスト・45分以内の返り無しで一つ）、次の parent/startup 入力で外部起こしへ戻るときは待ちの組と初回開始を保持し、owner 切替でも基点が延びないことをテストし `bats plugins/dev-workflow/tests/child-background-wait.bats` を exit 0 にする。固定文・受信・異種予約文の判断は作り直さない。触る範囲: plugins/dev-workflow/skills/develop/references/child-background-wait.md:3-64、plugins/dev-workflow/tests/child-background-wait.bats:1-200

## 2. 親の送信判定

- [x] 2.1 通常の watch-stopped ポーリングに作業待ち専用候補を接続する。状態・経路・親子・open・同世代/セッション・現行ログの同じ marker と状態を確認し、停止済み子の stop_uuid/コメント/150k 除外を作業待ちへ流用しない。大きい会話で background 文を一回送ること、通常報告・owner（子の自己通知への戻りと対で、親の送信0回）・依存待ち・done/waiting・旧/不正記録・tmux・単発・watch-done のみは送信0回を Bats に追加し、`bats --filter 'keepalive' plugins/dev-workflow/tests/epic-dispatch.bats` を exit 0 にする。親の正本に新旧二経路を記す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1536-1730（keepalive 判定と記録）、plugins/dev-workflow/scripts/epic-dispatch.sh:1758-1805（ターンの検査）、plugins/dev-workflow/scripts/epic-dispatch.sh:2210-2257（既存ポーリング）、plugins/dev-workflow/scripts/epic-dispatch.sh:2343-2345（固定文生成）、plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:1-17、plugins/dev-workflow/tests/epic-dispatch.bats:6992-9201
- [x] 2.2 同じ現行 CLI 一本で TTL と最後の成功リクエストを別に読み、3000/3600秒の送信窓・前回未応答なら非送信・初回開始から min(43200, owner-wait 設定) の上限を実装する。2999/3000/3599/3600秒、43199/43200秒、設定0/3600/86400、未来/不明、5m、cache-read のみ、親再開/掛け直し/延長で基点不変、pending をテストし、同じ keepalive Bats を exit 0 にする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1536-1730、plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:5-11、plugins/dev-workflow/tests/epic-dispatch.bats:6992-9201
- [x] 2.3 部品直前の状態と現行会話の再読を追加し、親子/path/launcher/端末/session/世代/待ちの組の変更、元作業通知、新しい入力/通常発言では同じポーリング内に送信しない。状態・ログ更新を注入する Bats で send 0回、既存の keepalive 理由と同一理由の時刻不変、stdout/終了理由の非変更を確認し、同じ keepalive Bats を exit 0 にする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1682-1730、plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:5-11、plugins/dev-workflow/tests/epic-dispatch.bats:6992-9201

## 3. Orca の限定した画面許可

- [x] 3.1 検査済み作業待ちの一呼び出しだけ `EPIC_DISPATCH_KEEPALIVE_BACKGROUND_WAIT=1` を渡し、Orca の既知背景待機行を初回と送信直前の二度とも限定して許す。通常経路は親環境の値も明示的に無効化する。既存の二引数・通常停止子/tmux の画面判定・送信後到達確認は保つ。背景待機だけの成功候補、通常呼び出しの skipped busy、二回目に変化、前景スピナー/dialog/draft/未知枠/枠内待機の拒否、送信後背景待機だけでは failed send を fixture で確認し、keepalive Bats を exit 0 にする。親手順にも許可と限界を反映する。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1682-1719、plugins/dev-workflow/scripts/epic-launch-orca.sh:112-273（画面判定・cmd_keepalive）、plugins/dev-workflow/skills/develop/references/epic-keepalive-watch.md:7-17、plugins/dev-workflow/tests/epic-dispatch.bats:7970-9201

## 4. 統合と変更記録

- [ ] 4.1 `bats plugins/dev-workflow/tests/epic-child-state.bats plugins/dev-workflow/tests/child-background-wait.bats plugins/dev-workflow/tests/epic-dispatch.bats` を exit 0 にし、主の返事待ちの固定文・送信条件・150k 除外・既存の期限設定・tmux・停止受領・wait の出力/終了規則が変わらないことを確認する。共有 JSON と child-log の除外は変更不要で、作業待ちの受信がツールなし一行の既存契約へ接続していることも既存回帰で確かめる。`openspec validate epic-background-keepalive-send-1777 --type change --strict` と `git diff --check` を exit 0 にする。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:1-1090、plugins/dev-workflow/tests/child-background-wait.bats:1-200、plugins/dev-workflow/tests/epic-dispatch.bats:6992-10381、openspec/changes/epic-background-keepalive-send-1777/specs/（本 change の差分仕様）
- [ ] 4.2 変更記録に外部起こしの対象・自己タイマーとの切替・初回開始からの12時間・互換性・実測未実施を記す。実作業中への誤送信、余分な応答/リクエスト、未計測の頻度と送信判定の制限を後続 PR のリスク宣言へ引き継ぐ文面を作り、記録と design の整合を確認する。この工程で主への質問や PR 作成は行わない。触る範囲: plugins/dev-workflow/changes/1777.md（新規）

## Workflow follow-up

- 仕様レビューは未実施。独立した R1 のレビューと記録先の APPROVE を確認してから実装へ進む。今回は artifact 作成のみで、Draft PR 作成・実装・archive・merge は行わない。触る範囲: openspec/changes/epic-background-keepalive-send-1777/（仕様レビュー対象）
- 後続 PR のリスク宣言で主の許容を取る。実作業中への誤送信の影響・頻度未計測、前回未応答時の非送信・限定反復・12時間基点と観測競合の限界を記す。触る範囲: 後続 PR 本文（GitHub #1777 に対応する PR。未作成）
- **受け入れ条件・未実施（マージ後でよい）:** 実エピックの60分超の作業待ちで、維持一回あたり成功リクエスト一回、ツールなし一行応答、自己タイマーなしを実会話ログで照合する。元作業/待ち ID と基点、モデル・会話量・TTL、送信/返事/request 時刻、cache_read_input_tokens、送信試行数・実送信数・誤送信数/試行数を #1777 へコメントする。元作業通知と親 timeout のリクエストを区別し、fixture や send 成功で代替しない。候補・ログ不足なら未確認のまま残す。生ログは LLM_LOG_DIR（未設定なら保存先を確認）にだけ保存し、repo 内に置かない。触る範囲: GitHub issue #1777 の実測コメント、LLM_LOG_DIR の実会話ログ（リポジトリ外）
