# Plan: 公式ループ4タイプをハーネスに実装する（anthropic-knowledge-reflect）

## 生成情報
- 作成日: 2026-07-04
- Brain Dump元: /goal 指示「Anthropic公式ナレッジ調査→claude-harness実装 goal指示書」+ フィードバック3件（①既存資産活用でなく「普通に使うだけでは実現できないもの」のハーネス追加 ②loop engineering で調べ直せ ③公式記事 https://claude.com/blog/getting-started-with-loops がやりたいことの本体）
- 中核ソース: **"Getting started with loops"（claude.com 公式ブログ、Claude Code チーム、2026-06-30）**。詳細は `research/loop-engineering.md` 冒頭
- 別トラック: 既存資産のコンテンツ品質監査は `plan-b-existing-audit.md` に分離済み

## ゴール
公式記事が定義する **4つのループタイプ（ターンベース / ゴールベース / タイムベース / プロアクティブ）** を、このユーザーの実際の定常業務に落とした「**設計されたループのレシピ集 + State 規約**」としてハーネスに実装する。

公式の立場は「ループのランタイムはネイティブプリミティブ（skill / /goal / /loop / /schedule / workflows / auto mode）であり、ループは**その合成**で作る」。したがって**独自のループ実行系（カスタム schema + driver）は作らない**。ハーネスが提供するのは:
1. **skill への自己検証ステップの組み込み**（ターンベースの公式最適化）
2. **定量的成功基準を持つ /goal レシピ**（ゴールベース）
3. **定常業務の /loop・/schedule レシピ**（タイムベース）
4. **プロアクティブ合成ルーチン**（/schedule + /goal + workflows + auto mode）と State 規約

## ビジネスコンテキスト
- 対象ユーザー: このユーザー本人（marketplace の唯一のメンテナ兼利用者）
- 提供価値: 「人間が毎回プロンプトする」から「ループが定常業務を回し、人間は例外だけ処理する」への移行。具体的には (1) 既存スキルが自己検証するようになり手戻りが減る、(2) 定常業務（PR 面倒見・レポート・backlog 消化・依存更新）がレシピ1発でループ化できる、(3) 停止基準・コスト管理が公式ベストプラクティスに沿った形でレシピに焼き込まれる
- 成功指標: 受け入れ条件の機械検証が全て PASS。プロアクティブルーチン 1 本以上が実際に /schedule 登録されて 1 サイクル完走する

## 一次ソース（実装時の判断基準）
builder / reviewer は迷ったら以下を参照する（全て本 run の `research/` に保存済み・URL 実在確認済み）:
- `research/loop-engineering.md` — **冒頭の公式記事セクションが最上位**（4ループタイプ・選択フレームワーク・品質/トークン管理ベストプラクティス）。後半はコミュニティ側の背景（Osmani の 5+1 構成要素・State・失敗6類型は設計の参考として有効）
- `research/claude-code-official.md` — §7 harnesses 論文（長期タスクの外部状態設計: feature-list / progress notes / 1セッション1機能）
- `research/anthropic-agent-knowledge.md` — engineering 記事11本（fan-out コスト・敵対的レビュー・委譲契約）
- `research/gap-analysis.md` — ギャップ判定表

## 技術要件
- スタック: Markdown（SKILL.md / commands / references）+ JSON Schema（最小限）+ bats-core + ネイティブプリミティブ（/goal・/loop・/schedule・Workflow・auto mode）
- 参照パターン:
  - 検証ステップの既存形: longrun の verifier 4軸・browser-verifier（機能性/UX の E2E）
  - 非対話・cron 実行の既存形: daily-report / weekly-report の非対話モード節
  - worktree 隔離 + Draft PR: `plugins/worktree/`（wt-setup --with-pr）
- 制約:
  - `~/.claude/rules/plugin-editing.md` 準拠: version bump + marketplace.json 同期必須
  - このリポジトリの CLAUDE.md 準拠: worktree 作業は Draft PR バックアップ、main 直 push 禁止
  - モデル ID 直書き禁止（`plugins/longrun/references/model-tiers.md` が唯一のソース）
  - **独自ループランタイムの再発明禁止**: 反復・スケジュール・停止判定はネイティブ（/goal の最大試行・/loop/schedule のキャンセル・Workflow の budget）に任せ、レシピは「明確な停止基準を宣言する」ことに責任を持つ
  - ループの外向きアクションは非破壊デフォルト（Draft PR / issue コメントまで）。マージ等の不可逆操作は人間へエスカレーション
  - 全レシピに停止基準（最大試行数 or 時間 or 定量ゴール）とコスト注意（公式トークン管理6項目のうち該当するもの）を必ず含める
- テストフレームワーク: bats-core + grep ベース検証
- テスト実行コマンド: `find plugins -name '*.bats' -print0 | xargs -0 bats`

## スコープ
### 含むもの
- 新プラグイン `loops`（レシピ集 + State 規約 + 設計ガイドスキル）（change-1）
- ターンベース: 既存スキルへの自己検証ステップ組み込み（change-2）
- ゴールベース + タイムベース: /goal・/loop・/schedule レシピ集（change-3）
- プロアクティブ: 合成ルーチン 3 本（backlog 消化 / 長期ビルド / レシピ採掘・更新のメタループ）（change-4）
- marketplace 同期・README・コストガードレール（change-5）

### 含まないもの
- 独自のループ実行系（loop-definition schema による宣言的ランタイム・headless driver スクリプト）（理由: 公式路線は「ネイティブプリミティブの合成」。前版 plan で設計したが公式記事の確認により方針転換）
- 既存資産のコンテンツ品質監査（`plan-b-existing-audit.md` に分離済み）
- Slack / Linear 等の外部コネクタ（現行ワークフローは gh + openspec/backlog.md で足りる）
- skill-eval / e2s-tune（「スキルを改善するループ」として将来のレシピ追加で対応。backlog へ）
- 別 marketplace のプラグイン（対象リポジトリ外。ただしレシピ形式はそちらでも使える書き方にする）

## Changes分解

### change-1: loops-plugin（レシピ集の器 + State 規約 + 設計ガイド）
- **スコープ**: 新プラグイン `plugins/loops/` を作る。
  1. **レシピ形式の規約**: `recipes/<name>.md` — 各レシピは「ループ型（4分類のどれか）/ 目的 / 起動コマンド（コピペ可能な /goal・/loop・/schedule 文字列）/ 停止基準 / 必要な前提（skill・設定）/ コスト注意 / エスカレーション条件」の固定見出しで書く。**ランタイムを持たない**（レシピは人間とエージェントが読む設計図）
  2. **State 規約**: プロアクティブ/長期ループが使う `loops/state/<name>.state.md` の形式（現在の作業 / 前回の試行と結果 / 人間への引き継ぎ待ち / 繰り越しタスク）とテンプレート。「エージェントは忘れるが、リポジトリは記憶する」
  3. **`/loops:design`**: 公式の選択フレームワーク（何を手放すか: 検証ステップ→停止条件→トリガー→プロンプト自体）に沿って対話でループ型を選び、レシピ形式の定義を書き出すガイドスキル。Bad Loop 検査（停止基準の欠如・検証なき成功宣告・報酬ハッキング余地・過剰な実行頻度）を組み込む
  4. **選択フレームワーク reference**: `references/loop-types.md` に公式4タイプ表と使い分け・具体例を収録（`research/loop-engineering.md` 冒頭の要約を配布物化）
  5. **実行機構 reference**: `references/execution-mechanisms.md` — 定期実行の機構の使い分け表と設定手順。優先順位:
     - **① 常駐セッション + セッション内 cron（推奨）**: 常時起動している Claude Code セッション（例: ユーザーの AGENT/Pikke 運用）内で CronCreate / /loop により定時発火。**ローカルファイル（`~/.claude/projects/` jsonl 含む）にアクセスでき、サブスクリプション枠で動く**。ローカルデータを読むループはこれを第一候補とする
     - **② launchd/cron + `claude -p`（フォールバック）**: 常駐セッションが無い環境向け。ローカル定時 headless 実行（同一ログイン認証のため通常はサブスク枠）。plist テンプレート + 登録/解除手順を同梱
     - **③ /schedule（クラウド）**: リポジトリだけで完結する仕事専用。PC を閉じても動くが、**ローカルファイルは読めず、従量課金になる点に注意**を明記
- **使用スキル**: なし（longrun の plan-interview-methodology.md を参照流用）
- **依存関係**: 独立（change-2〜4 の前提）
- **config.yaml rules**:
  - "レシピはネイティブコマンド文字列を第一級の成果物とする（コピペで動くこと）。独自 CLI やラッパースクリプトを作らない"
  - "停止基準の無いレシピを /loops:design が出力しないことをテストで確認する"
  - "MVP スコープ厳守: レシピ形式は markdown 見出し規約のみ。schema 化・機械検証は必要になってから（backlog）"

### change-2: skill-verification（ターンベースループの公式最適化）
- **スコープ**: 「skill に自己検証メカニズムを明示する」（公式ベストプラクティス）を、このリポジトリの成果物を出す主要スキルに適用する。
  1. 対象スキルの棚卸し: `plugins/*/skills/*/SKILL.md` のうち、成果物（コード・ファイル・レポート・設定）を出すものについて「完了宣言の前に何をどう検証するか」が本文に明示されているかを監査
  2. 欠けているスキルに **検証ステップ節**を追加: 公式例の粒度（「dev サーバーを起動し、ブラウザで操作確認、コンソールエラーなしを確認」）で、そのスキル固有の検証手段（テスト・lint・生成物の存在と形式チェック・実行結果の evidence）を具体的に書く
  3. 検証の書き方の共通原則を `plugins/loops/references/self-verification.md` に 1 枚化（「完了は主張であり証明ではない。evidence を提示してから完了を宣言する」）し、各スキルからは 1 行参照 + スキル固有手順のみ記載（重複コピー禁止）
- **使用スキル**: なし
- **依存関係**: change-1（references の置き場所）
- **config.yaml rules**:
  - "検証ステップは各スキルの実際の成果物に即して具体的に書く（汎用文言のコピペ追加を禁止）"
  - "既存スキルの機能・発火条件を変えない。追加は検証節のみ"
  - "追加によって SKILL.md が 500 行を超える場合は references へ分離する"

### change-3: goal-and-time-recipes（ゴールベース + タイムベースのレシピ集）
- **スコープ**: このユーザーの定常業務を /goal・/loop・/schedule レシピにする。初期セット:
  1. **goal レシピ**（定量基準 + 最大試行数を必須とする）:
     - `goal-tests-green.md`: 「全 bats PASS まで、最大 N 回」（このリポジトリの開発用）
     - `goal-acceptance-pass.md`: 「longrun plan.md の受け入れ条件の機械検証が全て PASS まで」（longrun 完了ゲート用）
     - `goal-lighthouse.md`: 公式例の移植（Web プロジェクト汎用）
  2. **time レシピ**:
     - `loop-pr-babysit.md`: `/loop 5m check my PR, address review comments, and fix failing CI` の Draft PR 運用（このリポジトリの CLAUDE.md 運用）向け調整版
     - `cron-daily-report.md` / `cron-weekly-report.md`: 既存 daily/weekly-report の非対話モードを定期実行に登録するレシピ。**両者ともローカルデータ（Vault・セッション jsonl）を読むため、常駐セッション内 cron を第一候補**とする（/schedule クラウドは不可。execution-mechanisms.md の使い分けに従う）。既存プラグインの記述と重複させず、登録コマンドと停止・頻度設計のみ
  3. 各レシピに公式トークン管理の該当項目（頻度最小化・決定論部分のスクリプト化・パイロット実行）を明記
  4. この6本は**初期シード**という位置づけ。以降の棚の成長・実測チューニングは change-4 の recipe-miner ルーチンが担う
- **使用スキル**: daily-report / weekly-report（レシピの対象として参照）
- **依存関係**: change-1
- **config.yaml rules**:
  - "goal レシピの成功基準は必ず機械検証可能（コマンドと期待値）で書く。『良くなったら』等の主観基準を禁止"
  - "schedule レシピの実行頻度はデフォルトを保守的に（daily 系は日次、PR babysit は 5-10 分）設定し、変更方法を併記する"
  - "既存プラグイン（daily/weekly-report）の本文は変更しない。レシピはあくまで登録・運用手順"

### change-4: proactive-routines（プロアクティブ合成ルーチン 3 本）
- **スコープ**: 公式の合成パターン（/schedule + /goal + 動的ワークフロー + オートモード）で、人間不在で回るルーチンを 3 本実装する。
  1. **backlog 消化ルーチン** `recipes/routine-backlog-triage.md`: /schedule（日次等）で起動 → discovery: `openspec/backlog.md` と open issues から着手可能タスクを選定（1 サイクルの処理数上限をレシピに明記）→ worktree を切って実装（第一エージェント）→ /code-review 相当の第二エージェントレビュー（公式品質プラクティス「第二エージェントによるレビュー」）→ **Draft PR まで**（マージは人間）→ state 更新（処理済み / 繰り越し / 引き継ぎ待ち）。/goal で「このサイクルで選定したタスクが全て Draft PR または凍結記録に到達するまで」を停止基準化
  2. **長期ビルドルーチン** `recipes/routine-long-build.md`: harnesses 論文の外部状態設計をネイティブ合成で実現。前提: `{longrun-dir}/feature-list.json`（`{id, description, verification, passes:false}`、項目・テスト削除禁止）と `claude-progress.md`。/schedule または手動再起動で 1 サイクル = 「smoke check（直近 passing 項目の検証再実行）→ `passes:false` の先頭 1 項目のみ実装 → verification コマンドの exit 0 evidence がある場合のみ `passes:true` 更新 → 説明的 commit → progress 追記」。/goal「全項目 passes:true、ただし同一項目 2 連続 FAIL で凍結して人間へ」を停止基準化。feature-list の形式は `plugins/loops/references/feature-list-format.md` に記載（schema 強制はしない）
  3. **レシピ採掘・更新ルーチン（メタループ）** `recipes/routine-recipe-miner.md`: ハーネス自身を実使用ログで改善し続けるループ。トリガー: **常駐セッション内の cron（週1）を第一候補**（`~/.claude/projects/` の jsonl を読むためローカル実行必須・サブスク枠で動く。常駐セッションが無い場合は launchd + `claude -p` にフォールバック。/schedule はローカルファイル不可のため使えない。詳細は change-1 の execution-mechanisms.md）。1サイクル = discovery: 直近7日のセッション jsonl をサブエージェントで圧縮解析（daily-report の llm-log-compactor の jq パターン流用。生ログをメインに載せない）し、(a) 同型依頼の3回以上の反復=ループ化候補、(b) 修正→テスト→修正の長い往復=/goal 化候補、(c) 定時性のある依頼=/schedule 化候補、(d) 既存レシピの実行痕跡=停止基準・頻度の実測チューニング候補、を抽出 → 生成: /loops:design の検査（停止基準必須・Bad Loop 検査）を通したレシピ新規案/更新 diff（**1サイクル最大3件**）→ 出力: この marketplace リポジトリへ **Draft PR**（自動 merge 禁止。レシピの採否は人間）→ persistence: state に提案済み/見送り理由/繰り越し候補を記録。候補ゼロなら「提案なし」で正常終了
  4. 全ルーチンの動作確認をこのリポジトリ（または安全なサンドボックス）で 1 サイクル実施
- **使用スキル**: worktree（隔離）、loops の State 規約、/loops:design（miner の生成検査）
- **依存関係**: change-1, change-3（/goal レシピの流用。miner はシードレシピの存在が前提）
- **config.yaml rules**:
  - "外向きアクションは Draft PR / issue コメントまで。merge・close・force 系はレシピの禁止事項節に明記し、エスカレーションに倒す"
  - "discovery で拾ったが処理しなかったタスクは state に繰り越しとして必ず記録する（silent drop 禁止）"
  - "同一タスク・同一項目の 2 連続失敗は凍結 + 人間へエスカレーション（無限リトライ禁止）をレシピの停止基準に含める"
  - "`passes:true` への更新は verification コマンドの exit 0 evidence がある場合のみ。自己申告更新の禁止をルーチンプロンプトに明記する"
  - "recipe-miner が生成・更新するレシピも停止基準必須の規約検査を必ず通す（検査を通らない提案は Draft PR に含めず見送り記録する）"
  - "recipe-miner のログ解析はサブエージェントに隔離し、抽出結果（候補リスト）のみをメインに返す"

### change-5: integration（marketplace 同期・README・コストガードレール）
- **スコープ**: (1) 新プラグイン `loops` の marketplace.json 登録、(2) 編集した全プラグインの version bump と同期、(3) ルート README に公式4ループタイプとレシピ集の位置づけ（公式記事リンク付き）を追記、(4) `plugins/loops/references/cost-guardrails.md`: 公式トークン管理6項目 + 「ループはチャットの約4倍、マルチエージェント構成は約15倍」の定量事実 + /usage・/workflows でのレビュー手順、(5) 受け入れ条件の統合検証
- **使用スキル**: なし
- **依存関係**: change-1〜4 全て（同期は最後に直列実行）
- **config.yaml rules**:
  - "marketplace.json の version は各 plugin.json と完全一致させる"
  - "README への追記は要約に留め、詳細は plugins/loops/ と research/ に委ねる"

## モデル割り当て

ティアは `plugins/longrun/references/model-tiers.md` で解決する（モデル ID は書かない）。

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| change-1 | builder | inherit | レシピ規約と設計ガイドの新規設計（以降の土台） | |
| change-1 | verifier | sonnet | 規約準拠・停止基準必須の中規模検証 | |
| change-1 | reviewer | inherit | 「ランタイム再発明禁止」制約との整合レビュー | |
| change-2 | builder | sonnet | 既存スキルへの検証節追加（基準明確な文書作業） | |
| change-2 | verifier | haiku | 検証節の存在・重複コピー無しの定型検証 | |
| change-2 | reviewer | inherit | スキル毎の検証手段の妥当性判断 | |
| change-3 | builder | sonnet | レシピ執筆（定型寄り） | |
| change-3 | verifier | haiku | 機械検証可能な基準・頻度設定の定型チェック | |
| change-3 | reviewer | inherit | 停止基準・コスト設計の妥当性判断 | |
| change-4 | builder | inherit | 人間不在ルーチンの安全設計（非破壊・凍結・State）が critical | |
| change-4 | verifier | sonnet | 1 サイクルデモの E2E 検証 | |
| change-4 | reviewer | inherit | 不可逆アクション防止・暴走防止の安全レビュー | |
| change-5 | builder | sonnet | version 同期・README 追記の定型作業 | |
| change-5 | verifier | haiku | 統合 grep 検証一式の定型実行 | |
| change-5 | reviewer | inherit | リポジトリ全体整合の最終レビュー | |

## 画面・UI設計
該当なし（CLI プラグイン）

## データモデル
- `recipes/<name>.md`（固定見出し規約。schema 強制なし）
- `loops/state/<name>.state.md`（State 規約: 現在の作業 / 前回の試行と結果 / 引き継ぎ待ち / 繰り越し）
- `{longrun-dir}/feature-list.json`（長期ビルドルーチンの真のソース。形式は references に記載）
- marketplace.json ↔ 各 plugin.json の version 一致

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている（`find plugins -name '*.bats' -print0 | xargs -0 bats`）
3. [ ] ビルドエラーなし（全 *.json の JSON parse PASS。スクリプトを追加した場合は `bash -n` / `node --check` PASS）
4. [ ] 統合テストがPASS（worktreeマージ後、下記 5-15 を main 上で再実行して全 PASS）

**機能固有の条件:**
5. [ ] `plugins/loops/` が存在し、`/loops:design` スキル・`references/loop-types.md`・State テンプレート・レシピ形式規約を持つ
6. [ ] 全レシピ（recipes/*.md）が固定見出し（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）を持つことが grep で確認できる。停止基準の無いレシピが 0 件
7. [ ] `plugins/loops/` に独自ランタイム（ループを回す常駐スクリプト・カスタム driver）が存在しない。レシピの起動コマンドが全てネイティブプリミティブ（/goal・/loop・/schedule・skill 起動）である
8. [ ] 成果物を出す主要スキル（棚卸しリストは change-2 で確定、最低でも longrun-plan / wt-setup / wt-clean / daily-report / weekly-report / infra-setup / e2s-distill を含む）の SKILL.md に自己検証ステップ節がある
9. [ ] goal レシピ 3 本・time レシピ 3 本以上が存在し、goal レシピの成功基準が全て機械検証可能（コマンド + 期待値）で書かれている
10. [ ] `recipes/routine-backlog-triage.md` が存在し、非破壊制約（Draft PR まで）・処理数上限・繰り越し記録・2連続失敗凍結の 4 点を含む。1 サイクルのデモ実行ログが `{longrun-dir}` に残っている
11. [ ] `recipes/routine-long-build.md` が存在し、1サイクル1項目・evidence 必須の passes 更新・smoke check・凍結条件を含む。3 項目以上の feature-list で 2 サイクル以上に分けた完走デモのログが残っている
12. [ ] `recipes/routine-recipe-miner.md` が存在し、(a) 常駐セッション内 cron を第一候補とするローカル定期実行（/schedule 不可の理由と launchd フォールバック付き）、(b) 1サイクル最大3提案、(c) Draft PR 出力・自動 merge 禁止、(d) サブエージェント隔離のログ解析、の 4 点を含む。実ログに対する 1 サイクルのデモ実行で提案（または「提案なし」の正常終了）と state 更新が確認できる
13. [ ] `references/execution-mechanisms.md` が機構の使い分け表（常駐セッション cron 推奨・/schedule の従量課金注意を含む）と launchd テンプレートを含む
14. [ ] `references/cost-guardrails.md` が公式トークン管理 6 項目を含む
15. [ ] `loops` が marketplace.json に登録され、編集した全プラグインで plugin.json version が bump され marketplace.json と一致する

## 意思決定ガイドライン
- 優先順位: 安全性（暴走・課金・不可逆アクション防止） > 公式路線への忠実さ（ネイティブ合成・ランタイム再発明禁止） > シンプルさ > レシピの本数
- リスク許容度: 保守的。特にプロアクティブルーチンは非破壊デフォルト（Draft PR まで）を厳守
- 「完了は主張であり証明ではない」: 全ループ・全スキルで evidence（テスト出力・exit code・生成物の実在）を確認してから完了を宣言する設計とする
- 不明点の扱い: 迷ったら `research/loop-engineering.md` 冒頭の公式記事セクション（4タイプ表・品質/トークン管理）に立ち返る。コミュニティ由来の概念（5+1構成要素・失敗6類型）は参考に留め、公式と矛盾したら公式に従う
- 実装中に見つけた拡張候補（レシピの schema 化・イベント駆動・skill-eval/e2s-tune のループ化・外部コネクタ）は実装せず `openspec/backlog.md` に記録する

## 動作確認方法
- 開発サーバー: なし
- テスト: `find plugins -name '*.bats' -print0 | xargs -0 bats` + レシピ見出しの grep 検証
- 確認手順:
  1. 受け入れ条件 5-15 の各検証コマンドを実行し全て期待値になることを確認
  2. **design デモ**: `/loops:design` で小さなループを 1 本設計し、停止基準必須が機能することを確認（停止基準なしでは出力されない）
  3. **goal デモ**: `goal-tests-green.md` のコマンドをこのリポジトリで実行し、全 bats PASS で停止することを確認
  4. **backlog triage デモ**: 1 サイクル実行 → Draft PR 作成・state 更新・繰り越し記録を確認
  5. **long-build デモ**: 3 項目 feature-list で 2 サイクル完走 → 1 項目を故意に失敗させ凍結 + エスカレーションを確認
  6. **recipe-miner デモ**: 直近の実ログに対して 1 サイクル実行 → 提案 Draft PR（または「提案なし」の正常終了）と state 更新・繰り越し記録を確認。常駐セッションでの cron 登録 → 発火 → 解除の一連が execution-mechanisms.md の手順通りに動くことを確認（launchd フォールバックは手順の机上確認でよい）
  7. マージ後、新セッションで `/plugin install loops@oratta-claude-harness` → `/reload-plugins` で新プラグインが見えることを確認

## Brain Dumpからの原文メモ
> /goal Anthropic公式ナレッジ調査→claude-harness実装 goal指示書
>
> （フィードバック1）既存のものをどう活かしてほしいわけじゃなくて、アンソロピックはこういう風に使うべきだって言ってるけども、普通に使ってるだけじゃ実現できないものみたいなものをハーネスとして追加したい
>
> （フィードバック2）違うな、それloopじゃない。loop engineeringで調べてみて
>
> （フィードバック3）https://claude.com/blog/getting-started-with-loops これは読んだ？こういうことなんだけど
>
> （フィードバック4）ログをもとに定期的にループレシピを作成や更新するというループを作ってみよう。1（loops-plugin の設計ガイドと規約）を使って
>
> （解釈: 中核は公式記事「Getting started with loops」の4ループタイプ。ハーネスの責務は独自ランタイムではなく「ネイティブプリミティブの合成レシピ + skill 自己検証 + State 規約」の提供。既存資産監査は plan-b、調査資料は research/ に分離）

---

## 付録: 各 change の根拠（一次ソース要約）

### 付録 A: change-1 (loops-plugin) の根拠
公式記事（`research/loop-engineering.md` 冒頭）:
- 選択フレームワーク: ループ型ごとに「手放す対象」が異なる（ターンベース=検証ステップ / ゴールベース=停止条件 / タイムベース=トリガー / プロアクティブ=プロンプト自体）→ /loops:design のインタビュー構造そのもの
- 「明確な成功・停止基準を定義（曖昧さを減らす）」→ 停止基準必須の規約
- State はコミュニティ側（Osmani）由来だが公式のプロアクティブ合成例（「翌日 state から再開」相当の運用）と整合し、harnesses 論文（progress notes）でも公式裏付けあり

### 付録 B: change-2 (skill-verification) の根拠
公式記事: ターンベースループの最適化 = 「**スキルに検証ステップを組み込み、自己検証能力を向上**」。公式例: 「フロントエンド変更を確認する前に dev サーバーを起動し、ブラウザで操作確認、コンソールエラーなしを確認」と具体的に記述する。
`research/anthropic-agent-knowledge.md` ソース9: 「『成功した』と主張させず evidence を提示させる」。

### 付録 C: change-3 (goal-and-time-recipes) の根拠
公式記事:
- /goal は「エバリュエータモデルが成功基準を評価し、基準達成まで反復。**定量的な基準（テスト合格数・スコア閾値）が最も効果的**」。公式例 `/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries`
- /loop はローカル・/schedule はクラウド。公式例 `/loop 5m check my PR, address review comments, and fix failing CI`
- トークン管理: 「ルーチン実行頻度を必要最小限に」「決定論的作業はスクリプト化」「大規模実行前にパイロット」

### 付録 D: change-4 (proactive-routines) の根拠
公式記事: プロアクティブループ = 「イベント/スケジュールがトリガー、人間不在。バグ分類・マイグレーション・依存関係更新などの定期業務」。合成例: `/schedule every hour: check #project-feedback for bug reports. /goal: don't stop until every report found this run is triaged, actioned, and responded to.` 品質プラクティス「**第二エージェントによるレビュー**（/code-review 等）」。
`research/claude-code-official.md` §7（harnesses 論文）: feature-list JSON（`passes:false`）・progress notes・1セッション1機能・「丁寧なテスト後にのみ passing」・セッション開始時 smoke check → 長期ビルドルーチンの外部状態設計。
`research/anthropic-agent-knowledge.md` ソース2: fan-out 暴走防止のスケーリングルール（1 サイクルの処理数上限）。

### 付録 E: 前版 plan からの方針転換の記録
- 前版（Loop Engineering コミュニティ解釈版）は `loop-definition.schema.json` + `/loops:run` + `build-loop.sh` driver という**独自ランタイム**を設計していた
- 公式記事の確認により「ランタイムはネイティブ、ハーネスはレシピと規約」に転換。schema 強制・driver スクリプトは廃案（レシピの markdown 規約と references での形式記載に置換）
- 廃案分で将来も価値がありうるもの（レシピの機械検証・loop-audit 相当）は backlog へ記録する
