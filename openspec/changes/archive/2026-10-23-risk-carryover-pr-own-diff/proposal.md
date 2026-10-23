## Why

pr-review-gate 手順 3-c（前の HEAD の許容の引き継ぎ）は、`risk-carryover-check.sh` の判定 4 で根拠ファイルの `git diff <前 HEAD> <新 HEAD>` が空かだけを見ている。そのため PR 自身の中身が変わっていなくても、main の取り込みで根拠ファイルが動くと引き継げず、主は同じリスクの許容を聞き直される。#1245（PR #1265）では、兄弟の子が同じファイル（SKILL.md・epic.md など）をマージしただけで `CARRYOVER=no` になり、主に聞き直した。さらに判定 2 は merge commit でない commit（PR 自身の修正）を 1 件でも見つけると `NG:` を出すので、PR 自身の修正が入った HEAD はリスクの中身によらず必ず主に聞き直す。

主の決定（2026-10-23、issue #1238）は、#441・#694・エピック #725 で決めた方針（リスクの中身が同じなら、一度許容したリスクを聞き直さない）をここにも当てることで、判定の基準を「ファイルが変わったか」から「リスク宣言の中身が前と同じか」に移す。この change は、そのうち機械的に決まる部分（main から入った変更だけで根拠ファイルが動いた場合）を扱い、PR 自身の差分が変わった場合を後続の change（`risk-carryover-decider-judge`）が判定役で扱えるように、スクリプトの出力で区別する。

## What Changes

- `risk-carryover-check.sh` の判定 4 を、根拠ファイルの前後の diff が空かではなく、**根拠ファイルの PR 自身の差分**（base との merge-base からの差分）が前後で同じかで判定する形に変える。前後の diff が空でなく PR 自身の差分が同じファイルは `EVIDENCE_MAIN_ONLY=<ファイル>` の行で出し、引き継げる側にする
- PR 自身の差分が前後で違う根拠ファイルは `EVIDENCE_PR_CHANGED=<ファイル>` の行で出し、`NG:` にせず、新しい終了コード **4**（`CARRYOVER=if-judged`）を返す。あわせて、それらのファイルの前後の diff の行数の合計を `EVIDENCE_DIFF_LINES=<行数>` で出す（後続の change が判定役に渡すかの上限に使う）
- 前後どちらかの HEAD でバイナリの根拠ファイルが前後で変わったときは `NG:` にする
- 判定 2 から「merge commit でない commit がある」を `NG:` の理由から外し、その件数を `PR_COMMITS=<件数>` で出す。履歴の書き換え（判定 1）・main 以外のブランチの merge・3 親以上の merge・第 1 親が PR の履歴の外の merge は今どおり `NG:`
- 終了コードの優先順を 1（`NG:` あり）→ 4 → 3（許可リストの条件を満たさない衝突解消）→ 0 にする
- **BREAKING**（G の読み方）: 今まで終了コード 1 だった「main 側の変更で根拠ファイルが変わった」「merge commit でない commit がある」が、終了コード 0・3・4 のどれかになる。古い 3-c の文面とは組み合わせない（同じ PR で 3-c も直す）
- `pr-review-gate/stages/hold.md` 手順 3-c を直す: 冒頭の目的の文を「main の取り込みや PR 自身の修正で HEAD が動いても、リスクの中身が同じなら聞き直さない」に、スクリプトの出力と終了コードの説明に新しい行と終了コード 4 を足す。この change の時点では、**終了コード 4 は引き継がず手順 6 で主に聞き、`EVIDENCE_PR_CHANGED=` の行を引き継げなかった理由として質問に添える**（判定役に比べさせる経路は後続の change）。引き継ぎの根拠の行の「根拠ファイルの diff は空」を、空か main からの変更だけか（`EVIDENCE_MAIN_ONLY=` のファイル）を書ける形に直し、PR 自身の commit の件数を書く欄を足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: Requirement「前の HEAD の許容を新しい HEAD に引き継いでよい条件」（条件①・守備範囲・シナリオ）、「risk-carryover-check.sh が差分の範囲と根拠ファイルの無変更を判定する」（判定 2・判定 4・出力・終了コード・シナリオ）、「引き継いだ宣言の書式と合格条件」（引き継ぎの根拠の行）を変える

## Impact

- `plugins/dev-workflow/scripts/risk-carryover-check.sh`
- `plugins/dev-workflow/tests/risk-carryover-check.bats`（今の「main 側の変更で根拠ファイルが変わった → 1」「merge commit でない commit → 1」「許可リスト外の衝突解消と merge commit でない commit → 1」「サブディレクトリから呼ぶ → 1」の期待を直し、新しいケースを足す）
- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（3-c だけ）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（3-c の文面検査）
- `plugins/dev-workflow/changes/1238.md`（変更の記録。版は上げない）
- `pass.md` の合格条件の表と `gate-runner.md` は 3-c を参照するだけなので変えない見込み（実装時に確認）
- 関連: issue #1238（記録先。PR は `Refs #1238`）、#1245（main の取り込みの実例）、#441・#694（引き継ぎの既存の経路）、後続の change `risk-carryover-decider-judge`（終了コード 4 を判定役に比べさせる）
