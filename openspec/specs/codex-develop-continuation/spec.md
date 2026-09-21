# codex-develop-continuation Specification
## Purpose
TBD - created by archiving change codex-develop-continuation-state. Update Purpose after archive.
## Requirements
### Requirement: 継続依頼は初回の Codex 設定を復元する
この要件は run と worker の台帳を持つ経路にのみ適用する（MUST）。Codex executor の初回確定後、coordinator は既存 develop が選択した記録先（issue を優先し、issue が無い場合は Draft PR）に、旧単一設定 run では固定マーカー `<!-- codex-develop-continuation:v1 ... -->` と順序固定の必須キー `executor`、`account`、`model`、`run-dir`、`worker-state`、`cwd` を持つ1行、profile run では `<!-- codex-develop-continuation:v2 ... -->` と順序固定の必須キー `executor`、`profile`、`config-version`、`config-hash`、`run-dir`、`worker-state`、`cwd` を持つ1行の継続記録を保存しなければならない（MUST）。各値は UTF-8 の RFC 3986 パーセントエンコード（`%HH` は大文字）で表し、未知キー・重複キー・空値・改行を含む記録は不正とする。選択した記録先のコメントをコメント ID の降順で調べ、最新候補が不正なら停止、正しい場合は最新候補だけを採用し、古い候補と未選択の記録先は無視しなければならない（MUST）。引数なしの追加依頼では、その記録と run の整合性を検証したうえで同じ Codex executor と run に委譲しなければならない（MUST）。

v2 の config-version は1、config-hash は private run の execution_config の canonical JSON SHA-256 とし、profile/版/hash と既存パス/所有者/権限を照合しなければならない（MUST）。v1 は旧 run、v2 は profile run にのみ適用し、外部 profile ファイルを読み直してはならない（MUST NOT）。profile run の追加依頼は同じ snapshot の当該役割に固定する。

前景実行の経路は run ディレクトリも worker の台帳も持たないので、継続記録を保存してはならず（MUST NOT）、記録先から継続記録を探してもならない（MUST NOT）。前景実行でセッションをまたいだ継続が必要になった場合は、記録先（issue または Draft PR）と作業ディレクトリの現状からその工程をやり直さなければならない（MUST）。

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

#### Scenario: 前景実行の途中でセッションが終わる
- **WHEN** 前景実行で進めていた工程が、セッションの終了によって結果を返さずに終わる
- **THEN** 継続記録は保存も検索もされず、coordinator は記録先と作業ディレクトリの現状からその工程をやり直す

### Requirement: 復元不能時は安全に停止する
この要件は継続記録を持つ経路にのみ適用する（MUST）。継続設定を一意に復元できない場合、coordinator は Claude 実行または別 account/run へ黙って fallback してはならず（MUST NOT）、不足している指定を求めて停止しなければならない（MUST）。前景実行の経路では、復元ではなく工程のやり直しで再開しなければならず（MUST）、そのときも Claude 実行や別アカウントへ黙って倒してはならない（MUST NOT）。

#### Scenario: 記録がない
- **WHEN** executor 未指定の追加依頼に対して継続記録が見つからない
- **THEN** coordinator は停止し、executor と旧 account/model または profile、および run-dir の指定を求める

#### Scenario: 記録が不一致または曖昧
- **WHEN** 最新候補の形式不正、run 不在、または account/model/worker-state/cwd または profile/config-version/config-hash の不一致、v1/v2 と run 形式の不一致がある
- **THEN** coordinator は Codex も Claude も実行せず、検出した不一致を示して指定を求める

#### Scenario: 前景実行で再開する
- **WHEN** 前景実行で止まった工程を再開する
- **THEN** coordinator は継続記録を探さず、同じ役割の設定を解決し直してその工程をやり直し、Claude 実行や別アカウントへ倒さない

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

### Requirement: coordinator と担当者の責務境界を守る
coordinator は記録先の選択、GitHub コメントの取得・保存、LLM ログの取得を担わなければならない（MUST）。継続記録の生成・解析と run の整合性検証は、継続記録を持つ経路でのみ coordinator が担う（MUST）。GitHub 操作と commit/push は、その権限を持つ役（workspace-write role の担当者）が worker の中で自分で完了しなければならない（MUST）。coordinator がこれらを代理してよいのは、capability `codex-worker` の「揃えられなかった項目を項目ごとに記録する」で記録された項目に限る（MUST）。担当者は固定された executor/account/model（台帳経路の run は run-dir、profile run は同一 snapshot の当該役割の executor/account/model/effort、前景実行は依頼ファイルへ固定した当該役割の executor/account/model/effort）による調査・修正・レビューを行い、結果とテスト証跡を返さなければならない（MUST）。coordinator は担当者の調査・修正・レビューを代行してはならない（MUST NOT）。read-only role の担当者は GitHub へ書き込んではならず（MUST NOT）、そのレビュー結果は coordinator が既存書式で代理投稿しなければならない（MUST）。担当者は LLM ログの取得を行ってはならない（MUST NOT）。この境界は Codex 専用の仕様必須・承認台帳・check/archive ゲートを追加してはならない（MUST NOT）。

#### Scenario: 担当者への調査・修正・レビュー委譲
- **WHEN** 初回または追加依頼が調査、修正、レビューを要求する
- **THEN** coordinator は記録された同じ担当へ依頼し、担当者の返却した判断・変更・テスト証跡を受け取る。coordinator 自身はその調査・修正・レビューを実行しない

#### Scenario: 本体が記録と run の整合性を担う
- **WHEN** 継続記録の生成・解析、LLM ログの取得、または run の整合性検証が必要になる
- **THEN** coordinator が許可された範囲で実行する。transport の完了だけでは品質承認・finish/G 合格と扱わない

#### Scenario: 書く役が GitHub 操作と commit/push を自分で行う
- **WHEN** workspace-write role の担当者が commit、push、Draft PR 作成、または記録先へのコメントを必要とする
- **THEN** 担当者が worker の中で自分で完了し、coordinator は代理しない。代理が入るのは、揃えられなかった項目として記録済みの操作だけである

#### Scenario: 読む役のレビュー結果を投稿する
- **WHEN** read-only role の担当者がレビュー結果を返す
- **THEN** 担当者は GitHub へ書き込まず、coordinator が既存書式で代理投稿する。投稿成功前に後続実装・完了扱いとしない

#### Scenario: 前景実行では run の整合性検証が発生しない
- **WHEN** 前景実行で委譲を行う
- **THEN** coordinator は継続記録の生成・解析と run の整合性検証を行わず、記録先の選択・コメントの取得と保存・LLM ログの取得は従来どおり担う

