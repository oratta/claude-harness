# longrun-degraded-run-artifacts Specification

## Purpose
TBD - created by archiving change openspec-degradation. Update Purpose after archive.
## Requirements
### Requirement: 縮退モードでは spec 類を run ディレクトリ内に自己完結生成する

縮退モードの run は、OpenSpec CLI（`openspec new change` / `openspec apply` 等）を一切呼び出さず、change ごとの proposal / tasks 相当のドキュメントを `_longruns/<run>/specs/<change-name>/` 配下に生成しなければならない（SHALL）。tasks 相当はチェックボックス形式（`- [ ] X.Y`）を維持し、Build フェーズの進捗トラッキングに使用する（SHALL）。`openspec/` ディレクトリ配下には一切書き込んではならない（MUST NOT）。

#### Scenario: 縮退 run で proposal / tasks 相当が run ディレクトリに生成される

- **WHEN** 縮退モードで run を開始し、Setup フェーズの change 分解が完了する
- **THEN** 各 change の proposal.md / tasks.md 相当が `_longruns/<run>/specs/<change-name>/` 配下に生成され、tasks はチェックボックス形式で Build フェーズから参照できる

#### Scenario: 縮退 run は openspec ディレクトリに書き込まない

- **WHEN** openspec 未 init の repo で縮退 run を完走させる
- **THEN** repo 内に `openspec/` ディレクトリは作成されず、生成物はすべて `_longruns/<run>/` 配下に収まっている

### Requirement: 縮退モードでも verification-guide 相当を生成する

縮退モードの run は、Feedback フェーズでユーザーが動作確認に使う verification-guide 相当（Scenario の WHEN/THEN チェックリスト）を、`_longruns/<run>/specs/` 配下の spec 類から抽出して `_longruns/<run>/verification-guide.md` に生成しなければならない（SHALL）。形式は通常モードの verification-guide と同等とする（SHALL）。

#### Scenario: 縮退 run で verification-guide が生成される

- **WHEN** 縮退モードの run が Verify フェーズを完了して Feedback フェーズに入る
- **THEN** `_longruns/<run>/verification-guide.md` が通常モードと同等の WHEN/THEN チェックリスト形式で生成され、ユーザーに動作確認手順として提示される

### Requirement: 縮退 run は Archive まで完走できる

縮退モードの run は、OpenSpec CLI が存在しない環境でも Setup → Build Contract → Build → Verify → Feedback → Archive の全フェーズを完走できなければならない（SHALL）。Archive フェーズでは OpenSpec change の移動をスキップし、ランディレクトリのアーカイブのみを行う（SHALL）。

#### Scenario: コマンド不在環境で縮退 run が全フェーズ完走する

- **WHEN** `npx openspec` が解決できない環境で縮退モードを承諾して run を実行し、Archive フェーズまで進める
- **THEN** OpenSpec CLI 呼び出し起因のエラーが一切発生せず全フェーズが完了し、ランディレクトリが `_longruns/` のアーカイブ先に移動される（`openspec/changes/archive/` への移動は発生しない）

