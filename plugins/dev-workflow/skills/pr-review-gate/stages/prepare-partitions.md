# prepare-partitions — pr-review-gate

**区画の判定（一周目のレビューだけ）**: light / full の行数判定は上記のまま行う。別に、PR files API のファイルごとの追加＋削除を `${CLAUDE_PLUGIN_ROOT}/scripts/review-partitions.sh` に渡し、合計が 600 行を超えたらファイル単位の区画を作る。files API が返す順に 400 行以下を目安に詰め、1 ファイルで 400 行を超えるものは単独の区画にする。0 行のファイルは直前の区画（先頭なら区画 1）に置く。`${CLAUDE_PLUGIN_ROOT}` が未設定のときは、この段のファイル（stages/prepare.md）の位置から `../../../scripts/review-partitions.sh` を絶対パスに解決して使う。入力は 2 段で作る（1 本のパイプにしない。パイプだと `gh api` が失敗しても空の入力が渡り、「合計 0 行」と区別できない）。

`review-partitions.sh` の取得・検査コマンドは `stages/prepare.md` で既に実行済みの出力を使い、重ねて取得しない。
