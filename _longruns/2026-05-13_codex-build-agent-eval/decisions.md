# Decisions Log

## Plan フェーズで確定済みの意思決定（plan.md 由来）

### D-001: アーキ方針 — 別 Agent 新設 + orchestrator 分岐
- **コンテキスト**: longrun-builder を Codex 5.5 Pro に委譲する方法の選択
- **選択**: Phase 2 で `longrun-builder-codex` Agent を新設し orchestrator 側で分岐
- **却下案**: ①現行 builder 内部を Bash 委譲化（フォールバック実装が複雑）/ ②Hybrid（Codex 委譲量が薄く効果不明）
- **根拠**: 影響範囲を限定 + A/B 比較が容易 + フォールバックを素直に書ける
- **エビデンス**: AskUserQuestion 回答（"別 Agent 新設 + orchestrator 分岐（推奨）"）

### D-002: フォールバック検出 — 実行失敗検出
- **選択**: codex-companion task の exit code / stderr / stdout 解析で 429・quota・auth エラーを検出 → opus 経由再実行
- **却下案**: ①事前ヘルスチェック（Codex CLI に quota 取得 API 不在）/ ②両方併用（PoC スコープに対し重い）
- **根拠**: PoC 段階で十分。Phase 2 でタイムアウト・部分成功などのエッジを追加可能
- **エビデンス**: AskUserQuestion 回答 + longrun-reviewer 指摘3への対応（受け入れ条件 #10 で網羅）

### D-003: スコープ — Phase 1 PoC のみ
- **選択**: 本 plan は PoC + 評価レポートまで。本実装は Phase 2 で別 plan
- **根拠**: ブランチ名 `codex-build-agent-eval` の含意と整合。サブスク仕様未知で実装まで一気にやると stuck リスク
- **エビデンス**: AskUserQuestion 回答 + plan.md 「Phase 2 への引き継ぎ条件」セクション

### D-004: 検証対象 — oratta-claude-harness 内 sandbox
- **選択**: `_longruns/2026-05-13_codex-build-agent-eval/sandbox/` にダミー実装
- **根拠**: OpenSpec / longrun が手元に揃う + Codex 暴走時の被害を sandbox に閉じられる
- **エビデンス**: AskUserQuestion 回答

### D-005: モデル ID — PoC 中に同定
- **選択**: `codex` CLI で利用可モデル一覧を取得し「5.5 Pro 相当」を採用。不在時は最上位 Pro 系で代替
- **根拠**: 「5.5 pro」の実在 ID が plan 時点で未確認
- **エビデンス**: AskUserQuestion 回答 + longrun-reviewer 指摘2への対応

### D-006: PoC 評価軸 — 4 軸全採用
- **選択**: TDD 完走 / フォールバック / コスト時間 / TDD 忠実度
- **根拠**: 単独軸では Go/No-Go 根拠が薄い。4 軸あれば Phase 2 リスクも抽出できる
- **エビデンス**: AskUserQuestion 回答（multiSelect 全選択）

## Plan Review（longrun-plan 内）での確定事項

### D-007: 受け入れ条件 #6 を #6a / #6b に分割
- **コンテキスト**: longrun-reviewer 指摘1 (BLOCKER) — Codex の TDD 完走能力とコミット粒度制御能力が混線する
- **選択**: #6a = RED→GREEN ループ成立、#6b = git log コミット順序確認。#6a 成立 + #6b 不成立 → Conditional Go
- **根拠**: Codex の能力評価とプロンプト設計の出来を独立軸として分離
- **エビデンス**: longrun-reviewer レビュー（2 ラウンド目で APPROVE）

### D-008: Codex 暴走対策の三重防御
- **コンテキスト**: longrun-reviewer 指摘4 (BLOCKER) — sandbox 外書き込みが事後検出のみ
- **選択**: ①事前 `git status` クリーン化、②実行直後 `git diff --name-only` で sandbox 外即時破棄、③Bats でガード自体をテスト (#12)
- **根拠**: Codex CLI に `--cd` / `--sandbox` 相当はあるが、PoC 段階で過信せず多段防御
- **エビデンス**: plan.md change-A config.yaml rules + 受け入れ条件 #12
