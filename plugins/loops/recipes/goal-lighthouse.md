# レシピ: goal-lighthouse

> 初期シードレシピ（change-3 goal-time-recipes）。公式記事「Getting started with loops」の公式例を移植したもの。
> 規約は `plugins/loops/references/recipe-format.md` を参照。

## ループ型

**ゴールベース**（4 分類: ターンベース / ゴールベース / タイムベース / プロアクティブ のうち）。
Lighthouse スコアという定量閾値を成功基準に、達成まで自律最適化させる。公式記事が挙げるゴールベースの代表例。
選定基準は `references/loop-types.md` の「停止条件を手放す」に従う。

## 目的

Web プロジェクトのトップページの Lighthouse スコアを目標値以上に引き上げるまで、計測 → 改善 → 再計測を自律反復させる。
公式例 `/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries` を、このハーネスのレシピ形式に移植した Web プロジェクト汎用レシピ。

## 起動コマンド

コピペ可能な `/goal` 文字列（公式例の忠実な移植）:

```
/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries
```

- 出典: 公式記事「Getting started with loops」（claude.com, 2026-06-30）のゴールベース公式例そのまま。
- 起動コマンドはネイティブプリミティブ `/goal` のみ。**独自 CLI やラッパースクリプトは作らない**。
- 計測手段（Lighthouse CI 等）はプロジェクト側の既存スクリプトを参照するに留め、driver は新設しない。

## 停止基準

- **成功基準（定量・機械検証可能）**: Lighthouse スコアが閾値 **デフォルト 90 以上**（`90 or above`）に達すること。
  - **測定手段**: `npx lighthouse <url> --output=json` または Lighthouse CI（`lhci autorun`）の performance スコアを読み取り、90 以上かを判定する。エバリュエータはこのスコア数値で判定する。
  - **閾値の変更方法**: 起動コマンド文字列中の `90` を目標値（例: `95`）へ書き換える。
- **打ち切り条件（必須）**: 最大試行数のデフォルトは **5 回**（`stop after 5 tries`、公式例準拠）。
  - **変更方法**: 起動コマンド文字列末尾 `stop after 5 tries` の数値 `5` を書き換える。
- スコア 90 以上の達成、または最大試行 5 回の到達のいずれかで必ず停止する。

## 前提

- **Web プロジェクトであること**（トップページに HTTP アクセスできる）。
- **Lighthouse 実行手段**があること（`lighthouse` CLI / `@lhci/cli` / Chrome ヘッドレス）。
- 計測対象 URL（ローカル dev サーバー or デプロイ先）が起動・到達可能であること。
- 参照: `plugins/loops/references/recipe-format.md`。

## コスト注意

公式トークン管理の該当項目:
- **実行頻度を必要最小限にする**: スコア計測は決定論的なので毎試行 LLM に丸投げせず、計測コマンドの結果だけを渡す。
- **決定論的作業のスクリプト化**: Lighthouse 計測自体はスクリプト化し、LLM には改善案の実装のみを任せる。
- **大規模実行前のパイロット実行**: まず `stop after 2 tries` で計測フローが通ることを確認してから本数を上げる。
- ループはチャットの約 4 倍のトークンを消費する点に留意する。

## エスカレーション

- 同一の改善施策が **2 連続で効果なし**（スコアが変化しない/悪化する）場合は人間へエスカレーションする。
- スコアを偽装する変更（計測対象の差し替え・閾値の勝手な引き下げ等の報酬ハッキング）は禁止。必要ならエスカレーション。
- 最大試行数に達しても 90 未満なら、到達した最高スコアと残課題を提示して人間に引き渡す（達成と偽らない）。
