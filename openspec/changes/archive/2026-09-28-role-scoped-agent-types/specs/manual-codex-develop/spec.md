## MODIFIED Requirements

### Requirement: 委譲は前景実行の 3 手順で行う
手動 adapter 手順書は、role の設定を解決した直後に executor で一度だけ分岐しなければならない（MUST）。新規の Claude role は canonical role の Agent 呼び出しを使う。Codex role の 1 回の委譲は「その工程に限定した指示を UTF-8 ファイルに書く → `codex-develop.py request` で依頼ファイルを作り `codex-worker.py run` を前景コマンドとして起動する → 完了通知で結果の JSON を読む」の 3 手順で行わなければならない（MUST）。account 名から CODEX_HOME への登録境界は `request` に渡す `--account-home NAME=PATH` または `--account-home-file PATH` だけとし、独立した register command や永続 account registry を設けてはならない（MUST NOT）。手順書に job の受領・再送・run directory・worker state・継続記録の操作を戻してはならない（MUST NOT）。停止は Claude では起動した Agent、Codex では起動した foreground command の停止操作で行わなければならない（MUST）。

Claude role の Agent 呼び出しの `subagent_type` は、canonical role で決めなければならない（MUST）。作業者 W（仕様化判断・仕様作成・仕様差戻し、実装・TDD・verify・修正、archive・Draft PR・仕様宣言）は `dev-workflow:worker`、ゲート実行者 G（ゲートの照合・記録）は `dev-workflow:gate-runner`、仕様レビュー R1 と G が必要とする独立 PR レビューは `general-purpose`、`decider` role は `dev-workflow:decider` とする（SHALL）。事前分類に当たる R1 または G が要求したレビュアーを profile の `decider` entry で起こす場合は、従来どおり `dev-workflow:decider` を使う（SHALL）。

名前付き profile では thread の新規作成と再開を profile role 単位で決めなければならない（MUST）。同じ profile role の Claude thread を canonical develop が再開する前には毎回、現在有効な残量モードの上限を確認する。起動時の適用 model が現在の上限内である場合に限って既存の名前付き thread を SendMessage で再開する。上限を超える場合は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、要求 tuple を変更せず、上限内の適用 model で同じ role の fresh thread へ手渡しし、要求値・適用値・変更理由を記録しなければならない（MUST）。profile role が変わる境界、独立レビュー、または executor=codex の委譲では fresh thread を使い、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

#### Scenario: 手順書から旧状態操作が消えている
- **WHEN** adapter の通常手順を機械的に検索する
- **THEN** register、job の受領・再送、run directory、worker state、継続記録を操作する手順がいずれも見つからない

#### Scenario: Claude role を委譲する
- **WHEN** role resolver が executor=claude と account=current、Claude tier、effort を返す
- **THEN** Codex request を作らず、返された model を要求 model として保持し、残量モード適用後の model で canonical role を Agent に委譲する。W は `subagent_type: dev-workflow:worker`、G は `dev-workflow:gate-runner`、R1 と独立 PR レビューは `general-purpose`、`decider` role は `dev-workflow:decider` とし、`exhausted` で適用 model が `opus` に下がっても `decider` の subagent_type は変えない。effort は監査情報として保持するだけで Agent の引数に変換しない

#### Scenario: 手順書が canonical role ごとの種別を書く
- **WHEN** `plugins/dev-workflow/references/codex-develop.md` の Claude role の新規起動の段落を読む
- **THEN** W に `dev-workflow:worker`、G に `dev-workflow:gate-runner`、`decider` role に `dev-workflow:decider` が書かれ、W / G を `general-purpose` で起こす記述が無い

#### Scenario: Codex role を委譲する
- **WHEN** role resolver が executor=codex を返す
- **THEN** 指示ファイル、request、foreground run の経路を使い、job id や永続 transport state を使わない

#### Scenario: 同じ Claude profile role を再開する
- **WHEN** canonical develop が差戻しまたは次段のため、同じ profile role の名前付き Claude thread を再開する
- **THEN** 再開前に現在有効な上限を確認し、既存 thread の適用 model が上限内の場合に限って、要求 tuple と適用 model を変えず SendMessage で再開する

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
