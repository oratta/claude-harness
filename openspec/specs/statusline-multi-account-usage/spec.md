# statusline-multi-account-usage Specification

## Purpose
statusline がレートリミットをアカウント（スロット）別に描画する要件を定める。いま使っているアカウントはライブ値で、それ以外は usage snapshot の値と取得からの経過時間で描く。スロットが 1 つのときは従来と 1 バイトも変わらない出力になることを最優先の制約とする。

## Requirements
### Requirement: 値が得られたスロットごとにレートリミット行を描画する
`plugins/statusline/scripts/statusline.sh` は、レジストリのスロットのうち**値が得られたものについて**レートリミットを描画しなければならない（SHALL）。行の並びはレジストリの宣言順とする。

各スロットの行の出し方は現行の入れ子条件をスロット単位に適用したものでなければならない（SHALL）:

- 5h 消化率が得られないスロットは、そのスロットの行を 1 行も出してはならない（MUST NOT）
- 5h 消化率が得られたスロットは `5h` 行を出す
- `5h` 行を出したスロットのうち、7d 消化率も得られたものだけ `7d All`（+ 条件を満たせば `Fable`）行を出す

スロットが複数あるときは各行の左端にスロットの `label` を置く。label 列の幅は文字数ではなく**表示幅**（East Asian Width が W / F の文字を 2 桁と数える）で揃えなければならない（SHALL）。全角のラベル（`仕事` など）でバーの左端がずれないようにするため。バーの描画・色分け・日程線・分母表示（例 `82%/74%`）は既存の描画関数（`bar_seg` / `bar2`）をそのまま使い、意味論を変えてはならない（MUST NOT）。

目標レイアウト:

```
A  5h      ▓▓▓▓▓▓▓▓░░░░░░░░  55%          ~4h 12m
A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  82%/74%   Fable ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  94%   ~2d 3h
B  5h      ░░░░░░░░░░░░░░░░   3%
B  7d All  ░░░░░░░░░░░░░░░░   1%/0%    Fable ░░░░░░░░░░░░░░░░   0%   2h前
```

#### Scenario: 全角ラベルでも列が揃う
- **WHEN** `label` が `仕事`（表示幅 4）のスロットと `B`（表示幅 1）のスロットを含むレジストリで statusline を実行する
- **THEN** 両スロットの行で `5h` / `7d All` の開始位置（表示幅）が一致する

#### Scenario: 2 スロットで 4 行が出る
- **WHEN** 2 スロットのレジストリと、両スロットの値を含む snapshot を与えて statusline を実行する
- **THEN** レートリミット表示はスロットごとに 2 行、計 4 行になり、各行の左端にそのスロットの `label` が付く

#### Scenario: 欠測スロットは行を出さない
- **WHEN** 2 スロットのレジストリで、片方のスロットの値が全て `null`（欠測）である snapshot を与えて statusline を実行する
- **THEN** 値のあるスロットの 2 行だけが出て、欠測スロットの行は出ない

#### Scenario: 7d が欠ければ 5h 行だけ出す
- **WHEN** あるスロットの 5h 消化率は得られるが 7d 消化率が得られない状態で statusline を実行する
- **THEN** そのスロットは `5h` 行だけを出し、`7d All` 行は出さない

#### Scenario: rate_limits が来ないときはレートリミット行が 1 行も出ない
- **WHEN** stdin に `rate_limits` が含まれず、snapshot も存在しない状態で statusline を実行する
- **THEN** レートリミット行は 1 行も出ない（現行と同じ）

#### Scenario: バー描画の意味論が変わらない
- **WHEN** 複数スロットの statusline 出力を検査する
- **THEN** バーの塗り・日程線・分母表示は 1 スロット時と同じ関数で生成された形式である

### Requirement: スロットが 1 つのときは現行と同一の出力にする
スロットが 1 つだけのとき（レジストリ不在を含む）、statusline のレートリミット表示はこの変更の前と**バイト単位で同一**でなければならない（SHALL）。`label` 列を出してはならない（MUST NOT）。

#### Scenario: レジストリ不在で現行と同一
- **WHEN** レジストリファイルが存在しない状態で、変更前と同じ stdin と snapshot を与えて statusline を実行する
- **THEN** 出力は変更前の出力とバイト単位で一致し、`label` 列は現れない

#### Scenario: 1 スロットのレジストリでも label を出さない
- **WHEN** スロットを 1 つだけ持つレジストリを与えて statusline を実行する
- **THEN** 出力に `label` 列は現れない

#### Scenario: schema 1 の snapshot でも描画できる
- **WHEN** `accounts` を持たない schema 1 の snapshot を与えて statusline を実行する
- **THEN** トップレベルのキーから既定スロット 1 つとして現行どおり描画される

### Requirement: active スロットはライブ値、非 active スロットは snapshot 値と経過時間で描く
active スロットのレートリミットは stdin の `.rate_limits.*` のライブ値から描画しなければならない（SHALL）。非 active スロットは snapshot の `accounts` の値から描画し、行末にそのスロットの `fetched_at` からの経過時間（例 `2h前`）を併記しなければならない（SHALL）。

#### Scenario: active スロットにライブ値を使う
- **WHEN** stdin の `.rate_limits` と snapshot の active スロットの値が異なる状態で statusline を実行する
- **THEN** active スロットの行は stdin のライブ値で描画される

#### Scenario: 非 active スロットに経過時間が付く
- **WHEN** 非 active スロットの `fetched_at` が現在より 2 時間前である snapshot を与えて statusline を実行する
- **THEN** その非 active スロットの行末に取得からの経過時間が表示される

### Requirement: 6 時間の鮮度ゲートは active スロットにのみ適用する
現行の statusline は Fable バーを snapshot の `fetched_at` が 6 時間以内のときだけ描く鮮度ゲートを持つ。このゲートは **active スロットにのみ適用しなければならない**（SHALL）。非 active スロットに適用してはならない（MUST NOT）。

非 active アカウントはトークンの期限切れでフェッチが落ちるのが常態で、値は日単位で古くなる（`usage-snapshot-multi-account` の design D4）。ゲートを非 active にも適用すると、非 active 行は 6 時間後に黙って消え、鮮度を経過時間の併記でユーザーに委ねるという設計そのものが成立しない。逆にゲートを active から外すと、古い snapshot のケースで 1 スロット時のバイト同一性が破れる。

#### Scenario: active スロットのゲートは現行どおり
- **WHEN** active スロットの `fetched_at` が 6 時間より古い snapshot を与えて statusline を実行する
- **THEN** active スロットの Fable バーは描かれない（現行と同じ）

#### Scenario: 非 active スロットはゲートで消えない
- **WHEN** 非 active スロットの `fetched_at` が 6 時間より古い（例: 2 日前）snapshot を与えて statusline を実行する
- **THEN** その非 active スロットの Fable バーは描かれ、行末に経過時間が併記される

### Requirement: 非 active スロットの resets_at が過去のときは分母と残り時間を出さない
非 active スロットは値が日単位で古くなるため、snapshot の `weekly_resets_epoch` / `five_hour_resets_epoch` が現在時刻より過去になるのが常態である。窓の残り時間が正の範囲に無いスロットについては、日程消化率の分母表示（例 `82%/74%`）と残り時間を出してはならない（MUST NOT）。バー本体は消化率だけで描く（現行の `bar_seg` に空の日程消化率を渡した場合と同じ挙動）。

#### Scenario: リセット時刻が過去なら分母を出さない
- **WHEN** 非 active スロットの `weekly_resets_epoch` が現在より過去である snapshot を与えて statusline を実行する
- **THEN** その行に日程消化率の分母と残り時間は表示されず、バーは消化率だけで描かれる

### Requirement: active スロット判定は共通規則に従う
statusline の active スロット判定は、`usage-account-registry` capability の「active スロットの判定規則」（`CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出した Keychain サービス名での突き合わせ → snapshot の `active` → 最初のスロット）に従わなければならない（SHALL）。

statusline サブプロセスへの環境変数の伝播が保証されていないため、snapshot へのフォールバックが必要である。

#### Scenario: env から判定する
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が 2 番目のスロットの `securestorage` と一致する状態で statusline を実行する
- **THEN** snapshot の `active` が別のスロットを指していても、2 番目のスロットが active として扱われる

#### Scenario: env が無ければ snapshot にフォールバックする
- **WHEN** 既定スロットを持たない（全スロットが explicit な `securestorage` を持つ）レジストリで `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定、かつ snapshot の `active` が 2 番目のスロットを指す状態で statusline を実行する
- **THEN** 優先順位 1 が空振りし、2 番目のスロットが active として扱われる

#### Scenario: env が未設定でも既定スロットには一致する
- **WHEN** 既定スロットを含むレジストリで `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定、かつ snapshot の `active` が別のスロットを指す状態で statusline を実行する
- **THEN** 優先順位 1 が既定スロットに一致し、既定スロットが active として扱われる

