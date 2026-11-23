# Proposal

## Why

作業の結果を待つ子への外部の声かけを、現行の停止済み子向け予約文と分離する必要がある。親の送信を広げる前に、予約文の往復が通常入力として世代を進めたり、元の作業待ちの記録を消したりしない受信基盤を整える（#1792）。

## What Changes

- 共通定義に作業待ち用の固定文と専用の一行応答形式を追加し、停止済み子用の定義と既存の生成結果を保つ。
- child-log の共有読取部品で、固定文の種類に対応する正しい応答だけを通常会話から除外する。
- 子の UserPromptSubmit / Stop で両方の予約文を認識し、元のターン情報と記録を保持する。
- 対応する 2 つの bats に新旧予約文、通常入力、応答の取り違えを確かめる回帰テストを追加する。
- 子の受信手順は #1793、親の送信有効化と自己タイマーの撤去は #1777 に残す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 共有定義と child-log の予約文・応答の除外を作業待ち用へ拡張する。
- `dev-workflow-epic-state`: 予約文の往復によるターン情報の更新除外を作業待ち用にも適用する。

既存 capability に記述が分かれているが、変更は一つの受信プロトコルを同じ共有定義で認識する機能単位である。issue の本体決定に従って単一 change とする。

## Impact

実装と回帰テストは次の 5 ファイルに限定する（OpenSpec artifact と変更記録 `plugins/dev-workflow/changes/1792.md` は別枠）。

- `plugins/dev-workflow/references/child-cache-keepalive.json`
- `plugins/dev-workflow/scripts/child-log-read.py`
- `plugins/dev-workflow/scripts/epic-child-state.sh`
- `plugins/dev-workflow/tests/child-log-read.bats`
- `plugins/dev-workflow/tests/epic-child-state.bats`

新しい依存パッケージ、記録スキーマの変更、親の送信経路の変更は不要。`epic-keepalive.md`、`child-background-wait.md`、`child-background-wait.bats` は変更しない。#1743 の自己タイマーも維持する。順序は #1792 → #1793 → #1777。
