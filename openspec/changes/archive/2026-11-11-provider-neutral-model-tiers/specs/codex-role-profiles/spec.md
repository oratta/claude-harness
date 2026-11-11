## RENAMED Requirements

- FROM: `### Requirement: Codex entry の model は系統名か完全なモデル ID で書ける`
- TO: `### Requirement: Codex の model は系統名か完全なモデル ID で受け付ける`

## MODIFIED Requirements

### Requirement: 名前付き設定セットを共通入口で選ぶ
システムは `/develop --profile NAME [--profile-file PATH]` と対応する develop CLI の role resolver を提供しなければならない（MUST）。組み込み名は `codex-standard`、`codex-economy`、`hybrid-standard`、`claude-write-codex-review`、`claude-default` とし、各 entry は executor/account/effort と任意の `tier_cap` を持ち、model を持ってはならない（MUST NOT）。形式版 2 の JSON は design の厳密な形式を満たし、全 canonical role を網羅しなければならない（MUST）。形式版 1 の profile は組み込み・外部とも拒否しなければならない（MUST）。各 role の executor は `codex` または `claude` とし、同じ profile 内で混在できなければならない（MUST）。profile と旧 account/model の併用を拒否しなければならない（MUST）。resolver の model は `model-tier-resolution` の格と対応表から決めなければならない（MUST）。

#### Scenario: 二つの Codex 組み込みセットを解決する
- **WHEN** `FABLE_BUDGET_MODE=conserve`、`SHARED_BUDGET_MODE=ok` で `codex-standard` または `codex-economy` を入力なしで解決する
- **THEN** spec-write は順に sol/high または luna/medium、spec-review/impl-review/review は sol/high、decider は astra/high、implement は sol/medium または luna/medium、explore/summarize は luna/low に解決する。model の値は系統名そのもの（`sol` / `luna` / `astra`）で、全 entry は executor=codex、account=current となる

#### Scenario: 既存の混在セットを役割ごとに解決する
- **WHEN** `FABLE_BUDGET_MODE=conserve`、`SHARED_BUDGET_MODE=ok` で `hybrid-standard` の書く役、独立レビュー役、decider、補助役を順に入力なしで解決する
- **THEN** 順に codex/sol、claude/opus、claude/fable、codex/luna に解決し、Codex が書き Claude が検査する向きを維持する。Codex role の model は系統名で返る

#### Scenario: Claude が書き Codex が検査する組み込みセットを解決する
- **WHEN** `FABLE_BUDGET_MODE=conserve`、`SHARED_BUDGET_MODE=ok` で `claude-write-codex-review` を入力なしで解決する
- **THEN** spec-write/implement は claude/current/sonnet/medium、explore/summarize は claude/current/haiku/low、spec-review/impl-review/review は codex/current/sol/high、decider は codex/current/astra/high となる

#### Scenario: claude-default を組み込みセットとして解決する
- **WHEN** `--profile claude-default` を account-home なしで入力なしのまま解決する
- **THEN** 全 role が executor=claude、account=current で、model は自動選択の Claude 既定構成と同じ値になる

#### Scenario: 節約の構成は格の上限で表す
- **WHEN** 組み込み profile の `tier_cap` を読む
- **THEN** `codex-economy` の spec-write と implement だけが `tier_cap: 最安` を持つ

#### Scenario: 組み込み profile にモデル ID が書かれていない
- **WHEN** 組み込み profile の全 entry を走査し、`git grep -nE 'gpt-[0-9]' plugins/dev-workflow/references/codex-role-profiles.json` を実行する
- **THEN** どの entry にも `model` キーが無く、grep は 0 件である

#### Scenario: 役割ごとに登録 Codex account を選ぶ
- **WHEN** version=2 の外部 profile-file の Codex 役割に異なる登録 account を指定して解決する
- **THEN** 各 entry の account を保存し、外部ファイルを組み込みと merge せず、各 Codex 委譲は当該 entry の account だけを使う

#### Scenario: 曖昧または不完全な指定を拒否する
- **WHEN** profile と account/model のいずれかを併用する、profile-file のみ指定する、未知版/version 1/名前/キー/役割・重複キー・欠落役割・空値・`model` キー・未定義の `tier_cap`・未登録 Codex account・`codex`/`claude` 以外の executor がある
- **THEN** resolver は失敗し、実行可能な request/run/job を作らず、既定値や別 account に置換しない

### Requirement: executor ごとの role 設定を検証する
形式版 2 の profile の検証は executor を discriminator として行わなければならない（MUST）。`codex` entry は登録済み account と非空の effort を要求する。`claude` entry は account=`current` と非空の effort を要求しなければならない（MUST）。どちらの entry も model を持ってはならず（MUST NOT）、`tier_cap` は持つなら 4 格のどれかでなければならない（MUST）。Claude entry の effort は必須の非空文字列として解決結果に保持するが Agent 呼び出しへ渡してはならない（MUST NOT）。

**守備範囲（profile の検証）**: ①入力の出どころは、組み込みの JSON と利用者の `--profile-file` である。②拾いたい誤りは、`model` キーの残存（形式版 1 の書き換え漏れ）・未定義の `tier_cap`・空値である。③通してよい入力は、`tier_cap` の無い entry と claude entry の `tier_cap` である。account の実在は Codex だけ検査する。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: 有効な Claude role を解決する
- **WHEN** account=current、非空 effort の Claude review role を解決する
- **THEN** executor/account/effort と格から引いた model を欠落なく返す

#### Scenario: 残量モードは resolver の要求 tuple を変更しない
- **WHEN** Claude decider role を、`FABLE_BUDGET_MODE=exhausted` または `SHARED_BUDGET_MODE=depleted` の環境で解決する
- **THEN** 結果の `requested_model` は `fable` のままで、`model` にだけ上限が適用される。結果の `execution_config` の entry と `execution_config_hash` は残量モードで変わらない

#### Scenario: 未対応の Claude account を拒否する
- **WHEN** Claude role の account が current 以外である
- **THEN** 別 Claude account の実行は未対応だと分かるエラーで profile 全体を拒否し、欄そのものを欠落扱いにしない

#### Scenario: Claude model と Fable role 制約を検証する
- **WHEN** executor を問わず entry が `model` キーを持つ
- **THEN** profile 全体を拒否し、Agent も Codex worker も起動しない。最上位の格になる role は decider だけなので、`fable` が decider 以外に渡る経路は無い

#### Scenario: 未知 executor を拒否する
- **WHEN** executor が codex と claude のどちらでもない
- **THEN** profile 全体を拒否し、別 executor や既定 executor に置換しない

### Requirement: 明示指定が無い工程では provider の週次余裕から構成を選ぶ
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決しなければならない（MUST）。余裕（margin）は `dev-workflow-headroom` capability の行の `margin`（週の経過率 − 週次の使用率の未丸め値）を使わなければならない（MUST）: Claude は `headroom.claude_rows(now, snapshot_path)` の起動 account の行、Codex は `read_codex_usages` が認証の主体を照合した各 account の cache を `headroom.codex_row(account, cache, now)` に渡した行で、行の `status` が `ok` のときだけその `margin` を使い、それ以外は欠測とする。起動 account がオフ（`enabled: false`）のスロットなら行は `off` で、Claude の margin は欠測になる。resolver は経過率と使用率から margin を数え直してはならない（MUST NOT）。0 以上を余裕あり、負値または欠測を詰まりとして design の選択表を適用しなければならない（MUST）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

headroom の設定（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`）が不正で行を数えられないときは、自動選択を欠測として進めてはならず（MUST NOT）、`{"status": "blocked", "error": <設定の名前を含む文>}` を出して終了コード 2 で止まらなければならない（MUST）。

**守備範囲（headroom の設定の不正で止める判定）**: ①入力の出どころは、develop を起動した利用者の環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` だけで、値の検査は headroom（`dev-workflow-headroom` の要件「設定は headroom の中で 1 か所から解決する」）が行い、resolver はその例外を `blocked` に写す。Claude の実効値と Codex の cache を欠測にする判定は要件「snapshot の鮮度と週次窓を fail-safe に検証する」の守備範囲に従う。②拾いたい誤りは、数でない・0〜100 の外の設定値が「余りが無い」に見えて構成選択が黙って Claude 既定に倒れることである。③通してよい入力は、未設定・空文字（既定値で数える）、0 と 100 ちょうど、小数の値である。margin は天井とペースによらないので、値が利用者の意図と違っても範囲内なら構成選択は変わらず、検知しない。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude の実効値を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使う。probe がフェッチしなかった・失敗した・timeout した場合も、既存の記録と snapshot から求めた実効値で評価しなければならない（MUST）。

#### Scenario: 両 provider に余裕がある
- **WHEN** Claude margin が +20、最良 Codex margin が +10 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、書く役と補助役は Claude、レビュー役は Codex の系統名 sol、decider は astra に解決する

#### Scenario: Codex が詰まっている
- **WHEN** Claude margin が 0 以上で、最良 Codex margin が負値または欠測である
- **THEN** coordinator の全役割 Claude 既定構成を選ぶ

#### Scenario: Claude だけが詰まっている
- **WHEN** Claude margin が -5 で最良 Codex margin が +30 である
- **THEN** `codex-standard` を選び、全 Codex role を代表 account に束縛する

#### Scenario: 両 provider が詰まっている
- **WHEN** Claude と最良 Codex の margin がともに -5、または双方が欠測である
- **THEN** 既に coordinator が動作している全役割 Claude 既定構成を選ぶ

#### Scenario: 明示 profile は自動選択を迂回する
- **WHEN** `--profile NAME` を明示して工程を開始する
- **THEN** 構成の選択には Claude/Codex の snapshot を使わず、usage probe も実行せず、指定 profile の検証済み role 設定を返す。残量モードの導出には `model-tier-resolution` のとおり Claude の実効値を読む

#### Scenario: 起動 account と snapshot.active が食い違う
- **WHEN** 起動時の `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出したサービス名がスロット A に一致し、schema 2 snapshot の `active` とトップレベルのミラーがスロット B を指す
- **THEN** `usage-account-registry` の優先順位に従ってスロット A の headroom の行から Claude margin を取り、スロット B のトップレベル値へフォールバックしない

#### Scenario: 使用量 API が 429 を返し続けてもセッション記録で評価する
- **WHEN** profile を明示せず canonical phase を開始し、probe が 429 で snapshot を更新できず、起動 account の鍵のセッション記録が 1 時間前の週次 20%（リセット時刻は現在より後）である
- **THEN** Claude margin をその記録から数えた headroom の行から取り、欠測として扱わない。証跡の `fetched_at` には記録の `observed_at` を載せる

#### Scenario: margin は headroom の行から取る
- **WHEN** `headroom.claude_rows` と `headroom.codex_row` が、週の経過率と使用率からは出ない margin（Claude 12.345・Codex 6.789）を持つ `status: ok` の行を返すようにして自動選択する
- **THEN** 証跡の Claude margin が 12.345、Codex margin が 6.789 になり、`claude-write-codex-review` を選ぶ

#### Scenario: headroom の設定が不正なら止まる
- **WHEN** `HEADROOM_7D_CAP_PCT` が `abc` で profile を明示せず工程を開始する
- **THEN** 構成を選ばず、`status: blocked` と `HEADROOM_7D_CAP_PCT` を含むエラーを出して終了コード 2 で終わる

### Requirement: Codex の model は系統名か完全なモデル ID で受け付ける
対応表の Codex の値は系統名（英小文字だけからなる値。例: `astra` / `sol` / `luna`）で書かなければならない（MUST）。旧形式 `--model` は、版を固定したい利用者のために系統名と完全なモデル ID（それ以外の値。例: `gpt-6-sol`）のどちらも従来どおり受け付けなければならない（MUST）。resolver は値を変換せずにそのまま request の model に写し、旧形式の model に対する静的検証は非空文字列であることだけとする（実在しない値は worker が解決時に止める）。系統名から実際のモデル ID への解決は resolver で行ってはならず（MUST NOT）、Codex worker が委譲の直前に行う（`codex-worker` capability）。develop 本体は Codex 委譲の結果を記録先に書くとき、要求した model の値と worker が返した解決後のモデル ID の両方を書かなければならない（MUST）。

#### Scenario: 外部 profile-file に系統名と完全 ID を混ぜる
- **WHEN** version=2 の外部 profile-file で、ある Codex role に `model: sol`、別の Codex role に `model: gpt-5.6-sol` を書いて request を作る
- **THEN** `model` キーを理由に profile 全体を拒否する。対応表の値は `git grep -nE 'gpt-[0-9]' plugins/dev-workflow/references/model-tier-map.json` が 0 件で、モデル ID を書かない

#### Scenario: 旧形式で系統名と完全 ID を指定する
- **WHEN** 旧形式 `--account NAME --model sol`、または `--account NAME --model gpt-6-astra` で request を作る
- **THEN** どちらも拒否されず、request の model は指定した値のままになる

#### Scenario: 解決後の ID を記録先に残す
- **WHEN** model=sol の Codex role を委譲し、worker の結果 JSON の `execution.model_resolution` が requested=sol、resolved=gpt-6-sol を返す
- **THEN** develop 本体の記録先コメントには要求値 `sol` と解決後の ID `gpt-6-sol` の両方が書かれ、どの ID で走ったかが後から追える
