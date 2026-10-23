## ADDED Requirements

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

## MODIFIED Requirements

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
