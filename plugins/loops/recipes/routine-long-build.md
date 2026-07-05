# レシピ: routine-long-build

> プロアクティブ合成ルーチン（change-4 proactive-routines）。harnesses 論文（`research/claude-code-official.md` §7）の
> 外部状態設計（feature-list JSON + progress notes + 1 セッション 1 機能 + 丁寧なテスト後にのみ passing + セッション開始時 smoke check）を
> ネイティブ合成（/schedule または手動再起動 + /goal）で実現した版。
> feature-list の形式は `plugins/loops/references/feature-list-format.md`、規約は `plugins/loops/references/recipe-format.md` を参照。

## ループ型

**プロアクティブ**（4 分類: ターンベース / ゴールベース / タイムベース / プロアクティブ のうち）。
スケジュールまたは手動再起動がトリガーで、人間不在で長期ビルドを 1 サイクルずつ前進させる。
「プロンプト自体を手放す」（`references/loop-types.md`）。反復・停止判定はネイティブ（/goal の定量ゴール）に委ねる。

## 目的

大きな機能セット（feature-list）を、1 セッション 1 機能の粒度で丁寧に積み上げる。エージェントのコンテキストは
揮発するが、`feature-list.json`（真のソース）と `claude-progress.md`（進捗ノート）がリポジトリに残るため、
次サイクルが続きから再開できる。「エージェントは忘れるが、リポジトリは記憶する」。

## 起動コマンド

コピペ可能なネイティブプリミティブ文字列。スケジューラ登録手順は書かない（呼び出し側の責務・スコープ外）。

```
/schedule daily: /goal advance the long build. Read {longrun-dir}/feature-list.json and {longrun-dir}/claude-progress.md, then run exactly one cycle: (1) smoke check the most recent passing items by re-running their verification commands, (2) implement only the single first passes:false item, (3) run that item's verification command and only set passes:true if it exits 0 with logged evidence, (4) write a descriptive commit, (5) append the cycle record to claude-progress.md. Do not stop until every item is passes:true; if the same item FAILs twice in a row, freeze it (leave it passes:false, never delete it) and escalate to a human. Never set passes:true by self-report without exit 0 evidence.
```

（手動再起動で回す場合は先頭の `/schedule daily:` を外し、`/goal ...` 本体をそのまま手動で 1 サイクルずつ起動する。）

- 起動コマンドはネイティブプリミティブ `/schedule` + `/goal`（または `/goal` の手動再起動）のみ。**独自 driver・常駐スクリプトは作らない（MUST NOT）**。
- **自己申告更新の禁止（発火時プロンプトに明記）**: verification コマンドの exit 0 evidence なしに `passes:true` にしてはならない。
- **推奨頻度のデフォルトは日次**（保守的）。頻度変更は先頭 `daily` を書き換える。

### 1 サイクルの手順（この順序を厳守）

1. **smoke check（実装より前）**: 直近 passing 項目の verification コマンドを再実行し、退行がないことを確認する。
2. **1 項目のみ実装**: `passes:false` の**先頭 1 項目のみ**を実装対象とする。1 サイクルで複数項目は実装しない。
3. **verification 実行 + passes 更新**: 当該項目の verification コマンドを実行し、**exit 0 の evidence（実行ログ）がある場合のみ** `passes:true` に更新する。exit が 0 でなければ `passes:false` のまま（自己申告更新は禁止）。
4. **説明的 commit**: 何を実装したかが分かる commit を作る（passes 更新の後）。
5. **progress 追記**: `claude-progress.md`（progress notes）に、smoke check 結果・実装項目・verification の exit code・passes 更新・凍結有無を追記する（passes 更新の後）。

## 停止基準

- **定量ゴール（/goal）**: 「**全項目 `passes:true`**」になるまで停止しない。
- **2 連続 FAIL の凍結**: **同一項目が 2 連続で FAIL** した場合、その項目を**凍結**（`passes:false` のまま、当該サイクル以降の自動リトライ対象から除外）し、**人間へエスカレーション**する。無限リトライは禁止。
- 凍結項目は feature-list から**削除しない**（削除禁止）。凍結の事実と理由は progress notes に記録する。
- 全項目 passes:true か、残る未達項目が全て凍結済みになった時点で、ループは終了する。

## 前提

- `{longrun-dir}/feature-list.json` が存在すること（各項目 `{id, description, verification, passes:false}`。形式は `references/feature-list-format.md`）。
- `{longrun-dir}/claude-progress.md`（progress notes）が存在するか、初回サイクルで作成すること。
- verification コマンドが実在し、exit code が本物であること（bats / grep / jq 等）。
- git が使え、サイクルごとに commit できること。
- 参照: `plugins/loops/references/feature-list-format.md`、`plugins/loops/references/recipe-format.md`、`plugins/loops/references/state-convention.md`。

## コスト注意

公式トークン管理の該当項目:
- **実行頻度を必要最小限にする**: デフォルトは日次。1 サイクル 1 項目で少しずつ進めるため 1 回のトークンは有界。
- **決定論的作業のスクリプト化**: smoke check と verification は決定論的なコマンド（bats / grep / jq）に落とし、LLM には実装のみを任せる。
- **大規模実行前のパイロット実行**: 初回は 1 サイクルだけ手動で回し、smoke check と verification が意図通り exit code を返すことを確認する。
- ループはチャットの約 4 倍のトークンを消費する点に留意する。

## エスカレーション

**外向きアクションは非破壊デフォルト（Draft PR / issue コメントまで。ここでは feature branch への commit まで）**。以下は人間へエスカレーションする:

- **同一項目 2 連続 FAIL** → 凍結（`passes:false` のまま**削除しない**）+ progress notes に理由記録 + 人間へエスカレーション。
- verification コマンド自体が壊れている / 判定不能な場合 → 人間へ引き渡す（勝手に verification を書き換えない）。
- **マージ・force push・項目/テストの削除は禁止**（不可逆操作）。必要になったら人間の判断に委ねる。
- 設計判断が必要・スコープの再定義が必要な場合も人間へエスカレーション。
