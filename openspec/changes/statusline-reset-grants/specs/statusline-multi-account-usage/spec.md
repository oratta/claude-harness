## ADDED Requirements

### Requirement: Claude のアカウントの行にリセット権の残数と期限を表示する
`plugins/statusline/scripts/statusline.sh` は、表示する Claude の各スロットについて、snapshot（`dev-workflow-escalation-tripwires` capability の「usage-probe と snapshot 契約」）の `accounts.<id>.reset_grants` が読めるとき、そのスロットの最後の行（7d の行があればそれ、無ければ 5h の行）の末尾に、行末の経過時間のあとに続けて ` │ ` を挟んで残数と最短期限を表示しなければならない（SHALL）。書式・色・欠測の扱いは要件「Codex リセット権の残数と期限を表示する」と同じにする: `リセットN回・最短あとXdYh`（24 時間未満は `あとXhYm`）、期限まで 3 日以内は黄、24 時間以内は赤、それより先は DIM、有効な束に期限のあるものが無ければ `期限不明`、最短期限を過ぎていれば `期限経過（更新待ち）`。

数え方: `resets_left` が 0 より大きい整数で `paused` が true でない束だけを数える。残数は `resets_left` の和、最短期限は数えた束の `ends_at` のうち読めるものの最小値。`ends_at` が null・欠落・読めない値の束は残数には数え、期限には含めない。`reset_grants` が空の配列なら `リセット0回` を表示する。`reset_grants` が無い・配列でない、または束が 1 つ以上あるのにすべて読めない・使えない（`resets_left` が整数でない・負など）ときは、区画を出してはならない（MUST NOT）。欠測を 0 回として扱わない。

`reset_grants` が読めないスロットの行、および snapshot が無いときの出力は、この要件を足す前とバイト単位で同一でなければならない（SHALL）。表示処理はリセット権を使う API を呼んではならず、リセット権のための通信を増やしてはならない（MUST NOT）。値の出どころは snapshot の欄だけとし、statusline は別のキャッシュを持たない。

#### Scenario: 残数と最短期限が出る
- **WHEN** active スロットの snapshot の `reset_grants` が `resets_left` 1 の束 2 つ（`ends_at` が 3 日 21 時間後と 10 日後、どちらも `paused: false`）である
- **THEN** そのスロットの最後の行の末尾に `リセット2回・最短あと3日21h` が出る

#### Scenario: 3 日以内は黄、24 時間以内は赤
- **WHEN** 最短期限が 2 日後の snapshot と 12 時間後の snapshot をそれぞれ描く
- **THEN** 前者は黄の色コード、後者は赤の色コードが、`リセット…` の文字列に付く

#### Scenario: paused と 0 回の束は数えない
- **WHEN** `reset_grants` が `paused: true` の束と `resets_left: 0` の束と、`resets_left: 1` の有効な束 1 つである
- **THEN** 残数は 1 回で、最短期限は有効な束の `ends_at` になる

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
