## MODIFIED Requirements

### Requirement: スロットが 1 つのときは現行と同一の出力にする
Codex 表示が無効でスロットが 1 つだけのとき（レジストリ不在を含む）、statusline のレートリミット表示は、リセット権の区画（要件「Claude のアカウントの行にリセット権の残数と期限を表示する」）が出ない場合はこの変更の前と**バイト単位で同一**でなければならない（SHALL）。区画が出る場合の差は、そのスロットの最後の行の末尾への区画の追加だけで、それ以外の部分（バー・色・経過時間・行数）は変えてはならない（MUST NOT）。`label` 列を出してはならない（MUST NOT）。active の目印も出してはならない（MUST NOT）— 目印は「複数あるうちのどれか」を示すためのもので、スロットが 1 つのときには示す対象が無い。

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

#### Scenario: 区画が出る 1 スロットでは区画の追加だけが差になる
- **WHEN** 1 スロットで `reset_grants` を持つ snapshot と、それを除いた同じ snapshot を同じ stdin で描く
- **THEN** 前者の出力は後者の出力の最後の行の末尾に区画が付いただけで、label 列も active の目印も無く、他の部分は一致する


## ADDED Requirements

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
