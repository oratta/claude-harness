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

### Requirement: active スロットの行を視覚的に示す
スロットが複数あるとき、`plugins/statusline/scripts/statusline.sh` は active スロットの行を非 active スロットの行と視覚的に区別しなければならない（SHALL）。区別は**記号と明るさの二重符号化**で行わなければならない（SHALL）:

- **active スロットの行**: 行頭に `▸ `（U+25B8 と半角スペース。表示幅 2）を置き、記号と `label` をどちらも `DIM` ではなく通常の明るさで描く
- **非 active スロットの行**: 行頭に半角スペース 2 つを置き、`label` は `DIM` のまま描く

記号だけ、または明るさだけにしてはならない（MUST NOT）。色が落ちる経路（スクリーンショット、ログやファイルへのリダイレクト、ANSI を解釈しない表示先）では記号が残り、記号が読めない環境（フォントに `▸` が無い）では明るさが残る必要があるため。どちらか一方だけにすると、その手がかりが失われた環境で「どちらのアカウントの数字を見ているか」が分からなくなり、statusline の判断材料としての意味が失われる。記号は主・明るさは補助という位置づけなので、記号自体に `DIM` を掛けてはならない（MUST NOT）。

**目印の記号は East Asian Width が Neutral のものでなければならない**（SHALL）。差し替える場合もこの制約を満たさなければならない。見た目の似た候補 `▶`（U+25B6）・`●`（U+25CF）・`◆`（U+25C6）・`·`（U+00B7）はいずれも Ambiguous なので使ってはならない（MUST NOT）。

理由: この statusline はバー本体（`BAR_GLYPH` 既定 `▂` U+2582、EAW=Ambiguous）を 1 本につき 16 セル並べており、「端末が曖昧幅を半角として扱う」前提の上に成り立っている。それでもバーが問題にならないのは、バーが**揃えたい列より下流**にあるためである（バーの左端の位置を決めているのは行頭の目印列・label 列・`bar_seg` のラベルフィールドで、すべて ASCII。バーのグリフ幅は左端の位置に効かない）。目印はここが違い、**揃えたい列より上流**、それも行頭にある。記号が出るのは active 行だけで非 active 行は ASCII の半角スペース 2 つになるため、EAW=Ambiguous の記号を使うと、曖昧幅を全角に設定した端末では active 行の行頭が 3 桁・非 active 行が 2 桁になり、その差 1 桁が label 以降のすべての列に伝播する。EAW=Neutral を選ぶことは、既にある前提を新たに広げないという意味でもある。

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

