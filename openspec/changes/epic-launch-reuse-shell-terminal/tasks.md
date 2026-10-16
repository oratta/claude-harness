## 1. launch が最初の端末を再利用する

- [x] 1.1 `shell_start`（子のパスと起動コマンドを受け、端末数が 1 なら起動コマンドを `terminal send --enter` で打ち込み、一覧を引き直して Claude Code になるのを待つ。戻り値 0 起動済み・1 端末 0 個・3 失敗）を足し、`cmd_launch` の `terminal create` の前で呼ぶ。1 のときだけ従来の `terminal create` に進む。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:263-300（`cmd_launch` の直前に新規関数）、plugins/dev-workflow/scripts/epic-dispatch.sh:340-370（`cmd_launch` の端末作成部分）
- [x] 1.2 ヘッダコメントの launch の説明に、最初の端末の再利用を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:21-30

## 2. テスト

- [x] 2.1 launch の呼び出し順のテストを、`terminal list` の呼び出しが入る形に直す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:488-520
- [x] 2.2 シェルの端末を再利用する場面（端末 1 つ・Claude Code になる）、Claude Code にならない場面、端末 2 個、一覧が読めない場面のテストを足す。スタブに `tlist_after_<N>`（起動コマンドが届いたあとの一覧）を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:75-90（terminal list のスタブ）、plugins/dev-workflow/tests/epic-dispatch.bats:520-570（launch のテストの並び）

## 3. 記録と検証

- [x] 3.1 変更の記録 `plugins/dev-workflow/changes/1055.md`（新規）を書く
- [x] 3.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats`、`scripts/lint.sh`、`openspec validate --specs --strict`、`openspec validate epic-launch-reuse-shell-terminal --type change --strict` を通す
- [ ] 3.3 （本体の作業。W は行わない）受け入れ条件 2 の実機確認: 実機の Orca で launch した子のワークツリーの `orca terminal list` が 1 行で、その端末が Claude Code であることを確かめる。触る範囲: なし（実行だけ）
