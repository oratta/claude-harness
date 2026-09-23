# codex-role-profiles Specification

## Purpose
TBD - created by archiving change codex-develop-role-profiles. Update Purpose after archive.
## Requirements
### Requirement: 名前付き設定セットを共通入口で選ぶ
システムは `/develop --profile NAME [--profile-file PATH]` と対応する develop CLI の role resolver を提供しなければならない（MUST）。組み込み名は `codex-standard`、`codex-economy`、`hybrid-standard`、`claude-write-codex-review` とし、各 entry は executor/account/model/effort を持つ。形式版1の JSON は design の厳密な形式を満たし、全 canonical role を網羅しなければならない（MUST）。各 role の executor は `codex` または `claude` とし、同じ profile 内で混在できなければならない（MUST）。profile と旧 account/model の併用を拒否しなければならない（MUST）。

#### Scenario: 二つの Codex 組み込みセットを解決する
- **WHEN** `codex-standard` または `codex-economy` を解決する
- **THEN** spec-write は順に sol/high または luna/medium、spec-review/impl-review/review/decider は astra/high、implement は sol/medium または luna/medium、explore/summarize は luna/low に解決する。正式モデル名は design の表の値と一致し、全 entry は executor=codex、account=current となる

#### Scenario: 既存の混在セットを役割ごとに解決する
- **WHEN** `hybrid-standard` で書く役、独立レビュー役、decider、補助役を順に解決する
- **THEN** 各 role は既存 profile に記録された executor/account/model/effort をそのまま返し、Codex が書き Claude が検査する向きを維持する

#### Scenario: Claude が書き Codex が検査する組み込みセットを解決する
- **WHEN** `claude-write-codex-review` を解決する
- **THEN** spec-write/implement は claude/current/sonnet/medium、explore/summarize は claude/current/haiku/low、spec-review/impl-review/review/decider は codex/current/gpt-6-astra/high となる

#### Scenario: 役割ごとに登録 Codex account を選ぶ
- **WHEN** version=1 の外部 profile-file の Codex 役割に異なる登録 account を指定して解決する
- **THEN** 各 entry の account を保存し、外部ファイルを組み込みと merge せず、各 Codex 委譲は当該 entry の account だけを使う

#### Scenario: 曖昧または不完全な指定を拒否する
- **WHEN** profile と account/model のいずれかを併用する、profile-file のみ指定する、未知版/名前/キー/役割・重複キー・欠落役割・空値・未登録 Codex account・`codex`/`claude` 以外の executor がある
- **THEN** resolver は失敗し、実行可能な request/run/job を作らず、既定値や別 account に置換しない

### Requirement: 解決済み設定と版を init で固定する
profile run は execution_config の version/profile/roles と execution_config_hash を保存しなければならない（MUST）。resume は保存 snapshot を正本とし、外部設定を再読込してはならない（MUST NOT）。旧 run は従来の account/model を全役割へ適用し、effort 省略を保持しなければならない（MUST）。

#### Scenario: 設定ファイルが変更または削除される
- **WHEN** init 後にファイルを変更/削除して別工程を dispatch または継続復元する
- **THEN** 保存した版/名前/全 entry だけで解決し、snapshot/hash 不一致や未知版なら停止する

#### Scenario: 旧 run を再開する
- **WHEN** execution_config を持たない旧 run を再開する
- **THEN** 全役割に旧 account/model を適用し、run や旧 request に effort を追加しない

### Requirement: pending の役割と設定を固定して再送する
profile dispatch は pending_execution の role/executor/account/model/effort と payload hash を submit より前に保存しなければならない（MUST）。retry はこれらと snapshot、保存 request の request_id/cwd/role/設定/hash を照合し、元 request を再生成せず submit しなければならない（MUST）。旧 pending のキーや hash を変更してはならない（MUST NOT）。

#### Scenario: 異なる役割 account を持つ run の送信応答が失われる
- **WHEN** spec-review の pending があり retry する
- **THEN** run 全体の account/model ではなく spec-review の固定 entry を照合し、元 request_id と payload のまま同一 job を回収する

#### Scenario: pending の値が変わる
- **WHEN** executor/account/model/effort/role/cwd/request_id/hash または snapshot との一致が崩れる
- **THEN** retry は拒否し、prompt 再生成、新しい job、別 account への送信を行わない

#### Scenario: 旧 pending を新しい worker で再送する
- **WHEN** effort が無く旧テンプレートの prompt を持つ保存 request を retry する
- **THEN** 元キーと値と payload hash を維持し、effort=null や executor も追記せず、既存結果があれば model/list を呼ばず回収する

#### Scenario: unknown の job を再送する
- **WHEN** 同じ request_id が unknown として保存されている
- **THEN** 同一 job の状態を返すだけで再実行せず、ack や別 job への置換による迂回を許さない

### Requirement: 設定切替は品質工程を変えない
役割/ティアは既存 roles と model-tiers を参照し、phase は役割指示の選択に留めなければならない（MUST）。spec/review/finish/gate の既存 role 対応を保持し、explore/summarize は read-only の任意の補助役としなければならない（MUST）。手動とバーンの呼び出し側に同じ版付き設定と CLI resolver を提供し、独自の品質工程を作ってはならない（MUST NOT）。

#### Scenario: セットを切り替えて既存工程を実行する
- **WHEN** 標準/節約/混在/旧形式で同じ coordinator の仕様不要・仕様必要・レビュー差戻し・gate 失敗の fixture を実行する
- **THEN** 仕様要否、独立レビュー条件、工程順、差戻し判断/上限は同じであり、変わるのは設定と観測結果だけである。finish/gate は implement の設定を使う

#### Scenario: 手動とバーンの呼び出し例を解決する
- **WHEN** 同じ名前と設定を手動 CLI とバーン呼出し側の fixture から同じ init/resolver に渡す
- **THEN** 同じ snapshot が得られ、手動でバーン窓を要求せず、バーン接続/自動配分を今回新設しない

### Requirement: 実モデル受け入れと回帰を残す
実装は `codex-standard`、`codex-economy`、`hybrid-standard` の各組み込みセットで仕様作成、独立仕様レビュー、実装、独立実装レビューを実モデルで一件完走し、各役割の要求と取得できた実効 model/effort、account、executor、job/thread/turn ID、対象 HEAD を PR gate の動作確認に記録しなければならない（MUST）。未観測の実効設定や失敗を成功と扱ってはならない（MUST NOT）。

#### Scenario: 三つの組み込みセットの実機証拠を検査する
- **WHEN** coordinator が各組み込みセットの実行証跡を回収する
- **THEN** 別 job/thread の独立レビューと実効設定の観測元を確認でき、実効値が未観測または要求と異なる場合はその受け入れを未達と報告する

#### Scenario: ローカル回帰を実行する
- **WHEN** `scripts/test.sh` を引数なしで実行する
- **THEN** worker の開始前拒否/両RPC、develop の工程不変/pending固定/旧retry/継続v1-v2を fixture で検証し、Python 回帰はリポジトリ直下の `tests/python-suites.bats` 経由でファイル名を絞らずに全件検出される

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

### Requirement: 明示指定が無い工程では provider の週次余裕から構成を選ぶ
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決し、schema 2 snapshot の対応する `accounts` entry を読まなければならない（MUST）。余裕は reset までの週経過率から週次使用率を引いた未丸め値とし、0 以上を余裕あり、負値または欠測を詰まりとして design の選択表を適用しなければならない（MUST）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude snapshot を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使い、probe が失敗または timeout した場合も既存 snapshot に対する 300 秒の freshness 検証を維持しなければならない（MUST）。

#### Scenario: 両 provider に余裕がある
- **WHEN** Claude margin が +20、最良 Codex margin が +10 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、書く役と補助役は Claude、レビュー役と decider は Codex gpt-6-astra に解決する

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

### Requirement: snapshot の鮮度と週次窓を fail-safe に検証する
自動選択は `fetched_at` が整数で `0 <= now - fetched_at <= 300`、週次使用率が有限の 0..100、reset が現在より後かつ 7 日以内の snapshot だけを fresh としなければならない（MUST）。Codex は `minutes=10080` の有効な window だけを週次比較に使い、5 時間窓や reset credit を代用してはならない（MUST NOT）。不正、未来時刻、301 秒以上古い値、期限切れ reset は欠測として扱わなければならない（MUST）。この freshness 境界は Claude 起動 account 自動選択と同じでなければならない（MUST）。

#### Scenario: freshness 境界を判定する
- **WHEN** 同じ snapshot の age を 300 秒と 301 秒にして評価する
- **THEN** 300 秒は fresh、301 秒は欠測となり、古い側を余っている provider/account として選ばない

#### Scenario: 週次ではない Codex window を除外する
- **WHEN** Codex snapshot に fresh な 5 時間 window だけがある
- **THEN** Codex provider を欠測とし、その使用率を週次 margin に使わない

### Requirement: 複数 Codex account を分離して観測し代表 account を固定する
resolver は dev-workflow に同梱された実装だけで、登録された各 CODEX_HOME の quota snapshot を account ごとの分離 cache へ並行取得し、認証情報、CODEX_HOME path、生 RPC 応答を保存してはならない（MUST NOT）。statusline plugin、設定ディレクトリへコピーされた helper、またはそれらの版を実行時依存にしてはならない（MUST NOT）。取得成功時だけ window と `fetched_at` を更新し、取得失敗時は前回値を保持して freshness 検証後の値を候補にしなければならない（MUST）。fresh な 7 日窓を持つ account のうち margin 最大を代表とし、同点は account-home 宣言順で先の account を選ばなければならない（MUST）。一 account の失敗を他 account の欠測に波及させてはならない（MUST NOT）。選択後は当該工程の自動 profile に含まれる全 Codex role を代表 account に束縛し、execution config hash で固定しなければならない（MUST）。

profile・旧 account/model・account-home 対応表がいずれも未指定の自動選択では、resolver は `CODEX_HOME`、未設定なら `~/.codex` が既存の絶対ディレクトリの場合だけ、それを `current` account の対応として評価しなければならない（MUST）。候補が無ければ Codex は欠測のままにしなければならない（MUST）。明示 profile・旧形式、または明示対応表では、この既定対応を補完に使ってはならない（MUST NOT）。

#### Scenario: 対応表なしの通常起動で current Codex を評価する
- **WHEN** profile と account-home を付けずに工程を開始し、`CODEX_HOME` が既存の絶対ディレクトリを指す
- **THEN** そのディレクトリを `current` account として quota 候補に含める

#### Scenario: 既定 Codex home が存在しない
- **WHEN** `CODEX_HOME` が未設定で `~/.codex` が存在しない
- **THEN** Codex margin を欠測として扱い、存在しない既定対応を作らない

#### Scenario: 明示指定へ既定対応を補完しない
- **WHEN** Codex account を含む profile を明示し、account-home 対応表を渡さない
- **THEN** `CODEX_HOME` や `~/.codex` へ倒さず、対応表不足として拒否する

#### Scenario: 最も余裕がある account を選ぶ
- **WHEN** 二つの CODEX_HOME に fresh な週次 snapshot があり、宣言順で後の account の margin が大きい
- **THEN** 後の account を Codex 代表にし、自動 profile の全 Codex role がその account を使う

#### Scenario: 取得失敗後も fresh な前回値を使う
- **WHEN** account A の取得が失敗して前回値 age=200 秒・margin=+30 が保持され、account B の取得が成功して margin=+10 になる
- **THEN** 取得成否では候補を除外せず、fresh な前回値を持つ account A を Codex 代表にする

#### Scenario: 取得失敗後の freshness 境界を適用する
- **WHEN** 取得に失敗した account の同じ前回値を age=300 秒と age=301 秒で評価する
- **THEN** age=300 秒では候補に含め、age=301 秒ではその account だけを欠測にする

#### Scenario: dev-workflow 単独配置で quota を取得する
- **WHEN** statusline plugin とコピー済み helper が存在しない環境で、dev-workflow の profile 未指定 resolver を実行する
- **THEN** dev-workflow 同梱実装だけで各 CODEX_HOME の quota を取得し、自動選択を完了する

#### Scenario: 旧 statusline helper を参照しない
- **WHEN** 設定ディレクトリに機械向け mode を持たない旧版 `statusline-codex.py` が存在する
- **THEN** resolver はその helper を実行も import もせず、dev-workflow 同梱実装の結果だけを使う

#### Scenario: 同点は宣言順で決める
- **WHEN** 二つの eligible Codex account の未丸め margin が等しい
- **THEN** account-home 宣言順で先の account を代表にする

### Requirement: 自動選択の根拠を秘密なしで記録する
自動選択結果は選択した構成、理由コード、Claude と最良 Codex の未丸め margin の表示値、各 fetched_at、代表 Codex account を返さなければならない（MUST）。初回工程の結果を記録先の最初の develop 開始コメントへ残し、後続工程も dispatch 記録へ同じ evidence を残さなければならない（MUST）。欠測は `missing` と明示し、0 に置換してはならない（MUST NOT）。認証情報、CODEX_HOME path、生 snapshot を記録してはならない（MUST NOT）。

#### Scenario: 最初のコメントへ理由を記録する
- **WHEN** profile 未指定で `/develop` の最初の工程を開始する
- **THEN** 記録先の最初の develop 開始コメントから選択構成、両 provider の margin/fetched_at、代表 Codex account または missing、理由コードを確認でき、実際の role 投げ先がその構成と一致する

#### Scenario: 全体回帰を実行する
- **WHEN** repository の `scripts/test.sh` を実行する
- **THEN** 自動選択、明示指定、profile 検証、Codex snapshot 分離を含む回帰が exit 0 になる
