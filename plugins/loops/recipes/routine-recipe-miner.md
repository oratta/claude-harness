# レシピ: routine-recipe-miner

> プロアクティブ合成ルーチン（change-4 proactive-routines）の**メタループ**。
> ハーネス自身を実使用ログで改善し続ける。直近 7 日のセッション jsonl をサブエージェントで圧縮解析し、
> ループ化候補を抽出 → 規約検査を通した提案を **Draft PR** で出す（自動 merge 禁止・採否は人間）。
> 規約は `plugins/loops/references/recipe-format.md`、Bad Loop 検査は `references/loop-types.md`、
> State 規約は `references/state-convention.md`、ログ圧縮は daily-report の llm-log-compactor（jq パターン）を参照。

## ループ型

**プロアクティブ**（**メタループ**）。4 分類: ターンベース / ゴールベース / タイムベース / プロアクティブ のうち
プロアクティブ。スケジュール（または手動）がトリガーで人間不在で回る。対象がハーネス自身（レシピ棚）なので
「メタループ」と呼ぶ。「プロンプト自体を手放す」（`references/loop-types.md`）。

## 目的

レシピ棚の成長を人手に依存させない。実使用ログ（何を繰り返し頼んでいるか）を材料に、ループ化・/goal 化・
/schedule 化の候補や既存レシピの実測チューニングを見つけ、規約を満たす提案だけを Draft PR で人間に差し出す。
「ログをもとに定期的にループレシピを作成・更新するループ」。

## 起動コマンド

コピペ可能なネイティブプリミティブ文字列。**スケジューラへの登録手順は書かない（呼び出し側の責務・スコープ外）**。
ここで宣言するのは発火時プロンプト・推奨頻度・停止基準・実行環境の制約まで。

```
/goal mine loop recipes from recent usage. Spawn a subagent to analyze the last 7 days of session jsonl under ~/.claude/projects/ using the llm-log-compactor jq pattern, and return only a candidate list (never load raw logs into the main context). From the candidates, generate at most 3 new/updated recipe proposals, each of which MUST pass the convention check (stop-criteria required + Bad Loop check). Open a Draft PR to this marketplace repo for the passing proposals (never auto-merge; a human decides adoption). Record proposed / deferred-with-reason / carried-over candidates in loops/state/routine-recipe-miner.state.md. If there are zero candidates, finish normally as "no proposal". Stop after this single cycle.
```

- 起動コマンドはネイティブプリミティブ `/goal`（手動起動で 1 サイクル）+ サブエージェント。**独自 CLI・常駐 driver は作らない（MUST NOT）**。
- **推奨頻度は週 1 想定**。ただし**定期実行への登録・実行方法の選択は呼び出し側の責務でスコープ外**（別セッションの Pikke プロセス整理が担う）。

### 1 サイクルの手順（発火時プロンプトの中身）

1. **discovery（サブエージェント隔離）**: 直近 7 日のセッション jsonl（`~/.claude/projects/` 配下）の解析を
   **サブエージェントに隔離**して実行する。daily-report の **llm-log-compactor の jq パターン**を流用して圧縮解析し、
   **候補リスト（抽出結果）のみをメインセッションに返す**。**生ログをメインセッションのコンテキストに載せない（MUST NOT）**。
   抽出する 4 種の候補:
   - (a) **同型依頼の 3 回以上の反復** = **ループ化候補**
   - (b) **修正→テスト→修正の長い往復** = **/goal 化候補**
   - (c) **定時性のある依頼** = **/schedule 化候補**
   - (d) **既存レシピの実行痕跡** = 停止基準・頻度の**実測チューニング候補**
2. **生成**: 候補から新規案 / 更新 diff を作る。**1 サイクル最大 3 件**（提案上限）。
   各提案は **停止基準必須** + **Bad Loop 検査**（停止基準の欠如 / 検証なき成功宣告 / 報酬ハッキング余地 / 過剰な実行頻度）の
   規約検査を必ず通す。**検査を通らない提案は Draft PR に含めず、見送り理由を state に記録する**。
3. **出力**: 検査を通った提案を、この marketplace リポジトリへの **Draft PR** として出力する。
   **自動 merge 禁止**。レシピの採否は**人間**が判断する（merge・close・force 系操作は実行しない）。
4. **persistence**: `loops/state/routine-recipe-miner.state.md` に **提案済み / 見送り理由 / 繰り越し候補**の 3 区分で記録する。
   discovery で拾ったが処理しなかった候補は繰り越しに記録（silent drop 禁止）。**候補ゼロなら「提案なし」で正常終了**する。

## 停止基準

- **1 サイクル完了で停止**: discovery → 生成（最大 3 件）→ 出力（Draft PR）→ persistence まで進めたら 1 サイクル終了。
- **提案上限**: 1 サイクル**最大 3 件**。超過分は繰り越しに記録して次サイクルへ。
- **候補ゼロ**: 候補がゼロのサイクルは「**提案なし**」として**正常終了**する（異常系ではない）。
- 規約検査を通らない提案は Draft PR に含めず見送る（無理に提案を作らない）。

## 前提

- **ローカル実行必須**: `~/.claude/projects/` 配下のセッション **jsonl** を読むため、このループは**ローカル実行が必須**である
  （クラウド実行では jsonl にアクセスできない）。これは**実行環境の制約**として宣言する。
- **定期実行への登録・実行方法の選択は呼び出し側の責務でありスコープ外**（cron 設定・launchd・`claude -p` 配線は本レシピに含めない）。
- daily-report の **llm-log-compactor**（jq パイプライン）が参照できること。
- `gh` CLI が使え、この marketplace リポジトリへ Draft PR を作成できること。
- State 規約: `plugins/loops/references/state-convention.md`。規約検査: `references/recipe-format.md` + `references/loop-types.md`（Bad Loop 検査）。

## コスト注意

公式トークン管理の該当項目:
- **実行頻度を必要最小限にする**: 推奨は週 1。毎日回さない。
- **決定論的作業のスクリプト化**: jsonl の圧縮解析は llm-log-compactor の **jq パターン**（決定論的）に落とし、生ログを LLM に読ませない。
- **サブエージェント隔離**: ログ解析をサブエージェントに隔離し、抽出結果（候補リスト）のみをメインに返すことでメインのコンテキスト汚染を防ぐ。
- **大規模実行前のパイロット実行**: 初回は手動 1 サイクルで回し、候補抽出と規約検査が意図通り動くことを確認する。
- ループはチャットの約 4 倍、サブエージェントを含むマルチエージェント構成は約 15 倍のトークンを消費する点に留意する。

## エスカレーション

**外向きアクションは非破壊デフォルト（Draft PR まで）**。以下は行わず、必要なら人間へエスカレーションする:

- **自動 merge しない**（merge 禁止）。レシピの採否は**人間**が判断する。
- **PR を close しない・force push しない**（close / force 系禁止）。
- 規約検査（停止基準必須・Bad Loop 検査）を通らない提案は Draft PR に含めず、**見送り**として state に理由記録する。
- 候補の解釈が曖昧・提案の妥当性判断が必要な場合は Draft PR の説明にその旨を書いて人間へ委ねる。
- 解析自体が失敗した場合（jsonl 読めない等）は「候補ゼロ（提案なし）の正常終了」とは区別し、異常系として人間へエスカレーションする。
