## ADDED Requirements

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

既存の `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rate-limit-snapshot` の書き込み（形と、`CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空なら書かない条件）は変えてはならない（MUST NOT）。

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

### Requirement: 記録と snapshot から実効値を求める
使用量の読み手は、スロットごと・窓（5 時間枠・全体の週次・Fable 週次）ごとに、セッション記録と usage snapshot の `accounts[slot]` から次の規則で「実効値」を求めなければならない（SHALL）。スロットに対応するセッション記録は、スロットの `securestorage` から書き手と同じ導出で求めた鍵のファイルとし、鍵が一致しない記録をそのスロットの値として読んではならない（MUST NOT）。

1. 情報源の `pct` または `resets_epoch` が有限の数でなければ、その情報源のその窓は無いものとする
2. 現在時刻がリセット時刻以上なら `pct` を 0 とみなす。全体の週次・Fable 週次のリセット時刻は、現在時刻より後になるまで 7 日ずつ進める。5 時間枠のリセット時刻は `null` とする
3. 現在時刻がリセット時刻より前なら、情報源の `pct` を下限としてそのまま使う。取得からの経過時間で値を捨ててはならない（MUST NOT）
4. 両方の情報源に値があるとき、2 の読み替えのあとでリセット時刻の差が 3600 秒以内なら同じ窓として `pct` の大きい方を取り、リセット時刻は取得時刻の新しい情報源のものを使う。差が 3600 秒を超えるときはリセット時刻の後の方を取る。5 時間枠でリセット時刻が `null` になった側と、リセット前の値を持つ側があれば、リセット前の側を取る
5. 実効値の取得時刻は、採った値の情報源の取得時刻（セッション記録は `observed_at`、snapshot は `fetched_at`）とする

Fable 週次はセッション記録に無いため、snapshot の `fable_weekly_pct` と `weekly_resets_epoch` から 1〜3 で求める。どの情報源からも求まらない項目は欠測（`null`）とし、0 に置き換えてはならない（MUST NOT）。

dev-workflow の読み手（`select-account.sh`・`session-tripwires.sh`・`agent-model-guard.sh`・`codex-develop.py`）は、この規則を `plugins/dev-workflow/scripts/usage_view.py` の 1 か所の実装から使わなければならない（SHALL）。`usage_view.py` は `--json` で全スロットの実効値と active スロットの id を 1 行の JSON で出力する。

#### Scenario: B の記録は A の値として読まれない
- **WHEN** accounts.json に A（既定）と B を登録し、B の鍵の記録だけに週次 90% を置き、A には記録も snapshot の値も無い状態で実効値を求める
- **THEN** A の実効値の週次は欠測で、B の実効値の週次が 90 である

#### Scenario: リセット時刻を過ぎた記録は 0% として扱う
- **WHEN** 週次 80%・リセット時刻が現在より 1 時間前、5 時間枠 95%・リセット時刻が現在より 10 分前の記録だけがあるスロットの実効値を求める
- **THEN** 週次は 0 でリセット時刻は元の値に 7 日を足した時刻、5 時間枠は 0 でリセット時刻は `null` になる

#### Scenario: リセット前の古い値は下限として使う
- **WHEN** 2 日前に書かれ、週次 40%・リセット時刻が現在より 1 日後の記録だけがあるスロットの実効値を求める
- **THEN** 週次は 40 で、欠測にならない

#### Scenario: 同じ窓なら大きい方を取る
- **WHEN** 同じリセット時刻の週次について、記録が 50%（新しい）、snapshot が 55%（古い）を持つ
- **THEN** 実効値の週次は 55 である

#### Scenario: 新しい窓の値を優先する
- **WHEN** snapshot の週次のリセット時刻が過ぎて 0% に読み替えられ、記録には新しい窓（リセット時刻が現在より後）の 10% がある
- **THEN** 実効値の週次は 10 である

#### Scenario: 情報源がどちらも無ければ欠測
- **WHEN** 記録も snapshot の値も無いスロットの実効値を求める
- **THEN** 全項目が `null` で、0 にはならない
