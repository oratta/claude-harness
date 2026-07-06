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
| レート上限（ハードキャップ） | 5時間枠 {{RATE_5H_MAX}}% / 7日枠 {{RATE_7D_MAX}}% |
| レートヘッドルーム（ペース超過許容） | 5時間枠 +{{RATE_5H_HEADROOM}}pt / 7日枠 +{{RATE_7D_HEADROOM}}pt |
| 朝ダイジェスト | {{DIGEST_HOUR}} 時以降のその日最初のサイクル |
| 提案ストック上限 | {{PROPOSAL_CAP}} 件 |

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

## 状態機械

Step 0 と 0.5 は毎サイクル評価する。Step 1〜4 は**上から順に評価し、最初に該当した1つのモードだけ**を実行する。

### Step 0: レートガード（ペース基準の動的閾値）

固定閾値ではなく**枠の経過率に連動した動的閾値**で判定する。同じ使用率でも、枠の序盤なら「行き過ぎ」としてスキップし、終盤ならハードキャップまで許容する。

- 判定式: `動的閾値 = min(ハードキャップ, 枠の経過率% + ヘッドルーム)`
  - 枠の経過率 = `(枠の長さ − (resets_at − 現在時刻)) ÷ 枠の長さ × 100`（0〜100 にクランプ。枠の長さ: 5時間枠 = 18000 秒、7日枠 = 604800 秒）
  - 消費ペースが時間経過ペースをヘッドルーム分を超えて上回っていたらスキップ。枠の開始直後はヘッドルームがそのまま下限の閾値になる
  - `resets_at` が無い（null）枠はハードキャップのみで判定する（従来動作へのフォールバック）

1. 以下のコマンドで判定する（決定論的作業のスクリプト化。LLM が暗算しない）:

   ```bash
   jq -r --argjson now "$(date +%s)" \
      --argjson cap5 {{RATE_5H_MAX}} --argjson head5 {{RATE_5H_HEADROOM}} \
      --argjson cap7 {{RATE_7D_MAX}} --argjson head7 {{RATE_7D_HEADROOM}} '
     def clamp: if . < 0 then 0 elif . > 100 then 100 else . end;
     def th(resets; win; cap; head):
       if resets == null then cap
       else [cap, ((100 * (win - (resets - $now)) / win) | clamp) + head] | min end;
     . as $s
     | th($s.five_hour_resets_at; 18000; $cap5; $head5) as $t5
     | th($s.seven_day_resets_at; 604800; $cap7; $head7) as $t7
     | "\(if ($s.five_hour_pct > $t5) or ($s.seven_day_pct > $t7) then "SKIP" else "GO" end) 5h=\($s.five_hour_pct)%(閾値\($t5|floor)%) 7d=\($s.seven_day_pct)%(閾値\($t7|floor)%) ts=\($s.ts)"
   ' "$HOME/.claude/.rate-limit-snapshot"
   ```

2. 出力が `SKIP` なら、このサイクルは**何もせずスキップ**し、出力（現在値と動的閾値）と復帰見込み（`*_resets_at`）を報告して終了する。
3. `ts` が現在時刻より2時間以上古い場合は「スナップショットが古い」と明記した上で続行してよい。
4. ファイルが存在しない・jq が失敗する場合はガードなしで続行し、その旨を報告に含める。

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
7. 更新したブランチは push する（feature ブランチへの push は許可されている）。

### Step 1.5: passed の鮮度チェック

`agent-review:passed` の PR のうち、`origin/{{MAIN_BRANCH}}` との間でコンフリクトが発生しているものがあれば、`agent-review:pending` に戻して次サイクル以降で再レビューさせる。これにより「passed = 今すぐコンフリクトなしでマージでき、直近の main で動作確認済み」が常に保たれる。

### Step 2: 修正モード — `agent-review:failed` の PR がある

最も古い1件を選び、PR ブランチの worktree でレビューコメントの指摘を修正する。

1. 修正後、`{{TEST_CMD}}` / `{{LINT_CMD}}` を実行し、証拠をターン内に表示する。
2. push して PR コメントに対応内容を書き、`agent-review:pending` に戻す。
3. 同一 PR で failed が2回付いたら、それ以上触らず PR コメントに経緯をまとめ、元 issue を `agent-blocked` にして人間へ引き渡す。

### Step 3: 実装モード — 実行可能な issue がある

**実行可能な issue** = open かつ `agent-ready` 付き、かつ `agent-wip` / `agent-blocked` / `size:large` が付いていないもの。念のため、open な PR が既に紐づいている issue も除外する（`gh pr list --search "<番号> in:body"` 等で確認）。最も番号の小さい1件を選ぶ。

1. 受け入れ条件が測定可能な形で書かれていない issue は拾わない。不足点を issue コメントで指摘し、次の候補へ（候補が尽きたら Step 4 へ）。
2. 着手宣言: `agent-wip` ラベルを付け、着手コメントを残す。
3. `{{WORKTREE_BASE}}` 配下に worktree を作成する（ブランチ名: `agent/issue-<番号>-<slug>`、起点は `origin/{{MAIN_BRANCH}}`）。wt-setup スキルが使えるなら使う。
4. 受け入れ条件を仕様として実装する。テストを先に書く（大原則 6・7 を遵守）。
5. `{{TEST_CMD}}` / `{{LINT_CMD}}` / `{{BUILD_CMD}}` を実行し、証拠をターン内に表示する。
6. 通ったら push して **Draft PR** を作成する。本文に `Closes #<番号>` と検証ログを書き、`agent-review:pending` ラベルを付ける。
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
| 2026-01-01 11:00 | skip | - | rate guard | 5h 45%（閾値 38%） |
```

このログはレビュー段階の効果測定に使う。**レビュー検出率（failed / レビュー総数）が数週間ほぼ 0% なら、レビューモードの廃止を人間に提案すること。**
