## Why

公開側のリポジトリ（flatmate 本体と Claude Harness 公開版）にオーナー固有の名前が混ざっていないかを調べる検査が、いまは flatmate の `scripts/ship-check.sh` の中にしかない。Harness 側（#1129 の受け入れ条件 2）は同じ検査を作り直すことになり、2 本あると辞書の書式と判定がずれて片方だけで漏れる。そこで、禁止語の照合と許可（allow）の期限の検査を、公開版 Harness の共有スクリプトとして切り出す。エピック genetta-inc/flatmate#1722 の子（記録先 oratta/claude-harness#1207）。

この change は共有スクリプト・その単体のテスト・辞書と allow の書式の文書までを受け持つ。Harness の CI に接続し #1168 の検索のテストを移すのは後続の change `public-names-ci-check`、flatmate 側の置き換えは genetta-inc/flatmate#1732 が受け持つ。

## What Changes

- dev-workflow プラグインの `scripts/` に `forbidden-words-check.sh` を足す。検査するファイルの一覧を標準入力、ルート・辞書・allow を引数で受け取り、本文とパス名の固定文字列一致（大文字小文字を区別しない）で禁止語を探し、違反を 1 件 1 行で標準エラーに出して終了コードで返す
- allow は 2 種類の行を持つ。flatmate の既存書式 `<path>:<語>:#<issue>`（issue が OPEN の間だけ有効、ファイルの中のその語をすべて許す）はそのまま、後続の change が #1168 の恒久の許可（ファイル・行に含まれる固定の文字列・基準）を載せるための `<path>:<語>:=<行に含まれる固定の文字列>`（期限なし、その文字列を含む行の当たりだけ許す）を足す
- 違反の文面と出す順序は flatmate の `ship-check.sh` の現行の出力を引き継ぐ。flatmate が呼び出し側を置き換えたあとも同じ違反一覧になるための契約として、引数・環境変数・終了コード・違反件数の受け渡しを spec に固定する
- 辞書の書式と allow の有効期限の規則の文書 `plugins/dev-workflow/docs/forbidden-words-check.md` を足す
- スクリプトの bats のテストを足す

## Capabilities

### New Capabilities
- `dev-workflow-forbidden-words-check`: 公開側のリポジトリに固有名が混ざっていないかを辞書で調べる共有スクリプト（呼び出しの契約・辞書の書式・allow の 2 種類の書式と期限の規則・違反の文面・flatmate からの呼び出しの契約）

### Modified Capabilities

（なし。#1168 の検索のテスト〈`harness-public-private-split`〉を共有スクリプトへ移すのは後続の change `public-names-ci-check`）

## Impact

- 足す: `plugins/dev-workflow/scripts/forbidden-words-check.sh`、`plugins/dev-workflow/tests/forbidden-words-check.bats`、`plugins/dev-workflow/docs/forbidden-words-check.md`、`plugins/dev-workflow/changes/1207.md`
- 直さない: `.github/workflows/`（聖域パス。この change では触らない）、`tests/public-private-split.bats`（後続の change）、`docs/public-private-split.md`（dev-workflow は `plugins/dev-workflow/` の行が覆うので表は直さない）
- 常時注入の固定分は増えない（スクリプトとドキュメントだけで、スキル・hook・description を足さない）
- 対象外: Harness の CI への接続と公開版の辞書（後続の change）、flatmate 側の置き換え（genetta-inc/flatmate#1732）、辞書の網羅（リポジトリごとの責務。検査の保証は「辞書に登録した語の混入を止める」まで）
