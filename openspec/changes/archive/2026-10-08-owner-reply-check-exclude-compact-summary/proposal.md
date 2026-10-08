## Why

`owner-reply-check.sh` は、pr-review-gate が会話で受けたリスク許容の返事を「主の発言として会話ログに実在するか」で確かめるスクリプトで、ゲート通過条件の判定に使われる。会話の圧縮後にモデルが書いた要約の行は `type: "user"` で `isMeta` も `origin` も無いため、現在の 7 条件をすべて通り、主の発言として数えられうる（PR #748 / issue #721 の 2 周目レビューの残差。issue #756）。要約は過去の会話をモデルが言い換えた文なので、主が言っていない許容の言い回しが入ることがある。

## What Changes

- `owner-reply-check.sh` の主の発言の判定に 8 条件目「`isCompactSummary` が true でない」を足す。判定は行の属性だけで行い、本文の接頭辞は見ない
- `plugins/dev-workflow/tests/owner-reply-check.bats` に、要約の行を通さない回帰テスト（本文が `This session is being continued…` で始まる形と、別の文字列で始まる形）と、`isCompactSummary: false` の行は通すテストを足す
- spec `dev-workflow-owner-reply-check` の条件の列挙（①〜⑦ → ①〜⑧）と守備範囲の「7 条件」を 8 条件に揃える。スクリプト冒頭のコメントの条件一覧も揃える

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-owner-reply-check`: 要件「主の発言として数える行と数えない行」に 8 条件目（`isCompactSummary` が true でない）と、そのシナリオを足す

## Impact

- `plugins/dev-workflow/scripts/owner-reply-check.sh`（判定関数 `owner_text` と冒頭コメント）
- `plugins/dev-workflow/tests/owner-reply-check.bats`
- `plugins/dev-workflow/changes/756.md`（新規。変更の記録）
- 呼び出し側（`skills/pr-review-gate/stages/pass.md` 手順 5・`hold.md` 手順 3-c）の手順と出力の形式は変わらない。要約の行が `MATCH:` に出なくなるだけ
