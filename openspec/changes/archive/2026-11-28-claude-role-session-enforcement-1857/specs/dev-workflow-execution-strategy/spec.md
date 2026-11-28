# Spec Delta

## MODIFIED Requirements

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

有効な `agent_id`（空でない文字列）がある場合、`DEVELOP_ROLE` の有無によらず従来のサブエージェント経路を優先する（MUST）。この場合の計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。

導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を**深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探してよい（MAY。入れ子のサブエージェント）。この探索は毎ツール呼び出しのコストになるため上限を設けなければならず（MUST）、走査したディレクトリエントリが 200 件を超えるか探索が 20ms を超えたら打ち切って何も出力せず exit 0 とする（SHALL）。

有効な `agent_id` がなく、環境変数 `DEVELOP_ROLE` が空でない場合をマーカー付き役とする（SHALL。役名の列挙では制限しない）。この場合は payload の `transcript_path` 自身だけを測らなければならない（MUST）。`agent_transcript_path` や subagents 以下へ代替してはならず、`agent_id` を捏造してはならない（MUST NOT）。`DEVELOP_ROLE` は hook の起動環境からだけ読み、payload やツール本文の同名文字列を印として採用しない（MUST NOT）。通知・強制停止の閾値、比較、JSON 出力、return 宣言と診断はサブエージェントと同じ要件を適用する（MUST）。

読み取りはファイル末尾の固定 256KB だけを対象とし、そこに現れる最後の `assistant` レコードの usage を合算する（MUST）。しきい値はこの計測レコードの `message.model` を使って共通処理から取得した `context_cap` / `context_hard_cap` とし、モデル入力・上書き・正数条件・診断は dev-workflow-token-thresholds の文脈計測の要件に従わなければならない（MUST）。この 256KB は環境変数で上書きできる形にしてはならない（MUST NOT。小さすぎる値を与えられると静かに fail-open して途中計測が全体で無効になるため。変更は仕様変更として扱う）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

`DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` である・`python3` が無い・`DEVELOP_ROLE` が未設定か空で、読み込んだ stdin が**メインスレッドからの呼び出しであることを JSON をパースせずに判定できる**のいずれかは、**python3 を起動する前に判定して** exit 0 しなければならない（MUST）。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッドであるため、そこに python3 の起動コストを課してはならない（MUST NOT）。

パースせずに行うこの判定は、**JSON 意味論的に `agent_id` キーを持つ payload を早期 exit させてはならない**（MUST NOT）。JSON のキーは Unicode エスケープ（`\uXXXX`）でも書けるため、生文字列 `"agent_id"` の有無だけを見る判定では、同値な表記（`"\u0061gent_id"` など）の payload が無音で素通りする。判定は次の必要条件で行う（SHALL）: 生文字列 `"agent_id"` を含む、または 4 文字の並び `\u00` を含む payload は python3 に渡す。それ以外でも `DEVELOP_ROLE` が空でなければ python3 に渡し、印もなければ早期 exit する。

この必要条件が成り立つ根拠は 2 つある。第一に、`\uXXXX` 以外の JSON 文字列エスケープが生む文字（`"` `\` `/` とバックスペース・改頁・改行・復帰・タブ）は `agent_id` を構成できないため、生表記でないキーは必ず `\uXXXX` を含む。第二に、`agent_id` の 8 文字はすべて U+005F〜U+0074 の範囲にあり、その `\uXXXX` 表記は上位 2 桁が必ず `00` になる（16 進の大文字小文字の揺れは下位 2 桁にしか現れない）。したがって前置は `\u00` に絞ってよい。

判定は必要条件であって十分条件ではなく、`agent_id` を持たない payload が python3 に渡ってよい（MAY）。その場合はパース後に有効な `agent_id` が無く、マーカー付き役でもないと判定されれば、何も出力せず exit 0 する。この向きの外し方が起きる頻度は payload の内容に依存する（PostToolUse の payload は `tool_response` を含むため、Read が読んだファイル内容・Bash の出力・Grep の結果にこの並びがあれば起動する。JSON シリアライザが `\b \f \n \r \t` 以外の制御文字を 4 桁 16 進で綴った出力も同じ）。判定を誤ってよいのはこの向き（余計に起動して無音で終わる）だけであり、逆向き（`agent_id` を持つ payload の早期 exit）は許されない（MUST NOT）。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 上の 3 つ ／ stdin が読めない・JSON でない ／ 導出したトランスクリプトが無い・usage が読めない ／ 探索の上限に達した。しきい値解決の失敗（共通処理の API 欠損・呼出し時の通常例外を含む）・解決値の正数条件違反は stdout 空・exit 0 とし、理由を stderr に出さなければならない（MUST）。再検証通知が無い閾値以内は stdout 空・exit 0 とし、fallback・再検証が必要なら stderr に診断を出す（MUST）。再検証通知があるときは、閾値以内でも stderr の診断に加えて、診断だけの単一 JSON（`hookSpecificOutput` の `hookEventName` と `additionalContext` のみ）を stdout に出して exit 0 とし、本人への通知経路とする（MUST）。出力の形・文面・決定フィールドを付けない規則は dev-workflow-token-thresholds の文脈計測の診断の要件に従う。共通処理の正常な fallback だけを理由に判定を無効にしてはならない（MUST NOT）。

守備範囲は、同梱表・共通処理の結果と payload・ログ・hook の起動環境の `DEVELOP_ROLE` を入力元とし、閾値以内の無音を理由に再検証の必要が本人に届かない誤りと、診断だけでツールを止める誤りを拾う。通知の到達は出力検査と公式の配送規則を根拠とし、実機観測や入力の穴の完全封鎖を完了条件にしない。通してよい入力の例は、根拠に含まれる既知モデルで閾値以内の呼出し（stdout も stderr も空で通す）と、`DEVELOP_ROLE` が無く、`agent_id` を持たないが `\u00` を含む payload（python3 を起動したうえで無音で通す）である。主の起動環境へ空でない `DEVELOP_ROLE` が誤継承され、有効な agent_id がなければ、その主も役として自身ログの計測と二段制約を受けることを許容する。起動環境の印の認証や誤継承の完全防止を完了条件にしない。

#### Scenario: agent_id が無い呼び出しは python3 を起動せず無音

- **WHEN** `DEVELOP_ROLE` が未設定または空で、`agent_id` を含まず、`\u00` も含まない PostToolUse payload を hook に渡す
- **THEN** python3 を起動せずに、何も出力せず exit 0 で終わる

#### Scenario: Unicode エスケープ表記の agent_id でも早期 exit しない

- **WHEN** `agent_id` キーを `"\u0061gent_id"` のように Unicode エスケープで書いた（`json.loads` すると `agent_id` になる）payload を、強制停止の閾値を超えたトランスクリプトを指す形で PreToolUse / `Bash` として渡す
- **THEN** 早期 exit せず、生表記の payload と同じ deny（`permissionDecision: "deny"`）を出す

#### Scenario: エスケープを含むだけの呼び出しは無音で終わる

- **WHEN** `DEVELOP_ROLE` が未設定または空で、`agent_id` を持たないが `\u00` を含む（`tool_response` の中身など）PostToolUse payload を渡す
- **THEN** python3 は起動してよいが、何も出力せず exit 0 で終わる

#### Scenario: 上限内では無音

- **WHEN** 導出したトランスクリプトの最後の usage 合算が解決した `context_cap` 以内である
- **THEN** 根拠に含まれる既知モデルなら stdout も stderr も空・exit 0 で終わる。fallback・再検証が必要なモデルなら stderr に診断が出ると同時に、stdout は `additionalContext` だけの再検証通知 JSON（拒否・締めの決定フィールドなし）になり、exit 0 で終わる

#### Scenario: 測れないときは止めない

- **WHEN** 導出したトランスクリプトが存在しない、または usage を持つ assistant レコードが末尾に無い
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: 入れ子のサブエージェントは深さ 3 段まで探す

- **WHEN** `<session_id>/subagents/` の 2 段目のサブディレクトリに `agent-<agent_id>.jsonl` が置かれている payload を渡す
- **THEN** そのファイルを計測対象として特定する

#### Scenario: 探索の上限に達したら打ち切る

- **WHEN** `<session_id>/subagents/` 以下に 200 件を超えるエントリがあり、目的のファイルが見つからない
- **THEN** 探索を打ち切り、何も出力せず exit 0 で終わる

#### Scenario: 5MB のトランスクリプトでも 100ms 未満

- **WHEN** 5MB のトランスクリプトを対象に hook を 1 回実行する
- **THEN** 実行時間が 100ms 未満で、stdout は閾値判定の結果と必要な再検証通知だけであり、必要なモデル診断は stderr にも出る

#### Scenario: 全解除できる

- **WHEN** `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` を設定して閾値超の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: マーカー付き役は自身のログで二段の制約を受ける

- **WHEN** `DEVELOP_ROLE=worker` で有効な `agent_id` が無い payload を渡し、`transcript_path` の最新 assistant usage 合算を cap 以下、cap と同値、cap 超、hard と同値、hard 超に変える
- **THEN** cap 超の PostToolUse は計測値・上限・締めの指示と return 宣言の書き分けを含む `hookSpecificOutput.additionalContext` を exit 0 で返す。cap 以下は締めを通知しない
- **AND** hard 超の PreToolUse は Edit / Write / NotebookEdit と内容によらない全 Bash を deny し、理由に計測値・hard・cwd・編集済みファイル一覧を return に書く指示・本体が commit する旨・`工程中断:` を含む。hard 以下と Read / Grep / Glob は拒否しない

#### Scenario: 別ログや印の本文を取り違えない

- **WHEN** 自身のログと subagents のログを逆の閾値側に置き、有効な `agent_id` がないマーカー付き役の payload に別の `agent_transcript_path` も指定する
- **THEN** 判定とモデル別閾値の根拠は `transcript_path` の最新 assistant usage と model だけである
- **AND** 環境の印を外し、payload や `tool_input` にだけ `DEVELOP_ROLE=worker` を書いた呼び出しは計測対象にならない

#### Scenario: マーカー付き役でも欠測はゼロとみなさない

- **WHEN** マーカー付き役の自身ログが欠落・読めない・末尾に usage がない、または payload が壊れている
- **THEN** 既存の fail-open と同様に stdout 空・exit 0 であり、他のログを探さず、計測値ゼロや品質成功を出力しない
- **AND** `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`、不正閾値、hard <= cap、モデルの fallback / 再検証通知も既存の規則どおり扱う

#### Scenario: マーカーがあっても有効な agent_id を優先する

- **WHEN** 有効な `agent_id` がある同じ payload を `DEVELOP_ROLE` ありとなしで渡し、自身ログと導出した subagent ログを逆の閾値側に置く
- **THEN** 両方とも既存の導出・上限つき探索で subagent ログを測り、出力と終了コードが一致する
