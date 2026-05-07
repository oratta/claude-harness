# Longrun Plugin v5.2

Claude Code 自律実行システム。Anthropic の [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) の知見を反映した設計。

## v5.2 変更点

- **MVP モード（`--mode=mvp`）を `/longrun:plan` に追加**。詳細は下記「MVP モード」セクション参照。
- フルモードの既存挙動は完全維持（regression なし）。`--mode=mvp` フラグなし or `--mode=full` の場合は従来通り Step 1〜8 を実行する。
- `plugins/longrun/templates/plan-template-mvp.md`（軽量テンプレ）を新規追加。
- `/longrun:archive` に `<!-- mvp-mode -->` マーカー判定を追加。MVP モード plan.md は OpenSpec change archive をスキップしてランディレクトリのみアーカイブ。
- `plugin.json` と `longrun-plan` SKILL.md frontmatter の version を 5.2.0 に同期 bump（プラグインキャッシュ無効化）。

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

## MVP モード（`--mode=mvp`）

`/longrun:plan` に追加された軽量フロー。**短時間で人間が手で MVP を実装する**ケース向けの汎用機能で、特定プロジェクトに依存しない。

### 起動方法

```
/longrun:plan --mode=mvp <ブレインダンプ or テーマ>
/lr:p --mode=mvp <ブレインダンプ or テーマ>   # 短縮形（lr プラグインがある場合）
```

`--mode` フラグなし、または `--mode=full` の場合は従来のフルモードで起動する。

### フルモードとの違い

| 観点 | フルモード | MVP モード |
|---|---|---|
| Build Contract レビュー | 必須（`longrun-reviewer`） | **スキップ** |
| TDD 強制 | 必須（Red → Green → Refactor） | **スキップ**（人間実装前提） |
| Verifier 自動起動 | 必須（4 軸定量評価） | **スキップ**（人間がその場で確認） |
| リサーチ | 任意 | **並列リサーチ subagent×1**（類似サービス + 実装パターンを 1 レポート 2 セクション） |
| Plan Review | `longrun-reviewer` 単体 | `longrun-mvp-plan-reviewer` + `longrun-mvp-bestpractice-reviewer` を**並列起動** |
| OpenSpec 自動連携 | あり（backlog 照合 / change 自動生成 / archive 時 spec コピー） | **なし**（plan.md 先頭に `<!-- mvp-mode -->` マーカー、`/longrun:archive` は OpenSpec を触らない） |
| テンプレート | `templates/plan-template.md`（フル版） | `templates/plan-template-mvp.md`（軽量版） |

### いつ使うか

- 短時間で人間が手で MVP を実装するケース（数十分〜数時間スケール）
- 自律実行の重装備（Build Contract / TDD / Verifier）が過剰に感じるとき
- まず動くものを作って人間がレビューしたいとき

逆に、自動実装パイプラインに乗せたい / 仕様 driven で長期保守したい場合はフルモードを使うこと。

### アーカイブ

```
/longrun:archive _longruns/<dir>/
```

`plan.md` 先頭の `<!-- mvp-mode -->` マーカーを自動検知し、OpenSpec change の archive をスキップしてランディレクトリのみ `_longruns/_archive/` に移動する。フルモード plan.md（マーカーなし）は従来通り OpenSpec change と一緒に archive される。
