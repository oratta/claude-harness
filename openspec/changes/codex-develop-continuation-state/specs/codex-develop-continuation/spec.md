## ADDED Requirements

### Requirement: 継続依頼は初回の Codex 設定を復元する
Codex executor の初回確定後、coordinator は issue または Draft PR に executor・account・model・run-dir・worker-state を機械可読な継続記録として保存しなければならない（MUST）。引数なしの追加依頼では、その記録と run の整合性を検証したうえで同じ Codex executor と run に委譲しなければならない（MUST）。

#### Scenario: 初回設定から追加依頼を復元する
- **WHEN** 記録先に `executor codex`、account、model、run-dir、worker-state が一意に記録され、保存済み run の固定値と一致した状態で追加依頼が来る
- **THEN** coordinator はオプション再指定なしで同じ run・account・model を使い、追加依頼を Codex 担当へ委譲する

#### Scenario: 追加依頼でも担当を変更しない
- **WHEN** 初回と同じ会話で調査・修正・レビューの追加依頼が来る
- **THEN** coordinator は記録された executor/account/model/run-dir を使い、Claude 本体が調査・原因判断・コード修正を代行しない

### Requirement: 復元不能時は安全に停止する
継続設定を一意に復元できない場合、coordinator は Claude 実行または別 account/run へ黙って fallback してはならず（MUST NOT）、不足している指定を求めて停止しなければならない（MUST）。

#### Scenario: 記録がない
- **WHEN** executor 未指定の追加依頼に対して継続記録が見つからない
- **THEN** coordinator は停止し、executor・account・model・run-dir の指定を求める

#### Scenario: 記録が不一致または曖昧
- **WHEN** 記録の形式不正、複数候補、run 不在、または account/model/worker-state/cwd の不一致がある
- **THEN** coordinator は Codex も Claude も実行せず、検出した不一致を示して指定を求める

### Requirement: 継続復元は既存 develop の品質工程を変えない
継続設定の復元は transport の選択だけを担い、仕様要否・分割・レビュー・verify・finish/G・差戻しの条件を既存 develop と roles の正本から変更してはならない（MUST NOT）。

#### Scenario: 仕様不要の追加依頼
- **WHEN** 継続した Codex の W が既存基準に従い `仕様化判断: しない` を返す
- **THEN** coordinator は既存 develop の実装工程へ進み、Codex adapter の仕様必須や独自承認を要求しない

#### Scenario: 継続した案件のレビュー
- **WHEN** 追加依頼を含む案件が通常のレビューまたは finish/G に到達する
- **THEN** coordinator は既存 develop のレビュー・代理操作・ゲート条件を適用し、transport 完了を品質承認として扱わない

### Requirement: 継続復元の回帰を検証する
実装は設定復元、復元不能時の停止、追加依頼の委譲先固定を自動テストで検証しなければならない（MUST）。また、追加依頼を1回以上含む案件を公開 PR の finish/G まで実測し、その結果を記録しなければならない（MUST）。

#### Scenario: 回帰テストが3つの境界を固定する
- **WHEN** 継続機能のテストスイートを実行する
- **THEN** 初回設定の復元、復元不能時の停止、追加依頼の同一委譲先固定がそれぞれ成功し、既存テストも成功する

#### Scenario: 公開 PR 完走を記録する
- **WHEN** 初回依頼の後に追加依頼を投入した一件を公開 PR の finish/G まで実行する
- **THEN** 実行コマンド、対象 HEAD、追加依頼が同一設定へ委譲された証拠、finish/G の結果を記録する
