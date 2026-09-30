## Why

develop の本体は、PR トークン上限の計測の直前に記録先の `Codex 消費:` コメントを `gh api --paginate --slurp ... | jq ... > codex-records.txt` で集めて `pr-token-budget.sh --codex-records` に渡す。`gh api` が通信障害や認証エラーで失敗しても記録ファイルは空か途中までのまま残り、そのまま集計されるので、Codex の消費が抜けた合計が exit 0（上限以内）として返る。仕様が「計測できない」ときに定めた exit 1 の経路（止まらずに進み、記録先に通知する）にも入らず、上限判定が黙って外れる（PR #399 のレビュー指摘、issue #419）。

## What Changes

- `Codex 消費:` コメントの収集を `plugins/dev-workflow/scripts/codex-records.sh` に切り出す。記録先番号ごとに取得と抽出の成否を検査し、全番号で成功したときだけ `--out` のファイルを作って exit 0 を返す。1 つでも失敗したら exit 1 を返し、`--out` のファイルを残さない（途中までの記録や前回のファイルを使わせない）
- `skills/develop/SKILL.md` の計測手順を、この収集スクリプトが exit 0 のときだけ `pr-token-budget.sh` を呼ぶ形に書き換える。収集が非 0 なら集計を呼ばず、`pr-token-budget.sh` の exit 1（計測できない）と同じ扱いにして、理由「Codex 消費コメントを取得できなかった」で記録先に通知する（1 サイクル 1 回の制限も同じ）
- 収集の成功・最初の番号の失敗・途中ページや次の番号の失敗をスタブで再現する bats テストを足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-token-budget`: 「本体は spawn と再開の前に測り、上限超なら止まる」要件で、記録ファイルの作り方を収集スクリプト経由にし、取得失敗を exit 1（計測できない）の経路に合流させる。収集スクリプトの振る舞い（全番号成功時だけファイルを作る）を要件として足す

## Impact

- 追加: `plugins/dev-workflow/scripts/codex-records.sh`、`plugins/dev-workflow/tests/codex-records.bats`
- 変更: `plugins/dev-workflow/skills/develop/SKILL.md`（PR トークン上限の節）、`plugins/dev-workflow/tests/develop-skill.bats`（SKILL.md の手順の文言テスト）、`plugins/dev-workflow/changes/419.md`
- `pr-token-budget.sh` は変えない（GitHub を読まない性質を保つ）
- 依存: `gh`・`jq`（従来の手順と同じ）
