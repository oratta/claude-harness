# レシピ: goal-tests-green

> /loops:design デモ（change-1 タスク 5.2）で生成した出力例。change-3 の正式レシピ集とは別。

## ループ型

ゴールベース（手放す対象 = 停止条件 / プリミティブ = /goal）

## 目的

このリポジトリの bats テストが全 PASS になるまで、実装を自律修正する。人間は最終確認だけに集中する。

## 起動コマンド

```
/goal make `find plugins -name '*.bats' -print0 | xargs -0 bats` exit 0 (all bats PASS), stop after 5 tries
```

## 停止基準

- 定量ゴール: `find plugins -name '*.bats' -print0 | xargs -0 bats` の exit code が 0（全 bats PASS）
- 最大試行数: stop after 5 tries（無進捗・予算切れの独立出口）

## 前提

- bats-core がインストール済み（`which bats`）
- 実行環境の制約: このリポジトリの git root で実行すること

## コスト注意

- 決定論的検証（bats）を報酬信号にするため LLM 判定コストは最小。
- 5 回上限で暴走・トークン爆発を防ぐ（ループはチャットの約 4 倍）。

## エスカレーション

- 5 回試行しても全 PASS に届かない場合は停止し、失敗テストの一覧と最後の diff を添えて人間へ引き継ぐ。
- テストファイル自体の削除・書き換えによる「見かけ上の PASS」は禁止（報酬ハッキング）。該当したら人間へエスカレーション。
