# Proposal

## Why

Orca 1.4.263 の画面読み取りは `result.terminal` に入るが、声かけの起動部品とテストは `result` 直下を前提にしており、実際には毎回 `failed observe` になる（#1728）。入力を壊さず声かけを届けるため、現行の画面出力による空欄判定と送信確認の契約を合わせる。

## What Changes

- `result.terminal.tail` / `source` を読み、`draft` が無い場合も画面の入力領域全体から空欄を確認する。任意の `draft` がある場合は追加の入力証拠として扱う。
- `turn_started` の検出を現行 send 応答で確認し、未確認時の画面見直しでも同じ構造と空欄判定を使う。送信後に前景が実行中になり入力が空になった場合だけ補助的に到達を認める。
- 壊れた JSON / 想定外の観測構造を stderr の `failed observe shape` で特定可能にし、stdout の結果語と記録形式は保つ。
- Orca fixture と既存の分類テストを現行構造に合わせ、実測出力に基づく回帰ケースを加える。
- 実装段で、実際の停止中の子への到達・予約された返事・次のリクエストのキャッシュ利用を確認し、#1728 に証拠を残す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: 起動部品の Orca 画面観測・空欄判定・送信後確認・観測構造の診断を改定する。

## Impact

- 実装対象: `plugins/dev-workflow/scripts/epic-launch-orca.sh` の観測と送信確認、および `plugins/dev-workflow/tests/epic-dispatch.bats` の Orca fixture / 回帰テスト。独立 fixture ファイルを増やさず、実測例をこのテスト内に置く。
- tmux の部品、停止の印、声かけの固定文、TTL、15 万トークン以上を除外する既存規則、返事の数え方（#1545）、起動し直しの調査（#1729）には広げない。
- 前提: Orca CLI / host の現行 read と send、bash・Python 3・jq・bats、実機確認用の停止中の子とその会話ログへのアクセス。
- 分割判定: 単一 capability の送信判定契約で、観測・送信確認・fixture が一体のため単一 change。仕様 artifact は `.openspec.yaml` を含め 5 ファイル、実装は上記 2 ファイルの見込み（全工程の合計は 5 を超えるため本体へ報告する）。
