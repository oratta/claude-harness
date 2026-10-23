# statusline-multi-account-usage Specification

## Purpose
statusline がレートリミットをアカウント（スロット）別に描画する要件を定める。いま使っているアカウントはライブ値で、それ以外は usage snapshot の値と取得からの経過時間で描く。Codex 表示が無効でスロットが 1 つのときは従来と 1 バイトも変わらない出力になることを最優先の制約とする。
## Requirements
### Requirement: 値が得られたスロットごとにレートリミット行を描画する
`plugins/statusline/scripts/statusline.sh` は、レジストリのスロットのうち**値が得られたものについて**レートリミットを描画しなければならない（SHALL）。行の並びはレジストリの宣言順とする。

各スロットの行の出し方は現行の入れ子条件をスロット単位に適用したものでなければならない（SHALL）:

- 5h 消化率が得られない非 active スロットは行を出さない。表示対象の Claude スロットが複数あるときの active が欠測なら、同じ目印・label 列で `取得待ち` を1行出さなければならない（SHALL）。使用率や snapshot の値をライブ値として補ってはならない（MUST NOT）
- 5h 消化率が得られたスロットは `5h` 行を出す
- `5h` 行を出したスロットのうち、7d 消化率も得られたものだけ `7d All`（+ 条件を満たせば `Fable`）行を出す

表示対象の Claude スロットが複数あるときは各行の左端を「active の目印（表示幅 2。要件「active スロットの行を視覚的に示す」）＋ 名前の列」の順で構成しなければならない（SHALL）。名前は「サービス名 + 半角スペース + アカウント名」とし、Claude のスロットは `Claude <label>`（`<label>` はレジストリのスロットの `label`）、Codex の行は `Codex <label>`（`<label>` は要件「Codex の表示名を codex.label で決める」で決まる値）とする。目印の列は active / 非 active を問わず全行が等しく表示幅 2 を占め、非 active 行では半角スペース 2 つで埋める。名前の列の幅は文字数ではなく**表示幅**（East Asian Width が W / F の文字を 2 桁と数える）で揃えなければならない（SHALL）。アカウント名（`<label>`）の表示幅が 8 を超える場合は 8 桁に切り詰めたものを使う（`usage-account-registry` capability の `label` の規定に従う。長い label で全行が押し出されるのを防ぐ）。切り詰めるのはアカウント名の部分だけで、サービス名（`Claude ` / `Codex `）は常に残さなければならない（SHALL。名前全体を 8 桁に切ると `Claude 仕事` が `Claude 仕` のように中途半端に切れ、どのアカウントか分からなくなるため）。したがって名前の最大幅は `Claude ` の 7 桁 + 8 桁 = 15 桁で、名前の列の幅は表示される名前の表示幅の最大値とする。目印の列と名前の列の幅がどちらも全行で等しいことにより、バーの左端は全角のラベル（`仕事` など）を含めて揃う。バーの描画・色分け・日程線・分母表示（例 `82%/74%`）は既存の描画関数（`bar_seg` / `bar2`）をそのまま使い、意味論を変えてはならない（MUST NOT）。非 active でオフのスロットは要件「オフのスロットは表示しない」に従って描画対象から外す。

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
- **THEN** 数値を含むレートリミット行は出ない。表示対象の Claude スロットが複数ある場合のみ active の目印・label と `取得待ち` の行を出す。

#### Scenario: バー描画の意味論が変わらない
- **WHEN** 複数スロットの statusline 出力を検査する
- **THEN** バーの塗り・日程線・分母表示は 1 スロット時と同じ関数で生成された形式である

### Requirement: スロットが 1 つのときは現行と同一の出力にする
Codex 表示が無効でスロットが 1 つだけのとき（レジストリ不在を含む）、statusline のレートリミット表示は、リセット権の区画（要件「Claude のアカウントの行にリセット権の残数と期限を表示する」）が出ない場合で、かつ要件「`.headroom.json` の値を使えるアカウントを決める」で値を使えるアカウントが無い場合は、この変更の前と**バイト単位で同一**でなければならない（SHALL）。区画が出る場合の差は、そのスロットの最後の行の末尾への区画の追加だけで、それ以外の部分（バー・色・経過時間・行数）は変えてはならない（MUST NOT）。値を使えるアカウントがある場合の差は、要件「ロケットモードのための列を空ける」「Claude のロケットモードを描く」「リセット権の区画を 🚀 と数で描く」が定める部分だけとする。`label` 列を出してはならない（MUST NOT）。active の目印も出してはならない（MUST NOT）— 目印は「複数あるうちのどれか」を示すためのもので、スロットが 1 つのときには示す対象が無い。

Codex の行が出るときの 1 スロット表示の名前の列は、要件「Codex の行の名前は Codex とアカウント名にする」に従う（この要件の `label` 列を出さない規定は、Codex の行が出ないときに限る）。

登録簿には複数スロットがあっても、非 active のオフスロットを除いた表示対象の Claude スロットが 1 つだけなら同じ 1 スロット表示にしなければならない（SHALL）。active 判定そのものは非表示のスロットも含む登録簿全体で行う。

#### Scenario: レジストリ不在で現行と同一
- **WHEN** レジストリファイルが存在しない状態で、変更前と同じ stdin と snapshot を与えて statusline を実行する
- **THEN** 出力は変更前の出力とバイト単位で一致し、`label` 列も active の目印も現れない

#### Scenario: 1 スロットのレジストリでも label を出さない
- **WHEN** スロットを 1 つだけ持つレジストリを与えて、Codex の行が出ない状態で statusline を実行する
- **THEN** 出力に `label` 列も active の目印も現れない

#### Scenario: schema 1 の snapshot でも描画できる
- **WHEN** `accounts` を持たない schema 1 の snapshot を与えて statusline を実行する
- **THEN** トップレベルのキーから既定スロット 1 つとして現行どおり描画される

#### Scenario: 登録簿は複数でも表示対象が 1 スロット
- **WHEN** A が active で B だけが `enabled: false` の 2 スロットの登録簿を与える
- **THEN** A は active 目印と名前列の無い 1 スロット表示で描かれ、B の行は無い

#### Scenario: A と B が両方オフで A が active なら A だけの 1 スロット表示
- **WHEN** A と B がどちらも `enabled: false` で A が active の 2 スロットの登録簿を与える
- **THEN** A はライブ値で active 目印と名前列の無い 1 スロット表示で描かれ、B の行は無い

#### Scenario: オフの B が active なら 2 スロット表示に戻る
- **WHEN** A がオン、B が `enabled: false` で、B が active の登録簿を与える
- **THEN** A と B の 2 スロットが名前列と active 目印付きで描かれ、B はライブ値で描かれる

#### Scenario: 区画が出る 1 スロットでは区画の追加だけが差になる
- **WHEN** 1 スロットで `reset_grants` を持つ snapshot と、それを除いた同じ snapshot を同じ stdin で描く
- **THEN** 前者の出力は後者の出力の最後の行の末尾に区画が付いただけで、label 列も active の目印も無く、他の部分は一致する

#### Scenario: 値を使えない `.headroom.json` は 1 スロットの出力を変えない
- **WHEN** 1 スロットで、`status` が `stale` の要素だけを持つ `.headroom.json` を置いて statusline を実行する
- **THEN** 出力は `.headroom.json` が無いときとバイト単位で一致する

### Requirement: active スロットはライブ値、非 active スロットは snapshot 値と経過時間で描く
active スロットのレートリミットは stdin の `.rate_limits.*` のライブ値から描画しなければならない（SHALL）。非 active スロットは、そのスロットの鍵のセッション記録（`usage-session-records` capability）と snapshot の `accounts` の値から、`usage-session-records` の「記録と snapshot から実効値を求める」規則の 1 と 4（同じ窓なら取得時刻が新しい方、取得時刻が等しいまたは無ければ大きい方（リセット時刻と取得時刻も大きい方の情報源のもの）、窓が違えば新しい窓、全体の週次は差が 1 時間を超えたら記録側。ただし記録側のリセット時刻が過去なら、この例外を使わずリセット時刻の後の方を取る）で選んだ値を描画し、行末に採った値の取得時刻（セッション記録は `observed_at`、snapshot は `fetched_at`）からの経過時間（例 `2h前`）を併記しなければならない（SHALL）。statusline は規則の 2（リセット時刻を過ぎた値を 0% とみなし、リセット時刻を 7 日進める）の読み替えを表示には行わない。規則 4 の窓の突き合わせは、読み替える前のリセット時刻どうしで行う。選んだ値のリセット時刻が過去なら、既存の要件「非 active スロットの resets_at が過去のときは分母と残り時間を出さない」に従って描く。Fable バーは snapshot の値から描く。statusline は他プラグインのスクリプトを実行時に読まず、この規則を自分で実装しなければならない（SHALL）。

#### Scenario: active スロットにライブ値を使う
- **WHEN** stdin の `.rate_limits` と snapshot の active スロットの値が異なる状態で statusline を実行する
- **THEN** active スロットの行は stdin のライブ値で描画される

#### Scenario: 非 active スロットに経過時間が付く
- **WHEN** 非 active スロットの `fetched_at` が現在より 2 時間前である snapshot を与え、そのスロットのセッション記録が無い状態で statusline を実行する
- **THEN** その非 active スロットの行末に取得からの経過時間が表示される

#### Scenario: 非 active スロットはセッション記録の新しい値で描く
- **WHEN** 非 active スロット B の snapshot の値が 5 時間前の週次 40% で、B の鍵のセッション記録が 3 分前の週次 45%（同じリセット時刻）である状態で、A のセッションとして statusline を実行する
- **THEN** B の行は週次 45% で描かれ、行末の経過時間は記録の `observed_at` からの時間になる

#### Scenario: 手動リセット後の新しい記録は古い snapshot の 100% より優先して描く
- **WHEN** 非 active スロット B の snapshot の週次が 100%（古い取得時刻）、B の記録の週次が 0%（新しい `observed_at`・同じリセット時刻）である状態で、A のセッションとして statusline を実行する
- **THEN** B の週次は 0% で描かれ、行末の経過時間は記録の `observed_at` からの時間になる

#### Scenario: リセット時刻が過去の値は読み替えずに描く
- **WHEN** 非 active スロット B の記録だけがあり、その週次が 80%・リセット時刻が現在より 1 時間前である状態で statusline を実行する
- **THEN** B の週次は 0% ではなく 80% で描かれ、分母と残り時間は出ない

#### Scenario: リセット時刻が 1 時間を超えて違えば記録側で描く
- **WHEN** 非 active スロット B の記録の週次が 30%・リセット時刻が現在より 2 日後、snapshot の週次が 60%・リセット時刻が現在より 5 日後である状態で statusline を実行する
- **THEN** B の週次は 30% で描かれ、行末の経過時間は記録の `observed_at` からの時間になる

#### Scenario: 記録側のリセット時刻が過去なら全体の週次の例外を使わない
- **WHEN** 非 active スロット B の記録の週次が 80%・リセット時刻が現在より 1 時間前、snapshot の週次が 10%・リセット時刻が現在より 7 日後である状態で statusline を実行する
- **THEN** B の週次は snapshot 側の 10% で描かれ、行末の経過時間は snapshot の `fetched_at` からの時間になる

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
表示対象の Claude スロットが複数あるとき、`plugins/statusline/scripts/statusline.sh` は active スロットの行を非 active スロットの行と視覚的に区別しなければならない（SHALL）。区別は**記号と明るさの二重符号化**で行わなければならない（SHALL）:

- **active スロットの行**: 行頭に `▸ `（U+25B8 と半角スペース。表示幅 2）を置き、記号と `label` をどちらも `DIM` ではなく通常の明るさで描く
- **非 active スロットの行**: 行頭に半角スペース 2 つを置き、`label` は `DIM` のまま描く

記号だけ、または明るさだけにしてはならない（MUST NOT）。色が落ちる経路（スクリーンショット、ログやファイルへのリダイレクト、ANSI を解釈しない表示先）では記号が残り、記号が読めない環境（フォントに `▸` が無い）では明るさが残る必要があるため。どちらか一方だけにすると、その手がかりが失われた環境で「どちらのアカウントの数字を見ているか」が分からなくなり、statusline の判断材料としての意味が失われる。記号は主・明るさは補助という位置づけなので、記号自体に `DIM` を掛けてはならない（MUST NOT）。

**目印の記号は East Asian Width が Neutral のものでなければならない**（SHALL）。差し替える場合もこの制約を満たさなければならない。見た目の似た候補 `▶`（U+25B6）・`●`（U+25CF）・`◆`（U+25C6）・`·`（U+00B7）はいずれも Ambiguous なので使ってはならない（MUST NOT）。

理由: この statusline はバー本体（`BAR_GLYPH` 既定 `▂` U+2582、EAW=Ambiguous）を 1 本につき 16 セル並べており、「端末が曖昧幅を半角として扱う」前提の上に成り立っている。それでもバーが問題にならないのは、バーが**揃えたい列より下流**にあるためである（バーの左端の位置を決めているのは行頭の目印列・label 列・`bar_seg` のラベルフィールドで、すべて ASCII。バーのグリフ幅は左端の位置に効かない）。目印はここが違い、**揃えたい列より上流**、それも行頭にある。記号が出るのは active 行だけで非 active 行は ASCII の半角スペース 2 つになるため、EAW=Ambiguous の記号を使うと、曖昧幅を全角に設定した端末では active 行の行頭が 3 桁・非 active 行が 2 桁になり、その差 1 桁が label 以降のすべての列に伝播する。EAW=Neutral を選ぶことは、既にある前提を新たに広げないという意味でもある。

active スロットの判定には既存の `active_idx`（`usage-account-registry` capability の「active スロットの判定規則」で確定したもの）をそのまま用いなければならない（SHALL）。描画側で判定を作り直してはならない（MUST NOT）。active スロットの値が欠測の場合も、目印と label に `取得待ち` を添えた行を1行出さなければならない（SHALL）。他のスロットへ目印を移してはならない（MUST NOT）。

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

#### Scenario: active スロットが欠測でも目印を表示する
- **WHEN** active スロットの値が全て `null`（欠測）で、非 active スロットにだけ値がある snapshot を与えて statusline を実行する
- **THEN** active の `▸ label  取得待ち` 行が1行出て、非 active スロットの行は半角スペース 2 つで始まる

### Requirement: Codex のアカウント上限を最後に1行追加する
Codex CLI の ChatGPT 認証が利用可能なとき、Claude の全スロットの下に `Codex` 行を追加しなければならない（SHALL）。通常 Codex バケットの取得できた窓だけを同じバー・色・日程線・リセット残時間で描き、取得からの経過時間を添える。窓は `windowDurationMins` に従い、週次だけでも表示する。Spark 等の別バケットを通常 Codex の上限として扱ってはならない（MUST NOT）。複数の窓は1行に並べる。

取得は公式 app-server の `account/rateLimits/read` を用い、描画はキャッシュを読む。ネットワーク応答を描画の完了条件にしてはならない（MUST NOT）。取得失敗でも前回の値と実際の取得時刻を維持し、初回欠測は `取得待ち` とする。認証が変わった場合は以前のキャッシュを流用してはならない（MUST NOT）。`STATUSLINE_CODEX=0` で無効化できる。

#### Scenario: 週間枠だけが返る
- **WHEN** 通常 Codex バケットの primary が10080分、secondary がnullである
- **THEN** Claude の下に Codex の `7d All` を1行表示し、5h は表示しない

#### Scenario: Codex 無効時の互換性
- **WHEN** `STATUSLINE_CODEX=0` でライブ値がある既存の入力を描く
- **THEN** Claude の出力は変更前とバイト単位で一致する

### Requirement: Codex リセット権の残数と期限を表示する
`rateLimitResetCredits.availableCount` が取得できたとき、Codex 行に残数を表示しなければならない（SHALL）。利用可能な権利の `expiresAt` の最短値を残時間に換算し、3日以内は黄色、24時間以内は赤色にする。期限情報が欠ければ期限不明、取得情報の期限を過ぎた場合は更新待ちと示し、推測の残数を表示してはならない（MUST NOT）。表示処理から権利の使用APIを呼んではならない（MUST NOT）。

#### Scenario: 最短期限が近づく
- **WHEN** 残数3回、取得済みの最短期限が24時間以内である
- **THEN** Codex 行に残数3回と最短期限までの時間が赤色で表示される

#### Scenario: 残数のみ取得できる
- **WHEN** 残数は3回だが credits が null である
- **THEN** リセット3回・期限不明と表示される

### Requirement: Codex の行の名前は Codex とアカウント名にする
Codex の行が表示されるとき、その左端の名前は `Codex <label>` でなければならない（SHALL）。`<label>` は要件「Codex の表示名を codex.label で決める」（`usage-account-registry` capability）で決まる値で、`codex.label` が無ければ `A` である。`取得待ち` の行にもこの名前を用いる。表示される Codex 行の名前列は Claude の表示対象スロットと共通の最大値で揃える。Codex がオフのときは要件「Codex がオフのとき表示行を出さず、取得しない」に従い、Codex 行を出さず、名前列の幅にも数えない。Codex の取得方法はこの要件で変えない（MUST NOT）。

表示する Claude スロットが 1 つ（レジストリ不在、または非 active のオフスロットを除いて 1 つになる場合を含む）で Codex の行が出るとき、Claude 側の各行の左端も「半角スペース 2 つ（目印の列）＋名前の列」で構成しなければならない（SHALL）。名前は複数スロットのときと同じ `Claude <label>` で、レジストリ不在の既定スロットは `Claude` とする。名前には `DIM` を掛けない（active の行と同じ）。active の目印 `▸` は出してはならない（MUST NOT。1 つのときに示す対象が無い）。名前の列の幅は Claude の名前と Codex の名前の表示幅の大きい方で、これにより Claude の行と Codex の行のバーの左端が揃う。Codex の行が出ないときの 1 スロット表示は今のまま（名前を出さず、バイト単位で同一）とする。

#### Scenario: codex.label が無ければ Codex A
- **WHEN** Codex の値が得られる状態で、`codex.label` を持たないレジストリを与えて statusline を実行する
- **THEN** Codex の行の名前は `Codex A` になる

#### Scenario: codex.label があればそれを使う
- **WHEN** Codex の値が得られる状態で、レジストリのトップレベルが `"codex": {"label": "X"}` を持つ
- **THEN** Codex の行の名前は `Codex X` になる

#### Scenario: Codex が無くスロットが 1 つなら出力は変わらない
- **WHEN** Codex の行が出ない状態で、レジストリ不在またはスロット 1 つのレジストリを与えて statusline を実行する
- **THEN** 出力は変更前とバイト単位で一致する

#### Scenario: 1 スロットでも Codex の行が出れば Claude の行に名前が出る
- **WHEN** スロット `a`（label `A`）だけのレジストリで、Codex の行（名前 `Codex A`）が出る状態で statusline を実行する
- **THEN** ANSI を除いた Claude の行は `  Claude A  5h` と `  Claude A  7d All` で始まり、`▸` は出ない。Claude の行と Codex の行のバーの開始位置（表示幅）が一致する

#### Scenario: レジストリ不在の 1 スロットは Claude と名乗る
- **WHEN** レジストリが無く、Codex の行（名前 `Codex A`）が出る状態で statusline を実行する
- **THEN** ANSI を除いた Claude の行は `  Claude   5h` で始まり（名前の列の幅は `Codex A` の 7）、Claude の行と Codex の行のバーの開始位置が一致する

### Requirement: オフのスロットは表示しない
`plugins/statusline/scripts/statusline.sh` は、非 active で `enabled` が JSON の `false` の Claude スロットについて、値や `off` の行を一切出してはならない（MUST NOT）。snapshot やセッション記録に値が残っていても、値が無くても同じである。active スロットの判定はオフを含む登録簿の全スロットから行い、その結果 active になったオフのスロットは、要件「active スロットはライブ値、非 active スロットは snapshot 値と経過時間で描く」に従ってライブ値で描かなければならない（SHALL）。

非表示のスロットは、表示対象の Claude スロット数と名前列の幅に数えてはならない（MUST NOT）。表示するオンの非 active スロットは登録簿の宣言順を保つ。`enabled` が省略または `true` のとき、出力は従来とバイト単位で同一でなければならない（SHALL）。`false` 以外の値は `usage-account-registry` の判定に従ってオンとして扱う。statusline は他プラグインのスクリプトを実行時に読まず、`enabled` の読み取りを自分で実装しなければならない（SHALL）。

#### Scenario: 値が残る非 active のオフスロットは行が無い
- **WHEN** A が active、B が `enabled: false` の 2 スロットの登録簿で、snapshot とセッション記録に B の値がある
- **THEN** ステータスラインに `Claude B` の名前も `off` の行も現れず、B の値・バー・経過時間も出ない

#### Scenario: 値が無い非 active のオフスロットも行が無い
- **WHEN** B が非 active かつ `enabled: false` で、B の値が snapshot にもセッション記録にも無い
- **THEN** B の行は出ない

#### Scenario: active のオフスロットはライブ値で描く
- **WHEN** `CLAUDE_SECURESTORAGE_CONFIG_DIR` が `enabled: false` の B の `securestorage` と一致し、stdin に `rate_limits` がある
- **THEN** B は active の目印が付いたライブ値で描かれ、`off` は出ない

#### Scenario: 非表示の全角ラベルは列幅に数えない
- **WHEN** A が active、B がオン、`仕事` という長い名前の C が非 active かつオフである
- **THEN** A と B の名前列は A と B の表示幅だけで揃い、C の行は無い

#### Scenario: enabled の省略と true は同じ
- **WHEN** 2 スロットの登録簿で両方の `enabled` を省略した場合と `true` にした場合を同じ入力で描く
- **THEN** 2 つの出力はバイト単位で一致する

### Requirement: Codex がオフのとき表示行を出さず、取得しない
レジストリの `codex.enabled` が `false`（`usage-account-registry` capability の要件「Codex を codex.enabled でオフにできる」）のとき、`plugins/statusline/scripts/statusline-codex.py` は、使用量の代わりに `off` の 1 行だけを標準出力に出して終わらなければならない（SHALL）。`codex` の起動（`app-server`）、Codex の認証ファイルの読み出し、キャッシュ（`.statusline-codex`）の読み書き、`--refresh` の子プロセスの起動のいずれも行ってはならない（MUST NOT）。出力は 2 通りに分かれる（SHALL）。通常の描画（引数なし、または `--read`）は `off` と改行の 1 行、`--refresh` は何も出さず（標準出力は空）に終わる。`--refresh` は描画用の出力を持たない子プロセスなので、`off` を出さない。

この要件は、要件「Codex のアカウント上限を最後に1行追加する」と要件「Codex リセット権の残数と期限を表示する」に優先する（SHALL）。この 2 つの要件が求める使用量・リセット権の描画とキャッシュの読み取りは、Codex がオフのときは適用しない。オフのとき、認証済みで取得済みのキャッシュが残っていても、使用量もリセット権も描かず、キャッシュも読まない（残ったキャッシュは消さず、オンに戻したとき従来どおり使われる）。

オフの判定は、認証の有無やバイナリの有無の判定より先に行わなければならない（SHALL）。Codex にログインしていない環境でも、取得を始めずに終了するため。

`plugins/statusline/scripts/statusline.sh` は helper の `off` を受け取ったとき Codex の行を一切出してはならず（MUST NOT）、Codex の名前を Claude 行の名前列の幅にも数えてはならない（MUST NOT）。`STATUSLINE_CODEX=0` のときは、従来どおり helper を呼ばず、Codex 行そのものを出さない。

`codex.enabled` が無い、または `false` 以外のとき、出力は変更前とバイト単位で同一でなければならない（SHALL）。`statusline-codex.py` は他プラグインのスクリプトを実行時に読まず、`codex.enabled` の読み取りを自分で実装しなければならない（SHALL）。

#### Scenario: オフなら off を出して codex を起動しない
- **WHEN** `codex.enabled` が `false` で、`STATUSLINE_CODEX_BIN` に起動を記録するスタブを指定して `statusline-codex.py` を実行する
- **THEN** 標準出力は `off` の 1 行で、スタブは 1 回も起動されず、`.statusline-codex` は作られない

#### Scenario: 認証済みで既存のキャッシュがあってもオフなら行を出さない
- **WHEN** `codex.enabled` が `false` で、`auth.json` が有効で、`.statusline-codex` に使用量とリセット権の取得済みの値がある状態で statusline を実行する
- **THEN** Codex 行は出ず、使用量・バー・`リセット` の表示も出ない。`.statusline-codex` は読まれも書き換えられもせず、内容は変わらない

#### Scenario: オフなら認証が無くても off を出す
- **WHEN** `codex.enabled` が `false` で、`CODEX_HOME` に `auth.json` が無い状態で `statusline-codex.py` を実行する
- **THEN** 標準出力は `off` の 1 行になる

#### Scenario: オフなら --refresh は何もしない
- **WHEN** `codex.enabled` が `false` で `statusline-codex.py --refresh` を実行する
- **THEN** 標準出力は空（`off` も出さない）で、`codex` は起動されず、キャッシュも作られない

#### Scenario: statusline.sh は Codex 行を出さない
- **WHEN** `codex.enabled` が `false` の状態で statusline を実行する
- **THEN** Codex の名前も `off` も行に現れず、Codex の名前は Claude 行の列幅にも反映されない

#### Scenario: STATUSLINE_CODEX=0 はオフの設定より優先する
- **WHEN** `codex.enabled` が `false` で `STATUSLINE_CODEX=0` の状態で statusline を実行する
- **THEN** Codex 行は出ない

#### Scenario: 設定が無い環境では出力が変わらない
- **WHEN** `codex` を書いていないレジストリと `"codex": {"enabled": true}` のレジストリを、同じ入力と同じキャッシュで順に与える
- **THEN** 2 つの出力は変更前とバイト単位で一致する

### Requirement: Claude のアカウントの行にリセット権の残数と期限を表示する
`plugins/statusline/scripts/statusline.sh` は、表示する Claude の各スロットについて、snapshot（`dev-workflow-escalation-tripwires` capability の「usage-probe と snapshot 契約」）の `accounts.<id>.reset_grants` が読めるとき、そのスロットの最後の行（7d の行があればそれ、無ければ 5h の行）の末尾に、行末の経過時間のあとに続けて ` │ ` を挟んで残数と最短期限を表示しなければならない（SHALL）。書式・色・欠測の扱いは要件「Codex リセット権の残数と期限を表示する」と同じにする: `リセットN回・最短あとXdYh`（24 時間未満は `あとXhYm`）、期限まで 3 日以内は黄、24 時間以内は赤、それより先は DIM、有効な束に期限のあるものが無ければ `期限不明`、最短期限を過ぎていれば `期限経過（更新待ち）`。

数え方: `resets_left` が 0 より大きい整数で `paused` が true でない束だけを数える。残数は `resets_left` の和、最短期限は数えた束の `ends_at` のうち読めるものの最小値。`ends_at` が null・欠落・読めない値の束は残数には数え、期限には含めない。`reset_grants` が空の配列なら `リセット0回` を表示する。`reset_grants` が無い・配列でない、または束が 1 つ以上あるのにすべて読めない・使えない（`resets_left` が整数でない・負など）ときは、区画を出してはならない（MUST NOT）。欠測を 0 回として扱わない。

`reset_grants` が読めないスロットの行、および snapshot が無いときの出力は、この要件を足す前とバイト単位で同一でなければならない（SHALL）。区画が出るときの差は区画の追加だけである。区画が持つ取得時刻はなく、非 active 行の経過時間はセッション記録と突き合わせた後の値で必ずしも snapshot の取得時刻ではない。区画の鮮度は、snapshot の欄が「最後の取得が成功した、または試みていない」ときだけ残る契約と、期限を過ぎたときの `期限経過（更新待ち）` で担保する。表示処理はリセット権を使う API を呼んではならず、リセット権のための通信を増やしてはならない（MUST NOT）。値の出どころは snapshot の欄だけとし、statusline は別のキャッシュを持たない。

#### Scenario: 残数と最短期限が出る
- **WHEN** active スロットの snapshot の `reset_grants` が `resets_left` 1 の束 2 つ（`ends_at` が 3 日 21 時間後と 10 日後、どちらも `paused: false`）である
- **THEN** そのスロットの最後の行の末尾に `リセット2回・最短あと3日21h` が出る

#### Scenario: 3 日以内は黄、24 時間以内は赤
- **WHEN** 最短期限が 2 日後の snapshot と 12 時間後の snapshot をそれぞれ描く
- **THEN** 前者は黄の色コード、後者は赤の色コードが、`リセット…` の文字列に付く

#### Scenario: paused と 0 回の束は数えない
- **WHEN** `reset_grants` が `paused: true` の束と `resets_left: 0` の束と、`resets_left: 1` の有効な束 1 つである
- **THEN** 残数は 1 回で、最短期限は有効な束の `ends_at` になる

#### Scenario: paused は boolean の true だけを除外する
- **WHEN** `resets_left: 1`・`ends_at: null` の束 1 つだけの `reset_grants` を、`paused` が欠落・`null`・文字列 `"true"`・`false` の各場合で描く
- **THEN** どの場合も `リセット1回・期限不明` が出る
- **AND** `paused: true` の場合は、その束は数えられず区画が出ない（数えられる束が無い）

#### Scenario: 期限が無ければ期限不明
- **WHEN** 有効な束が `ends_at: null` の 1 つだけである
- **THEN** `リセット1回・期限不明` が出る

#### Scenario: 空配列は 0 回
- **WHEN** `reset_grants` が `[]` である
- **THEN** `リセット0回` が出る（期限の表示は付かない）

#### Scenario: 欄が無ければ区画を出さず出力は変わらない
- **WHEN** snapshot のスロットに `reset_grants` が無い、または snapshot が無い
- **THEN** 出力は、この要件を足す前の出力とバイト単位で一致する

#### Scenario: 読めない束だけなら区画を出さない
- **WHEN** `reset_grants` の束がすべて `resets_left` が文字列または負である
- **THEN** 区画は出ず、出力は欄が無いときと一致する

#### Scenario: 非 active のアカウントにも出る
- **WHEN** 2 スロットの登録簿で、非 active スロットの snapshot に `reset_grants` がある
- **THEN** 非 active スロットの最後の行の末尾（経過時間のあと）にリセット権の区画が出る

**守備範囲**（この要件の `reset_grants` の集計に限る）
- 入力の出どころ: dev-workflow の `usage-probe.sh` が書く自分の snapshot。probe が値を変えずに写すので、型の崩れや欠落は残りうる。外部の第三者が作る入力ではない
- 拾う誤り: 欄が配列でない、束がオブジェクトでない、`resets_left` が 0 より大きい整数でない。これらの束は数えず、数えられる束が 1 つも無ければ区画を出さない。`paused` は boolean の `true` だけを除外する。`ends_at` が日時に直せない束は、残数には数え、期限には含めない
- 意図的に通す入力: `ends_at` の欠落・null（残数付きで `期限不明`）、`paused` の欠落・null・文字列 `"true"` などの boolean の `true` 以外（除外せず数える）、未知のキー、過去の `ends_at`（`期限経過（更新待ち）`）
- 未知の穴を塞ぎ切ることを完了条件にしない。想定外の形は区画を出さないに倒し、行の他の部分は変えない

### Requirement: `.headroom.json` の値を使えるアカウントを決める
`plugins/statusline/scripts/statusline.sh` は、`${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json`（oratta/claude-harness#1300 の `headroom.py` が書く schema 1）を読み、表示するアカウントごとに、その値を使えるかどうかを決めなければならない（SHALL）。statusline は値を読むだけで、余り・使える量・期限を数え直してはならず（MUST NOT）、headroom.py を含む他プラグインのスクリプトを実行時に呼んではならない（MUST NOT）。

入れ物の形は #1300 の schema 1 の確定版に従う。この要件を書いた時点の仮の形は change の design.md「D1. 仮に置いた JSON の形」で、トップレベルの `accounts` 配列の要素が `provider`（`"claude"` / `"codex"`）と `account` を持ち、Claude の要素は `account` が登録簿のスロットの `id`（登録簿が無いときは `default`）、Codex の要素は `account` が `current` のものが statusline の Codex の行に当たるとする。時刻（`computed_at`・`weekly_reset_at`・`earliest_expiry`）は epoch 秒の整数と、ISO 8601 の `Z` か `±HH:MM` の時差付きの文字列（小数秒は落とす）の両方を読む。

アカウントの値を使えるのは、次のすべてを満たすときだけでなければならない（SHALL）:

1. ファイルがあり、トップレベルがオブジェクトで、`schema` が数値の 1
2. `computed_at` が読め、現在時刻との差（現在 − `computed_at`）が 21600 秒未満
3. そのアカウントに当たる要素がちょうど 1 つあり、その `status` が文字列の `"ok"`
4. 要素の `weekly_reset_at` が読め、statusline がそのアカウントの行に描く週次のリセット時刻（Claude は `7d All` の行のリセット時刻、Codex は `windowDurationMins` が 10080 の窓のリセット時刻）との差が 3600 秒以内。描く行に週次のリセット時刻が無ければ満たさない
5. `rocket` が null か、`count` が 1 以上の整数で `earliest_expiry` が読めて現在より後のオブジェクト
6. `tickets` が null か、`count` が 0 以上の整数のオブジェクトで、その `earliest_expiry` が null・欠落、または読めて現在より後
7. Claude で `rocket` が null でないとき、`capacity_pct` が 100 より大きい数値

1 つでも外れたアカウントは、この要件を足す前の描き方で描かなければならない（SHALL）。使える項目だけを拾って一部を描いてはならない（MUST NOT）。どのアカウントの値も使えないとき、レートリミット表示はこの要件を足す前とバイト単位で同一でなければならない（SHALL）。

statusline が読む項目は `schema`・`computed_at`・各要素の `provider`・`account`・`status`・`weekly_reset_at`・`rocket`・`tickets`・`capacity_pct` だけとする。バーの使った量は今と同じ出どころ（active は stdin のライブ値、非 active は snapshot とセッション記録から選んだ値、Codex は `.statusline-codex`）から取り、要素の `used_pct` で置き換えてはならない（MUST NOT）。

ファイルは全アカウント分を jq 1 回で読まなければならない（SHALL）。ファイルが無いときは jq を起動してはならない（MUST NOT）。

**守備範囲**（この要件の `.headroom.json` の読み取りに限る）
- 入力の出どころ: 同じマシンの dev-workflow の `headroom.py`（oratta/claude-harness#1300）が書く自分のファイル。外部の第三者が作る入力ではない。probe が止まれば古いまま残り、#1300 の版が変われば形が変わりうる
- 拾う誤り: 条件 1〜7 の外れ（JSON として読めない・`schema` が 1 でない・`accounts` が配列でない・`computed_at` が古い・当たる要素が 0 個か 2 個以上・`status` が `ok` でない・`weekly_reset_at` が描く値とずれる・`rocket` / `tickets` / `capacity_pct` の型崩れ・失効を過ぎた `earliest_expiry`）。どれもそのアカウントを「使えない」に倒し、今の描き方に戻す
- 意図的に通す入力: 未知のキー、読まない項目（`used_pct`・`elapsed_pct`・`deadline_at`・`deadline_reason`・`forecast`・`surplus_pct`・`margin`・`best`・`label`）の欠落や型崩れ、`tickets.earliest_expiry` の null・欠落、時刻の epoch 秒と ISO 8601 の混在、`capacity_pct` の小数（整数に丸める）、他のアカウントの要素の崩れ（そのアカウントだけ使えなくなり、他は使える）
- 未知の穴を塞ぎ切ることを完了条件にしない。想定外の形はそのアカウントを使えないに倒し、行の他の部分は変えない

#### Scenario: ファイルが無ければ今と同じ
- **WHEN** `.headroom.json` が無い状態で、この要件を足す前と同じ stdin・snapshot・登録簿で statusline を実行する
- **THEN** 出力は足す前とバイト単位で一致する

#### Scenario: status が ok でなければ今と同じ
- **WHEN** 当たる要素の `status` が `stale`・`missing`・`off` のいずれかで、`rocket` と `tickets` を持つ `.headroom.json` を置いて statusline を実行する
- **THEN** 出力は `.headroom.json` が無いときとバイト単位で一致する

#### Scenario: 古いファイルは使わない
- **WHEN** `computed_at` が現在より 21600 秒前の `.headroom.json` を置いて statusline を実行する
- **THEN** 出力は `.headroom.json` が無いときとバイト単位で一致する

#### Scenario: 読めない形は使わない
- **WHEN** `.headroom.json` が JSON として読めない、`schema` が 2、`accounts` が配列でない、のいずれかの状態で statusline を実行する
- **THEN** 出力は `.headroom.json` が無いときとバイト単位で一致する

#### Scenario: 失効を過ぎたリセット権を持つ値は使わない
- **WHEN** 当たる要素の `rocket.earliest_expiry` が現在より前の `.headroom.json` を置いて statusline を実行する
- **THEN** そのアカウントの行は `.headroom.json` が無いときと同じに描かれ、🚀 は出ない

#### Scenario: 週次の窓が違えば使わない
- **WHEN** Codex の要素の `weekly_reset_at` が、`.statusline-codex` の週次の窓のリセット時刻と 2 時間違う
- **THEN** Codex の行は、要件「ロケットモードのための列を空ける」の空白を除いて、`.headroom.json` が無いときと同じ中身で描かれる

#### Scenario: 使えるアカウントだけが変わる
- **WHEN** 2 スロットの登録簿で、スロット `a` の要素は使える条件を満たし、スロット `b` の要素は `status` が `stale` の `.headroom.json` を置く
- **THEN** `a` の行だけがロケットモードの描き方（要件「Claude のロケットモードを描く」）になり、`b` の行の中身（バー・数字・右端の区画）は、要件「ロケットモードのための列を空ける」の空白を除いて、`.headroom.json` が無いときと同じになる

#### Scenario: jq はファイルがあれば 1 回、無ければ起動しない
- **WHEN** jq の起動のうち引数に `.headroom.json` を含むものを数えるスタブを PATH の先頭に置き、2 スロットの登録簿と Codex の行が出る状態で、`.headroom.json` を置いたときと置かないときにそれぞれ statusline を実行する
- **THEN** 置いたときの数は 1、置かないときの数は 0 になる

### Requirement: ロケットモードのための列を空ける
要件「`.headroom.json` の値を使えるアカウントを決める」で値を使えるアカウントの行が 1 つでも描かれるとき、statusline は描くすべてのレートリミット行（Claude の `5h`・`7d All` の行と Codex の行。`取得待ち` の行を除く）で、次の 2 つの列を空けなければならない（SHALL）。使えるアカウントの行が 1 つも無いときは空けてはならない（MUST NOT）。

- **🚀 の列**: `5h`・`7d All`・Codex の各窓のバーの直前に置く表示幅 4 の列。ラベルの欄（今は表示幅 9 で左寄せ）を表示幅 7 に縮め、そのうしろに置く。ロケットモードの行の `7d All`（Codex は週次の窓）では要件「Claude のロケットモードを描く」「Codex のロケットモードを描く」の印を入れ、それ以外は半角スペース 4 つで埋める。🚀（U+1F680）は表示幅 2 と数える
- **使える量の列**: Claude の `7d All` と Codex の週次の窓のバーの直後に置く表示幅 9 の右寄せの列。Claude のロケットモードの行では「使った / 使える」（例 `20/200%`）を入れ、それ以外は半角スペースで埋める。この列のうしろの割合の数字は、今の `%3d`（前に半角スペース 1 つ）ではなく `%5d` で描く

この要件が変えるのは列の幅と空白だけで、バーの塗り・色・日程線・分母の意味論は変えない。要件「値が得られたスロットごとにレートリミット行を描画する」の描画関数の規定に、列の幅に限って優先する（SHALL）。

`5h` の行の割合の数字と Fable のバーはこの要件で変えない。名前の列と目印の列の規則（要件「値が得られたスロットごとにレートリミット行を描画する」）は変えないので、空けた列も含めてバーの左端は全行で揃う。

#### Scenario: リセット権が無くても列は空く
- **WHEN** 2 スロットの登録簿で、スロット `a` の要素が使える条件を満たし `rocket` と `tickets` が null、スロット `b` には要素が無い `.headroom.json` を置いて statusline を実行する
- **THEN** 両スロットの `5h` と `7d All` の行は、ラベルの欄 7 桁のうしろに半角スペース 4 つがあってからバーが始まり、`7d All` の行はバーの直後に半角スペース 9 つがあってから割合の数字が続く。🚀 も「使った / 使える」も出ない

#### Scenario: 空けた列でもバーの左端は揃う
- **WHEN** Claude のスロット `a` がロケットモードで、Codex の行がロケットモードでない状態で statusline を実行する
- **THEN** ANSI を除いた出力で、Claude の各行と Codex の行のバーの開始位置（表示幅）が一致する

### Requirement: Claude のロケットモードを描く
Claude のアカウントの値を使えて `rocket` が null でないとき（ロケットモード）、statusline はそのアカウントの `7d All` の行を次のとおり描かなければならない（SHALL）。

- **🚀 の列**: `rocket.count` が 1 なら `🚀`、2 以上なら `🚀` に続けて `count` の数字（例 `🚀2`）を置き、表示幅 4 になるまで半角スペースで埋める
- **使える量**: `capacity_pct` を整数に丸めた値を使える量とする。バーと割合の数字は、使った量（今と同じ整数の消化率）を使える量で割った割合（四捨五入した整数。使った量が 0 より大きく割合が 0 になるときは 1）で描く。バーの色はこの割合と 7d の日程消化率から今の `usage_color_num` で決める
- **足した分の空き**: バーのセルのうち、使える量の 100% に当たる位置（`BAR_WIDTH × 100 ÷ 使える量` を切り捨てたセル番号）以降で、塗られていないセルの背景色を 256 色の 24（青）にする。日程の線は今と同じく背景色の上に描く
- **使える量の列**: `<使った量>/<使える量>%`（例 `20/200%`）をバーの色で右寄せに描く
- **割合と経過**: 割合の数字に続けて、今と同じ `/` と日程消化率を描く（例 `10%/59%`）。日程消化率が無ければ今と同じく付けない
- **名前**: 名前の列があるとき、`7d All` の行の名前（アカウント名の部分を含む `Claude <label>`。うしろの空白は含めない）を `\033[1;38;5;16;48;5;214m`（太字・黒字・オレンジの地）で描き、`DIM` を掛けない。active の目印 `▸ ` はそのまま前に置く。`5h` の行の名前は変えない

ロケットモードでない Claude のアカウント（値を使えて `rocket` が null）の行は、要件「ロケットモードのための列を空ける」の空白だけが違い、バーの塗り・色・割合の数字の値は今と同じにする（使える量を 100 として描く）。

この要件は、要件「値が得られたスロットごとにレートリミット行を描画する」の「バーの描画・色分け・日程線・分母表示は既存の描画関数をそのまま使い、意味論を変えてはならない」に、ロケットモードの `7d All` の行に限って優先する（SHALL）。

#### Scenario: リセット権 1 枚で 200% になる
- **WHEN** 7d の消化率が 20%・日程消化率が 59% のスロットの要素が、`rocket` `{count: 1}`・`capacity_pct` 200 である
- **THEN** ANSI を除いたそのスロットの `7d All` の行は、バーの直前が `🚀  `、バーの直後が `  20/200%   10%/59%` になる。バーの 16 セルのうち 1 セル目が塗られ、9 セル目から 16 セル目の背景色が 24 になる

#### Scenario: リセット権 2 枚で 🚀2 と 300% になる
- **WHEN** 7d の消化率が 20%・日程消化率が 59% のスロットの要素が、`rocket` `{count: 2}`・`capacity_pct` 300 である
- **THEN** ANSI を除いたその行は、バーの直前が `🚀2 `、バーの直後が `  20/300%    7%/59%` になる。6 セル目以降の塗られていないセルの背景色が 24 になる

#### Scenario: ロケットモードの名前はオレンジの地になる
- **WHEN** 2 スロットの登録簿で、スロット `a`（label `A`）がロケットモードである
- **THEN** `a` の `7d All` の行の名前 `Claude A` の直前に `\033[1;38;5;16;48;5;214m` が付き、`a` の `5h` の行の名前には付かない

#### Scenario: 色は使える量に対する割合で決まる
- **WHEN** 7d の消化率が 80%・日程消化率が 30%、`capacity_pct` 200 のロケットモードである
- **THEN** 割合は 40% で、バーと数字の色は `usage_color_num 40 30` の値（203）になる

### Requirement: Codex のロケットモードを描く
Codex のアカウントの値を使えて `rocket` が null でないとき（ロケットモード）、statusline は Codex の行の週次の窓（`windowDurationMins` が 10080）を次のとおり描かなければならない（SHALL）。

- **🚀 の列**: `rocket.count` に関わらず `🚀` に半角スペース 2 つを続ける（数を付けない）
- **経過**: 日程消化率を、窓の始まり（週次のリセット時刻 − 604800 秒）から `rocket.earliest_expiry` までに対する現在の位置（整数に切り捨て、0 から 100）にする。バーの日程の線・色・`/` のうしろの数字にこの値を使う。現在が窓の始まりより前なら日程消化率は無い扱いにする
- **残り時間**: 今の週次のリセットまでの残り時間の代わりに、`rocket.earliest_expiry` までの残り時間（`fmt_left` の書式）を 256 色の 214（24 時間以内は 203）で描き、続けて半角スペースと、かっこに入れた週次のリセットまでの残り時間（例 ` (~6d 6h)`）を `DIM` で描く
- **使える量**: 足さない。バーと割合の数字は今の消化率のまま描き、使える量の列は空白で埋める
- **名前**: Codex の行の名前を要件「Claude のロケットモードを描く」と同じ色の指定で描く

経過と残り時間は statusline が描くたびに数える。`.headroom.json` の `elapsed_pct`・`deadline_at` は読まない。週次以外の窓（5 時間など）はこの要件で変えない。

この要件は、要件「Codex のアカウント上限を最後に1行追加する」の「同じバー・色・日程線・リセット残時間で描き」に、ロケットモードの週次の窓に限って優先する（SHALL）。

#### Scenario: 経過と残り時間が失効に対して描かれる
- **WHEN** Codex の週次の窓のリセットが現在の 6 日 6 時間後、`rocket.earliest_expiry` が現在の 1 日 20 時間後、消化率が 42% である
- **THEN** ANSI を除いた Codex の行は、バーの直前が `🚀  `、割合と経過が `42%/` に失効に対する経過の値（窓の始まり 18 時間前から 1 日 20 時間後までに対する 18 時間の位置で 29%）を続けたもの、残り時間が `~1d 20h (~6d 6h)` になる

#### Scenario: 24 時間以内は残り時間が赤になる
- **WHEN** Codex がロケットモードで、`rocket.earliest_expiry` が現在の 9 時間後である
- **THEN** 失効までの残り時間 `~9h 0m` に 256 色の 203 が付き、かっこの週次のリセットまでの残り時間には `DIM` が付く

#### Scenario: Codex は数を付けない
- **WHEN** Codex の要素が `rocket` `{count: 3}` である
- **THEN** 🚀 の列は `🚀  ` で、`🚀3` は出ない

### Requirement: リセット権の区画を 🚀 と数で描く
値を使えるアカウントの行では、statusline は今の右端のリセット権の区画（要件「Claude のアカウントの行にリセット権の残数と期限を表示する」「Codex リセット権の残数と期限を表示する」の `リセットN回・…`）を出さず、同じ位置（行の最後、経過時間のあと）に、`.headroom.json` の `tickets` から次の区画を出さなければならない（SHALL）。

- 区画は区切り（半角スペース 2 つ＋`│`＋半角スペース 2 つ。今の区切りと同じ）に続けて `🚀×<tickets.count>` と、`tickets.earliest_expiry` があれば半角スペースと失効までの残り時間（`fmt_left` の書式。例 `🚀×3 ~1d 20h`）
- Codex のロケットモードでは残り時間を付けず `🚀×<tickets.count>` だけにする（要件「Codex のロケットモードを描く」の残り時間と重なるため）
- 色: ロケットモードの Claude のアカウントは 256 色の 214、そのうち失効まで 24 時間以内は 203。Codex のロケットモードは 214。ロケットモードでないアカウントは `DIM`
- `tickets` が null か `count` が 0 なら区画を出さない

値を使えないアカウントの行は、今の区画をそのまま出す。この要件は、値を使えるアカウントの行に限り、上の 2 つの要件に優先する（SHALL）。

#### Scenario: ロケットモードの区画はオレンジ
- **WHEN** Claude のスロットがロケットモードで、`tickets` が `{count: 3}`・最短の失効が現在の 1 日 15 時間後である
- **THEN** そのスロットの `7d All` の行の末尾に `🚀×3 ~1d 15h` が 256 色の 214 で出て、`リセット` の文字列は出ない

#### Scenario: 24 時間以内は赤
- **WHEN** Claude のスロットがロケットモードで、`tickets` の最短の失効が現在の 18 時間後である
- **THEN** 区画の `🚀×N ~18h 0m` に 256 色の 203 が付く

#### Scenario: 週次リセットより後に切れるだけなら灰色で 🚀 は出ない
- **WHEN** Claude のスロットの要素が `rocket` null・`tickets` `{count: 1}`（失効は現在の 10 日 3 時間後）・`capacity_pct` 100 である
- **THEN** そのスロットの行に 🚀 の列の印は出ず、末尾に `🚀×1 ~10d 3h` が `DIM` で出る。バーと割合の数字の値は `.headroom.json` が無いときと同じ

#### Scenario: Codex のロケットモードは数だけ
- **WHEN** Codex がロケットモードで、`tickets` が `{count: 3}` である
- **THEN** Codex の行の末尾は `🚀×3` で、うしろに残り時間が付かない

#### Scenario: リセット権が無ければ区画を出さない
- **WHEN** 値を使えるアカウントの要素の `tickets` が null、または `count` が 0 である
- **THEN** そのアカウントの行の末尾に区切りの `│` 以降の区画は出ない

