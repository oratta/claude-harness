# Plan: 公式推奨×素のClaude Codeのギャップをハーネス機能として追加する（anthropic-knowledge-reflect）

## 生成情報
- 作成日: 2026-07-04
- Brain Dump元: /goal 指示「Anthropic公式ナレッジ調査→claude-harness実装 goal指示書」+ ユーザーフィードバック「既存のものをどう活かすかではなく、Anthropic はこう使うべきと言っているが普通に使っているだけでは実現できないものを、ハーネスとして追加したい」
- 調査体制: 並列3エージェント調査 → ギャップ分析。全資料は `research/` 配下に保存済み
- 別トラック: 既存資産のコンテンツ品質監査（description・schema横展開・語調調律等）は `plan-b-existing-audit.md` に分離。本 plan の完了後に必要なら別 run で実施

## ゴール
Anthropic 公式ナレッジのうち「**公式が推奨しているが、素の Claude Code を普通に使うだけでは実現できず、毎回自前で組むことになるもの**」（`research/gap-analysis.md` で特定した 4 機構）をこの marketplace のハーネス機能として新規追加する:
1. **外側セッションループ**（longrun 新モード）— harnesses 論文のリファレンスアーキテクチャ
2. **skill 評価ハーネス**（新プラグイン）— eval 駆動開発の機構化
3. **スキル自己改善ループ**（e2s 拡張）— 実使用ログからの description/指示文チューニング
4. **検証ゲート hook pack**（新プラグイン）— 決定論的検証ゲートの配布可能化

## ビジネスコンテキスト
- 対象ユーザー: このユーザー本人（marketplace の唯一のメンテナ兼利用者）
- 提供価値: (1) コンテキストウィンドウを超える長期タスクを「セッションを跨いで」自律駆動できるようになる（現状 longrun は 1 セッション内で完結する規模が上限）、(2) スキルの品質を主観でなく評価で担保できるようになる、(3) スキルが使われるほど自動的に良くなる改善サイクルが回る、(4) 「テストが通るまで終われない」を宣言でなく機構で保証できる
- 成功指標: 受け入れ条件の機械検証が全て PASS。特に change-1 はデモタスク（複数セッションを要する規模の実装）を外側ループで完走できること

## 一次ソース（実装時の判断基準）
builder / reviewer は迷ったら以下を参照する（全て本 run の `research/` に保存済み・URL 実在確認済み）:
- `research/gap-analysis.md` — 本 plan の選定根拠（公式推奨 × 素のCC × 既存ハーネスの判定表）
- `research/anthropic-agent-knowledge.md` — engineering 記事11本の統合資料
- `research/claude-code-official.md` — Claude Code 公式ドキュメントの推奨・アンチパターン（§7 に harnesses 論文の要点）
- `research/repo-survey.md` — リポジトリ現状マップ

## 技術要件
- スタック: Markdown（SKILL.md / commands / agents）+ bash / node スクリプト + JSON Schema + bats-core + `claude -p`（headless）
- 参照パターン:
  - schema 契約: `plugins/longrun/schemas/*.schema.json`（外部ファイルが唯一のソース）
  - 状態外部化の既存資産: `_longruns/<run>/` の plan.md / decisions.md / workflow-runs.jsonl
  - jsonl 解析: `plugins/daily-report/agents/llm-log-compactor.md` の jq ロジック（change-3 で流用）
- 制約:
  - `~/.claude/rules/plugin-editing.md` 準拠: 編集した全プラグインで plugin.json version bump + marketplace.json 同期必須
  - このリポジトリの CLAUDE.md 準拠: worktree 作業は Draft PR バックアップ運用、main 直 push 禁止
  - モデル ID を直書きしない（`plugins/longrun/references/model-tiers.md` が唯一のソース）
  - headless 実行（`claude -p`）は課金実行になるため、driver スクリプトには**セッション数上限・停止条件をコードの条件式で**必ず持たせる（「上限は LLM の自制に依存しない」という longrun 既存 GATE の踏襲）
  - 新プラグインは既存の構成規約（`.claude-plugin/plugin.json` + ルート直下 `skills/` `commands/` `agents/` `hooks/`）に従う
- テストフレームワーク: bats-core + `node --check` + grep ベース検証
- テスト実行コマンド: `find plugins -name '*.bats' -print0 | xargs -0 bats`

## スコープ
### 含むもの
- longrun への外側セッションループモードの追加（change-1）
- skill 評価ハーネスの新設（change-2）
- e2s へのスキル自己改善ループ追加（change-3）
- 検証ゲート hook pack の新設（change-4）
- 上記に伴う marketplace.json 同期・README 更新（change-5）

### 含まないもの
- 既存資産のコンテンツ品質監査（description 三人称化・infra schema 化・weekly-report 隔離・SKILL.md 分割・語調調律）（理由: `plan-b-existing-audit.md` に分離済み。新機構追加が本 run の主目的）
- harvest / sns-strategy 等、別 marketplace のプラグイン（理由: 対象リポジトリ外）
- Tool Search / defer_loading / Tool Use Examples への対応（理由: API・Claude Code 本体が提供済みでハーネス不要。gap-analysis #9〜#10）
- CLAUDE.md・`.claude/rules/` の変更（理由: 調査結論は「現行運用ルールは公式仕様で追認済み。変更不要」）

## Changes分解

### change-1: longrun-session-loop（外側セッションループ）
- **スコープ**: harnesses 論文のリファレンスアーキテクチャを longrun の新モードとして実装する。
  1. **feature-list 契約**: `plugins/longrun/schemas/feature-list.schema.json` を新設。plan.md の Changes/受け入れ条件から生成する `{longrun-dir}/feature-list.json`（各項目 `{id, description, verification, passes: false}`）が外側ループの真のソース。**テスト・項目の削除禁止**を schema コメントと GATE で明記
  2. **driver スクリプト**: `plugins/longrun/scripts/session-loop.sh` を新設。while ループで `claude -p`（headless・`--output-format json`）を起動し、各セッションに「feature-list.json を読む → `passes:false` の項目を **1 つだけ**選ぶ → 実装 → 検証コマンドで evidence を取る → 通ったら `passes:true` に更新 → 説明的 commit → progress notes 追記 → 終了」を指示する。**セッション数上限（デフォルト設定可能）・全項目 PASS・連続失敗数**の 3 つをコードの条件式で停止判定
  3. **セッションプロンプトのテンプレート化**: `plugins/longrun/templates/session-loop/` に init セッション用（環境セットアップ・init.sh 生成・初期 commit）と feature セッション用（1機能実装）の 2 プロンプトテンプレートを置く（論文の init agent / coding agent 分離）。feature セッションは開始時に smoke check（直近 passing 項目の検証コマンド再実行）を行い、壊れていたら新機能より先に修復する
  4. **progress notes**: `{longrun-dir}/claude-progress.md` にセッション毎の要約を追記（次セッションが最初に読む。compaction に依存しない状態引き継ぎ）
  5. **エントリポイント**: `/longrun:loop <longrun-dir>`（`plugins/longrun/commands/loop.md`）と lr エイリアス `/lr:l` を追加。既存 `/longrun:exec`（in-session Workflow）とは併存し、使い分け（1セッションに収まる規模=exec / 収まらない規模=loop）を exec.md と README に 1 段落で明記
- **使用スキル**: なし
- **依存関係**: 独立
- **config.yaml rules**:
  - "driver の停止条件（セッション上限・全PASS・連続失敗）は bash の条件式で実装し、LLM の判断に委ねない"
  - "feature セッションのプロンプトには『1 セッションで 1 項目のみ。他の passes:false に手を出さない』『トークン残量を理由に途中終了せず、区切りの良い状態で commit して progress notes に引き継ぎを書く』を含める"
  - "`passes:true` への更新は検証コマンドの exit code 0 の evidence がある場合のみ（自己申告での更新をプロンプトで禁止し、driver 側でも検証コマンド再実行による抜き取り確認を行う）"
  - "headless 実行の permission は `--permission-mode` と `--allowedTools` で明示し、bypassPermissions を使わない"
  - "デモタスクによる E2E 検証（3 項目以上の feature-list を 2 セッション以上に分けて完走）を受け入れに含める"

### change-2: skill-eval（評価ハーネス新プラグイン）
- **スコープ**: 「スキルを書く前に評価を作れ」という公式の開発プロセスを新プラグイン `plugins/skill-eval/` として機構化する。
  1. **評価定義の規約**: 評価対象スキルの隣に `evals/scenarios.md`（3 シナリオ以上: 入力プロンプト・期待挙動・判定基準）を置く規約を定義。schema は `plugins/skill-eval/schemas/scenario.schema.json`
  2. **実行スキル**: `/skill-eval:run <plugin>:<skill>` — 各シナリオをサブエージェント（フレッシュコンテキスト）で実行し、LLM-as-judge（ルーブリック: 期待挙動の充足 / 指示への忠実さ / トークン効率。0.0〜1.0）で採点、`evals/results/<date>.md` にベースラインとして保存。2 回目以降は前回との差分を表示
  3. **Claude A/B 法スキル**: `/skill-eval:ab <plugin>:<skill>` — 設計役（スキルを読み改善案を出す）とフレッシュ実使用役（改善版でシナリオを実行）を交互に回す反復改善セッションのガイド
  4. **トリガー精度チェック**: `/skill-eval:trigger <plugin>:<skill>` — description だけを見て「このプロンプトで発火すべきか」を判定するテーブル（発火すべき 5 例・すべきでない 5 例）を生成・実行し、description の過発火/不発火を検出
- **使用スキル**: なし
- **依存関係**: 独立
- **config.yaml rules**:
  - "judge はフレッシュなサブエージェントで実行し、評価対象スキルの実行コンテキストと分離する"
  - "採点ルーブリックは schema 外部ファイルを唯一のソースとする（longrun GATE の踏襲）"
  - "MVP スコープ厳守: 対象はこの marketplace の skill のみ。任意リポジトリの skill 対応・CI 統合は backlog へ"
  - "サブエージェント消費が大きい（1 シナリオ=1 エージェント+judge）ため、1 回の run で実行するシナリオ数の上限をコマンド引数で制御できるようにする"

### change-3: e2s-skill-tuner（自己改善ループ）
- **スコープ**: `plugins/experience-to-skill/` に既存スキルの改善ループを追加する。公式事例（Claude 自身に失敗を診断させツール説明を書き換えさせ完了時間40%短縮）の機構化。
  1. **新コマンド**: `/e2s:tune <plugin>:<skill>` — cwd（および `~/.claude/projects/`）のセッション jsonl から対象スキルが発火したセッションを抽出し、サブエージェントに「混乱・手戻り・誤発火・指示の無視が起きた箇所」を診断させる（jsonl 解析は daily-report の `llm-log-compactor` の jq ロジックを流用し、生ログをメインに返さない）
  2. **改善提案の構造化**: 診断結果を `{発火判定の問題 | 指示の曖昧さ | 情報の欠落 | 過剰な指示}` に分類し、description・SKILL.md 本文への具体 diff 案として提示。**適用はユーザー承認後**（自動書き換えしない）
  3. **skill-eval 連携**: 対象スキルに `evals/scenarios.md` があれば、適用前後で `/skill-eval:run` を実行して改善を数値で確認する手順を組み込む（無ければ省略可のオプション扱い）
- **使用スキル**: なし（daily-report の jq パターンと e2s 既存の jsonl 抽出基盤を流用）
- **依存関係**: change-2（skill-eval 連携部分のみ。連携を除く本体は独立実装可）
- **config.yaml rules**:
  - "スキル本文の自動書き換えは禁止。必ず diff 提示 → ユーザー承認 → 適用の順"
  - "jsonl 解析はサブエージェントに隔離し、メインコンテキストに生ログを載せない"
  - "診断対象セッションが 0 件の場合は『データ不足』を明示して終了する（推測で改善案を出さない）"

### change-4: verify-gate（検証ゲート hook pack）
- **スコープ**: 「CLAUDE.md は助言、hook は保証」の公式定義に基づき、決定論的検証ゲートを配布可能な新プラグイン `plugins/verify-gate/` として実装する。
  1. **Stop hook: tests-pass gate**: 作業ディレクトリにテストコマンド設定（`.claude/verify-gate.json` 等）がある場合、Stop 時にテストを実行し、失敗していたら exit 2 + stderr で停止をブロックして修正を促す。設定が無いプロジェクトでは何もしない（opt-in）
  2. **PreToolUse hook: 破壊的 git 操作ガード**: `git push --force` / `git reset --hard` / `git clean -f` 等（`~/.claude/rules/git-commit-policy.md` の禁止リスト準拠）を deny し、明示承認を促すメッセージを返す
  3. **設定スキル**: `/verify-gate:setup` — 対象プロジェクトでゲートを対話的に有効化（テストコマンドの登録・ガード対象の選択）し、`.claude/verify-gate.json` を生成
  4. hooks は `${CLAUDE_PLUGIN_ROOT}` 参照で実装し、hook スクリプトは stdin JSON を 1 回だけ読む・出力上限に収める等の公式仕様（`research/claude-code-official.md` §3）に準拠
- **使用スキル**: なし
- **依存関係**: 独立
- **config.yaml rules**:
  - "ゲートは全て opt-in（設定ファイルが無ければ完全に無音・no-op）。plugin を入れただけで全プロジェクトの挙動が変わってはならない"
  - "Stop hook のテスト実行にはタイムアウトを設け、テストが遅い/壊れている場合に停止不能ループへ陥らないこと（連続ブロック回数の上限をコードで持つ）"
  - "hook スクリプトは bats でユニットテスト（stdin JSON を与えて exit code / stdout を検証）する"

### change-5: integration（marketplace 同期・README・使い分けガイド）
- **スコープ**: (1) 新設 2 プラグイン（skill-eval / verify-gate）の marketplace.json 登録、(2) 編集した全プラグイン（longrun / lr / experience-to-skill）の plugin.json version bump と marketplace.json 同期、(3) ルート README に 4 機構の位置づけ（どの公式ナレッジのどのギャップを埋めるか。`research/gap-analysis.md` へのリンク）を追記、(4) 受け入れ条件の統合検証一式の実行
- **使用スキル**: なし
- **依存関係**: change-1〜4 全て（同期は全編集完了後に直列実行）
- **config.yaml rules**:
  - "marketplace.json の version は各 plugin.json と完全一致させる"
  - "README への追記は各機構 2〜3 行の要約に留め、詳細は各プラグインの README / research/ に委ねる"

## モデル割り当て

ティアは `plugins/longrun/references/model-tiers.md` で解決する（モデル ID は書かない）。

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| change-1 | builder | inherit | driver の停止条件・headless 制御など安全性 critical な新規設計 | |
| change-1 | verifier | sonnet | デモタスク E2E とスクリプト検証（中規模） | |
| change-1 | reviewer | inherit | 暴走防止・課金実行制御のアーキテクチャレビュー | |
| change-2 | builder | inherit | 評価ルーブリック・judge 分離の新規設計 | |
| change-2 | verifier | sonnet | シナリオ実行の機能検証 | |
| change-2 | reviewer | inherit | 評価設計の妥当性判断 | |
| change-3 | builder | sonnet | 既存 jq 基盤流用の中規模実装 | |
| change-3 | verifier | haiku | diff 提示フロー・0件時挙動の定型検証 | |
| change-3 | reviewer | inherit | 自動書き換え禁止ガードの保全レビュー | |
| change-4 | builder | inherit | hook は全プロジェクトに影響しうる。公式仕様準拠と no-op 保証が critical | |
| change-4 | verifier | sonnet | bats による hook ユニットテスト検証 | |
| change-4 | reviewer | inherit | opt-in 設計・停止不能ループ回避の安全レビュー | |
| change-5 | builder | sonnet | version 同期・README 追記の定型作業 | |
| change-5 | verifier | haiku | 統合 grep 検証一式の定型実行 | |
| change-5 | reviewer | inherit | リポジトリ全体整合の最終レビュー | |

## 画面・UI設計
該当なし（CLI プラグイン。UI 成果物は生成しない）

## データモデル
- `feature-list.json` ↔ `plugins/longrun/schemas/feature-list.schema.json`（change-1 の真のソース）
- `evals/scenarios.md` ↔ `plugins/skill-eval/schemas/scenario.schema.json`
- `.claude/verify-gate.json`（対象プロジェクト側のゲート設定）
- marketplace.json ↔ 各 plugin.json の version 一致

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている（`find plugins -name '*.bats' -print0 | xargs -0 bats`）
3. [ ] ビルドエラーなし（全 .sh の `bash -n` PASS + .mjs の `node --check` PASS + 全 *.json の JSON parse PASS）
4. [ ] 統合テストがPASS（worktreeマージ後、下記 5-13 を main 上で再実行して全 PASS）

**機能固有の条件:**
5. [ ] `plugins/longrun/scripts/session-loop.sh` が存在し、停止条件 3 種（セッション上限・全項目PASS・連続失敗上限）が bash 条件式として grep で確認できる
6. [ ] `plugins/longrun/schemas/feature-list.schema.json` が存在し JSON parse PASS。テンプレート 2 種（init / feature セッション）が `plugins/longrun/templates/session-loop/` に存在する
7. [ ] デモタスク（3 項目以上の feature-list）を session-loop で 2 セッション以上に分けて完走し、feature-list.json の全項目が evidence 付きで `passes:true` になったログが `{longrun-dir}` に残っている
8. [ ] `/longrun:loop` と `/lr:l` のコマンドが存在し、exec.md と README に exec / loop の使い分けが記載されている
9. [ ] `plugins/skill-eval/` が存在し、run / ab / trigger の 3 コマンドと scenario.schema.json を持つ。このリポジトリ内の実スキル 1 つ以上に `evals/scenarios.md`（3 シナリオ以上）が作成され、`/skill-eval:run` の結果ファイルが生成できる
10. [ ] `/e2s:tune` コマンドが存在し、(a) 自動書き換えをしない（diff 提示→承認フロー）、(b) 対象セッション 0 件時にデータ不足で終了する、の 2 点が定義に明記されている
11. [ ] `plugins/verify-gate/` が存在し、Stop hook / PreToolUse hook / setup スキルを持つ。設定ファイルが無い環境で両 hook が no-op であることが bats で検証されている
12. [ ] verify-gate の Stop hook に連続ブロック回数上限とタイムアウトがコードとして存在する
13. [ ] 新設 2 プラグインが marketplace.json に登録され、編集した全プラグインで plugin.json version が bump され marketplace.json と一致する

## 意思決定ガイドライン
- 優先順位: 安全性（暴走・課金・停止不能ループの防止） > 公式アーキテクチャへの忠実さ > シンプルさ > 機能の豊富さ
- リスク許容度: change-1 と change-4 は保守的に（headless 課金実行と hook は影響が大きい）。change-2 / 3 は MVP 割り切りで小さく作る
- 不明点の扱い: 公式アーキテクチャの解釈に迷ったら `research/claude-code-official.md` §7（harnesses 論文の要点）と `research/gap-analysis.md` を再読。それでも曖昧なら「小さく作って decisions.md に論点記録」に倒す
- 各機構は独立に価値が出る MVP を優先し、相互連携（e2s-tune → skill-eval 等）は疎結合のオプションに留める
- 実装中に見つけた拡張候補（CI 統合・任意リポジトリ対応等）は実装せず `openspec/backlog.md` に記録する

## 動作確認方法
- 開発サーバー: なし
- テスト: `find plugins -name '*.bats' -print0 | xargs -0 bats` / `bash -n plugins/*/scripts/*.sh` / hook への stdin JSON 注入テスト
- 確認手順:
  1. 受け入れ条件 5-13 の各検証コマンドを実行し全て期待値になることを確認
  2. **session-loop デモ**: 小さなデモリポジトリ（または本リポジトリの安全なサンドボックス dir）で 3 項目の feature-list を作り、`session-loop.sh` をセッション上限 4 で実行 → 完走・commit 履歴・progress notes を確認。次に故意に 1 項目の検証コマンドを失敗させ、連続失敗上限で停止することを確認
  3. **skill-eval デモ**: 既存スキル 1 つに scenarios.md を書き `/skill-eval:run` → 結果ファイルとスコアを確認
  4. **verify-gate デモ**: サンドボックスプロジェクトで `/verify-gate:setup` → わざとテストを壊して Stop がブロックされること、設定削除で no-op に戻ることを確認
  5. マージ後、新セッションで `/reload-plugins` → `/plugin install skill-eval@oratta-claude-harness` 等で新プラグインが見えることを確認

## Brain Dumpからの原文メモ
> /goal Anthropic公式ナレッジ調査→claude-harness実装 goal指示書
>
> （初版への フィードバック）loopに関してはなんかなかった？今、ちょっと思ったのと違うのは、既存のものをどう活かしてほしいわけじゃなくて、アンソロピックはこういう風に使うべきだって言ってるけども、普通に使ってるだけじゃ実現できないものみたいなものをハーネスとして追加したいっていうふうになってたんで、そういう動き方できてたんでしょうか。
>
> （解釈: 既存プラグインの品質監査ではなく、「公式推奨 − 素の Claude Code の標準機能 = ギャップ」を新しいハーネス機構として実装する。ギャップ分析は research/gap-analysis.md に、既存資産監査は plan-b-existing-audit.md に分離）

---

## 付録: 各 change の公式ナレッジ根拠（一次ソース要約）

### 付録 A: change-1 (session-loop) の根拠
`research/claude-code-official.md` §7「長時間エージェントのハーネス」（effective-harnesses-for-long-running-agents、本文直接確認済み）:
- 「**compaction だけでは不十分**。セッションをまたぐ一貫性は、外部状態ファイル + git で担保する」
- 「**init エージェント**（初回のみ環境セットアップ）と **coding エージェント**（以降、段階的に前進）を、同じツール・異なるプロンプトで分ける」
- 「状態の外部化: 機能リストファイル（JSON で `passes:false` 列挙）、`init.sh`、`claude-progress.txt`、初期 git commit」
- 「**1セッション1機能**に限定して過剰実装を防ぐ。セッション末に説明的な git commit」
- 「丁寧なテスト後にのみ `passing` を立てる。セッション開始時に基本機能の動作確認をしてバグを早期検出」

`research/anthropic-agent-knowledge.md` ソース11（prompting）: 「トークン残量を理由に早期終了するな、限界前に progress を保存せよ」「`tests.json` で構造化テスト管理（テスト削除禁止を明記）」「状態追跡は git（最新モデルは git での複数セッション跨ぎ状態管理が得意）」

素の Claude Code とのギャップ: /loop・cron・auto memory・compaction はあるが、「fresh context のセッションを外部状態から再開させる駆動ループ」「passes の evidence 管理」「1セッション1機能の強制」は全て自前実装が必要（gap-analysis #1）。longrun の resumeFromRunId same-session 制約（repo-survey 弱点H）もこの機構が実質解となる。

### 付録 B: change-2 (skill-eval) の根拠
- ソース10（skill authoring）: 「**広範なドキュメントを書く前に評価を作れ**。skill なしで実行しギャップ記録 → 3シナリオ評価 → ベースライン測定 → 最小限の命令 → 反復」「**Claude A/B 法**（設計役 A とフレッシュ実使用役 B を交互）」
- ソース2（multi-agent）: 「評価は約20クエリの小規模から始めよ。LLM-as-judge（0.0〜1.0、ルーブリック=factual accuracy/citation/completeness/source quality/tool efficiency）」
- ソース6（Agent Skills）: 「Claude 視点で name/description を**実使用ログで磨く**」
- 素の Claude Code とのギャップ: 評価の機構は一切なく全て手動（gap-analysis #2）。

### 付録 C: change-3 (e2s-tune) の根拠
- ソース2（multi-agent）: 「Claude 自身に失敗を診断させツール説明を書き換えさせ、**完了時間40%短縮**を達成」
- ソース3（writing-tools）: 「Agent 自身に評価トランスクリプトを分析させ改善提案させる（"with agents" の由来）」
- 素の Claude Code とのギャップ: セッション jsonl はあるが、それを既存スキルの改善に還流する機構は無い。e2s は新スキル蒸留のみ（gap-analysis #3）。

### 付録 D: change-4 (verify-gate) の根拠
- ソース9（Claude Code best practices）: 「拡張機能の責務: **hooks=毎回例外なく起きる決定論的アクション（CLAUDE.md は助言的、hook は保証）**」「ゲート強度4段階: プロンプト指示 < /goal 条件 < **Stop フックで決定論的ブロック** < 検証サブエージェント」「『成功した』と主張させず evidence 提示させる」
- `research/claude-code-official.md` §3（hooks 公式仕様）: exit 2 + stderr でブロック、stdin JSON は 1 回のみ、出力上限、`${CLAUDE_PLUGIN_ROOT}` 参照。
- 素の Claude Code とのギャップ: hooks 機構自体は本体にあるが、検証ゲートは毎回自前で書く必要があり、配布可能な hook pack が無い（gap-analysis #4）。

### 付録 E: 今回対応しないギャップ（判定済み）
- **defer_loading / Tool Search / Tool Use Examples**（gap-analysis #9）: API・本体提供済み。ハーネス不要
- **compaction / auto memory / subagents / worktree**（#10）: 本体提供済み
- **既存資産のコンテンツ品質**（#6〜8, #11〜12）: `plan-b-existing-audit.md` に分離済み。本 run 完了後に別 run で実施可
