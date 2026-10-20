## RENAMED Requirements

- FROM: `### Requirement: オフのスロットは値の代わりに off を 1 行出す`
- TO: `### Requirement: オフのスロットは表示しない`
- FROM: `### Requirement: Codex がオフのとき Codex 行は off を出し、取得しない`
- TO: `### Requirement: Codex がオフのとき表示行を出さず、取得しない`

## MODIFIED Requirements

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

### Requirement: スロットが 1 つのときは現行と同一の出力にする
Codex 表示が無効でスロットが 1 つだけのとき（レジストリ不在を含む）、statusline のレートリミット表示はこの変更の前と**バイト単位で同一**でなければならない（SHALL）。`label` 列を出してはならない（MUST NOT）。active の目印も出してはならない（MUST NOT）— 目印は「複数あるうちのどれか」を示すためのもので、スロットが 1 つのときには示す対象が無い。

登録簿には複数スロットがあっても、非 active のオフスロットを除いた表示対象の Claude スロットが 1 つだけなら同じ 1 スロット表示にしなければならない（SHALL）。active 判定そのものは非表示のスロットも含む登録簿全体で行う。

#### Scenario: レジストリ不在で現行と同一
- **WHEN** レジストリファイルが存在しない状態で、変更前と同じ stdin と snapshot を与えて statusline を実行する
- **THEN** 出力は変更前の出力とバイト単位で一致し、`label` 列も active の目印も現れない

#### Scenario: 1 スロットのレジストリでも label を出さない
- **WHEN** スロットを 1 つだけ持つレジストリを与えて statusline を実行する
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

### Requirement: Codex の行の名前は Codex とアカウント名にする
Codex の行が表示されるとき、その左端の名前は `Codex <label>` でなければならない（SHALL）。`<label>` は要件「Codex の表示名を codex.label で決める」（`usage-account-registry` capability）で決まる値で、`codex.label` が無ければ `A` である。`取得待ち` の行にもこの名前を用いる。表示される Codex 行の名前列は Claude の表示対象スロットと共通の最大値で揃える。Codex がオフのときは要件「Codex がオフのとき表示行を出さず、取得しない」に従い、Codex 行を出さず、名前列の幅にも数えない。Codex の取得方法はこの要件で変えない（MUST NOT）。

表示する Claude スロットが 1 つ以下（レジストリ不在、または非 active のオフスロットを除いて 1 つになる場合を含む）のとき、Claude 側の行には名前を出さない現行のままとし（バイト単位で同一）、Codex の行だけが `Codex <label>` を名前として持つ。

#### Scenario: codex.label が無ければ Codex A
- **WHEN** Codex の値が得られる状態で、`codex.label` を持たないレジストリを与えて statusline を実行する
- **THEN** Codex の行の名前は `Codex A` になる

#### Scenario: codex.label があればそれを使う
- **WHEN** Codex の値が得られる状態で、レジストリのトップレベルが `"codex": {"label": "X"}` を持つ
- **THEN** Codex の行の名前は `Codex X` になる

#### Scenario: Codex が無くスロットが 1 つなら出力は変わらない
- **WHEN** Codex の行が出ない状態で、レジストリ不在またはスロット 1 つのレジストリを与えて statusline を実行する
- **THEN** 出力は変更前とバイト単位で一致する
