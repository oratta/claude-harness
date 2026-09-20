# manual-codex-develop Specification

## Purpose
TBD - created by archiving change codex-develop-role-profiles. Update Purpose after archive.
## Requirements
### Requirement: 手動で実行先とアカウントを固定する
手動Codex開発は旧形式の登録account/model、または名前付きprofileの役割別executor/account/model/effortをinitで固定し、共通App Server workerだけに委譲しなければならない（MUST）。profileと旧account/modelの同時指定を拒否し、worker失敗時にexec/Claudeへfallbackしてはならない（MUST NOT）。

#### Scenario: 旧形式の手動依頼
- **WHEN** 人間がCodexと単一の登録account/modelを指定する
- **THEN** burn窓を要求せず同account/modelで全委譲を行い、effortを後付けしない

#### Scenario: 設定セットの手動依頼
- **WHEN** 人間がCodexとprofileを指定する
- **THEN** burn窓を要求せずinitの役割別snapshotを固定し、各委譲は該当役割のaccount/model/effortだけを使う

### Requirement: 品質工程を維持する
工程管理はdevelopの正本を使用し、W/R1/G/追加レビュアー/deciderの全役割をCodexへ委譲しなければならない（MUST）。レビューは別threadかつread-onlyでなければならない（MUST）。

#### Scenario: 仕様に差し戻し
- **WHEN** 独立仕様レビューが修正を要求する
- **THEN** Claudeが正本の回数上限を確認し、Codex作業者へ修正を委譲する

#### Scenario: 既存CLI経路に到達する
- **WHEN** CodexモードでGが別レビューを要求する
- **THEN** ClaudeがApp Serverの新しいread-only依頼を作り、codex execやClaude reviewerを呼ばない

### Requirement: provider指定で品質ワークフローを分岐させない
仕様要否・レビュー・検証・工程順序は既存developの正本に一元化しなければならない（MUST）。Codex adapterは起動・状態確認・結果回収・中断・実行先とownershipの管理を担当し、独自の仕様必須条件や品質ゲートを設けてはならない（MUST NOT）。phaseは役割指示選択ラベルであり工程順序の強制ではない。

#### Scenario: 仕様不要の通常判断
- **WHEN** Wが既存developに従い仕様化判断をしないと理由付きで返す
- **THEN** 本体はその記録を使って既存developの実装工程へ進み、Codex adapterは仕様artifactやR1承認を追加要求しない

#### Scenario: 仕様が必要な通常判断
- **WHEN** Wが既存developに従い仕様化すると判断する
- **THEN** 本体は正本の仕様作成・R1レビュー・承認条件を適用し、adapterは指示された役割をCodexへ委譲する

#### Scenario: 既存の検証で失敗する
- **WHEN** 正本が要求する検証で失敗する
- **THEN** 本体と担当役割は既存developの差戻し規則に従い、adapterに別の検証手順や承認台帳を作らない

### Requirement: 輸送結果を品質承認にしない
workerのcompletedやackを品質合格として扱ってはならない（MUST NOT）。本体は最終回答とerror_kindを確認して既存developのレビュー記録/判断契約へ渡さなければならない（MUST）。workerの認証・ownership・read-only・unknown時再実行禁止は維持しなければならない（MUST）。

#### Scenario: 途中APPROVEと最終差戻し
- **WHEN** commentaryにAPPROVEがあり最終回答はREQUEST_CHANGESである
- **THEN** workerは最終回答を回収し、本体は既存レビュー契約で差戻しを扱う

#### Scenario: 実行エラーを伴う結果
- **WHEN** 結果に認証変更や未対応要求のerror_kindがある
- **THEN** 本体は品質承認として記録せず、実行失敗として扱う

### Requirement: 保存依頼のまま送信を復旧する
送信到達が不明なpendingは、保存requestのrequest_id/cwd/roleとpendingに固定したexecutor/account/model/effortおよびpayload hashが一致する場合に限り同じ依頼をidempotent submitできなければならない（MUST）。旧run/pendingは単一account/modelとeffort省略を読み取り互換で扱い、既存payload/hashを変更してはならない（MUST NOT）。retry時にpromptを再生成したり新しいrequest_idを割り当ててはならない（MUST NOT）。

#### Scenario: 旧版pendingが送信前に失敗した
- **WHEN** 保存済みrequestがありworkerに結果が存在するか不明な旧runでretryする
- **THEN** 旧identity情報の一致を確認して元のrequestをそのまま送信し、effortや設定版を後付けせず旧品質metadataを工程条件にしない

#### Scenario: 結果が既に存在する
- **WHEN** 同じrequest_idの結果がworkerに保存済みである
- **THEN** 同一ジョブを回収し、重複実行せず受領後にackできる。ただしunknownのack/置換は禁止する

#### Scenario: 保存依頼のaccountが一致しない
- **WHEN** 保存requestの固定設定がpendingの当該役割と一致しない（旧runは旧account/model/cwd/request_idの不一致）
- **THEN** retryを拒否し、依頼を再生成して別ジョブとして送らない

#### Scenario: 役割によって設定が異なる
- **WHEN** profile run のレビュー役が作業役とは異なるaccount/model/effortを持つ
- **THEN** retryはレビューpendingの固定値を照合し、run全体の単一account/modelを要求しない

