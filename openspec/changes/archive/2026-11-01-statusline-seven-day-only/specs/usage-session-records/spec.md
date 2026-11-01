## MODIFIED Requirements

### Requirement: ステータスラインが起動アカウント別の記録を書く
`plugins/statusline/scripts/statusline.sh` は、stdin の `rate_limits.five_hour.used_percentage` と `rate_limits.seven_day.used_percentage` の少なくとも一方があるとき、その描画で受け取った `rate_limits` を起動アカウント別の記録 `<記録ディレクトリ>/<アカウント鍵>.json` に書かなければならない（SHALL。書くかどうかの条件は下の `observed_at` の段落に従う）。記録ディレクトリは `USAGE_SESSIONS_DIR`、未設定なら `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions` とする。

アカウント鍵は書き手の起動環境の `CLAUDE_SECURESTORAGE_CONFIG_DIR` だけから決めなければならない（SHALL）。未設定または空なら `default`、それ以外は値を NFC 正規化した UTF-8 の sha256 の 16 進先頭 8 桁とする（`usage-account-registry` の Keychain サービス名の導出と同じ）。書き手は `accounts.json`・usage snapshot の `active`・レジストリの先頭スロットのいずれからも鍵を決めてはならない（MUST NOT）。

記録は次の形の JSON でなければならない（SHALL）。値が無い項目は `null` とし、キーを省いてはならず（MUST NOT）、`0` を書いてはならない（MUST NOT）。

```json
{"schema": 1, "key": "default", "observed_at": 1790170001,
 "five_hour_pct": 3, "five_hour_resets_epoch": 1790176200,
 "weekly_all_pct": 69, "weekly_resets_epoch": 1790373600}
```

`observed_at` は、そのセッションが記録に載せる値を新しく受け取った（前回書いた値と変わった）描画の時刻（epoch 秒）、`five_hour_*` は `rate_limits.five_hour`、`weekly_*` は `rate_limits.seven_day` の `used_percentage` / `resets_at` とする。Claude Code は API 応答以外（権限モードや vim モードの切り替え、リセット時刻の到来、プロンプトキャッシュの期限切れ）でもステータスラインを動かし、そのとき渡される `rate_limits` はセッションが前に受け取った値のままである。そのため書き手はセッションごとに前回書いた値（5 時間枠・週次の使用率とリセット時刻の組）を、記録ディレクトリ内の、セッション ID から決めたそのセッション専用のファイルに覚え、今回の値が前回書いた値と同じなら記録を書いてはならない（MUST NOT）。比べる相手は記録ファイルの中身ではなく、そのセッション自身が前回書いた値でなければならない（SHALL。記録ファイルは同じアカウントの他のセッションも上書きするため、ファイルと比べると、止まっているセッションが古い値を新しい時刻で書くのを防げない）。値が変わったら、記録を書き、その値を覚え直す。セッション ID が無い描画は覚える先が無いので、従来どおり毎回書く。前回値のファイルが無い・読めない・形が違うときは前回値なしとして記録を書く。覚える側のファイルの書き込み失敗は無視し、ステータスラインの出力を変えてはならない（MUST NOT）。7 日より古い覚えのファイルは書き込みのついでに消してよい。

書き込みは記録ディレクトリ内の一時ファイルに書いてから置き換える形で行い、読み手に書きかけの内容を見せてはならない（MUST NOT）。ディレクトリ作成・書き込みの失敗は無視し、ステータスラインの出力を変えてはならない（MUST NOT）。

`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rate-limit-snapshot` の形と書込条件は `rate-snapshot` capability の writer 契約に従わなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空なら書かない条件は維持する。

**前回値の判定の守備範囲**: 判定に使う入力は stdin の `session_id` と、そのセッション専用の前回値ファイルの中身である。拾いたい誤りは、止まっているセッションが前回と同じ値を新しい取得時刻で書くことである。次は通す: `session_id` が無い描画は毎回書く。前回値ファイルが無い・読めない・形が違うときは前回値なしとして書く。他セッションの書き込みを挟んだあとに前回と全く同じ値を本当に受け取り直した描画は書かれない（その間の記録は他セッションの新しい値か snapshot で、使用量を多く見積もる側にしか倒れない）。前回値ファイルの文字種や改ざんまで検査し、穴が見つかるたびに塞ぎ切ることは完了条件にしない。

**守備範囲**: セッション記録の判定に使う入力は、このマシンの statusline に渡される stdin JSON の `rate_limits` と、起動環境の `CLAUDE_SECURESTORAGE_CONFIG_DIR` である。拾いたい誤りは、5 時間枠と週次の使用率の両方が無いときに記録を書くことと、別アカウントの鍵で記録することである。レジストリ未登録の非既定アカウントでも、その環境変数から導出した鍵への記録は通す。未知の入力上の穴が見つかるたびに検査を足して塞ぎ切ることは、この要件の完了条件にしない。snapshot の書込条件の守備範囲は `rate-snapshot` の要件に従う。

#### Scenario: 既定アカウントのセッションは default に書く
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` を未設定にし、`rate_limits` を含む JSON で statusline を実行する
- **THEN** 記録ディレクトリに `default.json` ができ、`five_hour_pct` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_epoch` が stdin の値と一致し、`key` が `default` である

#### Scenario: B のセッションは B の鍵にだけ書く
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` を B のディレクトリにし、accounts.json に A（既定）と B を登録し、usage snapshot の `active` を A にした状態で statusline を実行する
- **THEN** 記録ディレクトリには B の鍵（B のディレクトリの sha256 先頭 8 桁）のファイルだけが書かれ、`default.json` は作られも変更されもしない

#### Scenario: レジストリに無いアカウントでも自分の鍵に書く
- **WHEN** accounts.json に登録されていない `CLAUDE_SECURESTORAGE_CONFIG_DIR` で statusline を実行する
- **THEN** その値から導出した鍵のファイルにだけ書かれ、登録済みスロットの鍵のファイルは変わらない

#### Scenario: 止まっていたセッションが古い値で描き直しても記録は新しいセッションの値のまま
- **WHEN** 同じアカウントのセッション X が週次 40% を受け取って記録を書き、続いてセッション Y が週次 60% を受け取って記録を書き、そのあと X が週次 40% のまま同じ値で描き直す
- **THEN** 記録の週次は 60% のまま、`observed_at` も Y が書いた時刻のままである

#### Scenario: セッションが新しい値を受け取れば記録を書く
- **WHEN** 上の状態のあと X が週次 45% を受け取って描き直す
- **THEN** 記録の週次は 45% になり、`observed_at` は X のその描画の時刻になる

#### Scenario: 週次だけの描画でも記録を書く
- **WHEN** `rate_limits` に `seven_day` だけがある JSON で statusline を実行する
- **THEN** 記録は妥当な JSON で、`weekly_all_pct` / `weekly_resets_epoch` が stdin の値と一致し、`five_hour_pct` / `five_hour_resets_epoch` は `null` である

#### Scenario: 週次だけの同じ値の描き直しでは書かない
- **WHEN** 同じセッションが `seven_day` だけの同じ値で statusline を再実行する
- **THEN** 記録は書き直されず、`observed_at` は前回の値のままである

#### Scenario: 5 時間枠が戻れば記録を書く
- **WHEN** 週次だけの記録を書いたセッションが、同じ週次の値に `five_hour` が加わった JSON で statusline を実行する
- **THEN** 記録の `five_hour_pct` は stdin の値になり、`observed_at` はその描画の時刻になる

#### Scenario: rate_limits が無ければ書かない
- **WHEN** `rate_limits` を含まない JSON で statusline を実行する
- **THEN** 記録ディレクトリにファイルは作られない

#### Scenario: 記録ディレクトリに書けなくても表示は変わらない
- **WHEN** 記録ディレクトリの親が書き込み不可の状態で statusline を実行する
- **THEN** statusline は exit 0 で、記録が書けた場合と同じ出力を返す

## ADDED Requirements

### Requirement: 5 時間枠が null の値を欠測として読む
セッション記録または usage snapshot の `five_hour_pct` が `null` のとき、harness の読み手（`usage_view.py` と、それを使う `headroom.py`・`select-account.sh`、statusline の非 active スロットの値の選択）はその情報源の 5 時間枠を欠測として扱い、同じ情報源の週次の値を通常どおり読まなければならない（SHALL）。`null` を 0 として扱ってはならず（MUST NOT）、異常終了してはならない（MUST NOT）。`usage-probe.sh` は使用量 API の応答の `five_hour` が `null` でも週次の値があれば取得成功として扱い、snapshot の `five_hour_pct` を `null` で書かなければならない（SHALL）。

**守備範囲**: ①入力の出どころは、このマシンの statusline と usage-probe が書いた記録と snapshot の `five_hour_pct`、および使用量 API の応答の `five_hour` である。②拾いたい誤りは、`null` を 0 と読むこと、`null` で読み手が落ちて週次の値まで失うことである。③`five_hour` のキーが無い応答、未知のキーを持つ応答・記録、`five_hour_pct` が `null` でリセット時刻だけに値がある記録は通す。④未知の穴が見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 週次だけの記録を実効値にする
- **WHEN** 既定アカウントのセッション記録の `five_hour_pct` が `null`、`weekly_all_pct` が 12、`weekly_resets_epoch` が現在より後で、snapshot にそのスロットの値が無い状態で実効値を求める
- **THEN** 実効値の `weekly_all_pct` は 12、`five_hour_pct` は `null` である

#### Scenario: 5 時間枠が欠測でも選択の候補に残る
- **WHEN** どのスロットの実効値の `five_hour_pct` も `null` で、週次の値とリセット前のリセット時刻は揃っている状態で headroom を求める
- **THEN** 週次の余りで `best` が決まり、5 時間枠を理由に候補から外されない

### Requirement: 片方の情報源に残る 5 時間枠の値は規則どおり使う
新しい記録の 5 時間枠が `null` で、もう一方の情報源に 5 時間枠の値があるときは、要件「記録と snapshot から実効値を求める」の規則どおりその値を使わなければならない（SHALL）。5 時間枠が無くなった移行のための特別な扱いを読み手に足してはならない（MUST NOT）。

#### Scenario: 片方の情報源に残る 5 時間枠の値を使う
- **WHEN** セッション記録の `five_hour_pct` が `null` で、snapshot の同じスロットに 5 時間枠の値とリセット前のリセット時刻がある状態で実効値を求める
- **THEN** 実効値の `five_hour_pct` は snapshot の値である
