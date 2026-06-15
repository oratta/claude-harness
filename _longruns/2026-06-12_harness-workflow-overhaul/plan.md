---
options:
  integrate: true   # change-5 が別リポジトリ（marketing-harness）のためマルチリポジトリ統合を有効化
---

# Plan: harness 大型改修 — longrun Workflow 化・StructuredOutput 契約・OpenSpec 縮退・MVP 分離・モデル割り当て

## 生成情報
- 作成日: 2026-06-12
- Brain Dump元: `/Users/oratta/Dropbox/Application/Obsidian/oratta2025/harness大型改修プラン素材 - longrun Workflow化・StructuredOutput契約・OpenSpec同梱.md`
- 質問回数: 6問（スコープ / 実行構造 / MVPモード×2 / status・decisions / モデル割り当て）

## ゴール

longrun の手書きオーケストレーション（SKILL.md インライン展開 + Agent 手動制御 + checkpoint.md 散文パース）を Claude Code の Workflow ツールに載せ替え、サブエージェント契約を JSON Schema（StructuredOutput）で機構的に強制する。あわせて OpenSpec CLI 不可環境の縮退モード、MVP モードの独立スキル分離、plan 段階のモデル割り当てリコメンド機構を導入し、harness 全体の堅牢性と保守性を一段引き上げる。

## ビジネスコンテキスト
- 対象ユーザー: oratta 本人（claude-harness / marketing-harness の唯一の開発・運用者）
- 提供価値: 散文契約のドリフトによる無言の破壊を構造的に排除し、自律実行の暴走（Verify ループ無限化）を上限とコードで防止する。長時間 run の中断再開を `resumeFromRunId` で確実にする
- 成功指標: 代表 plan.md 1 本が新アーキテクチャで完走する / Verify ループが上限で必ず停止する / 不正形式のサブエージェント出力が検証層で 100% 検出される

## 技術要件
- スタック: Claude Code プラグイン（markdown skill / agent / command）、Workflow ツール（`agent()` / `pipeline()` / `parallel()` / `resumeFromRunId` / `opts.schema` / `opts.model` / `opts.agentType`）、bash スクリプト、jq
- 参照パターン:
  - Workflow スクリプトの作法: Workflow ツールの組み込みドキュメント（meta ピュアリテラル / Date.now() 不可 / ネスト1段 / JS のみ）
  - 既存 agent 定義: `plugins/longrun/agents/*.md`（`agentType: 'longrun:longrun-builder'` 等でそのまま再利用、書き直し不要）
  - bats テスト: `plugins/experience-to-skill/tests/`・`plugins/daily-report/tests/`（claude-harness 側）、`plugins/harvest/tests/`（marketing-harness 側、既存 `@test` 313 本）
- 制約:
  - marketplace 版のみを編集（`~/.claude/rules/plugin-editing.md`）
  - version 同期は plugin.json / marketplace.json top-level / marketplace.json plugins[] の **3 箇所**（過去に同期漏れ事故あり。PR #5 で解消直後）
  - worktree は `~/.superset/worktrees/` 配下 + `--with-pr`（Draft PR バックアップ）。PR は change ごとに分ける。マージは承認制
  - Workflow スクリプト内で `Date.now()` / `Math.random()` / argless `new Date()` 使用禁止（タイムスタンプは args 注入）
  - main への直接 push 禁止
- テストフレームワーク: bats（bats-core）。スクリプト・schema・分岐ロジックの単体テストに使用
- テスト実行コマンド:
  - claude-harness: `bats plugins/longrun/tests/`（新設）
  - marketing-harness: `bats plugins/harvest/tests/`（既存スイートに追加）

## スコープ

### 含むもの
- **change-1 (C)**: OpenSpec CLI 不可環境向け縮退モードの追加（claude-harness / longrun）
- **change-2 (A)**: `/longrun:exec` の Workflow ツール載せ替え（claude-harness / longrun v6.0.0 BREAKING）。`/lr:s` `/lr:d` および `/longrun:status` `/longrun:decisions` の廃止、`longrun-orchestrator` スキルの解体・再編（backlog の命名規則リファクタリングを吸収）を含む
- **change-3 (M)**: MVP モードの独立スキル分離（`--mode=mvp` 廃止 → `/longrun:mvp` + `/lr:m` 新設）
- **change-4 (D)**: plan 段階のモデル割り当てリコメンド機構（plan テンプレート拡張 + exec 側の `opts.model` 消費）
- **change-5 (B)**: harvest サブエージェント契約の StructuredOutput 化（marketing-harness / harvest v0.14.0）
- backlog「Skill 命名規則リファクタリング」のうち `longrun-orchestrator` 分のみ（change-2 に吸収）

### 含まないもの
- MVP モード（分離後の `/longrun:mvp`）自体の Workflow 化（理由: exec の Workflow 化パターンが安定してから次 run で判断。分離により独立最適化が可能になったため強制不要）
- Phase 2: Codex Builder Integration（理由: 5 change 規模の大型タスク。ただし change-2 で builder の agentType をパラメータ化し受け皿のみ用意する）
- `longrun-orchestrator` 以外の Skill 命名規則リファクタリング 7 件（理由: プラグイン単位で別 PR の原則。backlog に残置）
- sns-strategy phase agent 群への StructuredOutput 横展開（理由: 素材の推奨どおりスコープ外。`docs/PLUGIN-CONVENTIONS.md` への規約追記のみ change-5 に含める）
- 縮退モード run の OpenSpec ありへの「昇格」変換（理由: 利用実績を見てから。backlog に追記）
- 旧 checkpoint.md 形式の互換読み取り（理由: `/lr:s` `/lr:d` 自体を廃止するため不要）

## Changes分解

実行構造: **change-1 → change-2 → change-3 → change-4 を直列**（同一リポジトリ・同一プラグインのファイル群を触るためコンフリクト回避）、**change-5 は別リポジトリのため最初から並行**。PR は change ごとに分け、各 PR マージ後に次の change の worktree を切る。

### change-1: openspec-degradation（Change C）
- **対象リポジトリ**: claude-harness（このリポジトリ）
- **スコープ**: OpenSpec CLI（`npx openspec`）が解決できない環境、またはユーザーが OpenSpec 不要と明示した場合の縮退モードを一級の動作モードとして定義する
  - exec の Step 0 検証に「`npx openspec` 解決可能 + init 済み」の前提条件チェックを昇格。失敗時は AskUserQuestion で縮退モードを提案
  - 縮退モードでは spec 類（proposal / tasks / verification-guide 相当）を `_longruns/<run>/` 内に自己完結生成
  - feedback の Tier 3 記録先を縮退時は `_longruns/<run>/backlog.md` にフォールバック
  - **最初のタスク**: 素の repo（openspec 未 init）での `openspec init --tools claude` → `openspec apply` の実機検証。カスタムスキーマの出所（init で入るのか claude-harness 固有か）を確定し、結果を docs に記録（ギャップ 2 の解消）
  - status コマンドへの縮退分岐は実装しない（change-2 で廃止されるため）
- **使用スキル**: なし（プラグイン本体の改修）
- **依存関係**: 独立（直列チェーンの先頭）
- **バージョン**: longrun 5.2.0 → 5.3.0（追加的変更）
- **config.yaml rules**:
  - "既存の openspec/ あり repo の従来挙動を一切変えない（回帰なし）"
  - "実機検証はコマンド出力のエビデンス付きで docs に記録する"

### change-2: workflow-exec（Change A 本体）
- **対象リポジトリ**: claude-harness
- **スコープ**: `/longrun:exec` を「plan.md を読んだ後、Workflow スクリプトを生成・起動する」形に全面書き換え（v6.0.0 BREAKING）
  - **最初のタスク**: Workflow ツールの作法を実環境で確認し（最小の hello-world workflow を 1 本起動して挙動観測）、確定したシグネチャと制約（`agent` / `pipeline` / `parallel` の引数、`opts` で渡せるキー、`resumeFromRunId` の挙動、meta ピュアリテラル / Date.now 不可 / ネスト 1 段制約）をエビデンス付きで `_longruns/<run>/workflow-tool-reference.md` に固定する。以降の実装はこのファイルを一次ソースとし、記憶・推測でシグネチャを書かない（change-1 の openspec 実機検証と同じパターン）
  - `meta.phases` で Review → Build → Verify を表現。既存 agent 定義は `agentType: 'longrun:longrun-builder'` 等で再利用
  - **成果物の構造化**: `agent(prompt, {schema})` で builder 完了レポート・verifier 4 軸スコア（functionality / quality / completeness / UX）・reviewer 判定（APPROVE / REQUEST_CHANGES）を JSON Schema 強制。schema は `plugins/longrun/schemas/*.schema.json` に外部化
  - **Verify ループ**: `while` + 明示上限（3 周）+ `budget.remaining()` ガードで暴走を構造的に防止。上限到達時は状態をユーザーに報告して停止
  - **ユーザー対話の境界**: Build Contract 承認ゲートと Feedback Tier 確認で workflow を分割し、メインループに戻して AskUserQuestion → 次の workflow を起動（workflow 内 agent からは AskUserQuestion 不可のため）
  - **再開**: `resumeFromRunId` を一次手段に。checkpoint.md は人間向け監査ログとして書き続ける（機械可読パースは廃止）
  - **権限**: exec Step 0 で現在の権限モードを検査し、`acceptEdits` 未満ならユーザーに切り替え案内してから起動
  - **builder の agentType をパラメータ化**（Codex Builder Phase 2 の受け皿。今回はデフォルト `longrun:longrun-builder` 固定）
  - `/lr:e` は orchestrator インライン展開ハックを廃止し `/longrun:exec` への単純委譲に戻す（`plugins/lr/commands/e.md` の書き換え）
  - `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` を削除。削除対象を明示: `plugins/longrun/commands/{status,decisions}.md`、`plugins/lr/commands/{s,d}.md`、**`plugins/lr/.claude-plugin/plugin.json` の commands[] と description**、longrun 側 plugin.json / README、および `exec.md` 末尾の「実行中の進捗確認」セクション（`/longrun:status` / `openspec list` への案内が現存）
  - `longrun-orchestrator` スキルを解体（Workflow スクリプト生成ロジックは exec コマンド + 同梱スクリプトテンプレートへ移管）。backlog の命名規則リファクタリング（orchestrator 分）をこれで消化
  - Workflow 起動の opt-in 整理: `/lr:e`（slash command 起動）は Workflow ツールの「ユーザーが起動した slash command の指示で呼ぶ」要件に該当するため追加確認は不要、と exec 内に明記
- **使用スキル**: なし
- **依存関係**: change-1 完了後（縮退モードの Step 0 分岐を前提に exec を設計するため）
- **バージョン**: longrun 5.3.0 → 6.0.0、lr 5.1.1 → 6.0.0（s/d 削除を含む BREAKING）
- **config.yaml rules**:
  - "Workflow スクリプト内で Date.now() / Math.random() / argless new Date() を使わない"
  - "workflow のネストは 1 段まで。分割境界（承認ゲート）はメインループに戻す"
  - "既存 agent 定義 7 種の .md は書き直さない（agentType 参照で再利用）"

### change-3: mvp-plan-split（MVP 分離）
- **対象リポジトリ**: claude-harness
- **スコープ**: `longrun-plan` スキルから MVP モードを独立スキルに分離し、それぞれを別々に最適化可能にする
  - 新スキル `longrun-mvp-plan`（名詞形命名）+ 新コマンド `/longrun:mvp` + 短縮 `/lr:m` を新設
  - `--mode=mvp` フラグは廃止。旧フラグ指定時は「`/longrun:mvp` に移動した」案内を出して終了（サイレント無視しない）
  - MVP 用 agent 3 種（research / plan-reviewer / bestpractice-reviewer）と `plan-template-mvp.md` は新スキル帰属に整理
  - `<!-- mvp-mode -->` マーカーと archive 側の分岐は現状維持（成果物形式は不変）
  - Gap Analysis / Interview の方法論は共通参照ドキュメントに切り出して両スキルが Read する（量が少なければ複製許容、実装時判断）
  - MVP フロー自体のロジックは変更しない（オーケストレーションは現状の Agent 並列のまま。Workflow 化は次 run で判断）
- **使用スキル**: なし
- **依存関係**: change-2 完了後（plugin.json / README の同時編集によるコンフリクト回避のための直列化。論理的依存はない）
- **バージョン**: longrun 6.0.0 → 6.1.0、lr 6.0.0 → 6.1.0（/lr:m 追加）
- **config.yaml rules**:
  - "MVP フローの中身（ステップ構成・agent 契約）を変えない。移動と分離のみ"
  - "Skill 名は名詞形（-er / -or 終わり禁止）"

### change-4: model-allocation（Change D）
- **対象リポジトリ**: claude-harness
- **スコープ**: plan 段階で change × agent ロールごとの推奨モデルを生成し、exec がそれを消費する機構
  - `plugins/longrun/templates/plan-template.md` に「モデル割り当て」セクションを追加（ロール / 推奨ティア / 理由 / 上書き欄の表）。ティア → モデル ID 対応表も `plugins/longrun/` 配下のリファレンスドキュメントに置く
  - `longrun-plan` スキルに推奨生成ステップを追加。ヒューリスティクス: アーキテクチャレビュー・複雑な TDD 実装 → 指定なし（inherit）/ 定型的検証・要約 → `haiku` / リサーチ・ブラウザ操作・中規模実装 → `sonnet`
  - **保守的デフォルト**: 確信度の低いタスクは「指定なし（inherit）」。Workflow ツール自体の設計指針に整合
  - ティア → モデル ID の対応はリファレンスドキュメント 1 箇所に集約（ハードコード散在禁止）
  - exec の workflow スクリプト生成時に plan.md のモデル割り当て表を読み `opts.model` に渡す
  - モデル割り当てセクションが無い旧 plan.md でも exec が動く（全 inherit にフォールバック）
- **使用スキル**: なし
- **依存関係**: change-2 完了後（新 exec の workflow 生成ロジックに乗るため）。change-3 とはファイル重複（plan スキル）があるため change-3 の後
- **バージョン**: longrun 6.1.0 → 6.2.0
- **config.yaml rules**:
  - "モデル ID のハードコードを plan.md・workflow スクリプトに散在させない（ティア対応表 1 箇所参照）"
  - "迷ったら inherit（モデル未指定）に倒す"

### change-5: harvest-structured-output（Change B）
- **対象リポジトリ**: **marketing-harness**（`~/.claude/plugins/marketplaces/marketing-harness`。worktree を同リポジトリから切る）
- **スコープ**: harvest プラグインのサブエージェント契約を StructuredOutput 化（v0.13.1 → v0.14.0）
  - **最初のタスク**: 散文契約（STATUS line / BEGIN_RAW_JSON / `Status:` 文字列マッチ / 5 セクション位置パース）に依存する既存 bats を grep で洗い出し、書き換え対象本数を design.md に列挙する（既存スイートは実測で `@test` **313 本**（ファイル数は約 230）。母数は `@test` 数で固定すること）
  - **契約の外部化**: `plugins/harvest/schemas/{property,plan,researcher,evaluator}.schema.json` を新設。SKILL.md は schema を参照する形に（STATUS line + BEGIN_RAW_JSON/END_RAW_JSON フェンスの散文契約と、bestprac-refresh の「5 セクション固定順序」位置パース・`Status:` 文字列マッチを廃止）
  - **検証層**: sub agent の戻りを `scripts/validate-contract.sh`（jq ベース）で検証してから後続処理へ。失敗時は 1 回リトライ → フォールバック（メイン逐次実行、既存設計踏襲）
  - **マスキングの原子性**: redact 完了まで property.md を書かない（tmp に書いて mv）+ クラッシュ残骸 `.property.raw.json` の起動時クリーンアップ
  - schema（形式）と SKILL.md（手続き。Search Audit 必須・WebSearch 回数等）の責務分担を design.md で文書化
  - `docs/PLUGIN-CONVENTIONS.md` に StructuredOutput 契約の規約を追記（sns-strategy 等への横展開はしない）
  - knowledge skill の Workflow 化は見送り（claude-harness への依存を作らず B 単体で完結させる）
- **使用スキル**: なし
- **依存関係**: 独立（別リポジトリ。change-1〜4 と完全並行可）
- **バージョン**: harvest 0.13.1 → 0.14.0（marketing-harness 側も version 3 箇所同期）
- **config.yaml rules**:
  - "既存 bats スイート（実 `@test` 313 本）を壊さない（契約関連テストの書き換えは最初のタスクで洗い出した一覧との差分で明示。全 PASS 判定の母数は `@test` 数 313 を基準とする）"
  - "フォールバック発動時も成果物（knowledge/*.md）の形式は現行と同一"

## 画面・UI設計

CLI（Claude Code セッション内）のみ。Web UI なし。

- `/lr:e` 起動時: 権限モード検査 → 縮退モード提案（必要時）→ Workflow 起動。進捗はネイティブの `/workflows` ライブビューで参照（status コマンドの代替）
- 承認ゲート: workflow 分割境界でメインループに戻り AskUserQuestion（Build Contract 承認 / Feedback Tier 確認）
- `/longrun:mvp`: 既存 MVP モードと同一の対話 UX（Gap Analysis → Interview → リサーチ → 並列レビュー → ハンドオフ）
- plan.md のモデル割り当て表: ユーザーが plan 確認時に直接編集して上書きできる markdown 表

## データモデル

主要な構造化データ（DB なし、すべてファイル）:

- **JSON Schema 群**:
  - claude-harness: `plugins/longrun/schemas/` — builder 完了レポート（コミットハッシュ / テスト結果 / 完了タスク）、verifier 4 軸スコア（functionality / quality / completeness / UX、各 0-100）、reviewer 判定（status: APPROVE|REQUEST_CHANGES + findings[]）
  - marketing-harness: `plugins/harvest/schemas/` — property / plan / researcher / evaluator の 4 本
- **plan.md モデル割り当て表**: `| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |`
- **checkpoint.md**: 人間向け監査ログに格下げ（機械可読契約から除外）。decisions.md は現行どおり
- **run の再開情報**: Workflow の `runId`（`_longruns/<run>/` 内に記録し `resumeFromRunId` で使用）

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている
3. [ ] ビルドエラーなし（plugin.json / marketplace.json / schema JSON の jq 構文検証 + bats 全 PASS をビルド相当とする）
4. [ ] 統合テストがPASS（worktreeマージ後、両リポジトリの bats フルスイート）

**機能固有の条件:**
5. [ ] (change-1) `npx openspec` が解決できない環境で `/lr:e` が縮退モードを提案し、縮退 run が完走する（bats でコマンド不在をシミュレート）
6. [ ] (change-1) 素の repo での `openspec init --tools claude` → `apply` の挙動が実機検証され、結果が docs に記録されている
7. [ ] (change-1) 既存の openspec/ あり repo では従来挙動が変わらない（回帰なし）
8. [ ] (change-2) (a) 生成される workflow スクリプトが構文検証と schema 検証を通り、(b) 最小 fixture plan（1 change / 1 タスク）で Review → Build → Verify が 1 周完走して runId が記録される — を builder が確認しログに残す（フル代表 plan の完走確認は「動作確認方法」のユーザー手動確認に委ねる）
9. [ ] (change-2) Verify ループが上限 3 周到達で必ず停止し、状態がユーザーに報告される（workflow スクリプトの単体検証）
10. [ ] (change-2) 中断 → `resumeFromRunId` 再開で、完了済み change の builder agent が再実行されない
11. [ ] (change-2) `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` が削除され、`plugins/longrun/` と `plugins/lr/` 配下の全 plugin.json / README / commands/*.md（exec.md 含む）、**およびリポジトリ直下 `.claude-plugin/marketplace.json`（lr / longrun の description 文字列・plugins[] エントリ）** に残存参照がない（grep で 0 件）
11b. [ ] (change-2) Workflow ツールの実機検証結果が `_longruns/<run>/workflow-tool-reference.md` にエビデンス（実行した workflow とその出力）付きで固定されている
12. [ ] (change-3) `/longrun:mvp`（`/lr:m`）で従来の MVP フローが完走し、`<!-- mvp-mode -->` マーカー付き plan.md が生成される
13. [ ] (change-3) `/longrun:plan --mode=mvp` 指定時に移行案内が表示される（サイレント無視しない）
14. [ ] (change-4) `/longrun:plan` の生成する plan.md にモデル割り当て表が含まれ、exec が表の値を workflow スクリプトの `opts.model` に反映する。表が無い旧 plan.md では全 inherit で動く
15. [ ] (change-5) schema 4 本が存在し、validate-contract.sh の単体 bats が通る
16. [ ] (change-5) sub agent が不正形式を返す fixture でリトライ → フォールバックが発動する
17. [ ] (change-5) `/harvest:knowledge` と `/harvest:bestprac-refresh` の E2E が現行と同等の成果物を生む
18. [ ] (change-5) `.property.raw.json` がいかなる失敗パスでも翌回起動時に残らない
19. [ ] (全change) version 3 箇所同期（plugin.json / marketplace.json top-level / marketplace.json plugins[]）が両リポジトリで取れている。claude-harness 側は **longrun・lr の両プラグインそれぞれ**について 3 箇所同期を確認する（lr 5.1.1 → 6.x の bump 漏れに注意）

## 意思決定ガイドライン
- 優先順位: 構造的な堅牢性（schema・上限・resume）> 後方互換 > 実装の簡潔さ。BREAKING を許容した run なので互換シムは最小限（`--mode=mvp` の案内のみ）
- リスク許容度: claude-harness 側は積極的（v6.0.0 BREAKING を明示済み）、marketing-harness 側は保守的（成果物形式・フォールバック動作は現行同等を厳守）
- 不明点の扱い: Workflow ツールの仕様が不明な点は組み込みドキュメントを一次ソースとし、推測で実装しない。モデル割り当てで迷ったら inherit に倒す。ユーザー対話が必要な設計分岐は workflow を分割してメインループに戻す方を選ぶ
- 巻き込み事項: backlog「Skill 命名規則リファクタリング」の orchestrator 分は change-2 で消化（確定時に backlog 消込み）。Codex Phase 2 は agentType パラメータ化の受け皿のみ

## 動作確認方法
- 開発サーバー: なし（CLI プラグイン）。動作確認は Claude Code セッションで slash command を実行する
- テスト:
  - claude-harness: `bats plugins/longrun/tests/`
  - marketing-harness: `bats plugins/harvest/tests/`
  - 構文検証: `jq . plugins/longrun/schemas/*.schema.json` / `jq . .claude-plugin/marketplace.json` 等
- 確認手順:
  1. claude-harness worktree で `/lr:e _longruns/<代表plan>/` を実行し、Workflow 起動 → `/workflows` で進捗表示 → 承認ゲートで AskUserQuestion が来ることを確認（フル代表 plan の完走 E2E はこのユーザー手動確認が最終判定。受け入れ条件 8 の自動検証は最小 fixture plan まで）
  2. Verify ループを意図的に FAIL させ（fixture）、3 周で停止して報告が出ることを確認
  3. 実行中に中断 → `resumeFromRunId` で再開し、完了済みフェーズがスキップされることを確認
  4. `npx openspec` を PATH から外した環境で `/lr:e` を実行し、縮退モード提案 → 完走を確認
  5. `/longrun:mvp` で MVP プラン作成が従来どおり完走することを確認
  6. marketing-harness で `/harvest:knowledge` を実行し、成果物が現行と同等であること、不正 fixture でフォールバックが出ることを確認

## Brain Dumpからの原文メモ
> 各 change は独立した longrun として実行する。**1 run = 1 change** を厳守（Change A は特に大きいので、plan 段階でさらに分割される想定）
> → Interview で変更: 「全部まとめて並行でやる。プルリクは別」（A・B・C を 1 run に統合、PR は change ごと。A/C のファイル重複により C→A 直列 + B 並行に調整）

> なんか似たような、同じものをオプションで呼ぶのに共通のロジックを通ってないっていうのが、とても気持ち悪く感じる
> → MVP モードの議論から、共通点が少ないなら「別のスキルとして実装しちゃった方が、それぞれ別々に最適化ができていい」（change-3 の起点）

> s, d全く使ってないからいらん気がしている
> → status / decisions コマンド廃止の決定

> プランの段階でどのタスク、またはどのエージェントに対してどのモデルを使うべきかというリコメンドを作ることはできるでしょうか。可能であれば、それも今回のスコープに入れたいです。Change Dでも構いません
> → change-4 の起点

> Verify → Feedback ループに上限・暴走対策がない（LLM の自制とユーザーの手動停止頼み）／checkpoint.md を grep/sed で読む脆いパース。スキーマ検証なし／ドリフトすると無言で壊れる
