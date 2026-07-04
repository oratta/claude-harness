# Loop Engineering 調査資料

調査日: 2026-07-04（WebSearch / WebFetch による直接確認）

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
