# prepare-partitions — pr-review-gate

入口: 一周目で取得・照合済みのファイルごとの追加＋削除の合計が 600 行を超えるときだけ読む。

**区画の詰め方（一周目のレビューだけ）**: light / full の判定は `stages/prepare.md` の手順 2-0 のまま行う。`review-partitions.sh` の ROOT の解決・入力の作り方・失敗したときの止め方は `stages/prepare.md` の「区画の判定」が正本。PR files API のファイルごとの追加＋削除の合計が 600 行を超えたらファイル単位の区画を作る。files API が返す順に 400 行以下を目安に詰め、1 ファイルで 400 行を超えるものは単独の区画にする。0 行のファイルは直前の区画（先頭なら区画 1）に置く。

`review-partitions.sh` の取得・検査コマンドは `stages/prepare.md` で既に実行済みの出力を使い、重ねて取得しない。

出口: `stages/prepare.md` の手順 2-0 の区画の判定へ戻る。
