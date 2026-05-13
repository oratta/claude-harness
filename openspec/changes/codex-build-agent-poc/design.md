# Design: Codex Build Agent PoC

## Goals
- Codex CLI 0.130.0 と既存 codex プラグインを使い、longrun-builder 相当の TDD 実装を委譲できるかを実証する
- Codex 利用不可時に Opus 経由（longrun-builder Agent）へ自動フォールバックする経路を擬似検証する
- 上記検証結果を Go / Conditional Go / No-Go の 3 分岐で記録し、Phase 2 本実装 plan の起票判断を機械的に行う

## Non-Goals
- `longrun-builder-codex` Agent の新規作成（Phase 2 のスコープ）
- `longrun-orchestrator` SKILL の改変（Phase 2 のスコープ）
- Codex CLI / openai-codex プラグインへのコントリビューション
- 複数モデル A/B 比較（PoC では「5.5 Pro 相当」1 モデルで判定）
- 大規模 sample（PoC は最小単位の TS 関数 1 個 + Vitest テスト 1〜2 件で十分）

## Architecture

```
_longruns/2026-05-13_codex-build-agent-eval/
├── plan.md                        # 既存（longrun-plan の出力）
├── checkpoint.md                  # 既存（orchestrator）
├── decisions.md                   # 既存（orchestrator）
├── verification-guide.md          # NEW（Build 前半で生成）
├── prompts.md                     # NEW（Codex への TDD プロンプト + 反復ログ）
├── sandbox/                       # NEW（TS + Vitest プロジェクト）
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   └── greet.ts               # PoC 実装対象（最小）
│   └── tests/
│       └── greet.test.ts          # Vitest テスト
├── scripts/
│   ├── run-poc.sh                 # NEW（Codex 経由 TDD 実行 + 事前/事後ガード）
│   ├── run-fallback.sh            # NEW（擬似 Codex ダウン → Opus 経由）
│   ├── measure-tdd-fidelity.sh    # NEW（git log 走査 → テスト無し率算出）
│   └── tests/
│       └── run-poc.bats           # NEW（ガード自体のテスト）
├── evaluation.md                  # NEW（Verify 後半で記入）
└── summary.md                     # NEW（Feedback で生成）
```

## Decisions

### Decision: PoC 対象は最小単位の TS 関数
- **日時**: 2026-05-13
- **コンテキスト**: PoC で Codex に投げる sample change の規模をどうするか
- **選択肢**: A: 最小単位（1 関数 + 1〜2 テスト） / B: 中規模（複数ファイル + モック） / C: 既存 plugin の一部抜粋
- **決定**: A
- **理由**: 規模が大きいと「Codex の能力」と「sample 自体の難しさ」が混線する。PoC は能力評価が主目的なので最小単位が適切（plan.md 意思決定ガイドラインの「YAGNI」と整合）
- **リスク**: Codex の真の限界は測れない → Phase 2 plan で「より複雑な sample」を引き継ぎリスクに記載

### Decision: フォールバック検証は Opus 直接呼び出しではなく擬似化
- **日時**: 2026-05-13
- **コンテキスト**: `run-fallback.sh` で「Opus 経由再実行」をどう実装するか
- **選択肢**:
  - A: 実際に longrun-builder Agent を起動（PoC 内で Agent ツール起動は不可能）
  - B: `claude` CLI が手元にあれば呼ぶ
  - C: 擬似化 — fallback が呼ばれたことをログに記録し、Vitest を直接実行して PASS を確認
- **決定**: C
- **理由**: PoC で検証したいのは「Codex 失敗を検出して別経路に切り替わる」というロジックの動作。Opus 側の実装能力は既知（既存 longrun-builder で日常的に動いている）なので再検証不要
- **リスク**: Opus 側の実装速度は再計測できない → 既存 longrun 履歴から参考時間を引き継ぎ事項に記録

### Decision: Codex CLI 呼び出しは `codex exec` 直接ではなく codex-companion 経由
- **日時**: 2026-05-13
- **コンテキスト**: `run-poc.sh` から Codex を呼ぶ手段
- **選択肢**:
  - A: `codex exec -m <model> "<prompt>"` を直接呼ぶ
  - B: `node ${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs task` 経由
- **決定**: B（既存 codex プラグインの contract に沿う）
- **理由**: codex-cli-runtime SKILL.md に契約が定義されており、Phase 2 で `longrun-builder-codex` Agent を作る際もこの helper を使う想定。PoC で同じ経路を踏むことで Phase 2 への学びが直結する
- **リスク**: codex-companion.mjs の動作仕様が未確定の場合がある → PoC 中に挙動を観察し evaluation.md に記録

### Decision: TDD 忠実度判定は機械的アルゴリズムのみ
- **日時**: 2026-05-13
- **コンテキスト**: 受け入れ条件 #9 の判定方法
- **選択肢**: A: 機械的（git show --name-only による分類） / B: 人間目視 / C: 両方併用
- **決定**: A
- **理由**: longrun-reviewer 指摘6 への対応。再現性を担保し、Go 判定の客観性を確保
- **リスク**: 「テストファイルなのに実は実装も書いている」ような細かいケースは検出できない → Phase 2 リスクに記載
