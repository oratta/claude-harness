## MODIFIED Requirements

### Requirement: 手動で実行先とアカウントを固定する
手動開発は旧形式の Codex account/model、または名前付き profile の役割別 executor/account/model/effort を委譲ごとに解決しなければならない（MUST）。前景実行では、Claude role は account=current と Claude tier を固定して Agent へ渡し、Codex role は account 名を呼び出し側の設定から CODEX_HOME へ解決して依頼ファイルへ固定しなければならない（MUST）。profile と旧 account/model の同時指定を拒否し、どちらの executor が失敗しても他方へ fallback してはならない（MUST NOT）。Codex account 名から CODEX_HOME への対応は `--account-home NAME=PATH` の繰り返し指定、または同じ対応を書いた JSON ファイルで与え、対応に無い Codex account は拒否しなければならない（MUST）。

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

### Requirement: 委譲は解決済み executor の正規経路で行う
手動 adapter 手順書は、role の設定を一度解決した直後に executor で一度だけ分岐しなければならない（MUST）。Claude role は canonical role の Agent 呼び出しを使い、Codex role は「工程限定の指示ファイルを書く → `codex-develop.py request` で依頼ファイルを作る → `codex-worker.py run` を前景コマンドとして起動して結果 JSON を読む」を使う。どちらも fresh thread とし、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

#### Scenario: Claude role を委譲する
- **WHEN** role resolver が executor=claude と account=current、Claude tier、effort を返す
- **THEN** Codex request を作らず、返された model で canonical role を Agent に委譲し、effort は監査情報として保持するだけで Agent の引数に変換しない

#### Scenario: Codex role を委譲する
- **WHEN** role resolver が executor=codex を返す
- **THEN** 指示ファイル、request、foreground run の経路を使い、台帳・job id・ack を使わない

#### Scenario: 旧台帳 dispatch が Claude role を選ぶ
- **WHEN** 保存 snapshot の role が executor=claude に解決される
- **THEN** Codex worker へ送信する前に停止して foreground provider route を案内し、Claude tuple を Codex worker へ渡さない
