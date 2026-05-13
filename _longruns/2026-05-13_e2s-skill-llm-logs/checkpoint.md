---
phase: Setup
status: in_progress
last_updated: 2026-05-13T00:00:00Z
---

# Checkpoint — 2026-05-13 e2s-skill-llm-logs

## ツール検証結果

- openspec: `/Users/oratta/.volta/bin/openspec` (v1.2.0)
- git: v2.40.1 on branch `e2s-skill-llm-logs-2`
- bats: `/opt/homebrew/bin/bats` (v1.13.0)
- jq: `/usr/bin/jq` (v1.7.1-apple)

## フェーズ進捗

- [x] Setup: ツール検証完了
- [ ] Setup: Explore コードベース調査（実行中）
- [ ] Setup: OpenSpec 初期化チェック
- [ ] Setup: 初期コミット
- [ ] Build Contract: longrun-reviewer による Changes 分解レビュー
- [ ] Build: change-A の OpenSpec 仕様作成 + verification-guide.md 生成
- [ ] Build: change-A の TDD 実装（longrun-builder）
- [ ] Build: change-B の OpenSpec 仕様作成 + 実装
- [ ] Verify: longrun-verifier 静的検証
- [ ] Verify: longrun-browser-verifier（該当なし、CLI plugin のため skip 判断）
- [ ] Feedback: ユーザー動作確認
- [ ] Archive: OpenSpec change + ランディレクトリのアーカイブ

## Changes 概要

| Change | スコープ | 依存 | Status |
|---|---|---|---|
| change-A | e2s 既存削除＋新設計実装（jsonl 起点・対話完結 1 コマンド） | 独立 | Pending |
| change-B | グローバルルール (`~/.claude/rules/git-commit-policy.md`) + 既存 openspec change `experience-to-skill-plugin` 整理 | change-A の main マージ後 | Pending |

## 重要な決定（plan review Round 1 で確定）

1. jsonl ディレクトリエンコーディング: `/` だけでなく `.` も `-` に変換、連続ハイフン保持
2. サニタイズロジック (`scripts/sanitize.sh` Layer 1 + skill 内 Layer 2) は旧ファイル削除前に新ファイルへスナップショット
3. グローバルルール書き換えは change-A の main マージ後に分離（不整合期間排除）
4. 旧コマンド参照は 3 段検査（grep + find + plugin.json）で 0 件確認
5. jsonl スキャン順序: 存在確認 → mtime → サイズ上限 50MB → grep
6. fixture jsonl をテストに 1 件コミット（サニタイズ済み）
