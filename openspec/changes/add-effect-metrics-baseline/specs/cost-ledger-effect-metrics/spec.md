## ADDED Requirements

### Requirement: 期間指定の効果メトリクスを 1 行 JSON で出力する

`plugins/cost-ledger/scripts/weekly-metrics.sh` は `--since YYYY-MM-DD --until YYYY-MM-DD` を受け取り、UTC で since 日の 00:00:00 以上、until 翌日の 00:00:00 未満を対象に、標準出力へ 1 行の有効な JSON を出さなければならない（MUST）。JSON はトップレベルに `period` / `main` / `sub` / `gate` / `pace` / `pr` / `quality` / `time` / `warnings` を持たなければならない（MUST）。進捗と診断は stderr に出し、stdout の JSON に混ぜてはならない（MUST NOT）。

日付形式が不正、または since が until より後なら、説明を stderr に出して非 0 で終了しなければならない（MUST）。

#### Scenario: 指定期間の JSON が一行で出る

- **WHEN** fixture の全入力が揃った状態で `weekly-metrics.sh --since 2026-09-01 --until 2026-09-21` を実行する
- **THEN** stdout は改行で終わる 1 行の JSON で、必須トップレベルキーをすべて持ち、exit 0 になる

#### Scenario: 期間の終端日を含む

- **WHEN** until 日の 23:59:59Z と until 翌日の 00:00:00Z にレコードがある
- **THEN** 前者だけが集計に含まれる

#### Scenario: 日付範囲が不正である

- **WHEN** since が until より後、またはいずれかが `YYYY-MM-DD` でない
- **THEN** JSON を出さず、理由を stderr に出して非 0 になる

### Requirement: メインとサブエージェントの消費を同じ定義で集計する

システムは Claude Code のメインセッションと固定深さ `*/*/subagents/agent-*.jsonl` のサブエージェントを別の母集団として集計しなければならない（SHALL）。各母集団で usage 付き assistant メッセージを `requestId`、無ければ `message.id`、それも無ければ `uuid` で重複排除し、`turns` をその件数、`ctx_per_turn` を `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` の平均、`cost_usd` を既存 cost-ledger の料金表と計算規則による API 換算コストとしなければならない（MUST）。

`main` と `sub` はそれぞれ `turns` / `ctx_per_turn` / `cost_usd` を持ち、`sub` は加えて `by_role` / `model_share` を持たなければならない（MUST）。Workflow 配下など固定深さの glob に入らない transcript をサブエージェント母集団へ混ぜてはならない（MUST NOT）。不正な JSON 行または必要フィールドが不正な行で全体を中断せず、除外件数を `warnings` に出さなければならない（MUST）。

#### Scenario: 同じメッセージ ID を一度だけ数える

- **WHEN** 同じ usage と message ID を持つ assistant レコードが複数ファイルにある
- **THEN** 対応する母集団の turns、読み込み量、コストには 1 回だけ反映される

#### Scenario: 読み込み量の平均を共通定義で出す

- **WHEN** input、cache creation、cache read が異なる複数ターンを集計する
- **THEN** main と sub の `ctx_per_turn` は各ターンの 3 種トークン合計の算術平均になる

#### Scenario: 壊れた行を可視化して集計を続ける

- **WHEN** 対象 transcript に不正 JSON と有効な usage 行が混在する
- **THEN** 有効行の指標が出力され、除外件数が warnings に現れる

### Requirement: サブエージェントを役割と起動時モデルで分類する

システムはサブエージェント transcript ごとに、起動プロンプト先頭の明示語と transcript / meta ファイル名だけから、優先順 `decider` / `gate-runner` / `worker` / `other` のいずれか一つへ分類しなければならない（MUST）。`sub.by_role` は 4 役割すべてについて turns、ctx_per_turn、cost_usd、active_h、starts を持たなければならない（MUST）。分類に用いたプロンプト本文を出力してはならない（MUST NOT）。

起動時モデルは meta JSON の model、無ければ最初の usage 付き assistant メッセージの model を使い、Opus / Sonnet / Fable / Haiku / other に正規化しなければならない（SHALL）。`sub.model_share` は各モデルの transcript 起動数を全 transcript 起動数で割った比率でなければならず、ターン数を分母にしてはならない（MUST NOT）。

#### Scenario: 明示された4役割を一意に分類する

- **WHEN** fixture に gate-runner、worker、decider を示す起動情報と、どれにも一致しない transcript がある
- **THEN** 各 transcript は優先順に従って 4 役割の一つだけに数えられる

#### Scenario: 起動数を分母にモデル比率を出す

- **WHEN** Opus 起動 1 件が 10 ターン、Sonnet 起動 1 件が 1 ターンを持つ
- **THEN** `sub.model_share.opus` と `sub.model_share.sonnet` はそれぞれ 0.5 になる

#### Scenario: 生プロンプトを漏らさない

- **WHEN** 起動プロンプトに固有の秘密文字列が含まれる
- **THEN** weekly metrics の JSON と warnings にその文字列は現れない

### Requirement: 15分を超える空白を除外して稼働時間を計算する

システムは transcript ごとに usage 付き assistant 行を timestamp 順に並べ、隣接行の間隔が 0 秒以上 15 分以下の場合だけ、その差分全体を稼働時間へ加えなければならない（MUST）。15 分を超える interval は全体をアイドルとして除外し、別 transcript 同士の timestamp をつないではならない（MUST NOT）。最後の 1 行へ固定時間を加えてはならない（MUST NOT）。

出力は `time.main_active_h` / `time.sub_active_h` / `time.by_role` を持ち、`time.by_role` は `gate-runner` / `worker` / `decider` / `other` の時間を持たなければならない（MUST）。

#### Scenario: 15分以下の interval だけを足す

- **WHEN** 同一 transcript の timestamp 間隔が 10 分、15 分、16 分である
- **THEN** 稼働時間には最初の 25 分だけが加算される

#### Scenario: 並行 transcript を直列につながない

- **WHEN** 二つの transcript の行が時刻順に交互に現れる
- **THEN** それぞれの transcript 内 interval だけが計算され、ファイルをまたぐ interval は加算されない

### Requirement: gate-runner 指標を PR 単位で出す

システムは gate-runner の起動情報から repository と PR 番号を取り出し、同じ PR に属する transcript のターン数、読み込み量、稼働時間を合算した後、対象 PR 間の中央値を `gate.turns_per_pr` / `gate.ctx_per_pr` / `gate.minutes_per_pr` として出さなければならない（MUST）。PR を識別できない gate-runner は `sub` と役割別集計には含める一方、PR 単位の分母から除外し、その件数を warnings に出さなければならない（MUST）。

#### Scenario: 同じ PR の複数起動を先に合算する

- **WHEN** 同じ PR に gate-runner が 2 回起動され、別の PR に 1 回起動されている
- **THEN** 同じ PR の値を合算した二つの PR 値から各中央値が計算される

#### Scenario: PR 不明の gate-runner を分母から外す

- **WHEN** PR 番号を識別できない gate-runner transcript がある
- **THEN** その消費と時間は sub と `by_role["gate-runner"]` に含まれるが、gate の PR 中央値には含まれず warnings に件数が出る

### Requirement: usage snapshot をアカウント別の日次 JSONL に追記する

`plugins/cost-ledger/scripts/usage-pace-log.sh` は usage snapshot から実行 timestamp と各アカウント ID の `weekly_all_pct` / `weekly_resets_epoch` だけを読み、`${USAGE_PACE_LOG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/usage-pace.log}` へ 1 回の実行につき 1 行の JSON を追記しなければならない（MUST）。複数アカウントは同じ行の別系列として保持しなければならない（MUST）。アカウントラベル、securestorage パス、OAuth token、生 API 応答をログへ書いてはならない（MUST NOT）。snapshot が存在しない、不正、または必要な usage 値が一つも無い場合は行を追記せず非 0 で終了しなければならない（MUST）。

README は手動実行、ログ確認、launchd または同等の日次 scheduler への登録例、解除方法を記載しなければならない（SHALL）。実装・テストは利用者環境へ scheduler を登録してはならない（MUST NOT）。

#### Scenario: AとBを同じ日次レコードへ残す

- **WHEN** snapshot にアカウント A と B の weekly_all_pct と reset epoch がある
- **THEN** 追記された 1 行 JSON は A と B を別キーで保持し、どちらの認証情報も含まない

#### Scenario: 不正 snapshot を追記しない

- **WHEN** snapshot が途中書き込みまたは不正 JSON である
- **THEN** usage pace log の行数は増えず、スクリプトは非 0 になる

#### Scenario: scheduler 登録は利用者の明示操作である

- **WHEN** 実装後の repository のテストとセットアップを実行する
- **THEN** launchd / cron の登録状態は変わらず、README の手順を利用者が実行した場合だけ日次ジョブが追加される

### Requirement: 週次枠ペースを reset 窓ごとに7日換算する

システムは usage pace log をアカウント ID と同一 `weekly_resets_epoch` の窓で分け、各窓の最初と最後の `weekly_all_pct` の差を経過日数で割って 7 倍した値を計算しなければならない（MUST）。reset 境界をまたぐ値を連結してはならない（MUST NOT）。2 点未満または経過時間 0 の窓は計算せず warnings に出さなければならない（MUST）。

`pace.by_account` はアカウント別の各窓の換算値を保持し、`pace.weekly_sum_pct` は比較期間に重なる各週・各アカウントの換算値の合計を週数で平均した値でなければならない（MUST）。

#### Scenario: アカウント別に7日換算する

- **WHEN** 同じ reset 窓で A が 2 日間に 20 ポイント、B が 2 日間に 10 ポイント増える
- **THEN** by_account の7日換算は A が 70、B が 35 となり、その週の合計は 105 になる

#### Scenario: reset をまたいだ減少を消費にしない

- **WHEN** weekly_all_pct が reset 前の 90 から reset 後の 5 に変わる
- **THEN** -85 を同一 interval の消費として使わず、別の reset 窓として扱う

### Requirement: PRリードタイムとマージ後の品質をGitHubから集計する

システムは認証済み `gh` を用い、現在の repository で author が `@me`、mergedAt が指定期間内の PR を母集団とし、createdAt から mergedAt までの中央値を `pr.lead_time_median_h`、件数を `pr.merged_count` に出さなければならない（MUST）。

各対象 PR の mergedAt から 7 日以内に同じ repository で作成された `bug` ラベル付き issue の集合を取り、重なる窓に入る同一 issue を一度だけ数えた値を `quality.bug_issues_7d` に出さなければならない（MUST）。この値を個別 PR が原因である件数として表現してはならない（MUST NOT）。

`gh` が失敗する、未認証である、または repository を解決できない場合は、GitHub 指標を 0 として成功させず、理由を stderr に出して非 0 にしなければならない（MUST）。

#### Scenario: Draft作成からマージまでを測る

- **WHEN** 期間内に createdAt から mergedAt まで 10 時間と 20 時間の本人 PR がある
- **THEN** `pr.lead_time_median_h` は 15、`pr.merged_count` は 2 になる

#### Scenario: 重なる7日窓のbug issueを重複させない

- **WHEN** 一つの bug issue が二つの対象 PR のマージ後7日窓の両方に入る
- **THEN** `quality.bug_issues_7d` には 1 件として数えられる

#### Scenario: GitHub取得失敗をゼロに見せない

- **WHEN** `gh` が認証エラーで PR 一覧を返せない
- **THEN** weekly metrics は非 0 で終了し、GitHub 指標が 0 の JSON をベースラインとして出さない

### Requirement: fixtureで全指標を検証し実ホームを読まない

テストは projects root、usage snapshot、usage pace log、料金表、`gh` 応答を fixture または環境変数で差し替え、実際の home、GitHub repository、認証情報、scheduler 設定を読み書きしてはならない（MUST NOT）。fixture は重複 ID、4 役割、4 モデル、15 分境界、複数 PR、reset 境界、bug issue の重なる窓を含まなければならない（SHALL）。

`scripts/test.sh` は weekly metrics と usage pace logger のテストを含み、既存 cost-ledger CLI の回帰テストとともに exit 0 にならなければならない（MUST）。

#### Scenario: 受け入れ条件のjqが成功する

- **WHEN** fixture に対して `weekly-metrics.sh --since 2026-09-01 --until 2026-09-21` を実行する
- **THEN** 出力へ issue #362 記載の jq 式を適用すると exit 0 になる

#### Scenario: テストで利用者環境を変更しない

- **WHEN** cost-ledger のテスト一式を実行する
- **THEN** fixture 用一時ディレクトリ以外の usage pace log、home、launchd / cron 設定は変更されない

### Requirement: 実データ蓄積とepic投稿を実装後運用として引き渡す

README は、実装・マージ後に usage pace log を 3 日分以上蓄積して `wc -l` が 3 以上であることを確認する手順と、2026-09-01〜09-21 の JSON を表へ整形して epic #360 に「ベースライン 2026-09-01〜09-21」として投稿する手順を記載しなければならない（SHALL）。これらの実データ生成と GitHub コメント投稿を repository のテストや実装工程で自動実行してはならない（MUST NOT）。

#### Scenario: 実装だけでは運用条件を完了扱いにしない

- **WHEN** scripts、tests、README の変更が完了したが、日次運用をまだ3日行っていない
- **THEN** コード検証は完了できる一方、3日分ログと epic ベースライン投稿は残る運用 handoff として明示される
