## Why

プロンプトキャッシュ（同じ前置きを安く再利用する仕組み）の読み出しは入力単価の 1/10 以下で、5 分以上の放置やセッション途中のモデル・effort 変更で切れる（公式記事 What a task costs on Opus 5.5）。今の statusline にはキャッシュが効いているかを示す表示が無く、効いていないセッションに気づけない。Claude Code 2.1.251 以降は statusline の入力 JSON に `prompt_cache`（ヒット率・ミス回数など）を渡し、2.1.260 以降は直近のミスの原因（`last_miss_cause`）も渡すので、これを 2 行目に 1 区画で出す（issue #714 の概要 1）。

## What Changes

- `statusline.sh` の 2 行目に、キャッシュヒット率の区画 `Cache <N>%` を足す。置き場所は `Context` 区画の直後（`Context 91%  │  Cache 82%  │  API …  │  Session …`）
- 直近のミスの原因が入力にあれば、同じ区画の中に `miss:<短い名前>` を続ける（例: `Cache 82% miss:tools`）。原因が複数なら先頭 1 つと残りの件数（`miss:tools+1`）
- `prompt_cache` が無い入力（2.1.251 より前の版、メイン会話の最初の API 応答の前）と、`hit_ratio` が `null` の入力では区画を出さず、標準出力は従来と 1 バイトも変わらない
- 環境変数 `STATUSLINE_PROMPT_CACHE=0` で区画を消せる（既定は表示）
- README の表示例・2 行目の説明・環境変数の表を直し、変更の記録 `plugins/statusline/changes/714.md` を書く

## Capabilities

### New Capabilities

- `statusline-prompt-cache-segment`: statusline の 2 行目にプロンプトキャッシュのヒット率と直近のミスの原因を出す区画の表示契約

### Modified Capabilities

（なし。既存の `statusline-multi-account-usage` はレートリミット行、`session-cost-record` はセッションコストの記録を扱い、どちらの要件も変えない）

## Impact

- `plugins/statusline/scripts/statusline.sh`（入力の読み取り・区画の組み立て・2 行目の連結・冒頭コメント）
- `plugins/statusline/tests/statusline-prompt-cache.bats`（新規）
- `plugins/statusline/README.md`
- `plugins/statusline/changes/714.md`（新規）
- 描画 1 回あたり `jq` の起動が 1 回増える。ファイルの読み書きとネットワークアクセスは増えない
- 動いているのはコピー先の `~/.claude/statusline.sh` なので、マージ後に `/statusline:setup` を再実行するまで表示は出ない（変更の記録に書く）
- 常時注入の予算（`tests/injection-budget.bats`）: `description` と `rules/` を変えないので測定値は動かない
