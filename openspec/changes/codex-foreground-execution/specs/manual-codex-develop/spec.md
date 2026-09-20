## ADDED Requirements

### Requirement: 委譲は前景実行の 3 手順で行う
手動Codex開発のadapter手順書は、1 回の委譲を「その工程に限定した指示をUTF-8ファイルに書く → 前景実行のコマンドを背景実行で起動する → 完了通知で結果の JSON を読む」の 3 手順として記述しなければならない（MUST）。手順書に受領（`ack`）・送信復旧（`retry`）・run ディレクトリ・worker の台帳ディレクトリ・継続記録の操作を残してはならない（MUST NOT）。停止は起動したコマンドの停止操作で行い、Codex 専用の中断コマンドを手順書の通常経路に置いてはならない（MUST NOT）。委譲ごとに新しいスレッドを使い、前工程の成果物と必要な要約だけを引き継がなければならない（MUST）。

#### Scenario: 手順書から台帳経路の操作が消えている
- **WHEN** adapter の手順書を機械的に検索する
- **THEN** 受領・送信復旧・run ディレクトリ・worker の台帳ディレクトリ・継続記録を指す語がいずれも見つからない

#### Scenario: 1 件の委譲を行う
- **WHEN** 本体が次の役割と工程を決めて委譲する
- **THEN** 指示をファイルに書き、前景実行を背景で起動し、完了通知で結果の JSON を読む 3 手順で完了し、状態照会と受領の操作を行わない

#### Scenario: 走行中の委譲を止める
- **WHEN** 本体が走行中の委譲を止める必要がある
- **THEN** 起動したコマンドを停止させることで止め、Codex 側に別の中断コマンドを要求しない

## MODIFIED Requirements

### Requirement: 手動で実行先とアカウントを固定する
手動Codex開発は旧形式の登録account/model、または名前付きprofileの役割別executor/account/model/effortを固定し、共通App Server workerだけに委譲しなければならない（MUST）。前景実行では固定は委譲ごとの解決として行い、解決した役割別のexecutor/account/model/effortと実行アカウントのCODEX_HOMEを依頼ファイルへ載せなければならない（MUST）。台帳経路では従来どおりinitのsnapshotで固定する（MUST）。profileと旧account/modelの同時指定を拒否し、worker失敗時にexec/Claudeへfallbackしてはならない（MUST NOT）。前景実行はアカウント名からCODEX_HOMEを解決するために台帳を読んではならず（MUST NOT）、どのCODEX_HOMEを使うかは呼び出し側の責任である。

#### Scenario: 旧形式の手動依頼
- **WHEN** 人間がCodexと単一の登録account/modelを指定する
- **THEN** burn窓を要求せず同account/modelで全委譲を行い、effortを後付けしない

#### Scenario: 設定セットの手動依頼
- **WHEN** 人間がCodexとprofileを指定する
- **THEN** burn窓を要求せず役割別の設定を固定し、各委譲は該当役割のaccount/model/effortだけを使う

#### Scenario: 前景実行で役割別の設定を解決する
- **WHEN** 前景実行で1件の委譲を組み立てる
- **THEN** その役割のexecutor/account/model/effortを解決して依頼ファイルへ固定し、実行アカウントのCODEX_HOMEを同じ依頼に載せ、他の役割の設定を持ち込まない

### Requirement: provider指定で品質ワークフローを分岐させない
仕様要否・レビュー・検証・工程順序は既存developの正本に一元化しなければならない（MUST）。Codex adapterは起動・停止・結果の受け取りと、台帳経路に限った状態確認・結果回収・実行先とownershipの管理を担当し、独自の仕様必須条件や品質ゲートを設けてはならない（MUST NOT）。前景実行では状態確認・結果回収・ownershipの管理は発生せず、adapterが担うのは起動・停止・結果の受け取りだけである。phaseは役割指示選択ラベルであり工程順序の強制ではない。

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
workerのcompletedやackを品質合格として扱ってはならない（MUST NOT）。本体は最終回答とerror_kindを確認して既存developのレビュー記録/判断契約へ渡さなければならない（MUST）。workerの認証とread-onlyの強制は経路によらず維持しなければならない（MUST）。ownershipとunknown時再実行禁止は台帳経路の要件として維持しなければならない（MUST）。前景実行はownershipを持たず、結果が不明な委譲はその工程をやり直す（MUST）。

#### Scenario: 途中APPROVEと最終差戻し
- **WHEN** commentaryにAPPROVEがあり最終回答はREQUEST_CHANGESである
- **THEN** workerは最終回答を回収し、本体は既存レビュー契約で差戻しを扱う

#### Scenario: 実行エラーを伴う結果
- **WHEN** 結果に認証変更や未対応要求のerror_kindがある
- **THEN** 本体は品質承認として記録せず、実行失敗として扱う

#### Scenario: 前景実行の結果が得られないまま終わる
- **WHEN** 前景実行が結果のJSONを返す前に終了する
- **THEN** 本体は同じ依頼を再送せず、記録先と作業ディレクトリを見てその工程をやり直す

### Requirement: 保存依頼のまま送信を復旧する
この要件は台帳経路にのみ適用する（MUST）。送信到達が不明なpendingは、保存requestのrequest_id/cwd/roleとpendingに固定したexecutor/account/model/effortおよびpayload hashが一致する場合に限り同じ依頼をidempotent submitできなければならない（MUST）。旧run/pendingは単一account/modelとeffort省略を読み取り互換で扱い、既存payload/hashを変更してはならない（MUST NOT）。retry時にpromptを再生成したり新しいrequest_idを割り当ててはならない（MUST NOT）。前景実行はpendingを保存しないので、この復旧経路を持ってはならない（MUST NOT）。

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

#### Scenario: 前景実行で送信到達が不明になる
- **WHEN** 前景実行が結果を返さずに終わり、ターンが始まったかどうかが分からない
- **THEN** 保存された依頼からの再送は行わず、その工程をやり直す
