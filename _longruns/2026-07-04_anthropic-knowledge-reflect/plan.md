# Plan: Loop Engineering をハーネスとして実装する（anthropic-knowledge-reflect）

## 生成情報
- 作成日: 2026-07-04
- Brain Dump元: /goal 指示「Anthropic公式ナレッジ調査→claude-harness実装 goal指示書」+ フィードバック2件（①既存資産の活用ではなく「公式が推奨するが普通に使うだけでは実現できないもの」をハーネスとして追加したい ②loop engineering で調べ直せ）
- 中核コンセプト: **Loop Engineering**（2026-06 成立。Boris Cherny [Anthropic・Claude Code 責任者]「I don't prompt Claude anymore. My job is to write loops.」）。詳細は `research/loop-engineering.md`
- 別トラック: 既存資産のコンテンツ品質監査は `plan-b-existing-audit.md` に分離済み

## ゴール
「エージェントに人間がプロンプトする」から「**エージェントをプロンプトするループを設計する**」への転換（Loop Engineering）を、このハーネスの機構として実装する。Claude Code 本体はループの**部品**（/loop・/goal・cron・worktree・skills・MCP・subagents）を提供済みだが、「**設計されたループそのもの**」——ループ定義の規約、State レイヤー、discovery（仕事を自分で見つける）、generator/evaluator 分離の汎用部品、ループの安全監査——は提供していない。このギャップを新プラグイン `loops` と longrun 拡張として埋める。

## ビジネスコンテキスト
- 対象ユーザー: このユーザー本人（marketplace の唯一のメンテナ兼利用者）
- 提供価値: (1) 「人間が plan を書いて渡す」（現行 longrun）から「ループが仕事を見つけて回り、人間は例外だけ処理する」への移行、(2) ループを1枚の定義ファイルで宣言・監査できるため、Cherny の言う「ループを書く仕事」が再利用可能な資産になる、(3) 停止条件・予算・無進捗検出を機構で持つため、悪いループ（暴走・報酬ハッキング・検証なき成功宣告）を設計段階で排除できる
- 成功指標: 受け入れ条件の機械検証が全て PASS。canonical loop 2 本（triage / build）が実タスクでデモ完走する

## 一次ソース（実装時の判断基準）
builder / reviewer は迷ったら以下を参照する（全て本 run の `research/` に保存済み・URL 実在確認済み）:
- `research/loop-engineering.md` — **本 plan の中核**。5+1 構成要素（Automations / Worktrees / Skills / Connectors / Sub-agents / State）、5つのムーブ（discovery→handoff→verification→persistence→scheduling）、generator/evaluator/loop の3部構成、失敗6類型、Good/Bad Loop
- `research/gap-analysis.md` — 公式推奨 × 素のCC × 既存ハーネスの判定表
- `research/claude-code-official.md` — §7 に harnesses 論文の要点（build loop の外部状態設計の原典）
- `research/anthropic-agent-knowledge.md` — engineering 記事11本（evaluator のルーブリック設計・敵対的レビュー・fan-outコスト等）

## 技術要件
- スタック: Markdown（SKILL.md / commands / agents）+ bash / node スクリプト + JSON Schema + bats-core + `claude -p`（headless）+ cron ルーチン（/schedule）
- 参照パターン:
  - schema 契約: `plugins/longrun/schemas/*.schema.json`（外部ファイルが唯一のソース）
  - 実装者/検証者分離の既存形: longrun の builder / verifier / reviewer agents
  - worktree 隔離: `plugins/worktree/`（wt-setup --with-pr の Draft PR バックアップ運用）
- 制約:
  - `~/.claude/rules/plugin-editing.md` 準拠: version bump + marketplace.json 同期必須
  - このリポジトリの CLAUDE.md 準拠: worktree 作業は Draft PR バックアップ、main 直 push 禁止
  - モデル ID 直書き禁止（`plugins/longrun/references/model-tiers.md` が唯一のソース）
  - **ループの停止条件はコードの条件式で持つ**（LLM の自制に依存しない。longrun 既存 GATE の踏襲）。headless / cron 実行は課金実行のため、反復上限・トークン予算・無進捗検出の 3 種を必須とする
  - ループが行う外向きアクション（PR 作成・issue 更新）は Draft / 非破壊デフォルト。マージ等の不可逆操作は人間へのエスカレーションに倒す
- テストフレームワーク: bats-core + `node --check` + grep ベース検証
- テスト実行コマンド: `find plugins -name '*.bats' -print0 | xargs -0 bats`

## スコープ
### 含むもの
- ループ定義規約・State 規約・設計/監査スキルを持つ新プラグイン `loops`（change-1）
- canonical loop その1: **triage loop**（discovery 型。仕事を自分で見つける）（change-2）
- canonical loop その2: **build loop**（long-horizon 型。harnesses 論文の外部状態設計）（change-3）
- generator/evaluator 分離の汎用部品と決定論的検証ゲート（change-4）
- marketplace 同期・README・コストガードレール文書（change-5）

### 含まないもの
- 既存資産のコンテンツ品質監査（`plan-b-existing-audit.md` に分離済み）
- skill 評価ハーネス（skill-eval）と e2s 自己改善ループ（理由: 前版 plan の候補だったが、これらは「スキルを改善するループ」であり本 plan の loops 基盤の上に将来のループとして実装する方が筋が良い。`openspec/backlog.md` へ記録）
- Slack / Linear 等の外部コネクタ統合（理由: このユーザーの現行ワークフローは gh CLI + openspec/backlog.md で足りる。必要になったら個別ループに追加）
- harvest / sns-strategy 等、別 marketplace のプラグイン（対象リポジトリ外。ただし loops の規約はそちらでも使える設計にする）

## Changes分解

### change-1: loops-foundation（ループ定義規約と設計・監査スキル）
- **スコープ**: 新プラグイン `plugins/loops/` を作り、Loop Engineering の土台を実装する。
  1. **ループ定義規約**: `loops/<name>.loop.md`（YAML frontmatter + 本文）を規約化。必須フィールド: `goal`（テスト可能な完了条件）/ `trigger`（cron | 手動 | イベント）/ `discovery`（仕事の見つけ方）/ `generator`（実装エージェントと委譲契約4点）/ `evaluator`（検証エージェント or 決定論コマンドとルーブリック）/ `stop`（**反復上限・トークン予算・無進捗検出の3種必須**）/ `persist`（State への書き込み内容）/ `escalation`(人間に返す条件)。schema は `plugins/loops/schemas/loop-definition.schema.json`
  2. **State 規約**: `{project}/loops/state/<loop-name>.state.md` に「現在の作業 / 前回の試行と結果 / 人間への引き継ぎ待ち」を記録する形式を定義（「エージェントは忘れるが、リポジトリは記憶する」）。テンプレートを同梱
  3. **`/loops:design`**: 対話インタビューでループ定義を作成するスキル（longrun-plan のインタビュー方法論を流用）。5つのムーブ（discovery→handoff→verification→persistence→scheduling）を順に埋め、Bad Loop 検査（停止条件の欠如・検証なき成功宣告・報酬ハッキング余地）を組み込む
  4. **`/loops:audit`**: 既存ループ定義を機械チェックするスキル。停止3種の有無 / evaluator の独立性（generator と同一エージェントに採点させていないか）/ 外向きアクションの非破壊性 / State 書き込みの有無を検査し、失敗6類型（`research/loop-engineering.md`）に照らしたレポートを出す
  5. **`/loops:run`**: ループ定義を読み、trigger に応じて実行をセットアップする（cron なら /schedule ルーチン登録、手動なら即時1周実行）。実行1周は「discovery → handoff（worktree + generator）→ verification（evaluator）→ persistence（state 更新）→ scheduling（次回予約 or 停止）」の5ムーブを踏む
- **使用スキル**: なし（longrun の plan-interview-methodology.md を参照流用）
- **依存関係**: 独立（change-2〜4 の前提）
- **config.yaml rules**:
  - "loop-definition.schema.json が唯一のソース。スキル本文へ JSON 構造を重複コピーしない"
  - "stop 3種（反復上限・予算・無進捗検出）が欠けた定義は /loops:run が実行を拒否する（audit 任せにしない）"
  - "MVP スコープ厳守: trigger は cron と手動の 2 種のみ。イベント駆動（webhook 等）は backlog へ"

### change-2: triage-loop（canonical loop その1: 仕事を自分で見つける）
- **スコープ**: Osmani essay の代表例（朝のトリアージループ）をこのリポジトリの実情に合わせた ready-made ループ定義 + 支援スキルとして実装する。
  1. **ループ定義**: `plugins/loops/templates/triage.loop.md` — discovery: 対象リポジトリの (a) CI 失敗（`gh run list`）、(b) open issues / PR レビューコメント（`gh`）、(c) `openspec/backlog.md` の未消化項目 を読み、優先度付きタスクリストを作る → handoff: タスク毎に worktree を切り generator subagent に委譲（委譲契約4点付き）→ verification: evaluator subagent + テスト実行 → 外向きアクション: **Draft PR 作成まで**（マージは人間）→ persistence: state 更新と人間向けサマリ → scheduling: cron（朝次）
  2. **トリアージの努力量スケーリング**: 発見タスク数に応じた fan-out 上限（同時 worktree 数・1周あたり処理タスク数）を定義側のパラメータで持つ（multi-agent 論文の「単純クエリに50サブエージェント」暴走の防止）
  3. **デモ**: このリポジトリ自身を対象に 1 周実行し、backlog から拾ったタスクが Draft PR + state 更新まで到達することを確認
- **使用スキル**: worktree（wt-setup 相当の隔離）、loops-foundation の実行系
- **依存関係**: change-1
- **config.yaml rules**:
  - "外向きアクションは Draft PR / issue コメントまで。merge・close・force 系は escalation（人間）に必ず倒す"
  - "discovery で拾ったが処理しなかったタスクは state に『未処理として繰り越し』を明記する（silent drop 禁止）"
  - "同一タスクで 2 周連続 evaluator FAIL したらそのタスクを凍結して人間へエスカレーション（無限リトライ禁止）"

### change-3: build-loop（canonical loop その2: long-horizon ビルド）
- **スコープ**: harnesses 論文の外部状態設計（feature-list + progress notes + 1セッション1機能）を、change-1 のループ定義形式に載せた long-horizon ビルドループとして longrun に追加する。
  1. **ループ定義**: `plugins/longrun/templates/build.loop.md` — goal: feature-list.json の全項目 `passes:true` / discovery: `passes:false` の先頭項目を 1 つ選ぶ / generator: fresh session（`claude -p`）で 1 項目のみ実装 / evaluator: 各項目の `verification` コマンド実行（exit code 0 の evidence がある場合のみ `passes:true` 更新）/ persist: `claude-progress.md` 追記 + 説明的 commit / stop: セッション上限・全PASS・連続失敗上限
  2. **feature-list 契約**: `plugins/longrun/schemas/feature-list.schema.json`（各項目 `{id, description, verification, passes:false}`）。項目・テストの削除禁止を明記
  3. **driver**: `plugins/longrun/scripts/build-loop.sh` — 停止3種を bash 条件式で実装。セッション開始時 smoke check（直近 passing 項目の検証コマンド再実行）
  4. **エントリポイント**: `/longrun:loop <longrun-dir>` + `/lr:l`。既存 `/longrun:exec` との使い分け（1セッションに収まる規模=exec / 収まらない規模=loop）を exec.md と README に明記
- **使用スキル**: loops-foundation の規約（定義形式・state）
- **依存関係**: change-1
- **config.yaml rules**:
  - "generator セッションのプロンプトに『1セッション1項目のみ』『トークン残量を理由に途中終了せず、区切りの良い状態で commit して progress に引き継ぎを書く』を含める"
  - "`passes:true` への更新は evaluator（検証コマンド）の exit code 0 evidence がある場合のみ。generator の自己申告更新を禁止し、driver 側でも抜き取り再実行する"
  - "headless 実行は `--permission-mode` と `--allowedTools` を明示し bypassPermissions を使わない"
  - "デモタスク（3項目以上の feature-list）を 2 セッション以上に分けて完走する E2E 検証を受け入れに含める"

### change-4: evaluator-pack（generator/evaluator 分離の汎用部品）
- **スコープ**: 「自分の成果物を自分で採点させない」を任意のループに差し込める汎用部品にする。
  1. **汎用 evaluator agent**: `plugins/loops/agents/loop-evaluator.md` — フレッシュコンテキストで diff / 成果物 / ルーブリックだけを見て採点する。プロンプトに「correctness / 要件に関わるギャップのみ flag する（健全でも何か報告しようとする過剰指摘を抑止）」を明記（Claude Code best practices の敵対的レビュー原則）。返却は `plugins/loops/schemas/evaluator-verdict.schema.json`（verdict / evidence / 修正指示）に準拠
  2. **決定論 evaluator の優先原則**: ループ定義の evaluator フィールドは「決定論コマンド（テスト・型チェック・lint）を第一候補、LLM-judge は検証不可能な性質（文章品質等）に限定」を schema の説明と /loops:design のインタビューに組み込む
  3. **verify-gate hook（opt-in）**: `plugins/loops/hooks/` に Stop hook を同梱。対象プロジェクトに `.claude/loops-gate.json`（テストコマンド登録）がある場合のみ、Stop 時にテストを実行し失敗なら exit 2 でブロック。**設定が無ければ完全 no-op**。連続ブロック回数上限とタイムアウトをコードで持つ
- **使用スキル**: なし
- **依存関係**: change-1（schema 配置と /loops:design への組み込み）
- **config.yaml rules**:
  - "evaluator agent は評価対象を生成したコンテキストから隔離する（fresh subagent）。generator と同一セッション内での自己評価をループ定義上許可しない"
  - "hook は plugin を入れただけで挙動が変わらないこと（設定ファイル無し=no-op）を bats で検証する"
  - "hook スクリプトは stdin JSON を1回だけ読む・出力上限に収める等の公式仕様（research/claude-code-official.md §3）に準拠する"

### change-5: integration（marketplace 同期・README・コストガードレール）
- **スコープ**: (1) 新プラグイン `loops` の marketplace.json 登録、(2) 編集した全プラグイン（longrun / lr / loops）の version bump と同期、(3) ルート README に Loop Engineering の位置づけ（prompt ⊂ context ⊂ harness ⊂ loop、Cherny の引用、`research/loop-engineering.md` へのリンク）を追記、(4) **コストガードレール文書**: ループはチャットの約4倍、マルチエージェント構成は約15倍のトークンを消費する事実と、予算設定の目安を `plugins/loops/references/cost-guardrails.md` に記載、(5) 受け入れ条件の統合検証
- **使用スキル**: なし
- **依存関係**: change-1〜4 全て（同期は最後に直列実行）
- **config.yaml rules**:
  - "marketplace.json の version は各 plugin.json と完全一致させる"
  - "README への追記は要約に留め、詳細は plugins/loops/ 側と research/ に委ねる"

## モデル割り当て

ティアは `plugins/longrun/references/model-tiers.md` で解決する（モデル ID は書かない）。

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| change-1 | builder | inherit | 規約・schema・実行拒否ロジックの新規設計 | |
| change-1 | verifier | sonnet | schema/スキル整合の中規模検証 | |
| change-1 | reviewer | inherit | ループ規約の設計レビュー（以降全 change の土台） | |
| change-2 | builder | inherit | 外向きアクション制御と fan-out 上限が安全性 critical | |
| change-2 | verifier | sonnet | デモ1周の E2E 検証 | |
| change-2 | reviewer | inherit | 非破壊デフォルト・エスカレーション設計のレビュー | |
| change-3 | builder | inherit | headless driver・停止条件など安全性 critical な実装 | |
| change-3 | verifier | sonnet | デモタスク E2E とスクリプト検証 | |
| change-3 | reviewer | inherit | 暴走・課金制御のアーキテクチャレビュー | |
| change-4 | builder | sonnet | agent 定義 + schema + hook の中規模実装 | |
| change-4 | verifier | sonnet | hook の bats ユニットテスト検証 | |
| change-4 | reviewer | inherit | 自己評価禁止・no-op 保証の安全レビュー | |
| change-5 | builder | sonnet | version 同期・README 追記の定型作業 | |
| change-5 | verifier | haiku | 統合 grep 検証一式の定型実行 | |
| change-5 | reviewer | inherit | リポジトリ全体整合の最終レビュー | |

## 画面・UI設計
該当なし（CLI プラグイン）

## データモデル
- `loops/<name>.loop.md` ↔ `plugins/loops/schemas/loop-definition.schema.json`（ループの真のソース）
- `loops/state/<name>.state.md`（State レイヤー規約）
- `feature-list.json` ↔ `plugins/longrun/schemas/feature-list.schema.json`（build loop の真のソース）
- evaluator 返却 ↔ `plugins/loops/schemas/evaluator-verdict.schema.json`
- `.claude/loops-gate.json`（対象プロジェクト側の opt-in ゲート設定）
- marketplace.json ↔ 各 plugin.json の version 一致

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている（`find plugins -name '*.bats' -print0 | xargs -0 bats`）
3. [ ] ビルドエラーなし（全 .sh の `bash -n` PASS + .mjs の `node --check` PASS + 全 *.json の JSON parse PASS）
4. [ ] 統合テストがPASS（worktreeマージ後、下記 5-14 を main 上で再実行して全 PASS）

**機能固有の条件:**
5. [ ] `plugins/loops/` が存在し、design / audit / run の 3 スキルと loop-definition.schema.json / evaluator-verdict.schema.json を持つ
6. [ ] loop-definition.schema.json が stop 3種（反復上限・トークン予算・無進捗検出）を必須フィールドとして定義し、stop が欠けた定義で `/loops:run` が実行を拒否することがテストで確認できる
7. [ ] State 規約テンプレートが存在し、「現在の作業 / 前回の試行と結果 / 人間への引き継ぎ待ち」の 3 節を持つ
8. [ ] `plugins/loops/templates/triage.loop.md` が存在し schema 検証を通る。このリポジトリを対象にしたデモ 1 周で「discovery → worktree → generator → evaluator → Draft PR → state 更新」が完走したログが `{longrun-dir}` に残っている
9. [ ] triage loop の外向きアクションに merge / close / force 系が含まれないことが定義と実装の grep で確認できる
10. [ ] `plugins/longrun/scripts/build-loop.sh` が存在し、停止条件 3 種が bash 条件式として grep で確認できる。feature-list.schema.json が存在し JSON parse PASS
11. [ ] デモタスク（3項目以上の feature-list）を build loop で 2 セッション以上に分けて完走し、全項目が evidence 付きで `passes:true` になったログが残っている
12. [ ] `plugins/loops/agents/loop-evaluator.md` が存在し、委譲契約 4 点と「correctness / 要件に関わるもののみ flag」の記述を持つ
13. [ ] verify-gate hook が設定ファイル無し環境で no-op であること、連続ブロック上限・タイムアウトを持つことが bats で検証されている
14. [ ] `loops` が marketplace.json に登録され、編集した全プラグインで plugin.json version が bump され marketplace.json と一致する

## 意思決定ガイドライン
- 優先順位: 安全性（暴走・課金・不可逆アクションの防止） > Loop Engineering アーキテクチャへの忠実さ > シンプルさ > 機能の豊富さ
- リスク許容度: 保守的。特に「ループが自分で仕事を見つけて外向きアクションを打つ」triage loop は非破壊デフォルト（Draft PR まで）を厳守
- Good Loop 原則の内面化: 「ループの完了は主張であり証明ではない」。全ループで evidence（テスト出力・exit code）を state に残す設計とし、検証なき成功宣告を機構で禁止する
- 不明点の扱い: Loop Engineering の解釈に迷ったら `research/loop-engineering.md` の 5+1 構成要素と失敗 6 類型に立ち返る。それでも曖昧なら「小さく作って decisions.md に論点記録」
- 実装中に見つけた拡張候補（イベント駆動 trigger・外部コネクタ・skill-eval/e2s-tune のループ化）は実装せず `openspec/backlog.md` に記録する

## 動作確認方法
- 開発サーバー: なし
- テスト: `find plugins -name '*.bats' -print0 | xargs -0 bats` / `bash -n` / hook への stdin JSON 注入テスト
- 確認手順:
  1. 受け入れ条件 5-14 の各検証コマンドを実行し全て期待値になることを確認
  2. **loops:design デモ**: 対話で小さなループ定義を 1 本作り、schema 検証と `/loops:audit` が通ることを確認。stop を故意に欠落させ、run が拒否することを確認
  3. **triage デモ**: このリポジトリを対象に 1 周実行（backlog 由来タスク → Draft PR → state 更新）。処理しなかったタスクの繰り越しが state に残ることを確認
  4. **build デモ**: 3 項目の feature-list をセッション上限 4 で完走。次に 1 項目の検証コマンドを故意に失敗させ、連続失敗上限で停止することを確認
  5. **verify-gate デモ**: サンドボックスで設定を有効化 → テストを壊して Stop がブロックされること、設定削除で no-op に戻ることを確認
  6. マージ後、新セッションで `/plugin install loops@oratta-claude-harness` → `/reload-plugins` で新プラグインが見えることを確認

## Brain Dumpからの原文メモ
> /goal Anthropic公式ナレッジ調査→claude-harness実装 goal指示書
>
> （フィードバック1）既存のものをどう活かしてほしいわけじゃなくて、アンソロピックはこういう風に使うべきだって言ってるけども、普通に使ってるだけじゃ実現できないものみたいなものをハーネスとして追加したい
>
> （フィードバック2）違うな、それloopじゃない。loop engineeringで調べてみて
>
> （解釈: 中核コンセプトは Loop Engineering [Cherny/Steinberger/Osmani, 2026-06]。「エージェントをプロンプトするループを設計する」ための機構——ループ定義規約・State・discovery・generator/evaluator 分離・監査——をハーネスに追加する。既存資産監査は plan-b、調査資料は research/ に分離）

---

## 付録: 各 change の根拠（一次ソース要約）

### 付録 A: change-1 (loops-foundation) の根拠
`research/loop-engineering.md`:
- ループの解剖学 = 5つのムーブ（discovery → handoff → verification → persistence → scheduling）と 5+1 構成要素（Automations / Worktrees / Skills / Connectors / Sub-agents / **State**）
- 「明確でテスト可能な終了条件を持つ目標。**停止条件の欠如が最も一般的な失敗**。複数の独立した出口（ルーブリック通過 / 予算切れ / 反復上限 / 無進捗検出）」
- State: 「エージェントは忘れるが、リポジトリは記憶する」。STATE.md に現在の作業・前回の試行と結果・人間への引き継ぎ待ち
- 素の Claude Code とのギャップ: 部品（/loop・/goal・cron・worktree・subagents）はあるが、**ループ定義の規約・State 規約・監査の道具が無く、毎回アドホックに組む**しかない
- 先行実装の存在確認: loop-audit / loop-init / loop-cost（https://github.com/cobusgreyling/loop-engineering）

### 付録 B: change-2 (triage-loop) の根拠
- Osmani essay の代表例: 「朝の automation 実行 → CI 失敗と open issues をトリアージ → タスク毎に隔離 worktree → 第一サブエージェントが修正案 → 第二サブエージェントが検証 → コネクタで PR 作成 → state へ保存 → 翌日 state から再開」
- Cherny: 「ループが実行されて Claude にプロンプトを与え、何をすべきか見つけ出す」——**discovery（仕事を自分で見つける）が現行ハーネスに無い最大の欠落**（longrun は人間が plan を書く起点）
- fan-out 上限: multi-agent 論文（`research/anthropic-agent-knowledge.md` ソース2）「努力量スケーリングルールをスキル内に明記して暴走を防ぐ」

### 付録 C: change-3 (build-loop) の根拠
- `research/claude-code-official.md` §7（harnesses 論文、本文直接確認済み）: 「compaction だけでは不十分。外部状態ファイル + git」「機能リスト JSON（`passes:false`）」「1セッション1機能」「丁寧なテスト後にのみ passing」「セッション開始時に動作確認」
- `research/anthropic-agent-knowledge.md` ソース11: 「トークン残量を理由に早期終了するな」「テスト削除禁止を明記」「状態追跡は git が得意」
- Loop Engineering との合流: build loop は「trigger=手動/駆動スクリプト、discovery=passes:false の先頭、evaluator=検証コマンド」という**ループ定義形式の一具体例**として実装する（前版 plan の session-loop 設計を規約に載せ直したもの）

### 付録 D: change-4 (evaluator-pack) の根拠
- `research/loop-engineering.md`: 3部構成「generator + evaluator + loop」。「**実装者と検証者を分離**（自分の成果物を自分で評価する構造的課題の解決）」「決定論的検証（テスト・型チェッカー）を報酬信号として信頼し、LLM 判定は検証不可能な場面に限定」
- `research/anthropic-agent-knowledge.md` ソース9: 敵対的レビューは「correctness / 要件に関わるもののみ flag」。「hooks = 決定論的アクション（CLAUDE.md は助言、hook は保証）」
- 失敗類型「検証なしでの成功宣告」への機構的対策が verify-gate

### 付録 E: 今回対応しないもの（判定済み）
- **skill-eval / e2s-tune**（前版 plan の change-2/3）: 「スキルを改善するループ」として loops 基盤の上に将来実装する方が一貫する。backlog へ
- **イベント駆動 trigger・外部コネクタ（Slack/Linear）**: 現行ワークフローでは gh + backlog で足りる。backlog へ
- **既存資産のコンテンツ品質監査**: `plan-b-existing-audit.md` に分離済み
