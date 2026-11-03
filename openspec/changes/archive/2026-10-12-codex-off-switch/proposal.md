## Why

Codex を使わない期間（解約中や使用量を使い切った期間）に、Codex を止める設定の置き場所が無い。今は 3 か所が Codex を呼び続ける。

- develop の投げ先の自動選択は、Codex の使用量を取りに行き、古い観測値の余裕で Codex を選びうる
- pr-review-gate の従来経路は、full 判定のたびに Codex を呼び、失敗を実測してから Claude のレビュアーに切り替わる。その待ち時間が毎回かかる
- ステータスラインは Codex の使用量を取りに行く

#976 で Claude のアカウントは `accounts.json` の `enabled` でオフにできるようになった。Codex も同じ操作でオフにできるようにする。エピック #980 で「Codex のレビューを続ける（full 判定の既定は Codex のまま）」と決まっているので、この change は Codex を使わない期間のための設定であって、Codex がオンのときの挙動は変えない。

## What Changes

- `accounts.json` のトップレベルに任意のキー `codex`（オブジェクト）を足し、`codex.enabled` が JSON の `false` のとき Codex をオフとして読む。省略・`true`・真偽値でない値はオン。`schema` は `1` のまま
- develop の投げ先の自動選択（`codex-develop.py` の `select_configuration`）は、オフなら Codex を候補から外し、構成 `claude-default`・reason `codex-off` を返す。Codex の使用量の取得もしない
- オフのときに Codex を使う profile、または旧形式の `--account` / `--model` を明示すると、依頼ファイルを作らず exit 2 で終わり、エラー文にオフであることと戻し方を出す。黙って Claude に差し替えない
- pr-review-gate の従来経路は、オフなら full でも Codex を試さず（バイナリ探索も呼び出しもしない）、Claude のレビュアーで行う。PR コメントの「レビュー実行者:」にオフが理由であることを書く
- ステータスラインの Codex 行は、オフなら `off` を出し、`codex` を起動せず使用量を取得しない
- オンオフを読む処理を `usage_view.py` に足し、ゲートの G が使えるよう `usage_view.py --codex-enabled`（`on` / `off` を 1 行出す）を設ける
- `codex.enabled` を書いていない環境では、自動選択の結果・レビューの経路・ステータスラインの出力のいずれも変わらない

切り替えのコマンド（#977）はこの change に含めない。確認は `accounts.json` を手で書き換えて行う。Codex のアカウントごとのオフ、モデルの格や役ごとのモデルの決め方（#616）には手を出さない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `usage-account-registry`: レジストリのトップレベルに任意の `codex` を認め、Codex のオンオフの意味と読み方（5 か所に準じる読み手の規則）を定める
- `dev-workflow-develop`: Codex がオフのときの自動選択（構成・reason・使用量を取得しない）と明示指定の拒否を定める
- `dev-workflow-pr-review-gate`: 従来モードの full で Codex がオフのとき Codex を試さないこと、オフの判定を実測の三条件とは別の「設定」として扱うこと、PR コメントの書式を定める
- `statusline-multi-account-usage`: Codex 行がオフのとき `off` を出し、取得をしないことを定める

## Impact

- コード: `plugins/dev-workflow/scripts/usage_view.py`、`plugins/dev-workflow/scripts/codex-develop.py`、`plugins/statusline/scripts/statusline-codex.py`、`plugins/statusline/scripts/statusline.sh`（`off` の行の組み立て）
- 手順書: `plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md`、`stages/triage.md`
- テスト: `plugins/dev-workflow/tests/test_codex_develop.py`、`test_usage_view.py`、`pr-review-gate-skill.bats`、`plugins/statusline/tests/test_codex.py`
- 文書: `plugins/dev-workflow/docs/codex-develop.md`、`references/codex-develop.md`、`plugins/dev-workflow/README.md`、`plugins/statusline/README.md`、両プラグインの `changes/978.md`
- 互換性: `codex` を書いていない登録簿は従来どおり。#976 の `enabled` を読む 5 か所は `accounts` だけを読み、未知のトップレベルのキーを無視するので影響を受けない。`accounts-init.sh` はトップレベルを丸ごと読み書きするので `codex` を消さない
- #616 との関係: `codex-develop.py` の `select_configuration` 周辺を触る差分は、引数 1 つと冒頭の分岐 1 つに抑える。モデルの格・役ごとのモデルには触れない
