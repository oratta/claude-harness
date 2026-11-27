# Proposal

## Why

develop の実行モードは決まった入力から決まるのに、本体が毎回 SKILL.md の優先順と環境変数の正規化を読み直している。issue #1686 の残り候補から、この判定だけを既存動作のままスクリプトに移し、読ませる説明を減らす。

## What Changes

- `plugins/dev-workflow/scripts/develop-mode.sh` を追加する。`--unmanned` の有無、依頼がチャンネルから届いたことを示す `--channel-request` の有無、プロセスの `DEV_WORKFLOW_UNATTENDED` から、既存の開始コメントの 1 行を返す。
- 先に bats で優先順・印の正規化・出力と終了コードを固定する。hook は呼び出さず、変更もしない。
- SKILL.md「モードの決め方」のアルゴリズム説明を呼び方 1 行と出力の分類表に置き換える。開始コメントへの記録・モードの維持・引き継ぎ・channel.md の読み込みは動作指示として残す。
- 既存 capability の該当要件を MODIFIED で全文更新し、文面を読む Scenario と既存 bats も移動後の責務に合わせる。
- 手順書の前後の字数と bytes、固定注入と場面別予算の実測を finish の PR 本文へ残す。減った対象の予算を実測まで下げる。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 要件「実行モードは引数・印・依頼の届き方で開始時に決める」の判定主体と SKILL.md の記述契約を変更する。優先順、モード、理由、開始時・再開時の動作は維持する。

## Impact

実装対象は新しい script とその bats、SKILL.md の該当小節、`tests/develop-channel-mode.bats` の旧説明検査、影響した予算値、変更の記録。`epic-dispatch.sh`、既存 script の出力語・終了コード、hook 本体、マージ手順は変更しない。

残り候補の扱いは issue の分割判定に記録済み。(b) 片付け・待ち終了前の確認は既存出力だけでは動作を代替できないため出さない。(c) マージ待ちの入力収集は独立した次の change に分ける。今回の PR では issue #1686 を閉じない。
