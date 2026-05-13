# Phase 2 Plan Draft — Codex Build Agent Integration

> **使い方**: 次セッションで `/longrun:plan _longruns/2026-05-13_codex-build-agent-eval/phase2-draft.md` を起動すると、本ドキュメントを brain dump として読み込んで Phase 2 plan.md が生成される想定。
> 
> Phase 1 PoC の決定的成果（`evaluation.md` Conditional Go + 9 件のリスク + ★最重要発見）と合わせて読むこと。

## Phase 2 のゴール

longrun の Build フェーズ Agent (`longrun-builder`, Opus) と並列に運用できる **`longrun-builder-codex` Agent を新設**し、orchestrator が Codex サブスク利用可否で動的に分岐する仕組みを実装する。Codex 経路失敗時は既存の `longrun-builder` (Opus) に **実行失敗検出** でフォールバックする。

Phase 1 PoC で得られた Conditional Go 判定を、本実装で **Go 相当の品質**に引き上げる:

- Codex commit を **親 repo に乗せる** 方式を確立
- prompt から **`--allow-empty` noop test 許容を撤廃** し、TDD 規律を実体として強制
- 同一 change で **Codex vs Opus の実時間・実コスト比較** を取得（n ≥ 2）

## Phase 1 からの ★最重要引き継ぎ事項

PoC で発見した致命的挙動: **Codex は `--skip-git-repo-check + -C sandbox` で独自 `gitmeta/` に commit を閉じ込める**。親 repo の `git log` に Codex の commit が一切現れない。

Phase 2 plan の **最初のタスク**として以下 3 案のうちどれかを選択 + PoC 確認する:

| 案 | 内容 | Pros | Cons |
|---|------|------|------|
| **A** | `codex exec -C <repo-root>` で親 repo を作業 root に指定し、Codex に sandbox path のみ書き換えさせる | gitmeta が発生しない（親 repo の git を使う） | Codex が sandbox 外を触る安全性低下、sandbox 境界の強制が prompt 依存に |
| **B** | gitmeta/ を `git format-patch` → 親 repo で `git am` で取り込む | 案 A より安全（sandbox 内に閉じる） | 統合スクリプト追加で複雑度増、`gitmeta` 命名が Codex 内部仕様依存 |
| **C** | `codex apply` サブコマンドで Codex の diff を親 repo に適用 | Codex 公式機能 | 0.130.0 の `codex apply` がどの程度安定か未調査 |

PoC のリスクから言えば **A が本命**だが、安全性とのトレードオフを最初の 1〜2 時間で実証する。

## Changes 分解の素案

### change-1: Codex commit を親 repo に乗せる方式の確立
- **スコープ**: 案 A/B/C を一通り実証し、採用案を spec として固定
- **使用スキル**: なし
- **生成物**:
  - `plugins/longrun/scripts/codex-commit-integration.sh`（または codex-rescue 経由の wrapper）
  - 実証ログを Phase 2 run dir の `integration-tests.md` に残す

### change-2: prompt 規律の見直し
- **スコープ**: `--allow-empty` noop test 許容を Phase 1 prompts.md V2 から撤廃。「既存テストで spec を満たす場合は **commit を打たず Step 2 に直行**」へ書き換え。Codex が「テスト無し commit」を打った場合は detect & fail
- **生成物**:
  - `plugins/longrun/agents/longrun-builder-codex.md` の prompt セクション
  - prompt 規律違反検出スクリプト（`measure-tdd-fidelity.sh` の拡張版、commit 単位で「テスト無し」を即 fail にする option）

### change-3: longrun-builder-codex Agent 新設
- **スコープ**:
  - 新規 Agent ファイル `plugins/longrun/agents/longrun-builder-codex.md`（model: 不要、Bash で codex-companion 経由）
  - 既存 `longrun-builder` と同等の `tools: Read, Write, Edit, Bash, Glob, Grep` 構成 + `permissionMode: bypassPermissions`
  - 各 task の TDD ループを Codex に委譲、Claude 側は verification-guide.md 更新と commit 規律検証のみ

### change-4: orchestrator 分岐ロジック
- **スコープ**: `plugins/longrun/skills/longrun-orchestrator/SKILL.md` の Build フェーズに「Codex 利用可なら builder-codex、不可なら builder」分岐を追加
- **フォールバック検出**: 実行失敗（exit code / stderr）で判定（Phase 1 D-002）
- **生成物**:
  - SKILL.md 変更
  - orchestrator 分岐ロジック自体の Bats テスト（PoC 実装の resampling）

### change-5: 比較計測ハーネス
- **スコープ**: 同一 sample change を Codex / Opus 両方に走らせる比較ハーネス。実時間・トークン・忠実度を記録
- **生成物**:
  - `plugins/longrun/scripts/compare-builders.sh`
  - 比較レポート `_longruns/<date>_phase2-codex-builder/comparison.md`

## 受け入れ条件の素案

**必須条件**:
1. [ ] 全 change の OpenSpec 仕様作成・レビュー済み
2. [ ] 全テスト PASS
3. [ ] ビルドエラーなし
4. [ ] 既存 `longrun-builder` の動作不変（regression テスト PASS）

**機能固有条件**:
5. [ ] change-1: Codex の commit が親 repo の `git log` に現れる（PoC ★最重要引き継ぎを解決）
6. [ ] change-2: Codex が `--allow-empty` で noop test commit を打った場合に検出して fail（Phase 1 で観測した anti-pattern の阻止）
7. [ ] change-3: `longrun-builder-codex` Agent が単一 OpenSpec change を TDD で完走できる
8. [ ] change-4: Codex 認証無効状態（fake codex で再現）で orchestrator が builder-codex を起動せず builder にフォールバックする
9. [ ] change-5: 同一 sample change を Codex / Opus 両方で走らせ、**実時間・実トークン・no-test-rate** を `comparison.md` に記録
10. [ ] **Phase 1 PoC のリスク 4 件（タイムアウト / 部分成功 / quota / NW vs 認証）すべてに Phase 2 実装で対処済み**
11. [ ] `plugins/codex/` への変更なし（codex プラグインは upstream に追従）

## 技術要件

- スタック: Bash, Node.js（codex-companion 経由）, Claude Code Agent 定義（YAML frontmatter + Markdown）
- テストフレームワーク: Bats（Phase 1 と同じ）、対象スクリプトの shellcheck
- 制約: 
  - `plugins/codex/` を変更しない
  - 既存 `longrun-builder` の挙動を変えない（並列共存）
  - Codex サブスク使用枠を意識（並列実行数の上限を Phase 1 で観測した値を spec に固定）

## 推奨フロー

1. **Spike 1（半日）**: change-1 の案 A/B/C を順に試して採用案決定
2. **Build Phase**:
   - change-2 → change-3 → change-4 → change-5 の順（依存あり）
   - change-1 採用案次第で並列化の余地あり
3. **Verify**: longrun-verifier + 比較計測ハーネスでの実測
4. **Feedback**: 比較レポート (`comparison.md`) を見てユーザーが Go/Stay 判断

## 関連参照

- Phase 1 evaluation: `_longruns/2026-05-13_codex-build-agent-eval/evaluation.md`
- Phase 1 prompts.md V2: `_longruns/2026-05-13_codex-build-agent-eval/prompts.md`
- Phase 1 decisions（17 件）: `_longruns/2026-05-13_codex-build-agent-eval/decisions.md`
- Codex プラグイン参照（変更禁止）: `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/`
- 既存 builder（並列共存対象）: `plugins/longrun/agents/longrun-builder.md`
- 既存 orchestrator（分岐ロジック追加対象）: `plugins/longrun/skills/longrun-orchestrator/SKILL.md`

## Phase 1 で生成した素材で再利用可能なもの

| 素材 | 流用先 |
|------|--------|
| `scripts/run-poc.sh` | change-3 の builder-codex Agent 内部に取り込み（事前/事後ガード機構） |
| `scripts/run-fallback.sh` | change-4 の orchestrator 分岐ロジックのテスト材料 |
| `scripts/measure-tdd-fidelity.sh` | change-5 の比較計測ハーネスに `--no-merges` 修正版を取り込み |
| `scripts/tests/*.bats` | change-3/4 の Bats テストの雛形 |
| `sandbox/greet` | change-5 の比較ハーネスの最小 sample（追加で中規模 sample を作る） |
| `prompts.md V2` | change-2 で `--allow-empty` 撤廃版に書き換え |

## 個人的優先度（私の評価）

- 案 A 試行と change-2 (prompt 規律) は **最優先**（Phase 1 の本質的 shortfall を解決）
- change-5 (比較計測) は Phase 2 plan のレビュー時点で最も重要視されると思う。「結局 Codex の方が速い？」の問いに直接答える材料が今ない
- change-3/4 (Agent + orchestrator) は規模的に **change-1 と並列**で進められるはずだが、change-1 採用案の挙動で勝手が変わるので連番で書いた
