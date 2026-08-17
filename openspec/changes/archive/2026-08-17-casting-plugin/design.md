## Context

「観点の配役」フレームワークの設計は claude.ai artifact（正本）と oratta/claude-harness#112（実装用データ）で確定済み。この change は設計の再検討をせず、確定した語彙・形式を harness の資産として実体化する。設計判断のうち実装に効くものだけをここに記録する。

## Decisions

### 宣言形式は YAML ではなく Markdown 表

先行事例調査では microsoft/agent-governance-toolkit の宣言的 YAML を部品候補としたが、採らない。読者が人間と LLM の両方であること、harness の既存資産（rules・skills・specs）がすべて md 正本方式であること、配役表は「読んで従う」ものであって機械が実行するポリシーではないことが理由。機械検証は casting-check.sh が md 表をパースして行う。

### 常時ロード層と参照時ロード層の2層分割

flatmate の CLAUDE.md 運用と同じ思想。毎ターン効くべき返信前チェック5手順だけを `rules/perspective-casting.md`（30行以内）に置き、カタログ本文・手順詳細は plugin 側（参照時ロード）に置く。rules へのカタログ複製は二重管理になるため spec で MUST NOT とした。

### casting-check.sh の照合は LC_ALL=C の grep -F

観点語彙は日本語。macOS の awk はマルチバイト文字列比較が壊れる実績があるため（`$2=="名前"` が全行 true になる）、語彙照合に awk の文字列比較を使わず、`LC_ALL=C` の `grep -F` / sed で行単位照合する。spec の MUST NOT に含めた。

### local.md は gitignore、precedents.md は git 追跡

第2層（エージェント/マシン別の上書き）は Mearman/agent-permissions の2枚構成を借用し gitignore。判例台帳は「判例が積まれるほど主に来る論点が減る」というフレームワークの蓄積機構そのものなので、プロジェクトの資産として git 追跡する。

### スコープ外（このchangeでやらない）

観点注入方式（レビュアー vs オーケストレーター）の実装、hooks による返信前チェックの強制、flatmate 側の適用（channel-reply-policy・burn-hold の判定差し替え＝genetta-inc/flatmate#361 の別トラック）。
