## Why
スロットが 8 個登録済みの登録簿に `accounts.sh add z` や `accounts-init.sh --id z` を実行すると、成功（exit 0）して 9 個目が登録簿に載る。しかし使用量を読む `usage_view.read_slots()` は先頭 8 個で打ち切るので、9 個目は自動選択にも使用量取得にも入らない。エラーも警告も出ず、黙って効かない。あわせて PR #1483 のレビュー指摘 F1: `add` の id の位置に来たハイフン始まりの引数（`add --lable` など）が id として登録される。

## What Changes
- `accounts.sh add` と `accounts-init.sh` は、`accounts` 配列がすでに 8 要素のとき、新しい id の追加を stderr に理由を出して exit 2 で拒否する。既存 id の登録し直しは従来どおり
- `accounts.sh add` は、id の位置のハイフン始まりの引数（`--help` / `-h` を除く）を exit 2 で拒否する
- spec `usage-account-registry` に要件「登録できるスロットは 8 個まで」を足し、要件「登録簿を一覧・追加・オン・オフするコマンド」の「accounts-init.sh は変えない」とハイフン始まりの扱いを直す

## Impact
`plugins/dev-workflow/scripts/accounts.sh`、`plugins/dev-workflow/scripts/accounts-init.sh`、`plugins/dev-workflow/tests/accounts-command.bats`、`openspec/specs/usage-account-registry/spec.md`。Refs #1031。
