## MODIFIED Requirements

### Requirement: 複数 Codex account を分離して観測し代表 account を固定する
resolver は dev-workflow に同梱された実装だけで、登録された各 CODEX_HOME の quota snapshot を account ごとの分離 cache へ並行取得し、認証情報、CODEX_HOME path、生 RPC 応答を保存してはならない（MUST NOT）。statusline plugin、設定ディレクトリへコピーされた helper、またはそれらの版を実行時依存にしてはならない（MUST NOT）。取得成功時だけ window・`fetched_at`・リセット権（`resets`）を更新し、取得失敗時は前回値（`resets` を含む）を保持して実効値の規則で読んだ値を候補にしなければならない（MUST。前回値の古さでは除外しない）。7 日窓を持つ account のうち margin 最大を代表とし、同点は account-home 宣言順で先の account を選ばなければならない（MUST）。一 account の失敗を他 account の欠測に波及させてはならない（MUST NOT）。選択後は当該工程の自動 profile に含まれる全 Codex role を代表 account に束縛し、execution config hash で固定しなければならない（MUST）。

cache は `version` 2 とし、`account/rateLimits/read` の応答の `rateLimitResetCredits` が `availableCount`（0 以上の整数）と `credits`（配列）の形を持つときだけ、`resets: {"available_count": <availableCount>, "expires_at": [<status が available の各 credit の expiresAt。整数でないもの（null・文字列など）は null として持つ>]}` を保存しなければならない（MUST）。形が合わない・欄が無いときは `resets` を書いてはならない（MUST NOT。リセット権が分からないことを 0 枚と区別する）。credit の id や応答の他の欄を保存してはならない（MUST NOT）。cache の `version` が 1 でも 2 でも、margin の読み方は変えてはならない（MUST NOT）。Codex のリセット権の取得元はこの cache だけであり、headroom（`dev-workflow-headroom` capability）はここから読む。

**守備範囲**: この要件が候補に通す・落とす入力は、利用者が渡す account-home 対応表（または既定の `CODEX_HOME`）と、resolver が account ごとに保つ cache の値だけである。拾いたい誤りは、存在しない・相対パスの CODEX_HOME、認証の主体が cache と食い違う前回値、週次窓の無い値であり、これらはその account だけを欠測にする。通してよい入力は、実在する絶対ディレクトリの有効な対応表、取得失敗後に残った古い前回値（リセット時刻がまだ先、または過ぎていて 0% として読めるもの）である。リセット権の正規化では、`rateLimitResetCredits` の欄が無い・`availableCount` が 0 以上の整数でない・`credits` が配列でない応答から守り（`resets` を書かず、分からないことを 0 枚と区別する）、status が available 以外の credit・未知の欄・`expiresAt` が null の credit は検査せず通す（available 以外は数えず、`expiresAt` が整数でない available の credit は失効 null として持つ）。account の候補判定はこの範囲で足り、穴が見つかるたびに塞ぎ切ることを完了条件にしない。

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
- **WHEN** 二つの CODEX_HOME に有効な週次 snapshot があり、宣言順で後の account の margin が大きい
- **THEN** 後の account を Codex 代表にし、自動 profile の全 Codex role がその account を使う

#### Scenario: 取得失敗後も前回値を使う
- **WHEN** account A の取得が失敗して前回値 age=200 秒・margin=+30 が保持され、account B の取得が成功して margin=+10 になる
- **THEN** 取得成否では候補を除外せず、前回値を持つ account A を Codex 代表にする

#### Scenario: 取得失敗が続いて前回値が古くなっても使う
- **WHEN** 取得に失敗した account の前回値が age=301 秒以上で、そのリセット時刻が現在より後である
- **THEN** その account を欠測にせず、前回の使用率を下限として候補に含める

#### Scenario: dev-workflow 単独配置で quota を取得する
- **WHEN** statusline plugin とコピー済み helper が存在しない環境で、dev-workflow の profile 未指定 resolver を実行する
- **THEN** dev-workflow 同梱実装だけで各 CODEX_HOME の quota を取得し、自動選択を完了する

#### Scenario: 旧 statusline helper を参照しない
- **WHEN** 設定ディレクトリに機械向け mode を持たない旧版 `statusline-codex.py` が存在する
- **THEN** resolver はその helper を実行も import もせず、dev-workflow 同梱実装の結果だけを使う

#### Scenario: 同点は宣言順で決める
- **WHEN** 二つの eligible Codex account の未丸め margin が等しい
- **THEN** account-home 宣言順で先の account を代表にする

#### Scenario: リセット権を cache に足す
- **WHEN** `account/rateLimits/read` の応答の `rateLimitResetCredits` が `availableCount: 2` と、status が available の credit 2 つ（`expiresAt` が整数）、status が used の credit 1 つを持つ
- **THEN** cache は `version: 2` で、`resets.available_count` が 2、`resets.expires_at` が available の 2 つの失効時刻になり、credit の id は保存しない

#### Scenario: リセット権の欄が無い応答
- **WHEN** 応答に `rateLimitResetCredits` が無いか、`availableCount` が 0 以上の整数でないか、`credits` が配列でない
- **THEN** cache に `resets` を書かず、window と `fetched_at` は今までどおり更新する
