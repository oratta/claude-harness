# Longrun Plugin

Claude Code 自律実行システム。Anthropic の [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) の知見を反映した設計。

版履歴は [CHANGELOG.md](CHANGELOG.md) を参照。

## コマンド

| コマンド | 短縮 | 説明 |
|---------|------|------|
| `/longrun:plan` | `/lr:p` | plan.md を対話的に作成（フルモード） |
| `/longrun:mvp` | `/lr:m` | 軽量 MVP plan.md を対話的に作成（人間実装向け） |
| `/longrun:exec` | `/lr:e` | Workflow を生成・起動して自律実行を開始 |
| `/longrun:archive` | `/lr:a` | 完了した実行をアーカイブ |
| `/longrun:feedback` | `/lr:f` | フィードバックを分類・実行 |

進捗確認はネイティブの **`/workflows` ライブビュー** を使う（旧 `/longrun:status` `/lr:s` は v6.0 で廃止）。意思決定は `_longruns/<run>/decisions.md` を直接 Read する（旧 `/longrun:decisions` `/lr:d` は v6.0 で廃止）。

## アーキテクチャ

```
/longrun:exec → Workflow スクリプト生成・起動（exec コマンド + templates/workflow/）
  ├── workflow #1 (Review)        ← longrun-reviewer agent で Build Contract レビュー
  │     ↓ メインループに戻る: APPROVE は decisions.md に記録して自動続行、
  │       REQUEST_CHANGES のみ AskUserQuestion で停止（v6.4）
  └── workflow #2 (Build→Verify)  ← change ごとに longrun-builder で TDD 実装
        Verify ループ（上限3周 + budget ガード） ← longrun-verifier の 4 軸スコア
        ↓ 完了レポートを出してターン終了（ブロック待機しない）。
          フィードバックは /lr:f、アーカイブは /lr:a で再開（v6.4）

Skills (対話的・メインセッションで実行):
  longrun-plan      ← plan.md 作成
  longrun-feedback  ← フィードバック Tier 分類

Agents (自律実行・別コンテキスト。Workflow から agentType で参照):
  longrun-builder           ← TDD 実装（builder-report schema）
  longrun-verifier          ← 4軸定量評価・静的（verifier-score schema）
  longrun-browser-verifier  ← ブラウザ動作検証
  longrun-reviewer          ← Build Contract + Spec Review（reviewer-verdict schema）
```

成果物の StructuredOutput 契約は `schemas/builder-report.schema.json` / `verifier-score.schema.json` / `reviewer-verdict.schema.json` に外部化されており、生成 Workflow スクリプトが `agent(prompt, {schema})` で機構的に強制する。

## 命名規則

Skill と Agent の役割を名前で識別可能にしている。命名違反は Claude が Skill/Agent 種別を誤推論して起動失敗（`Agent type ... not found`）の原因となる。

| 種別 | 命名パターン | 例 |
|------|-------------|----|
| **Skill** | 動詞または名詞単独 | `longrun-plan`, `longrun-mvp-plan`, `longrun-feedback` |
| **Agent** | 役割名（`-er` / `-or` 終わり） | `longrun-builder`, `longrun-reviewer`, `longrun-verifier`, `longrun-browser-verifier` |

新規追加時は本ルールに従うこと。違反すると `/longrun:plan` 系コマンドの起動経路で再び誤起動エラーが発生する。

## MVP プランモード（`/longrun:mvp`）

独立スキル `longrun-mvp-plan` による軽量フロー。**短時間で人間が手で MVP を実装する**ケース向けの汎用機能で、特定のプロジェクトに依存しない（どのプロジェクトからでも呼び出せる）。

### 起動方法

```
/longrun:mvp <ブレインダンプ or テーマ>
/lr:m <ブレインダンプ or テーマ>   # 短縮形（lr プラグインがある場合）
```

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

## OpenSpec 縮退モード（v5.3 で追加）

OpenSpec CLI を前提にしない（または使わない）環境でも longrun の Review → Build → Verify → Feedback → Archive サイクルを完走させるための一級の動作モード。

### 発動条件

`/lr:e` 起動直後の **Step 0（preflight）** で `scripts/openspec-preflight.sh` を実行し、以下を判定する:

| preflight 出力 | 条件 | Step 0 の動作（v6.4） |
|----------------|------|---------------|
| `OK`      | CLI 解決可 かつ `openspec/` 存在 | **質問なしで通常モード即続行**（OpenSpec を使わない opt-out は `/lr:e --degraded` フラグ） |
| `NO_CLI`  | `openspec` が PATH にも npx にも解決できない | AskUserQuestion: 縮退モードで実行 / 中断してセットアップ |
| `NO_INIT` | CLI はあるが `openspec/` が無い | AskUserQuestion: init して通常続行 / 縮退モード / 中断 |

検出は `command -v openspec` **または** `npx --no-install openspec` の OR 条件（確定値とエビデンスは `docs/openspec-cli-verification.md`）。`--degraded` フラグまたは NO_CLI/NO_INIT 時の選択で縮退が確定すると `_longruns/<run>/.degraded-mode` マーカーが作成される。

### 成果物パス（縮退時）

縮退モードでは `openspec/` 配下に一切書き込まず、すべて run ディレクトリ内に自己完結する:

```
_longruns/<run>/
├── .degraded-mode                    # 縮退マーカー（exec Step 0 で作成）
├── plan.md
├── specs/<change-name>/
│   ├── proposal.md                   # openspec new change の代替（自己完結生成）
│   └── tasks.md                      # チェックボックス形式（- [ ] X.Y）で進捗管理
├── verification-guide.md             # specs/ の WHEN/THEN から生成（通常モードと同形式）
└── backlog.md                        # feedback Tier 3 のフォールバック記録先
```

- Archive は OpenSpec change の移動をスキップし、ランディレクトリのみ `_longruns/_archive/` へ移動（spec 類は内包されるため一緒に保全される）。判定は `.degraded-mode` マーカーで行い、MVP マーカー（`<!-- mvp-mode -->`）より優先する。
- feedback の Tier 3（new change）は `openspec/backlog.md` ではなく `_longruns/<run>/backlog.md` に記録される。

### 既知の制限

- ~~`/longrun:status` は縮退モードに非対応~~ → **v6.0.0 で `/longrun:status` 自体が削除されたため本制限は消滅**。縮退 run を含め進捗確認はネイティブの `/workflows` ライブビューで行う（5.3.0 時点では status に縮退分岐を実装していなかったが、change-2 で status を廃止したため投資不要だった判断が結実した）。
- 縮退モードでは `openspec validate` による構造検証が効かない。tasks のチェックボックス形式・spec の WHEN/THEN 形式はテンプレートで担保し、形式逸脱は Verify フェーズのレビューで補完する。
- 縮退 run から OpenSpec あり構成への「昇格」変換は未実装（backlog 残置）。

### 回帰（通常モードへの影響）

既存の openspec/ あり repo で Step 0 が `OK` を返した場合、実行フロー・成果物のパス・形式は 5.2.0 と完全に同一。v6.4 以降、Step 0 で増えるユーザー対話は**ゼロ**（旧: 動作モード確認の 1 問。ノンストップ実行ポリシーで廃止）。`.degraded-mode` マーカーは通常モードでは作成されない。
