# Spec Delta

## MODIFIED Requirements

### Requirement: 未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する
dev-workflow プラグインは `scripts/subagent-stop-guard.sh` を `hooks/hooks.json` の `SubagentStop` と `Stop` に登録しなければならない（MUST）。有効な `agent_id`（空でない文字列）がない Stop は、環境変数 `DEVELOP_ROLE` が空でないときだけ対象に加える（MUST。以下マーカー付き役）。有効な `agent_id` がある場合は印の有無によらず既存のサブエージェント経路を優先する（MUST）。hook は、停止しようとしているサブエージェント自身のトランスクリプトから自分が `run_in_background` で起動した背景タスクの ID を集め（所有の判定）、停止イベントの payload `background_tasks` にその ID が `status:"running"` で残っているものを未完了として数えなければならない（MUST）。起動の ID は Bash ツールの tool_result 本文 `Command running in background with ID: <id>.` から取る（SHALL。サブエージェント側のトランスクリプトでは `toolUseResult` が null で使えない、2026-09-27 の実測）。自分のトランスクリプトに起動の記録が無い ID は、`background_tasks` に `running` で残っていても数えない（MUST NOT。配列は親セッション全体の台帳で、本体や他のサブエージェントの背景タスクも入る）。`status` が `running` 以外の値、および配列に無い ID は終了したものとして通す（SHALL）。出力ファイルの更新時刻やプロセスの有無で完了を推定してはならない（MUST NOT）。

**守備範囲。** この検査は次の範囲だけを受け持つ（SHALL）。
- 入力の出どころ: hook の起動環境の `DEVELOP_ROLE` / `DEV_WORKFLOW_STOP_GUARD` / `TMPDIR`、Claude Code の停止イベント payload の識別・ログ欄（`agent_id` / `session_id` / `transcript_path` / `agent_transcript_path`）と `background_tasks` の `id` / `status`、対象自身のトランスクリプト（Claude Code が書く JSONL）、既存カウンタファイルとその読み書き可否。マーカー付き役は自身の `transcript_path` だけを使う
- 拾う誤り: Bash ツールの `run_in_background` で起動した背景タスクが `background_tasks` に `running` で残ったまま停止すること、の 1 つだけ。本体や兄弟のサブエージェントの背景タスクは所有の判定で外れるので、この誤りに含まれない
- 通す入力の例: 背景起動が無い停止／起動したすべてのタスクが `background_tasks` から消えている、または `status` が `running` でない停止（上限到達後に TaskStop で停止してから return する停止を含む）／印のないメインセッション（有効な `agent_id` がなく `DEVELOP_ROLE` が未設定か空）／python3 が無い・payload が壊れている・payload に `background_tasks` が無い・トランスクリプトが見つからない／安全な session_id が無い・カウンタを作成または読み書きできない／`DEV_WORKFLOW_STOP_GUARD=off`。主の環境へ空でない `DEVELOP_ROLE` が誤継承された場合は役として対象にすることを許容し、その主も未完了の所有タスクがあれば上限まで拒否する
- 守らないもの: `run_in_background` を使わず Bash の中で `nohup … &` や `setsid` で起こしたプロセス（tool_result に `Command running in background with ID:` が記録されない）／`codex-companion.mjs` の job／正本と食い違う待ち値・完了シグナル（文言検査が受け持つ）／拒否の上限回数まで理由を無視して停止を繰り返したサブエージェント／payload に `background_tasks` を持たない版の Claude Code（この版では判定を見送る）

新しい抜け道が見つかっても、この要件の完了条件は「拾う誤り」に挙げた 1 つを止めることであり、抜け道を塞ぎ切ることではない（SHALL）。守らないものに当たる指摘は、この要件の範囲外として扱う。

未完了が 1 件以上あれば、hook は stdout に `{"decision":"block","reason":"…"}` を出して停止を拒否しなければならない（MUST）。理由文には、未完了のタスク ID（取れれば出力ファイルのパスも）、完了を待つ目的でターンを終えてはならず前景の待ちループで完了を確認すること、**上限まで待ち終えた・結果を使わないと決めたなら TaskStop でそのタスクを停止してから終えること**、正本 `plugins/dev-workflow/references/subagent-waiting.md` の場所、今回が拒否の上限回数の何回目か（例 `1/3`）を含めなければならない（MUST）。待ち値・完了マーカーの雛形を理由文に再掲してはならない（MUST NOT）。拒否の回数表記は、hook の定数を正本とテストで突き合わせているので、指示書への再掲には当たらない（SHALL）。

マーカー付き役の対象トランスクリプトは payload の `transcript_path` 自身だけであり、`agent_transcript_path` や subagents 以下へ代替してはならない（MUST NOT）。役の `agent_id` は捏造しない（MUST NOT）。既存のサブエージェントの対象トランスクリプトは、payload に `agent_transcript_path` があればそれを使う（SHALL）。無いときは `transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<親>/<session_id>/subagents/agent-<agent_id>.jsonl` を導出し、そこに無ければ worktree 隔離のための探索を行う。この導出と探索の上限（深さ・件数・時間）は `scripts/context-tripwire.sh` と同じにする（SHALL）。

#### Scenario: 背景でテストを起動したままターンを終えようとする
- **WHEN** サブエージェントが `run_in_background` で test.sh を起動し、そのタスクが `background_tasks` に `running` で残ったままターンを終えようとする
- **THEN** hook が停止を拒否し、未完了のタスク ID・前景の待ちループで待つこと・上限まで待ったなら TaskStop で停止してから終えること・正本の場所・拒否の回数を理由として返す

#### Scenario: 背景タスクがすべて終わっている
- **WHEN** サブエージェントが起動した背景タスクがすべて `background_tasks` に無い、または `status` が `running` でない
- **THEN** hook は何も出力せず停止を通す

#### Scenario: 上限まで待ってから停止して return する
- **WHEN** 前景ループを上限回数まで回しても完了せず、サブエージェントが背景タスクを TaskStop で停止してから return する
- **THEN** TaskStop で停止したタスクは `background_tasks` から消えているので、hook は 1 回目の停止で通す

#### Scenario: 背景タスクを起動していない
- **WHEN** トランスクリプトに `Command running in background with ID:` を含む tool_result が 1 件も無い
- **THEN** hook は何も出力せず停止を通す

#### Scenario: 本体の背景タスクが動いている
- **WHEN** 本体が `ci-watch.sh wait` を `run_in_background` で起動しており、背景起動をしていないサブエージェントが停止する（`background_tasks` に本体の shell が `running` で入っている）
- **THEN** 自分の起動記録が無いので hook は何も出力せず停止を通す

#### Scenario: 範囲外の抜け道を指摘された
- **WHEN** Bash の中で `nohup … &` で起こしたプロセスを残したまま停止すると hook を通る、と指摘される
- **THEN** 守備範囲の「守らないもの」に当たるので、この要件の範囲外として扱い、塞ぐことを完了条件にしない

#### Scenario: マーカー付き役の Stop が未完了の背景タスクを拒否する
- **WHEN** `DEVELOP_ROLE=worker` で有効な `agent_id` のない Stop payload を渡し、自身の `transcript_path` に起動記録がある ID が `background_tasks` に running で残っている
- **THEN** `decision: block` と未完了 ID・前景待ち・TaskStop・正本パス・拒否回数を含む reason を exit 0 の JSON で返す
- **AND** `stop_hook_active=true` でも拒否上限以内は block する

#### Scenario: 自身が起動していないタスクと完了済みタスクを通す
- **WHEN** マーカー付き役の Stop に、自身の起動記録がない running ID、または自身の起動記録があるが running でないか台帳から消えた ID だけがある
- **THEN** stdout 空・exit 0 で停止を通す。別ログの起動記録や出力ファイルの更新時刻で所有・完了を推測しない

#### Scenario: マーカーがある既存サブエージェントの停止を変えない
- **WHEN** 有効な `agent_id` がある同じ SubagentStop payload を、`DEVELOP_ROLE` ありとなしで渡す
- **THEN** 既存の対象ログ・所有判定・回数・出力・終了コードが一致する


### Requirement: 停止の拒否は上限回数までの後詰めにする

**守備範囲**: 入力元と背景タスク判定の範囲は要件「未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する」の「守備範囲」に従う。この回数検査で拾う誤りは、理由を無視する停止を無限に拒否することと、役・別 session・既存 subagent のカウンタの混同である。通してよい例は、未完了タスクが残っていても上限到達後に再度停止すること、削除できないカウンタを残して停止を通すこと、見送り後に残った回数から拒否を再開することである。上限を繰り返して停止する経路やカウンタ操作を含む穴の完全封鎖を完了条件にしない。

正当な出口は「前景で完了まで待つ」か「TaskStop で停止してから終える」であり、hook の拒否回数の上限は、理由文を無視して停止を繰り返すサブエージェントを無限に止め続けないための後詰めである（SHALL）。hook は同じサブエージェント（`session_id` と `agent_id` の組）への拒否回数を `${TMPDIR:-/tmp}/dev-workflow-stop-guard/<session_id>-<agent_id>.count` に数え、正本 `subagent-waiting.md` の総待ちの上限回数（前景ループの回数）に達した後の停止は通さなければならない（MUST）。**停止を通す時点（上限到達で通す場合と、未完了の背景タスクが無く通す場合のいずれでも）でそのカウンタファイルを削除する（SHALL。削除できなくても停止は通す）。判定を見送って通す場合（対象トランスクリプトが見つからない・読めない場合、`DEV_WORKFLOW_STOP_GUARD=off` の場合など）はこの削除の対象外で、カウンタファイルは残る。残った値は、次に停止を通す時点で削除されるまで引き継がれ、その間の拒否は 1 回目からではなく残った回数の続きから数える（`2/3` から始まりうる）。拒否回数のファイルが読めない場合は、削除されるまで判定の見送りが続く。** マーカー付き役にも同じ上限回数・削除・見送り時の規則を適用する（MUST）。役のカウンタは `${TMPDIR:-/tmp}/dev-workflow-stop-guard/role-sessions/<session_id>.count` に置き、session_id は既存のパス部品検査を通す（SHALL）。役名や捏造した agent_id をキーにせず、既存 subagent の回数と混ざらないようにする（MUST）。拒否の判定に `stop_hook_active` を使ってはならない（MUST NOT）— 1 回拒否した後の継続中は常に真になり、2 回目以降の停止を無条件に通してしまうため。hook が持つ上限回数は 1 か所の定数にし、テストで正本の記述と一致することを検査しなければならない（MUST）。上限を超えて通すときは、その旨を stderr に 1 行出す（SHALL）。

#### Scenario: 上限回数まで拒否した後にもう一度止まる
- **WHEN** 同じサブエージェントをすでに上限回数まで拒否しており、未完了の背景タスクを残したままもう一度ターンを終えようとする
- **THEN** hook は停止を通し、上限を超えて通したことを stderr に 1 行出し、カウンタファイルを削除する

#### Scenario: 正本の上限回数を変えた
- **WHEN** 正本の総待ちの上限回数を変えたが、hook の定数を直していない
- **THEN** `scripts/test.sh` が失敗し、hook の定数を正本に合わせるよう示す

#### Scenario: 判定を見送って通した後はカウンタが残る
- **WHEN** サブエージェントが一度拒否されたあと、対象トランスクリプトが見つからないか読めない、または `DEV_WORKFLOW_STOP_GUARD=off` のために hook が判定を見送って停止を通す
- **THEN** hook はカウンタファイルを削除せず、そのあと停止を通してカウンタが削除される前に同じサブエージェントが再び拒否されるときの回数は、1 回目からではなく残った回数の続き（`2/3` など）から数える

#### Scenario: 正しく待ってから停止したのにカウンタが残っている
- **WHEN** サブエージェントが一度拒否されたあと、理由文どおりに前景で待つ、または TaskStop で背景タスクを停止してから停止し、未完了の背景タスクが無い状態で hook が停止を通す
- **THEN** hook はその時点でカウンタファイルを削除し、次のターンで同じサブエージェントが再び未完了の背景タスクを残して停止しようとしても拒否回数は 0 から数え直す

#### Scenario: 役の拒否上限とカウンタを session 単位で分離する
- **WHEN** 同じマーカー付き役の Stop を上限回数まで拒否し、さらにもう一度渡す
- **THEN** 既存と同じ上限到達の stderr を出して停止を通し、役のカウンタを削除する
- **AND** 別 session の役、同じ session の実在する subagent のカウンタは増減しない。未完了がなくなって通る場合も役のカウンタを消し、再度未完了となれば 1 回目から数える


### Requirement: 停止の拒否はサブエージェントに限り、判定できなければ通す

**守備範囲**: 入力元・対象選択と許容する入力は要件「未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する」の「守備範囲」に従う。この見送り判定で拾う誤りは、対象外の主を拒否すること、欠測や読めないカウンタで停止を妨げること、役の欠損ログを別ログで補うことである。通してよい例は、未完了タスクが実在していても台帳欠落・自身ログ欠落・安全でない session_id・読めないカウンタ・明示 off により無出力で停止することである。主の環境へ実際に印が誤継承されれば役扱いを許容し、印の認証・欠測や抜け道の完全封鎖を完了条件にしない。

hook は有効な `agent_id` がなく `DEVELOP_ROLE` も未設定か空の停止（印のないメインセッション）に対して何も出力してはならない（MUST NOT）。python3 が無い・payload が壊れている・payload に `background_tasks` が無い・対象トランスクリプトが見つからないか読めない・拒否回数のファイルが作れないか読めないときは、stdout に何も出力せず exit 0 で停止を通さなければならない（MUST）。payload に `background_tasks` が無い・対象トランスクリプトが見つからないか読めない・拒否回数のファイルが作れないか読めないときは、stderr に判定を見送った旨を 1 行出す（SHALL）。印のないメインセッションの停止と `DEV_WORKFLOW_STOP_GUARD=off` では stderr にも何も出さない（MUST NOT）。python3 が無い・payload が壊れているときも、サブエージェントの停止かどうかを判定できないので stderr に出さない（SHALL）。環境変数 `DEV_WORKFLOW_STOP_GUARD=off` のときは判定をせずに停止を通す（SHALL）。この hook は install 先の全サブエージェントの停止で走るため、5MB のトランスクリプトで 200ms 未満で終えなければならない（MUST）。測り方は `tests/context-tripwire.bats` の性能テストと同じく複数回（3 回）測って最良値を見る（SHALL）。

#### Scenario: メインセッションが通知待ちで止まる
- **WHEN** `DEVELOP_ROLE` が未設定か空で `agent_id` の無い payload で hook が呼ばれる
- **THEN** hook は何も出力せず exit 0 で終わる

#### Scenario: トランスクリプトが見つからない
- **WHEN** 導出したパスにも探索範囲にも対象トランスクリプトが無い
- **THEN** hook は何も出力せず exit 0 で停止を通す

#### Scenario: payload に background_tasks が無い
- **WHEN** 旧い・異なる版の Claude Code で payload に `background_tasks` キーが無い
- **THEN** hook は判定を見送り、stdout に何も出さず exit 0 で通す。stderr に見送った旨を 1 行出す

#### Scenario: 全解除
- **WHEN** `DEV_WORKFLOW_STOP_GUARD=off` が設定されている
- **THEN** 未完了の背景タスクがあっても hook は停止を通す

#### Scenario: マーカー付き役も既存の見送り条件に従う
- **WHEN** マーカー付き役の Stop で自身ログ・background_tasks・安全な session_id・カウンタを読めないか、`DEV_WORKFLOW_STOP_GUARD=off` を設定する
- **THEN** stdout 空・exit 0 で通し、既存と同じ条件で判定見送りの stderr を出す。ログを別のセッションから補わない

#### Scenario: payload の印の文字列は主を役に変えない
- **WHEN** 環境の `DEVELOP_ROLE` は未設定か空で、payload や transcript の本文にだけ役の印を書く
- **THEN** 有効な `agent_id` のない Stop は stdout / stderr 空・exit 0 で通る
