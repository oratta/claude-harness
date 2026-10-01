## 1. 書き手（セッションごとの前回値）

- [ ] 1.1 先にテストを書く（Red）: 同じアカウントのセッション X（週次 40%）→ Y（60%）→ X が 40% のまま描き直し、で記録が 60% のまま・`observed_at` が Y の時刻のまま。X が 45% を受け取れば書く。セッション ID 無しは毎回書く。覚えのファイルが書けなくても出力不変。`mk_input`（同 bats:44）は session_id 固定なので、X と Y を分けるために session_id を引数化する。触る範囲: `plugins/statusline/tests/statusline-session-records.bats`
- [ ] 1.2 `statusline.sh` の記録の書き込みに、セッション ID ごとの署名ファイルの比較・保存と、7 日超の削除を足す。触る範囲: `plugins/statusline/scripts/statusline.sh:150-175`実装メモ: `session_id` は `jq -c` の JSON 文字列（引用符付き）なので、ハッシュ対象は引用符付きの表現のままに固定する。ハッシュは既定アカウント経路で python3 を起動しないため `shasum -a 256` か `sha256sum` で取る。「7 日より古い」は mtime 基準（`find -mtime +7`）。（「起動アカウント別のセッション記録」節。`session_id` は 41 行目、署名の先例は 99-113 行目）

## 2. 読み手の規則（同じ窓は取得時刻が新しいほう）

- [ ] 2.1 先にテストを書く（Red）: snapshot 週 100%・同じリセット時刻・新しい記録 0% で実効値が 0。記録が新しく値も大きいとき従来どおり大きい値。取得時刻が等しければ大きいほう。既存の `test_same_window_takes_the_larger_value`（記録 50%・NOW-60、snapshot 55%・NOW-5h で 55 を期待）は新規則と逆なので、期待値を 50、`weekly_observed_at == NOW-60`、`weekly_resets_epoch` は記録側に書き換える。触る範囲: `plugins/dev-workflow/tests/test_usage_view.py:90`
- [ ] 2.2 `usage_view.py` の `_combine` / `_larger` を直す。触る範囲: `plugins/dev-workflow/scripts/usage_view.py:137-163`
- [ ] 2.3 `select-account.sh` が snapshot 100%・新しい記録 0% のアカウントを週 0% として扱うテストを足す（コード変更が要らないことの確認）。触る範囲: `plugins/dev-workflow/tests/account-selector.bats`、`plugins/dev-workflow/scripts/select-account.sh:57`
- [ ] 2.4 `statusline.sh` 内の `combine` / `larger` を同じ規則に直し、他アカウント行が 0% を出すテストを足す。既存の「larger value of the same window wins even when older」（新規則と逆）を書き換える。触る範囲: `plugins/statusline/scripts/statusline.sh:555-580`、`plugins/statusline/tests/statusline-multi-account.bats:777`

## 3. 仕上げ

- [ ] 3.1 `LC_ALL=en_US.UTF-8 bash scripts/test.sh` が exit 0
- [ ] 3.2 spec delta を archive で本 spec に反映する
