## MODIFIED Requirements

### Requirement: 同じ集計を再実行する手順と更新記録を一か所に持つ

再検証手順は原スクリプトの取得、材料、実行順、期待する集計、限界、結果の保存先を一か所に記さなければならない（MUST）。値を変えるたび同じ手順の結果を判断用 issue / PR に残し、各値の出典を更新する（MUST）。原スクリプト未取得を再現済みとせず、repo に集計スクリプトを追加してはならない（MUST NOT）。decision-criteria.md から表と手順に到達できること（MUST）。

#### Scenario: 必要な材料と集計順が分かる

- **WHEN** 手順を読む
- **THEN** #1799 の基準 38 件と新モデル標本の区別、ログ・全ページのコメント・Codex 消費・PR ファイル情報、原スクリプトと引数/hash の取得、collect → calib → analyze → analyze2 → analyze3 → handover → ctxcap → analyze4 → analyze5 の順、固定分・見積もり誤差・手渡し損益分岐・4 上限の再検討が記されている

#### Scenario: 原スクリプトや保存先が不足する

- **WHEN** 原スクリプトが取得できない、または派生ログの保存に必要な LLM_LOG_DIR が未設定である
- **THEN** 手順は前者を再現未完と記録するよう求め、後者は保存先の確認を求める。repo 内や推測した個人ディレクトリに保存させない

#### Scenario: 値を更新するときに同じ結果を残す

- **WHEN** 再検証の結果を受けて登録値を変更する
- **THEN** 手順に従い対象モデル・日付・材料・再実行コマンド/hash・集計表・旧新値・採否理由・限界を issue または PR コメントに残し、表の該当レコードの根拠をその結果へ更新する

#### Scenario: 入口と配線の境界が読める

- **WHEN** decision-criteria.md の文脈上限の節と、利用手順 token-thresholds.md を読む
- **THEN** 表と再検証手順へのリンクがあり、共通処理が subagent-context.sh と context-tripwire.sh の文脈上限・強制停止と、pr-token-budget.sh の累計上限の 3 経路へ接続済みであることが明記され、「未配線」の記述が残っていない。モデルは各計測に採用したレコード（累計は数えた各リクエスト）から取得すること、上書き・CLI と hook の 0 の差・stderr 診断・失敗時の扱い（hook は fail-open、CLI は exit 1）が分かり、既存の停止・権限の意味は変わらない

## ADDED Requirements

### Requirement: 累計計測は数えたリクエストのモデルで共通の値を引く

`pr-token-budget.sh` は、usage を合計した重複除去後の各リクエストと同じ assistant レコードの `message.model` を集め、モデルごとに共通の解決処理で `pr_token_cap` を引き、最小の値を上限の既定にしなければならない（MUST）。欠落・非文字列・空白だけは不明とし、meta の別名・親・環境から補わない（MUST NOT）。Codex の thread はモデルの集合に入れない。数えたリクエストが無ければ不明で解決した値を使う。

守備範囲: 入力の出どころは、紐付いた各サブエージェントの会話記録の assistant レコードの `message.model` と同梱の表である。拾いたい誤りは、meta の別名や Codex 分を混ぜて常に未知モデル扱いになることと、混ざったモデルの片方を黙って落とすことである。通してよい入力は、前後に空白が付いた既知 ID（無加工で渡して未知扱いになる）、モデル申告の真偽、Codex のモデルの変化（集合に入れないので知らせない）である。これらの穴を塞ぎ切ることを完了条件にしない。

#### Scenario: 登録済みモデルだけなら表の値を診断なしで使う

- **WHEN** 紐付く 2 体の全リクエストの `message.model` が `claude-opus-5-5` と `claude-sonnet-5-5` で、上書きが無い
- **THEN** 出力の `cap` は 30000000 で、stderr に `unknown_model` も `revalidation_required` も出ない

#### Scenario: 未知モデルが混ざれば fallback と再検証の対象になる

- **WHEN** 紐付く 1 体のリクエストが `claude-opus-5-5`、もう 1 体が表に無い `claude-sonnet-5` で、上書きが無い
- **THEN** `cap` は登録行と fallback の `pr_token_cap` の最小値で、stderr に `claude-sonnet-5` の `unknown_model` と、対象 `pr_token_cap` の `revalidation_required` が出る

#### Scenario: モデルの無いリクエストは不明として数える

- **WHEN** 紐付くサブエージェントの assistant レコードの 1 つに `message.model` が無い、または空白だけである
- **THEN** そのリクエストのモデルは不明として fallback で解決され、meta の `model`（例: `sonnet`）は使われない

#### Scenario: 値が分かれたら最小値を採る

- **WHEN** 表を差し替えた配布物の写しで、数えたモデル 2 つの `pr_token_cap` が 40000000 と 20000000 である
- **THEN** 出力の `cap` は 20000000

#### Scenario: 数えたリクエストが無ければ診断なしで fallback の値を使う

- **WHEN** 紐付くサブエージェントが 0 体で、Codex の記録だけがある
- **THEN** `cap` は fallback 行の `pr_token_cap` で、stderr に `unknown_model` も `revalidation_required` も出ない

### Requirement: 累計計測の上書きは --cap と env の優先順位を守る

`pr-token-budget.sh` の上限は `--cap` > `DEV_WORKFLOW_PR_TOKEN_CAP` > モデル行 / fallback の順でなければならない（MUST）。有効な `--cap` があるときは env を共通処理に渡さない。env は共通処理の規則に従い、空白だけは未設定、前後空白付きの ASCII 非負整数は有効、0 も通す（MUST）。不正な env は `invalid_override` で exit 1 とする。

守備範囲: 入力の出どころは `--cap` と `DEV_WORKFLOW_PR_TOKEN_CAP` である。拾いたい誤りは、優先順位の取り違えと、不正な env を黙って既定値に戻すことである。通してよい入力は、有効な `--cap` に隠れる不正な env（例: `--cap 9000` と `DEV_WORKFLOW_PR_TOKEN_CAP=abc`）、0、文脈系の env の不正（共通処理に渡さないので見ない）である。これらの穴を塞ぎ切ることを完了条件にしない。

#### Scenario: 前後空白付きの env は有効

- **WHEN** `DEV_WORKFLOW_PR_TOKEN_CAP=" 7000 "` で `--cap` を付けずに実行する
- **THEN** 出力の `cap` は 7000

#### Scenario: 空白だけの env は未設定

- **WHEN** `DEV_WORKFLOW_PR_TOKEN_CAP="  "` で実行する
- **THEN** 出力の `cap` はモデル行 / fallback の値で、exit 1 にならない

#### Scenario: 不正な env は exit 1、有効な --cap はそれを遮る

- **WHEN** `DEV_WORKFLOW_PR_TOKEN_CAP=-1` で、`--cap` を付けずに実行し、次に `--cap 9000` を付けて実行する
- **THEN** 前者は stdout の `error` に `invalid_override` と `DEV_WORKFLOW_PR_TOKEN_CAP` があり stderr に理由が出て exit 1、後者は `cap` が 9000 で exit 0 か 2（合計との比較どおり）

### Requirement: 累計計測の診断は既存 JSON と配布先の手順参照を保つ

`pr-token-budget.sh` は、数えたモデルの `unknown_model` と、対象が `pr_token_cap` の `revalidation_required` を、上書き時も呼び出しごとに `pr-token-budget: ` 付きで stderr に出さなければならない（MUST）。再検証の行には要求モデル・根拠モデル・対象と、同じ配布物の `token-thresholds.md` の絶対パスを書く。stdout の 1 行 JSON のキーと exit code の意味は変えない（MUST NOT 変える）。本体は診断だけを理由に spawn・再開・委譲を止めてはならない（MUST NOT）。

守備範囲: 入力の出どころは、共通処理が返す診断と実行中のスクリプトの位置である。拾いたい誤りは、上書きや `--cap` のときに診断が消えること、別の配布物の手順を案内すること、stdout の JSON を壊すことである。通してよい入力は、測るたびに同じ診断が出ることと、診断の文言の細部である。これらの穴を塞ぎ切ることを完了条件にしない。

#### Scenario: 上書きしても診断を出し、JSON は変わらない

- **WHEN** 未知モデルのリクエストを数え、`--cap 9000` を付けて実行する
- **THEN** stderr に `pr-token-budget: unknown_model` と、`対象=pr_token_cap` と手順の絶対パスを含む `pr-token-budget: revalidation_required` の行が出て、同じ行は 1 回ずつで、stdout は従来のキーだけの 1 行 JSON で `cap` は 9000

#### Scenario: 同梱の配布物の手順を示す

- **WHEN** スクリプトと共通処理・表・手順を一時ディレクトリの配布物の写しに置き、その写しのスクリプトを実行する
- **THEN** 再検証の行の手順のパスは写しの `skills/develop/references/token-thresholds.md` の絶対パスである

#### Scenario: 本体の手順に診断の扱いが書かれている

- **WHEN** `skills/develop/references/pr-token-budget.md` を読む
- **THEN** 上限の既定がモデル別の表から決まること、再検証の診断を受けても spawn・再開・委譲を止めず、自分で再検証を始めず、記録先の作業の最後の主への報告に再検証が要る旨を書くことが書かれている

### Requirement: 累計の共通解決が失敗したら計測できないで終わる

`pr-token-budget.sh` は、共通処理の取得・呼出し・結果の取り出しで起きた `Exception` を `resolver_unavailable: <型>: <文>` とし、表・上書きの不正（`ValueError`）はその理由として、どちらも stderr に理由、stdout に `error` の 1 行 JSON を出して exit 1 で終わらなければならない（MUST）。隠れた定数の上限で補ってはならない（MUST NOT）。exit 1 のあとの扱いは `pr-token-budget.md` の「計測できない」のとおり。

守備範囲: 入力の出どころは配布物の表と `scripts/token_thresholds.py` である。拾いたい誤りは、壊れた表や欠けた共通処理を定数 30000000 で補って成功を装うことである。通してよい入力は、形式が正しい表（値や根拠の中身の正しさは見ない）である。予測できない障害すべてを扱い切ることを完了条件にしない。

#### Scenario: 共通処理が無い配布物

- **WHEN** 配布物の写しから `scripts/token_thresholds.py` を除いて実行する
- **THEN** stdout の `error` が `resolver_unavailable` で始まり、stderr に理由が出て exit 1。30000000 などの定数で計測を続けない

#### Scenario: 表が壊れた配布物

- **WHEN** 配布物の写しの `references/token-thresholds.json` を不正な JSON にして実行する
- **THEN** stdout の `error` が `invalid_table` で始まり exit 1
