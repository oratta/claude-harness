# Longrun v3.0

Claude Code ロングラン自律実行システム。
OpenSpec applyへの実装委任 + カスタムスキーマによるTDD/スキル注入 + マルチchange分解 + サブエージェント隔離で、人間の介入なしに品質を担保した自律的実装を完遂する。

## v3.0の設計思想

**longrunはオーケストレーターに徹し、実装はOpenSpec applyに完全委任する。**

```
v2.x: longrun ──自前実装──→ コード
              └─ OpenSpec（ドキュメント生成だけ）

v3.0: longrun ──委任──→ OpenSpec apply ──実装──→ コード
              └─ カスタムスキーマでTDD/スキル/decision-agentパターンを注入
```

## コマンド

| コマンド | 説明 |
|---------|------|
| `/longrun:instruction [brain-dump]` | 対話的にinstruction.mdを作成（マルチchange分解 + スキル選定） |
| `/longrun:exec [path]` | instruction.mdに基づいて自律実行を開始 |
| `/longrun:status [path]` | 現在の進捗状況を確認（openspec list集約） |
| `/longrun:decisions [number]` | 設計判断の一覧を確認 |

## Phaseフロー

```
Phase 0: Setup（codebase探索、OpenSpec初期化、カスタムスキーマセットアップ）
Phase 1: ドキュメント作成（changeごとにサブエージェント + spec-review-agent）
Phase 2: 実装（changeごとにworktree + openspec apply + カスタムスキーマTDD）
Phase 3: 統合（worktreeマージ + 統合テスト + verification-agent）
Phase 4: ハンドオフ（openspec list集約 + verification-guide + ユーザー承認 + archive）
```

## v2.xからの主な変更

### 廃止
- test-agent（TDDはカスタムスキーマのapply.mdテンプレートで注入）
- spec-agent（OpenSpecのff + カスタムスキーマのproposeテンプレートに委任）
- decision-agent（スキーマテンプレートに振る舞いとして注入）
- longrun独自のタスク進捗管理（OpenSpec tasks.mdに一元化）

### 残留
- instruction-builder（マルチchange分解 + スキル選定に大幅改修）
- spec-review-agent（変更なし）
- verification-agent（統合検証にスコープ変更）

### 新規
- カスタムスキーマ `longrun-tdd`（TDD + HARD-GATE + 自律判断ルール）
- config.yaml動的生成（changeごとのスキル注入）
- Git Worktree管理（changeごとの隔離実装）
- change並列/直列制御（依存グラフベース）

## 前提条件

- OpenSpec CLI v1.2.0+（`npm install -g @fission-ai/openspec`）
- Git（worktree機能を使用）
