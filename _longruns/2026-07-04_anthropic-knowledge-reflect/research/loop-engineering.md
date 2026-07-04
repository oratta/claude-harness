# Loop Engineering 調査資料

調査日: 2026-07-04（WebSearch / WebFetch による直接確認）

## ⭐ 公式一次ソース: "Getting started with loops"（claude.com 公式ブログ）

- URL: https://claude.com/blog/getting-started-with-loops
- 著者: Delba de Oliveira, Michael Segner（Claude Code チーム）/ 公開: 2026-06-30 / 本文直接確認済み
- **本資料の最上位ソース**。以下のコミュニティ essay 群（Osmani 等）より優先する

**定義**: ループ = 「停止条件に達するまでエージェントが仕事を繰り返すサイクル」。トリガー方法・停止基準・使用プリミティブ・適するタスク類型で分類される。

**公式の4ループタイプと選択フレームワーク**:

| ループ型 | トリガー | 停止 | 手放す対象 | 使用場面 | 推奨プリミティブ |
|---|---|---|---|---|---|
| **ターンベース** | ユーザープロンプト | タスク完了 | 検証ステップ | 探索・判断が要る単発タスク | **skill に検証ステップを組み込む** |
| **ゴールベース** | 手動プロンプト | ゴール達成 or 最大試行数 | 停止条件 | 検証可能な終了基準があるタスク | **/goal**（別のエバリュエータモデルが成功基準を判定） |
| **タイムベース** | 時間間隔 | キャンセル or 完了 | トリガー | 定期的・外部システム連携 | **/loop**（ローカル）・**/schedule**（クラウド） |
| **プロアクティブ** | イベント/スケジュール（人間不在） | タスク毎はゴール達成、ルーチンは手動キャンセルまで | プロンプト自体 | バグ分類・マイグレーション・依存更新などの定常業務 | **/schedule + /goal + 動的ワークフロー + オートモード の合成** |

**具体例（公式記載）**:
- ゴールベース: `/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries`（定量基準が最も効果的: テスト合格数・スコア閾値）
- タイムベース: `/loop 5m check my PR, address review comments, and fix failing CI`
- プロアクティブ（合成）: `/schedule every hour: check #project-feedback for bug reports. /goal: don't stop until every report found this run is triaged, actioned, and responded to.`
- ターンベースの検証 skill: 「フロントエンド変更を確認する前に dev サーバーを起動し、ブラウザで操作確認、コンソールエラーなしを確認」と具体的に記述

**コード品質維持（公式ベストプラクティス）**:
1. コードベース自体をクリーンに保つ（Claude は既存パターンに従う）
2. **skill に自己検証メカニズムを明示**
3. フレームワークの最新ベストプラクティスへのアクセスを確保
4. **第二エージェントによるレビュー**（/code-review skill または GitHub Code Review 統合）
5. 個別修正をシステム全体の改善にフィードバックする

**トークン使用量管理（公式）**:
- 正しいプリミティブ・モデルを選ぶ（小規模タスクに複数エージェント不要）
- 明確な成功・停止基準を定義する（曖昧さを減らす）
- 大規模実行前にパイロットを実施する
- **決定論的作業はスクリプト化**（推論より低コスト）
- ルーチン実行頻度を必要最小限に
- `/usage`・`/goal`・`/workflows` で使用量をレビュー

**このリポジトリへの含意（最重要）**: 公式の立場は「**ループのランタイムは Claude Code のネイティブプリミティブ（skill / /goal / /loop / /schedule / workflows / auto mode）であり、ループはその合成で作る**」。したがってハーネスが独自のループ実行系（カスタム schema + driver スクリプト）を再発明するのは公式路線とズレる。ハーネスが埋めるべきギャップは **(a) skill への自己検証ステップの組み込み（ターンベースの最適化）、(b) 定量的成功基準を持つ /goal レシピ、(c) 定常業務の /loop・/schedule レシピ、(d) プロアクティブ合成ルーチンの設計と State 規約** という「**設計されたループのレシピ集**」の提供。

---

## コミュニティ側の背景（Osmani / Steinberger / Cherny）

## 概要と成立経緯

**Loop Engineering = 「エージェントに自分でプロンプトするのをやめ、エージェントをプロンプトするシステム（ループ）自体を設計する」実践**。2026年6月に成立した、prompt engineering の後継概念。

- **2026-06-07**: Peter Steinberger（OpenClaw 開発者）が「コーディングエージェントにプロンプトすべきではない。エージェントにプロンプトを与えるループを設計すべき」と投稿（約650万ビュー）
- **2026-06-08**: Addy Osmani（Google）が canonical essay「Loop Engineering」を発表し用語と解剖学を確立 — https://addyosmani.com/blog/loop-engineering/
- **同時期**: **Boris Cherny（Anthropic・Claude Code 責任者）**: 「**I don't prompt Claude anymore. I have loops running that prompt Claude and figure out what to do. My job is to write loops.**」— Anthropic 側からの実践の主流化宣言

> 位置づけの入れ子: **prompt ⊂ context ⊂ harness ⊂ loop**。
> Prompt Engineering（2022–24: 表現の最適化）→ Context Engineering（2025: 推論時に見える情報の管理）→ Harness Engineering（2026: エージェント周辺環境の設計）→ **Loop Engineering（2026: それら全体を回す制御ループ自体の設計）**

## ループの解剖学（Osmani の canonical anatomy）

1ターンのループは **5つのムーブ**に分解される: **discovery（仕事を見つける）→ handoff（割り当てる）→ verification（検証する）→ persistence（状態を残す）→ scheduling（次の実行を予約する）**。

構成要素は **5+1**:

| # | 構成要素 | 役割 | Claude Code での対応物 |
|---|---|---|---|
| 1 | **Automations / Scheduling** | 心拍。定期実行で発見とトリアージを自動化 | `/loop`・`/goal`・cron ルーチン（/schedule）・GitHub Actions |
| 2 | **Worktrees** | 並列エージェントのファイル競合防止 | `--worktree`・subagent の `isolation: worktree` |
| 3 | **Skills** | 永続的プロジェクト知識（毎回ゼロから推測させない） | SKILL.md / CLAUDE.md |
| 4 | **Plugins / Connectors** | 外部ツール連携（PR作成・issue更新・Slack） | MCP・gh CLI・plugins |
| 5 | **Sub-agents** | **実装者と検証者の分離**（自分の成果物を自分で採点させない） | `.claude/agents/`・agent teams |
| +1 | **State** | 「エージェントは忘れるが、リポジトリは記憶する」。STATE.md / Linear 等に進捗・前回の試行・人間への引き継ぎを記録 | ファイル規約（native 機構なし） |

**3部構成の最小形**: **generator**（作業するエージェント）+ **evaluator**（ルーブリックで採点する別エージェント or プログラム）+ **loop**（evaluator のレポートを generator に戻し、ルーブリック通過か予算切れまで回す）。

## 代表的なループ例（Osmani essay の実装パターン）

> 朝の automation 実行 → 昨日の CI 失敗と open issues をトリアージスキルで読み込み → 各タスク用に隔離 worktree を開く → 第一サブエージェント（generator）が修正案を作成 → 第二サブエージェント（evaluator）が検証 → コネクタで PR 作成・チケット更新 → 結果を state（markdown/Linear）へ保存 → 翌日の実行時、state から前日の途中地点を再開。

## 設計原則

- **明確でテスト可能な終了条件を持つ目標**（例:「テストをパスさせる」）。停止条件の欠如が最も一般的な失敗
- **複数の独立した出口**: ルーブリック通過 / 予算切れ / 反復上限 / 無進捗検出（同じ行動の反復を検知）
- **決定論的検証を報酬信号に**: テスト・型チェッカーを信頼し、LLM 判定は検証不可能な場面に限定
- **コンテキスト腐食対策**: 要約・枝刈り・外部状態への退避
- **エスカレーション**: 回復可能エラーと致命的エラーを区別し、致命的なら人間へ

## 典型的な失敗パターン（6つ）

1. コンテキストオーバーフロー
2. 同じ行動の反復（無進捗ループ）
3. 目標の不適切な仕様化（報酬ハッキング）
4. 検証なしでの成功宣告（「完了」は主張であり証明ではない）
5. エラーの複合化
6. トークン消費の爆発（ループはチャットの約4倍、マルチエージェント構成は約15倍）

## Good Loop vs Bad Loop（Osmani）

- **良いループ**: 設計時に意図を明確化 → 実行中の検証はエンジニアが責任を持つ → 結果のコードを理解した上で出荷
- **悪いループ**: 設計を「考えることの回避」に使う → 実装内容の把握を放棄 →「comprehension debt（理解の負債）」「cognitive surrender（認識的降伏）」→ 品質低下スパイラル
- 最終メッセージ: 「ループを設計せよ。エンジニアであり続けよ」

## 素の Claude Code とのギャップ（このリポジトリへの含意）

構成要素 1〜5 は Claude Code 本体が**部品として**提供済み（/loop・/goal・cron・worktree・skills・MCP・subagents）。**提供されていないのは「設計されたループそのもの」**:

- **ループ定義の規約が無い**: goal / trigger / discovery / generator / evaluator / 停止条件 / persistence を1枚で宣言する形式が無く、毎回アドホックにプロンプトで組む
- **State レイヤーの規約が無い**: STATE.md 相当（現在の作業・前回の試行と結果・人間への引き継ぎ待ち）は自前で設計する必要がある
- **discovery（仕事を自分で見つける）ループが無い**: 既存ハーネス（longrun）は「人間が plan を書いて渡す」起点。CI 失敗・issue・backlog を自動でトリアージして仕事を拾うループは存在しない
- **evaluator の汎用部品が無い**: longrun の verifier は build 専用。任意のループに差し込める generator/evaluator ペアの規約が無い
- **loop-audit / loop-cost が無い**: 停止条件の有無・無進捗検出・トークン予算をループ定義に対して機械チェックする道具が無い（コミュニティには loop-audit / loop-init / loop-cost の先行例あり: https://github.com/cobusgreyling/loop-engineering）

## ソース（実在確認済み）

- Addy Osmani, "Loop Engineering"（canonical essay, 2026-06-08）: https://addyosmani.com/blog/loop-engineering/ （本文直接確認済み）
- The New Stack（Boris Cherny の発言）: https://thenewstack.io/loop-engineering/
- Cobus Greyling, "Loop Engineering": https://cobusgreyling.substack.com/p/loop-engineering （本文直接確認済み）
- Tosea.ai, "Loop Engineering: Complete Guide 2026": https://tosea.ai/blog/loop-engineering-ai-agents-complete-guide-2026 （本文直接確認済み。進化系統・パターン比較・失敗類型）
- O'Reilly Radar, "Loop Engineering": https://www.oreilly.com/radar/loop-engineering/
- 先行実装例: https://github.com/cobusgreyling/loop-engineering （loop-audit / loop-init / loop-cost CLI）
