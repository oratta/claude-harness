# Proposal

## Why

子が自分の背景作業を待つ間のキャッシュ維持には終了上限がなく、会話20万トークンの24時間の維持は約 $2.52 となり、最後に一度だけ書き直す $1.60 を超える。主の決定（2026-11-23、親経由で確認済み）に従い、停止済み子の維持と同じ12時間に上限をそろえる。

## What Changes

- 最初の維持タイマーを置いた時刻を待ちの基点として保持し、再設置で更新しない。
- 自己通知の受信後の再設置条件に、基点から12時間未満であることを加える。12時間に達したら次のタイマーを置かず、元作業と実行IDを保持して完了通知を待ち続け、届いたときの一度の書き直しを受け入れる。
- #1743 に新しい費用比較コメントを追加し、手順書と変更記録を12時間上限に合わせる。旧会話部分の維持費は約 $1.32、1h TTL の一度の書き直しは $1.60 として比較し、追加費用と実機確認を分ける。
- 上限・基点・上限後の元作業保持を契約テストで検査する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-child-background-wait`: 初回タイマーを基点とする12時間上限、上限後の完了待ち継続、上限を反映した費用比較を定める。

## Impact

対象は `plugins/dev-workflow/skills/develop/references/child-background-wait.md`、`plugins/dev-workflow/tests/child-background-wait.bats`、`plugins/dev-workflow/changes/1743.md` と #1743 の追加コメント。単一 capability・一つの上限決定に閉じるため単一 change とする。`SKILL.md`、起動時・常時注入の予算、親の待機機構や元作業の実行契約は変更しない。
