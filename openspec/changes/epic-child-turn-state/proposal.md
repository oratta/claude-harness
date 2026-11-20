# Proposal

## Why

エピックの子の作業報告が主の返事待ちと推定され、主との対話中に親が返事や起動し直しを行った（#1670）。子が状態・入力の送り手・受付時刻を毎ターン記録する契約を先に確定し、後続の #1744 が推定に代わる入力を読めるようにする。

## What Changes

- 別セッション方式（Orca・tmux）の子だけに UserPromptSubmit / Stop フックを追加する。通常ターンの最終非空行 `状態: <主の返事待ち|作業報告|完了> — <中身>` を検査し、欠落・不正なら停止を拒否して書き足させる。
- 既存の子ごとの JSON に任意の `turn_input` / `turn_state` を追加する。入力の送り手・受付時刻・セッション・世代を記録し、新しい通常入力で旧状態を原子的に無効にする。状態の保存も同じ排他と置き換えを使う。
- `epic-child-stop.md` に毎ターンの状態行とフックの責務を記す。声かけ予約文は従来の一行応答と状態維持の例外とし、`止まった理由:` と見込みの行は新しい状態行の直前の末尾部分に残す。
- 親の wait / resolve / reply の判定・送信・起動し直しは変更しない。#1744 の親側と #1745 の時間による知らせは対象外。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: 子が生成するターン情報の任意拡張、入力受付と Stop の世代照合、末尾行の強制、予約文の例外を追加する。既存の `status` / `stop` と親側の読み方は維持する。

## Impact

実装予定は次の5ファイルのみ（すべて `plugins/dev-workflow/` 配下）。この仕様工程では OpenSpec artifact だけを作り、実装しない。

1. `scripts/epic-child-state.sh`（新規）: 入力受付・Stop の入口。
2. `scripts/epic-state.sh`: 子のターン拡張の読み書きと世代照合。
3. `hooks/hooks.json`: UserPromptSubmit / Stop の登録。
4. `tests/epic-child-state.bats`（新規）: 状態行・送り手・時刻・世代・対象外・予約文・排他の検証。
5. `skills/develop/references/epic-child-stop.md`: 子の毎ターンの契約。

既存の `references/child-cache-keepalive.json` と `child-log-read.py` の予約文生成を読み取りで再利用する。新しい外部依存・常時注入・起動部品の変更はない。既存 capability への追加要件として閉じ、develop の親手順や既存の声かけ要件を書き換えない。分割根拠と順番は [本体の決定](https://github.com/oratta/claude-harness/issues/1670#issuecomment-7052998109) に従う。
