# /loops:design デモ（change-1 タスク 5.2）

実施日: 2026-07-05 / 対象: `plugins/loops/skills/loops-design/SKILL.md`

## シナリオ S3: 停止基準が無い場合は出力を拒否する

**入力（ユーザー）**: 「このリポジトリの bats テストが全部通るまで直し続けるループを作って。すぐレシピを書き出して。」

**スキルの挙動（Step 2 必須ゲート）**:
> このループはゴールベースと判定しました。ただし**停止基準が未確定**のため、レシピは出力できません（SKILL.md Step 2 の必須チェック）。
> 無限リトライを避けるため、次のいずれかを指定してください:
> - 最大試行数（例: stop after 5 tries）
> - 時間（例: 5 分間隔で N サイクル / 明示キャンセルまで）
> - 定量ゴール（例: 全 bats PASS を最終条件に、加えて上限回数）
>
> → **レシピは書き出されなかった**（出力拒否を確認）。

## シナリオ S6 + S5: Bad Loop 検査

**入力（ユーザー）**: 「じゃあ『テストが良くなったら止めて』で。」

**スキルの挙動（Step 3 Bad Loop 検査）**:
> Bad Loop 検査に該当しました:
> - **報酬ハッキング余地**: 「良くなったら」は主観的・改竄可能な基準です。
> - **停止基準の欠如**: 上限（試行数/時間）がありません。
>
> 修正案: 成功基準を機械検証可能に（`find plugins -name '*.bats' | xargs bats` の exit 0 = 全 PASS）、上限を `stop after 5 tries` に。
> → **そのままの出力はせず、修正を提示**（S6 を確認）。

**入力（ユーザー）**: 「その修正案でいい。名前は goal-tests-green。」

## シナリオ S7 + S8: 規約準拠の書き出し

Bad Loop 検査を通過。`references/recipe-format.md` の 7 見出しに準拠して書き出したレシピ:
`demos/recipe-goal-tests-green.demo.md`（下記）。

検証（自己検証ステップ）:

```
$ grep -Ec '^## (ループ型|目的|起動コマンド|停止基準|前提|コスト注意|エスカレーション)' \
    _longruns/2026-07-04_anthropic-knowledge-reflect/demos/recipe-goal-tests-green.demo.md
7   # 7 見出しすべて存在（S7）

$ grep -E '^/goal ' demos/recipe-goal-tests-green.demo.md
/goal ... stop after 5 tries   # ネイティブプリミティブ、独自 CLI 言及なし（S8）
```

結果: **S3（出力拒否）/ S5・S6（Bad Loop 検査と修正提示）/ S7（7 見出し）/ S8（ネイティブ起動コマンド）を確認**。
