## MODIFIED Requirements

### Requirement: ステータスラインが起動アカウント別の記録を書く
`plugins/statusline/scripts/statusline.sh` は、stdin の `rate_limits.five_hour.used_percentage` があるとき、その描画で受け取った `rate_limits` を起動アカウント別の記録 `<記録ディレクトリ>/<アカウント鍵>.json` に書かなければならない（SHALL）。記録ディレクトリは `USAGE_SESSIONS_DIR`、未設定なら `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions` とする。

アカウント鍵は書き手の起動環境の `CLAUDE_SECURESTORAGE_CONFIG_DIR` だけから決めなければならない（SHALL）。未設定または空なら `default`、それ以外は値を NFC 正規化した UTF-8 の sha256 の 16 進先頭 8 桁とする（`usage-account-registry` の Keychain サービス名の導出と同じ）。書き手は `accounts.json`・usage snapshot の `active`・レジストリの先頭スロットのいずれからも鍵を決めてはならない（MUST NOT）。

記録は次の形の JSON でなければならない（SHALL）。値が無い項目は `null` とする。

```json
{"schema": 1, "key": "default", "observed_at": 1790170001,
 "five_hour_pct": 3, "five_hour_resets_epoch": 1790176200,
 "weekly_all_pct": 69, "weekly_resets_epoch": 1790373600}
```

`observed_at` は書き込んだ時刻（epoch 秒）、`five_hour_*` は `rate_limits.five_hour`、`weekly_*` は `rate_limits.seven_day` の `used_percentage` / `resets_at` とする。書き込みは記録ディレクトリ内の一時ファイルに書いてから置き換える形で行い、読み手に書きかけの内容を見せてはならない（MUST NOT）。ディレクトリ作成・書き込みの失敗は無視し、ステータスラインの出力を変えてはならない（MUST NOT）。

`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rate-limit-snapshot` の形と書込条件は `rate-snapshot` capability の writer 契約に従わなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空なら書かない条件は維持する。

**守備範囲**: セッション記録の判定に使う入力は、このマシンの statusline に渡される stdin JSON の `rate_limits` と、起動環境の `CLAUDE_SECURESTORAGE_CONFIG_DIR` である。拾いたい誤りは、5 時間枠の使用率が無いときに記録を書くことと、別アカウントの鍵で記録することである。レジストリ未登録の非既定アカウントでも、その環境変数から導出した鍵への記録は通す。未知の入力上の穴が見つかるたびに検査を足して塞ぎ切ることは、この要件の完了条件にしない。snapshot の書込条件の守備範囲は `rate-snapshot` の要件に従う。

#### Scenario: 既定アカウントのセッションは default に書く
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` を未設定にし、`rate_limits` を含む JSON で statusline を実行する
- **THEN** 記録ディレクトリに `default.json` ができ、`five_hour_pct` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_epoch` が stdin の値と一致し、`key` が `default` である

#### Scenario: B のセッションは B の鍵にだけ書く
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` を B のディレクトリにし、accounts.json に A（既定）と B を登録し、usage snapshot の `active` を A にした状態で statusline を実行する
- **THEN** 記録ディレクトリには B の鍵（B のディレクトリの sha256 先頭 8 桁）のファイルだけが書かれ、`default.json` は作られも変更されもしない

#### Scenario: レジストリに無いアカウントでも自分の鍵に書く
- **WHEN** accounts.json に登録されていない `CLAUDE_SECURESTORAGE_CONFIG_DIR` で statusline を実行する
- **THEN** その値から導出した鍵のファイルにだけ書かれ、登録済みスロットの鍵のファイルは変わらない

#### Scenario: rate_limits が無ければ書かない
- **WHEN** `rate_limits` を含まない JSON で statusline を実行する
- **THEN** 記録ディレクトリにファイルは作られない

#### Scenario: 記録ディレクトリに書けなくても表示は変わらない
- **WHEN** 記録ディレクトリの親が書き込み不可の状態で statusline を実行する
- **THEN** statusline は exit 0 で、記録が書けた場合と同じ出力を返す
