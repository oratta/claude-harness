# Tasks

## 1. 共通定義と会話ログの種類別照合

- [x] 1.1 design.md の互換形式で `background` 定義と固定文生成を追加し、ログ読取で新旧の種類を認識する。生成結果の差異、旧 `--keepalive-text` の不変、新しい `--keepalive-text background` の成功と、新旧それぞれの正常往復で元の発言・uuid・時刻・主の発言・last_input_at・input_after が保たれる回帰テストを追加する。`bats plugins/dev-workflow/tests/child-log-read.bats` が通ることを確認する。触る範囲: plugins/dev-workflow/references/child-cache-keepalive.json:1-6、plugins/dev-workflow/scripts/child-log-read.py:1-353、plugins/dev-workflow/tests/child-log-read.bats:30-205
- [x] 1.2 種類に対応した一行応答だけを除外することを確認するテストを追加する。交差した種類の応答・固定文のない専用応答・型違い・複数行・一文字追加の固定文・本当の user の割込みは通常会話として出す。新旧固定文の切替、tool_result / meta / ローカルコマンドを挟む正常往復、背景タスクが予約文だけでは完了しないことも確認する。同じ bats スイートが通ることを確認する。触る範囲: plugins/dev-workflow/scripts/child-log-read.py:211-320、plugins/dev-workflow/tests/child-log-read.bats:17-310

## 2. 状態フックの予約文集合と記録保持

- [x] 2.1 共通の生成器から新旧固定文を読み、UserPromptSubmit の予約文除外と未登録通知の除外、Stop の最新 user 照合を同じ集合に拡張する。`作業報告` の通常記録と dependency_wait が true の記録で、予約文の受付・正常応答・型違い・別種類の応答・複数行・状態行付き応答の Stop が、記録全体と mtime を変えないテストを追加する。既存の停止済み子のケースも残し、`bats plugins/dev-workflow/tests/epic-child-state.bats` が通ることを確認する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:110-260、plugins/dev-workflow/tests/epic-child-state.bats:25-947
- [x] 2.2 新しい予約文に一文字追加した入力と、その後の本当の主・親の入力が通常どおり世代を進め turn_state を null にすること、以後の Stop は通常の状態行検査を受けることを回帰テストで確かめる。新予約文の未登録通知除外、対象外 session の不変、定義読取失敗で既存のエラー経路を保つことも確認し、同じ bats スイートが通ることを確認する。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:110-294、plugins/dev-workflow/tests/epic-child-state.bats:116-784
- [x] 2.3 受信基盤の追加と、子の手順・親の送信・自己タイマーの変更を後続へ残す境界を変更記録に書き、実装差分が指定 5 ファイルと OpenSpec artifact・変更記録に限定されることを `git diff --name-only` で確認する。触る範囲: plugins/dev-workflow/changes/1792.md（新規）

## 3. 受け入れ条件の統合確認

- [x] 3.1 `bats plugins/dev-workflow/tests/child-log-read.bats plugins/dev-workflow/tests/epic-child-state.bats` と `openspec validate child-background-keepalive-protocol-1792 --type change --strict` を実行し、全て exit 0 を確認する。新予約文の正常往復は「ログでは会話に数えない・フックでは元の記録を保つ」、逸脱応答は「ログでは表示・フックでは元の記録を保つ」が両立することを対応ケースで確認する。触る範囲: plugins/dev-workflow/tests/child-log-read.bats:1-310、plugins/dev-workflow/tests/epic-child-state.bats:1-1020

## Workflow follow-up

- 仕様化工程では実装せず、本体が起こす R1 のレビューを待つ。承認記録の確認後に実装工程へ進む。
- 実装・verify 後の finish 工程で archive と PR 作成を行う。merge はこの作業者の範囲外。
- #1793 で子の受信手順を接続し、その後 #1777 で親の送信と自己タイマーの扱いを変更する。
