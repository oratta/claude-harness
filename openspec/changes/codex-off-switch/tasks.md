行番号は仕様づくりの時点（HEAD 7225146d）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。テストは各節の実装より先に書き、落ちることを見てから実装する。#616 の子が同じ `codex-develop.py` を触る予定なので、この change の差分は `select_configuration` の引数 1 つと冒頭の分岐 1 つ、`automatic_selection` と `build_request` の分岐に限り、モデルの格・役ごとのモデルには触れない。

## 1. オンオフの読み取り（usage_view.py）

- [ ] 1.1 `plugins/dev-workflow/tests/test_usage_view.py` に、`codex.enabled` が `false` / `true` / 省略 / `"false"` / `0` / `null` の 6 つと `"codex": false`（オブジェクトでない）で `false` だけがオフに読まれること、ファイル無し・壊れた JSON・トップレベルが配列でオンに読まれること、`read_slots` / `read_registry` の戻り値が `codex` の有無で変わらないこと、`--codex-enabled` が `on` / `off` の 1 行を出して exit 0 になることのテストを足す。触る範囲: plugins/dev-workflow/tests/test_usage_view.py:320-374（末尾に新しいクラスを足す）
- [ ] 1.2 `usage_view.py` に `read_codex_enabled(path)`（`codex` がオブジェクトで `enabled is False` のときだけ偽、それ以外は真）を足し、`main` に `--codex-enabled` を足す（登録簿のパスは `default_paths()["accounts_file"]`）。`--json` の出力は変えない。冒頭の docstring に 1 行足す。触る範囲: plugins/dev-workflow/scripts/usage_view.py:1-16（docstring）、plugins/dev-workflow/scripts/usage_view.py:94-101（`read_registry` の後ろに足す）、plugins/dev-workflow/scripts/usage_view.py:254-275（`main`）
- [ ] 1.3 `python3 -m pytest plugins/dev-workflow/tests/test_usage_view.py` が exit 0 になることを確かめる（この PC の `python3` に pytest が無いときは、`uv run --no-project --with pytest python -m pytest -p no:cacheprovider <同じファイル>` で確かめ、実施時の記録に書く）。触る範囲: なし（実行のみ）

## 2. develop の自動選択と明示指定（codex-develop.py）

- [ ] 2.1 `plugins/dev-workflow/tests/test_codex_develop.py` に、spec の dev-workflow-develop の Scenario 6 件を足す: オフなら Codex の余裕が Claude より大きくても `claude-default`・`codex-off`／オフで Claude にも余裕が無くても `codex-off`／オフで `read_codex_usages`（またはそれが呼ぶ取得）が呼ばれない／オフで `--profile codex-standard` が exit 2 でエラー文にオフ／オフで旧形式が exit 2／`--account-home` 無しの profile でもエラー文がオフ（`account is not registered` ではない）／`codex` 無し・レジストリ無し・`enabled: true` の 3 つで selection evidence が同一で `enabled` キーが無い（既存のテストが通り続けることに加えて 1 本で確かめる）。登録簿は `CLAUDE_ACCOUNTS_FILE` を一時ファイルに向けて作る。触る範囲: plugins/dev-workflow/tests/test_codex_develop.py:355-380（`select_configuration` のテストの並び）、plugins/dev-workflow/tests/test_codex_develop.py:470-520（明示指定と自動選択のテストの並び）、plugins/dev-workflow/tests/test_codex_develop.py:578-700（自動選択の足場）
- [ ] 2.2 `select_configuration` に `codex_enabled=True` を足し、偽なら先頭で `('claude-default', 'codex-off')` を返す。`automatic_selection` は `usage_view.read_codex_enabled` で読み、オフなら `read_codex_usages` を呼ばず、`codex` ブロックを `{'account': None, 'margin': None, 'fetched_at': None, 'enabled': False}` にする。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:96-105（`select_configuration`）、plugins/dev-workflow/scripts/codex-develop.py:271-292（`automatic_selection`）
- [ ] 2.3 `build_request` の明示指定の分岐（旧形式と `--profile`）で、オフなら `RuntimeError`（エラー文は `codex is off: set "codex"."enabled" to true or remove it in <登録簿のパス>`）。profile は、オフのときだけ `load_profile(..., accounts=None)` で先に読んで executor が `codex` の role があるかを確かめ、無ければ通常どおり読み直す。この拒否は `account_homes` の検査や `account is not in the account-home table` より先に置く。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:500-541（`build_request` の分岐）、plugins/dev-workflow/scripts/codex-develop.py:393-416（`load_profile`。変更は不要で、呼び方の確認のみ）
- [ ] 2.4 `python3 -m pytest plugins/dev-workflow/tests/test_codex_develop.py` が exit 0 になることを確かめる（pytest が無い PC では 1.3 と同じ代替）。触る範囲: なし（実行のみ）

## 3. pr-review-gate の従来経路（手順書）

- [ ] 3.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に次の新規テストを足す: `review-run.md` の「従来モードの不可判定」に `Codex オフ` と `usage_view.py --codex-enabled` があること、オフのとき Codex を呼ばない（バイナリ探索もしない）と書かれていること、オフが実測の三条件ではなく設定であると書かれていること、証拠欄の雛形に `未実行（Codex オフ）` があること、`triage.md` の「レビュー実行者:」の書式に `（full・Codex オフ）` があること、オフの判定を書いたのが `review-run.md` の 1 か所だけであること（`gate-runner.md` などに同じ手順が再掲されていない）。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:300-340（レビュー実行者の部分のテストの並び）
- [ ] 3.2 `stages/review-run.md` を直す: 2-1 の表の「既定」行の使う条件に「Codex がオンのとき」を足し、表の下に「Codex がオフのとき」の節を足す（full と判定したあと Codex を試す前に `python3 <dev-workflow>/scripts/usage_view.py --codex-enabled` を実行し、`off` ならバイナリ探索も呼び出しもせず Task サブエージェントに回す。オフは設定であって、三条件の実測ではない）。「従来モードの不可判定」の冒頭にオフは三条件とは別と一言添える。証拠の雛形に `Task サブエージェント（full・Codex オフ）` と `未実行（Codex オフ）` を足す。「G として動くとき」の表の full の行にオフの扱い（`needs-reviewer`、根拠 `Codex オフ（設定）`）を足す。同じ手順を別のファイルに再掲しない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md:13-26（表）、plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md:30-40（不可判定と雛形）、plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md:84-100（G の表）
- [ ] 3.3 `stages/triage.md` の「レビュー実行者:」の書式に `レビュー実行者: Task サブエージェント（full・Codex オフ）` を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:136-140
- [ ] 3.4 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 4. ステータスライン

- [ ] 4.1 `plugins/statusline/tests/test_codex.py` に、spec の statusline-multi-account-usage の Scenario を足す: オフなら `off` の 1 行で、`STATUSLINE_CODEX_BIN` の起動記録スタブが 1 回も呼ばれず `.statusline-codex` が作られない／`auth.json` が有効で既存のキャッシュがあってもオフなら `off` だけでキャッシュは読まれず内容も変わらない／`auth.json` が無くても `off`／`--refresh` は標準出力が空で何もしない／`false` だけがオフ（6 つの値）／`codex` 無しと `enabled: true` で出力が一致。`statusline.sh` 経由の行（`Codex` に `off` が続く 1 行）と `STATUSLINE_CODEX=0` の優先は `plugins/statusline/tests/statusline.bats` に足す。触る範囲: plugins/statusline/tests/test_codex.py:121-225（`RenderTests`）、plugins/statusline/tests/statusline.bats（Codex 行のテストの並びを探して足す）
- [ ] 4.2 `statusline-codex.py` に、登録簿の `codex.enabled` を読む処理を自前で足し（`CLAUDE_ACCOUNTS_FILE` → `${CLAUDE_CONFIG_DIR:-~/.claude}/accounts.json`。`usage_view.py` は読まない）、`main` の先頭で、オフなら通常の描画は `off` と改行の 1 行を出して戻る（`--refresh` のときは何も出さずに戻り、標準出力は空）。`statusline.sh` は `off` を `pending` の行と同じ組み立てで `DIM` の `off` にする。触る範囲: plugins/statusline/scripts/statusline-codex.py:179-200（`main`）、plugins/statusline/scripts/statusline.sh:518-523（`codex_rows` の取得）、plugins/statusline/scripts/statusline.sh:806-815（`pending` の分岐の隣）
- [ ] 4.3 `python3 -m pytest plugins/statusline/tests/test_codex.py` と `bats plugins/statusline/tests/statusline.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 4b. accounts-init.sh が codex を消さないこと

- [ ] 4b.1 `plugins/dev-workflow/tests` の `accounts-init` のテスト（bats。無ければ `account-selector.bats` の登録簿を作る足場の隣）に、`"codex": {"enabled": false}` を持つレジストリへ `accounts-init.sh --id a --label A2` を実行しても、`a` の `label` が変わり、トップレベルの `codex` が `{"enabled": false}` のまま残ることのテストを足す。実装の変更は不要の見込み（既存の書き戻しは文書全体を保つ）で、落ちたときだけ `accounts-init.sh` を直す。触る範囲: plugins/dev-workflow/tests（`accounts-init` を呼ぶ bats を grep で探して足す）、plugins/dev-workflow/scripts/accounts-init.sh:74-95（確認のみ）

## 5. 文書と変更の記録

- [ ] 5.1 `plugins/dev-workflow/docs/codex-develop.md` と `plugins/dev-workflow/references/codex-develop.md` の自動選択の段落に、`codex.enabled` が `false` のときの挙動（構成 `claude-default`・reason `codex-off`、明示指定は拒否）を 1 文ずつ足す。既存のテストが要求する語（`claude-write-codex-review`・`margin`）は消さない。触る範囲: plugins/dev-workflow/docs/codex-develop.md:24、plugins/dev-workflow/references/codex-develop.md:9-17
- [ ] 5.2 `plugins/dev-workflow/README.md` の `enabled` の節の隣に、Codex をオフにする書き方（`"codex": {"enabled": false}`）と戻し方を足す。`plugins/statusline/README.md` の Codex の節に `off` の表示とオフの書き方を足す。触る範囲: plugins/dev-workflow/README.md:82、plugins/statusline/README.md:199-216
- [ ] 5.3 変更の記録を `plugins/dev-workflow/changes/978.md` と `plugins/statusline/changes/978.md` に書く。置き場所の決定（`accounts.json` のトップレベル `codex.enabled`）と理由（design.md の決定 1 の表の要約と、別ファイルへ戻す条件）、オフになる条件が `false` との一致 1 つであること、#616 に足した差分を小さく保ったこと、戻し方を書く。形式は `plugins/dev-workflow/changes/976.md` に揃える。触る範囲: plugins/dev-workflow/changes/978.md（新規）、plugins/statusline/changes/978.md（新規）
- [ ] 5.4 `bats tests/injection-budget.bats` と、触ったプラグインのテスト一式（`bats plugins/dev-workflow/tests plugins/statusline/tests` と `python3 -m pytest plugins/dev-workflow/tests plugins/statusline/tests`）が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 6. 実機確認（実装の段の外。PR の実装が揃ったあと、マージの前に本体が行う。テストでは代えない）

- [ ] 6.1 実機の `accounts.json` のトップレベルに `"codex": {"enabled": false}` を手で足し、full 判定になる PR を 1 本、**従来経路**（`レビュー経路: 従来`。adapter 経路では `Task サブエージェント（full・Codex オフ）` のコメントが出ないため使えない）のゲートに通して、PR コメントの `レビュー実行者:` に `Task サブエージェント（full・Codex オフ）` が出ること、Codex が呼ばれていないこと（`codex` の起動の痕跡が無い）を確かめる。その `レビュー実行者:` のコメントの URL を issue #978 に貼る。確認後、`codex` のキーを消して戻す。担い手は本体（interactive では主）。実装の段では行わない。触る範囲: なし（実機操作のみ）
