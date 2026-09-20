## MODIFIED Requirements

### Requirement: 継続依頼は初回の Codex 設定を復元する
Codex executor の初回確定後、coordinator は既存 develop が選択した記録先（issue を優先し、issue が無い場合は Draft PR）に、旧単一設定 run では固定マーカー `<!-- codex-develop-continuation:v1 ... -->` と順序固定の必須キー `executor`、`account`、`model`、`run-dir`、`worker-state`、`cwd` を持つ1行、profile run では `<!-- codex-develop-continuation:v2 ... -->` と順序固定の必須キー `executor`、`profile`、`config-version`、`config-hash`、`run-dir`、`worker-state`、`cwd` を持つ1行の継続記録を保存しなければならない（MUST）。各値は UTF-8 の RFC 3986 パーセントエンコード（`%HH` は大文字）で表し、未知キー・重複キー・空値・改行を含む記録は不正とする。選択した記録先のコメントをコメント ID の降順で調べ、最新候補が不正なら停止、正しい場合は最新候補だけを採用し、古い候補と未選択の記録先は無視しなければならない（MUST）。引数なしの追加依頼では、その記録と run の整合性を検証したうえで同じ Codex executor と run に委譲しなければならない（MUST）。

v2 の config-version は1、config-hash は private run の execution_config の canonical JSON SHA-256 とし、profile/版/hash と既存パス/所有者/権限を照合しなければならない（MUST）。v1 は旧 run、v2 は profile run にのみ適用し、外部 profile ファイルを読み直してはならない（MUST NOT）。profile run の追加依頼は同じ snapshot の当該役割に固定する。

#### Scenario: 初回設定から追加依頼を復元する
- **WHEN** 記録先に `executor codex`、account、model、run-dir、worker-state が一意に記録され、保存済み run の固定値と一致した状態で追加依頼が来る
- **THEN** coordinator はオプション再指定なしで同じ run・account・model を使い、worker-state と cwd の保持・検証結果が一致することを確認して、追加依頼を Codex 担当へ委譲する

#### Scenario: 追加依頼でも担当を変更しない
- **WHEN** 初回と同じ会話で調査・修正・レビューの追加依頼が来る
- **THEN** coordinator は旧 run では記録された executor/account/model/run-dir、profile run では記録に一致する snapshot の当該役割の設定を使い、Claude 本体が調査・原因判断・コード修正を代行しない

#### Scenario: 記録形式と重複候補を fixture で判定する
- **WHEN** fixture に、予約文字をエンコードした正しい最新記録、古い正しい記録、未知キーを含む記録、重複キーを含む記録、issue と Draft PR の記録を与える
- **THEN** coordinator は選択済み記録先の最新で正しい 1 件だけを採用し、値を復号して v1 の必須6フィールドまたは v2 の必須7フィールドを得て、未知キー・重複キー・不正な最新記録では停止する

#### Scenario: profile を追加依頼へ引き継ぐ
- **WHEN** v2 の profile/config-version/config-hash と run の snapshot、パス、所有者/0700 が一致する
- **THEN** 同じ run と全役割の解決済み設定を復元し、外部設定の変更/削除は結果に影響しない

#### Scenario: v1 と v2 の候補が混在する
- **WHEN** 選択した記録先に旧 v1 と新 v2 または未知版の候補がある
- **THEN** 版にかかわらず最新コメントの一意な候補を選び、最新が不正/未知版なら停止して古い v1 に戻らない

### Requirement: 復元不能時は安全に停止する
継続設定を一意に復元できない場合、coordinator は Claude 実行または別 account/run へ黙って fallback してはならず（MUST NOT）、不足している指定を求めて停止しなければならない（MUST）。

#### Scenario: 記録がない
- **WHEN** executor 未指定の追加依頼に対して継続記録が見つからない
- **THEN** coordinator は停止し、executor と旧 account/model または profile、および run-dir の指定を求める

#### Scenario: 記録が不一致または曖昧
- **WHEN** 最新候補の形式不正、run 不在、または account/model/worker-state/cwd または profile/config-version/config-hash の不一致、v1/v2 と run 形式の不一致がある
- **THEN** coordinator は Codex も Claude も実行せず、検出した不一致を示して指定を求める

### Requirement: coordinator と担当者の責務境界を守る
coordinator は記録先の選択、GitHub コメントの取得・保存、LLM ログの取得、run の整合性検証、GitHub 操作、および worker が実行できない場合の commit/push の代理を担わなければならない（MUST）。担当者は固定された executor/account/model/run-dir（profile run は同一 snapshot の当該役割の executor/account/model/effort） による調査・修正・レビューを行い、結果とテスト証跡を返さなければならない（MUST）。coordinator は担当者の調査・修正・レビューを代行してはならず（MUST NOT）、担当者は GitHub 操作・ログ取得を行ってはならない（MUST NOT）。この境界は Codex 専用の仕様必須・承認台帳・check/archive ゲートを追加してはならない（MUST NOT）。

#### Scenario: 担当者への調査・修正・レビュー委譲
- **WHEN** 初回または追加依頼が調査、修正、レビューを要求する
- **THEN** coordinator は記録された同じ担当へ依頼し、担当者の返却した判断・変更・テスト証跡を受け取る。coordinator 自身はその調査・修正・レビューを実行しない

#### Scenario: 本体が記録・操作・代理 transport を担う
- **WHEN** 継続記録、LLM ログ、GitHub コメント、commit、または push の操作が必要になる
- **THEN** coordinator が許可された範囲で実行または worker の失敗時に代理し、担当者は GitHub やログの操作を実行しない。transport の完了だけでは品質承認・finish/G 合格と扱わない
