# Plan: longrun:plan に MVP モードを追加する

## 生成情報
- 作成日: 2026-05-07
- Brain Dump元: docs/cooking-mvp-mode-plan.md（5章で別 longrun 立ち上げを宣言）
- 質問回数: 4問

## ゴール
`/longrun:plan` に MVP モード（`--mode=mvp`）を追加し、ヒアリング → 並列リサーチ → v0統合 → 並列レビュー → 軽量 plan.md 出力という短時間用ワークフローを提供する。フルモードは温存し、コマンドフラグで切り替え可能にする。

## ビジネスコンテキスト
- 対象ユーザー: 短時間で人間が手で MVP を実装する開発者全般。**特定プロジェクト（1h-cooking 等）には依存しない汎用機能**として実装する
- 提供価値: 重装備な Build Contract / TDD / Verifier をスキップしつつ、ヒアリング+並列リサーチ+レビューによる「初期プラン v0」を高速生成
- 成功指標:
  - `/longrun:plan --mode=mvp` 実行から最終 plan.md 出力まで人間操作含めて短時間（数分〜十数分）で完了
  - 任意のプロジェクトから呼び出して MVP プランが得られる（プロジェクト固有の前提を持たない）
  - フルモードの既存挙動に regression なし

## 技術要件
- スタック: Claude Code Skill (Markdown駆動) + Agent定義 (Markdown frontmatter)
- 参照パターン:
  - `plugins/longrun/skills/longrun-plan/SKILL.md`（既存フルモードのフロー）
  - `plugins/longrun/agents/longrun-reviewer.md`（既存 Agent 定義のフォーマット）
  - `plugins/longrun/templates/plan-template.md`（既存テンプレ構造）
- 制約:
  - フルモード（引数なし or `--mode=full`）は既存挙動を**完全に維持**する。回帰禁止
  - `~/.claude/commands/` や `~/.claude/skills/` を直接編集しない（marketplace版のみ編集 - plugin-editing.md ルール）
  - `plugin.json` のバージョンを上げる
- テストフレームワーク: なし（プラグイン本体は Markdown ベース。ユニットテストは存在しない）
- テスト実行コマンド: `bash plugins/longrun/scripts/validate-plan.sh _longruns/<dir>/plan.md`（既存があれば。なければ動作確認の手動 invocation のみ）

## スコープ

### 含むもの
- `--mode=mvp` フラグの受領と分岐ロジックを `longrun-plan` SKILL.md に追加
- 3つの新規 Agent 定義ファイル（research×1, review×2）を `plugins/longrun/agents/` に追加
- 軽量 plan テンプレ `plugins/longrun/templates/plan-template-mvp.md` の新規作成
- `/longrun:archive`（`commands/archive.md`）に MVP モード対応の分岐を追加（OpenSpec change 生成をスキップして `_longruns/` ディレクトリのアーカイブのみ実施）
- `commands/plan.md` と `lr:p` エイリアスの引数説明更新（`--mode=mvp` の受け渡し）
- `plugin.json` のバージョン bump

### 含まないもの
- フルモードの挙動変更（理由: regression リスク回避。MVP モードは追加機能として共存させる）
- `/longrun:exec` 側の MVP モード対応（理由: MVP モードの plan.md は人間実装前提なので exec への引き渡し不要）
- subagent の自動テストフレームワーク導入（理由: harness 全体に unit test 文化がない。スコープ外）
- 特定プロジェクト（1h-cooking 等）側からの呼び出し統合・専用ラッパー作成（理由: longrun:plan は汎用機能として疎結合に保つ。プロジェクト固有のラッパーは各プロジェクト側で実装する）
- フルモードと MVP モードの subagent 共有化リファクタ（理由: 過剰最適化。先に動かす）

## Changes分解

### change-A: MVPモード用 subagent 3種を追加
- **スコープ**: `plugins/longrun/agents/` に以下3ファイルを新規作成
  - `longrun-mvp-research.md` — 類似サービス+実装パターンを**1回の調査**で行い、1レポートに2セクション（## 類似サービス事例 / ## 実装パターン）で出力。同一クエリで重複検索を避けトークン節約
  - `longrun-mvp-plan-reviewer.md` — 初期プラン v0 を受け取り、スコープが MVP として過大でないか / 矛盾がないか / 受け入れ条件が検証可能か をレビュー（**特定の時間枠に依存しない汎用レビュー**）
  - `longrun-mvp-bestpractice-reviewer.md` — 該当ドメインの落とし穴・anti-pattern を外部知識ベースで指摘
- **使用スキル**: research-with-fallback（外部リサーチに使用）、context7 MCP
- **依存関係**: 独立（先に着手可）
- **config.yaml rules**:
  - "research subagent は同一クエリで重複検索しないこと。1度の調査で2レポート出力する設計を厳守"
  - "Agent 定義は既存 longrun-reviewer.md と同じ frontmatter 形式（name / description / tools）に従うこと"
  - "review subagent は plan v0 を input として受け取り、APPROVE/REQUEST_CHANGES 形式で出力すること"
  - "review subagent（特に bestpractice-reviewer）は外部検索を**1回まで**に制限すること。トークン爆発防止のため"
  - "**全 subagent（research / plan-review / bestpractice-review）はレポート末尾に必ず `## Search Audit` セクションを付与すること**。形式: `- queries: <数>` `- list: [<クエリ文字列の配列>]`。これが受け入れ条件の検証根拠となる"

### change-B: longrun-plan SKILL.md に MVP モード分岐を追加
- **スコープ**:
  - `plugins/longrun/skills/longrun-plan/SKILL.md` を更新
  - 引数解釈に `--mode=mvp` フラグ判定を追加
  - **MVP モード対応マッピング表を SKILL.md に明記する**（Step 1〜8 × 再利用/差し替え/スキップ）:
    | 既存 Step | MVP モード対応 | 内容 |
    |---|---|---|
    | Step 1 (テンプレ読み込み) | **差し替え** | `templates/plan-template-mvp.md`（軽量版）を読み込む |
    | Step 2 (OpenSpec状態確認) | **スキップ** | 人間実装前提なので backlog 照合不要 |
    | Step 2b (Brain Dump収集) | **再利用** | 引数 / 対話で取得する流れは同じ |
    | Step 3 (Gap Analysis) | **再利用** | 軽量化せずそのまま実施 |
    | Step 4 (Interview) | **再利用** | AskUserQuestion で 3〜5 問 |
    | **新規 Step 4.5 (並列リサーチ)** | **追加** | research subagent×1 を起動（類似サービス+実装パターン1レポート2セクション） |
    | Step 5 (Synthesis) | **差し替え** | 軽量テンプレに従って v0 plan.md を生成 |
    | Step 5a (残りステップ宣言) | **差し替え** | MVP 用文言（review subagent×2 並列レビュー → ユーザー確認）に書き換え |
    | Step 5b (Backlog照合) | **スキップ** | Step 2 をスキップしているため不要 |
    | Step 6 (Validation) | **差し替え** | 軽量テンプレ用 Validation チェックリストに切り替え |
    | Step 7 (Plan Review) | **差し替え** | longrun-reviewer ではなく longrun-mvp-plan-reviewer + longrun-mvp-bestpractice-reviewer を**並列起動** |
    | Step 8 (確認+確定) | **差し替え** | backlog 消込みなし。ハンドオフ案内のみ（人間実装 or `/longrun:exec`） |
  - MVP モードでは Build Contract レビュー / TDD 強制 / Verifier 自動起動をスキップする旨を SKILL.md に明記
- **使用スキル**: なし（Markdown 編集のみ）
- **依存関係**: change-A 完了後に着手（subagent 定義が存在しないと SKILL.md から呼び出せない）
- **config.yaml rules**:
  - "フルモード（引数なし or --mode=full）の既存挙動を変更しないこと。フラグ判定の追加のみで既存ロジックに触らない"
  - "**変更前後で SKILL.md の Step 1〜8 既存セクションの diff が『フラグ判定の追加 + MVP モード分岐の追加』以外に発生していないこと**。git diff で Step 本文の文言変更が無いことを確認する"
  - "subagent 並列起動は `Agent` ツールを単一メッセージ内で複数 tool_use に分けて呼び出す"
  - "MVP モードでも Validation（plan.md 必須セクション存在チェック）は省略しない。軽量版テンプレに対するチェックに切り替える"

### change-C: 軽量テンプレ追加 + archive 拡張 + ドキュメント更新
- **スコープ**:
  - `plugins/longrun/templates/plan-template-mvp.md` を新規作成（フルテンプレから Build Contract / TDD / Verifier 関連セクションを除外）
  - `plugins/longrun/commands/archive.md` を更新: MVP モードで作成された plan.md（frontmatter or マーカーで判定）の場合、OpenSpec change 生成をスキップして `_longruns/<dir>/` のアーカイブ処理のみ実施
  - `plugins/longrun/commands/plan.md` の引数説明に `--mode=mvp` を追記
  - `lr:p` エイリアス（`plugins/longrun/commands/` 内）も `--mode=mvp` を受け渡せるよう更新
  - `plugins/longrun/.claude-plugin/plugin.json` のバージョンを bump（minor: 4.2.0 → 4.3.0 を想定）
  - **`plugins/longrun/skills/longrun-plan/SKILL.md` の frontmatter `version: 4.2.0` も `4.3.0` に同期 bump**（プラグインキャッシュがバージョン単位なのでスキル側も bump 必須）
  - `plugins/longrun/README.md` に MVP モードの使い方を追記
- **使用スキル**: なし
- **依存関係**: change-A, change-B 完了後（テンプレと archive の対応はスキル本体が動いてから検証する必要がある）
- **config.yaml rules**:
  - "軽量テンプレは Build Contract / TDD / Verifier 関連セクションを含めないこと。代わりに『調査結果サマリ（類似サービス）』『調査結果サマリ（実装パターン）』『レビュー結果サマリ』セクションを含める"
  - "**軽量テンプレの先頭に『フルテンプレ（plan-template.md）から派生。共通セクション（ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法）変更時は両方更新すること』のコメントを必ず入れる**。divergence 防止"
  - "archive 拡張は MVP モード判定マーカー（plan.md 内の `<!-- mvp-mode -->` コメント等）で分岐すること。frontmatter 追加は破壊的変更になるので避ける"
  - "plugin.json と SKILL.md frontmatter の version を**同時に**bump すること（plugin-editing.md ルール）"

## 画面・UI設計
（該当なし — CLI/スキル機能のため UI 変更なし）

ユーザー体験の観点:
- 起動: `/longrun:plan --mode=mvp [引数]` または `/lr:p --mode=mvp [引数]`
- ヒアリング: 既存と同じ AskUserQuestion 形式（最大 3〜5 問）
- 進捗表示: subagent 並列起動時に「research/plan-review/best-practice の3 subagent を並列起動中」を出力
- 完了表示: `_longruns/YYYY-MM-DD_slug/plan.md` の保存先案内 + 「人間で実装する場合の次の一手」のハンドオフ提案

## データモデル
（該当なし — ファイルベース設計）

ファイル構成:
- 入力: ユーザーの brain dump（コマンド引数 or 対話で取得）
- 中間データ: research レポート（context内に保持、ファイル化しない）、v0 plan（context内）、review レポート（context内）
- 出力: `_longruns/YYYY-MM-DD_slug/plan.md`（軽量テンプレに従う）

MVP モード判定マーカー:
- 軽量テンプレの先頭に `<!-- mvp-mode -->` コメントを埋め込み、archive 側で判定に使う
- フルモード plan.md には埋め込まれないので既存挙動に影響なし

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている（※プラグイン本体は unit test なし。代替として「手動 invocation で期待動作を確認」を満たす）
3. [ ] ビルドエラーなし（型チェック + ビルド）（※Markdown プラグインなのでビルド工程なし。代替として「marketplace から install 後に `/plugin install` が成功する」を満たす）
4. [ ] 統合テストがPASS（worktreeマージ後）（※「main にマージ後、`/longrun:plan --mode=mvp` を1回実行して plan.md が生成されること」で代替）

**機能固有の条件:**
5. [ ] `/longrun:plan --mode=mvp` 実行で `plugins/longrun/agents/longrun-mvp-research.md` `longrun-mvp-plan-reviewer.md` `longrun-mvp-bestpractice-reviewer.md` の3 Agent が呼び出せること（手動確認: ログ or プロンプト出力で並列起動が確認できる）
6. [ ] research subagent の出力レポート末尾に `## Search Audit` セクションがあり、`queries: 1` と表示されること。実装パターンレポートの方も同じ Search Audit を共有していること（**Search Audit による定量検証**）
7. [ ] フルモード `/longrun:plan`（引数なし）実行時、SKILL.md の Step 1 GATE 通過 → `templates/plan-template.md`（フル版・**軽量版でない**）読み込みのログが出ること。Step 2〜8 が既存挙動通り実行されること（**ログ出力で具体的に検証**）
8. [ ] MVP モードで生成された plan.md が `templates/plan-template-mvp.md` の必須セクション（ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法 / 調査結果サマリ / レビュー結果サマリ）を全て含むこと（手動確認: 出力 plan.md を目視）
9. [ ] `/longrun:archive` が MVP モード plan.md（`<!-- mvp-mode -->` マーカーあり）を検知し、OpenSpec change 生成をスキップして `_longruns/` ディレクトリのみアーカイブできること（手動確認: テスト用に作った MVP plan.md を archive 実行）
10. [ ] `plugins/longrun/.claude-plugin/plugin.json` と `plugins/longrun/skills/longrun-plan/SKILL.md` frontmatter の **両方の** version が 4.3.0 に bump されている
11. [ ] review subagent（plan-reviewer / bestpractice-reviewer）の出力レポート末尾にも `## Search Audit` セクションがあり、`queries: <=1` であること（トークン爆発防止の検証）
12. [ ] change-B の git diff で SKILL.md の Step 1〜8 既存セクション本文の文言が変更されていないこと（フラグ判定追加と MVP モード分岐の追加のみ）（**git diff レビューで検証**）

## 意思決定ガイドライン
- 優先順位: 既存フルモードの regression 回避 > MVP モードの完成度 > コード重複の削減
- リスク許容度: 保守的（既存ユーザーがいる機能の拡張なので、既存挙動への影響を最小化）
- 不明点の扱い:
  - subagent の prompt 文言で迷ったら、既存 `longrun-reviewer.md` の構造を踏襲する
  - 軽量テンプレで残すセクションで迷ったら、フルテンプレから「Build Contract / TDD / Verifier 関連」を削るだけにする（追加はしない）
  - archive のマーカー方式で迷ったら、HTMLコメント `<!-- mvp-mode -->` を選ぶ（frontmatter は破壊的変更）

## 動作確認方法
- 開発サーバー: なし（プラグインのため）
- テスト: なし（プラグイン本体に unit test なし）
- 確認手順:
  1. worktree 内で `plugins/longrun/.claude-plugin/plugin.json` のバージョンが上がっているか確認
  2. 新しい Claude Code セッションを起動（プラグイン再読み込みのため）
  3. `/longrun:plan --mode=mvp テスト用のシンプルな機能追加` を実行
  4. AskUserQuestion で 3〜5 問のヒアリングが行われることを確認
  5. ヒアリング後、`Agent` ツールで research subagent が並列起動されることを確認（メッセージ内のツール呼び出しを目視）
  6. v0 統合後、`Agent` ツールで review subagent×2 が並列起動されることを確認
  7. 最終 plan.md が `_longruns/YYYY-MM-DD_slug/plan.md` に保存されることを確認
  8. 生成された plan.md の先頭に `<!-- mvp-mode -->` マーカーが含まれることを確認
  9. `/longrun:archive _longruns/YYYY-MM-DD_slug/` を実行し、OpenSpec change 生成がスキップされ `_longruns/` のみアーカイブされることを確認
  10. **回帰確認**: 別セッションで `/longrun:plan` を引数なしで実行し、フルモードが既存挙動通り動くことを確認

## Brain Dumpからの原文メモ

> 1h-cooking 側に `/cooking:requirements` を新設するより、`longrun:plan` に **MVP モード** を追加して同じスロットを埋めるほうが筋がいい。後者なら他プロジェクトでも使える汎用機能になり、1h-cooking は単に呼び出すだけで済む。

> なんかリサーチ系が同じリソースをリサーチしちゃいそうな気がしているから、シミュラーリサーチもパターンリサーチも検索ワードが同じで、別々のエージェントで同じことを調べて、別の趣旨のレポートを作るみたいなことになりそうだから。なんかクエリや検索対象が同じになりそうなリサーチは一つのリサーチエージェントにして、複数のレポートを作るようにしないとトークンが爆発しそうな気がする。

> MVP モードでは以下の重装備をスキップする: Build Contract レビュー / TDD 強制 / Verifier 起動による自動受け入れ判定。理由: 1h で人間が手で MVP を作る前提なので、自律実行の安全装置は不要。レビューは人間がその場でやる。
