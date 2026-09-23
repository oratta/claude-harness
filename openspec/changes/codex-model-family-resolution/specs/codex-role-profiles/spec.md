## MODIFIED Requirements

### Requirement: 名前付き設定セットを共通入口で選ぶ
システムは `/develop --profile NAME [--profile-file PATH]` と対応する develop CLI の role resolver を提供しなければならない（MUST）。組み込み名は `codex-standard`、`codex-economy`、`hybrid-standard`、`claude-write-codex-review` とし、各 entry は executor/account/model/effort を持つ。形式版1の JSON は design の厳密な形式を満たし、全 canonical role を網羅しなければならない（MUST）。各 role の executor は `codex` または `claude` とし、同じ profile 内で混在できなければならない（MUST）。profile と旧 account/model の併用を拒否しなければならない（MUST）。組み込み profile の Codex entry の model は、モデル ID ではなく系統名（`astra` / `sol` / `luna`）で書かなければならない（MUST）。

#### Scenario: 二つの Codex 組み込みセットを解決する
- **WHEN** `codex-standard` または `codex-economy` を解決する
- **THEN** spec-write は順に sol/high または luna/medium、spec-review/impl-review/review/decider は astra/high、implement は sol/medium または luna/medium、explore/summarize は luna/low に解決する。model の値は系統名そのもの（`sol` / `luna` / `astra`）で、全 entry は executor=codex、account=current となる

#### Scenario: 既存の混在セットを役割ごとに解決する
- **WHEN** `hybrid-standard` で書く役、独立レビュー役、decider、補助役を順に解決する
- **THEN** 各 role は既存 profile に記録された executor/account/model/effort をそのまま返し、Codex が書き Claude が検査する向きを維持する。Codex role の model は系統名で返る

#### Scenario: Claude が書き Codex が検査する組み込みセットを解決する
- **WHEN** `claude-write-codex-review` を解決する
- **THEN** spec-write/implement は claude/current/sonnet/medium、explore/summarize は claude/current/haiku/low、spec-review/impl-review/review/decider は codex/current/astra/high となる

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
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決し、schema 2 snapshot の対応する `accounts` entry を読まなければならない（MUST）。余裕は reset までの週経過率から週次使用率を引いた未丸め値とし、0 以上を余裕あり、負値または欠測を詰まりとして design の選択表を適用しなければならない（MUST）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude snapshot を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使い、probe が失敗または timeout した場合も既存 snapshot に対する 300 秒の freshness 検証を維持しなければならない（MUST）。

#### Scenario: 両 provider に余裕がある
- **WHEN** Claude margin が +20、最良 Codex margin が +10 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、書く役と補助役は Claude、レビュー役と decider は Codex の系統名 astra に解決する

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
- **THEN** `usage-account-registry` の優先順位に従ってスロット A の `accounts[A]` から Claude margin を求め、スロット B のトップレベル値へフォールバックしない

#### Scenario: 工程開始時に Claude snapshot を更新する
- **WHEN** profile を明示せず canonical phase を開始し、既存 Claude snapshot が 301 秒以上古い
- **THEN** 同梱 probe を有限時間で実行して同じ `USAGE_SNAPSHOT` を再読込し、probe が更新できた値を評価する。probe が更新できなければ古い値を欠測として扱う

## ADDED Requirements

### Requirement: Codex entry の model は系統名か完全なモデル ID で書ける
Codex entry の model は、系統名（英小文字だけからなる値。例: `astra` / `sol` / `luna`）と完全なモデル ID（それ以外の値。例: `gpt-6-sol`）のどちらでもよく、resolver は値を変換せずにそのまま request の model に写さなければならない（MUST）。外部 profile-file と旧形式 `--model` は、版を固定したい利用者のために完全なモデル ID を従来どおり受け付けなければならない（MUST）。系統名から実際のモデル ID への解決は resolver で行ってはならず（MUST NOT）、Codex worker が委譲の直前に行う（`codex-worker` capability）。develop 本体は Codex 委譲の結果を記録先に書くとき、要求した model の値と worker が返した解決後のモデル ID の両方を書かなければならない（MUST）。

#### Scenario: 外部 profile-file に系統名と完全 ID を混ぜる
- **WHEN** version=1 の外部 profile-file で、ある Codex role の model を `sol`、別の Codex role の model を `gpt-5.6-sol` として request を作る
- **THEN** 両方とも検証を通り、各 request の model はそれぞれ `sol` と `gpt-5.6-sol` のまま書かれる

#### Scenario: 旧形式で系統名と完全 ID を指定する
- **WHEN** 旧形式 `--account NAME --model sol`、または `--account NAME --model gpt-6-astra` で request を作る
- **THEN** どちらも拒否されず、request の model は指定した値のままになる

#### Scenario: 解決後の ID を記録先に残す
- **WHEN** model=sol の Codex role を委譲し、worker の結果 JSON の `execution.model_resolution` が requested=sol、resolved=gpt-6-sol を返す
- **THEN** develop 本体の記録先コメントには要求値 `sol` と解決後の ID `gpt-6-sol` の両方が書かれ、どの ID で走ったかが後から追える
