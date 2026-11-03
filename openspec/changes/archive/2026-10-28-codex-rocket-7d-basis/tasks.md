## 1. statusline の日程消化率

- [x] 1.1 `plugins/statusline/tests/statusline-headroom.bats` に、失効まで 1 日 17 時間で日程消化率 75%、失効が 7 日より先で 0%、既存の経過のテストの期待値 73% のテストを足し、実装前に落ちることを確かめる。触る範囲: plugins/statusline/tests/statusline-headroom.bats
- [x] 1.2 `plugins/statusline/scripts/statusline.sh` の Codex ロケットモードの日程消化率を、7 日分母・起点＝失効の 7 日前・起点前は 0 に切り詰めて数える。触る範囲: plugins/statusline/scripts/statusline.sh
- [x] 1.3 変更の記録 `plugins/statusline/changes/1393.md` を書く。触る範囲: plugins/statusline/changes/1393.md（新規）
