## Why

アカウントの週の枠を手動でリセットすると、使用率は下がるがリセット時刻は変わらない。いまの規則は「同じ週の値どうしは大きいほうを採る」ので、リセット後の 0%（セッション記録）より、リセット前の 100%（usage snapshot）が採られる。`usage-probe.sh` は記録と snapshot のどちらも 3 時間以内なら API を呼ばないため、snapshot も更新されない。結果、`cld`（`select-account.sh`）はリセット済みのアカウントを避け、ステータスラインの他アカウント行も 100% を出し続ける（2026-10-01 に実害: `selected=a ... margins=a:20.48,b:-13.83`）。

単純に「新しいほうを採る」に変えると別の問題が出る。記録の `observed_at` は、ステータスラインが動くたびの `date +%s` で、値を受け取った時刻ではない。Claude Code は API 応答以外（権限モード・vim モードの切り替え、リセット時刻の到来、プロンプトキャッシュの期限切れ）でもステータスラインを動かし、そのとき渡される `rate_limits` は、そのセッションが前に受け取った古い値のままである。記録は 1 アカウント 1 ファイルで全セッションが上書きするので、止まっているセッションの古い値が新しい取得時刻で書かれ、使用量を少なく見積もる。両方を直す。

## What Changes

- 書き手（`plugins/statusline/scripts/statusline.sh`）: セッションごとに、自分が前回書いた値を覚える。今回の値が前回書いた値と同じなら記録を書かない。値が変わったときだけ、その時刻を `observed_at` として書く。比べる相手は記録ファイルの中身ではなく、そのセッション自身が前回書いた値。
- 読み手の規則: 同じ窓（リセット時刻の差 3600 秒以内）で値が食い違ったら、`pct` の大きさでなく取得時刻が新しいほうの値を採る。取得時刻が等しい・無いときだけ大きいほうを採る。実装は `plugins/dev-workflow/scripts/usage_view.py` の `_combine` / `_larger` と、`statusline.sh` 内の写し（`combine` / `larger`）。`select-account.sh` は `usage_view.build_view` から実効値を読むので、`usage_view.py` を直せば反映される（コード変更不要）。
- spec: `usage-session-records`（記録の書き方・実効値の規則）と `statusline-multi-account-usage`（非 active 行の選び方）を新しい規則に合わせる。

## Capabilities

### Modified Capabilities
- `usage-session-records`: 記録の取得時刻の意味（値を新しく受け取った時刻）と書込条件、実効値の同じ窓での選び方
- `statusline-multi-account-usage`: 非 active スロット行での同じ窓の選び方

## Impact

- コード: `plugins/statusline/scripts/statusline.sh`、`plugins/dev-workflow/scripts/usage_view.py`
- テスト: `plugins/statusline/tests/statusline-session-records.bats`、`plugins/statusline/tests/statusline-multi-account.bats`（777 行目「larger value ... wins even when older」は新規則と逆なので書き換え）、`plugins/dev-workflow/tests/test_usage_view.py:90` の `test_same_window_takes_the_larger_value`（同上。期待値を 50 に）、`plugins/dev-workflow/tests/test_usage_view.py`、`plugins/dev-workflow/tests/account-selector.bats`
- 挙動への影響: 記録の `observed_at` の意味が「書いた時刻」から「値が変わった時刻」になるため、usage-probe（`openspec/specs/dev-workflow-escalation-tripwires/spec.md:146`、記録の `observed_at` が `USAGE_PROBE_STALE` 以内なら API を呼ばない）が API を呼ぶ頻度は上がる。
- 範囲外: #442（Codex 側の古い値の読み方、active 行が記録を読まないことを確かめるテスト）。この change には含めない。実装中に #442 のそのテストの前提が変わったら #442 に書く。
