## MODIFIED Requirements

### Requirement: snapshot の鮮度と週次窓を fail-safe に検証する
Codex の自動選択は、取得からの経過時間で値を捨ててはならない（MUST NOT）。`fetched_at` が整数で現在以前、週次使用率が有限の 0..100、reset が整数の snapshot について、Claude 側と同じ実効値の規則で読まなければならない（MUST）。リセット時刻を過ぎた窓は使用率 0%・リセット時刻は 1 週間単位で現在より先へ送った値とし、過ぎていなければ取得した使用率を下限としてそのまま使う。リセット時刻が現在から 7 日より先でも欠測にせず、週経過率が負になって余裕が負になるだけとする。Codex は `minutes=10080` の有効な window だけを週次比較に使い、5 時間窓や reset credit を代用してはならない（MUST NOT）。不正な値、未来時刻、週次窓が無い snapshot は欠測として扱わなければならない（MUST）。Claude 側は取得からの経過時間で判定せず、`usage-session-records` の実効値の規則（リセット時刻を過ぎた窓は 0%、過ぎていなければ下限）に従わなければならない（MUST）。Claude の実効値の週次使用率が有限の 0..100 でない、または週次のリセット時刻が求まらないときは欠測として扱わなければならない（MUST）。

**守備範囲**: 入力は、dev-workflow 同梱の resolver が各 CODEX_HOME の quota 取得結果から作る account ごとの cache（取得成功時の値、または取得失敗時に保持された前回値）だけである。拾いたい誤りは、cache の破損・手書きによる型や範囲の誤り（`fetched_at` やリセット時刻が整数でない、使用率が有限の 0..100 でない、週次窓が無い）と、時計のずれによる未来の取得時刻であり、これらは欠測にして余っている provider として選ばない。通してよい入力は、取得から数分〜数日たった値でリセット時刻がまだ先のもの（下限として使う）、リセット時刻を過ぎた値（0% で読む）、リセット時刻が現在から 7 日より先の値（余裕が負になるだけ）である。取得時刻が古いことは誤りとして扱わない。cache の値が実際の使用量より低い（取得後に使われた分を反映していない）ことは下限として許容し、検知しない。この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: Codex の古い値はリセット前なら下限として使う
- **WHEN** Codex の週次 snapshot が 301 秒以上前（例: 1 日前）に取得され、リセット時刻が現在より後である
- **THEN** 取得した使用率を下限としてそのまま使い、欠測として扱わない

#### Scenario: Codex のリセットを過ぎた窓は 0% で読む
- **WHEN** Codex の週次 snapshot のリセット時刻が現在以前である
- **THEN** 使用率を 0%、リセット時刻を 1 週間単位で現在より先へ送った値として margin を求める

#### Scenario: Codex のリセット時刻が 7 日より先でも欠測にしない
- **WHEN** Codex の週次 snapshot のリセット時刻が現在から 7 日より先である
- **THEN** 欠測にせず、週経過率が負になる margin を求める。余裕が負なので Codex は選ばれない

#### Scenario: 未来の取得時刻は欠測にする
- **WHEN** Codex snapshot の `fetched_at` が現在より後である
- **THEN** 欠測として扱う

#### Scenario: Claude の古い値はリセット前なら使う
- **WHEN** Claude の起動 account の値が 1 日前に取得され、週次のリセット時刻が現在より後である
- **THEN** その値から Claude margin を求め、欠測として扱わない

#### Scenario: 週次ではない Codex window を除外する
- **WHEN** Codex snapshot に fresh な 5 時間 window だけがある
- **THEN** Codex provider を欠測とし、その使用率を週次 margin に使わない

### Requirement: 複数 Codex account を分離して観測し代表 account を固定する
resolver は dev-workflow に同梱された実装だけで、登録された各 CODEX_HOME の quota snapshot を account ごとの分離 cache へ並行取得し、認証情報、CODEX_HOME path、生 RPC 応答を保存してはならない（MUST NOT）。statusline plugin、設定ディレクトリへコピーされた helper、またはそれらの版を実行時依存にしてはならない（MUST NOT）。取得成功時だけ window と `fetched_at` を更新し、取得失敗時は前回値を保持して実効値の規則で読んだ値を候補にしなければならない（MUST。前回値の古さでは除外しない）。7 日窓を持つ account のうち margin 最大を代表とし、同点は account-home 宣言順で先の account を選ばなければならない（MUST）。一 account の失敗を他 account の欠測に波及させてはならない（MUST NOT）。選択後は当該工程の自動 profile に含まれる全 Codex role を代表 account に束縛し、execution config hash で固定しなければならない（MUST）。

**守備範囲**: この要件が候補に通す・落とす入力は、利用者が渡す account-home 対応表（または既定の `CODEX_HOME`）と、resolver が account ごとに保つ cache の値だけである。拾いたい誤りは、存在しない・相対パスの CODEX_HOME、認証の主体が cache と食い違う前回値、週次窓の無い値であり、これらはその account だけを欠測にする。通してよい入力は、実在する絶対ディレクトリの有効な対応表、取得失敗後に残った古い前回値（リセット時刻がまだ先、または過ぎていて 0% として読めるもの）である。account の候補判定はこの範囲で足り、穴が見つかるたびに塞ぎ切ることを完了条件にしない。

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
