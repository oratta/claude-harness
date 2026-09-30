## MODIFIED Requirements

### Requirement: 名前付き設定セットを共通入口で選ぶ
システムは `/develop --profile NAME [--profile-file PATH]` と対応する develop CLI の role resolver を提供しなければならない（MUST）。組み込み名は `codex-standard`、`codex-economy`、`hybrid-standard`、`claude-write-codex-review` とし、各 entry は executor/account/model/effort を持つ。形式版1の JSON は design の厳密な形式を満たし、全 canonical role を網羅しなければならない（MUST）。各 role の executor は `codex` または `claude` とし、同じ profile 内で混在できなければならない（MUST）。profile と旧 account/model の併用を拒否しなければならない（MUST）。組み込み profile の Codex entry の model は、モデル ID ではなく系統名（`astra` / `sol` / `luna`）で書かなければならない（MUST）。

#### Scenario: 二つの Codex 組み込みセットを解決する
- **WHEN** `codex-standard` または `codex-economy` を解決する
- **THEN** spec-write は順に sol/high または luna/medium、spec-review/impl-review/review は sol/high、decider は astra/high、implement は sol/medium または luna/medium、explore/summarize は luna/low に解決する。model の値は系統名そのもの（`sol` / `luna` / `astra`）で、全 entry は executor=codex、account=current となる

#### Scenario: 既存の混在セットを役割ごとに解決する
- **WHEN** `hybrid-standard` で書く役、独立レビュー役、decider、補助役を順に解決する
- **THEN** 各 role は既存 profile に記録された executor/account/model/effort をそのまま返し、Codex が書き Claude が検査する向きを維持する。Codex role の model は系統名で返る

#### Scenario: Claude が書き Codex が検査する組み込みセットを解決する
- **WHEN** `claude-write-codex-review` を解決する
- **THEN** spec-write/implement は claude/current/sonnet/medium、explore/summarize は claude/current/haiku/low、spec-review/impl-review/review は codex/current/sol/high、decider は codex/current/astra/high となる

#### Scenario: 組み込み profile にモデル ID が書かれていない
- **WHEN** `git grep -nE 'gpt-[0-9]' plugins/dev-workflow/references/codex-role-profiles.json` を実行する
- **THEN** 0 件である

#### Scenario: 役割ごとに登録 Codex account を選ぶ
- **WHEN** version=1 の外部 profile-file の Codex 役割に異なる登録 account を指定して解決する
- **THEN** 各 entry の account を保存し、外部ファイルを組み込みと merge せず、各 Codex 委譲は当該 entry の account だけを使う

#### Scenario: 曖昧または不完全な指定を拒否する
- **WHEN** profile と account/model のいずれかを併用する、profile-file のみ指定する、未知版/名前/キー/役割・重複キー・欠落役割・空値・未登録 Codex account・`codex`/`claude` 以外の executor がある
- **THEN** resolver は失敗し、実行可能な request/run/job を作らず、既定値や別 account に置換しない

### Requirement: 明示指定が無い工程では provider の週次余裕から構成を選ぶ
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決し、そのスロットの実効値（`usage-session-records` capability の「記録と snapshot から実効値を求める」。セッション記録と schema 2 snapshot の対応する `accounts` entry から求める）を読まなければならない（MUST）。余裕は reset までの週経過率から週次使用率を引いた未丸め値とし、0 以上を余裕あり、負値または欠測を詰まりとして design の選択表を適用しなければならない（MUST）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude の実効値を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使う。probe がフェッチしなかった・失敗した・timeout した場合も、既存の記録と snapshot から求めた実効値で評価しなければならない（MUST）。

#### Scenario: 両 provider に余裕がある
- **WHEN** Claude margin が +20、最良 Codex margin が +10 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、書く役と補助役は Claude、レビュー役は Codex の系統名 sol、decider は astra に解決する

#### Scenario: Codex が詰まっている
- **WHEN** Claude margin が 0 以上で、最良 Codex margin が -5、欠測、または stale のいずれかである
- **THEN** coordinator の全役割 Claude 既定構成を選ぶ

#### Scenario: Claude だけが詰まっている
- **WHEN** Claude margin が -5 で最良 Codex margin が +30 である
- **THEN** `codex-standard` を選び、全 Codex role を代表 account に束縛する

#### Scenario: 両 provider が詰まっている
- **WHEN** Claude と最良 Codex の margin がともに -5、または双方が欠測である
- **THEN** 既に coordinator が動作している全役割 Claude 既定構成を選ぶ

#### Scenario: 明示 profile は自動選択を迂回する
- **WHEN** `--profile NAME` を明示して工程を開始する
- **THEN** Claude/Codex の snapshot を読み取らず、指定 profile の検証済み role tuple を返す

#### Scenario: 起動 account と snapshot.active が食い違う
- **WHEN** 起動時の `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出したサービス名がスロット A に一致し、schema 2 snapshot の `active` とトップレベルのミラーがスロット B を指す
- **THEN** `usage-account-registry` の優先順位に従ってスロット A の実効値から Claude margin を求め、スロット B のトップレベル値へフォールバックしない

#### Scenario: 使用量 API が 429 を返し続けてもセッション記録で評価する
- **WHEN** profile を明示せず canonical phase を開始し、probe が 429 で snapshot を更新できず、起動 account の鍵のセッション記録が 1 時間前の週次 20%（リセット時刻は現在より後）である
- **THEN** Claude margin をその記録から求め、欠測として扱わない。証跡の `fetched_at` には記録の `observed_at` を載せる
