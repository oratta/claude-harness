# デモ: routine-long-build 複数サイクル完走 + 凍結

change-4 proactive-routines / 受け入れ条件 11 / tasks グループ 4 の evidence。

- 対象レシピ: `plugins/loops/recipes/routine-long-build.md`
- 形式リファレンス: `plugins/loops/references/feature-list-format.md`
- 実行日: 2026-07-05
- サンドボックス: `_longruns/2026-07-04_anthropic-knowledge-reflect/demos/long-build-sandbox/`
- feature-list（3 項目、全て `passes:false` 初期値、実在の verification コマンド）:

```json
[
  { "id": "feat-1", "description": "greet.txt に Hello を書く", "verification": "grep -q Hello greet.txt", "passes": false },
  { "id": "feat-2", "description": "nums.txt を JSON 配列 [1,2,3] にする", "verification": "jq -e '.==[1,2,3]' nums.txt", "passes": false },
  { "id": "feat-3", "description": "impossible.txt に決して現れない語（デモ用・故意失敗）", "verification": "grep -q NEVER_EVER_PRESENT impossible.txt", "passes": false }
]
```

verification コマンドは bats / grep / jq で exit code が本物（tasks 4.1）。

## 複数サイクル完走ログ（tasks 4.2）

### Cycle 1

- **smoke check**: passing 項目がまだ無いためスキップ（記録: 直近 passing なし）。
- **実装（1 項目のみ）**: `passes:false` の先頭 = `feat-1`。`echo "Hello world" > greet.txt`。
- **verification**: `grep -q Hello greet.txt` → **exit code 0**。
- **passes 更新**: exit 0 evidence があるため `feat-1.passes = true`（自己申告ではなく exit 0 に基づく）。
- **commit**: `feat(long-build-demo): implement feat-1 greet.txt`（説明的 commit・相当物）。
- **progress 追記**: 下記 progress notes の Cycle 1 行。

### Cycle 2

- **smoke check（実装より前）**: 直近 passing = `feat-1`。`grep -q Hello greet.txt` を再実行 → **exit code 0**（退行なし）。
- **実装（1 項目のみ）**: `passes:false` の先頭 = `feat-2`。`echo "[1,2,3]" > nums.txt`。
- **verification**: `jq -e '.==[1,2,3]' nums.txt` → **exit code 0**。
- **passes 更新**: exit 0 evidence があるため `feat-2.passes = true`。
- **commit**: `feat(long-build-demo): implement feat-2 nums.txt`。
- **progress 追記**: 下記 Cycle 2 行。

（1 サイクル 1 項目・smoke check が実装より前・commit と progress が passes 更新の後、をログで確認）

## 故意の 2 連続 FAIL → 凍結 + エスカレーション（tasks 4.3）

### Cycle 3（feat-3 attempt 1）

- **smoke check**: feat-1 / feat-2 を再実行 → いずれも exit 0（退行なし）。
- **実装**: `passes:false` の先頭 = `feat-3`。
- **verification**: `grep -q NEVER_EVER_PRESENT impossible.txt` → **exit code 1（FAIL）**。
- **passes 更新**: exit 0 でないため `feat-3.passes = false` のまま（自己申告更新なし）。連続失敗カウント = 1。

### Cycle 4（feat-3 attempt 2）

- **verification**: 再実装後も `grep -q NEVER_EVER_PRESENT impossible.txt` → **exit code 1（FAIL）**。連続失敗カウント = **2 連続**。
- **凍結**: 同一項目 `feat-3` が **2 連続 FAIL**。**凍結**（`passes:false` のまま、以降の自動リトライ対象から除外）。
- **削除しない**: `feat-3` は feature-list から**削除されない**（`passes:false` のまま残る。削除禁止）。
- **エスカレーション**: 凍結の事実と理由を progress notes に記録し、**人間へエスカレーション**。

## progress notes（`claude-progress.md` 相当）

```
Cycle 1: smoke=none; impl=feat-1; verify exit 0; feat-1 passes:true; committed
Cycle 2: smoke feat-1 exit 0; impl=feat-2; verify exit 0; feat-2 passes:true; committed
Cycle 3: smoke feat-1/feat-2 exit 0; impl=feat-3; verify exit 1 (FAIL #1); feat-3 passes:false
Cycle 4: impl=feat-3 retry; verify exit 1 (FAIL #2 = 2連続); FREEZE feat-3 (passes:false, not deleted); ESCALATE to human
```

実測 exit code（サンドボックスで実際に実行）:

```
feat-1 verification exit code: 0
feat-1 smoke exit code: 0
feat-2 verification exit code: 0
feat-3 verification attempt-1 exit code: 1
feat-3 verification attempt-2 exit code: 1
```

## 規約検査（tasks 3.4 / 4.4・手動実行、スキル起動非依存）

`/loops:design` は未インストールのため起動せず、`references/recipe-format.md`（**停止基準必須**）と
`references/loop-types.md` の **Bad Loop 検査** 4 項目を手動適用した:

| 検査項目 | 結果 | 根拠 |
|---|---|---|
| 停止基準必須 | **PASS** | 停止基準節に /goal「全項目 passes:true」+ 2 連続 FAIL 凍結あり |
| 検証なき成功宣告がないか | **PASS** | passes:true は verification の exit 0 evidence がある場合のみ |
| 報酬ハッキング余地がないか | **PASS** | 項目・verification 削除禁止でスコープ縮小による偽完了を防止 |
| 過剰な実行頻度がないか | **PASS** | デフォルト日次 + 1 サイクル 1 項目で有界 |

全 4 項目 **PASS**。

## 確認結果サマリ

- 2 サイクル以上（実際は 4 サイクル）の完走ログ: smoke check・実装項目・verification exit code・passes 更新・progress 追記を確認。
- 故意 2 連続 FAIL: feat-3 が凍結され `passes:false` のまま**削除されない**、人間へのエスカレーションが progress notes に記録されたことを確認。
- 規約検査: 停止基準必須 + Bad Loop 検査 4 項目すべて PASS（手動実行、`/loops:design` 非依存）。
