## ADDED Requirements

### Requirement: コンパクト直後に develop を呼んでいた会話へ SKILL.md の読み直しを差し込む hook を登録する
`plugins/dev-workflow/hooks/hooks.json` は、SessionStart に matcher `compact` のエントリを置き、`${CLAUDE_PLUGIN_ROOT}/scripts/develop-compact-reread.sh` を呼ぶ command を登録しなければならない（MUST）。スクリプトは stdin の JSON の `source` が `compact` のときだけ働き、それ以外（`startup`・`clear`・`resume`・空・`source` が無い）では、会話で develop を呼んでいても何も出さずに exit 0 で終わらなければならない（MUST）。

#### Scenario: hooks.json が compact の SessionStart に登録している
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の `hooks.SessionStart` を読む
- **THEN** matcher を `|` で区切った値に `compact` を含み、`develop-compact-reread.sh` を呼ぶ command を持つエントリがある

#### Scenario: compact 以外の起動では何も出さない
- **WHEN** 会話記録に `dev-workflow:develop` の Skill 呼び出しがあり、`source` が `startup`・`clear`・`resume`・空文字のいずれかの入力でスクリプトを実行する
- **THEN** stdout は空で exit 0

### Requirement: develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する
スクリプトは stdin の `transcript_path` が指す会話記録（jsonl）を 1 行ずつ読み、次のどれかが 1 つあれば「develop を呼んでいた」とみなさなければならない（MUST）。(a) `type` が `assistant` の行の `message.content` にある `type: tool_use`・`name: Skill` のブロックで、`input.skill` が `dev-workflow:develop`。(b) `type` が `user` の行の `message.content` が文字列か、一覧の `type: text` のブロックの `text` で、`<command-name>/dev-workflow:develop</command-name>` を含む。(c) `type` が `attachment` の行の `attachment.type` が `invoked_skills` で、`skills` の要素の `name` が `dev-workflow:develop`。

#### Scenario: Skill 呼び出しで数える
- **WHEN** 会話記録に `input.skill` が `dev-workflow:develop` の Skill の tool_use があり、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

#### Scenario: 文字列の user の発言のコマンドで数える
- **WHEN** 会話記録の user の行の `message.content` が `<command-name>/dev-workflow:develop</command-name>` を含む文字列で、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

#### Scenario: 一覧の user の発言の text のブロックのコマンドで数える
- **WHEN** user の行の `message.content` が一覧で、画像のブロックのあとの text のブロックが `<command-name>/dev-workflow:develop</command-name>` を含み、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

#### Scenario: 前のコンパクトのあとの invoked_skills で数える
- **WHEN** 会話記録に `compact_boundary` の行と、`skills` に `name: dev-workflow:develop` を持つ `invoked_skills` の attachment の行があり、`source: compact` で実行する
- **THEN** 読み直しの文を差し込む

### Requirement: 名前空間の無い develop・別のスキル・文中の言及は数えない
スクリプトは、上の 3 種類の記録の形と名前 `dev-workflow:develop` に完全に一致するものだけを数えなければならない（MUST）。次は数えてはならない（MUST NOT）: 名前空間の無い `develop`（Skill の `input.skill`・`<command-name>/develop</command-name>`・`invoked_skills` の `name`）、名前に develop を含む別のスキルやコマンド（`dev-workflow:codex-develop`・`/dev-workflow:develop-epic` など）、assistant の text のブロックや tool_result の中身で名前に触れただけのもの。develop を呼んでいない会話では何も出さない（MUST）。

#### Scenario: 名前空間の無い develop は数えない
- **WHEN** 会話記録に `input.skill` が `develop` の Skill 呼び出し、`<command-name>/develop</command-name>` の user の発言、`name: develop` の `invoked_skills` だけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: 名前に develop を含む別のスキルは数えない
- **WHEN** 会話記録に `dev-workflow:codex-develop` の Skill 呼び出しと `<command-name>/dev-workflow:develop-epic</command-name>` の user の発言だけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: 文中や tool_result で触れただけなら数えない
- **WHEN** 会話記録に、assistant の text のブロックと user の tool_result の中身に `dev-workflow:develop` や `<command-name>/dev-workflow:develop</command-name>` が書かれた行だけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: develop を呼んでいない会話では何も出さない
- **WHEN** 会話記録に普通の user の発言と `probe:hello` の Skill 呼び出しだけがあり、`source: compact` で実行する
- **THEN** stdout は空で exit 0

### Requirement: 差し込む文は SKILL.md の読み直しと親か子かの確かめ直しを求める
develop を呼んでいたと判定したとき、スクリプトは stdout に `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<文>"}}` の形の JSON を 1 つ出さなければならない（MUST）。`<文>` は次の 2 つの要素を含まなければならない（MUST）。(1) `${CLAUDE_PLUGIN_ROOT}/skills/develop/SKILL.md` の絶対パスを示し、それを Read ツールで offset と limit を使って分けて読み直すこと。(2) 自分がエピックの親か子かを記録先の issue から確かめ直してから続けること。

#### Scenario: 差し込む文が 2 つの要素を含む
- **WHEN** develop を呼んでいた会話記録で `source: compact` で実行する
- **THEN** exit 0 で、stdout の JSON の `hookSpecificOutput.hookEventName` が `SessionStart`、`additionalContext` が `<CLAUDE_PLUGIN_ROOT>/skills/develop/SKILL.md`・`offset`・`limit`・`親`・`子`・`記録先` を含む

### Requirement: 判定できないときは何も出さず、セッションの開始を止めない
スクリプトは常に exit 0 で終わらなければならない（MUST）。次のときは何も出してはならない（MUST NOT。fail-open）: stdin が空か JSON でない、`transcript_path` が無いかファイルが無い、`CLAUDE_PLUGIN_ROOT` が空、`python3` が PATH に無い。会話記録のうち JSON として読めない行と、JSON として読めるが値の型が想定と違う行は 1 行ずつ飛ばし、走査を続けなければならない（MUST。そのあとの行に呼び出しがあれば差し込む）。

#### Scenario: stdin が JSON でなければ何も出さない
- **WHEN** stdin に `not json` を渡すか、stdin を空にして実行する
- **THEN** どちらも stdout は空で exit 0

#### Scenario: 会話記録が無ければ何も出さない
- **WHEN** `transcript_path` が存在しないファイルを指す `source: compact` の入力で実行する
- **THEN** stdout は空で exit 0

#### Scenario: CLAUDE_PLUGIN_ROOT が空なら何も出さない
- **WHEN** develop を呼んでいた会話記録で、`CLAUDE_PLUGIN_ROOT` を空にして `source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: python3 が無ければ何も出さない
- **WHEN** develop を呼んでいた会話記録で、`python3` の無い PATH で `source: compact` で実行する
- **THEN** stdout は空で exit 0

#### Scenario: 壊れた行を飛ばして走査を続ける
- **WHEN** 会話記録に JSON として読めない行だけがあるときに実行し、続けてそのあとに `dev-workflow:develop` の Skill 呼び出しを足して実行する
- **THEN** 1 回目は stdout が空で exit 0、2 回目は読み直しの文を差し込む

#### Scenario: 形の違う行を飛ばして走査を続ける
- **WHEN** 会話記録に `skills` が数値の `invoked_skills`、`name` が一覧の要素、`input.skill` が一覧の Skill 呼び出し、`text` が一覧の text のブロック、最上位が一覧の行だけがあるときに実行し、続けてそのあとに `dev-workflow:develop` の Skill 呼び出しを足して実行する
- **THEN** 1 回目は stdout が空で exit 0、2 回目は読み直しの文を差し込む

### Requirement: hook の振る舞いを bats で確かめる
`plugins/dev-workflow/tests/develop-compact-reread.bats` は、要件「コンパクト直後に develop を呼んでいた会話へ SKILL.md の読み直しを差し込む hook を登録する」「develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する」「名前空間の無い develop・別のスキル・文中の言及は数えない」「差し込む文は SKILL.md の読み直しと親か子かの確かめ直しを求める」「判定できないときは何も出さず、セッションの開始を止めない」の各 Scenario を、偽の会話記録（fixture は SessionStart(compact) の時点の実機の形。今回のコンパクトの `compact_boundary` と `invoked_skills` はまだ無い）で確かめなければならない（MUST）。

#### Scenario: bats が通る
- **WHEN** `bats plugins/dev-workflow/tests/develop-compact-reread.bats` を実行する
- **THEN** 全件が通る

## MODIFIED Requirements

### Requirement: 時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が子の起動コマンドに前置きする `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` の `<値>` は、既定で `120000` でなければならない（MUST）。環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` が設定されていればその値を使う（SHALL）。設定された値が空文字か、数字だけでない文字列なら、`launch` は stderr に変数名と使い方を出して exit 1 で終わり、`orca` と `git` を 1 つも呼んではならない（MUST）。100,000 未満の値は拒まない（SHALL。下限の扱いは Claude Code が持つ）。

時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、次を書かなければならない（MUST）。

- **閾値**: 子は 120,000（`launch` が付ける。`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられる）、親も同じ 120,000。親は主が起動するセッションなので `launch` は付けられず、主が起動するセッションは主の起動コマンド（例: `cld`）が、値が未設定のときだけ 120000 を入れる（外から渡された値は上書きしない）。個人の設定ファイルのパスは書かない。どちらの値も `~/.claude/settings.json` の `env` に置かない（主の手元の全セッションに効くため）
- **分ける条件**: 子に返事を送る前に、子の端末が無ければ起動し直す。子の最後のリクエストから 60 分未満ならそのまま送る。60 分以上で、その間に待っている間の自動コンパクトが走っていればそのまま送る。60 分以上でコンパクトが走っていなければ、会話量 N が 150,000 トークン以上なら起動し直し、150,000 未満ならそのまま送る
- **判定に使う事実**: 子の端末の有無（子のワークスペースに端末が残っているか。`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻と、そのあとの `compact_boundary` の有無、会話量 N（`plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>`）
- **親への適用**: 親自身が長く待ったあとも同じ条件で、そのまま続けるか起動し直すかを決める。親の状態のうち、回し方（`回し方:`）・終わった子（`子 #N マージ → 残り k 件` / `子 #N 見送り`）・外した子エピック（`後で別に起動するエピック:`）・残したワークツリー（`子 #N のワークツリーを残した`）・親が通した判断（`親の判断: 子 #N 通した`）はエピックのコメントから、残りの子は依存グラフと子 issue の状態から復元できる
- **根拠と限り**: 値と条件の根拠として #1039 の集計コメントの URL と要点（返事の直前の会話の中央値、起動し直しの費用、閾値ごとの費用の増減）、実績の少なさと PC が寝ているとコンパクトが走らないこと。加えて、コンパクトのあと develop を呼んでいた会話には SessionStart の hook（`scripts/develop-compact-reread.sh`）が `SKILL.md` の読み直しを差し込むことと、その費用（1 回約 39k トークンで、集計の控えめの想定で足した 40k とは別にかかること）、両方を足した想定は計算し直しておらず #1264 で計算すること、控えめの想定でも 120,000 は最良と差が小さく既定の 200,000 より子で安いので値を変えていないこと（#1217 の計算コメントの URL）
- **再集計**: 1〜2 週間回したあとに同じ集計をやり直して #1039 にコメントし、値を見直す。件数・金額は合否に使わず記録する

送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の SKILL.md の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

develop の SKILL.md「エピックの扱い」の「回し方」は、子セッションの起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で「そのまま送る」か「起動し直す」かを決めることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、既定の前置き、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` での上書き、空文字と数字でない値の拒否、規則のファイルの上の記述（値・分ける条件・`settings.json` に置かないこと）、SKILL.md の上の記述を確かめなければならない（MUST）。

この要件の守備範囲は、閾値の上書き値の検査と、返事の前の分類の 2 つである。

閾値の上書き値の検査について、入力として扱うのは `launch` を実行したシェルの環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS`（主か親のセッションが `launch` の呼び出しに付けたもの）だけである。拾いたい誤りは、空文字や `120k`・`1.2e5`・`120,000` のような数字だけでない値がそのまま子の起動コマンドに入り、子の Claude Code が閾値を読めずに既定の 200,000 で動くことと、値の空白や記号でコマンドが壊れることである。次は通してよく、この検査では止めない: `0` や `99999` のような 100,000 未満の数字（下限の扱いは Claude Code が持つ）／`200000` や `1000000` のような大きな数字／`0120000` のような先頭に 0 の付いた数字／変数が設定されていない環境（既定の 120000 を使う）。

返事の前の分類について、入力として扱うのは、子の端末の有無（子のワークスペースに端末が残っているか）、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）に記録された最後のリクエストの時刻とそのあとの `compact_boundary` の有無、同じトランスクリプトから `plugins/dev-workflow/scripts/subagent-context.sh --file` で測った会話量 N である。この分類は、`epic-dispatch.sh wait --resolve` が親の代わりに通す返事を除き、スクリプトではなく本体が規則のファイルを読んで行う。`wait --resolve` が通す返事は、要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」のとおり `resolve_stopped` が同じ表で分類する（例外）。拾いたい誤りは、PC が寝ていてコンパクトが走らなかった 150,000 トークン以上の会話に、そのまま返事を送って会話全体を書き込み直すことと、コンパクトが走った子や 60 分未満の子を起動し直して、子が積んだ判断と起動し直しの費用（平均約 258k）を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／N が 150,000 前後で、測り方の誤差で扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子／この変更より前に起動され、前置きが無く既定の 200,000 で動いている子／主の起動コマンドが値を入れず、既定のまま動く親／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）で値が渡らなかった子。

どちらについても、すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: launch は子の起動コマンドに既定の閾値を前置きする
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` の無い環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'` である

#### Scenario: 閾値は環境変数で変えられる
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000` の環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=400 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=150000 cld --model 'opus'` である

#### Scenario: 閾値の上書きが空なら起動しない
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=` の環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr に `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` と使い方が出て exit 1、`orca` と `git` は呼ばれない

#### Scenario: 閾値の上書きが数字でなければ起動しない
- **WHEN** `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=120k` の環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** stderr に `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` と使い方が出て exit 1、`orca` と `git` は呼ばれない

#### Scenario: 規則のファイルに値と分ける条件が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子・親とも 120,000 の値、親の値を主の起動コマンドが未設定のときだけ入れる形で付けて `settings.json` の `env` に置かないこと、端末が無い・60 分未満・コンパクトが走った・N が 150,000 以上か未満で「そのまま送る」か「起動し直す」かを分ける条件、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること）、親の状態の復元（親が通した判断を含む）、1〜2 週間後の再集計が書かれている

#### Scenario: SKILL.md の回し方が規則のファイルを指す
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 子の起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で決めることが書かれている
