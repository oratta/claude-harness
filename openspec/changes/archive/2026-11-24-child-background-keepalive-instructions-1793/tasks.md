# Tasks

## 1. 子の受信手順と契約テスト

- [x] 1.1 `epic-keepalive.md` に作業待ち前の読み込み、トップレベルと `background` の種類選択、完全一致する予約文への一行応答・ツール禁止・状態保持を接続し、旧停止中の受信規則を残す。固定文全文を複写せず共有定義から生成することと、両種類の保持対象を `child-background-wait.bats` に追加して同スイートで確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic-keepalive.md:1-7、plugins/dev-workflow/tests/child-background-wait.bats:4-22、plugins/dev-workflow/tests/child-background-wait.bats:118-131
- [x] 1.2 `child-background-wait.md` から受信正本と共通 JSON の事前読み込みへ接続し、作業待ち向け予約文を通常入力時のタイマー取消より先に分類する。一行だけでターンを終え、元作業 ID・実行 ID・自己タイマー ID・初回設置時刻を保持する分岐を記す。通常入力・元作業と自己通知の照合・完了時の取消を維持する。両文書を検査するテスト（先行分類、保持対象、受信ターンのツール禁止、非一致入力の既存経路）を加え、`bats plugins/dev-workflow/tests/child-background-wait.bats` で既存タイマー雛形・12時間上限も含めて確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/child-background-wait.md:3-10、plugins/dev-workflow/skills/develop/references/child-background-wait.md:41-58、plugins/dev-workflow/tests/child-background-wait.bats:40-53、plugins/dev-workflow/tests/child-background-wait.bats:75-131
- [x] 1.3 手順接続と検証範囲を変更記録に残す。親の送信有効化・自己タイマー撤去・実会話の検証は #1777 に残ることを書き、issue #1793 と差分を照合する。触る範囲: plugins/dev-workflow/changes/1793.md（新規）

## 2. 統合確認

- [x] 2.1 `bats plugins/dev-workflow/tests/child-background-wait.bats plugins/dev-workflow/tests/child-log-read.bats plugins/dev-workflow/tests/epic-child-state.bats tests/develop-epic-scene-budget.bats tests/bats-assertion-guard.bats` と `git diff --check` を実行し exit 0 を確認する。受信基盤・親送信・共有定義の差分がないことも確認する。場面予算を超えたら本文の意味を維持して簡潔にし、上限変更が不可避なら根拠を本体へ返す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-keepalive.md:1-7、plugins/dev-workflow/skills/develop/references/child-background-wait.md:3-58、plugins/dev-workflow/tests/child-background-wait.bats:1-151（他スイート・予算ファイルは実行・参照のみ）

## Workflow follow-up

- R1 の APPROVE を記録先で確認してから実装へ進む。
- 実装＋verify の後は本体の指示に従って archive・本 spec への同期・PR の仕様宣言へ進む。この工程では実装も archive も行わない。
