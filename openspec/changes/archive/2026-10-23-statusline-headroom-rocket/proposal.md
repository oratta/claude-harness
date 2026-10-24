## Why

ステータスラインの右端には今「リセット3回・最短あと1日20h」と出るだけで、リセット権（使用率を 0 に戻せる権利）が使える量にも期限にも入っていない。次の週次リセットより前に切れるリセット権は使わないと失うのに、画面からはそれが分からない（oratta/claude-harness#1302）。headroom の計算（oratta/claude-harness#1300）が `.headroom.json` にアカウントごとのリセット権の扱いを書くようになるので、statusline はそれを読んで見せ方だけを変える。見せ方は 2026-10-23 にオーナーが決めた 1 行案（genetta-inc/flatmate#1711 の同意の記録）に従う。

## What Changes

- `plugins/statusline/scripts/statusline.sh` が `${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json`（schema 1）を読む。計算はせず、書かれた値（リセット権の数・最短の失効・使える量）を表示に使うだけ。プラグインをまたぐコードの依存は作らない
- ファイルが新しく、アカウントの `status` が `ok` のときだけ、そのアカウントの行をロケットモード（次の週次リセットより前に切れるリセット権がある状態）の描き方にする。どれにも当たらなければ今と 1 バイトも変わらない
- ロケットモードの行は、バーの前に 🚀（Claude で 2 枚以上なら 🚀2）を出し、名前の地をオレンジにする
- Claude のロケットモードでは、該当 1 枚ごとに使える量へ 100% を足し、足した分のバーの空きを青で塗り、数字を「使った / 使える」（例 `20/200%`）とその割合・経過（例 `10%/59%`）にする
- Codex のロケットモードでは、経過の線と残り時間をリセット権の失効に対して描き、週次リセットまでの時間をかっこに灰色で添える
- 右端のリセット権の区画を、`.headroom.json` が使えるアカウントでは `🚀×N ~1d 20h` に置き換える（ロケットモードの Claude はオレンジ、そのうち失効まで 24 時間以内は赤。ロケットモードでなければ灰色。Codex のロケットモードは `🚀×N` だけ）
- **BREAKING（表示）**: Claude の表示が 1 アカウントで Codex の行が出るとき、Claude の行にも名前の列を出す（今は出ないので Codex の行とバーの位置がずれる）。Codex の行が出ないときの 1 アカウント表示は今と同じ

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `statusline-multi-account-usage`: `.headroom.json` を読んでロケットモードを描く要件を足す。1 アカウント表示でも Codex の行が出るときは名前の列を出すように、「スロットが 1 つのときは現行と同一の出力にする」と「Codex の行の名前は Codex とアカウント名にする」を変える

## Impact

- コード: `plugins/statusline/scripts/statusline.sh`（`.headroom.json` の読み取り、`bar2` / `bar_seg` の拡張、Claude と Codex の行の組み立て、1 アカウント時の名前の列）
- テスト: 新しい `plugins/statusline/tests/statusline-headroom.bats`。`plugins/statusline/tests/statusline-multi-account.bats` の「the codex.label row never becomes a slot」と、`plugins/statusline/tests/statusline-reset-grants.bats` の「reset grants: the Codex row output is the same as before the shared formatter」（origin/main との比較を Codex の行だけに絞る）は期待が変わる
- 依存: oratta/claude-harness#1300 が書く `.headroom.json` の schema 1。この change の時点では #1300 の書式が確定していないので、仕様は design.md の「仮に置いた JSON の形」を前提にし、実装の前に #1300 の確定版と突き合わせて合わせる
- 描画 1 回あたりの外部プロセス: `.headroom.json` があるときだけ jq を 1 回増やす。無いときは増やさない
