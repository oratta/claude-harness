## MODIFIED Requirements

### Requirement: 名前付き設定セットを共通入口で選ぶ
システムは `/develop --profile NAME [--profile-file PATH]` と対応する develop CLI の role resolver を提供しなければならない（MUST）。組み込み名は `codex-standard`、`codex-economy`、`hybrid-standard` とし、各 entry は executor/account/model/effort を持つ。形式版1の JSON は design の厳密な形式を満たし、全 canonical role を網羅しなければならない（MUST）。各 role の executor は `codex` または `claude` とし、同じ profile 内で混在できなければならない（MUST）。profile と旧 account/model の併用を拒否しなければならない（MUST）。

#### Scenario: 二つの Codex 組み込みセットを解決する
- **WHEN** `codex-standard` または `codex-economy` を解決する
- **THEN** spec-write は順に sol/high または luna/medium、spec-review/impl-review/review/decider は astra/high、implement は sol/medium または luna/medium、explore/summarize は luna/low に解決する。正式モデル名は design の表の値と一致し、全 entry は executor=codex、account=current となる

#### Scenario: 混在する組み込みセットを役割ごとに解決する
- **WHEN** `hybrid-standard` で書く役、独立レビュー役、decider、補助役を順に解決する
- **THEN** 各 role は profile に記録された executor/account/model/effort をそのまま返し、Codex の role と Claude の role が同じ profile から選ばれる

#### Scenario: 役割ごとに登録 Codex account を選ぶ
- **WHEN** version=1 の外部 profile-file の Codex 役割に異なる登録 account を指定して解決する
- **THEN** 各 entry の account を保存し、外部ファイルを組み込みと merge せず、各 Codex 委譲は当該 entry の account だけを使う

#### Scenario: 曖昧または不完全な指定を拒否する
- **WHEN** profile と account/model のいずれかを併用する、profile-file のみ指定する、未知版/名前/キー/役割・重複キー・欠落役割・空値・未登録 Codex account・`codex`/`claude` 以外の executor がある
- **THEN** resolver は失敗し、実行可能な request/run/job を作らず、既定値や別 account に置換しない

## ADDED Requirements

### Requirement: executor ごとの role 設定を検証する
Version 1 profile の検証は executor を discriminator として行わなければならない（MUST）。`codex` entry は登録済み account を要求し、model/effort を非空文字列として保持する。`claude` entry は account=`current` と model=`haiku|sonnet|opus|fable` を要求し、`fable` は role=`decider` にだけ許可しなければならない（MUST）。Claude entry の effort は必須の非空文字列として解決結果に保持するが Agent 呼び出しへ渡してはならない（MUST NOT）。

#### Scenario: 有効な Claude role を解決する
- **WHEN** account=current、model=opus、非空 effort の Claude review role を解決する
- **THEN** executor/account/model/effort を欠落なく返し、Codex model への変換を行わない

#### Scenario: 残量モードは resolver の要求 tuple を変更しない
- **WHEN** model=fable の Claude decider role を、`FABLE_BUDGET_MODE=exhausted` または `SHARED_BUDGET_MODE=depleted` の環境で解決する
- **THEN** resolver は model=fable を含む profile の executor/account/model/effort をそのまま返し、Agent 起動時の上限適用を resolver 内で先取りしない

#### Scenario: 未対応の Claude account を拒否する
- **WHEN** Claude role の account が current 以外である
- **THEN** 別 Claude account の実行は未対応だと分かるエラーで profile 全体を拒否し、欄そのものを欠落扱いにしない

#### Scenario: Claude model と Fable role 制約を検証する
- **WHEN** Claude tier 以外の model、または decider 以外の role に model=fable を指定する
- **THEN** profile 全体を拒否し、Agent も Codex worker も起動しない

#### Scenario: 未知 executor を拒否する
- **WHEN** executor が codex と claude のどちらでもない
- **THEN** profile 全体を拒否し、別 executor や既定 executor に置換しない
