## ADDED Requirements

### Requirement: 時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が子の起動コマンドに前置きする `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` の `<値>` は、既定で `120000` でなければならない（MUST）。環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` が設定されていればその値を使う（SHALL）。設定された値が空文字か、数字だけでない文字列なら、`launch` は stderr に変数名と使い方を出して exit 1 で終わり、`orca` と `git` を 1 つも呼んではならない（MUST）。100,000 未満の値は拒まない（SHALL。下限の扱いは Claude Code が持つ）。

時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、次を書かなければならない（MUST）。

- **閾値**: 子は 120,000（`launch` が付ける。`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられる）、親は 100,000。親は主が起動するセッションなので、主が親を起動するコマンドの先頭に `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=100000` を付ける。どちらの値も `~/.claude/settings.json` の `env` に置かない（主の手元の全セッションに効くため）
- **分ける条件**: 子に返事を送る前に、子の端末が無ければ起動し直す。子の最後のリクエストから 60 分未満ならそのまま送る。60 分以上で、その間に待っている間の自動コンパクトが走っていればそのまま送る。60 分以上でコンパクトが走っていなければ、会話量 N が 150,000 トークン以上なら起動し直し、150,000 未満ならそのまま送る
- **判定に使う事実**: 子の端末の有無（`orca terminal list --worktree path:<子> --json`）、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻と、そのあとの `compact_boundary` の有無、会話量 N（`plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>`）
- **親への適用**: 親自身が長く待ったあとも同じ条件で、そのまま続けるか起動し直すかを決める。親の状態のうち、回し方（`回し方:`）・終わった子（`子 #N マージ → 残り k 件` / `子 #N 見送り`）・外した子エピック（`後で別に起動するエピック:`）・残したワークツリー（`子 #N のワークツリーを残した`）はエピックのコメントから、残りの子は依存グラフと子 issue の状態から復元できる。親が通した判断はまだ記録されない
- **根拠と限り**: 値と条件の根拠として #1039 の集計コメントの URL と要点（返事の直前の会話の中央値、起動し直しの費用、閾値ごとの費用の増減）、実績の少なさと PC が寝ているとコンパクトが走らないこと
- **再集計**: 1〜2 週間回したあとに同じ集計をやり直して #1039 にコメントし、値を見直す。件数・金額は合否に使わず記録する

送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順が書き、このファイルを参照する）。

develop の SKILL.md「エピックの扱い」の「回し方」は、子セッションの起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で「そのまま送る」か「起動し直す」かを決めることを書かなければならない（MUST）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、既定の前置き、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` での上書き、空文字と数字でない値の拒否、規則のファイルの上の記述（値・分ける条件・`settings.json` に置かないこと）、SKILL.md の上の記述を確かめなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、`launch` を実行した環境の `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` だけである。拾いたい誤りは、子が既定の 200,000 で起動されて、1 時間以上たってから返事が来る止まり方の大半でコンパクトが走らないことである。次は通してよく、この要件では止めない: この変更より前に起動された子セッションには前置きが無く既定の 200,000 のまま動く／主が親の起動コマンドに値を付け忘れた親は既定のまま動く／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形のときは値が渡らない／PC が寝ているとコンパクトは走らない。

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
- **THEN** 子 120,000・親 100,000 の値、親の値を主の起動コマンドで付けて `settings.json` の `env` に置かないこと、端末が無い・60 分未満・コンパクトが走った・N が 150,000 以上か未満で「そのまま送る」か「起動し直す」かを分ける条件、判定に使う事実、親の状態の復元、1〜2 週間後の再集計が書かれている

#### Scenario: SKILL.md の回し方が規則のファイルを指す
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 子の起動コマンドに `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` が付くことと、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で決めることが書かれている

## MODIFIED Requirements

### Requirement: エピックの並列起動は 1 段で止める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` は、子セッションを起動する端末のコマンドの先頭に `EPIC_DISPATCH_PARENT_EPIC=<epic>` を置かなければならない（MUST。`<epic>` は `launch` に渡したエピック番号）。そのうしろ、`<cmd>` の前には `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` を置く（MUST。`<値>` の既定と上書きは要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」が定める）。コマンド全体は `EPIC_DISPATCH_PARENT_EPIC=<epic> CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値> <cmd> --model <model>` の形になり、端末を作れなかった子について stderr に出す `orca terminal create --command ...` の作り直しのコマンドにも同じ前置きが入る（SHALL）。この要件は、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」のうち `route` の出力の規定、`<cmd>` の形の規定、および Scenario「EPIC_DISPATCH_MODEL…」「EPIC_DISPATCH_CLAUDE_CMD…」の `--command` の値に優先する。並行する子の archive が終わったあとに元の要件へ畳み込む。

環境変数 `EPIC_DISPATCH_PARENT_EPIC` が空でない環境では:

- `route <child>...` は、子の番号の検査（数字でなければ使い方を出して exit 1）のあと、子の件数・`orca` の有無・`orca worktree current` の結果によらず stdout に `nested` の 1 行を出して exit 0 で終わらなければならない（MUST）。`orca` を呼んではならない（MUST NOT）
- `launch` は、引数の検査（既存の使い方の誤り）のあと、`orca` と `git` を 1 つも呼ばず、stderr に親エピックの番号と展開しない旨を出して exit 1 で終わらなければならない（MUST。子ワークツリーを作らない）。stdout には何も出さない（SHALL）
- `wait` の振る舞いは変えない（SHALL）

develop の SKILL.md「エピックの扱い」は次を規定しなければならない（MUST）。

- **エピックの子を外す**: 本体は依存グラフから求めた blocked されていない子のうち、sub-issue を持つ子（`gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` が 1 以上。`null` や空は 0 とみなす）をエピックとして外し、`route`・`launch`・サブエージェント方式のどれにも渡してはならない（MUST NOT）。経路が `nested` でないと確定したら（`route` が `nested` 以外を返したとき。`route` を呼ばない unmanned と、`回し方:` のコメントから経路を引き継いだ再開を含む）、外した子ごとにエピックへ `後で別に起動するエピック: #N` と 1 行コメントする（MUST）。再開時に `回し方:` のコメントから経路を引き継いだ場合も、`launch` に渡す前に同じ確認で外す（MUST）
- **`nested` を受けたセッション**: `route` が `nested` を返したら、そのセッションはエピックを展開してはならない（MUST NOT。Orca 経路もサブエージェント方式も使わない）。親エピック（`EPIC_DISPATCH_PARENT_EPIC` の番号）と自分の issue に `後で別に起動するエピック: #<自分の issue>` とコメントし、ユーザーに後で `/develop #<自分の issue>` を別に起動して回すと伝えて止まる（MUST）。自分の issue を閉じてはならない（MUST NOT）。`launch` が stderr に展開しない旨を出して exit 1 で終わったときも同じに扱い、「親ワークツリーで開き直す」とは報告しない（MUST NOT）
- **親の待ち受け**: Orca 経路の本体は、`timeout` と `closed` で起こされたときの確認で、エピックに `後で別に起動するエピック: #N` の行がある子を動いている子から外す（MUST）
- **親の完了報告**: 動いている子が無くなったときの本体の報告（エピックへのコメントとユーザーへの報告）に、エピックに記録した `後で別に起動するエピック:` の番号をすべて載せる（MUST）。子エピックが閉じるまで親エピックの完了条件は満たされないので、親エピックを閉じてはならない（MUST NOT）

この要件の守備範囲で入力として扱うのは、`launch` が子の端末のコマンドに前置きした `EPIC_DISPATCH_PARENT_EPIC`（子セッションの Claude Code とその Bash・サブエージェントに引き継がれる）、本体が依存グラフから求めた子の番号ごとの `sub_issues_summary.total`、エピックのコメントの `後で別に起動するエピック:` で始まる行である。拾いたい誤りは、並列起動された子のセッションが自分の issue をエピックとして孫のワークツリーとセッションを作ることである。次は通してよく、この要件では止めない: `EPIC_DISPATCH_PARENT_EPIC` の値は空でなければ数字かどうかを検査しない／人が手で `EPIC_DISPATCH_PARENT_EPIC` を付けて起動したセッションも `nested` になる／sub-issue を持たず本文で子を列挙しているだけのエピックは事前確認を通り、Orca 経路で起動された子なら子のセッションの `route` で止まり、サブエージェント方式で起こされた子（変数が無い）は止まらない／`回し方:` のコメントからサブエージェント方式を引き継いだ子エピックのセッションはスクリプトでは止まらない／この変更の前に起動された子セッションには変数が無く従来どおり展開しうる／`EPIC_DISPATCH_CLAUDE_CMD` が前置きの代入を受け付けない形（`exec` で始まる文字列など）のときは値が渡らない。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`EPIC_DISPATCH_PARENT_EPIC` の前置き、`route` の `nested`、`launch` の拒否、SKILL.md の上の記述を確かめなければならない（MUST）。

#### Scenario: launch は子の端末のコマンドに親エピックの番号を前置きする
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` の無い環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** `orca terminal create` の `--command` は `EPIC_DISPATCH_PARENT_EPIC=420 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 cld --model 'opus'` である

#### Scenario: 端末の作り直しのコマンドにも前置きが入る
- **WHEN** `orca terminal create` が失敗する環境で `epic-dispatch.sh launch 420 11` を実行する
- **THEN** stderr の作り直しのコマンドは `--command 'EPIC_DISPATCH_PARENT_EPIC=420 ` を含む（値全体が単一引用符で囲まれる）

#### Scenario: 並列起動された子のセッションでは route が nested を返す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` で、`orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0、`orca` は呼ばれない

#### Scenario: 並列起動された子のセッションでは launch が子ワークツリーを作らない
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh launch 460 11 12` を実行する
- **THEN** exit 1、stdout は空、`orca` と `git` は 1 回も呼ばれず、stderr に `420` を含む理由が出る

#### Scenario: 並列起動された子のセッションでも引数の誤りは使い方を出す
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `epic-dispatch.sh route '#11'` を実行する
- **THEN** stderr に使い方が出て exit 1

#### Scenario: SKILL.md に子エピックの扱いと完了報告が書かれている
- **WHEN** SKILL.md の「エピックの扱い」を読む
