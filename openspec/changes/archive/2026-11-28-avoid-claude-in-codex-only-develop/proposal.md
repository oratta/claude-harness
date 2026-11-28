## Why
`codex-standard` でも 4 つの例外経路が Claude を起こし、claude 不在時には余裕の欠測から Claude 構成へ倒れる。#1859 の範囲で、全工程 Codex の指定と実行可能な provider の制約を守る。

## What Changes
- 一時領域が必要なテスト再実行レビュー、画面確認 V、引き継ぎ判定、論点なし確認を `codex-develop.py request` の対象にする。
- Claude を使わない構成では、この 4 例外を起動せず既存の主への確認・保留経路に接続する。
- claude 不在時の自動選択に専用分岐を設け、Codex に余裕があれば Codex のみ、なければ理由を出して起動前に止める。
- `dev-workflow-develop` の V・引き継ぎ判定・論点なし確認の起動義務に今回の非起動条件を反映し、Codex オフ時の Claude 既定選択を Claude 実行可能時に限定する。
- `stages/reviewer-brief.md` の一時書き込みレビューの Claude 取り直し指示も request の結果に従わせ、Claude を使わない構成を迂回しないようにする。

## Capabilities
### New Capabilities
なし。
### Modified Capabilities
- `manual-codex-develop`: 例外 4 役も共通 resolver を通し、起動不能を品質合格にしない。
- `codex-role-profiles`: Claude を実行できない環境の自動選択と停止を規定する。
- `dev-workflow-develop`: 既存の起動義務と Codex オフ時の選択に、今回の例外条件だけを反映する。

- `dev-workflow-pr-review-gate`: 関連テストの自己再実行義務に、Claude を使わず一時ディレクトリが必要な場合だけ主の固定 HEAD の証拠を独立した読み取り専用 Codex レビュアーが評価する限定例外を反映する。

## Impact
`codex-develop.py`、同テスト、develop の入口・adapter・Gate Result・pr-review-gate の reviewer-brief の手順、`plugins/dev-workflow/changes/1859.md`。`codex-worker` の read-only policy と既存 profile 形式は維持する。他のエピック子の CLI 起動部・hook・共通ルール・選択閾値の変更は扱わない。
