# Proposal

## Why

Claude と Codex のキャッシュに古い develop 手順書が残ると、更新済みの運用を通らず開発が進む。Git 管理外のコピーも内容で比較し、配布済みの古い版と証明できる場合だけ入口で止める。

## What Changes

- 読込元の手順書集合の指紋を、取得した origin/main とその第一親履歴に照合する共通 CLI を追加する。
- マージ前の検証対象を読込元・元 worktree・HEAD・内容・記録先に拘束する印を追加する。
- 取得不能・新旧判定不能は記録先へ理由を投稿して続行し、投稿失敗も結果に残す。
- 記録先確定直後、仕様化判断・編集前に検査する入口契約と、一時環境の Bats テストを追加する。
- `plugins/dev-workflow/changes/1864.md` に変更と保証限界を記録する。

## Capabilities

### New Capabilities

- `develop-procedure-freshness`: 内容による新旧判定、マージ前の印、判定不能時の記録、CLI 終了コード。

### Modified Capabilities

- `dev-workflow-develop`: 記録先を確定した後、仕様化判断や編集より先に版を検査する要件を追加する。

## Impact

対象は dev-workflow の新規 Python スクリプト・詳細 reference・Bats、develop SKILL と worker/spec の入口接続、変更記録、および本 change。Python 標準ライブラリ・git・gh を使用する。hook や shell wrapper、plugin.json の version は追加しない。
根拠は [#1864](https://github.com/oratta/claude-harness/issues/1864) と [採用済みの設計判断](https://github.com/oratta/claude-harness/issues/1864#issuecomment-7234377970)。sync.sh の Codex 追随、worktree 読込手順、provider-compat-update、1860.md は他の子の範囲として含めない。導入前キャッシュへこの検査を強制する同期機構は追加しない。
