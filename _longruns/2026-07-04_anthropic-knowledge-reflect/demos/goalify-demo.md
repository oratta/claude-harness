# /loops:goalify デモ（change-1 タスク 5.3）

実施日: 2026-07-05 / 対象: `plugins/loops/skills/loops-goalify/SKILL.md`

## (a) 情報不足の brain dump → 不足観点のみヒアリング（S11）

**入力**: `/loops:goalify _longruns/.../demos/goalify-braindump-partial.demo.txt`（ファイルパス入力 = S10）

内容には **成功基準**（bats が全 ok）と **前提**（bats 済み・git root）が書かれているが、
**停止条件** と **スコープ境界** が無い。

**スキルの挙動（Step 1 充足分析 → Step 2 不足のみヒアリング）**:
> 成功基準・前提は brain dump にあるため質問しません。不足している 2 観点のみ確認します（AskUserQuestion）:
> 1. 停止条件: 最大試行数 or 時間は？
> 2. スコープ境界: 触ってよい範囲 / やらないことは？

→ **成功基準・前提については質問せず、停止条件・スコープ境界のみ質問**（S11 を確認）。

## (b) 全情報が揃った brain dump → ヒアリング 0 問で生成（S12）

**入力**: `/loops:goalify _longruns/.../demos/goalify-braindump-complete.demo.txt`

4 観点（成功基準 / 停止条件 / スコープ境界 / 前提）すべてが書かれている。

**スキルの挙動**: AskUserQuestion は **0 問**。そのまま生成へ進む（S12 を確認）。

生成物: `demos/loops-green.goal.md`（下記の検証を参照）。

### 自己検証（evidence）

```
$ grep -Ec '^## (目的|成功基準|制約|参照パス|エスカレーション条件)' demos/loops-green.goal.md
5   # 5 見出しすべて存在（S13）

# 成功基準が全てコマンド + 期待値（主観語なし）（S14）
$ grep -E 'exit code|出力が' demos/loops-green.goal.md     # コマンド+期待値の組
$ grep -E '良くなったら|いい感じ|きれいに' demos/loops-green.goal.md ; echo "exit=$?"
exit=1   # 主観語ゼロ
```

## /goal 起動コマンド 1 行（S15）とレシピ昇格の促し（S16）

goalify の出力に含まれる 1 行:

```
/goal follow demos/loops-green.goal.md until all success criteria pass, stop after 5 tries
```

レシピ昇格の案内（1 行）:

> このワークフローを**反復利用するなら `recipes/loops-green.md` へ昇格**を検討（`/loops:design` で規約準拠のレシピ化）。

結果: **S9/S10（両入力）/ S11（不足のみ質問）/ S12（0 問）/ S13（5 見出し）/ S14（機械検証可能）/ S15（/goal 1 行）/ S16（昇格案内）を確認**。
