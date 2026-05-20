# Summary: wt-clean-merge-active

## 概要

`wt-clean` が 🔴 Active worktree（未マージコミットあり）を検出した際、現状の「スキップ／全件破棄」に加えて「main にマージしてからクリーンアップ」する選択肢を**最優先（推奨）**として提示し、ユーザー個別確認のもとでマージ→サニティチェック→削除までを一気通貫で実行できるようにした。

- 開始: 2026-05-20 09:07 JST（/longrun:plan）
- 完了: 2026-05-20 10:30 JST（Verify PASS）
- 所要: 約 1 時間 23 分
- 自律コミット: ユーザー明示承認済み（本セッション限り）

## Changes 一覧

| Change | スコープ | コミット | OpenSpec |
|---|---|---|---|
| change-A: wt-clean-merge-active | wt-clean.md / SKILL.md / plugin.json / marketplace.json | 39c60ec, 3ba42a8, c4cf96b | proposal / design / tasks / spec validated |

## テスト結果（手動シナリオ仕様化）

自動テストランナー未整備のため、spec.md の WHEN/THEN Scenarios で仕様化（実機実行は Feedback でユーザー）:

| シナリオ | 内容 | 仕様化 |
|---|---|---|
| S1 | Dirty なし 🔴 1 件 → マージ → 成功 | ✅ |
| S2 | Dirty なし 🔴 1 件 → スキップ → 状態維持 | ✅ |
| S3 | Dirty なし 🔴 1 件 → 破棄削除 | ✅ |
| S4 | Dirty 同時 🔴 → マージ選択肢除外 | ✅ |
| S5 | Dirty なし 🔴 2 件 → 両方マージ | ✅ |
| S6 | 🔴 3 件、2 件目で競合 → 全保留 | ✅ |
| S7 | 🔴 0 件 → 新選択肢なし | ✅ |
| S8 | 既存「全て処理（🔴破棄）」ルート維持 | ✅ |
| S9 | `--keep` + 新ルート → 通常削除（明示） | ✅ |
| S10 | `--no-sync` + 新ルート → 非干渉 | ✅ |
| S11 | メインリポが MAIN_BRANCH 以外 → 中断 | ✅ |
| S12 | 全 🔴 が Dirty → 案内表示 | ✅（追加） |
| S13 | detached HEAD の 🔴 → マージ選択肢除外 | ✅（追加） |
| S14 | メインリポ merge in progress → 中断 | ✅（追加） |

合計 14 シナリオ。verification-guide.md の「テスト実装完了」「ロジック実装完了」は全て [x]、「動作確認完了」「ユーザー確認完了」は Feedback フェーズでユーザーが更新。

## 意思決定サマリー

D1: 単一 change-A 構成、worktree 分割なし（同 worktree 内で直接実装）
D2: 自動テストランナー未整備のためベースラインなし、手動シナリオで仕様化
D3: 自律コミット方針（ユーザー明示承認済み、本セッション限り）
D4: 完了レポートの最終表現は plan.md の 3 パターンをそのまま転記
D5: per-worktree 個別確認の表示順序は `git worktree list` の順（作成順）
D6: 競合発生時の不変条件を Step 5b-4 と Step 6d の両方に明記
D7: AskUserQuestion ラベル文言を既存 Step 3 スタイルに統一

## 評価スコア（本プロジェクト用調整版）

| 軸 | スコア | しきい値 | 判定 | 検証 Agent |
|----|-------|---------|------|----------|
| 品質（openspec validate / JSON 構文 / commands-SKILL 同期 / version bump） | 100% | 100% | ✅ | longrun-verifier |
| 完成度（plan 16 条件カバレッジ + エッジケース 3 件追加実装） | 100% | 80% | ✅ | longrun-verifier |
| 機能性（spec Scenario 仕様化） | 100% | 100% | ✅ | spec review |
| UX（操作フローの自然さ） | 手動シナリオ実機実行待ち | 70% | 保留 | longrun-browser-verifier N/A、ユーザーが Feedback で評価 |

## 変更ファイル一覧

実装:
- plugins/worktree/commands/wt-clean.md
- plugins/worktree/skills/wt-clean/SKILL.md
- plugins/worktree/.claude-plugin/plugin.json
- .claude-plugin/marketplace.json

OpenSpec:
- openspec/changes/wt-clean-merge-active/proposal.md
- openspec/changes/wt-clean-merge-active/design.md
- openspec/changes/wt-clean-merge-active/tasks.md
- openspec/changes/wt-clean-merge-active/specs/wt-clean-merge-active/spec.md

ランディレクトリ:
- _longruns/2026-05-20_wt-clean-merge-confirm/plan.md
- _longruns/2026-05-20_wt-clean-merge-confirm/checkpoint.md
- _longruns/2026-05-20_wt-clean-merge-confirm/decisions.md
- _longruns/2026-05-20_wt-clean-merge-confirm/verification-guide.md
- _longruns/2026-05-20_wt-clean-merge-confirm/summary.md

## 次のアクション（ユーザー）

1. 本ブランチ `wt-clean-merge-confirm` で動作確認:
   - `/reload-plugins` で plugin v1.8.0 を有効化
   - サンドボックス repo（例: `/tmp/wt-clean-test-$$`）で S1〜S14 のうち気になるシナリオを実機実行
2. フィードバック:
   - 問題なければ「OK」 → Archive フェーズ（OpenSpec change archive + _longruns archive）
   - 修正点があれば自由形式で伝える → longrun-feedback が Tier 分類して処理
