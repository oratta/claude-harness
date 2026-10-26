# Tasks

この工程は仕様化まで。以下は R1 の APPROVE が記録先に載った後の実装タスクであり、現時点では未実行。行番号は固定 HEAD `1b203ef5` の案内で、編集前に読み直す。

規模の申し送り: 送受信と起動部品の契約を一体で導入する不可分な機能として一つの change にするが、実装の対象ファイルは 5 個を超える見込み。本体が実装工程を渡す前に規模トリップワイヤーとの整合を判断する。worker が独自に範囲を増やしたり、無断で別 change に分けたりしない。

## 0. 実 CLI で観測の前提を確認する（実装の最初）

- [ ] 0.1 他の実装タスクより先に、Orca と tmux の両経路の既存セッションについて、実際の CLI 出力で「入力待ち・空欄」を観測できるか確かめる。実行中・入力済み・質問/許可の選択画面との区別も確認し、利用したコマンド・CLI の版・出力・終了コード・判定根拠を #1383 に記録する（会話の機微情報は伏せる）。既存セッションの読み取りで確認し、この確認のために Claude を呼び出さない。スタブの成功だけでは完了としない。両経路のどちらかで観測できない、または実セッション/必要な権限が無く検証できないなら、証拠と不足する観測を本体へ返して依存する実装を止める。推測で送信せず、追加の観測基盤を独断で作らない。触る範囲: `plugins/dev-workflow/scripts/epic-launch-orca.sh:90-106`（選択と CLI 呼び出し、読み取りのみ）、`plugins/dev-workflow/scripts/epic-launch-orca.sh:281-335`（既存の送信契約、読み取りのみ）、`plugins/dev-workflow/scripts/epic-launch-tmux.sh:28-157`（画面とログの観測、読み取りのみ）、`https://github.com/oratta/claude-harness/issues/1383`（観測の証拠と不足の記録）

## 1. 共有する文と質問を保持する受信・読み取り

- [ ] 1.1 声かけ文・専用の返事の接頭辞・順序付きの `待ち:`/`次:` の欄の型を一つの機械可読定義に置き、生成と照合を同じ定義から行う。子の停止前の読み込みと、声かけの受信ではツール/mark/記録を呼ばない例外を epic-child-stop.md に加える。欄の中身の確定は #1374 に残す。定義を変えたとき生成・照合が共に追従するテストと受信手順の Bats を通す。触る範囲: `plugins/dev-workflow/references/child-cache-keepalive.json`（新規）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1448-1530`（child_log_line と共有定義の読み込み）、`plugins/dev-workflow/skills/develop/references/epic-child-stop.md:1-17`、`plugins/dev-workflow/tests/epic-dispatch.bats:6457-6655`、`plugins/dev-workflow/tests/develop-skill.bats:975-1131`
- [ ] 1.2 child-log が完全一致の固定文と、その対応する型どおりの一行の返事だけを除き、元の質問・主の発言の本文と timestamp を保つようにする。連続往復、通常の「了解」、型が違う質問、途中の主/親の実際の返事、meta/tool_result の介在を Bats で確認する。epic.md の表を書く手順には、正常な一行の往復だけに質問保持を保証することを記す。予約文を主が直接入力した場合も固定文と型どおりの返事を除外し、識別を追加しない限界を記す。複数行・型違いの返事は全体を表示して最後の子の発言に選び、status/stop=stopped-seen・停止コメント・停止の基点を変えず、wait が継続して親を起こさないことを Bats で確認する。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1453-1529`、`plugins/dev-workflow/skills/develop/references/epic.md:49-59`、`plugins/dev-workflow/tests/epic-dispatch.bats:6457-6655`

## 2. 既存セッションだけに送る起動部品

- [ ] 2.1 0.1 の両経路の観測確認後、Orca の起動部品に既存・一意・入力待ち・空欄のセッションだけへ固定文を送る `keepalive <worktree> <text>` を加える。dev-workflow-epic-state delta の表・守備範囲・許可操作に従い、sent/skipped は exit 0、failed は exit 1、引数数違いは stdout 空・使い方を stderr・exit 2 とする。端末無し/曖昧/実行中/入力あり/選択画面は skipped、送信失敗は failed とし、create/close/relaunch/入力消去が無いことを既存の Orca スタブで確認する。送信と開始確認だけでは返事内容の成功としない。入力の観測が CLI で足りなければ実装を推測で続けず証拠を本体に返す。部品のコメントにも契約を書く。触る範囲: `plugins/dev-workflow/scripts/epic-launch-orca.sh:90-106`（既存セッションの選択）、`plugins/dev-workflow/scripts/epic-launch-orca.sh:281-335`（deliver の既存送信部分）、`plugins/dev-workflow/scripts/epic-launch-orca.sh:382-410`（入口）、`plugins/dev-workflow/tests/epic-dispatch.bats:1-250`（Orca スタブ。新しいケースは末尾に追加）
- [ ] 2.2 0.1 の両経路の観測確認後、tmux に同じ引数・stdout/exit の keepalive 経路を加え、dev-workflow-epic-state delta の 13 サブコマンドと許可操作の契約に従う。既存のペイン確認・画面の読み取りを使う。新規起動/終了/入力消去をせず、入力待ち・空欄の既存セッションのみ送ることをスタブ Bats で確認する。部品の説明に契約を書く。両起動部品について引数数違い、sent/skipped/failed と終了コード、観測不能、送信直前の状態変化、禁止操作を呼ばないことを Bats で確認する。触る範囲: `plugins/dev-workflow/scripts/epic-launch-tmux.sh:28-55`（画面パターンと使い方）、`plugins/dev-workflow/scripts/epic-launch-tmux.sh:70-157`（画面・入力・送信確認）、`plugins/dev-workflow/scripts/epic-launch-tmux.sh:271-300`（deliver 付近）、`plugins/dev-workflow/tests/epic-launch-tmux.bats:332-390`（ケースはこの近辺または末尾に追加）

## 3. wait の送信条件と期限

- [ ] 3.1 子の TTL と最後の成功した CLI リクエストを分けて読み、停止記録・未回答・stop=stopped-seen を確認し、50〜60 分と停止から 24 時間の条件を実装する。done/reap/再起動条件/5m/unknown/前の返事未着/実際の返事ありを除外する。既存のキャッシュ書き込み関数の契約は維持する。各境界（2999/3000/3599/3600 秒、86399/86400 秒）、cache-hit の応答、未来/不正時刻、複数セッションと計測不能、スリープ復帰を制御した時刻の Bats で確認し、reply-after-idle.md に期限と overage の観測遅れを書く。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1023-1161`（TTL/リクエスト/活動の読み取り）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1261-1433`（wait）、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md:1-32`（子の再開の表）、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md:77-92`（親の費用）、`plugins/dev-workflow/tests/epic-dispatch.bats:1865-2013`（TTL の既存ケース。声かけケースは末尾に追加）
- [ ] 3.2 待ちを続ける通常のポーリングで起動部品の keepalive を呼ぶ。正常な一行の返事でも複数行・型違いでも、声かけへの返事だけでは stdout/終了理由/停止の印・24 時間の基点を変えず、送信失敗でも通常の待ちを続ける。--interval/--timeout 0 の一回確認と片付け待ちは送らない。声かけ往復後も timeout まで待つケースと、本当の stopped/done/closed は返すケースを Bats で確認する。epic.md に打ち手と既存の一回の掛け直しの維持を書く。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1261-1433`、`plugins/dev-workflow/skills/develop/references/epic.md:77-94`（別セッションの wait と timeout）、`plugins/dev-workflow/tests/epic-dispatch.bats:1260-1864`（wait の既存ケース。声かけケースは末尾に追加）、`plugins/dev-workflow/tests/develop-skill.bats:1399-1503`（短い掛け直し）
- [ ] 3.3 #1379 の小さい timestamp 回帰を追加する。20 分前 Z/cli/1h、3 分前 -05:00/cli/5m、not a time/cli/1h の同居で、上限未指定 dispatch wait 11 の stderr に `wait limit 21600 (parent cache 5m)` が出ること、時差なしを UTC として比較することを Bats で確認する。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats:1865-2013`

## 4. 統合確認と実測

- [ ] 4.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-launch-tmux.bats` と `scripts/lint.sh` を exit 0 にする。lint は内部で Claude の plugin validate を呼ぶため、この Codex spec worker では実行しない。実装工程でも同じ禁止が続く場合は、実行可能な側での実行を本体へ依頼し、完了までは未完了にする。実セッションで質問→停止→固定文→正しい返事のあと、child-log が元の質問を保ち wait が継続することを確認し、端末の開始確認と区別して #1383 に証拠を残す。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats:1-6655`、`plugins/dev-workflow/tests/develop-skill.bats:1-1503`、`plugins/dev-workflow/tests/epic-launch-tmux.bats:1-502`（統合確認。失敗を直す範囲は前のタスクによる）、`scripts/lint.sh:1-170`（実行・読み取りのみ）
- [ ] 4.2 実装前の比較区間を特定し、実装後の実エピック一本の親・子双方のキャッシュ書き直し/読み出し/維持費用を既存 cost-ledger で比較する。design.md の計測項目と元データの識別子を #1383 にコメントし、削減したか・維持費込みではどうかを分けて結論を書く。実エピック未実行や比較不能なら不足をコメントして未完了にする。ログは repo に保存せず既存の配置から読む。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:637-659`（usage の抽出、読み取りのみ）、`plugins/cost-ledger/scripts/cost_ledger.py:3074-3096`（facts/intervals CLI、実行・読み取りのみ）、`plugins/cost-ledger/pricing.json:1-20`（読み取りのみ）、`https://github.com/oratta/claude-harness/issues/1383`（比較コメント）
- [ ] 4.3 送信方式・期限・overage の限界・親の費用・正常な往復に限る質問保持・予約文の衝突と異常返事の表示/停止維持を変更記録に残し、#1374/#1385 の範囲を取り込んでいないことを差分で確認する。触る範囲: `plugins/dev-workflow/changes/1383.md`（新規）

## Workflow follow-up

- R1 の仕様レビューは本体が別スレッドに委ねる。spec worker は実装・レビュー判定・archive をしない。
- 実装と実測が終わったら、本体の canonical develop 手順で verify、レビュー、archive、PR と仕様宣言へ進む。今回の worker は merge/auto-merge を行わない。
