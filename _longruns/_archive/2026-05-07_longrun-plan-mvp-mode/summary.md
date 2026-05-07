# Summary — longrun-plan-mvp-mode

## 概要
`longrun:plan` に MVP モード（`--mode=mvp`）を追加。フルモードは温存し、コマンドフラグで切り替え可能にした。

## 期間
- 開始: 2026-05-07 10:35
- 完了: 2026-05-07 11:50

## Changes
| Change | 内容 | コミット | 行数 |
|--------|------|---------|------|
| longrun-mvp-mode-subagents | 3 subagent 追加 (research / plan-reviewer / bestpractice-reviewer) | 58f5f9f | +480 |
| longrun-mvp-mode-skill-branch | SKILL.md に MVP モード分岐追加（既存本文 0 deletion） | 905b44b | +198 |
| longrun-mvp-mode-template-archive | 軽量テンプレ + archive 拡張 + version 同期 bump 5.2.0 | 123474a | - |
| (fix) plugin.json agents 登録 | verifier指摘で 3 MVP agent を agents 配列に追加 | aeb5b57 | +3 |

## 検証結果
- OpenSpec validate: 3 change 全て `is valid`
- plugin.json: valid JSON、agents=7 (既存4 + MVP3)
- SKILL.md フルモード regression: `git diff` で deletion 0 行（既存 Step 1〜8 本文不変）
- version 同期: plugin.json と SKILL.md frontmatter 共に 5.2.0
- 受け入れ条件 #5〜#12: コードレビュー観点では PASS（実機 invocation は Feedback で確認）

## 主要な意思決定（decisions.md 参照）
- **D1**: worktree なしで proud-rotate ブランチ直列実装（A→B→C 依存のため並列不可）
- **D2**: OpenSpec longrun-tdd スキーマセットアップをスキップ（Markdown only）
- **D3**: longrun-browser-verifier をスキップ（CLI/Markdown プラグイン）
- **D4**: Build Contract レビューを plan 段階の APPROVE と別に再実行
- **D5**: version 同期 bump は 4.3.0 ではなく 5.2.0 に統一（plugin.json が既に 5.1.0 だった）

## verifier 指摘で修正した1件
- BLOCKER: plugin.json `agents` 配列に新規 MVP agent 3 件が未登録 → fix(longrun) コミット aeb5b57 で修正

## 残存タスク（手動確認）
plan.md の動作確認方法 10 ステップ（受け入れ条件 #5〜#12 のうち実機 invocation 検証が必要なもの）:
1. plugin.json バージョン 5.2.0 確認 ✅（自動確認済）
2. 新セッション起動（プラグイン再読み込み）
3. `/longrun:plan --mode=mvp テスト用のシンプルな機能追加` 実行
4. AskUserQuestion で 3〜5 問のヒアリング確認
5. research subagent 並列起動確認
6. v0 統合後、review subagent×2 並列起動確認
7. 最終 plan.md が `_longruns/YYYY-MM-DD_slug/plan.md` に保存される確認
8. 生成 plan.md 先頭に `<!-- mvp-mode -->` マーカー含むこと確認
9. `/longrun:archive` で OpenSpec change 生成スキップ + `_longruns/` のみアーカイブ確認
10. 別セッションで `/longrun:plan`（引数なし）でフルモード regression 確認
