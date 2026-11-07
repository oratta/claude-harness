# Proposal

## Why

軽い通し方で passed 後、CI 見張りの fix から起きた新しい W が通常の仕様化判断を投稿してから失敗ログを読み、差分と無関係なので修正・push せず返す順序が現行手順で成立する。issue #1596 の目的は、不要な通常復帰によって最新の軽い判断だけが失われることを防ぐことである。

## What Changes

- 新しい spec 段 W は、`ci-fail` のログと PR 差分の関係確認を、通常の仕様化判断の再投稿より先に行う。
- 共有手順で差分と無関係と判断できたら、仕様化判断の再投稿・修正・push をせず本体へ返し、既存の `next --unrelated <チェック名> --after-fix` に接続する。
- 関係がある、または無関係と判断できない場合は従来の通常復帰へ進み、「する」なら artifact 一式と R1 の APPROVE を経る。競合・既存 W の通常復帰契約も維持する。
- decision-criteria.md の復帰手順、ci-watch.md「7. 直し方」、worker/spec.md の一般手順を接続し、順序と既存コマンドへの接続を関係テストで確認する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 「G が passed を返したら本体が CI を見張る」の軽い通し方からの復帰で、関係確認と判断投稿の順序、無関係時の最新判断の保持を定める。

## Impact

- 対象: `plugins/dev-workflow/skills/develop/references/decision-criteria.md`、同 `roles/worker/spec.md`、`plugins/dev-workflow/references/ci-watch.md`、`plugins/dev-workflow/tests/develop-trivial-light-path.bats`、`plugins/dev-workflow/changes/1596.md`。
- `ci-watch.sh` の分類・状態ファイル・修正回数・同じ HEAD の再実行上限と、R1・ゲートの合否契約は変更しない。`dev-workflow-ci-watch` の既存の無関係返却契約を利用する。
- 分割判断: 受け入れ条件 3 件は、関係確認と判断再投稿の順序という 1 つの判断で満たせ、既存の develop capability に閉じる。単一 change・1 PR とする。
- #1583・#1590・#1597 の範囲、重複整理、起動時に常に読む 3 ファイルの変更は予定しない。
