## ADDED Requirements

### Requirement: 子セッションの起動コマンドの既定は bin/cld の絶対パスである
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、環境変数 `EPIC_DISPATCH_CLAUDE_CMD` が未設定のとき、起動コマンドの既定として `plugins/dev-workflow/bin/cld` の絶対パス（スクリプト自身の位置から求める。空白などを含むパスは単一引用符で包む）を使わなければならない（SHALL）。ログイン zsh に定義されたシェル関数 `cld` に頼ってはならない（MUST NOT）。`bin/cld` が存在しないときだけ従来の `cld` に戻す。`EPIC_DISPATCH_CLAUDE_CMD` が設定されていれば（空文字を除く）その値を今までどおりそのまま使い、空文字なら使い方を出して exit 1 で終わる。

この要件より前の要件のシナリオが `cld --model …` のように書いている起動コマンドの先頭の語は、この既定の語（`bin/cld` の絶対パス）を指す略記として読む。

#### Scenario: 環境変数が未設定でも非ログインシェルから子を起動できる
- **WHEN** `EPIC_DISPATCH_CLAUDE_CMD` が未設定で PATH に `cld` が無い非ログインシェルのスタブ環境で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `orca terminal create` の `--command` の先頭の語は `plugins/dev-workflow/bin/cld` の絶対パスで、stdout は `launched 11`、exit 0

#### Scenario: 環境変数の指定は既定より優先する
- **WHEN** `EPIC_DISPATCH_CLAUDE_CMD='cld-account b'` で `epic-dispatch.sh launch 400 11` を実行する
- **THEN** `--command` は `cld-account b` で始まる（既定の絶対パスは使われない）
