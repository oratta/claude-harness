## MODIFIED Requirements

### Requirement: 手動で実行先とアカウントを固定する
手動開発は旧形式の Codex account/model、または名前付き profile の役割別 executor/account/model/effort を委譲ごとに解決しなければならない（MUST）。role resolver は profile にある要求 tuple を変更せず返さなければならない（MUST）。前景実行では、Claude role は account=current と要求された Claude tier を保持し、既存の残量モードを適用した実効 model で Agent を起動する。Codex role は account 名を呼び出し側の設定から CODEX_HOME へ解決して依頼ファイルへ固定しなければならない（MUST）。profile と旧 account/model の同時指定を拒否し、どちらの executor が失敗しても他方へ fallback してはならない（MUST NOT）。Codex account 名から CODEX_HOME への対応は `--account-home NAME=PATH` の繰り返し指定、または同じ対応を書いた JSON ファイルで与え、対応に無い Codex account は拒否しなければならない（MUST）。

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

### Requirement: 品質工程を維持する
工程管理は develop の正本を使用し、W/R1/G/追加レビュアー/decider の各役割を解決済み executor へ委譲しなければならない（MUST）。executor が Claude でも Codex でも、レビューは作業者と別 thread かつ read-only でなければならない（MUST）。

#### Scenario: 仕様に差し戻し
- **WHEN** 独立仕様レビューが修正を要求する
- **THEN** 本体が正本の回数上限を確認し、profile の spec-write executor へ修正を委譲する

#### Scenario: 独立レビューへ到達する
- **WHEN** G が別レビューを要求する
- **THEN** 本体は profile の impl-review executor で新しい read-only thread を作り、Claude と Codex のどちらを選んでも同じレビュー契約を適用する

### Requirement: provider指定で品質ワークフローを分岐させない
仕様要否・レビュー・検証・工程順序は既存 develop の正本に一元化しなければならない（MUST）。adapter は解決済み executor に応じた起動・停止・結果の受け取りと、台帳経路に限った状態確認・結果回収・実行先と ownership の管理を担当し、独自の仕様必須条件や品質ゲートを設けてはならない（MUST NOT）。前景実行では状態確認・結果回収・ownership の管理は発生せず、adapter が担うのは起動・停止・結果の受け取りだけである。phase は役割指示選択ラベルであり工程順序の強制ではない。

#### Scenario: 仕様不要の通常判断
- **WHEN** W が既存 develop に従い仕様化判断をしないと理由付きで返す
- **THEN** 本体はその記録を使って既存 develop の実装工程へ進み、adapter は仕様 artifact や R1 承認を追加要求しない

#### Scenario: 仕様が必要な通常判断
- **WHEN** W が既存 develop に従い仕様化すると判断する
- **THEN** 本体は正本の仕様作成・R1 レビュー・承認条件を適用し、adapter は指示された役割を解決済み executor へ委譲する

#### Scenario: 既存の検証で失敗する
- **WHEN** 正本が要求する検証で失敗する
- **THEN** 本体と担当役割は既存 develop の差戻し規則に従い、adapter に別の検証手順や承認台帳を作らない

### Requirement: 委譲は前景実行の 3 手順で行う
手動 adapter 手順書は、role の設定を解決した直後に executor で一度だけ分岐しなければならない（MUST）。新規の Claude role は canonical role の Agent 呼び出しを使う。Codex role の 1 回の委譲は「その工程に限定した指示を UTF-8 ファイルに書く → `codex-develop.py request` で依頼ファイルを作り `codex-worker.py run` を前景コマンドとして起動する → 完了通知で結果の JSON を読む」の 3 手順で行わなければならない（MUST）。手順書に受領（`ack`）・送信復旧（`retry`）・run ディレクトリ・worker の台帳ディレクトリ・継続記録の操作を通常経路として戻してはならない（MUST NOT）。停止は Claude では起動した Agent、Codex では起動したコマンドの停止操作で行い、旧台帳または Codex 専用の中断コマンドを通常経路に置いてはならない（MUST NOT）。

名前付き profile では thread の新規作成と再開を profile role 単位で決めなければならない（MUST）。同じ profile role の Claude thread を canonical develop が再開するときは、既存の名前付き thread を SendMessage で再開し、要求 tuple と起動時に適用した model を維持する。profile role が変わる境界、独立レビュー、または executor=codex の委譲では fresh thread を使い、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

#### Scenario: 手順書から旧台帳経路の操作が消えている
- **WHEN** adapter の通常手順を機械的に検索する
- **THEN** 受領・送信復旧・run ディレクトリ・worker の台帳ディレクトリ・継続記録を操作する手順がいずれも見つからない

#### Scenario: Claude role を委譲する
- **WHEN** role resolver が executor=claude と account=current、Claude tier、effort を返す
- **THEN** Codex request を作らず、返された model を要求 model として保持し、残量モード適用後の model で canonical role を Agent に委譲し、effort は監査情報として保持するだけで Agent の引数に変換しない

#### Scenario: Codex role を委譲する
- **WHEN** role resolver が executor=codex を返す
- **THEN** 指示ファイル、request、foreground run の経路を使い、台帳・job id・ack を使わない

#### Scenario: 同じ Claude profile role を再開する
- **WHEN** canonical develop が差戻しまたは次段のため、同じ profile role の名前付き Claude thread を再開する
- **THEN** fresh Agent を作らず SendMessage で既存 thread を再開し、最初の起動で固定した要求 tuple と適用 model を変えない

#### Scenario: profile role が変わる
- **WHEN** canonical develop の次の委譲で profile role が spec-write から implement のように変わる
- **THEN** 次の role の tuple を解決して fresh thread を起動し、前の thread から会話履歴全体ではなく成果物と必要な要約だけを渡す

#### Scenario: 走行中の委譲を止める
- **WHEN** 本体が走行中の委譲を止める必要がある
- **THEN** 解決済み executor で起動した Agent またはコマンドを停止し、旧台帳操作や Codex 側の別中断コマンドを要求しない

#### Scenario: 旧台帳 dispatch が Claude role を選ぶ
- **WHEN** 保存 snapshot の role が executor=claude に解決される
- **THEN** Codex worker へ送信する前に停止して foreground provider route を案内し、Claude tuple を Codex worker へ渡さない
