## Why

`/statusline:setup` は `statusline.sh` と `statusline-codex.py` を `<config>/` にコピーして使う作りで、プラグインを更新してもコピーは古いまま残る。主の Mac では 2026-09-26 のコピーが動き続け、その後に入ったオフのアカウントの扱い（#976）・プロンプトキャッシュの表示（#714）・Codex のオフ（#978）がどれも効いていなかった。打ち直しを覚えておく以外に気づく手段が無い（issue #1113）。

## What Changes

- `install.sh` が、コピーした 2 つのファイルの内容のハッシュを `<config>/.statusline-installed` に書く（内容が既に一致していて書き換えなかったときも書く。`--dry-run` では書かない）
- statusline プラグインに SessionStart フックを足す。フックはコピーごとに次を判定する
  - 記録どおり（手を入れていない）でプラグインの本体と違う → 黙ってプラグインの本体でコピーし直し、記録を書き直す
  - 記録と違う、または記録が無い（手を入れた、またはこの仕組みより前に入れた）でプラグインの本体と違う → 上書きせず、「更新あり」の印 `<config>/.statusline-update-available` を置く
  - プラグインの本体と同じ → 記録をその内容に合わせ、印の対象から外す
- `statusline.sh` は印があるとき、1 行目の末尾に `更新あり /statusline:setup` を足す（描画のたびにハッシュを取らず、印の有無だけを見る）。印が無いときの出力は 1 バイトも変えない
- 印を読む処理を持たない古いコピー（この変更より前のコピー）は「更新あり」を描けないので、その場合だけフックがセッション開始時に同じ案内を画面に出す
- フックが上書きしてよいのは、インストール済みのプラグイン（`<config>/plugins/` の下）から起動されたときだけ。`claude --plugin-dir` で開発中の版を読み込んだセッションでは何もしない
- README の「導入」「カスタマイズ」節と `/statusline:setup` の報告の案内文を、自動で更新されることに合わせて直す

表示の中身（名前・オフ・リセット権など）には手を出さない（親エピック genetta-inc/flatmate#1656 の注意書き）。

## Capabilities

### New Capabilities
- `statusline-copy-update`: ステータスラインのコピーを、手を入れていなければセッション開始時に自動でプラグインの本体に揃え、手を入れていれば上書きせず「更新あり」を知らせる仕組み（記録ファイル・印ファイル・フック・表示の取り決め）

### Modified Capabilities
（なし。既存の statusline 系の spec は描画の中身と記録ファイルの要件で、コピーの配り方は要件に書かれていない）

## Impact

- `plugins/statusline/scripts/install.sh`（記録の書き込み）
- `plugins/statusline/hooks/hooks.json`（新規）と `plugins/statusline/scripts/statusline-update-hook.sh`（新規）
- `plugins/statusline/scripts/statusline.sh`（1 行目の末尾の表示だけ）
- `plugins/statusline/README.md`・`plugins/statusline/commands/setup.md`（案内文）
- `plugins/statusline/tests/statusline-copy-update.bats`（新規）
- `plugins/statusline/changes/1113.md`（新規）
- 利用者側: `<config>/.statusline-installed` と `<config>/.statusline-update-available` の 2 ファイルが増える。新しい依存は無い（`shasum` か `sha256sum` のどちらかを使う。macOS と Linux の標準に入っている）
