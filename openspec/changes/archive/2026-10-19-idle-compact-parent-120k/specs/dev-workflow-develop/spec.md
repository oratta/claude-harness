## MODIFIED Requirements

### Requirement: 時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める
`plugins/dev-workflow/scripts/epic-dispatch.sh launch` が子の起動コマンドに前置きする `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` の `<値>` は、既定で `120000` でなければならない（MUST）。環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` が設定されていればその値を使う（SHALL）。設定された値が空文字か、数字だけでない文字列なら、`launch` は stderr に変数名と使い方を出して exit 1 で終わり、`orca` と `git` を 1 つも呼んではならない（MUST）。100,000 未満の値は拒まない（SHALL。下限の扱いは Claude Code が持つ）。

時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、次を書かなければならない（MUST）。

- **閾値**: 子は 120,000（`launch` が付ける。`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変えられる）、親も同じ 120,000。親は主が起動するセッションなので `launch` は付けられず、主が起動するセッションは主の起動コマンド（例: `cld`）が、値が未設定のときだけ 120000 を入れる（外から渡された値は上書きしない）。個人の設定ファイルのパスは書かない。どちらの値も `~/.claude/settings.json` の `env` に置かない（主の手元の全セッションに効くため）
- **分ける条件**: 子に返事を送る前に、子の端末が無ければ起動し直す。子の最後のリクエストから 60 分未満ならそのまま送る。60 分以上で、その間に待っている間の自動コンパクトが走っていればそのまま送る。60 分以上でコンパクトが走っていなければ、会話量 N が 150,000 トークン以上なら起動し直し、150,000 未満ならそのまま送る
- **判定に使う事実**: 子の端末の有無（子のワークスペースに端末が残っているか。`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻と、そのあとの `compact_boundary` の有無、会話量 N（`plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>`）
- **親への適用**: 親自身が長く待ったあとも同じ条件で、そのまま続けるか起動し直すかを決める。親の状態のうち、回し方（`回し方:`）・終わった子（`子 #N マージ → 残り k 件` / `子 #N 見送り`）・外した子エピック（`後で別に起動するエピック:`）・残したワークツリー（`子 #N のワークツリーを残した`）・親が通した判断（`親の判断: 子 #N 通した`）はエピックのコメントから、残りの子は依存グラフと子 issue の状態から復元できる
- **根拠と限り**: 値と条件の根拠として #1039 の集計コメントの URL と要点（返事の直前の会話の中央値、起動し直しの費用、閾値ごとの費用の増減）、実績の少なさと PC が寝ているとコンパクトが走らないこと
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
