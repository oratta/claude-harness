# レシピ: routine-backlog-triage

> プロアクティブ合成ルーチン（change-4 proactive-routines）。公式記事「Getting started with loops」の
> プロアクティブ合成例（`/schedule ... /goal: don't stop until every ... is triaged, actioned, and responded to.`）を
> このリポジトリの backlog 消化（`openspec/backlog.md` + open issues → Draft PR）に適用した版。
> 規約は `plugins/loops/references/recipe-format.md`、State 規約は `plugins/loops/references/state-convention.md` を参照。

## ループ型

**プロアクティブ**（4 分類: ターンベース / ゴールベース / タイムベース / プロアクティブ のうち）。
スケジュール（またはイベント）がトリガーで、人間不在で回る定期業務。ここでは「プロンプト自体を手放す」
（`references/loop-types.md` の選択フレームワーク）。/schedule + /goal + worktree 隔離 + 第二エージェントレビューの合成。

## 目的

backlog（`openspec/backlog.md`）と open issues に溜まった着手可能タスクを、人間が毎回指示しなくても
1 サイクルずつ消化する。第一エージェントが worktree で実装し、第二エージェントがレビューし、**Draft PR まで**進める。
マージ判断だけを人間に残す。「人間が毎回プロンプトする」から「ループが回し、人間は例外だけ処理する」への移行。

## 起動コマンド

コピペ可能なネイティブプリミティブ文字列（`<longrun-dir>` 等は環境に置換）。スケジューラへの登録手順は書かない
（**呼び出し側の責務・スコープ外**）。ここで宣言するのは発火時プロンプトと推奨頻度・停止基準・実行環境の制約まで。

```
/schedule daily: /goal triage the backlog. Read openspec/backlog.md and open GitHub issues, pick at most 2 actionable tasks this cycle, implement each in an isolated worktree, run a second-agent /code-review, and open a Draft PR for each. Do not stop until every task selected this cycle has reached either a Draft PR or a freeze record in loops/state/routine-backlog-triage.state.md. Never merge, close, or force-push; escalate those to a human.
```

- 起動コマンドはネイティブプリミティブ `/schedule` + `/goal` のみ。worktree 隔離は既存 `plugins/worktree/`（`/wt-setup --with-pr`）、
  レビューは `/code-review` 相当の第二エージェントを使う。**独自 CLI やラッパースクリプト・常駐 driver は作らない（MUST NOT）**。
- **推奨頻度のデフォルトは日次**（保守的）。上記は `daily`。
  - **頻度の変更方法**: コマンド文字列先頭の `daily` を書き換える（例: `weekly`）。頻度は上げすぎない（頻度最小化）。

### 1 サイクルの手順（発火時プロンプトの中身）

1. **discovery**: `openspec/backlog.md` と open issues（`gh issue list`）から着手可能タスクを列挙し、
   このサイクルで処理するのは **最大 2 件**（処理数上限。上限なしの全件処理は禁止）。
2. **隔離実装**: 選定タスクごとに worktree を切り（`/wt-setup --with-pr`）、第一エージェントが実装する。
3. **第二エージェントレビュー**: `/code-review` 相当の第二エージェントで敵対的レビューを行う（公式品質プラクティス）。
4. **Draft PR まで**: 各タスクを **Draft PR** として push する。マージ・Ready 化はしない。
5. **state 更新**: `loops/state/routine-backlog-triage.state.md` を **処理済み / 繰り越し / 引き継ぎ待ち** の 3 区分で更新する。
   discovery で拾ったが今サイクルで処理しなかったタスクは **繰り越し**として必ず記録する（silent drop 禁止）。

## 停止基準

- **定量ゴール（/goal）**: 「このサイクルで**選定したタスクが全て Draft PR または凍結記録に到達するまで**」停止しない。
  選定分が全て Draft PR 化されるか凍結記録に落ちた時点で 1 サイクル完了。
- **2 連続失敗の凍結**: 同一タスクが **2 連続**で失敗した場合、そのタスクを**凍結**（当該サイクル以降の自動リトライ対象から除外）し、
  state の引き継ぎ待ちに記録して**人間へエスカレーション**する。**無限リトライは禁止**。
- **処理数上限**: 1 サイクル最大 2 件（discovery の上限）。残りは繰り越し。
- 上記のいずれか（全選定タスクの Draft PR/凍結到達・2 連続失敗の凍結・処理数上限到達）で必ずサイクルが終了する。

## 前提

- `gh` CLI が使え、issue 一覧取得と Draft PR 作成ができること。
- `openspec/backlog.md` が存在すること（discovery の入力）。
- `plugins/worktree/`（`/wt-setup --with-pr`）による worktree 隔離運用。
- 第二エージェントレビュー（`/code-review` 相当）が使えること。
- State 規約: `plugins/loops/references/state-convention.md`（`loops/state/routine-backlog-triage.state.md` の 4 節形式）。
- このリポジトリの **Draft PR 運用**（CLAUDE.md）: worktree feature branch から Draft PR を作って逐次更新する運用。
- 参照: `plugins/loops/references/recipe-format.md`。

## コスト注意

公式トークン管理の該当項目:
- **実行頻度を必要最小限にする**: デフォルトは日次。backlog が空の日は 1 サイクルで discovery のみ実施して早期終了する。
- **1 サイクルの処理数上限**: fan-out 暴走防止（`research/anthropic-agent-knowledge.md` ソース 2 のスケーリングルール）。最大 2 件に制限。
- **決定論的作業のスクリプト化**: backlog / issue の列挙（`gh issue list` 等）は決定論的なので LLM には選定・実装のみを任せる。
- **大規模実行前のパイロット実行**: 初回は処理数上限 1 件で手動 1 サイクル回し、暴走しないことを確認してから常用する。
- ループはチャットの約 4 倍、第二エージェントを含むマルチエージェント構成は約 15 倍のトークンを消費する点に留意する。

## エスカレーション

**外向きアクションは非破壊デフォルト（外向きアクションの上限は Draft PR / issue コメントまで）**。以下は行わず、
必要になったら人間へエスカレーションする:

- **マージしない**（`gh pr merge` = merge 禁止）。マージ等の不可逆操作は**人間の判断に委ねる**。
- **PR を close しない**（close 禁止）。
- **force push しない**（force 系禁止）。ブランチ削除もエスカレーション。
- **main への直接 push をしない**（feature branch のみ）。
- 同一タスクが **2 連続**で失敗したら**凍結**し、state の引き継ぎ待ちに記録して**人間へエスカレーション**する。
- 設計判断が必要・タスクの意図が不明・レビューで重大な指摘が出た場合も人間へ引き渡す。
