## MODIFIED Requirements

### Requirement: 値が得られたスロットごとにレートリミット行を描画する
`plugins/statusline/scripts/statusline.sh` は、レジストリのスロットのうち**値が得られたものについて**レートリミットを描画しなければならない（SHALL）。行の並びはレジストリの宣言順とする。

各スロットの行の出し方は現行の入れ子条件をスロット単位に適用したものでなければならない（SHALL）:

- 5h 消化率が得られない非 active スロットは行を出さない。複数スロットの active が欠測なら、同じ目印・label 列で `取得待ち` を1行出さなければならない（SHALL）。使用率や snapshot の値をライブ値として補ってはならない（MUST NOT）
- 5h 消化率が得られたスロットは `5h` 行を出す
- `5h` 行を出したスロットのうち、7d 消化率も得られたものだけ `7d All`（+ 条件を満たせば `Fable`）行を出す

スロットが複数あるときは各行の左端を「active の目印（表示幅 2。要件「active スロットの行を視覚的に示す」）＋ 名前の列」の順で構成しなければならない（SHALL）。名前は「サービス名 + 半角スペース + アカウント名」とし、Claude のスロットは `Claude <label>`（`<label>` はレジストリのスロットの `label`）、Codex の行は `Codex <label>`（`<label>` は要件「Codex の表示名を codex.label で決める」で決まる値）とする。目印の列は active / 非 active を問わず全行が等しく表示幅 2 を占め、非 active 行では半角スペース 2 つで埋める。名前の列の幅は文字数ではなく**表示幅**（East Asian Width が W / F の文字を 2 桁と数える）で揃えなければならない（SHALL）。アカウント名（`<label>`）の表示幅が 8 を超える場合は 8 桁に切り詰めたものを使う（`usage-account-registry` capability の `label` の規定に従う。長い label で全行が押し出されるのを防ぐ）。切り詰めるのはアカウント名の部分だけで、サービス名（`Claude ` / `Codex `）は常に残さなければならない（SHALL。名前全体を 8 桁に切ると `Claude 仕事` が `Claude 仕` のように中途半端に切れ、どのアカウントか分からなくなるため）。したがって名前の最大幅は `Claude ` の 7 桁 + 8 桁 = 15 桁で、名前の列の幅は表示される名前の表示幅の最大値とする。目印の列と名前の列の幅がどちらも全行で等しいことにより、バーの左端は全角のラベル（`仕事` など）を含めて揃う。バーの描画・色分け・日程線・分母表示（例 `82%/74%`）は既存の描画関数（`bar_seg` / `bar2`）をそのまま使い、意味論を変えてはならない（MUST NOT）。要件「enabled が false のスロットは off の 1 行にする」の目標レイアウトとシナリオにある `A` / `B`（例 `  B  off`）は、`Claude A` / `Claude B`（例 `  Claude B  off`）に読み替える（この要件が優先する）。

目標レイアウト:

```
▸ Claude A  5h      ▓▓▓▓▓▓▓▓░░░░░░░░  55%          ~4h 12m
▸ Claude A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  82%/74%   Fable ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  94%   ~2d 3h
  Claude B  5h      ░░░░░░░░░░░░░░░░   3%
  Claude B  7d All  ░░░░░░░░░░░░░░░░   1%/0%    Fable ░░░░░░░░░░░░░░░░   0%   2h前
```

#### Scenario: 全角ラベルでも列が揃う
- **WHEN** `label` が `仕事`（表示幅 4）のスロットと `B`（表示幅 1）のスロットを含むレジストリで statusline を実行する
- **THEN** 両スロットの行で `5h` / `7d All` の開始位置（表示幅）が一致する。名前は `Claude 仕事` と `Claude B` になる

#### Scenario: 2 スロットで 4 行が出る
- **WHEN** 2 スロットのレジストリと、両スロットの値を含む snapshot を与えて statusline を実行する
- **THEN** レートリミット表示はスロットごとに 2 行、計 4 行になり、各行の左端に active の目印とそのスロットの名前（`Claude <label>`）が付く

#### Scenario: Claude のスロットの名前は Claude とアカウント名になる
- **WHEN** スロット `a`（`label` が `A`）とスロット `b`（`label` が `B`）を持つレジストリで statusline を実行する
- **THEN** 行頭の名前は `Claude A` と `Claude B` になる

#### Scenario: 長いアカウント名はアカウント名の部分だけ切る
- **WHEN** `label` が表示幅 8 を超える文字列（例 `abcdefghijkl`）のスロットを含むレジストリで statusline を実行する
- **THEN** 名前は `Claude abcdefgh` になり、サービス名 `Claude ` は切られない

#### Scenario: 欠測スロットは行を出さない
- **WHEN** 2 スロットのレジストリで、非 active スロットの値が全て `null`（欠測）である snapshot を与えて statusline を実行する
- **THEN** 値のあるスロットの 2 行だけが出て、欠測スロットの行は出ない

#### Scenario: 7d が欠ければ 5h 行だけ出す
- **WHEN** あるスロットの 5h 消化率は得られるが 7d 消化率が得られない状態で statusline を実行する
- **THEN** そのスロットは `5h` 行だけを出し、`7d All` 行は出さない

#### Scenario: rate_limits が来ないときはレートリミット行が 1 行も出ない
- **WHEN** stdin に `rate_limits` が含まれず、snapshot も存在しない状態で statusline を実行する
- **THEN** 数値を含むレートリミット行は出ない。複数スロットの場合のみ active の目印・label と `取得待ち` の行を出す。

#### Scenario: バー描画の意味論が変わらない
- **WHEN** 複数スロットの statusline 出力を検査する
- **THEN** バーの塗り・日程線・分母表示は 1 スロット時と同じ関数で生成された形式である

## ADDED Requirements

### Requirement: Codex の行の名前は Codex とアカウント名にする
Codex の行の左端の名前は `Codex <label>` でなければならない（SHALL）。`<label>` は要件「Codex の表示名を codex.label で決める」（`usage-account-registry` capability）で決まる値で、`codex.label` が無ければ `A` である。Codex の行の有無・取得・オフの扱いはこの要件で変えない（MUST NOT）。既存の要件「Codex がオフのとき Codex 行は off を出し、取得しない」と、`取得待ち` の行にある固定のラベル `Codex`（例 `Codex  off`）は `Codex <label>` に読み替える（この要件が優先する。例 `Codex A  off`）。オフの行の有無と `off` の文言は変えない（MUST NOT。オフの行の扱いは別の change の範囲）。名前の列の幅は Claude のスロットの名前と共通の最大値で揃える。

スロットが 1 つ以下（レジストリ不在を含む）のとき、Claude 側の行には名前を出さない現行のままとし（バイト単位で同一）、Codex の行だけが `Codex <label>` を名前として持つ。

#### Scenario: codex.label が無ければ Codex A
- **WHEN** Codex の値が得られる状態で、`codex.label` を持たないレジストリを与えて statusline を実行する
- **THEN** Codex の行の名前は `Codex A` になる

#### Scenario: codex.label があればそれを使う
- **WHEN** Codex の値が得られる状態で、レジストリのトップレベルが `"codex": {"label": "X"}` を持つ
- **THEN** Codex の行の名前は `Codex X` になる

#### Scenario: Codex が無くスロットが 1 つなら出力は変わらない
- **WHEN** Codex の行が出ない状態で、レジストリ不在またはスロット 1 つのレジストリを与えて statusline を実行する
- **THEN** 出力は変更前とバイト単位で一致する
