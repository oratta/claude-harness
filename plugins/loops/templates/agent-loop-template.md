# 自律開発ループ憲法（agent-loop）

> このファイルは自律開発ループの「1サイクルの手順書」であり、ループの実行系ではない。
> 反復は `/loop`（ネイティブプリミティブ）が担い、本ファイルは毎サイクル読み直される前提で書かれている。
> 生成元: `plugins/loops/templates/agent-loop-template.md`（`/loops:dev-agent-install` が値を埋めて配置する）。
> レシピ本体: `plugins/loops/recipes/loop-dev-agent.md`。

## プロジェクト設定

| 項目 | 値 |
|---|---|
| main ブランチ | {{MAIN_BRANCH}} |
| テストコマンド | `{{TEST_CMD}}` |
| lint コマンド | `{{LINT_CMD}}` |
| ビルドコマンド | `{{BUILD_CMD}}` |
| dev サーバー起動 | `{{DEV_SERVER_CMD}}`（URL: {{DEV_URL}}） |
| ブラウザ実機検証 | {{BROWSER_VERIFY}} |
| worktree 置き場 | `{{WORKTREE_BASE}}` |
| レート上限 | 5時間枠 {{RATE_5H_MAX}}% / 7日枠 {{RATE_7D_MAX}}% |
| 朝ダイジェスト | {{DIGEST_HOUR}} 時以降のその日最初のサイクル |
| 提案ストック上限 | {{PROPOSAL_CAP}} 件 |
| Review Queue Project | {{REVIEW_QUEUE}}（`<owner>/<番号>` 形式。`なし` なら連携をスキップ） |

## 大原則（全モード共通・違反禁止）

1. **1サイクル1仕事**。複数の issue / PR を1サイクルで扱わない。
2. **{{MAIN_BRANCH}} へのマージ・直接 push・コミットは絶対にしない**（push は permission deny ルールと pre-push フックで封鎖済み。マージは人間の仕事）。ループが main チェックアウトで行ってよいのは `.agent-loop/` 配下（git 管理外）への追記だけ。ループが main を動かすと origin と恒常的に分岐し、人間のマージ作業が再生産されるため。
3. **完了・合格の宣言には必ず証拠を付ける**。実行したコマンドと exit code・出力の要約をターン内に表示してから宣言する。自己申告のみの「完了」は禁止。
4. サイクル冒頭で `.agent-loop/GUARDRAILS.md` が存在すれば読む。サイクル中に得た教訓（踏んだ地雷・回避策）があれば1行追記し、**同じ内容を GUARDRAILS バックアップ issue（タイトル「GUARDRAILS: ループの教訓集」）にもコメントする**（ローカルファイルは git 管理外のため、耐久コピーは GitHub 側に置く）。
5. サイクル終了時に `.agent-loop/log.md` に実行ログを1行追記する（形式は末尾）。コミットはしない。サイクル結果の正式な記録は issue / PR へのコメントであり、ローカルのログは朝ダイジェスト集計用のキャッシュにすぎない。
6. 実装前に必ず codebase を grep して既存実装を確認する。「未実装」と決めつけて二重実装しない。
7. プレースホルダ・空実装・コンパイルを通すだけの実装で済ませない。

## コンテキスト管理（ディスパッチャ方式）

ループセッション（メイン）のコンテキストはサイクルを跨いで蓄積するため、メインは**配車係に徹する**。

1. メインが自分で行うのは: レートガード（Step 0）、朝ダイジェスト（Step 0.5）、モード判定と対象選定（gh クエリ）、サブエージェントへの委譲、ログ追記、結果報告のみ。
2. 各モードの作業本体（Step 1 のレビュー、Step 2 の修正、Step 3 の実装、Step 4 の調査・起票文案）は**サブエージェントに委譲**し、毎回まっさらなコンテキストで実行させる。メイン自身でファイルを読み込んで作業しない。
3. サブエージェントへ渡すもの: 本憲法ファイルのパス（該当 Step を読んで従うよう指示）、対象の issue / PR 番号、`.agent-loop/GUARDRAILS.md` のパス。
4. サブエージェントから受け取るもの: 結果サマリ（実行したコマンドと exit code の証拠、作成した PR / コメントの URL を含む）。メインはそれをログと報告に転記する。
5. 作業中の詳細（ファイル内容・テスト出力・試行錯誤）はサブエージェント側に閉じ、サイクル終了とともに破棄される。長期稼働でメインのコンテキストが自動要約されても、状態はすべて外部（ラベル・issue / PR コメント・`.agent-loop/`）にあるため失われて困る記憶はない。

## ラベル定義

| ラベル | 対象 | 意味 |
|---|---|---|
| `agent-ready` | issue | 人間が承認済み。ループが拾ってよい |
| `agent-proposed` | issue | ループの自己生成タスク案。人間が `agent-ready` に昇格するまで実行禁止 |
| `agent-wip` | issue | ループが着手中（二重着手防止） |
| `agent-blocked` | issue | 2回失敗して隔離。人間の判断待ち |
| `needs-approval` | issue | 準備までは可、実行に人間の承認が必要 |
| `human-only` | issue | ループは触らない（秘密情報・外部アカウント・設計判断など） |
| `size:large` | issue | 1サイクルに収まらない大型。着手せず分割提案のみ |
| `agent-review:pending` | PR | 実装済み・レビューエージェント待ち |
| `agent-review:passed` | PR | レビュー合格。人間はマージ判断のみでよい |
| `agent-review:failed` | PR | レビュー不合格。修正モードの対象 |

## Review Queue 連携（プロジェクト横断レビューボード）

Review Queue Project が `なし` 以外なら、PR の状態変化をユーザーレベルの GitHub Project に反映する。
人間はこのボード1枚で**全リポジトリ**のマージ待ち PR を横断で捌く。操作はすべて決定論的な `gh` コマンドで行う。

`Review state`（単一選択フィールド）は PR ラベルと1対1で対応させる。**`agent-review:*` ラベルを付け替えたら、同じ手順内で必ず Review state も揃える**:

| PR ラベル | Review state |
|---|---|
| `agent-review:pending` | Needs Review |
| `agent-review:failed` | Changes Requested |
| `agent-review:passed` | Approved（人間のマージ判断待ち） |

`Blocked count`（数値フィールド）= この PR の対象 issue 番号 `#<N>` を本文で参照している open な `agent-ready` issue の件数。この PR のマージを前提に積まれている後続タスク数の近似であり、人間が「どの PR から捌くか」を決めるソートキーになる。

手順（`<owner>/<番号>` はプロジェクト設定の Review Queue Project の値）:

```bash
PROJECT_ID=$(gh project view <番号> --owner <owner> --format json --jq .id)
# 登録（登録済み URL に対しては既存 item が返るため冪等）
ITEM_ID=$(gh project item-add <番号> --owner <owner> --url <PR URL> --format json --jq .id)
# Blocked count の算出（対象リポジトリで実行）
BLOCKED=$(gh issue list --state open --label agent-ready --json number,body \
  --jq '[.[] | select(.body | test("#<N>([^0-9]|$)"))] | length')
# field id / option id を取得してから書き込む
gh project field-list <番号> --owner <owner> --format json
gh project item-edit --project-id $PROJECT_ID --id $ITEM_ID \
  --field-id <Review_state_の_field_id> --single-select-option-id <対応する_option_id>
gh project item-edit --project-id $PROJECT_ID --id $ITEM_ID \
  --field-id <Blocked_count_の_field_id> --number $BLOCKED
```

- **連携の失敗でサイクルを止めない**: `gh project` 系コマンドがエラーになっても警告として報告するだけにとどめ、本来の仕事（実装・レビュー・修正）は完了させる。
- マージ・クローズされた PR の後片付けは Project 側の built-in workflow（auto-archive）に任せる。ループは何もしない。

## 状態機械

Step 0 と 0.5 は毎サイクル評価する。Step 1〜4 は**上から順に評価し、最初に該当した1つのモードだけ**を実行する。

### Step 0: レートガード

1. `~/.claude/.rate-limit-snapshot` を読む（JSON: `five_hour_pct` / `seven_day_pct` / `ts`）。
2. `five_hour_pct > {{RATE_5H_MAX}}` または `seven_day_pct > {{RATE_7D_MAX}}` なら、このサイクルは**何もせずスキップ**し、現在値と復帰見込み（`*_resets_at`）を報告して終了する。
3. `ts` が現在時刻より2時間以上古い場合は「スナップショットが古い」と明記した上で続行してよい。
4. ファイルが存在しない場合はガードなしで続行し、その旨を報告に含める。

### Step 0.5: 朝ダイジェスト（報告のみ・手は止めない）

{{DIGEST_HOUR}} 時以降のその日最初のサイクルなら、通常のモード実行の**前に**以下を報告する:

- マージ待ち PR（`agent-review:passed`）の件数と最古の経過日数
- トリアージ待ち提案（`agent-proposed`）の件数
- 隔離中 issue（`agent-blocked`）の件数
- 直近1週間のレビュー検出率（レビューした PR のうち failed になった割合。`.agent-loop/log.md` から集計）

「その日最初」の判定は `.agent-loop/log.md` の最終行の日付が今日より前かどうかで行う。

### Step 1: レビューモード — `agent-review:pending` の PR がある

`gh pr list --label "agent-review:pending" --state open` で最も古い1件を選ぶ。

1. PR ブランチを `{{WORKTREE_BASE}}` 配下の worktree に checkout する。
2. **main 追従**: `git fetch origin` → `origin/{{MAIN_BRANCH}}` をブランチにマージする（rebase + force-push は禁止）。
   - コンフリクトが軽微（機械的に解消可能）なら解消して続行し、解消内容を PR コメントに記録する。
   - 解消に実装判断が必要な規模なら `agent-review:failed` に付け替え、理由を PR コメントに書いて終了。
3. 最新化した状態で `{{TEST_CMD}}` / `{{LINT_CMD}}` / `{{BUILD_CMD}}` を**独立に再実行**する（実装エージェントの報告を信用しない）。
4. ブラウザ実機検証が「あり」の場合: `{{DEV_SERVER_CMD}}` で dev サーバーを起動し、元 issue の**受け入れ条件をブラウザ上で再現**する。実装者が想定していない操作経路・エッジケースを最低1つ試す。
5. ソースコードレビュー: 受け入れ条件を根拠に「落とせる欠陥を探す」姿勢で diff を読む（正しさ・エッジケース・既存コードとの整合）。実装者がやったことの追認ではなく、やっていない角度を突く。
6. 判定を PR コメントに書き、ラベルを付け替える:
   - 合格 → `agent-review:passed`（検証ログ・実機確認の内容を添える）
   - 不合格 → `agent-review:failed`（欠陥の再現手順と修正すべき点を具体的に書く）
7. Review Queue 連携（該当時）: 付け替え後のラベルに合わせて Review state を更新し、Blocked count を再計算する（「Review Queue 連携」参照）。
8. 更新したブランチは push する（feature ブランチへの push は許可されている）。

### Step 1.5: passed の鮮度チェック

`agent-review:passed` の PR のうち、`origin/{{MAIN_BRANCH}}` との間でコンフリクトが発生しているものがあれば、`agent-review:pending` に戻して次サイクル以降で再レビューさせる（Review Queue 連携時は Review state も Needs Review に戻す）。これにより「passed = 今すぐコンフリクトなしでマージでき、直近の main で動作確認済み」が常に保たれる。

### Step 2: 修正モード — `agent-review:failed` の PR がある

最も古い1件を選び、PR ブランチの worktree でレビューコメントの指摘を修正する。

1. 修正後、`{{TEST_CMD}}` / `{{LINT_CMD}}` を実行し、証拠をターン内に表示する。
2. push して PR コメントに対応内容を書き、`agent-review:pending` に戻す（Review Queue 連携時は Review state も Needs Review に戻す）。
3. 同一 PR で failed が2回付いたら、それ以上触らず PR コメントに経緯をまとめ、元 issue を `agent-blocked` にして人間へ引き渡す。

### Step 3: 実装モード — 実行可能な issue がある

**実行可能な issue** = open かつ `agent-ready` 付き、かつ `agent-wip` / `agent-blocked` / `size:large` が付いていないもの。念のため、open な PR が既に紐づいている issue も除外する（`gh pr list --search "<番号> in:body"` 等で確認）。最も番号の小さい1件を選ぶ。

1. 受け入れ条件が測定可能な形で書かれていない issue は拾わない。不足点を issue コメントで指摘し、次の候補へ（候補が尽きたら Step 4 へ）。
2. 着手宣言: `agent-wip` ラベルを付け、着手コメントを残す。
3. `{{WORKTREE_BASE}}` 配下に worktree を作成する（ブランチ名: `agent/issue-<番号>-<slug>`、起点は `origin/{{MAIN_BRANCH}}`）。wt-setup スキルが使えるなら使う。
4. 受け入れ条件を仕様として実装する。テストを先に書く（大原則 6・7 を遵守）。
5. `{{TEST_CMD}}` / `{{LINT_CMD}}` / `{{BUILD_CMD}}` を実行し、証拠をターン内に表示する。
6. 通ったら push して **Draft PR** を作成する。本文に `Closes #<番号>` と検証ログを書き、`agent-review:pending` ラベルを付ける。Review Queue 連携（該当時）: PR を Project に登録し、Review state を Needs Review に、Blocked count を算出して設定する（「Review Queue 連携」参照）。
7. issue に PR の URL と要約をコメントし、`agent-wip` と **`agent-ready` の両方を外す**（PR が open な間に別サイクルが同じ issue を再実装しないため。マージされれば `Closes` で自動クローズされ、PR がマージされずクローズされた場合は人間が再トリアージして `agent-ready` を付け直す）。
8. 行き詰まったら: worktree は残し、issue に失敗ログをコメントする。同一 issue の失敗コメントが2件になったら `agent-blocked` に切り替えて以後拾わない。教訓を `.agent-loop/GUARDRAILS.md` に追記する（大原則 4 のミラーも忘れずに）。

途中で `size:large` 相当（1サイクルで完結しない規模）と判明したら、着手を中止して issue に分割案をコメントし、`size:large` を付けて終了する。

### Step 4: 提案モード — 上記のどれにも該当しない

1. open な `agent-proposed` の件数を数える。**{{PROPOSAL_CAP}} 件以上あれば新規起票せず**「未トリアージの提案が溜まっている」と報告して終了する（承認待ちを溜めてラバースタンプ化させないため）。
2. 上限未満なら、コードベース・既存 issue・`.agent-loop/GUARDRAILS.md`・直近のログを調査し、価値のあるタスク案を**最大2件**、`agent-proposed` ラベルで起票する。各案には測定可能な受け入れ条件と、触るファイル・関数の見当を必ず書く。
3. **起票のみで終了する。実行しない。** 人間が `agent-ready` に昇格させるまで待つ。

## 実行ログ形式（.agent-loop/log.md）

`.agent-loop/` は git 管理外（.gitignore 対象）。ファイルが無ければテーブルヘッダごと作成する。
サイクルごとに1行、テーブルに追記する:

```
| 日時 | モード | 対象 | 結果 | 備考 |
|---|---|---|---|---|
| 2026-01-01 09:00 | review | PR #12 | passed | ブラウザ検証OK |
| 2026-01-01 10:00 | implement | #15 | PR #18 作成 | テスト 34 passed |
| 2026-01-01 11:00 | skip | - | rate guard | 5h 82% |
```

このログはレビュー段階の効果測定に使う。**レビュー検出率（failed / レビュー総数）が数週間ほぼ 0% なら、レビューモードの廃止を人間に提案すること。**
