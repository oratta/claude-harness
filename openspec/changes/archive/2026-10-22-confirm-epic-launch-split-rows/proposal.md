## Why

`docs/public-private-split.md` の仕分けの表には、エピック実行の部品 5 行（`epic-dispatch.sh`・`epic-launch-orca.sh`・`stop-judge.sh`・`parent-pass-criteria.md`・`parent-merge-criteria.md`）が「保留（#1123 の後）」のまま残っている。#1123 は閉じ、`epic-dispatch.sh` は起動部品を Orca の部品と tmux の部品から選ぶ形になった。保留の行が残ったままでは #1129 の後半（個人版のリポジトリへ部品を移す change）が移す範囲を決められないので、先に表を確定する。

## What Changes

- 仕分けの表の保留の 5 行を「公開版」に確定し、理由の欄に #1123 の結果のどこを見て決めたかを書く。dev-workflow の行（分割）の理由も直す
- 分類の値「保留（#1123 の後）」を文書と検査から消す（使う行が無くなるため）。「保留の行の確定」の節は、確定した結果の記録に書き換える
- 「載せない行の基準」に、Orca の起動部品の中の行と、`epic-dispatch.sh` の中で Orca の部品の扱いを書いた行を外す項目を足す。既存の「差し替え可能な起動部品の 1 つとして Orca を並べた行」の前提（`epic-launch-orca.sh` が公開版に決まる）が満たされたので、その旨に書き換え、「起動部品の 1 つとして一覧から外した行」は一覧に戻さない
- 公開版に確定した `parent-pass-criteria.md` と `parent-merge-criteria.md` の冒頭の「Orca 経路のエピックで」を、別セッション方式の書き方に直す（Orca だけを前提にした行は「載せない行の基準」に当たらないため）
- `tests/public-private-split.bats` の「`epic-launch-orca.sh` は保留の部品なので一覧の行が落ちる」検査を、確定後の形（公開版の部品を指す一覧の行は通り、保留の値の行は落ちる）に直す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `harness-public-private-split`: 分類の値から「保留（#1123 の後）」を外す／dev-workflow の固有名の検索の対象から「保留の行のファイル」の除外を外す／起動部品の基準の前提を「#1129 で公開版に確定した」に直し、Orca の起動部品の中の行を外す基準を足す／検査の守備範囲に、確定した 5 行が公開版から外れることを落とす例外を足す

## Impact

- `docs/public-private-split.md`（表・分類の値・保留の行の確定・載せない行の基準・起動部品の 1 つとして一覧から外した行の節）
- `tests/public-private-split.bats`（`ALLOWED` の値と保留の部品の検査）
- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`・`parent-merge-criteria.md`（冒頭の 1 行ずつ）
- `plugins/dev-workflow/changes/1129.md`（変更の記録、新規）
- 部品のファイルの移動・削除は無い。オーナーの環境の動きは変わらない（後続の change `move-private-parts-to-private-repo` の入力になる）
