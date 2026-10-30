## MODIFIED Requirements

### Requirement: 手動で実行先とアカウントを固定する
手動開発は旧形式の Codex account/model、または名前付き profile の役割別 executor/account/effort と `model-tier-resolution` の格から引いた model を委譲ごとに解決しなければならない（MUST）。role resolver は要求の値（`requested_tier`・`requested_model`）と適用の値（`tier`・`executed_tier`・`model`）を分けて返さなければならない（MUST）。前景実行では、Claude role は account=current で、resolver が返した `model` で Agent を起動する。Codex role は account 名を呼び出し側の設定から CODEX_HOME へ解決して依頼ファイルへ固定しなければならない（MUST）。profile と旧 account/model の同時指定を拒否し、どちらの executor が失敗しても他方へ fallback してはならない（MUST NOT）。Codex account 名から CODEX_HOME への対応は `--account-home NAME=PATH` の繰り返し指定、または同じ対応を書いた JSON ファイルで与え、対応に無い Codex account は拒否しなければならない（MUST）。

#### Scenario: 旧形式の手動依頼
- **WHEN** 人間が Codex の単一 account/model を指定する
- **THEN** burn 窓を要求せず同 account/model で全 Codex 委譲を行い、effort を後付けしない

#### Scenario: 混在設定セットの手動依頼
- **WHEN** 人間が混在 profile を指定して複数の role を順に委譲する
- **THEN** 各委譲は当該 role の executor/account/model/effort だけを解決し、Claude role は Agent、Codex role は前景 request/run を使う

#### Scenario: 前景実行で Codex role の設定を解決する
- **WHEN** executor=codex の role について前景依頼を組み立てる
- **THEN** その role の executor/account/model/effort を依頼ファイルへ固定し、account 名を呼び出し側の対応から解決した CODEX_HOME を同じ依頼に載せ、他 role の設定を持ち込まない

#### Scenario: 解決できない Codex account 名を指定する
- **WHEN** profile の Codex role が指す account 名が、呼び出し側が与えた対応に含まれていない
- **THEN** 依頼ファイルを作らずに拒否し、既定の CODEX_HOME や別 account の CODEX_HOME へ倒さない

### Requirement: 委譲は前景実行の 3 手順で行う
手動 adapter 手順書は、role の設定を解決した直後に executor で一度だけ分岐しなければならない（MUST）。新規の Claude role は canonical role の Agent 呼び出しを使う。Codex role の 1 回の委譲は「その工程に限定した指示を UTF-8 ファイルに書く → `codex-develop.py request` で依頼ファイルを作り `codex-worker.py run` を前景コマンドとして起動する → 完了通知で結果の JSON を読む」の 3 手順で行わなければならない（MUST）。account 名から CODEX_HOME への登録境界は `request` に渡す `--account-home NAME=PATH` または `--account-home-file PATH` だけとし、独立した register command や永続 account registry を設けてはならない（MUST NOT）。手順書に job の受領・再送・run directory・worker state・継続記録の操作を戻してはならない（MUST NOT）。停止は Claude では起動した Agent、Codex では起動した foreground command の停止操作で行わなければならない（MUST）。

Claude role の Agent 呼び出しの `subagent_type` は、canonical role で決めなければならない（MUST）。作業者 W（仕様化判断・仕様作成・仕様差戻し、実装・TDD・verify・修正、archive・Draft PR・仕様宣言）は `dev-workflow:worker`、ゲート実行者 G（ゲートの照合・記録）は `dev-workflow:gate-runner`、G が必要とする独立 PR レビューは `dev-workflow:reviewer`、仕様レビュー R1 は `general-purpose`、`decider` role は `dev-workflow:decider` とする（SHALL）。事前分類に当たる R1 または G が要求したレビュアーを profile の `decider` entry で起こす場合は、従来どおり `dev-workflow:decider` を使う（SHALL）。

名前付き profile では thread の新規作成と再開を profile role 単位で決めなければならない（MUST）。同じ profile role の Claude thread を canonical develop が再開する前には毎回、同じ phase と入力で `request` を呼び直し、返った `tier` と動いている thread の格（起動時に記録した `tier`）を比べる。呼び直しの結果は `tier` だけを読み、executor・account・依頼ファイルは使わず、構成の選び直しにも使わない（MUST NOT）。返った `tier` が thread の格より低くない場合に限って既存の名前付き thread を SendMessage で再開する。低い場合は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、要求 tuple を変更せず、上限内の適用 model で同じ role の fresh thread へ手渡しし、要求値・適用値・変更理由を記録しなければならない（MUST）。profile role が変わる境界、独立レビュー、または executor=codex の委譲では fresh thread を使い、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

#### Scenario: 手順書から旧状態操作が消えている
- **WHEN** adapter の通常手順を機械的に検索する
- **THEN** register、job の受領・再送、run directory、worker state、継続記録を操作する手順がいずれも見つからない

#### Scenario: Claude role を委譲する
- **WHEN** role resolver が executor=claude と account=current、`requested_model`、`model`、effort を返す
- **THEN** Codex request を作らず、返された `requested_model` を要求 model として保持し、返された `model` で canonical role を Agent に委譲する。本体は残量モードの上限を計算し直さない。W は `subagent_type: dev-workflow:worker`、G は `dev-workflow:gate-runner`、独立 PR レビューは `dev-workflow:reviewer`、R1 は `general-purpose`、`decider` role は `dev-workflow:decider` とし、`exhausted` で `model` が `opus` に下がっても `decider` の subagent_type は変えない。effort は監査情報として保持するだけで Agent の引数に変換しない

#### Scenario: 手順書が canonical role ごとの種別を書く
- **WHEN** `plugins/dev-workflow/references/codex-develop.md` の Claude role の新規起動の段落を読む
- **THEN** W に `dev-workflow:worker`、G に `dev-workflow:gate-runner`、レビュアーに `dev-workflow:reviewer`、`decider` role に `dev-workflow:decider` が書かれ、W / G とレビュアーを `general-purpose` で起こす記述が無い

#### Scenario: Codex role を委譲する
- **WHEN** role resolver が executor=codex を返す
- **THEN** 指示ファイル、request、foreground run の経路を使い、job id や永続 transport state を使わない

#### Scenario: 同じ Claude profile role を再開する
- **WHEN** canonical develop が差戻しまたは次段のため、同じ profile role の名前付き Claude thread を再開する
- **THEN** 再開前に同じ phase と入力で `request` を呼び直し、返った `tier` が thread の格より低くない場合に限って、要求 tuple と適用 model を変えず SendMessage で再開する。呼び直しで構成は選び直さない

#### Scenario: exhausted へ変更後に同じ Claude profile role を再開する
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した名前付き Claude thread がある
- **WHEN** `FABLE_BUDGET_MODE=exhausted` へ変わった後に同じ profile role を再開し、共有枠は depleted でない
- **THEN** 既存 thread に SendMessage せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread を applied model=`opus` で起動し、変更理由=`FABLE_BUDGET_MODE=exhausted` を記録する

#### Scenario: depleted へ変更後に同じ Claude profile role を再開する
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した名前付き Claude thread がある
- **WHEN** `SHARED_BUDGET_MODE=depleted` へ変わった後に同じ profile role を再開する
- **THEN** 既存 thread に SendMessage せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread を applied model=`sonnet` で起動し、変更理由=`SHARED_BUDGET_MODE=depleted` を記録する

#### Scenario: profile role が変わる
- **WHEN** canonical develop の次の委譲で profile role が spec-write から implement のように変わる
- **THEN** 次の role の tuple を解決して fresh thread を起動し、前の thread から会話履歴全体ではなく成果物と必要な要約だけを渡す

#### Scenario: 走行中の委譲を止める
- **WHEN** 本体が走行中の委譲を止める必要がある
- **THEN** 解決済み executor で起動した Agent または foreground command を停止し、別の状態操作を要求しない
