## Context

既存の `cost_ledger.py` は Claude Code の JSONL から usage と料金を取り出し、`subagent-context-audit.sh` はサブエージェントのコンテキスト量を監査できる。しかし両者の母集団・期間・出力形式は別で、役割別消費、PR 単位の gate-runner 指標、GitHub 上の速度と品質、usage 枠の進行、実稼働時間を同じ比較窓で結合する入口はない。

入力は利用者ローカルの会話履歴と usage snapshot、認証済み `gh` の応答である。ログには重複した assistant レコードがあり、複数セッション・複数エージェントは並行する。集計は再現可能である一方、個人パス、プロンプト本文、認証情報を成果物へ保存しない必要がある。

## Goals / Non-Goals

**Goals:**

- `--since` / `--until` の同一期間で、消費・速度・品質・稼働時間を 1 行 JSON にする。
- メイン／サブ、サブエージェント役割、起動時モデル、gate-runner の PR 単位という比較軸を固定する。
- fixture と fake `gh` だけで全計算を再現できるよう、入力境界を差し替え可能にする。
- usage snapshot の日次記録方法を提供し、利用者が launchd 等へ登録できる手順を文書化する。

**Non-Goals:**

- 実装工程で利用者の launchd / cron にジョブを登録すること。
- この PR だけで `usage-pace.log` の実データを 3 日分生成すること。
- この PR から epic #360 へ 2026-09-01〜09-21 の実測表を投稿すること。
- `/cost` の既存出力、料金表、issue / branch 帰属規則を変更すること。
- 指標をレビューゲートや残量モードの判定入力にして、実行を止めること。

## Decisions

### 1. 公開入口は shell、集計本体は Python に置く

利用者向けの契約は issue の受け入れ条件どおり `plugins/cost-ledger/scripts/weekly-metrics.sh` とし、これは引数検証と Python 集計器の起動だけを担う。JSONL の解析、時刻計算、中央値、GitHub JSON の結合、最終 JSON の生成は Python に置き、`cost_ledger.py` の usage 抽出・料金計算を再利用可能な関数として共有する。既存 `cost_ledger.py cost` の stdout は変更しない。

- **採用理由**: jq と shell だけで並行セッション、重複排除、時間窓、中央値を扱うと分岐が散り、既存の料金計算と二重実装になる。
- **却下案**: `subagent-context-audit.sh` に全指標を足す。このスクリプトは観測専用の fail-open 監査であり、GitHub データを必要とする期間レポートとは失敗契約も母集団も異なる。

### 2. 期間は UTC の閉区間の日付として扱う

`--since YYYY-MM-DD --until YYYY-MM-DD` は UTC で since 日の 00:00:00 以上、until 翌日の 00:00:00 未満として扱う。`since > until`、日付形式不正、必須入力の欠落は説明を stderr に出して非 0 とする。JSON は常に stdout の 1 行だけに出し、診断は stderr に分離する。

- **採用理由**: GitHub と JSONL の timestamp は UTC へ正規化でき、端末のタイムゾーンにより同じコマンドの結果が変わらない。
- **却下案**: ローカルタイムで日付境界を切る。利用者ごとの差と夏時間を fixture に持ち込む。

### 3. ターンと読み込み量は usage 付き assistant メッセージを単位にする

メインは `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` 直下のセッショントランスクリプト、サブはその配下の固定深さ `*/*/subagents/agent-*.jsonl` を走査する。weekly metrics は各母集団で usage 付き assistant メッセージを、空でない `message.id`、無ければ `requestId`、それも無ければ `uuid` の優先順で、キー種別を含む組（例: `message:<id>`）として重複排除する。3 つとも無い行は除外して warnings に数える。同じ `message.id` で `requestId` が異なっても 1 ターンである。ターン数は重複排除後の件数、1 ターン当たり読み込み量は `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` の合計をターン数で割った値とする。コストは既存料金表と既存の cache creation 5m / 1h fallback を使う。

この優先順は新しい weekly metrics だけの契約である。既存 `/cost` と `cost-ledger-attribution` の事実抽出・重複排除は引き続き `requestId`（無ければ `uuid`）を使う。共有するのは usage の構造検証と料金計算までとし、重複排除 helper を共有する場合も呼び出し側が policy を明示する。weekly metrics の追加や refactor によって既存 CLI の母集団を変えない。

Workflow 経由など固定深さの対象外は、既存 `subagent-context-audit.sh` と同様に母集団へ混ぜない。不正行と必要フィールド欠落は件数を `warnings` に出し、黙って捨てない。

### 4. 役割と起動時モデルは transcript ごとに一度だけ分類する

役割判定に使う「起動プロンプト先頭」は、最初の user/start record から得た起動プロンプトの最初の空でない 1 行だけとし、会話途中と 2 行目以降は見ない。候補は Unicode NFKC、ASCII 小文字、前後空白除去で正規化し、transcript と隣接 meta の basename（拡張子を除く）も同じように扱う。部分文字列ではなく英数字・`_`・`-`・`:` の境界を持つ次の literal だけを、優先順 `decider` → `gate-runner` → `worker` で照合する。

- `decider`: `dev-workflow:decider`、`role: decider`、basename の `decider` segment
- `gate-runner`: `gate-runner`、`role: gate`、`role: gate-runner`、`ゲート実行者 g`、basename の `gate-runner` segment
- `worker`: `role: spec-write`、`role: implement`、`role: archive`、`作業者 w`、basename の `worker` segment
- 一致なし: `other`

同じ候補に複数の literal があれば優先順で 1 役割だけにする。判定に用いた生プロンプトや path は出力しない。

transcript の起動時刻は JSONL 全行の最初の有効な timestamp とする。起動時モデルは隣接 meta JSON の model を優先し、無ければ最初の usage 付き assistant メッセージの `message.model` を使う。モデル名は Opus / Sonnet / Fable / Haiku / other に正規化する。期間内の usage・稼働 interval を持つ transcript は期間前に起動していても turns / cost / active time と役割別集計へ含めるが、`starts` と `sub.model_share` の分母・分子には起動時刻が比較期間内の transcript だけを含める。起動時刻を確定できない transcript は starts / model share から外して warnings に数える。したがって model share はターン比率でも「期間内に活動した transcript」の比率でもない。

- **採用理由**: issue が指定する「起動プロンプト先頭とファイル名」の事実に限定し、会話途中の本文を役割推定へ使わない。モデルも「起動時の比率」なので transcript を一票とする。

### 5. 稼働時間は transcript ごとの連続 interval から求める

usage や message type の有無を問わず、各 JSONL transcript の有効な timestamp を持つ全行を timestamp 順で並べる。隣り合う 2 行の元の差が 0 秒以上 15 分以下なら、その interval と UTC の比較期間 `[since 00:00:00, until 翌日 00:00:00)` の共通部分だけを稼働時間へ加える。15 分超なら、期間境界で切れば 15 分以下になっても interval 全体をアイドルとして除外する。このため境界直前・直後の隣接 1 行も interval 判定には読み、例えば 23:55→期間開始 00:00→00:05 に相当する 10 分 interval は期間内の 5 分だけを数える。timestamp 不正の行は除外して `warnings` に数え、最後の 1 行に固定時間を加算しない。並行 transcript 間の timestamp を直列につながず、消費の message-ID 重複排除を時間系列へ適用しない。

メイン／サブと役割別は各 transcript の稼働秒を合算する。gate-runner は起動プロンプトに現れるリポジトリと PR 番号で transcript を PR に束ね、PR ごとのターン数・読み込み量・稼働分を算出してから中央値を取る。PR を識別できない gate-runner は全体・役割別には含めるが PR 単位指標の分母から外し、件数を warnings に出す。

- **採用理由**: セッション間の空白や並行実行を作業時間に誤算入せず、issue が指定した 15 分境界をそのまま再現できる。

### 6. usage pace は追記専用 JSONL とリセット窓で計算する

`usage-pace-log.sh` は現在の usage snapshot を読み、実行時刻 `recorded_at` と、各アカウント ID の `fetched_at` / `weekly_all_pct` / `weekly_resets_epoch` を `${USAGE_PACE_LOG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/usage-pace.log}` に 1 行 JSON で追記する。`fetched_at` はその account の値を実際に観測した時刻で、probe の実行時刻や logger の `recorded_at` へ置き換えない。snapshot に存在する account は欠けた値を `null` のまま残し、少なくとも 1 account に 3 値すべてがあれば行を追記する。snapshot の一時ファイルや不完全 JSON は記録しない。アカウントラベル、securestorage パス、token は記録せず、複数プロセスの同時追記で 1 行が混ざらない方法を使う。

集計では `(account ID, fetched_at)` を観測の identity とし、同じ 3 値を持つ再記録は 1 観測に畳む。同じ identity で pct/reset が衝突する場合はその identity 全体を欠測として除外し warnings に出す。`fetched_at` / pct / reset のどれかが null・不正なら欠測であり、`recorded_at` を代用せず 0 消費ともみなさない。

週次換算は account ごと・同一 `weekly_resets_epoch` ごとに、reset の直前 7 日に属し比較期間内にある一意な観測をまとめる。7 つ以上の異なる UTC 観測日と正の経過時間を持つ窓だけを有効とし、最初と最後の pct 差を `fetched_at` の経過日数で割って 7 倍する。負の差、7 日未満の部分窓、欠測を含んで有効条件を満たさない窓は projection を `null` として `pace.by_account.<id>.windows` に残し warnings に出す。account ごとの `weekly_avg_pct` は、その account の有効窓の projection 合計をその account 自身の有効窓数で割る。A と B の reset 日や有効窓数が違っても共通の「週数」を分母にしない。

`pace.weekly_sum_pct` は、期間内の pace log に現れる全 account が少なくとも 1 有効窓を持つ場合だけ、各 account の `weekly_avg_pct` の合計とする。片方だけ欠測、全 account の有効窓が 0、pace log が 0 行の場合はキーを省略せず `null` にする。部分窓は 0 として分母・分子へ入れない。2026-09-01〜09-21 は pace log が存在しないため、3 日分の将来ログを取得しても遡及せず `null` になる。7 日分以上の日次観測が揃った有効窓を含む期間では非 null になる。

- **採用理由**: A・B を別系列のまま監査でき、全アカウントを合わせた週当たり消費も一つの比較値にできる。reset をまたいだ累積値の減少を消費の巻き戻しと誤認しない。
- **却下案**: snapshot の最新値だけを週次消費とみなす。週の途中の値なので比較日時に強く依存する。

### 7. GitHub 指標は期間内に merge された本人の PR を母集団にする

認証済み `gh` で login と現在の `owner/repo` を解決した後、`gh api --paginate 'repos/{owner}/{repo}/pulls?state=closed&per_page=100'` により全ページを取得し、`user.login` が本人、`merged_at` が null でなく比較期間内の PR をローカルで絞る。issue にある `gh search prs --author @me --merged` は母集団の意図を示す略記として扱い、実装の取得には使わない。`gh search prs --json` には `mergedAt` がなく、既定 30 件だからである。Draft 作成時刻は REST 応答の `created_at` とし、`lead_time_median_h` は `created_at` から `merged_at` まで、`merged_count` はその PR 数とする。

品質は `gh api --paginate 'repos/{owner}/{repo}/issues?state=all&labels=bug&per_page=100'` の全ページから `pull_request` を持たない issue をローカルで選び、それぞれの `merged_at` から 7 日後までに `created_at` が入る集合を取る。重なる窓に入る同一 issue は number で一度だけ数える。PR との因果関係を推定せず「merge 後 7 日窓に観測された bug issue 数」として出力する。

`gh` 失敗、未認証、repository を解決できない場合は、不正なゼロのベースラインを残さないため集計を非 0 で止める。テストでは PATH 上の fake `gh` を使い、実 REST と同じ snake_case fields と Link pagination 相当の複数ページを返す。2 ページ目の期間内 PR と bug issue も結果へ入ることを固定し、先頭 30 件だけで成功する実装を許さない。

### 8. 出力 schema と入力差し替えを固定する

トップレベルは `period` / `main` / `sub` / `gate` / `pace` / `pr` / `quality` / `time` / `warnings` を持つ。少なくとも issue の jq 条件に現れる以下の値を常に同じ型で出す。

- `main.turns`, `main.ctx_per_turn`, `main.cost_usd`
- `sub.turns`, `sub.ctx_per_turn`, `sub.cost_usd`, `sub.by_role`, `sub.model_share`
- `gate.turns_per_pr`, `gate.ctx_per_pr`, `gate.minutes_per_pr`
- `pace.weekly_sum_pct`, `pace.by_account`
- `pr.lead_time_median_h`, `pr.merged_count`
- `quality.bug_issues_7d`
- `time.main_active_h`, `time.sub_active_h`, `time.by_role`

テストは実ホームを読まず、projects root、snapshot、pace log、料金表を環境変数で fixture に差し替える。出力の時間・料金は丸め規則を実装内で一か所に持ち、同じ fixture から常に同じ JSON を得る。

`pace.weekly_sum_pct` は常にキーを持つが、上記の欠測時だけ number ではなく JSON `null` になる。ほかの欠測可能な中央値も schema で定めたキーを残し、欠測と実測 0 を区別する。

## Risks / Trade-offs

- **[役割名や meta schema が変わり分類精度が落ちる]** → 一致しないものを `other` に残し、分類件数を出す。生プロンプトの保存や広い本文推測はしない。
- **[全 JSONL 走査が重い]** → 期間を timestamp で早期除外し、1 回の走査で全ローカル指標を作る。別々のスクリプトで同じログを繰り返し読まない。
- **[GitHub 検索の揺れや API 制限]** → query 条件を stderr に示し、失敗時は非 0。fixture テストは fake `gh` で固定する。
- **[15 分規則が短い作業の最後を過小評価する]** → 最終行への恣意的な固定加算を避け、前後比較で同じ規則を使う。絶対的な勤怠時間として扱わない。
- **[pace の欠測で週次換算が偏る]** → 7 観測日未満の reset 窓を `null` として warnings に残し、account が一つでも欠ければ合計も `null` にする。導入手順に日次実行とログ確認を含める。
- **[ローカルログに機微情報がある]** → 出力は数値と分類だけに限定し、プロンプト、cwd、securestorage、認証情報を出力・永続化しない。

## Migration Plan

1. fixture ベースの Red テストを追加し、既存 `cost_ledger.py` の公開出力を回帰テストで固定する。
2. 共通解析と weekly metrics、usage pace recorder、README の手動導入手順を実装する。
3. `scripts/test.sh` と OpenSpec validate を通す。利用者環境への launchd 登録は行わない。
4. マージ後に利用者が日次記録を有効化し、3 日分以上を蓄積する。
5. 2026-09-01〜09-21 のコマンド結果（`pace.weekly_sum_pct: null` を欠測として明記）を整形し、epic #360 にベースラインとして投稿する。

ロールバックは追加スクリプトと文書を戻すだけで、既存 `/cost` の保存データ移行はない。利用者が登録した日次ジョブは導入手順に記載する解除方法で停止する。

## Open Questions

なし。実ログの蓄積と epic 投稿は実装後運用として、コード変更とは別に完了確認する。
