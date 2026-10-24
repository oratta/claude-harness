# dev-workflow-owner-message-number-check Specification

## Purpose
TBD - created by archiving change owner-message-number-check-hook. Update Purpose after archive.

## Requirements

### Requirement: Stop のエントリで主への発言の番号の検査を起動する

`plugins/dev-workflow/hooks/hooks.json` は `hooks.Stop` に 1 件のエントリを持ち、その hook は `type` が `command` で `"${CLAUDE_PLUGIN_ROOT}/scripts/owner-message-number-check.sh"` を起動しなければならない（MUST）。このエントリにも hook にも `matcher` と `timeout` を付けてはならない（MUST NOT）。既存の他のイベントのエントリは変えてはならない（MUST NOT）。スクリプトは実行権限を持ち、python3 を起動するときは `python3 -I` で起動しなければならない（MUST）。

#### Scenario: hooks.json に Stop のエントリがある
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` を JSON として読む
- **THEN** `hooks.Stop` は 1 件のエントリを持ち、その hook は `type` が `command` で、`command` に `${CLAUDE_PLUGIN_ROOT}` と `scripts/owner-message-number-check.sh` を含み、エントリにも hook にも `matcher` と `timeout` のキーが無い

#### Scenario: スクリプトが実行できる
- **WHEN** `plugins/dev-workflow/scripts/owner-message-number-check.sh` の権限を調べる
- **THEN** 実行権限が付いている

### Requirement: 発言の本文を、逆引用符のブロックを除いた空でない行の並びとして読む

`owner-message-number-check.sh` は、標準入力の JSON の `last_assistant_message` を発言の本文として読み、行頭の空白のあとが 3 つの逆引用符（```）で始まる行から次に同じ条件の行が来るまで（開きと閉じの行を含む。閉じが無ければ本文の終わりまで）を除いた、空白だけでない行の並びとして扱わなければならない（MUST）。`>` で始まる引用の行は除いてはならない（MUST NOT）。

守備範囲: ①入力は `Stop` の payload の `last_assistant_message`（主がそのまま読む本文）。②拾いたいのは、ブロックに貼ったログの `#数字` や `?` を依頼の本文と取り違える誤り。③除かずに数えてよい例は `>` の引用・`~~~` のブロック・4 字の字下げ。`>` を除かないのは、全行を主が読み、引用の中の番号も探す手間になるため。④見分け切ることを完了条件にしない。

#### Scenario: 逆引用符のブロックの中の行は 1 行目にも番号にも数えない
- **WHEN** `last_assistant_message` が逆引用符のブロック（中に `#42 をどうしますか？`）で始まり、ブロックのあとに「テストは通った。」の行だけを持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 引用の行の番号は数える
- **WHEN** `last_assistant_message` が「この手順書を入れてよいですか？」の行と `> #1712 の手順` の行を持ち、URL を持たない入力を渡す
- **THEN** 差し戻しの JSON が出て、`reason` は `行 2: #1712` を含む

### Requirement: 1 行目と区切りを決める

以下の要件の「1 行目」は、上の要件の行の並びの最初の行から前後の空白と `*` を除いたものでなければならない（MUST）。「区切り」は、並びのうち前後の空白を除くと `-` だけが 3 つ以上並ぶ最初の行で、区切りが無ければ本文全体を「区切りより上」として扱わなければならない（MUST）。区切りより上の行の順は、並びの最初の行を 1 として数える。

#### Scenario: 太字の質問も 1 行目の質問として扱う
- **WHEN** `last_assistant_message` が「**PR #1712 を入れてよいですか？**」の行だけを持つ入力を渡す
- **THEN** 差し戻しの JSON が出て、`reason` は `行 1: #1712` を含む

### Requirement: 主がすることの無い報告を対象にしない

1 行目が `主がすること` で始まり、`:` か `：` と 0 個以上の空白を挟んで `なし` が続く発言は、番号があっても対象にしてはならず、何も出力してはならない（MUST NOT）。

#### Scenario: 報告は番号があっても対象にしない
- **WHEN** `last_assistant_message` が「主がすること: なし」で始まり、次の行に「#1712 をマージした」を持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 太字で空白の無い報告の 1 行目も対象にしない
- **WHEN** `last_assistant_message` が「**主がすること:なし**」の行と「#1712 をマージした。」の行だけを持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 番号を含まない報告は差し戻さない
- **WHEN** `last_assistant_message` が「主がすること: なし」の行と「手順書をマージした。」の行だけを持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

### Requirement: 主に判断・確認・操作を求める発言だけを対象にする

上の要件で対象外にしなかった発言は、1 行目の末尾の文字が `？` か `?` であるか、区切りより上の最後の行が `と打って`・`を押して`・`と返して`・`と答えて` のどれかを含むときだけ対象にしなければならない（MUST）。対象にしない発言では何も出力してはならない（MUST NOT）。

守備範囲: ①入力は、メインセッション（`claude -p` の子を含む）の `Stop` の payload。②拾いたいのは、正本の 1 行目の書き分けに従って書いた主への依頼。③通してよい例は、1 行目が質問でなく答え方の行も無い依頼と、ツールで送った発言。`と書いて` は「…と書いてある」で当たるので入れず、「…と書いてください」の依頼は 1 行目の質問で拾う。答えの 1 行目が問い返しで入る害は理由の最後の文で抑える。④見分け切ることを完了条件にしない。

#### Scenario: 1 行目が質問でも答え方の行でもない発言は対象にしない
- **WHEN** `last_assistant_message` が「テストは通った。」の行と「#1712 を直した。」の行だけを持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 答え方の行で対象に入る
- **WHEN** `last_assistant_message` が「次の変更を入れる。」の行、「#1712 の続き。」の行、「よければ『OK』と打ってください。」の行を持つ入力を渡す
- **THEN** 差し戻しの JSON が出る

### Requirement: 区切りより上の番号と、リンクの無い番号を差し戻す

対象の発言について、本文から `http://` か `https://` で始まり空白の手前までの並び（URL）を取り除いたあとで、`#` に数字が続く並び（番号）を探さなければならない（MUST）。区切りより上に番号がある（条件 1）か、本文のどこかに番号があるのに、パスに `/issues/` か `/pull/` に数字が続く部分を含む URL が本文に 1 本も無い（条件 2）とき、キーが `decision`（値 `block`）と `reason`（空でない文字列）だけの JSON オブジェクトを 1 つ出さなければならない（MUST）。どちらにも当たらなければ何も出力してはならない（MUST NOT）。

守備範囲: ①入力は上の要件で対象にした発言。②拾いたいのは、番号で物を指したまま、または指す物を開けるリンク無しで主に届く発言。③通してよい例は、`#` の付かない番号（「PR 1712」）と、issue・PR でない物の番号。④番号の書き方をすべて拾い切ることを完了条件にしない。

#### Scenario: 1 行目の番号とリンクの無さで差し戻す
- **WHEN** `last_assistant_message` が「PR #1712 のリスクを許容しますか？」の行と「よければ『OK』と打ってください。」の行を持ち、URL を持たない入力を渡す
- **THEN** 終了コードは 0 で、標準出力は JSON として読めるオブジェクト 1 つであり、キーの集合は `decision` と `reason`、`decision` は `block` で、`reason` は `行 1: #1712` と `issue・PR の URL が 1 本も無い` を含む

#### Scenario: 番号が区切りより下と URL の中にだけあれば差し戻さない
- **WHEN** `last_assistant_message` が「子が書いた手順書をマージしてよいですか？」の行、「よければ『OK』と打ってください。」の行、`---` の行、「経緯: #1209 で決まりを直した。」の行、`https://github.com/oratta/claude-harness/pull/1712` の行を持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 区切りより上に URL があっても URL の外の番号は差し戻す
- **WHEN** `last_assistant_message` が「#1712 をマージしてよいですか？」の行と `https://github.com/oratta/claude-harness/pull/1712` の行を持つ入力を渡す
- **THEN** 差し戻しの JSON が出て、`reason` は `行 1: #1712` を含み、`issue・PR の URL が 1 本も無い` を含まない

#### Scenario: 区切りより下の番号でもリンクが無ければ差し戻す
- **WHEN** `last_assistant_message` が「手順書をマージしてよいですか？」の行、`---` の行、「経緯: #1209」の行を持ち、URL を持たない入力を渡す
- **THEN** 差し戻しの JSON が出て、`reason` は `issue・PR の URL が 1 本も無い` を含み、`行 ` で始まる番号の指摘を含まない

#### Scenario: URL の中の `#` と逆引用符のブロックの中の番号は数えない
- **WHEN** `last_assistant_message` が「この変更を入れてよいですか？」の行、`https://github.com/o/r/issues/5#issuecomment-123` の行、逆引用符のブロックの中の `#42` の行を持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

### Requirement: 差し戻しの理由は事実と正本の場所だけを書く

`reason` は `[dev-workflow 主への発言の差し戻し]` で始め、条件 1 なら区切りより上の番号を持つ行ごとに行の順と番号を `行 <順>: <番号>` の形ですべて示し、条件 2 なら `issue・PR の URL が 1 本も無い` の文字列を含めなければならない（MUST）。条件 2 に当たらないときは、この文字列を含めてはならない（MUST NOT）。続けて、`~/.claude/output-styles/readable.md` の節 3 の「ほかの決まり」の段落と 1 行目の書き分けの段落を書き直す先として指し、発言全体を書き直して出し直すこと、差し戻しはこのターンで 1 回だけであること、主への依頼でなければそのまま終えてよいことを書かなければならない（MUST）。

#### Scenario: 理由が事実と正本の場所を持つ
- **WHEN** 差し戻しの JSON の `reason` を読む
- **THEN** `[dev-workflow 主への発言の差し戻し]` で始まり、`~/.claude/output-styles/readable.md` と `節 3` と `ほかの決まり` と `1 行目` と `1 回` を含む

### Requirement: 差し戻しの理由に正本の文言を写さない

`reason` は、正本の決まりの文言を写してはならない（MUST NOT）。具体的には `中身で書`・`末尾の URL にだけ置く`・`番号で物を指さ` のどれも含んではならず、`~/.claude/` の付かない `output-styles/readable.md` で正本を指してはならない（MUST NOT）。正本 `output-styles/readable.md` は、`## 3. 判断を求めるときは` で始まる見出しと、その節の中に `ほかの決まり` で始まる段落・`番号は末尾の URL にだけ置く` の文・`主がすること: なし` の語を持ち続けなければならない（MUST）。これらを変える変更は、`reason` の文も同じ変更で見直す。

#### Scenario: 理由が正本の文言を持たない
- **WHEN** 差し戻しの JSON の `reason` を読む
- **THEN** `中身で書`・`末尾の URL にだけ置く`・`番号で物を指さ` のどれも含まず、`~/.claude/` の付かない `output-styles/readable.md` を含まない

#### Scenario: 指している段落が正本にある
- **WHEN** `output-styles/readable.md` を読む
- **THEN** `## 3. 判断を求めるときは` で始まる見出しがあり、その見出しから次の `## ` の見出しまでの間に、`ほかの決まり` で始まる行と `番号は末尾の URL にだけ置く` と `主がすること: なし` がある

### Requirement: 1 ターンに 1 回だけ差し戻し、どの入力でもセッションを止め続けない

`owner-message-number-check.sh` は、標準入力の JSON の `stop_hook_active` が `true` のとき、環境変数 `DEV_WORKFLOW_OWNER_NUMBER_CHECK` が `off` のとき、JSON に `agent_id` のキーがあるとき、入力が空・JSON として読めない・オブジェクトでない・`last_assistant_message` が無いか文字列でないとき、python3 が無いときは、何も出力せずに終わらなければならない（MUST）。どの入力でも終了コード 0 で終わり、標準エラーに何も書いてはならない（MUST）。

#### Scenario: 同じターンの 2 回目は差し戻さない
- **WHEN** 1 回目に差し戻した入力と同じ `last_assistant_message`（「PR #1712 のリスクを許容しますか？」）で、`stop_hook_active` を `true` にした入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 全解除で差し戻さない
- **WHEN** `DEV_WORKFLOW_OWNER_NUMBER_CHECK=off` を設定して、差し戻しに当たる入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: サブエージェントの停止として渡されたら差し戻さない
- **WHEN** 差し戻しに当たる `last_assistant_message` に `agent_id` のキーを足した入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 壊れた入力で何も出さずに終わる
- **WHEN** 空の入力、`{` だけの入力、`[]`、`{"session_id":"s1"}`、`{"last_assistant_message":123}`、`{"last_assistant_message":"PR #1712 を許容しますか？"`（閉じていない）のどれかを渡す
- **THEN** 終了コードは 0 で、標準出力と標準エラーはどちらも空である
