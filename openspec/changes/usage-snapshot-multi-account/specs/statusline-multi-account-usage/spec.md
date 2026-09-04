## ADDED Requirements

### Requirement: レートリミット行をスロット別に描画する
`plugins/statusline/scripts/statusline.sh` は、レジストリのスロットごとにレートリミットを 2 行（`5h` 行と `7d All` + `Fable` 行）描画しなければならない（SHALL）。スロットが複数あるときは各行の左端にスロットの `label` を置く。行の並びはレジストリの宣言順とする。

バーの描画・色分け・日程線・分母表示（例 `82%/74%`）は既存の描画関数（`bar_seg` / `bar2`）をそのまま使い、意味論を変えてはならない（MUST NOT）。

目標レイアウト:

```
A  5h      ▓▓▓▓▓▓▓▓░░░░░░░░  55%          ~4h 12m
A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  82%/74%   Fable ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  94%   ~2d 3h
B  5h      ░░░░░░░░░░░░░░░░   3%
B  7d All  ░░░░░░░░░░░░░░░░   1%/0%    Fable ░░░░░░░░░░░░░░░░   0%   2h前
```

#### Scenario: 2 スロットで 4 行が出る
- **WHEN** 2 スロットのレジストリと、両スロットの値を含む snapshot を与えて statusline を実行する
- **THEN** レートリミット表示はスロットごとに 2 行、計 4 行になり、各行の左端にそのスロットの `label` が付く

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
active スロットのレートリミットは stdin の `.rate_limits.*` のライブ値から描画しなければならない（SHALL）。非 active スロットは snapshot の値から描画し、行末に snapshot の取得時刻からの経過時間（例 `2h前`）を併記しなければならない（SHALL）。

#### Scenario: active スロットにライブ値を使う
- **WHEN** stdin の `.rate_limits` と snapshot の active スロットの値が異なる状態で statusline を実行する
- **THEN** active スロットの行は stdin のライブ値で描画される

#### Scenario: 非 active スロットに経過時間が付く
- **WHEN** 非 active スロットの取得時刻が現在より 2 時間前である snapshot を与えて statusline を実行する
- **THEN** その非 active スロットの行末に取得からの経過時間が表示される

### Requirement: active スロット判定は env 優先で snapshot にフォールバックする
active スロットの判定は `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値をレジストリの `securestorage` と突き合わせて行うことを優先しなければならない（SHALL）。環境変数が取得できない場合は、snapshot の `active` フィールドにフォールバックしなければならない（SHALL）。どちらも得られない場合は最初のスロットを active とする。

statusline サブプロセスへの環境変数の伝播が保証されていないため、この二段構えが必要である。

#### Scenario: env から判定する
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が 2 番目のスロットの `securestorage` と一致する状態で statusline を実行する
- **THEN** snapshot の `active` が別のスロットを指していても、2 番目のスロットが active として扱われる

#### Scenario: env が無ければ snapshot にフォールバックする
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が未設定で、snapshot の `active` が 2 番目のスロットを指す状態で statusline を実行する
- **THEN** 2 番目のスロットが active として扱われる
