# Proposal

## Why

エピックの子の作業報告が主の返事待ちと推定され、主との対話中に親が返事や起動し直しを行った（#1670）。子が状態・入力の送り手・受付時刻を毎ターン記録する契約を先に確定し、後続の #1744 が推定に代わる入力を読めるようにする。

## What Changes

- 別セッション方式（Orca・tmux）の子だけに UserPromptSubmit / Stop フックを追加する。通常ターンの最終非空行 `状態: <主の返事待ち|作業報告|完了> — <中身>` を検査し、欠落・不正なら停止を拒否して書き足させる。
- 既存の子ごとの JSON に任意の `turn_input` / `turn_state` を追加する。入力の送り手・受付時刻・セッション・世代を記録し、新しい通常入力で旧状態を原子的に無効にする。状態の保存も同じ排他と置き換えを使う。
- `epic-child-stop.md` に毎ターンの状態行とフックの責務を記す。声かけ予約文は従来の一行応答と状態維持の例外とし、`止まった理由:` と見込みの行は新しい状態行の直前の末尾部分に残す。
- 既存 Stop の `owner-message-number-check.sh` と状態保存を1つの入口で順に処理し、既存 Stop が拒否した発言を終了状態として公開しない。
- `epic-dispatch.sh` の依存待ち判定だけを、旧末尾形式と新しい状態行の直前のマーカーの両方に対応させる。状態記録を使う親の判定・送信抑止・起動し直しの変更（#1744）と、時間による知らせ（#1745）は対象外。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: 子が生成するターン情報の任意拡張、入力受付と Stop の世代照合、末尾行の強制、予約文の例外を追加する。既存の `status` / `stop` と親側の読み方は維持する。
- `dev-workflow-develop`: 依存待ちの末尾契約を、状態行を最後に置く子と旧形式の子で両立するよう調整する。親の依存待ちの扱い自体は維持する。

## Impact

実装予定は次の5ファイルのみ（すべて `plugins/dev-workflow/` 配下）。この仕様工程では OpenSpec artifact だけを作り、実装しない。

1. `scripts/epic-child-state.sh`（新規）: 入力受付・Stop の入口とターン拡張の読み書き・世代照合。`epic-state.sh` の汎用関数を再利用し、既存 Stop の判定を保存前に呼ぶ。
2. `hooks/hooks.json`: UserPromptSubmit の追加と Stop の入口の置き換え。
3. `tests/epic-child-state.bats`（新規）: 状態行・送り手・時刻・世代・対象外・予約文・排他・既存 Stop との組み合わせ・依存待ちの互換性の検証。
4. `skills/develop/references/epic-child-stop.md`: 子の毎ターンの契約。
5. `scripts/epic-dispatch.sh`: 依存待ちマーカーの末尾判定の最小の互換変更。

既存の `epic-state.sh`・`owner-message-number-check.sh`・`references/child-cache-keepalive.json`・`child-log-read.py` は変更せず再利用する。新しい外部依存・常時注入・起動部品の変更はない。develop の依存待ちの末尾契約以外の親手順や既存の声かけ要件は変えない。分割根拠と順番は [本体の分割決定](https://github.com/oratta/claude-harness/issues/1670#issuecomment-7052998109)、5ファイルの構成は [本体の修正決定](https://github.com/oratta/claude-harness/issues/1670#issuecomment-7053222677) に従う。
