## ADDED Requirements

### Requirement: 前景実行の結果は実行の開始と終了の時刻を持つ
前景実行の結果の 1 行 JSON は、「前景実行の結果は 1 行の JSON で返す」のキーに加えて、実行の開始の時刻 `started_at` と終了の時刻 `ended_at` を含まなければならない（MUST）。値は UTC の ISO8601 で秒までの `YYYY-MM-DDTHH:MM:SSZ` とする。`started_at` は依頼を読む前に取り、`ended_at` は一時領域を片付けたあと結果を出す直前に取る。どちらも時計から必ず取れる値なので、成功・失敗・ターンが始まらなかった場合を問わず `null` にしてはならない（MUST NOT）。`started_at` は `ended_at` より後であってはならない（MUST NOT）。

#### Scenario: ターンが完走した結果に時刻が入る
- **WHEN** 前景実行のターンが完了する
- **THEN** 1 行 JSON の `started_at` と `ended_at` は `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$` に一致し、`started_at` は `ended_at` 以前で、どちらも呼び出し側が worker を起動した前後の時刻の範囲に入る

#### Scenario: ターン開始前に失敗した結果にも時刻が入る
- **WHEN** 利用枠の確認やアカウントの照合で失敗し、ターンが始まらない
- **THEN** 同じ形の 1 行 JSON に `started_at` と `ended_at` が同じ書式で入り、`null` ではない
