## Why

`accounts.json` でオフにしたアカウントが、最新版のステータスラインでも `off` の行として残る。使っているアカウントだけを見たいという #1112 の要望と既存仕様が食い違う。さらに #1006 の README の登録例は、貼るシェルによってコマンドが見つからない、登録順が説明と異なる、既定アカウントの使用量が別スロットに帰属するという問題がある。

## What Changes

- **BREAKING**: 非 active で `enabled` が JSON の `false` の Claude スロットを、`off` の行も含めステータスラインから消す。active のスロットはオフでもライブ値を表示する。
- **BREAKING**: `codex.enabled` が JSON の `false` のとき、Codex の行を出さない。Codex の取得を止め、キャッシュに触れない既存の契約は保つ。
- 表示対象にならないスロットを、Claude の複数スロット表示判定と名前列の幅に数えない。表示対象の Claude スロットが 1 つなら従来の 1 スロット表示にする。
- #1006 の両 README の登録コマンドと順序を、各コードブロックをそのまま実行できる形に直す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `statusline-multi-account-usage`: オフの Claude / Codex 行の有無、表示対象数と列幅、active の例外を変更する。
- `usage-account-registry`: `enabled` / `codex.enabled` の statusline への影響を、新しい表示契約と一致させる。登録、選択、取得の契約は維持する。

## Impact

- 実装・テスト: `plugins/statusline/scripts/statusline.sh`、`plugins/statusline/tests/statusline-multi-account.bats`、`plugins/statusline/tests/statusline.bats`、`plugins/statusline/tests/test_codex.py`。
- 文書: `plugins/statusline/README.md`、`plugins/dev-workflow/README.md`、`plugins/statusline/changes/1112.md`。過去の変更記録 `plugins/dev-workflow/changes/976.md` / `978.md` は履歴として残し、現在の表示契約を新しい記録で上書きする。
- `statusline-codex.py` はオフ時に内部の `off` センチネルを返すままとし、描画側で行を捨てる。#1115 のリセット権表示と #527〜#530 の使用率・経過率は変更しない。
