# Design

## Context

change 2（PR #1808）は文脈計測を共通の解決処理につなぐとき、次の形を決めた（`decision-criteria.md` の文脈上限の節と `openspec/specs/dev-workflow-token-thresholds` の文脈計測の要件）。

- モデルは計測に採用した usage と同じ assistant レコードの `message.model`。欠落・非文字列・空白だけは不明とし、親・環境・別名から補わない
- CLI は `--cap` > 指標の env > モデル行 / fallback。env は共通処理の規則（空白だけは未設定、前後空白付き ASCII 非負整数は有効、0 も通す）。有効な `--cap` は不正 env も遮る
- 診断（`unknown_model` と、使う指標の `revalidation_required`）は上書きのときも呼び出しごとに stderr に出し、実行中のスクリプトと同じ配布物の `token-thresholds.md` の絶対パスを案内する。CLI の stdout は従来の JSON だけ
- 共通処理はスクリプトの実体の位置から `importlib` で読み、取得・呼出し・結果の取り出しで起きた `Exception` は `resolver_unavailable`。表・上書きの不正（`ValueError`）はその理由で、どちらも CLI は `error` の JSON と exit 1

`pr-token-budget.sh` は文脈計測と違い、1 体の 1 レコードではなく、記録先に紐付く複数のサブエージェントの全リクエストと Codex の thread を合計し、上限を合計に 1 本で掛ける。表の `pr_token_cap` は今は全モデル行と fallback で 30000000 で、根拠モデル集合は `claude-opus-5-5` と `claude-sonnet-5-5`（標本は Claude と Codex の混合）。

## Goals / Non-Goals

Goals:

- 累計上限の既定値を、記録先で実際に使ったモデルの表の値から決め、根拠モデルと違うモデルを使っていれば呼び出しごとに知らせる
- change 2 と同じ優先順位・env の規則・診断の出し方・失敗の扱いにそろえる
- 文書 3 本の「未配線」の記述を接続後の事実に直す

Non-Goals:

- 上限値（30000000）・エピックの子の権限（60000000）・exit 2 のあとの止まり方を変えない
- `pr-token-measure.sh`・`codex-records.sh` の動きを変えない（stderr は素通しされる）
- #1802 の粒度の計算（`epic-granularity.py` とその文書）に触れない
- Codex の固定モデル ID を表に足さない

## Decisions

### どのモデル ID で表を引くか: 数えたリクエストの `message.model` の集合

usage を合計したのと同じ assistant レコード（`requestId` → `message.id` → `uuid` で重複を除いた後の各リクエスト）の `message.model` を集める。重複行が別のモデル値を持つときは、usage と同じく後の行を採る。欠落・非文字列・空白だけは不明（`None`）として集合に入れる。meta の `model`（`sonnet` / `fable` のような spawn 時の別名）は使わない。共通処理の規則どおり別名から推測しないためと、change 2 と同じく「計測に使ったレコードのモデル」にそろえるため。

他の案: meta の `model` を使う（別名なので常に未知モデルになり、診断が毎回出て意味を失う）／記録先の代表モデルを 1 つ選ぶ（選び方の根拠が無く、混ざったモデルの片方を黙って見落とす）。

### 値が分かれたら最小値

集合の各モデル（不明を含む）を 1 回ずつ解決し、`pr_token_cap` の値の最小を上限にする。fallback が「現在値を引き上げない安全側」であるのと同じ向きで、混ざったモデルのうち最も厳しい値で止める。今の表では全行が 30000000 なので結果は変わらない。env の上書きはどのモデルの解決でも同じ値になるので、上書き時は env の値になる。

他の案: リクエスト数やトークン数で重み付けした値（表の値は合計に 1 本で掛ける前提で決めたもので、重み付けの根拠が無い）／最大値（安全側の逆向き）。

### 数えたリクエストが無いときは fallback の値を診断なしで使う

紐付く 0 体（最初の spawn の前の計測など）や、紐付いても assistant レコードが無いときは、不明モデルで 1 回解決して値を使い、`unknown_model` と `revalidation_required` は出さない。診断は「根拠と違うモデルを使った」ことを知らせるためのもので、まだ何も使っていないときに出すと、記録先ごとの最初の計測で毎回出て本体の報告を埋める。上書き・不正 env・共通処理の失敗の扱いは、この場合も同じ。

他の案: 不明として診断を出す（change 2 の「不明は診断」と字面はそろうが、使っていないモデルについての通知になる）。

### Codex の消費は再検証の対象にしない

`--codex-records` の行と rollout には固定のモデル ID が無く、表の累計の根拠標本はもともと Claude サブエージェントと Codex の混合である（`token-thresholds.md`）。Codex の thread を不明モデルとして集合に足すと、Codex を使った記録先では毎回診断が出るが、再検証の手順でも Codex を固定 ID 別に分けられないので、知らせを受けても動けない。Codex 分は従来どおり合計には入れ、モデルの集合には入れない。

他の案: Codex の thread を不明モデルとして数える（上の理由で通知が常時化する）。

### 優先順位・env・診断・失敗は change 2 の CLI の形にそろえる

- `--cap` の検査は今のまま（ASCII 非負整数でなければ exit 1）。有効な `--cap` があるときは env を共通処理に渡さない（不正 env も遮る）。無いときは `DEV_WORKFLOW_PR_TOKEN_CAP` があればそれだけを渡す
- 診断は `pr-token-budget: <message>` の形で stderr に出す。`unknown_model` は共通処理の文、`revalidation_required` は `metric` が `pr_token_cap` のものだけを、要求モデル・根拠モデル・対象 `pr_token_cap`・実行中のスクリプトの配布物の `skills/develop/references/token-thresholds.md` の絶対パスで書く。集合に複数モデルがあれば、要るモデルごとに出す（同じ文は 1 回）。上書き・`--cap` のときも出す
- stdout の 1 行 JSON のキーは変えない（`cap` は採用した上限）。exit code も 0 / 2 / 1 のまま
- 共通処理は `subagent-context.sh` と同じく `SCRIPT_PATH`（`${BASH_SOURCE[0]}`）から配布物の位置を出し、`importlib` で読む。`ValueError` は `{"error": "<理由>"}` と stderr、それ以外の境界の `Exception` は `resolver_unavailable: <型>: <文>` で、どちらも exit 1。値が整数でないときも `resolver_unavailable`
- env の不正の文言は、今の固定文 `DEV_WORKFLOW_PR_TOKEN_CAP must be a non-negative integer` から共通処理の `invalid_override: DEV_WORKFLOW_PR_TOKEN_CAP: ...` に変わる（exit 1 は同じ）

### 本体の新上限の計算は出力の `cap` を使う

「その時点の合計 ＋ 直前の計測で上限に使った値」の後者を、`--cap`・env・30000000 の順の説明ではなく、直前の計測の出力 `cap` と書く。モデル行の値が 30000000 から変わっても、本体が自分で順番をたどり直して食い違うことが無い。

### 本体は診断だけで止まらない

`pr-token-budget.md` に、stderr の再検証の診断を受けても spawn・再開・委譲を止めず、自分で再検証を始めず、主への報告（その記録先の作業の最後の報告）に再検証が要る旨と診断の文を書く、と書く。change 2 でサブエージェント本人に求めた扱いと同じ向き。

## Risks / Trade-offs

- 既存テストの多くは `run` で stdout と stderr を混ぜて JSON を読む。固定入力のモデルは `claude-sonnet-5`（表に無い ID）なので、接続後は stderr に診断が出て JSON の読み取りが壊れる。テストは `--separate-stderr` にそろえる（固定入力のモデルは変えず、未知モデルの診断の検査にも使う）
- 記録先に紐付く全トランスクリプトのモデルを集めるので、モデル数だけ共通処理を呼ぶ（表の読み込みが数回増える程度で、計測の時間はほぼ変わらない）
- 最小値の規則は、今の表では値が全行同じなので観測できる違いが無い。テストは env を使わず差を出せないため、表を差し替えた配布物の写しで検査する
