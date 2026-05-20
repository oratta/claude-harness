---
phase: Setup
status: complete
last_updated: 2026-05-20T13:30:00+09:00
---

## ツール検証結果
- openspec: /Users/oratta/.volta/bin/openspec (v1.2.0)
- git: 2.40.1 on daily-report-output-adjus
- bats: /opt/homebrew/bin/bats (利用可能)

## OpenSpec 状態
- openspec/ 初期化済み
- openspec/schemas/longrun-tdd/ 存在（apply.md / propose.md / spec.md / tasks.md / design.md / proposal.md 完備）
- openspec/changes/ には別件（infra-setup-skill）が存在、本ランの change とは独立

## ベースラインテスト
- daily-report プラグインに既存テストなし（tests/ ディレクトリ無し）
- 本ランで bats テストを新規追加する（change-2 / change-3 / change-4 のスコープ）

## コードベース調査結果（要点）
- daily-report プラグイン本体: `plugins/daily-report/skills/daily-report/SKILL.md`（Step 0〜6 シーケンシャル）
- 現状は単一 Skill、Agent 定義なし、plugin.json に `agents` フィールド無し（追加必要）
- MCP ツール使用 Agent の前例: `plugins/longrun/agents/longrun-browser-verifier.md`（`mcp__playwright__*`, `mcp__claude-in-chrome__*` を tools wildcard 指定） — change-0 spike の参照実装として利用
- 外部依存: `vlog-album` (marketing-harness), `obsidian-markdown` (obsidian) は plugins/ 配下に無し → 既存挙動として呼べる前提を維持、本ランでは触らない

## Changes 一覧（plan.md より）
| Change | スコープ | 依存 | 並列性 |
|--------|---------|------|--------|
| change-0 | spike: MCP 利用方式検証 | 独立 | 単独 |
| change-1 | 出力先パス統一（`01 - DAILY/`） | change-0 後 | 単独 |
| change-2 | voice-compactor Agent 新設 | change-0 後 | change-3 と並列可 |
| change-3 | llm-log-compactor Agent 新設 + メタ統計 | change-0 後 | change-2 と並列可 |
| change-4 | Skill 2フェーズ化 + sanity check + Step 4 維持 | change-1/2/3 後 | 単独 |
| change-5 | diary 中間ファイル参照に書き換え + 必要時 LLM ログ補完 | change-4 後 | 単独 |

## 完了フェーズ
- [x] Setup: ツール検証 / コードベース調査 / checkpoint 初期化
- [ ] Build Contract: longrun-reviewer で Changes 分解レビュー
- [ ] Build: 各 change を longrun-builder で TDD 実装
- [ ] Verify: longrun-verifier + longrun-browser-verifier で4軸定量評価
- [ ] Feedback: ユーザー確認
- [ ] Archive: OpenSpec change + ランディレクトリのアーカイブ

## 次フェーズへの引き継ぎ
- plan.md は longrun-plan で Round 2 APPROVE 済み（自己レビューバイアス除去のため Build Contract で再レビュー）
- change-0 spike を最初に実行し、結果を plan.md 末尾に追記してから change-2/3 着手
