## Why

bats はテスト本体を bash の `set -e` 下で実行する。POSIX/bash の仕様上、`!` で反転したコマンドの非ゼロ終了は `errexit` の対象外であり、これは `[[ ]]` / `(( ))` と違って**バージョンに関わらず常に成立する**（`#284` の `[[ ]]` の穴は bash 4.1 未満でだけ再現したが、`! cmd` の穴は CI の bash 5 系でも再現する）。このため `! grep -q ... "$FILE"` のような否定検査をテスト本文の途中に置くと、退行が起きても `not ok` にならず黙って pass する。issue #283 のコメントで、この書き方が `plugins/dev-workflow/tests/context-tripwire.bats:411-413` だけでなく他の bats ファイルにも多数あると報告されている。実測では `_longruns/` を除く追跡下の bats ファイルのうち 35 ファイルに行頭 `!` で始まる行が計179行あり、うち13行（`plugins/cost-ledger/tests/gate-report.bats`）は既に `! cmd || return 1` の形でガード済み、残り166行（34ファイル）が未ガードである。

## What Changes

- 対象166行（34ファイル）の、単独の文として置かれた `! cmd` 形の否定検査すべて（本文中の位置を問わず、最後の文も含む）に `|| return 1` を付ける。`plugins/cost-ledger/tests/gate-report.bats` が既に採っている形をそのまま踏襲し、issue 本文が提案する `run` + `[ "$status" -ne 0 ]` への書き換えは採らない（理由は design.md「Decisions」）。
- 対象の定義（grep 1本で機械照合できる形）と対象外（ヒアドキュメント内・`if`/`while` の条件式・複数行にまたがる文・既に `||`/`&&` で連結済みの行）を spec に明記し、ガード漏れを機械的に検査する常設テストを追加する。
- `! cmd` の非検査が bash のバージョンに関わらず常に起きることを示す実演テストを追加する（`#284` の `[[ ]]` 用の実演テストとは異なり、bash バージョン分岐は不要）。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `bats-assertion-guard`: 単独文の否定検査 `! cmd`（`! [[ ]]` を含む）もガード対象に加える要件を追加する。既存の `[[ ]]`（否定なし）の要件はそのまま変更しない。

## Impact

- 対象: `plugins/*/tests/*.bats` のうち 34 ファイル（`tests/*.bats` の 2 ファイルを含む）。`plugins/statusline/tests/statusline-multi-account.bats:215,216,303` の `! [[ ... ]]`（`#284` が明示的に本 change の範囲とした 3 箇所）を含む。
- 新規依存なし。既存の `bash scripts/test.sh` 実行方式・bats のバージョンも変更しない。
- ガードを付けた結果、現在 green だが実際は壊れていたアサーションが露呈して落ちるテストが出た場合は実装側の欠陥として別途 issue を切る（本 change の受け入れ条件外）。
