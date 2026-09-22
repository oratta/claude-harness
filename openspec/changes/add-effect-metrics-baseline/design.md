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

メインは `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` 直下のセッショントランスクリプト、サブはその配下の固定深さ `*/*/subagents/agent-*.jsonl` を走査する。各母集団で `requestId`、無ければ `message.id`、それも無ければ `uuid` を鍵に重複排除する。ターン数は重複排除後の usage 付き assistant メッセージ数、1 ターン当たり読み込み量は `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` の合計をターン数で割った値とする。コストは既存料金表と既存の cache creation 5m / 1h fallback を使う。

Workflow 経由など固定深さの対象外は、既存 `subagent-context-audit.sh` と同様に母集団へ混ぜない。不正行と必要フィールド欠落は件数を `warnings` に出し、黙って捨てない。

### 4. 役割と起動時モデルは transcript ごとに一度だけ分類する

役割は起動プロンプト先頭の明示語と transcript / meta ファイル名を正規化して、優先順 `decider` → `gate-runner` → `worker` → `other` で一意に決める。`dev-workflow:decider` は decider、pr-review-gate の実行担当を示す語は gate-runner、develop の W / worker を示す語は worker とし、どれにも一致しないものを other にする。判定に用いた生プロンプトは出力しない。

起動時モデルは隣接 meta JSON の model を優先し、無ければ最初の usage 付き assistant メッセージの `message.model` を使う。モデル名は Opus / Sonnet / Fable / Haiku / other に正規化し、`sub.model_share` は transcript 起動数を分母とする比率にする。ターン比率にはしない。

- **採用理由**: issue が指定する「起動プロンプト先頭とファイル名」の事実に限定し、会話途中の本文を役割推定へ使わない。モデルも「起動時の比率」なので transcript を一票とする。

### 5. 稼働時間は transcript ごとの連続 interval から求める

usage 付き assistant メッセージを transcript ごとに timestamp 順で並べ、隣り合う 2 行の差が 0 秒以上 15 分以下なら差分全体を稼働時間へ加え、15 分超ならその interval 全体をアイドルとして除外する。負の差と timestamp 不正は除外して `warnings` に数える。最後の 1 行に固定時間を加算しない。並行 transcript 間の timestamp を直列につながない。

メイン／サブと役割別は各 transcript の稼働秒を合算する。gate-runner は起動プロンプトに現れるリポジトリと PR 番号で transcript を PR に束ね、PR ごとのターン数・読み込み量・稼働分を算出してから中央値を取る。PR を識別できない gate-runner は全体・役割別には含めるが PR 単位指標の分母から外し、件数を warnings に出す。

- **採用理由**: セッション間の空白や並行実行を作業時間に誤算入せず、issue が指定した 15 分境界をそのまま再現できる。

### 6. usage pace は追記専用 JSONL とリセット窓で計算する

`usage-pace-log.sh` は現在の usage snapshot を読み、実行 timestamp と、各アカウント ID の `weekly_all_pct` / `weekly_resets_epoch` だけを `${USAGE_PACE_LOG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/usage-pace.log}` に 1 行 JSON で追記する。snapshot の一時ファイルや不完全 JSON を記録しない。アカウントラベル、securestorage パス、token は記録しない。複数プロセスの同時追記で 1 行が混ざらない方法を使う。

週次換算はアカウントごと・同一 reset epoch ごとに、期間内の最初と最後の pct 差を経過日数で割って 7 倍する。差が負になる reset 境界をまたいで連結しない。十分な 2 点が無い窓は欠測として warnings に出す。`pace.by_account` にアカウント別の窓と換算値を出し、比較期間に重なる各週・各アカウントの換算値の合計を週数で平均した値を `pace.weekly_sum_pct` とする。

- **採用理由**: A・B を別系列のまま監査でき、全アカウントを合わせた週当たり消費も一つの比較値にできる。reset をまたいだ累積値の減少を消費の巻き戻しと誤認しない。
- **却下案**: snapshot の最新値だけを週次消費とみなす。週の途中の値なので比較日時に強く依存する。

### 7. GitHub 指標は期間内に merge された本人の PR を母集団にする

認証済み `gh` で、現在の repository における author `@me`、merged、mergedAt が期間内の PR を列挙する。Draft 作成時刻は PR の createdAt とし、`lead_time_median_h` は createdAt から mergedAt まで、`merged_count` はその PR 数とする。

品質は、それぞれの merge 時刻から 7 日後までに同じ repository で作成された `bug` ラベル付き issue の集合を取り、重なる窓に入る同一 issue は一度だけ数える。PR との因果関係を推定せず「merge 後 7 日窓に観測された bug issue 数」として出力する。

`gh` 失敗、未認証、repository を解決できない場合は、不正なゼロのベースラインを残さないため集計を非 0 で止める。テストでは PATH 上の fake `gh` を使う。

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

## Risks / Trade-offs

- **[役割名や meta schema が変わり分類精度が落ちる]** → 一致しないものを `other` に残し、分類件数を出す。生プロンプトの保存や広い本文推測はしない。
- **[全 JSONL 走査が重い]** → 期間を timestamp で早期除外し、1 回の走査で全ローカル指標を作る。別々のスクリプトで同じログを繰り返し読まない。
- **[GitHub 検索の揺れや API 制限]** → query 条件を stderr に示し、失敗時は非 0。fixture テストは fake `gh` で固定する。
- **[15 分規則が短い作業の最後を過小評価する]** → 最終行への恣意的な固定加算を避け、前後比較で同じ規則を使う。絶対的な勤怠時間として扱わない。
- **[pace の欠測で週次換算が偏る]** → 2 点未満の reset 窓を計算せず warnings に残す。導入手順に日次実行とログ確認を含める。
- **[ローカルログに機微情報がある]** → 出力は数値と分類だけに限定し、プロンプト、cwd、securestorage、認証情報を出力・永続化しない。

## Migration Plan

1. fixture ベースの Red テストを追加し、既存 `cost_ledger.py` の公開出力を回帰テストで固定する。
2. 共通解析と weekly metrics、usage pace recorder、README の手動導入手順を実装する。
3. `scripts/test.sh` と OpenSpec validate を通す。利用者環境への launchd 登録は行わない。
4. マージ後に利用者が日次記録を有効化し、3 日分以上を蓄積する。
5. 2026-09-01〜09-21 のコマンド結果を整形し、epic #360 にベースラインとして投稿する。

ロールバックは追加スクリプトと文書を戻すだけで、既存 `/cost` の保存データ移行はない。利用者が登録した日次ジョブは導入手順に記載する解除方法で停止する。

## Open Questions

なし。実ログの蓄積と epic 投稿は実装後運用として、コード変更とは別に完了確認する。
