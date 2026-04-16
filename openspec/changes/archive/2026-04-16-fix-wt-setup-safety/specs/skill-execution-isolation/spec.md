## ADDED Requirements

### Requirement: スクリプト出力ベースの分岐は対話を最小化する

スクリプト出力に基づく LLM の分岐処理は、自明な判断に対して AskUserQuestion を使用せず、自動判定ルールに基づいて処理するものとする（SHALL）。AskUserQuestion は、判断に必要な情報がスクリプト出力や既存ファイルから得られない場合のみ使用する（SHALL）。

#### Scenario: .worktreeinclude のパターン選択で AskUserQuestion を使用しない
- **WHEN** `.worktreeinclude` の生成が必要と判定される
- **THEN** env 系・ローカル設定系のパターンは AskUserQuestion なしで自動決定される

#### Scenario: 判断不能な場合のみ AskUserQuestion を使用する
- **WHEN** `.gitignore` に分類ルールに該当しない未知のパターンがある
- **AND** そのパターンがワークツリーで必要かどうかスクリプト出力や既存ファイルから判断できない
- **THEN** そのパターンのみ AskUserQuestion で確認する
