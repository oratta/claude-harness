# dev-workflow-unclear-reply-rephrase Specification

## Purpose
主の発言に説明が伝わっていないことを示す語（「意味わからん」「説明して」など）があるときだけ、UserPromptSubmit の hook が、正本（`~/.claude/output-styles/readable.md` の節 3）の型で子の作業の言葉を使わずに言い直すよう促す文を差し込む規則を定める。
## Requirements
### Requirement: UserPromptSubmit の 2 件目のエントリで言い直しの hook を起動する

`plugins/dev-workflow/hooks/hooks.json` の `UserPromptSubmit` は、2 件目のエントリとして `"${CLAUDE_PLUGIN_ROOT}/scripts/unclear-reply-rephrase.sh"` を `type` が `command` の hook で起動しなければならない（MUST）。1 件目のエントリ（`prompt-tripwires-refresh.sh`）は変えてはならない（MUST NOT）。2 件目のエントリには `matcher` と `timeout` を付けてはならない（MUST NOT）。スクリプトは実行権限を持たなければならない（MUST）。スクリプトが python3 を起動するときは `python3 -I` で起動しなければならない（MUST）。

#### Scenario: hooks.json に 2 件目のエントリがある
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` を JSON として読む
- **THEN** `hooks.UserPromptSubmit` は 2 件のエントリを持ち、1 件目の hook の `command` は `prompt-tripwires-refresh.sh` を含み、2 件目の hook は `type` が `command` で `command` に `${CLAUDE_PLUGIN_ROOT}` と `scripts/unclear-reply-rephrase.sh` を含み、2 件目のエントリにも hook にも `matcher` と `timeout` のキーが無い

#### Scenario: スクリプトが実行できる
- **WHEN** `plugins/dev-workflow/scripts/unclear-reply-rephrase.sh` の権限を調べる
- **THEN** 実行権限が付いている

### Requirement: 決めた語を含む発言にだけ言い直しを促す文を差し込む

`unclear-reply-rephrase.sh` は、標準入力の JSON の `prompt` の文字列に次の語のどれかが部分一致で含まれるとき、標準出力に JSON オブジェクトを 1 つだけ書かなければならない（MUST）。語（この順を「語の一覧の順」と呼ぶ）: `意味わから`・`意味分から`・`意味がわから`・`意味が分から`・`意味不明`・`わからん`・`分からん`・`解らん`・`わかんない`・`分かんない`・`説明して`・`読みにくい`・`読み難い`・`伝わらない`・`伝わってない`・`何言って`・`なに言って`。

出力のオブジェクトのキーは `hookSpecificOutput` だけで、その `hookEventName` は `UserPromptSubmit`、`additionalContext` は空でない文字列でなければならない（MUST）。`decision`・`continue`・`systemMessage` を返してはならない（MUST NOT）。

どの語も含まない発言では、何も出力してはならない（MUST NOT）。次の行は、語を探す対象から外さなければならない（MUST）。①行頭の空白のあとが 3 つの逆引用符（```）で始まる行（```bash のように後ろに言語名などが続いてもよい）から、次に同じ条件の行が来るまでの行（開きと閉じの行を含む。閉じの行が来なければ発言の終わりまで）②行頭の空白のあとが `>` で始まる行。`わからない`・`分からない` だけの形と、`意味が` に `わから`・`分から` が続かない形（`意味がない` など）は語として扱ってはならない（MUST NOT）。

複数の語に当たるときは、語の一覧の順で最初に当たった語を 1 つだけ示さなければならない（MUST）（「意味わからん」は `わからん` にも当たるが、示すのは `意味わから`）。

守備範囲: ①想定する入力の出どころは、主が送った発言（`UserPromptSubmit` の hook に Claude Code が渡す `prompt`。`claude -p` で起動した子のセッションに渡る指示文も含む）である。②拾いたいのは、直前の説明が伝わらなかったと主が言う発言である。③差し込みが出なくてよい取りこぼしの例は「は？」「どういうこと」「原因がわからない、調べて」で、誤って出てよい例は「この関数を説明して」「なんで落ちるかわからん、調べて」である。誤って出たときの害は、差し込む文の「主の発言が新しい依頼なら、その依頼に答える」で抑える。④取りこぼした言い方が見つかったら語の一覧に足すが、伝わっていないことを示す言い方をすべて拾い切ることを、この要件の完了条件にしない。

入力の JSON の文字列が `\uXXXX` の形で逃がされていても、JSON として読んだあとの文字列で語を探さなければならない（MUST）。

#### Scenario: 語を含む発言で差し込みが出る
- **WHEN** `{"session_id":"s1","hook_event_name":"UserPromptSubmit","prompt":"<語の一覧のどれか 1 つを含む文>"}` を標準入力に渡す（語の一覧のすべての語について 1 つずつ確かめる）
- **THEN** 終了コードは 0 で、標準出力は JSON として読めるオブジェクト 1 つであり、キーの集合は `hookSpecificOutput` だけで、`hookEventName` が `UserPromptSubmit`、`additionalContext` が空でない

#### Scenario: 語を含まない発言では何も出ない
- **WHEN** `prompt` が「進めて」「原因がわからない、調べて」「やる意味がない」のどれかの入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 逆引用符のブロックと引用の行の中の語では出ない
- **WHEN** `prompt` が「このログを見て」に続けて逆引用符のブロックの中に `説明して` を含む文と、`> 意味不明` の引用の行だけを持つ入力を渡す
- **THEN** 終了コードは 0 で、標準出力は空である

#### Scenario: 言語名つきの開きのブロックと閉じられないブロックの中の語では出ない
- **WHEN** `prompt` が「見て」の行、```bash の行、`説明して` の行、``` の行を持つ入力と、「見て」の行、``` の行、`意味不明` の行で終わる（閉じの行が無い）入力を、それぞれ渡す
- **THEN** どちらも終了コードは 0 で、標準出力は空である

#### Scenario: ブロックの閉じのあとの語では出る
- **WHEN** `prompt` が ```bash の行、`ls` の行、``` の行、「これ説明して」の行を持つ入力を渡す
- **THEN** 差し込みの JSON が出る

#### Scenario: 複数の語に当たると一覧の順で最初の語を示す
- **WHEN** `prompt` が「意味わからん」の入力を渡す
- **THEN** `additionalContext` は `意味わから` を示し、`わからん` を当たった語として示さない

#### Scenario: 引用の外に語があれば出る
- **WHEN** `prompt` が `> 前の説明の引用` の行と、その次の行の「これ意味わからん」を持つ入力を渡す
- **THEN** 差し込みの JSON が出る

#### Scenario: 逃がされた日本語でも当たる
- **WHEN** `prompt` の値を `\u8aac\u660e\u3057\u3066`（逃がしを解くと `説明して`）と書いた入力を渡す
- **THEN** 差し込みの JSON が出る

### Requirement: 差し込む文は正本の場所を指し、型の中身を写さない

`additionalContext` の文は、次のすべてを満たさなければならない（MUST）。

- 正本を `~/.claude/output-styles/readable.md` の形のパスと「節 3」で指す
- 直前の説明が伝わっていないものとして扱い、子の作業の言葉や仕組みの名前を使わずに言い直すよう促す
- 主の発言が新しい依頼なら、その依頼に答えるよう添える
- 当たった語を 1 つ示す（複数に当たるときは語の一覧の順で最初の語）

文は、正本の型の中身を写してはならない（MUST NOT）。具体的には `主に聞く理由`・`いま困っていること`・`推奨と根拠`・`受け入れるリスク`・`答え方`・`主の側にしか答えが無い`・`決まりで主の承認が要る`・`主の手でしかできない操作` のどれも含んではならない（MUST NOT）。リポジトリ相対パス（`~/.claude/` の付かない `output-styles/readable.md`）で正本を指してはならない（MUST NOT）。

正本 `output-styles/readable.md` は `## 3. 判断を求めるときは` で始まる見出しを持ち続けなければならない（MUST）。正本の節の番号を変える変更は、この文も同じ変更で直す。

#### Scenario: 文が正本を指し、型の中身を持たない
- **WHEN** 語を含む発言で出た `additionalContext` を読む
- **THEN** `~/.claude/output-styles/readable.md` と `節 3` と当たった語と「新しい依頼」を含み、上に挙げた型の中身の語をどれも含まない

#### Scenario: 指している節が正本にある
- **WHEN** `output-styles/readable.md` の見出しを読む
- **THEN** `## 3. 判断を求めるときは` で始まる見出しがある

### Requirement: どの入力でも発言の送信を止めない

`unclear-reply-rephrase.sh` は、どの入力でも終了コード 0 で終わらなければならない（MUST）。JSON として読めない入力・`prompt` が無い入力・`prompt` が文字列でない入力・空の入力では、何も出力してはならない（MUST NOT）。標準エラーに何も書いてはならない（MUST NOT）。

#### Scenario: 壊れた入力で何も出さずに終わる
- **WHEN** 空の入力、`{` だけの入力、`{"session_id":"s1"}`、`{"prompt":123}` のどれかを渡す
- **THEN** 終了コードは 0 で、標準出力と標準エラーはどちらも空である

#### Scenario: 壊れた JSON の中に語があっても止めない
- **WHEN** `{"prompt":"説明して` のように語を含むが JSON として閉じていない入力を渡す
- **THEN** 終了コードは 0 で、標準出力と標準エラーはどちらも空である

