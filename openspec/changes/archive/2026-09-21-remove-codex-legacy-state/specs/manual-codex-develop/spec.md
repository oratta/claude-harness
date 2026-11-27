## MODIFIED Requirements

### Requirement: provider指定で品質ワークフローを分岐させない
仕様要否・レビュー・検証・工程順序は既存 develop の正本に一元化しなければならない（MUST）。adapter は解決済み executor に応じた起動・停止・結果の受け取りだけを担当し、独自の仕様必須条件、品質 gate、永続 transport state を設けてはならない（MUST NOT）。phase は役割指示選択ラベルであり工程順序の強制ではない。

#### Scenario: 仕様不要の通常判断
- **WHEN** W が既存 develop に従い仕様化判断をしないと理由付きで返す
- **THEN** 本体はその記録を使って既存 develop の実装工程へ進み、adapter は仕様 artifact や R1 承認を追加要求しない

#### Scenario: 仕様が必要な通常判断
- **WHEN** W が既存 develop に従い仕様化すると判断する
- **THEN** 本体は正本の仕様作成・R1 レビュー・承認条件を適用し、adapter は指示された役割を解決済み executor へ委譲する

#### Scenario: 既存の検証で失敗する
- **WHEN** 正本が要求する検証で失敗する
- **THEN** 本体と担当役割は既存 develop の差戻し規則に従い、adapter に別の検証手順や承認 store を作らない

### Requirement: 輸送結果を品質承認にしない
worker の completed を品質合格として扱ってはならない（MUST NOT）。本体は最終回答と error_kind を確認して既存 develop のレビュー記録/判断契約へ渡さなければならない（MUST）。worker の認証固定と read-only の強制を維持しなければならない（MUST）。前景実行が結果を返さず終了した場合は、保存依頼の replay や別 provider/account への fallback を行わず、記録先と worktree からその工程を fresh phase としてやり直さなければならない（MUST）。

#### Scenario: 途中APPROVEと最終差戻し
- **WHEN** commentary に APPROVE があり最終回答は REQUEST_CHANGES である
- **THEN** worker は最終回答を返し、本体は既存レビュー契約で差戻しを扱う

#### Scenario: 実行エラーを伴う結果
- **WHEN** 結果に認証変更や未対応要求の error_kind がある
- **THEN** 本体は品質承認として記録せず、実行失敗として扱う

#### Scenario: 前景実行の結果が得られないまま終わる
- **WHEN** 前景実行が結果の JSON を返す前に終了する
- **THEN** 本体は保存 request を再送せず、記録先と worktree を見てその工程を fresh phase としてやり直す

### Requirement: 委譲は前景実行の 3 手順で行う
手動 adapter 手順書は、role の設定を解決した直後に executor で一度だけ分岐しなければならない（MUST）。新規の Claude role は canonical role の Agent 呼び出しを使う。Codex role の 1 回の委譲は「その工程に限定した指示を UTF-8 ファイルに書く → `codex-develop.py request` で依頼ファイルを作り `codex-worker.py run` を前景コマンドとして起動する → 完了通知で結果の JSON を読む」の 3 手順で行わなければならない（MUST）。account 名から CODEX_HOME への登録境界は `request` に渡す `--account-home NAME=PATH` または `--account-home-file PATH` だけとし、独立した register command や永続 account registry を設けてはならない（MUST NOT）。手順書に job の受領・再送・run directory・worker state・継続記録の操作を戻してはならない（MUST NOT）。停止は Claude では起動した Agent、Codex では起動した foreground command の停止操作で行わなければならない（MUST）。

名前付き profile では thread の新規作成と再開を profile role 単位で決めなければならない（MUST）。同じ profile role の Claude thread を canonical develop が再開する前には毎回、現在有効な残量モードの上限を確認する。起動時の適用 model が現在の上限内である場合に限って既存の名前付き thread を SendMessage で再開する。上限を超える場合は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、要求 tuple を変更せず、上限内の適用 model で同じ role の fresh thread へ手渡しし、要求値・適用値・変更理由を記録しなければならない（MUST）。profile role が変わる境界、独立レビュー、または executor=codex の委譲では fresh thread を使い、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

#### Scenario: 手順書から旧状態操作が消えている
- **WHEN** adapter の通常手順を機械的に検索する
- **THEN** register、job の受領・再送、run directory、worker state、継続記録を操作する手順がいずれも見つからない

#### Scenario: Claude role を委譲する
- **WHEN** role resolver が executor=claude と account=current、Claude tier、effort を返す
- **THEN** Codex request を作らず、返された model を要求 model として保持し、残量モード適用後の model で canonical role を Agent に委譲する。`decider` role は `subagent_type: dev-workflow:decider`、他の role は `general-purpose` とし、`exhausted` で適用 model が `opus` に下がっても `decider` の subagent_type は変えない。effort は監査情報として保持するだけで Agent の引数に変換しない

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

## REMOVED Requirements

### Requirement: 保存依頼のまま送信を復旧する
**Reason**: canonical transport は foreground command と fresh phase であり、run/pending/request replay の永続状態を持たないため廃止する。

**Migration**: 結果を得られなかった委譲は、issue または Draft PR と worktree の状態を確認して工程の最初からやり直す。

#### Scenario: 送信到達が不明になる
- **WHEN** foreground command が結果 JSON を返さずに終了する
- **THEN** 保存 request を replay せず、同じ role の fresh phase を開始する
