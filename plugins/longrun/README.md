# Longrun Plugin v5.1

Claude Code 自律実行システム。Anthropic の [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) の知見を反映した設計。

## v5.1 変更点

- **Skill 命名統一**: `longrun-planner` → `longrun-plan` にリネーム（命名規則 §参照）。`/longrun:plan` 経由で Agent 誤起動が発生するエラー（`Agent type 'longrun:longrun-planner' not found`）を解消。
- `commands/plan.md` を Skill tool 明示呼び出しに変更（Agent tool 禁止を明記）
- `longrun-orchestrator` の Build Contract レビュー段階に **バイアス緩和ガード** を追加。reviewer の指摘を仮説として扱い、根拠（spec違反・契約違反・事実誤認）の有無で採否を判定するルールを固定文として埋め込み。Opus 系の self-preference bias と過剰受容バイアスへの対処。

## v5.0 変更点

- **リネーム**: `run` → `longrun` に戻した（一般名詞との衝突回避）
- `_runs/` → `_longruns/`、エージェント/スキル名も `longrun-*` に統一

## v4.0 変更点（旧 longrun → run 時代）

- `instruction.md` → `plan.md`、`progress.md` → `checkpoint.md`
- **Skill/Agent正しい使い分け**: 対話型 = Skill、自律実行 = Agent
- **フェーズ簡素化**: 8フェーズ → 5フェーズ（Plan → Build → Verify → Feedback → Archive）
- **Build Contract**: 実装前に longrun-reviewer がレビュー
- **4軸定量評価**: 機能性/品質/完成度/UX にハードしきい値
- **コンテキストリセット**: フェーズ間で Agent を分離し、checkpoint.md でハンドオフ
- **Context Anxiety 対策**: 完了条件チェックリストで早期終了を防止
- **spec-review-agent を longrun-reviewer に統合**

## コマンド

| コマンド | 短縮 | 説明 |
|---------|------|------|
| `/longrun:plan` | `/lr:p` | plan.md を対話的に作成 |
| `/longrun:exec` | `/lr:e` | 自律実行を開始 |
| `/longrun:status` | `/lr:s` | 進捗状況を確認 |
| `/longrun:decisions` | `/lr:d` | 意思決定一覧を確認 |
| `/longrun:archive` | `/lr:a` | 完了した実行をアーカイブ |
| `/longrun:feedback` | `/lr:f` | フィードバックを分類・実行 |

## アーキテクチャ

```
Skills (対話的・メインセッションで実行):
  longrun-plan          ← plan.md 作成
  longrun-orchestrator  ← 全体指揮（Plan→Build→Verify→Feedback→Archive）
  longrun-feedback      ← フィードバック Tier 分類

Agents (自律実行・別コンテキスト):
  longrun-builder           ← TDD 実装
  longrun-verifier          ← 4軸定量評価（静的）
  longrun-browser-verifier  ← ブラウザ動作検証
  longrun-reviewer          ← Build Contract + Spec Review
```

## 命名規則

Skill と Agent の役割を名前で識別可能にしている。命名違反は Claude が Skill/Agent 種別を誤推論して起動失敗（`Agent type ... not found`）の原因となる。

| 種別 | 命名パターン | 例 |
|------|-------------|----|
| **Skill** | 動詞または名詞単独 | `longrun-plan`, `longrun-orchestrator`, `longrun-feedback` |
| **Agent** | 役割名（`-er` / `-or` 終わり） | `longrun-builder`, `longrun-reviewer`, `longrun-verifier`, `longrun-browser-verifier` |

新規追加時は本ルールに従うこと。違反すると `/longrun:plan` 系コマンドの起動経路で再び誤起動エラーが発生する。
