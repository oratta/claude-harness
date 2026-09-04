## ADDED Requirements

### Requirement: active スロットの行を視覚的に示す
スロットが複数あるとき、`plugins/statusline/scripts/statusline.sh` は active スロットの行を非 active スロットの行と視覚的に区別しなければならない（SHALL）。区別は**記号と明るさの二重符号化**で行わなければならない（SHALL）:

- **active スロットの行**: 行頭に `▸ `（U+25B8 と半角スペース。表示幅 2）を置き、記号と `label` をどちらも `DIM` ではなく通常の明るさで描く
- **非 active スロットの行**: 行頭に半角スペース 2 つを置き、`label` は `DIM` のまま描く

記号だけ、または明るさだけにしてはならない（MUST NOT）。色が落ちる経路（スクリーンショット、ログやファイルへのリダイレクト、ANSI を解釈しない表示先）では記号が残り、記号が読めない環境（フォントに `▸` が無い）では明るさが残る必要があるため。どちらか一方だけにすると、その手がかりが失われた環境で「どちらのアカウントの数字を見ているか」が分からなくなり、statusline の判断材料としての意味が失われる。記号は主・明るさは補助という位置づけなので、記号自体に `DIM` を掛けてはならない（MUST NOT）。

**目印の記号は East Asian Width が Neutral のものでなければならない**（SHALL）。差し替える場合もこの制約を満たさなければならない。見た目の似た候補 `▶`（U+25B6）・`●`（U+25CF）・`◆`（U+25C6）・`·`（U+00B7）はいずれも Ambiguous なので使ってはならない（MUST NOT）。

理由: この statusline はバー本体（`BAR_GLYPH` 既定 `▂` U+2582、EAW=Ambiguous）を 1 本につき 16 セル並べており、「端末が曖昧幅を半角として扱う」前提の上に成り立っている。ただしバーは全行に等しく現れるため、端末が曖昧幅を全角にしてもすべての行が同じだけ広がるだけで、行どうしの列ずれは起きない。目印はここが違い、記号が出るのは active 行だけで非 active 行は ASCII の半角スペース 2 つになる。EAW=Ambiguous の記号を使うと曖昧幅の解釈の差が初めて**行と行のあいだ**に現れ、曖昧幅を全角に設定した端末では active 行だけが 1 桁右にずれる。EAW=Neutral を選ぶことは、既にある前提を新たに広げないという意味でもある。

active スロットの判定には既存の `active_idx`（`usage-account-registry` capability の「active スロットの判定規則」で確定したもの）をそのまま用いなければならない（SHALL）。描画側で判定を作り直してはならない（MUST NOT）。active スロットの値が欠測で行が出ない場合、目印の付いた行は 1 行も出ない（他のスロットへ目印を移してはならない（MUST NOT））。

#### Scenario: active スロットの行に記号が付く
- **WHEN** 2 スロットのレジストリと両スロットの値を含む snapshot を与えて statusline を実行する
- **THEN** active スロットの 2 行は `▸ ` で始まり、非 active スロットの 2 行は半角スペース 2 つで始まる

#### Scenario: 色が落ちても記号で判別できる
- **WHEN** 複数スロットの statusline 出力から ANSI エスケープをすべて取り除く
- **THEN** active スロットの行は `▸ ` で始まり、非 active スロットの行と区別できる

#### Scenario: active スロットの目印と label は DIM ではない
- **WHEN** 複数スロットの statusline 出力を検査する
- **THEN** active スロットの `▸ ` と `label` にはどちらも `DIM` が適用されておらず、非 active スロットの `label` には適用されている

#### Scenario: 目印の記号は Neutral 幅である
- **WHEN** 出力に使われている目印の記号の East Asian Width を調べる
- **THEN** Neutral であり、Ambiguous の記号（`▶` `●` `◆` `·`）は使われていない

#### Scenario: env で active が切り替わると目印も移る
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` を 2 番目のスロットの `securestorage` に向けて statusline を実行する
- **THEN** `▸ ` は 2 番目のスロットの行に付き、1 番目のスロットの行は半角スペース 2 つで始まる

#### Scenario: active スロットが欠測なら目印の付いた行は出ない
- **WHEN** active スロットの値が全て `null`（欠測）で、非 active スロットにだけ値がある snapshot を与えて statusline を実行する
- **THEN** 出力に `▸ ` で始まる行は無く、非 active スロットの行は半角スペース 2 つで始まる

## MODIFIED Requirements

### Requirement: 値が得られたスロットごとにレートリミット行を描画する
`plugins/statusline/scripts/statusline.sh` は、レジストリのスロットのうち**値が得られたものについて**レートリミットを描画しなければならない（SHALL）。行の並びはレジストリの宣言順とする。

各スロットの行の出し方は現行の入れ子条件をスロット単位に適用したものでなければならない（SHALL）:

- 5h 消化率が得られないスロットは、そのスロットの行を 1 行も出してはならない（MUST NOT）
- 5h 消化率が得られたスロットは `5h` 行を出す
- `5h` 行を出したスロットのうち、7d 消化率も得られたものだけ `7d All`（+ 条件を満たせば `Fable`）行を出す

スロットが複数あるときは各行の左端を「active の目印（表示幅 2。要件「active スロットの行を視覚的に示す」）＋ `label` 列」の順で構成しなければならない（SHALL）。目印の列は active / 非 active を問わず全行が等しく表示幅 2 を占め、非 active 行では半角スペース 2 つで埋める。label 列の幅は文字数ではなく**表示幅**（East Asian Width が W / F の文字を 2 桁と数える）で揃えなければならない（SHALL）。label の表示幅が 8 を超える場合は 8 桁に切り詰めたものを使う（`usage-account-registry` capability の `label` の規定に従う。長い label で全行が押し出されるのを防ぐ）。目印の列と label 列の幅がどちらも全行で等しいことにより、バーの左端は全角のラベル（`仕事` など）を含めて揃う。バーの描画・色分け・日程線・分母表示（例 `82%/74%`）は既存の描画関数（`bar_seg` / `bar2`）をそのまま使い、意味論を変えてはならない（MUST NOT）。

目標レイアウト:

```
▸ A  5h      ▓▓▓▓▓▓▓▓░░░░░░░░  55%          ~4h 12m
▸ A  7d All  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  82%/74%   Fable ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░  94%   ~2d 3h
  B  5h      ░░░░░░░░░░░░░░░░   3%
  B  7d All  ░░░░░░░░░░░░░░░░   1%/0%    Fable ░░░░░░░░░░░░░░░░   0%   2h前
```

#### Scenario: 全角ラベルでも列が揃う
- **WHEN** `label` が `仕事`（表示幅 4）のスロットと `B`（表示幅 1）のスロットを含むレジストリで statusline を実行する
- **THEN** 両スロットの行で `5h` / `7d All` の開始位置（表示幅）が一致する

#### Scenario: 2 スロットで 4 行が出る
- **WHEN** 2 スロットのレジストリと、両スロットの値を含む snapshot を与えて statusline を実行する
- **THEN** レートリミット表示はスロットごとに 2 行、計 4 行になり、各行の左端に active の目印とそのスロットの `label` が付く

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
スロットが 1 つだけのとき（レジストリ不在を含む）、statusline のレートリミット表示はこの変更の前と**バイト単位で同一**でなければならない（SHALL）。`label` 列を出してはならない（MUST NOT）。active の目印も出してはならない（MUST NOT）— 目印は「複数あるうちのどれか」を示すためのもので、スロットが 1 つのときには示す対象が無い。

#### Scenario: レジストリ不在で現行と同一
- **WHEN** レジストリファイルが存在しない状態で、変更前と同じ stdin と snapshot を与えて statusline を実行する
- **THEN** 出力は変更前の出力とバイト単位で一致し、`label` 列も active の目印も現れない

#### Scenario: 1 スロットのレジストリでも label を出さない
- **WHEN** スロットを 1 つだけ持つレジストリを与えて statusline を実行する
- **THEN** 出力に `label` 列も active の目印も現れない

#### Scenario: schema 1 の snapshot でも描画できる
- **WHEN** `accounts` を持たない schema 1 の snapshot を与えて statusline を実行する
- **THEN** トップレベルのキーから既定スロット 1 つとして現行どおり描画される
