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

システムは Claude Code のメインセッションと固定深さ `*/*/subagents/agent-*.jsonl` のサブエージェントを別の母集団として集計しなければならない（SHALL）。weekly metrics は各母集団で usage 付き assistant メッセージを、空でない `message.id`、無ければ `requestId`、それも無ければ `uuid` の優先順で、キー種別を含む組を鍵として重複排除しなければならない（MUST）。3 つとも無い行は除外して warnings に数えなければならない（MUST）。`turns` は重複排除後の件数、`ctx_per_turn` は `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` の平均、`cost_usd` は既存 cost-ledger の料金表と計算規則による API 換算コストでなければならない（MUST）。

この message-ID 優先規則は weekly metrics のみに適用し、既存 `/cost` と `cost-ledger-attribution` の `requestId`（無ければ `uuid`）基準の重複排除を変更してはならない（MUST NOT）。共有 helper を導入する場合も両 policy を呼び出し側で分離しなければならない（MUST）。

`main` と `sub` はそれぞれ `turns` / `ctx_per_turn` / `cost_usd` を持ち、`sub` は加えて `by_role` / `model_share` を持たなければならない（MUST）。Workflow 配下など固定深さの glob に入らない transcript をサブエージェント母集団へ混ぜてはならない（MUST NOT）。不正な JSON 行または必要フィールドが不正な行で全体を中断せず、除外件数を `warnings` に出さなければならない（MUST）。

#### Scenario: 同じメッセージ ID を一度だけ数える

- **WHEN** 同じ message ID と usage を持つが request ID は異なる assistant レコードが複数ファイルにある
- **THEN** 対応する母集団の turns、読み込み量、コストには 1 回だけ反映される

#### Scenario: message ID がない行は request ID へ fallback する

- **WHEN** message ID がない二つの usage 付き assistant レコードが同じ request ID を持つ
- **THEN** weekly metrics では一度だけ数えられ、message ID と request ID の両方がない場合は uuid が使われる

#### Scenario: 既存 cost コマンドの重複排除を変えない

- **WHEN** 同じ message ID だが異なる request ID を持つ fixture を既存 `cost_ledger.py cost` と weekly metrics の両方で集計する
- **THEN** weekly metrics は 1 件、既存 cost コマンドは従来どおり request ID ごとの 2 件として扱う

#### Scenario: 読み込み量の平均を共通定義で出す

- **WHEN** input、cache creation、cache read が異なる複数ターンを集計する
- **THEN** main と sub の `ctx_per_turn` は各ターンの 3 種トークン合計の算術平均になる

#### Scenario: 壊れた行を可視化して集計を続ける

- **WHEN** 対象 transcript に不正 JSON と有効な usage 行が混在する
- **THEN** 有効行の指標が出力され、除外件数が warnings に現れる

### Requirement: サブエージェントを役割と起動時モデルで分類する

システムはサブエージェント transcript ごとに、起動プロンプトの最初の空でない 1 行と transcript / 隣接 meta の basename だけから、優先順 `decider` / `gate-runner` / `worker` / `other` のいずれか一つへ分類しなければならない（MUST）。候補を Unicode NFKC と ASCII 小文字へ正規化し、英数字・`_`・`-`・`:` の境界を持つ literal として、decider は `dev-workflow:decider` / `role: decider` / basename の `decider`、gate-runner は `gate-runner` / `role: gate` / `role: gate-runner` / `ゲート実行者 g` / basename の `gate-runner`、worker は `role: spec-write` / `role: implement` / `role: archive` / `作業者 w` / basename の `worker` に一致した場合だけ分類しなければならない（MUST）。会話途中、起動プロンプトの 2 行目以降、単語内部の部分一致を分類に使ってはならない（MUST NOT）。`sub.by_role` は 4 役割すべてについて turns、ctx_per_turn、cost_usd、active_h、starts を持たなければならない（MUST）。分類に用いたプロンプト本文や path を出力してはならない（MUST NOT）。

起動時刻は JSONL 全行で最初の有効な timestamp としなければならない（SHALL）。起動時モデルは meta JSON の model、無ければ最初の usage 付き assistant メッセージの model を使い、Opus / Sonnet / Fable / Haiku / other に正規化しなければならない（SHALL）。`starts` と `sub.model_share` は起動時刻が比較期間内の transcript だけを分母・分子へ含めなければならない（MUST）。期間前に起動して期間内に usage または稼働 interval を持つ transcript は turns / cost / active time と役割別集計へ含める一方、starts / model share へ含めてはならない（MUST NOT）。起動時刻を確定できない transcript は starts / model share から除外して warnings に数えなければならない（MUST）。

#### Scenario: 明示された4役割を一意に分類する

- **WHEN** fixture に gate-runner、worker、decider を示す起動情報と、どれにも一致しない transcript がある
- **THEN** 各 transcript は優先順に従って 4 役割の一つだけに数えられる

#### Scenario: 起動数を分母にモデル比率を出す

- **WHEN** Opus 起動 1 件が 10 ターン、Sonnet 起動 1 件が 1 ターンを持つ
- **THEN** `sub.model_share.opus` と `sub.model_share.sonnet` はそれぞれ 0.5 になる

#### Scenario: 期間前に起動した transcript の継続分だけを集計する

- **WHEN** worker transcript が期間前に起動し、期間内にも usage 行と 15 分以下の interval を持つ
- **THEN** worker の turns、cost、active_h には期間内分が入るが starts は増えず、その起動モデルは model_share の分母・分子に入らない

#### Scenario: 生プロンプトを漏らさない

- **WHEN** 起動プロンプトに固有の秘密文字列が含まれる
- **THEN** weekly metrics の JSON と warnings にその文字列は現れない

### Requirement: 15分を超える空白を除外して稼働時間を計算する

システムは transcript ごとに、usage と message type の有無を問わず、有効な timestamp を持つ JSONL の全行を timestamp 順に並べなければならない（MUST）。隣接行の元の間隔が 0 秒以上 15 分以下の場合だけ、その interval と UTC 比較期間 `[since 00:00:00, until 翌日 00:00:00)` の共通部分を稼働時間へ加えなければならない（MUST）。15 分を超える interval は期間境界で切った共通部分が 15 分以下でも全体をアイドルとして除外し、別 transcript 同士の timestamp をつないではならない（MUST NOT）。期間境界をまたぐ interval の判定に必要な直前・直後の隣接行は読み、期間外部分は加算してはならない（MUST NOT）。最後の 1 行へ固定時間を加えてはならない（MUST NOT）。timestamp 不正の行は除外して warnings に数えなければならない（MUST）。

出力は `time.main_active_h` / `time.sub_active_h` / `time.by_role` を持ち、`time.by_role` は `gate-runner` / `worker` / `decider` / `other` の時間を持たなければならない（MUST）。

#### Scenario: 15分以下の interval だけを足す

- **WHEN** 同一 transcript で assistant、user、tool-result、assistant の各行の timestamp 間隔が 10 分、15 分、16 分である
- **THEN** 稼働時間には最初の 25 分だけが加算される

#### Scenario: usage のない行も interval を構成する

- **WHEN** usage 付き assistant 00:00、usage のない user 00:10、tool-result 00:20 が同じ transcript にある
- **THEN** 2 本の 10 分 interval が有効となり、稼働時間は 20 分になる

#### Scenario: 期間境界をまたぐ interval を切り取る

- **WHEN** 期間開始 5 分前と開始 5 分後に隣接行がある
- **THEN** 元の 10 分 interval は有効と判定され、期間内の 5 分だけが加算される

#### Scenario: 境界で切ってもアイドル判定を変えない

- **WHEN** 期間開始 20 分前と開始 5 分後に隣接行がある
- **THEN** 元の interval が 25 分なので、期間内の 5 分も加算されない

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

`plugins/cost-ledger/scripts/usage-pace-log.sh` は usage snapshot から logger の実行時刻 `recorded_at` と、各アカウント ID の `fetched_at` / `weekly_all_pct` / `weekly_resets_epoch` を読み、`${USAGE_PACE_LOG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/usage-pace.log}` へ 1 回の実行につき 1 行の JSON を追記しなければならない（MUST）。`accounts.<id>.fetched_at` はその account の値を実際に取得した観測時刻として保存し、`recorded_at` で置き換えてはならない（MUST NOT）。snapshot に存在する複数アカウントは、値が欠けた account も null の 3 キーを持つ別系列として同じ行に保持しなければならない（MUST）。アカウントラベル、securestorage パス、OAuth token、生 API 応答をログへ書いてはならない（MUST NOT）。snapshot が存在しない、不正、または 3 値がすべて有効な account が一つも無い場合は行を追記せず非 0 で終了しなければならない（MUST）。

README は手動実行、ログ確認、launchd または同等の日次 scheduler への登録例、解除方法を記載しなければならない（SHALL）。実装・テストは利用者環境へ scheduler を登録してはならない（MUST NOT）。

#### Scenario: AとBを同じ日次レコードへ残す

- **WHEN** snapshot にアカウント A と B の weekly_all_pct と reset epoch がある
- **THEN** 追記された 1 行 JSON は A と B を別キーで保持し、それぞれの fetched_at を含み、どちらの認証情報も含まない

#### Scenario: stale account の観測時刻を新しく見せない

- **WHEN** A は新しい fetched_at、B は fail-open で前回と同じ fetched_at と値を持つ snapshot を翌日も記録する
- **THEN** B の fetched_at は前回値のまま保存され、集計では同じ B 観測が 2 日分として扱われない

#### Scenario: 一部 account の欠測を保持する

- **WHEN** A の 3 値は有効だが B の fetched_at と usage 値が null の snapshot を記録する
- **THEN** 行は追記され、B は null を持つ欠測系列として残り、0 消費の観測にはならない

#### Scenario: 不正 snapshot を追記しない

- **WHEN** snapshot が途中書き込みまたは不正 JSON である
- **THEN** usage pace log の行数は増えず、スクリプトは非 0 になる

#### Scenario: scheduler 登録は利用者の明示操作である

- **WHEN** 実装後の repository のテストとセットアップを実行する
- **THEN** launchd / cron の登録状態は変わらず、README の手順を利用者が実行した場合だけ日次ジョブが追加される

### Requirement: 週次枠ペースを reset 窓ごとに7日換算する

システムは pace log の観測を `(account ID, fetched_at)` で識別し、3 値が同じ再記録は一つに重複排除しなければならない（MUST）。同じ identity で `weekly_all_pct` または `weekly_resets_epoch` が衝突する場合はその identity 全体を除外し、warnings に出さなければならない（MUST）。`fetched_at` / pct / reset のいずれかが null または不正な account entry は欠測であり、`recorded_at` を観測時刻に代用したり pct 0 として扱ったりしてはならない（MUST NOT）。

システムは有効な観測を account ID と同一 `weekly_resets_epoch` の窓で分け、reset の直前 7 日かつ比較期間内にある観測のうち、7 つ以上の異なる UTC 観測日と正の経過時間を持つ窓だけについて、最初と最後の `weekly_all_pct` の差を `fetched_at` の経過日数で割って 7 倍しなければならない（MUST）。reset 境界をまたぐ値を連結してはならない（MUST NOT）。負の差、7 観測日未満の部分窓、経過時間 0 の窓は projection を JSON `null` として `pace.by_account.<id>.windows` に残し、warnings に出さなければならない（MUST）。

`pace.by_account.<id>.weekly_avg_pct` はその account の有効な projection の算術平均、または有効窓 0 件なら `null` でなければならない（MUST）。`pace.weekly_sum_pct` は、期間内の pace log に現れる全 account が少なくとも一つ有効窓を持つ場合だけ、account ごとの `weekly_avg_pct` の合計でなければならない（MUST）。account ごとに reset 日または有効窓数が違っても共通の週数を分母にしてはならない（MUST NOT）。片方の account が欠測、全 account の有効窓が 0、または期間内 pace log が 0 行の場合、`pace.weekly_sum_pct` キーを必ず出して値を `null` とし、0 にしてはならない（MUST）。部分窓は分子にも分母にも 0 として入れてはならない（MUST NOT）。

#### Scenario: アカウント別に7日換算する

- **WHEN** 7 日の経過時間と7つ以上の UTC 観測日がある有効な reset 窓で A が 70 ポイント、B が 35 ポイント増える
- **THEN** by_account の7日換算は A が 70、B が 35 となり、その週の合計は 105 になる

#### Scenario: reset をまたいだ減少を消費にしない

- **WHEN** weekly_all_pct が reset 前の 90 から reset 後の 5 に変わる
- **THEN** -85 を同一 interval の消費として使わず、別の reset 窓として扱う

#### Scenario: reset 日が違う account を別々の分母で平均する

- **WHEN** A は有効窓 2 件、reset 日の違う B は有効窓 1 件を持つ
- **THEN** A は 2 件、B は 1 件をそれぞれの分母で平均し、その二つの account 平均を weekly_sum_pct へ合算する

#### Scenario: 部分週を0として平均しない

- **WHEN** A の reset 窓に 6 つの UTC 観測日しかない
- **THEN** その窓の projection は null で、A の有効窓数、平均の分子、平均の分母に入らず warnings に現れる

#### Scenario: 一方の account が欠測なら合計も欠測である

- **WHEN** A は有効窓を持つが、期間内ログに現れる B は null entry または部分窓だけで有効窓を持たない
- **THEN** A の by_account 値は出る一方、`pace.weekly_sum_pct` は null になる

#### Scenario: ベースライン期間に記録がなければnullである

- **WHEN** 2026-09-01〜09-21 の pace log が 0 行である
- **THEN** `pace.weekly_sum_pct` キーは存在して値が null となり、将来取得する3日分の記録で過去期間を補完しない

#### Scenario: 7日分以上の記録がある週は値を出す

- **WHEN** 比較期間の全 account に同一 reset 窓内の7つ以上の UTC 観測日があり、値が単調増加する
- **THEN** `pace.weekly_sum_pct` は null ではない number になる

### Requirement: PRリードタイムとマージ後の品質をGitHubから集計する

システムは認証済み `gh` から現在の repository と login を解決し、REST の closed pulls endpoint を `per_page=100` と `--paginate` で全ページ取得しなければならない（MUST）。REST 応答の `user.login` が本人、`merged_at` が null でなく指定期間内の PR を母集団とし、`created_at` から `merged_at` までの中央値を `pr.lead_time_median_h`、件数を `pr.merged_count` に出さなければならない（MUST）。`mergedAt` を出せない `gh search prs --json` や、その既定 30 件だけをデータ取得に使ってはならない（MUST NOT）。

システムは同じ repository の REST issues endpoint も `per_page=100` と `--paginate` で全ページ取得し、`pull_request` field を持たない `bug` ラベル付き issue を選ばなければならない（MUST）。各対象 PR の `merged_at` から 7 日以内に `created_at` が入る issue の集合を取り、重なる窓に入る同一 issue number を一度だけ数えた値を `quality.bug_issues_7d` に出さなければならない（MUST）。この値を個別 PR が原因である件数として表現してはならない（MUST NOT）。

`gh` が失敗する、未認証である、または repository を解決できない場合は、GitHub 指標を 0 として成功させず、理由を stderr に出して非 0 にしなければならない（MUST）。

#### Scenario: Draft作成からマージまでを測る

- **WHEN** 期間内に createdAt から mergedAt まで 10 時間と 20 時間の本人 PR がある
- **THEN** `pr.lead_time_median_h` は 15、`pr.merged_count` は 2 になる

#### Scenario: 全ページのマージ済みPRを数える

- **WHEN** fake gh の REST 応答が実 API と同じ `created_at` / `merged_at` / `user.login` を持つ複数ページで、2ページ目にも期間内の本人 PR がある
- **THEN** 2ページ目の PR も lead time と merged_count に含まれる

#### Scenario: 重なる7日窓のbug issueを重複させない

- **WHEN** 一つの bug issue が二つの対象 PR のマージ後7日窓の両方に入る
- **THEN** `quality.bug_issues_7d` には 1 件として数えられる

#### Scenario: bug issue も全ページを取得する

- **WHEN** fake gh の REST issues 応答の2ページ目に対象マージ後7日窓内の bug issue がある
- **THEN** その issue は `quality.bug_issues_7d` に含まれ、同じ number が別ページに再出現しても一度だけ数えられる

#### Scenario: GitHub取得失敗をゼロに見せない

- **WHEN** `gh` が認証エラーで PR 一覧を返せない
- **THEN** weekly metrics は非 0 で終了し、GitHub 指標が 0 の JSON をベースラインとして出さない

### Requirement: fixtureで全指標を検証し実ホームを読まない

テストは projects root、usage snapshot、usage pace log、料金表、`gh` 応答を fixture または環境変数で差し替え、実際の home、GitHub repository、認証情報、scheduler 設定を読み書きしてはならない（MUST NOT）。fixture は同一 message ID・異なる request ID、既存 `/cost` との policy 境界、4 役割の完全一致と紛らわしい非一致、期間前起動、4 モデル、usage のない user/tool-result 行、15 分境界と期間境界、stale fetched_at と account 欠測、partial/reset 日が違う複数 account、有効窓 0 件、複数ページの実 REST 形式 PR、bug issue の重なる窓を含まなければならない（SHALL）。

`scripts/test.sh` は weekly metrics と usage pace logger のテストを含み、既存 cost-ledger CLI の回帰テストとともに exit 0 にならなければならない（MUST）。

#### Scenario: 受け入れ条件のjqが成功する

- **WHEN** fixture に対して `weekly-metrics.sh --since 2026-09-01 --until 2026-09-21` を実行する
- **THEN** 出力へ issue #362 記載の jq 式を適用すると exit 0 になる

#### Scenario: pace欠測の受け入れ条件を区別する

- **WHEN** pace 記録のない 2026-09-01〜09-21 と、全 account に7日分以上ある期間をそれぞれ集計する
- **THEN** 前者は `has("weekly_sum_pct")` が true かつ値が null、後者は `.pace.weekly_sum_pct != null` が true になる

#### Scenario: テストで利用者環境を変更しない

- **WHEN** cost-ledger のテスト一式を実行する
- **THEN** fixture 用一時ディレクトリ以外の usage pace log、home、launchd / cron 設定は変更されない

### Requirement: 実データ蓄積とepic投稿を実装後運用として引き渡す

README は、実装・マージ後に usage pace log を 3 日分以上蓄積して `wc -l` が 3 以上であることを確認する手順と、2026-09-01〜09-21 の JSON を表へ整形して epic #360 に「ベースライン 2026-09-01〜09-21」として投稿する手順を記載しなければならない（SHALL）。この期間には pace 記録が存在しないため `pace.weekly_sum_pct: null` を欠測として明記し、将来の3日分を過去へ補完したり 0 と表記したりしてはならない（MUST NOT）。これらの実データ生成と GitHub コメント投稿を repository のテストや実装工程で自動実行してはならない（MUST NOT）。

#### Scenario: 実装だけでは運用条件を完了扱いにしない

- **WHEN** scripts、tests、README の変更が完了したが、日次運用をまだ3日行っていない
- **THEN** コード検証は完了できる一方、3日分ログと epic ベースライン投稿は残る運用 handoff として明示される
