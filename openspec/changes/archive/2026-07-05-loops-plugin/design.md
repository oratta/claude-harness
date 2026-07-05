# Design: loops-plugin

## Context

公式記事「Getting started with loops」（claude.com、2026-06-30）は、ループのランタイムをネイティブプリミティブ（skill / /goal / /loop / /schedule / workflows / auto mode）とし、ループは**その合成**で作るという立場を示した。前版 plan では `loop-definition.schema.json` + `/loops:run` + `build-loop.sh` driver という独自ランタイムを設計していたが、公式記事の確認により「ランタイムはネイティブ、ハーネスはレシピと規約」に方針転換した（plan.md 付録 E）。本 change はその転換後の最初の change であり、change-2〜4（skill 自己検証・シードレシピ・プロアクティブルーチン）の土台となる器・規約・設計ガイドを作る。

一次ソースの優先順位: `research/loop-engineering.md` 冒頭の公式記事セクションが最上位。コミュニティ由来の概念（Osmani の 5+1 構成要素・State・失敗 6 類型）は設計の参考に留め、公式と矛盾したら公式に従う。

## Goals / Non-Goals

**Goals:**

- 新プラグイン `plugins/loops/` の骨格（plugin.json・skills・references・templates・tests）を作る
- レシピ形式規約（固定見出し 7 項目・停止基準必須）と State 規約（4 節）を Markdown 規約として確立する
- `/loops:design`（選択フレームワーク + Bad Loop 検査 + 停止基準必須ゲート）と `/loops:goalify`（不足情報のみヒアリング → goal ブリーフ生成）の 2 スキルを提供する
- `references/loop-types.md` で公式 4 タイプと実行機構との責務分離を配布物化する

**Non-Goals:**

- 定期実行の機構・配線一式（セッション内 cron 登録・SessionStart 復元 hook・session-host supervisor・launchd・`claude -p` 配線）。実行側は別セッションの Pikke プロセス整理が担う。レシピは実行方法非依存に書く
- 独自のループ実行系（loop-definition schema による宣言的ランタイム・headless driver スクリプト）
- レシピ形式の schema 化・機械検証（必要になってから。backlog へ）
- シードレシピの執筆（change-3）・プロアクティブルーチン（change-4）・marketplace.json 登録と README 追記（change-5）

## Decisions

### D1: ランタイムを持たない — レシピは「人間とエージェントが読む設計図」

反復・スケジュール・停止判定はネイティブプリミティブ（/goal の最大試行・/loop・/schedule のキャンセル・Workflow の budget）に任せ、レシピの責任は「明確な停止基準を宣言する」ことに置く。レシピの第一級の成果物はコピペで動くネイティブコマンド文字列であり、独自 CLI・ラッパースクリプトは作らない（plan.md config rules）。

- 代替案: 前版の schema + driver 方式。宣言的で機械検証しやすいが、公式路線（ネイティブ合成）から逸脱し、driver の保守という新たな負債を生むため廃案。廃案分で将来価値がありうるもの（レシピの機械検証・loop-audit 相当）は `openspec/backlog.md` に記録する

### D2: レシピ形式は Markdown 見出し規約のみ（MVP スコープ厳守）

固定見出し 7 項目（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の grep 可能な規約とし、JSON Schema 強制はしない。検証は bats + grep で「見出しが存在するか」「停止基準の無いレシピが 0 件か」を機械確認する。

- 代替案: frontmatter YAML + schema 検証。厳密だが MVP スコープ超過であり、規約の初期変更コストが上がるため見送り（backlog）

### D3: 停止基準必須は「規約」と「/loops:design の出力ゲート」の二重で担保する

規約文書で停止基準を必須項目と定義し、さらに `/loops:design` は停止基準（最大試行数 / 時間 / 定量ゴール）が確定するまでレシピを出力しない。Bad Loop 検査 4 項目（停止基準の欠如・検証なき成功宣告・報酬ハッキング余地・過剰な実行頻度）を出力前チェックとして SKILL.md に組み込む。「停止基準の無いレシピを design が出力しないこと」はテストで確認する（plan.md config rules）。

### D4: 実行機構との責務分離はインターフェース宣言のみ

レシピが宣言するのは「発火時に投入するプロンプト」「推奨頻度」「停止基準」「実行環境の制約（例: ローカル jsonl を読むループはローカル実行必須）」まで。スケジューラ登録・セッション運用・課金選択は呼び出し側（Pikke プロセス整理側）の責務とし、`references/loop-types.md` に 1 節で明記する。これによりレシピは `claude -p` 配線・セッション内 cron などどの実行方式にも中立になる。

### D5: /loops:goalify は使い捨て goal ブリーフの一発生成

頻出ワークフロー「書き出し → /goal 用ファイル生成 → 不足ヒアリング」を 1 コマンド化する。ヒアリングは 4 観点（成功基準の機械検証可能化 / 停止条件 / スコープ境界 / 前提）の**不足分のみ**とし、`plugins/longrun/references/plan-interview-methodology.md` の方法論を参照流用する（コピーしない）。生成物は `goals/<name>.goal.md` + /goal 起動コマンド 1 行。反復利用が見えたらレシピへの昇格を促す 1 行を出力に含める（change-4 の recipe-miner の検出対象とも整合）。

### D6: モデル ID 直書き禁止

`plugins/loops/` 配下にはモデル ID（`claude-` で始まる識別子）を書かない。ティアに言及する場合は `plugins/longrun/references/model-tiers.md`（唯一のソース）への参照で表現する。grep テストで 0 件を担保する。

### D7: ファイル配置

- 規約: `references/recipe-format.md`（レシピ形式 + State 規約の置き場所はここに集約。State 規約を独立文書にするかは builder 裁量だが、規約の重複記載は禁止）
- 雛形: `templates/recipe-template.md` / `templates/state-template.md`
- 選択リファレンス: `references/loop-types.md`
- スキル: `skills/loops-design/SKILL.md` / `skills/loops-goalify/SKILL.md`（プラグイン名 `loops` により `/loops:design` / `/loops:goalify` として発火）
- テスト: `plugins/loops/tests/*.bats`（リポジトリ規約 `find plugins -name '*.bats' -print0 | xargs -0 bats` で回収される場所）

## Risks / Trade-offs

- [規約が Markdown のみのため、レシピの規約逸脱を書き込み時に強制できない] → bats + grep の規約テストを change-1 で同梱し、change-3/4 のレシピ追加時に同じテストが検査する。schema 化は必要になってから backlog で対応
- [/loops:design・/loops:goalify の対話挙動（出力拒否・0 問ヒアリング）は grep では完全検証できない] → SKILL.md の該当指示文言の存在を grep で検証し、挙動そのものは受け入れ条件のデモ（design デモ・goalify デモ）で人手確認する
- [State 規約の置き場所（`loops/state/`）は利用側リポジトリの規約であり、本リポジトリでは強制できない] → 規約とテンプレートの提供に留め、実際の運用検証は change-4 のルーチン 1 サイクルデモで行う
- [goalify のヒアリング省略判定（書き出しに既にあるか）の精度] → 判定に迷う場合は「聞く」側に倒す（過剰質問は軽微、情報欠落した goal ブリーフは /goal の暴走リスク）

## Migration Plan

新規プラグイン追加のみで既存プラグインへの変更は無いため、移行作業は不要。marketplace.json への登録・配布は change-5 で行う（それまで `loops` はリポジトリ内にのみ存在し、インストール対象にならない）。ロールバックはディレクトリ `plugins/loops/` の削除で完結する。

## Open Questions

- State 規約を `references/recipe-format.md` に同居させるか独立文書（例: `references/state-format.md`）にするかは builder 裁量（重複記載禁止のみ拘束）
- recipe-template.md の見出しを日本語固定にするか英語併記にするかは、change-3/4 のレシピ執筆と grep 検証の一貫性を優先して builder が決定し、規約文書に明記する
