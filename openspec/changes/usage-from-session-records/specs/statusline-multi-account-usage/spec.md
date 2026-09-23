## MODIFIED Requirements

### Requirement: active スロットはライブ値、非 active スロットは snapshot 値と経過時間で描く
active スロットのレートリミットは stdin の `.rate_limits.*` のライブ値から描画しなければならない（SHALL）。非 active スロットは、そのスロットの鍵のセッション記録（`usage-session-records` capability）と snapshot の `accounts` の値から、`usage-session-records` の「記録と snapshot から実効値を求める」規則の 4（同じ窓なら大きい方、窓が違えば新しい窓）で選んだ値を描画し、行末に採った値の取得時刻（セッション記録は `observed_at`、snapshot は `fetched_at`）からの経過時間（例 `2h前`）を併記しなければならない（SHALL）。Fable バーは snapshot の値から描く。statusline は他プラグインのスクリプトを実行時に読まず、この規則を自分で実装しなければならない（SHALL）。

#### Scenario: active スロットにライブ値を使う
- **WHEN** stdin の `.rate_limits` と snapshot の active スロットの値が異なる状態で statusline を実行する
- **THEN** active スロットの行は stdin のライブ値で描画される

#### Scenario: 非 active スロットに経過時間が付く
- **WHEN** 非 active スロットの `fetched_at` が現在より 2 時間前である snapshot を与え、そのスロットのセッション記録が無い状態で statusline を実行する
- **THEN** その非 active スロットの行末に取得からの経過時間が表示される

#### Scenario: 非 active スロットはセッション記録の新しい値で描く
- **WHEN** 非 active スロット B の snapshot の値が 5 時間前の週次 40% で、B の鍵のセッション記録が 3 分前の週次 45%（同じリセット時刻）である状態で、A のセッションとして statusline を実行する
- **THEN** B の行は週次 45% で描かれ、行末の経過時間は記録の `observed_at` からの時間になる
