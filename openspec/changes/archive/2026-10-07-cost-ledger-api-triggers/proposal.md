## Why

節目ごとのコスト行（#303）がきっかけにするのは `gh pr comment` などの 7 種のコマンドと合格ラベルの付与だけで、`gh api` の REST で行った投稿・クローズ・マージと、`gh pr create` / `gh pr reopen` には行が付かない。このリポジトリでは `gh pr edit` / `gh issue view` が GraphQL エラーになるためエージェントは `gh api` で投稿やクローズをすることが多く、その節目が履歴から抜ける。PR を作った時点の行も無いので、最初の行の増分が「PR を作るまで」と「最初のコメントまで」を合わせた値になる（issue #697、エピック #272 の子）。

あわせて、`gh api` の引数の読み方の誤りを直す。合格ラベルの付与の判定（`api_targets()`）は endpoint 以外の引数（`--input` の値など）からもラベルのパスを拾うので、コマンドが触れていない PR を「ゲート通過」の対象にすることがある（#697 のコメント、PR #704 のレビュー指摘）。

## What Changes

- `gh api` の次の呼び出しをきっかけに足す。行の書式・コメントの形・裏で動かす作りは #303 のまま
  - `repos/<owner>/<repo>/issues/<番号>/comments` への POST → `issue コメント`（番号が PR なら `PR コメント`）
  - `repos/<owner>/<repo>/pulls/<番号>` への PATCH で `state=closed` / `state=open` → `PR クローズ` / `PR 再オープン`
  - `repos/<owner>/<repo>/issues/<番号>` への PATCH で `state=closed` / `state=open` → `issue クローズ` / `issue 再オープン`（番号が PR なら PR の呼び名）
  - `repos/<owner>/<repo>/pulls/<番号>/merge` への PUT → `マージ`
- `gh pr create` をきっかけ `PR 作成`、`gh pr reopen` をきっかけ `PR 再オープン` として足す（呼び名を 2 つ新設する）。`gh pr create` の対象は `cwd` のブランチ（`-H` / `--head` があればそのブランチ）をヘッドに持つ PR
- `gh issue reopen` に渡された番号が PR だったときは、積まずに捨てていたのを `PR 再オープン` として積む（PR の再オープンがきっかけの表に入るため）
- `gh api` の引数は、位置引数である endpoint を 1 つだけ読み、各オプションの値を endpoint の候補から除く。合格ラベルの `labels[]=agent-review:passed` は `-f` / `-F` / `--raw-field` / `--field` の値としてだけ認める
- fast path（`gate-report.sh`）に `gh pr create`・`gh pr reopen` と、「`gh api` を含み、`/issues/` か `/pulls/` を含み、書き込みを示すオプションを含む」の条件を足す。`gh api` の読み取り（GET）では `python3` を起動しない
- hook 1 回の同期部分の所要時間と `gh` の呼び出し回数を変更の前後で実測して PR に書く（エピック #272 の「全体の制約」）

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `cost-ledger-timeline`: 「行を積むきっかけ」「対象の解決」「状態の変更は実測してから積む」「`gh` の呼び出し回数」を改め、「`gh api` の呼び出しの読み方」を足す
- `cost-ledger-gate-report`: 「ゲート通過を PostToolUse の hook で捕まえる」（fast path の文字列）と「ラベル付与コマンドの判定と対象 PR の取り出し」（endpoint だけを読む。`{owner}/{repo}` の endpoint での付与も対象にする。守備範囲を書く）を改める

## Impact

- `plugins/cost-ledger/scripts/gate-report.sh`（fast path）
- `plugins/cost-ledger/scripts/gate_report.py`（きっかけの判定・対象の確認。`stack()` と `cost_ledger.py` は触らない）
- `plugins/cost-ledger/tests/gate-report.bats`
- `plugins/cost-ledger/README.md`（きっかけの表と「やらないこと」の記述）、`plugins/cost-ledger/changes/697.md`（変更の記録）
- `hooks.json` は変えないので `/reload-plugins` は要らない
- 並行する PR #744（#691 の後追い）と同じファイルに触る箇所: `gate_report.py`（#744 は `stack()` だけ。この change は触らない）、`openspec/specs/cost-ledger-timeline/spec.md` の「行を積むきっかけ」の守備範囲の段落の 1 文、`README.md` の「やらないこと」の 1 文。扱いは design に書く
