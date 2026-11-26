## MODIFIED Requirements

### Requirement: statusline は既定アカウントの枠観測だけを書く

harness の `plugins/statusline/scripts/statusline.sh` は、stdin JSON の `rate_limits.five_hour.used_percentage` と `rate_limits.seven_day.used_percentage` の少なくとも一方と、空でない文字列 `session_id` が得られ、かつ `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定または空のときだけ snapshot を書かなければならない（MUST）。条件を満たさない場合は既存のローカル・共有 snapshot を変えず、表示を続けなければならない（MUST）。ローカルの保存先は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rate-limit-snapshot` とする。枠が欠けた場合に使用率ゼロを捏造してはならない（MUST NOT）。

**守備範囲**: 判定する入力は Claude Code が statusline に渡す stdin JSON と、起動環境の `CLAUDE_SECURESTORAGE_CONFIG_DIR` である。拾いたい誤りは、5h と 7d の使用率の両方、または空でない文字列の `session_id` が欠けた描画、非既定アカウントの描画から snapshot を書くことである。5h 使用率が `0` の入力、7d 使用率だけがある入力や、`session_id` が `session/a:01` のように記号を含む入力は、この条件を満たせば通す。使用率の意味上の範囲や `session_id` の文字種を網羅的に検査し、未知の穴が見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 5h 枠と出所がある
- **WHEN** 既定アカウントの入力に 5h 使用率と空でない `session_id` がある
- **THEN** ローカル snapshot を書き、取得できた枠値を保存し、欠けた 7d 値やリセット時刻は `null` とする

#### Scenario: 7d 枠と出所だけがある
- **WHEN** 既定アカウントの入力に 7d 使用率と空でない `session_id` があり、`rate_limits.five_hour` が無い
- **THEN** ローカル snapshot を書き、`seven_day_pct` と `seven_day_resets_at` は入力と一致し、`five_hour_pct` と `five_hour_resets_at` は `null` である

#### Scenario: 入力の枠または出所が欠ける
- **WHEN** 5h と 7d の使用率の両方がない入力、または空でない `session_id` がない入力を受ける
- **THEN** snapshot は更新せず statusline を表示する

#### Scenario: 非既定アカウント
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空の入力を受ける
- **THEN** ローカルも共有も更新せず statusline を表示する

### Requirement: snapshot は観測値・時刻・出所を記録する

書かれる JSON は `ts`、`observed_at`、`written_at`、`obs_sig`、`host`、`storage_binding`、`session_id`、`five_hour_pct`、`five_hour_resets_at`、`seven_day_pct`、`seven_day_resets_at` を持たなければならない（MUST）。枠値は入力の対応する値を使い、欠損する任意の値は `null` とする。枠が欠けてもキーを省いてはならず（MUST NOT）、`0` を書いてはならない（MUST NOT）。`written_at` は書込時の epoch 秒、`ts` は `observed_at` と同値とする。`session_id` は stdin JSON の文字列を JSON として損失なく記録し、実アカウントや認証世代の証明として扱ってはならない（MUST NOT）。

`storage_binding` はプロセスの `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定または空なら `storage-v1:default`、非空なら元の環境変数バイト列を小文字 hex にした `storage-v1:bytes:<hex>` とする。値をパスとして正規化してはならない（MUST NOT）。`host` は `hostname -s` を取得し、`A-Za-z0-9._-` 以外を `_` に置き換えた値とする。ホスト名を取得できない・空になる場合は `unknown` とする。

#### Scenario: 通常の観測
- **WHEN** 5h と 7d の枠値、リセット時刻、引用符や改行を含みうる `session_id` を受ける
- **THEN** 全ての必須キーを持つ妥当な JSON が書かれ、`ts == observed_at`、`storage_binding == "storage-v1:default"`、`session_id` は入力と一致する

#### Scenario: 5h 枠が無い観測
- **WHEN** 7d の枠値とリセット時刻だけを受ける
- **THEN** 全ての必須キーを持つ妥当な JSON が書かれ、`five_hour_pct` と `five_hour_resets_at` はキーがあって値が `null` である。共有先を設定していれば共有ファイルの本文も同じである

#### Scenario: ホスト名の安全化
- **WHEN** `hostname -s` にファイル名安全文字以外が含まれる
- **THEN** `host` ではその文字が `_` に置換される

### Requirement: 再表示は観測時刻を新鮮に見せかけない

writer はこれから書く 5h 使用率・5h リセット・7d 使用率・7d リセットの値から `obs_sig` を作らなければならない（MUST）。欠ける値は `null` の文字列として `obs_sig` に入れ、5h 使用率がない観測でも同じ作り方で作らなければならない（MUST）。5h と 7d の使用率がどちらもある観測の `obs_sig` の文字列は変えてはならない（MUST NOT）。前回ローカル snapshot の `obs_sig`、`storage_binding`、`session_id` が全て今回と同じ場合だけ `observed_at` を継承し、それ以外は現在時刻としなければならない（MUST）。同じ値の再表示では `written_at` だけを進める。旧形式など条件が欠ける前回ファイルから観測時刻を継承してはならない（MUST NOT）。

**守備範囲**: 判定する入力は今回の stdin から作る枠値・`session_id` と、writer が前回書いたローカル snapshot の比較用フィールドである。拾いたい誤りは、枠値や出所が変わったのに古い `observed_at` を引き継ぐことと、比較に必要なフィールドが欠ける旧形式から時刻を引き継ぐことである。`session_id` に引用符や改行があっても、前回と同じ文字列なら比較に通す。session ID の文字種や前回ファイルの追加キーまで検査し、未知の穴が見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 同一観測の再表示
- **WHEN** 同じ枠値・保存先印・`session_id` で再実行する
- **THEN** `observed_at` と `ts` は前回値のままで、`written_at` は新しい書込時刻になる

#### Scenario: 5h 枠が無い観測の再表示
- **WHEN** 5h 枠が無い同じ 7d の枠値・保存先印・`session_id` で再実行する
- **THEN** `observed_at` と `ts` は前回値のままで、`written_at` は新しい書込時刻になる

#### Scenario: 5h 枠が戻る
- **WHEN** 5h 枠が無い観測を書いたあと、同じ 7d の枠値に 5h の枠値が加わった入力を受ける
- **THEN** `observed_at` と `ts` は現在の観測時刻になり、`five_hour_pct` は入力の値になる

#### Scenario: 値または出所が変わる
- **WHEN** 枠値、保存先印、`session_id` のいずれかが変わるか、前回ファイルに必要な帰属がない
- **THEN** `observed_at` と `ts` は現在の観測時刻になる

## ADDED Requirements

### Requirement: snapshot の 5h 枠の null は欠測を表す
ローカルと共有先の snapshot の `five_hour_pct` と `five_hour_resets_at` の `null` は、その観測に 5h 枠が無かったこと（欠測）を表し、使用率 0 を表さない。snapshot の読み手は、この `null` を判定・表示・記録のどれでも使用率 0 として扱ってはならない（MUST NOT）。5h 枠が欠測でも、同じ snapshot の 7d の値は読まなければならない（SHALL）。

**守備範囲**: ①入力の出どころは writer が書くローカルと共有先の snapshot である。②拾いたい誤りは、`null` を 0 と読むことと、5h 枠の欠測で 7d の値まで捨てることである。③未知のキーを持つ snapshot、`five_hour_pct` が `null` で `five_hour_resets_at` だけに値がある snapshot は通す。④このリポジトリで検証するのは writer が `null` を書き `0` を書かないことまでで、連携先の読み手の追従は連携先の issue で行う。未知の穴が見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 週次だけの snapshot の読まれ方
- **WHEN** `five_hour_pct` が `null` で `seven_day_pct` が 12 の共有 snapshot を読み手が読む
- **THEN** 5h 枠は欠測として扱われ、使用率 0 にならず、7d の使用率は 12 として読まれる
