## Why

公開版 Harness の部品に、決めた固有名（オーナーのプロジェクト名や PC のパス）が戻っていないかの検索は、いまは `tests/public-private-split.bats`（#1168）の中の正規表現と許可リストにある。一方、同じ種類の検査は共有スクリプト `plugins/dev-workflow/scripts/forbidden-words-check.sh`（change `forbidden-words-check`、PR #1210 で main に入った）に切り出された。2 本のままだと、語と判定が bats とスクリプトに分かれ、片方だけで漏れる。そこで #1168 の検索と許可リストの鮮度の検査を共有スクリプトの呼び出しに置き換え、語は辞書のファイルにだけ置く。エピック genetta-inc/flatmate#1722 の子（記録先 oratta/claude-harness#1207。受け入れ条件 1 本目「Harness の CI が公開版の部品に対して禁止語検査を実行し、固有名を 1 つ足すと落ちる」を満たす change）。Harness の CI は `scripts/test.sh` で bats の全スイートを回すので、bats の検査が共有スクリプトを呼べば CI で走る。

## What Changes

- 公開版の部品に対する辞書を `tests/public-names/dict/` に置く。語は今の `tests/public-private-split.bats` にすでに書かれている語だけ（`moko`・`suimei`・`uranai`・`shukan`・`sns-autopilot`・`flatmate`・`new-resident`・`/Users/oratta`・`CLAUDE_HARNESS_DEV_DIR`）。新しい固有名は公開側に書かない
- #1168 の許可リスト（`NONDEV_ALLOW`・`DEVWF_ALLOW`）を、共有スクリプトの恒久の書式 `<path>:<語>:=<行に含まれる固定の文字列>` の allow ファイルに移す。各行の直前に基準（出典・互換）をコメントで書く
- `tests/public-private-split.bats` の語の検索 5 本（dev-workflow 以外 2 本・dev-workflow 3 本）と許可リストの鮮度の検査 2 本を、検索範囲の決定と共有スクリプトの呼び出しだけにする。語の正規表現と許可リストの配列は bats から消す。固有名を 1 つ足すと落ちること・許可された行は通ること・同じファイルの別の行に書くと落ちることを、置き換えと同じ bats で固定する
- 検索が大文字小文字を区別しなくなる（共有スクリプトの規則）。この差で新しく当たる行は 2 行（`Uranai で実証` と書いた `plugins/worktree/scripts/wt-setup.sh` と `plugins/worktree/skills/wt-setup/SKILL.md`）で、出典として名前を挙げる行なので、既存の基準「出典」で許可に載せる
- `harness-public-private-split` の 2 つの検索の要件を MODIFIED にし、公開版の辞書の要件を ADDED にする
- `docs/public-private-split.md` の許可リストの置き場の記述を新しい置き場に直す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities
- `harness-public-private-split`: 「dev-workflow 以外の公開版の部品は決めた固有名とオーナーの PC のパスを持たない」「dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない」の 2 要件を、共有スクリプトの呼び出し・辞書・allow ファイル・大文字小文字を区別しない照合に直す。「公開版の辞書は公開済みの語だけを持ち、語は辞書にだけ書く」を足す

## Impact

- 足す: `tests/public-names/dict/*.txt`（6 本）、`tests/public-names/allow/nondev.txt`
- 直す: `tests/public-private-split.bats`（語の検索と鮮度の検査の部分だけ。表と一覧の形・網羅の検査と配る候補の 6 ファイルの検査は触らない）、`docs/public-private-split.md`（許可リストの置き場の 1 行）
- 直さない: `.github/workflows/`（聖域パス。CI は `scripts/test.sh` で bats を回すので不要）、`plugins/dev-workflow/scripts/forbidden-words-check.sh` とその文書・テスト（change `forbidden-words-check` の成果物。規則を変えない）、`tests/injection-budget.txt`（常時注入の固定分は増えない）
- プラグインの配布物は変わらないので、`plugins/*/changes/` の記録は足さない
- 対象外: flatmate 側の置き換え（genetta-inc/flatmate#1732）、辞書の網羅（検査の保証は「辞書に登録した語の混入を止める」まで）、「配る候補の 6 ファイル」の検査（#1098。別の語と範囲を持つ）
