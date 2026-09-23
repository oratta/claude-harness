## ADDED Requirements

### Requirement: 系統名は委譲の直前に model/list から最新版へ解決する
worker は request の model が正規表現 `^[a-z]+$` に一致するとき、それを系統名として扱い、initialize と account 照合の後かつ thread/start の前に、指定された CODEX_HOME で起動した account の model/list（`includeHidden: true`、全ページ）から実際のモデル ID に解決しなければならない（MUST）。候補は `hidden` が `true` でなく、`model` フィールドが `^gpt-<版>-<系統名>$`（`<版>` は `[0-9]+(\.[0-9]+)*`）に完全一致する entry とし、版を数値の並びとして末尾の 0 を除いて比べ、最も新しい 1 件を選ばなければならない（MUST）。候補が 0 件なら `model_not_available`、最も新しい版の entry が 2 件以上なら `model_not_unique` で止まり、thread/start と turn/start を一度も呼ばず、別モデル・別 account・別 provider に fallback してはならない（MUST NOT）。系統名の固定の列挙を持ってはならない（MUST NOT）。model が `^[a-z]+$` に一致しないときは完全なモデル ID として、従来どおり `model` フィールドの完全一致で照合しなければならない（MUST）。経路（系統名・完全 ID）を問わず、model/list の全ページに `hidden` が真偽値以外の entry が 1 件でもあれば、その entry が照合対象かどうかにかかわらず `model_list_invalid` で止まらなければならない（MUST）。`hidden` キーが無い entry は表示扱いとする。系統名の経路でも、候補 0 件・非一意以外の失敗（一覧が不正・一覧の取得に失敗）は完全 ID と同じ `model_list_invalid` / `model_list_unavailable` で止まらなければならない（MUST）。

守備範囲: `model` は、組み込み役割表・外部 profile-file・旧形式 `--model` のいずれかから resolver がそのまま写した値で、利用者自身が書く設定である（外部からの信頼できない入力ではない）。この要件が拾いたい誤りは、要求した系統に表示モデルが無いこと、最新版が 1 件に決まらないこと、一覧が不正または取得できないことの 3 つで、いずれも別モデルに倒さず止める。通ることを許す入力は、`sol` / `luna` / `astra`、列挙していない系統名（`terra` 等）、版を固定した完全 ID（`gpt-5.6-sol`）、hidden のモデルの完全 ID 指定（`gpt-reserve`）である。守らないものは次のとおり: 系統名の打ち間違いと提供されていない系統は区別せず、どちらも同じ `model_not_available` とする。OpenAI が `gpt-<版>-<系統名>` の形を変えた場合は、利用者が完全 ID を書くか規則を直して対処する。英小文字だけの完全 ID が将来現れた場合に系統名と誤分類されることは受け入れる。新しく見つかった照合の穴を塞ぎ切ることを、この要件の完了条件にしない。

#### Scenario: 現在の一覧で三つの系統名を解決する
- **WHEN** model/list が `gpt-6-astra`、`gpt-6-sol`、`gpt-6-luna`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna`、`gpt-5.5` を表示し、`gpt-reserve` と `codex-auto-review` を hidden で返すフィクスチャで、model=sol、luna、astra の request をそれぞれ実行する
- **THEN** それぞれ `gpt-6-sol`、`gpt-6-luna`、`gpt-6-astra` に解決され、thread/start と turn/start の model には解決後の ID が渡る

#### Scenario: 該当する系統のモデルが無い
- **WHEN** model/list に `gpt-<版>-sol` の形の表示モデルが 1 件も無い（hidden の `gpt-7-sol` だけがある場合を含む）状態で model=sol を要求する
- **THEN** `error_kind` を `model_not_available` とし、thread/start と turn/start を呼ばず、非ゼロで終了する

#### Scenario: 最新版が 1 件に決まらない
- **WHEN** model/list に `gpt-6-sol` が 2 件ある、または `gpt-6-sol` と `gpt-6.0-sol` が並存する状態で model=sol を要求する
- **THEN** `error_kind` を `model_not_unique` とし、thread/start と turn/start を呼ばず、非ゼロで終了する

#### Scenario: 版を数値として比べる
- **WHEN** model/list に `gpt-5.9-sol` と `gpt-5.10-sol` があり、`gpt-6-sol-mini` もある状態で model=sol を要求する
- **THEN** `gpt-5.10-sol` に解決し、後ろに語が続く `gpt-6-sol-mini` は候補にしない

#### Scenario: 完全なモデル ID は従来どおり照合する
- **WHEN** model=gpt-5.6-sol、または hidden の `gpt-reserve` を要求する
- **THEN** 系統名の解決を行わず、`model` フィールドの完全一致で 1 件を選び、hidden でも受理する

## MODIFIED Requirements

### Requirement: effort を二段階で検証してから実行する
worker は依頼を受け取ったとき、optional effort の非空文字列、許可キー、定義済み role、`auth.json` を含む CODEX_HOME を静的に検証しなければならない（MUST）。モデル名と effort の対応は initialize 後かつ thread/start 前に、指定された CODEX_HOME で起動した account の model/list を使って検証しなければならない（MUST）。系統名を要求したときは、解決後のモデルの supportedReasoningEfforts に対して effort を検証しなければならない（MUST）。固定 enum で対応を推測してはならない（MUST NOT）。

#### Scenario: 静的に不正な request を渡す
- **WHEN** effort が空/非文字列、role が未定義、未知フィールドがある、または CODEX_HOME が利用できない
- **THEN** App Server に turn を送る前に拒否し、同じ形の失敗 JSON と非ゼロ終了コードを返す

#### Scenario: モデル固有の effort が非対応である
- **WHEN** model/list が luna に ultra を広告していないのに luna/ultra を要求する
- **THEN** 非対応 effort を `error_kind` に入れ、thread/start と turn/start を一度も呼ばず、非ゼロで終了する

#### Scenario: 系統名の effort を解決後のモデルで検証する
- **WHEN** model/list が `gpt-5.6-sol` には high を広告し、`gpt-6-sol` には high を広告しない状態で sol/high を要求する
- **THEN** 解決後の `gpt-6-sol` に対して検証し、`unsupported_model_effort` で止まり、旧版の `gpt-5.6-sol` に倒さない

#### Scenario: 一覧に無いモデルまたは一覧取得失敗
- **WHEN** 完全なモデル ID または系統名を要求し、includeHidden=true の全ページに該当する一意なモデルがない（完全 ID は model フィールドの完全一致、系統名は解決規則による）、一覧が不正、または model/list の取得に失敗する
- **THEN** 開始前に原因を返し、既定モデルや別の実行先へ fallback しない。一覧の不正は `model_list_invalid`、取得失敗は `model_list_unavailable` で、系統名でも完全 ID と同じ理由になる

#### Scenario: 広告された新しい effort または hidden モデル
- **WHEN** 明示指定した完全なモデル ID が一覧にあり、その supportedReasoningEfforts の reasoningEffort に要求値が含まれる
- **THEN** 固定 enum や hidden 属性を理由に拒否せず、指定モデルと effort を使用する

### Requirement: effort は turn start のみに渡す
worker は model を thread/start と turn/start の双方へ渡し、明示された effort を turn/start の effort にのみ渡さなければならない（MUST）。系統名を要求したときに両 RPC へ渡す model は解決後のモデル ID とし、request の payload の model は書き換えてはならない（MUST NOT）。effort が省略された依頼では送信時も省略し、payload を補完してはならない（MUST NOT）。指定 CODEX_HOME の identity、role ごとの sandbox・networkAccess、writableRoots を持たない readOnly policy を維持しなければならない（MUST）。explore / summarize は本体が汎用サブエージェントとして起こす read-only role なので、review 系と同じく networkAccess=true としなければならない（MUST）。

#### Scenario: 明示 effort を送信する
- **WHEN** model=sol の request で sol/high の検証が成功し、sol が gpt-6-sol に解決される
- **THEN** 両 RPC の model は gpt-6-sol、turn/start.effort は high となり、thread/start の effort や config に effort を追加しない

#### Scenario: effort がない request
- **WHEN** model のみを指定した依頼を実行する
- **THEN** model/list で model を照合または解決し、turn/start に effort を載せず、要求値を補完しない

### Requirement: 要求設定と実効設定を ID と共に公開する
worker は execution.version=1 形式で role/requested/effective/evidence を payload と別に保持し、thread_id と turn_id に結び付けなければならない（MUST）。execution には model の解決結果 `model_resolution: {requested, kind, resolved, source}` も入れなければならない（MUST）。`kind` は `family`（系統名）か `exact`（完全なモデル ID）、`resolved` は model/list で選んだモデル ID、`source` は `model/list` とし、解決の前に失敗したときや解決できなかったときは `resolved` を null、`source` を `unavailable` としなければならない（MUST）。公開先は標準出力の 1 行 JSON だけとし、worker が結果をファイルや永続 store に保存してはならない（MUST NOT）。要求値、解決結果、model/list の default を実効値として補完してはならない（MUST NOT）。

#### Scenario: 実効設定を観測できる
- **WHEN** account 照合が成功し、RPC 応答または通知で model/effort を取得する
- **THEN** executor/account/model/effort の要求値と実効値、観測元を別々に JSON に入れ、turn 観測を thread 観測より優先する。worker は差異を理由に失敗扱い・自動再送をせず、差異の判定は JSON を受け取った本体が行う

#### Scenario: 系統名の要求値と解決後の ID を両方公開する
- **WHEN** model=sol の request が gpt-6-sol に解決されて実行される
- **THEN** `execution.requested.model` は `sol`、`execution.model_resolution` は `{requested: "sol", kind: "family", resolved: "gpt-6-sol", source: "model/list"}` となり、`execution.effective.model` は RPC 応答で観測した値だけを持つ

#### Scenario: 実効値または ID が取得できない
- **WHEN** API が effort を返さない、または thread/turn 作成前に失敗する
- **THEN** 不明な実効値/ID は null、観測元は unavailable とし、取得できた role/要求設定/ID だけを返す。解決の前に失敗した場合は `model_resolution.resolved` も null とする

#### Scenario: 前景経路で実効設定を公開する
- **WHEN** 前景実行が完走または失敗して結果を返す
- **THEN** role/requested/effective/evidence/model_resolution と取得できた ID が標準出力の JSON に入り、ファイルへ保存されない
