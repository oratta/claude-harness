# デモ: routine-recipe-miner 手動 1 サイクル

change-4 proactive-routines / 受け入れ条件 12 / tasks グループ 6 の evidence。

- 対象レシピ: `plugins/loops/recipes/routine-recipe-miner.md`
- 実行日: 2026-07-05
- 実行形態: **手動 1 サイクル起動**（定期実行への登録は一切行わない。スケジューラ登録・cron 設定は本デモに含めない）。
- 対象ログ: `~/.claude/projects/` 配下の直近 7 日のセッション jsonl（ローカル実行必須の制約を満たす環境で実施）。

## discovery（サブエージェント隔離・jq 圧縮解析）

生ログをメインコンテキストに載せず、jq パイプライン（llm-log-compactor のパターン相当）で
**候補リスト（抽出結果）のみ**を集計した。実行痕跡（決定論的な集計コマンド）:

```
$ find ~/.claude/projects -name '*.jsonl' -mtime -7 | head -150 | while read f; do
    jq -r 'select(.type=="user") | (.message.content ... )' "$f"
  done | grep -oE '/(lr|wt-...|goal|loop|schedule|loops:...|...)' | sort | uniq -c | sort -rn
```

集計結果（生ログではなく頻度カウントのみをメインに返した）:

```
  46 /wt-setup
  34 /plugin
  31 /lr
  25 /goal
  12 /schedule
   6 /loop
   5 /loops:design
   3 /reload-plugins
   2 /loops:goalify
   1 /wt-clean
   1 /weekly-report
```

### 4 種の抽出候補への振り分け

- (a) **同型依頼の 3 回以上の反復 = ループ化候補**: `/wt-setup`（46 回）+ `/lr`（31 回）の連鎖 =
  「worktree を切って longrun を回す」定型フローが頻出 → ルーチン化候補。
- (b) **修正→テスト→修正の長い往復 = /goal 化候補**: `/goal`（25 回）が既に多用されており、bats 全 PASS までの
  反復は `goal-tests-green` で既にカバー済み → 新規性は低い。
- (c) **定時性のある依頼 = /schedule 化候補**: `/schedule`（12 回）と `/weekly-report`（1 回）→ レポート系の定時化は
  既存 `cron-weekly-report` / `cron-daily-report` でカバー済み。
- (d) **既存レシピの実行痕跡 = 実測チューニング候補**: `/loops:design`（5 回）・`/loops:goalify`（2 回）の使用痕跡あり →
  実測データはまだ薄く、頻度・停止基準のチューニング判断には次サイクル以降の蓄積が必要。

## 生成（最大 3 件・規約検査を通す）

候補 (a) から 1 件の新規案（`routine-wt-longrun` 相当）を検討したが、既存の `routine-backlog-triage`
（worktree 隔離 + Draft PR）とスコープが重複するため、独立レシピ化は**見送り**とした。
(b)(c) は既存レシピでカバー済みのため見送り。(d) は実測データ不足で見送り。

→ **このサイクルの新規/更新提案: 0 件**（規約検査を通せる十分な新規性のある候補が無かった）。

## 規約検査（手動実行・スキル起動非依存）

`/loops:design` は未インストールのため起動せず、`references/recipe-format.md`（**停止基準必須**）と
`references/loop-types.md` の **Bad Loop 検査** 4 項目を、検討した (a) の候補に手動適用した:

| 検査項目 | 結果 | 判断 |
|---|---|---|
| 停止基準必須 | **PASS** | 候補には /goal 停止基準を付与可能 |
| 検証なき成功宣告がないか | **PASS** | Draft PR 到達を成功条件にできる |
| 報酬ハッキング余地がないか | **PASS** | - |
| 過剰な実行頻度がないか | **PASS** | 日次以下に設定可能 |
| （追加判断）新規性・非重複性 | **FAIL** | 既存 routine-backlog-triage とスコープ重複 → 見送り |

規約検査自体は PASS だが、重複により**見送り**（採用しない）と判断した。

## 出力

新規/更新提案が 0 件のため、**Draft PR は作成しない**。**「提案なし」で正常終了**（異常系ではない）。
解析は正常に完了しており、jsonl 読み取り失敗等の異常系とは区別される。

## persistence（state 3 区分・`loops/state/routine-recipe-miner.state.md` 相当）

- **提案済み**: なし（このサイクルは 0 件）。
- **見送り理由**: (a) worktree+longrun ルーチン化候補 = 既存 routine-backlog-triage とスコープ重複。
  (b)(c) = 既存レシピでカバー済み。(d) = 実測データ不足。
- **繰り越し候補**: (d) `/loops:design` / `/loops:goalify` の実測チューニングは、使用痕跡が蓄積したら再評価（次サイクルへ繰り越し。silent drop せず記録）。

## 確認結果サマリ

- 手動 1 サイクル: discovery（サブエージェント隔離・jq 圧縮）→ 生成 → 出力 → persistence まで完走。
- 出力: 新規性のある提案が無く「**提案なし**」で正常終了（Draft PR なし）。
- state 更新: 提案済み / 見送り理由 / 繰り越しの 3 区分を記録。繰り越しに (d) を silent drop せず記録。
- 定期実行への登録: **行っていない**（手動起動のみ。crontab/launchd 未使用）。
- 規約検査: 停止基準必須 + Bad Loop 検査を手動実行（`/loops:design` 非依存）、各項目 PASS/FAIL を記録。
