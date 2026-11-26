# Proposal

## Why

`risk-carryover-check.sh` は根拠ファイルの PR 自身の差分を、`-U0` の削除・追加の行の並びだけで前後比較し、行の位置を見ない。そのため PR の修正が根拠ファイルの中で自分の足した行を同じ本文のまま別の場所へ動かすと、位置が変わって意味が変わりうるのに `EVIDENCE_MAIN_ONLY=`（main から来た変更だけ）と判定され、判定役を通らずに主の許容が次の HEAD へ引き継がれる（issue #1303。#1270 の作業中に push 時の自動セキュリティレビューが指摘）。

## What Changes

- `risk-carryover-check.sh` の判定 4: 前後の diff が空でない根拠ファイルについて、前の HEAD のあとに積まれた merge commit でない commit（PR 自身の commit）のどれかがそのファイルに触れていれば、PR 自身の差分が同じでも `EVIDENCE_MAIN_ONLY=` にせず `EVIDENCE_PR_CHANGED=` に出す（終了コード 4。判定役に差分を読ませる経路）
- 終了コード 4 の意味を「根拠ファイルの PR 自身の差分が前後で違うか、PR 自身の commit が根拠ファイルに触れた」に広げ、スクリプトの頭のコメントと `skills/pr-review-gate/stages/hold.md` 3-c の説明をそれに合わせる
- 守備範囲の「範囲外」から「同じ行の並びを別の場所へ動かしても同じと判定されること」を外し、残る隙間（merge commit の衝突解消による行の移動は終了コード 3 の全体レビューで受ける）と、新たに生じる誤検出（変えて戻した上に main が同じファイルを変えたときの終了コード 4）を書く
- 終了コード 0 / 3 / 1 / 2 の意味と出力の行の形は変えない。終了コード 4 になる場合が増えるだけで、どれも主に聞く側か判定役に回る側（安全側）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「risk-carryover-check.sh が差分の範囲と根拠ファイルの PR 自身の差分を判定する」の④と `EVIDENCE_MAIN_ONLY=` / `EVIDENCE_PR_CHANGED=` の条件、終了コード 4 の意味。要件「前の HEAD の許容を新しい HEAD に引き継いでよい条件」の終了コード 4 の説明と守備範囲

## Impact

- `plugins/dev-workflow/scripts/risk-carryover-check.sh`
- `plugins/dev-workflow/tests/risk-carryover-check.bats`
- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（3-c の呼び方のブロックと終了コード 4 の説明の文言）
- `plugins/dev-workflow/changes/1303.md`（新規）
- 判定役・判定の記録・引き継ぎの宣言の書式は変えない。判定役に渡す差分（前後の HEAD の根拠ファイルの diff）には行の移動がそのまま現れる
