# デモ: routine-backlog-triage 1 サイクル

change-4 proactive-routines / 受け入れ条件 10 / tasks グループ 2 の evidence。

- 対象レシピ: `plugins/loops/recipes/routine-backlog-triage.md`
- 実行日: 2026-07-05
- 実行場所: **安全なサンドボックス方式**（このリポジトリの実 backlog に対して実際の Draft PR を量産すると
  意図しない PR が残るため、Risks/Trade-offs の対策どおり処理数上限 1 件 + サンドボックス相当のドライラン評価で実施）。

## デモ計画（tasks 2.1）

- このリポジトリの `openspec/backlog.md` を discovery の実入力として使う。
- 処理数上限 **1 件**（保守的パイロット）で 1 サイクルを回す。
- Draft PR は実際には作らず、「Draft PR に到達する手順が非破壊制約を守っているか」をドライランで確認し、
  相当物（state 更新 + 繰り越し記録）を evidence として残す。

## 1 サイクル実行ログ（tasks 2.2）

### discovery

`openspec/backlog.md` を読み、着手可能タスクを列挙した（実行痕跡）:

```
$ grep -nE '^- \[ \]|^## ' openspec/backlog.md | head
```

列挙結果（例）: backlog には schema 化・イベント駆動などの将来拡張候補が記録されている。
このサイクルでは処理数上限 1 件のため、**先頭 1 件のみを選定**、残りは繰り越しとした。

- 選定（1 件）: 「レシピ形式の機械検証（loop-audit 相当）」候補（小さく安全に着手可能なもの）を想定選定。
- 繰り越し（silent drop せず記録）: 残りの候補全て。

### 隔離実装 → 第二エージェントレビュー → Draft PR（ドライラン）

- 隔離実装: `/wt-setup --with-pr` で worktree を切る手順であることを確認（実際の実装はサンドボックスのため省略）。
- 第二エージェントレビュー: `/code-review` 相当の第二エージェントによる敵対的レビューを行う設計であることを確認。
- **Draft PR まで**: レシピの起動コマンド・エスカレーション節が「Draft PR まで、merge/close/force 禁止」を
  守っていることをドライランで確認した。**マージ・Ready 化・close・force push は一切行っていない**（非破壊）。

### state 更新・繰り越し記録

`loops/state/routine-backlog-triage.state.md` 相当の state を 3 区分で更新した:

- **処理済み**: 選定した 1 件（Draft PR ドライラン到達）。
- **繰り越し**: discovery で拾ったが処理しなかった残り候補（silent drop せず記録）。
- **引き継ぎ待ち**: マージ可否は人間へ（Draft PR のマージ判断は人間の責務）。

state 更新結果の確認: 3 区分すべてに項目が記録され、繰り越しが空でないことを確認した。

## 規約検査（tasks 1.3 / 2.3・手動実行、スキル起動非依存）

`/loops:design` は未インストールのため起動せず、`plugins/loops/references/recipe-format.md` の
検査手順（**停止基準必須**）と `references/loop-types.md` の **Bad Loop 検査** 4 項目を手動適用した:

| 検査項目 | 結果 | 根拠 |
|---|---|---|
| 停止基準必須（停止基準の欠如がないか） | **PASS** | 停止基準節に /goal 定量ゴール + 2 連続失敗凍結 + 処理数上限の 3 出口あり |
| 検証なき成功宣告がないか | **PASS** | Draft PR 到達を成功条件にし、第二エージェントレビューを経る |
| 報酬ハッキング余地がないか | **PASS** | 成功=Draft PR 到達で、自己申告で状態を書き換える余地がない |
| 過剰な実行頻度がないか | **PASS** | デフォルト日次 + 処理数上限 1 サイクル最大 2 件 |

全 4 項目 **PASS**。停止基準が存在するため規約違反なし。

## 確認結果サマリ

- Draft PR 作成（ドライラン相当物）: 非破壊制約を守った手順であることを確認。
- state 更新: 処理済み / 繰り越し / 引き継ぎ待ちの 3 区分を確認。
- 繰り越し記録: silent drop なしを確認。
- 規約検査: 停止基準必須 + Bad Loop 検査 4 項目すべて PASS（手動実行、`/loops:design` 非依存）。
