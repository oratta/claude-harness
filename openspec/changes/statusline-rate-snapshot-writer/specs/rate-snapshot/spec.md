## ADDED Requirements

### Requirement: statusline は既定アカウントの枠観測だけを書く

harness の `plugins/statusline/scripts/statusline.sh` は、stdin JSON の `rate_limits.five_hour.used_percentage` と空でない文字列 `session_id` が得られ、かつ `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定または空のときだけ snapshot を書かなければならない（MUST）。条件を満たさない場合は既存のローカル・共有 snapshot を変えず、表示を続けなければならない（MUST）。ローカルの保存先は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rate-limit-snapshot` とする。枠が欠けた場合に使用率ゼロを捏造してはならない（MUST NOT）。

#### Scenario: 5h 枠と出所がある
- **WHEN** 既定アカウントの入力に 5h 使用率と空でない `session_id` がある
- **THEN** ローカル snapshot を書き、取得できた枠値を保存し、欠けた 7d 値やリセット時刻は `null` とする

#### Scenario: 入力の枠または出所が欠ける
- **WHEN** 5h 使用率または空でない `session_id` がない入力を受ける
- **THEN** snapshot は更新せず statusline を表示する

#### Scenario: 非既定アカウント
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空の入力を受ける
- **THEN** ローカルも共有も更新せず statusline を表示する

### Requirement: snapshot は観測値・時刻・出所を記録する

書かれる JSON は `ts`、`observed_at`、`written_at`、`obs_sig`、`host`、`storage_binding`、`session_id`、`five_hour_pct`、`five_hour_resets_at`、`seven_day_pct`、`seven_day_resets_at` を持たなければならない（MUST）。枠値は入力の対応する値を使い、欠損する任意の値は `null` とする。`written_at` は書込時の epoch 秒、`ts` は `observed_at` と同値とする。`session_id` は stdin JSON の文字列を JSON として損失なく記録し、実アカウントや認証世代の証明として扱ってはならない（MUST NOT）。

`storage_binding` はプロセスの `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定または空なら `storage-v1:default`、非空なら元の環境変数バイト列を小文字 hex にした `storage-v1:bytes:<hex>` とする。値をパスとして正規化してはならない（MUST NOT）。`host` は `hostname -s` を取得し、`A-Za-z0-9._-` 以外を `_` に置き換えた値とする。ホスト名を取得できない・空になる場合は `unknown` とする。

#### Scenario: 通常の観測
- **WHEN** 5h と 7d の枠値、リセット時刻、引用符や改行を含みうる `session_id` を受ける
- **THEN** 全ての必須キーを持つ妥当な JSON が書かれ、`ts == observed_at`、`storage_binding == "storage-v1:default"`、`session_id` は入力と一致する

#### Scenario: ホスト名の安全化
- **WHEN** `hostname -s` にファイル名安全文字以外が含まれる
- **THEN** `host` ではその文字が `_` に置換される

### Requirement: 再表示は観測時刻を新鮮に見せかけない

writer はこれから書く 5h 使用率・5h リセット・7d 使用率・7d リセットの値から `obs_sig` を作らなければならない（MUST）。前回ローカル snapshot の `obs_sig`、`storage_binding`、`session_id` が全て今回と同じ場合だけ `observed_at` を継承し、それ以外は現在時刻としなければならない（MUST）。同じ値の再表示では `written_at` だけを進める。旧形式など条件が欠ける前回ファイルから観測時刻を継承してはならない（MUST NOT）。

#### Scenario: 同一観測の再表示
- **WHEN** 同じ枠値・保存先印・`session_id` で再実行する
- **THEN** `observed_at` と `ts` は前回値のままで、`written_at` は新しい書込時刻になる

#### Scenario: 値または出所が変わる
- **WHEN** 枠値、保存先印、`session_id` のいずれかが変わるか、前回ファイルに必要な帰属がない
- **THEN** `observed_at` と `ts` は現在の観測時刻になる

### Requirement: 有効なアカウント ID だけを追加する

writer は固定パス `$HOME/.claude.json` の `oauthAccount.accountUuid` だけを読み、文字列の前後空白を除去した値が非空・改行なし・256 文字以下なら `account_id` として記録しなければならない（MUST）。非文字列、空、改行あり、長すぎる値、ファイルの欠損・破損ではキー自体を省き、書込と表示を続けなければならない（MUST）。UUID 書式の追加検証はしてはならない（MUST NOT）。他の個人情報キーや秘密資格情報を取得・出力してはならない（MUST NOT）。この ID を認証の証明と呼んではならない（MUST NOT）。

#### Scenario: アカウント ID を取得できる
- **WHEN** `oauthAccount.accountUuid` に有効な文字列がある
- **THEN** snapshot の `account_id` は空白除去後の値になる

#### Scenario: アカウント ID を取得できない
- **WHEN** `$HOME/.claude.json` が無い・不正か `accountUuid` が無効である
- **THEN** `account_id` キーは無く、他の項目の書込と表示は続く

### Requirement: snapshot を原子的にローカルと任意の共有先へ書く

writer は各出力先と同じディレクトリに一時ファイルを書いて `mv -f` で原子的に置換しなければならない（MUST）。共有ディレクトリが設定されていれば `<共有ディレクトリ>/<host>.json` にローカルと同じ JSON 本文を書かなければならない（MUST）。共有ディレクトリは、定義されていれば空文字も含めて `FLATMATE_RATE_SHARE_DIR` を最優先し、未定義なら `FLATMATE_RATE_SHARE_CONF`（既定 `$HOME/.claude/flatmate-rate-share`）の先頭の非コメント・非空行を使用する。両方なければ共有しない。設定ファイル由来のパスは前後空白を除去し、先頭の `~` または `~/` は `$HOME` に展開する。特定の同期サービスのパスを固定してはならない（MUST NOT）。共有先の作成・書込失敗はローカル書込と表示を妨げてはならない（MUST NOT）。

#### Scenario: 環境変数と設定ファイル
- **WHEN** `FLATMATE_RATE_SHARE_DIR` または設定ファイルに共有先がある
- **THEN** 正規化した `host` 名の共有ファイルが作られ、ローカル snapshot と本文が一致する

#### Scenario: 空文字で明示的に共有を無効にする
- **WHEN** 設定ファイルに有効なパスがあっても `FLATMATE_RATE_SHARE_DIR=""` を定義する
- **THEN** 共有ファイルを書かずローカルだけを書く

#### Scenario: 共有先へ書けない
- **WHEN** 設定された共有ディレクトリを作れないか書けない
- **THEN** ローカル snapshot と statusline の表示は成功する

### Requirement: snapshot 拡張後も表示を維持する

writer の追加処理は statusline の既存の出力行を変更してはならない（MUST NOT）。snapshot が書けない場合も描画を継続しなければならない（MUST）。

#### Scenario: writer の成否と表示
- **WHEN** 同じ描画入力を、共有先が利用可能な場合と利用不可の場合に渡す
- **THEN** 出力行は同じであり、既存の描画テストは通る
