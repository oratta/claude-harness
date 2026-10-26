## MODIFIED Requirements

### Requirement: wait --resolve は通す返事を送る前に起動し直すかを表で決める
`epic-dispatch.sh wait --resolve` の `resolve_stopped` は、判断が `通す` のとき、`reply-after-idle.md` の子の表に従って `deliver_reply` の `relaunch` を決めなければならない（MUST）。子の会話量 `context_tokens` が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら、経過時間と `compact_boundary` の有無によらず起動し直す（`relaunched`）。子の最後のリクエスト（トランスクリプトの最後の assistant の行の `timestamp`）から `EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）秒以上の場合も、会話量と `compact_boundary` の有無によらず起動し直す。2 条件は OR とし、どちらも真と確認できなければ今までどおり送る（`sent`）。トランスクリプトは、状態の記録の `worktree` のパスの英数字以外を `-` に置換した名前の `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}` 直下のディレクトリの `*.jsonl` で、ちょうど 1 本のときだけ使う（MUST）。0 本・2 本以上・ファイルを読めないときはそのまま送る（端末が無いときの起動し直しは既存の送信処理に従う）。会話量は同じトランスクリプトを `plugins/dev-workflow/scripts/subagent-context.sh --file <file>` で測った `context_tokens` を使う（MUST）。exit 0 と 2 の JSON の値を比較し、`over_cap` やサブエージェント用の閾値で代用してはならない（MUST NOT）。会話量を読めなくても時間条件が真なら起動し直し、時刻を読めなくても会話量条件が真なら起動し直す（MUST）。新しい閾値と既存の時間閾値は未設定のときだけ既定を使い、数字だけの非負整数を受け付け、空か数字だけでない値なら、有効な `--resolve` の待ち受けに入る前に変数名と使い方を出して exit 1 で終わる（MUST）。`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` は読まない（SHALL。設定されていても値を検査しない）。`tests/epic-dispatch.bats` は偽の `orca`・`gh`・トランスクリプトで次の Scenario を確かめなければならない（MUST）。

この要件の入力は、状態の記録の `worktree`、一意に選ばれたトランスクリプトの `timestamp`・`type` と会話量の計測値、上の環境変数である。拾いたい誤りは、大きい会話の子へ 60 分未満だからとそのまま送り続けること、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子を含む）へそのまま送ること、会話量が閾値未満かつ 60 分未満の子を不要に起動し直すことである。次は通してよく、この要件では止めない: 経過時間が 60 分前後で時刻の読み方により扱いが分かれる子／トランスクリプトが複数あり、そのまま送った子／PC が寝ていて、60 分未満と読め、会話量条件も真と確認できなかった子／計測に必要な情報が欠けて両方の条件を真と確認できなかった子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。送れたあとのエピックの記録と、成功した子を待ち受けの出力から外す契約は維持する（MUST）。以下の `sent` / `relaunched` は送信処理の結果であり、`wait` の stdout にその行を追加する要件ではない。

#### Scenario: 60 分以上・コンパクトなし・150,000 以上なら起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く、会話量が 150,000 以上で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、エピックに通した記録が残る

#### Scenario: 60 分以上なら会話量によらず起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、`compact_boundary` が無く会話量が 150,000 未満で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 60 分以上ならコンパクトが走っていても起動し直す
- **WHEN** 通す判断の子のトランスクリプトの最後のリクエストが 60 分以上前で、そのあとに `compact_boundary` がある状態で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 60 分未満ならそのまま送る
- **WHEN** 最後のリクエストが 60 分未満前で会話量が 149999 の子に、既定値で同じ実行をする
- **THEN** 返事は `sent` で届く

#### Scenario: 事実を読めなければそのまま送る
- **WHEN** トランスクリプトが無い、または 2 本ある
- **THEN** 返事は `sent` で届く

#### Scenario: 閾値の環境変数が数字でなければ起動しない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_IDLE_SEC=1h` で `wait --resolve` を実行する
- **THEN** stderr に変数名と使い方が出て exit 1 である

#### Scenario: 会話量の環境変数は読まない
- **WHEN** `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS=150k` で、最後のリクエストが 60 分以上前の子に `wait --resolve` を実行する
- **THEN** exit 1 にならず、返事は `relaunched` で届く

#### Scenario: 60 分未満でも会話量が閾値ちょうどかそれ以上なら起動し直す
- **WHEN** 最後の assistant が 5 分前で `context_tokens` が 150000 または 150001 の子に、既定値で `wait --resolve` を実行する
- **THEN** 返事は `relaunched` で届き、端末を起動し直して `/develop #<child>` と返事を送り、送れたあとにエピックに通した記録が残る

#### Scenario: 会話量条件は compact の有無によらない
- **WHEN** 最後の assistant が 5 分前で、`compact_boundary` がある子の最新の有効な usage による会話量が 150000 の状態で、既定値で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: compact 後の最新の会話量が小さければそのまま送る
- **WHEN** 150000 以上の usage のあとに `compact_boundary`、そのあとに 5 分前で会話量が 100000 の有効な usage がある状態で、既定値で実行する
- **THEN** 返事は `sent` で届き、compact 前の最大値では起動し直さない

#### Scenario: キャッシュの量も含む最後の有効な usage で決める
- **WHEN** 5 分前の有効な assistant usage が input 10000・cache_creation 40000・cache_read 100000 で、そのあとに usage が全部 0 の API エラーの assistant があり、既定値で実行する
- **THEN** `subagent-context.sh --file` の会話量 150000 を使い、返事は `relaunched` で届く

#### Scenario: 会話量を読めなくても時間条件で起動し直す
- **WHEN** 一意で読めるトランスクリプトに有効な usage が無い、または会話量の計測が失敗したが、最後の assistant が 60 分以上前の状態で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 時刻を読めなくても会話量条件で起動し直す
- **WHEN** 一意で読めるトランスクリプトから時刻を読めないが、会話量が 150000 の状態で既定値で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 両条件とも真と確認できなければそのまま送る
- **WHEN** 時刻と有効な usage の両方が無い、または最後の assistant が 5 分前で会話量だけを計測できない状態で実行する
- **THEN** 返事は `sent` で届く

#### Scenario: 会話量閾値は既定値と独立して上書きできる
- **WHEN** 最後の assistant が 5 分前で会話量 160000 の子に `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS=200000` で実行する
- **THEN** 返事は `sent` で届く

#### Scenario: 会話量閾値を 0 にできる
- **WHEN** 最後の assistant が 5 分前で会話量 100000 の子に `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS=0` で実行する
- **THEN** 返事は `relaunched` で届く

#### Scenario: 会話量閾値の不正値は待つ前に拒否する
- **WHEN** `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` を空文字・`150k`・`-1` のいずれかにして有効な `wait --resolve` を実行する
- **THEN** 変数名と使い方を stderr に出して exit 1 となり、子の端末を作成・送信・終了しない

### Requirement: 時間がたった子への返事は 60 分を境にそのまま送るか起動し直すかを決める
時間がたった子・親への返事の規則は `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` に置き、子について次を書かなければならない（MUST）: 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること（そのプロセスだけに効き通常の自動コンパクトは止めない・v2.1.290 以降が要る・`~/.claude/settings.json` に置かない）。子の表は上から、端末が無ければ起動し直す、会話量 N が `EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS`（既定 150000）以上なら経過時間と compact の有無によらず起動し直す、最後のリクエストから 60 分未満ならそのまま送る、60 分以上なら compact の有無と会話量によらず起動し直す、と書く。会話量条件が時間条件に優先するよう並べる。根拠は、コンパクトされた子は `SKILL.md` の中身を持たずに進むことと、費用の差の小ささ。

#### Scenario: 規則のファイルに子の切り方と分ける条件と根拠が書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/reply-after-idle.md` を読む
- **THEN** 子は `launch` が `--settings '{"idleCompaction":false}'` を付けてアイドル時のコンパクトを切ること、`settings.json` に置かないこと、子は端末が無い・会話量が新閾値以上・60 分以上のいずれかなら起動し直し、会話量が閾値未満か不明で 60 分未満ならそのまま送ること、新閾値の変数名と既定値 150000、子を起動し直す根拠（コンパクトされた子は `SKILL.md` の中身を持たない）と #1039 の決定を #1323 で覆したこと、判定に使う事実（端末の有無は `epic-dispatch.sh reply` が確かめること・最後のリクエストの時刻はトランスクリプトから読むこと・会話量は同じファイルを `subagent-context.sh --file` で測ること）が書かれている

根拠には、2026-10-23 の子のログで、コンパクトのあとに残ったのが `SKILL.md` のファイル名と `/develop` の入口だけで、再開したあとも読み直さずにゲートの実行まで進んでいたことと、起動し直しとの費用の差（1 回あたり Opus 5.5 で約 $0.5）、1 時間以上たってから返事が来る子の割合（3.2%）を書く（SHALL）。判定に使う事実は、子の端末の有無（`orca` のコマンドは書かず、要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」に従う。端末の有無は `epic-dispatch.sh reply` が確かめ、端末が無ければ起動し直す。要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」）と、子のセッションのトランスクリプト（`~/.claude/projects/` 配下の jsonl）の最後のリクエストの時刻、および同じファイルを `plugins/dev-workflow/scripts/subagent-context.sh --file <トランスクリプト>` で測った会話量 N である。事実を読めない場合は、上の自動判定の要件と同じく確認できた条件だけで決め、どちらも真と確認できなければそのまま送ると書く（MUST）。送り方と起動し直し方の手順本体はこのファイルに書かない（SHALL NOT。止まった子を親が解決する手順（develop の `references/epic.md` の Orca 経路と `epic-dispatch.sh reply`）が書き、このファイルを参照する）。

この分類は、`epic-dispatch.sh wait --resolve` が親の代わりに通す返事を除き、スクリプトではなく本体が規則のファイルを読んで行う。`wait --resolve` が通す返事は、要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」のとおり `resolve_stopped` が同じ子の表で分類する（例外）。拾いたい誤りは、60 分以上止まった子（コンパクトされて `SKILL.md` の中身を持たない子と、この変更より前に起動されてコンパクトされうる子を含む）にそのまま返事を送り、子が手順を外れて進むこと、大きい会話の子に時間だけを見て返事を送り続けること、会話量が閾値未満か不明で 60 分未満の子を不要に起動し直して、子が積んだ判断と起動し直しの費用を無駄にすることである。次は通してよく、この分類では止めない: 経過時間がちょうど 60 分前後で、時刻の読み方によって扱いが分かれる子／トランスクリプトが複数あってどれが子のセッションか分からず、そのまま送った子。すり抜ける入力が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 子の会話量の行が短時間の行に優先する
- **WHEN** 子の表を上から読む
- **THEN** 端末が無い行の次で、`EPIC_DISPATCH_RELAUNCH_FORCE_TOKENS` と既定値 150000 が明記された会話量の行により、60 分未満でも閾値以上なら起動し直すと分かる

#### Scenario: 閾値を選んだ根拠と限りが分かる
- **WHEN** 規則のファイルの子の説明を読む
- **THEN** #1046 の再集計の結論に合わせて 150000 を採用したことと、その集計はキャッシュ有効中の新条件の最適値を実証したものではないこと、時間条件は #1323 のまま残ることが書かれている
