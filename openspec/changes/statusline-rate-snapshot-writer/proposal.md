## Why

harness の statusline は各 PC で動いているが、現在のレート残量 snapshot は 5 キーを直接書くだけで、観測時刻・アカウント帰属・PC 間共有を表せない。flatmate の burn reader が利用する writer 契約を harness に移し、観測形式の正本を実際の writer 側に置く。

## What Changes

- `plugins/statusline/scripts/statusline.sh` が観測時刻と書込時刻、値の署名、ホスト名、保存先の印、セッション ID、取得できた場合のアカウント ID を含む JSON snapshot を書く。
- ローカル snapshot を原子的に置換し、設定があれば同じ本文をホスト別の共有ファイルへ書く。共有先の失敗でも表示とローカル書込みを続ける。
- writer の契約を harness の新しい `rate-snapshot` capability に定義し、テストと statusline の説明を更新する。

## Capabilities

### New Capabilities

- `rate-snapshot`: harness statusline が書くレート観測の条件、形式、時刻、帰属、共有出力。

### Modified Capabilities

なし。

## Impact

- 対象: `plugins/statusline/scripts/statusline.sh`、`plugins/statusline/tests/`、`plugins/statusline/README.md`、harness の `openspec/specs/rate-snapshot/`。
- 共有ディレクトリの既存契約 `FLATMATE_RATE_SHARE_DIR` / `FLATMATE_RATE_SHARE_CONF` / `~/.claude/flatmate-rate-share` を維持する。
- flatmate 側の reader、撤去、spec 更新、実機配線、為替キャッシュは flatmate#936 の範囲とする。
