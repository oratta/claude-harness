---
catalog_version: 1
---

# 観点の注入設計 — 注入マップ正本（injection map）

14観点それぞれの「コンテキスト＋判断基準を、いつ・どの機構でセッションに注入して論点潰しをするか」の唯一の正本（oratta/claude-harness#122 で確定）。観点の語彙・判定条件・担い手は `catalog.md` が正本で、ここには複製しない。このファイルが持つのは注入の**タイミングと配線**だけ。

カタログとの整合（`catalog_version` 一致・14観点の全掲載・タイミング語彙）は `tests/casting-injection.bats` が機械検査する。カタログの重量ルート（観点の追加・削除・統合・分割）を通したら、このファイルの該当行と `catalog_version` も同じ変更で更新する。

## 注入タイミングの語彙（8分類）

各タイミングは実装機構と1:1に対応する。ここに無いタイミング名を注入マップで使ってはならない（使いたくなったら先にこの表へ追加する）。

| タイミング | 意味 | 実装機構 |
|---|---|---|
| 常時 | rules / CLAUDE.md / hook で毎ターン（毎ツール呼び出し）効く | `rules/`・hooks |
| 毎ターンの配役判定 | 注入ではなく担い手の振り分け（casting 5手順）。未移譲観点をここで主に上げる | `rules/perspective-casting.md` |
| PR 時レンズ | pr-review-gate のレビューに観点付きレンズを追加する | pr-review-gate（汎用化は #125） |
| アクション直前ゲート | 外に出る・不可逆・課金になる直前に専任サブエージェントを必ず挟む | sns-safety-reviewer 型（汎用化は #126） |
| 定期監査 | cron で状態を観点付きで見回る | （予約。現時点で割当なし） |
| 注入しない | 移譲不能。主に上げるのが正しい | — |
| 起票・選定時 | issue の起票・着手選定の時点で観点を効かせる | burn-select 論点ゲート・issueify |
| 設計時 | plan・企画・仕様化の時点で観点を効かせる | longrun plan の research・opsx proposal |

## 14観点の注入マップ

| 観点 | 注入タイミング | 配線先機構 | 注入文書と置き場所 |
|---|---|---|---|
| 法的・規制 | PR 時レンズ＋アクション直前ゲート | コードに現れる規約違反（API 使用法・レート・データ保持）はレビューレンズ、成果物にしか現れない違反は直前ゲート | `policies/regulation.md`（必要な業種のみ） |
| 財務・コスト | 毎ターンの配役判定＋アクション直前ゲート | 方針文なしの支出判断は主へ。課金を伴う操作の直前はゲート（rate-guard は使用量側の部分実装） | `policies/budget.md` |
| 信用・レピュテーション | アクション直前ゲート | 外に出るもの全て（投稿・公開ページ・対外連絡）。現状は SNS 投稿のみ実装 | `policies/brand.md` |
| 情報セキュリティ・プライバシー | 常時 | secret-guard hook（user レベル PreToolUse）で移譲成立済み。現状維持 | — |
| 資産・回復可能性 | 常時＋PR 時レンズ | destructive-git-guard rule＋auto-merge の SACRED 判定。レビューでも聖域接触の自覚を確認（脅威モデルの明文化は #119） | 聖域リスト（正本は auto-merge workflow の SACRED 定義） |
| 報告の正確性 | 常時 | 報告系 rules＋pr-review-gate の証拠必須（exit code・実測）。現状維持 | — |
| 事業方向性・戦略整合 | 毎ターンの配役判定 | 未移譲＝主に上げる。フェーズ宣言文の整備が移譲の条件で、整備後の注入先は設計時 | `policies/phase.md`（既存 PHASE.md がある repo は stub 参照） |
| 優先順位・資源配分 | 起票・選定時 | burn-select の論点ゲート（flatmate#368）・issueify の受け入れ条件強制 | `policies/priority.md` |
| 開発スピード・機会損失 | 注入しない | 主（方向性と一体で移譲する） | — |
| 運用工数・維持 | PR 時レンズ | 維持コスト観点のレビューレンズ（#125 の対象） | `policies/maintenance.md` |
| 技術設計・品質 | PR 時レンズ | pr-review-gate 本体で移譲成立済み。現状維持 | テックスタック方針（repo の CLAUDE.md / docs） |
| ユーザー価値・市場 | 設計時 | longrun plan の research agent（longrun-mvp-research 等）。主にも分からないものは調べて決める | — |
| 美意識・ブランド感覚 | 注入しない | 主（判例の蓄積で徐々に移譲） | — |
| 感情的受容度 | 注入しない | 主（移譲不能） | — |

定期監査はどの観点にも割り当てていない（候補: 財務・コストの使用量見回り、運用工数・維持の棚卸し。実運用の必要が出た時点で割当と実装 issue を起こす）。

## 注入文書の置き場所規約

観点の移譲に必要な注入文書は `<repo>/.claude/casting/policies/<slug>.md` に置く。配役表（`project.md`）の「移譲に必要な文書」列からはこのファイル名で参照する。既存の別置き文書（repo ルートの PHASE.md 等）がある repo は、実体の移動を強制せず policies/ からの参照 stub でよい。

| 観点 | slug |
|---|---|
| 法的・規制 | regulation |
| 財務・コスト | budget |
| 信用・レピュテーション | brand |
| 事業方向性・戦略整合 | phase |
| 優先順位・資源配分 | priority |
| 運用工数・維持 | maintenance |

## 実装済み配線の一覧（実在パス）

| 配線 | タイミング | 実在場所 |
|---|---|---|
| 返信前チェック5手順 | 毎ターンの配役判定 | `rules/perspective-casting.md` |
| secret-guard hook | 常時 | user レベル hooks（`~/.claude/settings.json` の PreToolUse → `~/.claude/hooks/secret-guard.py`） |
| destructive-git-guard | 常時 | `rules/destructive-git-guard.md` |
| 聖域（SACRED）判定 | 常時（マージ時に機械判定） | `.github/workflows/auto-merge.yml` の SACRED 定義（テンプレ正本: `plugins/dev-workflow/templates/auto-merge/`） |
| 報告系規約 | 常時 | `rules/`＋pr-review-gate の証拠必須手順 |
| レビューゲート | PR 時レンズ | `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` |
| SNS 投稿前ゲート | アクション直前ゲート | sns-autopilot プラグインの sns-safety-reviewer agent |
| burn-select 論点ゲート | 起票・選定時 | genetta-inc/flatmate の `scripts/burn-select.sh`（flatmate#368） |
| plan 時リサーチ | 設計時 | `plugins/longrun` の research agent（longrun-mvp-research 等） |

## 未実装の配線（実装 issue）

- PR 時レンズの汎用化（repo 固有の方針文書をレビューレンズとして自動注入）: oratta/claude-harness#125
- アクション直前ゲートの汎用化（外に出る・不可逆・課金の直前に観点付きサブエージェント確認）: oratta/claude-harness#126
