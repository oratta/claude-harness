# goal: loops-green

> /loops:goalify デモ（change-1 タスク 5.3）で `goalify-braindump-complete.demo.txt` から生成した goal ブリーフ。
> 4 観点すべてが揃っていたためヒアリングは 0 問（S12）。

## 目的

loops プラグインの bats テストを全 PASS にする。

## 成功基準

- `find plugins/loops -name '*.bats' -print0 | xargs -0 bats` の exit code が **0**（全テスト ok）
- `find plugins/loops -name '*.bats' -print0 | xargs -0 bats | grep -c '^not ok'` の出力が **0**

（各項目は実行コマンド + 期待値の組。主観的基準を含まない。）

## 制約

- 触ってよいのは `plugins/loops/` 配下のみ。
- テストファイル自体の削除・改変による見かけ上の PASS は禁止。

## 参照パス

- `openspec/changes/loops-plugin/specs/` の各 spec.md
- `plugins/loops/references/`

## エスカレーション条件

- 5 回試行しても全 PASS に届かない場合は停止し、失敗テスト一覧を添えて人間へ引き継ぐ。
