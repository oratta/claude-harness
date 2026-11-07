# Proposal

## Why

通常経路の PR を見張り直した本体が既存 W を把握しないと、`fix` を既存 W の implement 再開へ渡す現行手順では担当を用意できない。#1597 の手順書の読み合わせで、この条件を ci-watch.md 9 が許す一方、通常経路の担当復元と情報不足時の停止先が未定義であることを確認した。

## What Changes

- 通常経路の CI 見張りに、前任 W の成果と既存の手渡し許可の根拠を残す引き継ぎを定める。
- W を把握しない本体は、対象の一致と手渡し可を確認できた場合だけ、新しい W に `段: implement` で手渡す。情報不足なら修正せず、共有手順の escalate と同じ停止・報告先へ返す。
- 既存 W の implement 再開、軽い通し方からの新規 spec 起動、同じ PR・状態ファイルによる見張り継続を維持し、関係 Bats に回帰ケースを足す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: CI 見張りの通常経路で W を把握しない場合の、引き継ぎの作成・読取り・担当の準備・停止先を追加する。

## Impact

手順の編集先は `plugins/dev-workflow/skills/develop/references/decision-criteria.md`、同 `handover.md`、`plugins/dev-workflow/references/ci-watch.md`。既存の `develop-trivial-light-path.bats` に関係テストを集約し、変更記録 `plugins/dev-workflow/changes/1597.md` を追加する。CLI・状態ファイル形式・修正回数・見張りの重複判定・#1583/#1590 の範囲は変えない。

分割判定: 単一 change。受け入れ条件は同じ担当引き継ぎ契約の正常系・情報不足・既存経路の維持の 3 点で、単一 capability・1 PR に収まる。独立した設計判断は、担当不明を既存の手渡し許可を持つ引き継ぎで解決し、足りなければ停止することの 1 つ。

起動時予算の対象 3 ファイルは編集予定に含めない。必要になった場合は周辺文を圧縮せず、OWNER の指示どおり追記による増加分まで該当予算を上げ、PR 本文に理由と https://github.com/oratta/claude-harness/issues/1586 を書く。
