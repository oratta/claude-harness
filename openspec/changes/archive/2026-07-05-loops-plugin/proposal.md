# Proposal: loops-plugin

## Why

公式記事「Getting started with loops」（claude.com、Claude Code チーム、2026-06-30）は、ループのランタイムをネイティブプリミティブ（skill / /goal / /loop / /schedule / workflows / auto mode）に委ね、ループは**その合成**として設計する方針を示した。現状のハーネスにはループを設計・記述するための共通規約（レシピ形式・State 規約・設計ガイド）が存在せず、ユーザーは毎回ゼロから /goal・/loop・/schedule のプロンプトを手書きしている。また「やりたいことを書き出す → /goal に読ませるファイルを作らせる → 不足情報はヒアリングさせる」という頻出ワークフローも毎回手動指示になっている。change-2〜4（skill 自己検証・レシピ集・プロアクティブルーチン）の土台として、レシピ集の器・規約・設計ガイドを最初に整備する。

## What Changes

- 新プラグイン `plugins/loops/` を追加する（レシピ集の器 + State 規約 + 設計ガイド。**独自のループ実行系＝常駐スクリプト・カスタム driver・宣言的 schema ランタイムは作らない**）
- **レシピ形式の規約**を新設する: `recipes/<name>.md` は「ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション」の固定見出しで書く。起動コマンドはネイティブプリミティブ（/goal・/loop・/schedule・skill 起動）のコピペ可能な文字列を第一級の成果物とする
- **State 規約**を新設する: プロアクティブ/長期ループが使う `loops/state/<name>.state.md` の形式（現在の作業 / 前回の試行と結果 / 人間への引き継ぎ待ち / 繰り越しタスク）とテンプレート
- **`/loops:design`** スキルを新設する: 公式の選択フレームワーク（何を手放すか: 検証ステップ → 停止条件 → トリガー → プロンプト自体）に沿って対話でループ型を選び、レシピ形式の定義を書き出す。停止基準の無いレシピを出力しない。Bad Loop 検査（停止基準の欠如・検証なき成功宣告・報酬ハッキング余地・過剰な実行頻度）を組み込む
- **`/loops:goalify <テキスト|ファイルパス>`** スキルを新設する: brain dump から不足情報のみをヒアリングし、`goals/<name>.goal.md`（成功基準は全てコマンド + 期待値で機械検証可能）と /goal 起動コマンド 1 行を生成する
- **`references/loop-types.md`** を新設する: 公式 4 ループタイプ（ターンベース / ゴールベース / タイムベース / プロアクティブ）の表と使い分け・具体例、および**実行機構との責務分離**（スケジューラ登録・セッション運用・課金選択はスコープ外＝呼び出し側の責務）の節を収録する
- 定期実行の機構・配線（セッション内 cron・SessionStart hook・supervisor・launchd・`claude -p` 配線）は**本 change に含めない**（別セッションの Pikke プロセス整理側が担う）
- marketplace.json への `loops` 登録は change-5（integration）で行う。本 change ではプラグイン本体のみ作成する

## Capabilities

### New Capabilities

- `loops-plugin-structure`: `plugins/loops/` の器（plugin.json・ディレクトリ構成・独自ランタイム不在・モデル ID 直書き禁止）を定義する
- `loops-recipe-format`: レシピ形式規約（固定見出し 7 項目・停止基準必須・ネイティブ起動コマンド・実行機構とのインターフェース宣言の範囲）とレシピテンプレートを定義する
- `loops-state-convention`: 長期/プロアクティブループ用 State ファイルの規約（4 節構成）とテンプレートを定義する
- `loops-design-skill`: `/loops:design` の対話フロー（選択フレームワーク・停止基準必須ゲート・Bad Loop 検査・規約準拠出力）を定義する
- `loops-goalify-skill`: `/loops:goalify` の入力・不足情報のみヒアリング・goal ブリーフ生成・レシピ昇格の促しを定義する
- `loops-loop-types-reference`: `references/loop-types.md` の内容（公式 4 タイプ表・使い分け・実行機構との責務分離の節）を定義する

### Modified Capabilities

（なし。既存プラグイン・既存 spec の要件変更は行わない）

## Impact

- **新規ファイル**:
  - `plugins/loops/.claude-plugin/plugin.json`
  - `plugins/loops/skills/loops-design/SKILL.md`（`/loops:design`）
  - `plugins/loops/skills/loops-goalify/SKILL.md`（`/loops:goalify`）
  - `plugins/loops/references/loop-types.md` / `references/recipe-format.md`
  - `plugins/loops/templates/recipe-template.md` / `templates/state-template.md`
  - `plugins/loops/tests/*.bats`（規約検証テスト）
- **変更ファイル**: なし（既存プラグインには触れない。marketplace.json 登録・README 追記は change-5）
- **依存**: なし（change-2〜4 が本 change の成果物を前提とする）
- **参照流用**: `plugins/longrun/references/plan-interview-methodology.md`（goalify のヒアリング方法論）、`plugins/longrun/references/model-tiers.md`（モデル ID の唯一のソース。loops 配下にモデル ID を書かない）
- **非対象**: 定期実行の機構・配線一式、独自ループランタイム（schema + driver）、シードレシピの執筆（change-3）、プロアクティブルーチン（change-4）
