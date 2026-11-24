# Proposal

## Why

PR #1808 のゲート一周目が failed になり、修正すべき 2 点が残った。

- 再検証の通知が stderr だけで、再開されないサブエージェントの本人に届かない。exit 0 の hook の stderr は Claude に届かず、人はデバッグログでしか見られない。受け入れ条件の「検証をやり直す作業を知らせる」「黙って古い値を使い続けない」を満たせない。
- 共通処理のロードに成功したあとで解決 API が欠けている・呼べない場合に、CLI が JSON を出さず、hook が traceback で exit 1 になる。出力契約を壊す。

## What Changes

- hook は、利用する文脈指標に `revalidation_required` があれば、stderr の診断に加えて、本人に届く `hookSpecificOutput.additionalContext` に再検証通知を出す。通知文は要求モデル・根拠モデル・対象指標・手順の絶対パスを含め、「根拠モデルと異なるため、案内した手順でしきい値を再検証する必要がある」と明示する。
- 診断だけでは締め・return・拒否を要求せず、`permissionDecision`・`decision`・`continue:false`・`systemMessage` を付けない。cap 内でも通知だけの単一 JSON を exit 0 で出す。cap 超の PostToolUse は既存の締め通知本文を保ち別段落で追記、hard 超の PreToolUse は既存の deny と理由を保ち同じ出力へ追加する。`hard <= cap` の PreToolUse は拒否せず、通知だけの JSON を出す。再検証が要らない閾値以内の stdout 空、解除・計測不能・解決失敗・正数条件違反の stdout 空・exit 0 は維持する。通知は呼出しごとに出し、状態保存や一度だけの抑制はしない。CLI は stderr と測定 JSON のまま。
- 共通処理との境界（解決 API の取得と callable 確認、呼出し、必須結果の取り出し、診断準備）の欠損・通常例外を `resolver_unavailable` にする。`invalid_table` / `invalid_override` の分類は維持し、`BaseException` や全体の握り潰しには広げない。CLI は error 文字列を持つ 1 行 JSON と exit 1、hook は stdout 空・exit 0。
- 両 Bats に、通知 JSON の解析検査と、API 欠損・非 callable・呼出し時 `RuntimeError`・必須キー欠損の戻り値の検査を追加する。`decision-criteria.md` の説明を、CLI は stderr、hook は本人への `additionalContext` と分かる形へ同期する。
- 段 A 以外のゲート指摘 18 件（テスト補強・文面の nit）は必須修正にしない。#1802 の範囲には手を出さない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-token-thresholds`: 文脈計測の診断を、stderr と hook の本人への `additionalContext` の両方に届く契約へ改め、上書き要件の stdout 例外と、解決失敗に API 欠損・通常例外を含めることを定める。
- `dev-workflow-execution-strategy`: 途中計測 hook の stdout を「再検証通知が無い場合に空」へ限定し、通知・拒否・大小逆転・閾値の間での再検証通知 JSON を許す。

## Impact

記録先は #1800（親 #1803）、PR #1808 の修正。実装で編集するファイルは次の 5 個だけ。

1. `plugins/dev-workflow/scripts/subagent-context.sh`
2. `plugins/dev-workflow/scripts/context-tripwire.sh`
3. `plugins/dev-workflow/tests/subagent-context.bats`
4. `plugins/dev-workflow/tests/context-tripwire.bats`
5. `plugins/dev-workflow/skills/develop/references/decision-criteria.md`

規模の数え方: OpenSpec artifact（この change の proposal・design・tasks・両 delta spec）、後工程で同期する主仕様 2 ファイル、`plugins/dev-workflow/changes/1808.md` の追記は仕様記録であり、上の実装 5 ファイルとは別に数える（前の change `model-context-threshold-wiring` と同じ数え方）。共通処理・JSON 表・利用手順 `token-thresholds.md`・累計経路は変更しない。#1802 の集計・見積もりは対象外。

通知の到達は Bats の出力検査と公式仕様（hooks の `additionalContext` の配送）を根拠とし、実機で観測済みとは記録しない。
