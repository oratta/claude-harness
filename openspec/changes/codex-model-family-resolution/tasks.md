## 1. worker の系統名解決（テスト先行）

- [x] 1.1 `plugins/dev-workflow/tests/test_codex_worker.py` に、2026-09-23 の一覧（表示: `gpt-6-astra` / `gpt-6-sol` / `gpt-6-luna` / `gpt-5.6-sol` / `gpt-5.6-terra` / `gpt-5.6-luna` / `gpt-5.5`、hidden: `gpt-reserve` / `codex-auto-review`）のフィクスチャを足し、model=sol/luna/astra がそれぞれ `gpt-6-*` に解決され thread/start・turn/start に解決後の ID が渡るテストを書く（Red）
- [x] 1.2 同じファイルに、該当 0 件（hidden の候補だけの場合を含む）で `model_not_available`、同版 2 件（同 slug 重複、`gpt-6-sol` と `gpt-6.0-sol`）で `model_not_unique`、どちらも thread/start を呼ばないテストを書く（Red）
- [x] 1.3 `gpt-5.10-sol` > `gpt-5.9-sol`、`gpt-6-sol-mini` を候補にしない、`hidden` が真偽値以外の entry が一覧にあれば系統名・完全 ID のどちらの経路でも `model_list_invalid`、系統名でも一覧取得失敗は `model_list_unavailable`、のテストを書く（Red）
- [x] 1.4 effort が解決後のモデルの `supportedReasoningEfforts` で検証されること（旧版だけが対応している effort は `unsupported_model_effort`）のテストを書く（Red）
- [x] 1.5 結果 JSON の `execution.model_resolution`（family 成功・exact 成功・解決前の失敗で `resolved: null` / `source: "unavailable"`）と、`requested.model` が系統名のまま・`effective.model` が観測値だけであることのテストを書く（Red）
- [x] 1.6 `plugins/dev-workflow/scripts/codex-worker.py` の `advertised_model()` に系統名の解決を足し、`run_turn()` が解決後の ID を thread/start と turn/start に渡し、`execution_metadata()` と recorder が `model_resolution` を持つようにする。payload の model は書き換えない。既存の完全 ID の照合は変えない（Green）
- [x] 1.7 既存の worker テストが全件通ることを確認する

## 2. 役割表と develop 側

- [x] 2.1 `plugins/dev-workflow/tests/test_codex_develop.py` の組み込み profile の期待値（`gpt-5.6-sol` / `gpt-5.6-luna` / `gpt-6-astra`）を系統名に変え、`codex-role-profiles.json` に `gpt-[0-9]` が無いことを確かめるテストを足す（Red）
- [x] 2.2 外部 profile-file に系統名と完全 ID を混ぜた場合、旧形式 `--model sol` と `--model gpt-6-astra` の場合に、request の model が指定値のまま書かれるテストを足す
- [x] 2.3 `plugins/dev-workflow/references/codex-role-profiles.json` の Codex role の model を `sol` / `luna` / `astra` に書き換える（Green）。`git grep -nE 'gpt-[0-9]' plugins/dev-workflow/references/codex-role-profiles.json` が 0 件であることを確認する

## 3. docs と仕様

- [x] 3.1 `plugins/dev-workflow/references/codex-develop.md` の委譲手順 3 に、記録先コメントへ `execution.model_resolution.requested` と `resolved`（と観測した `effective.model`）を両方書くことを足す。Codex の model は系統名か完全 ID で書け、系統名は worker が呼ぶ直前に最新版へ解決すること、新しいモデルが一覧に出るには Codex CLI の更新が要ることを一言書く
- [x] 3.2 docs は 3.1 の `plugins/dev-workflow/references/codex-develop.md` だけを直す（`docs/codex-develop.md` は存在しないので作らない）。`plugins/dev-workflow/references/model-tiers.md` 等、Codex の model 値の意味を説明している箇所に食い違いが無いか grep で確認し、あれば直す
- [ ] 3.3 `openspec validate codex-model-family-resolution --strict` が通ることを確認する（main spec への反映は archive で行う。archive 後に `openspec/specs/codex-worker/spec.md` の `gpt-5.6-sol` の例が消えていること、`openspec/specs/codex-role-profiles/spec.md` に `gpt-6-astra` が残っていないことを確認する）

## 4. 版と回帰

- [ ] 4.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を上げ、`plugins/dev-workflow/CHANGELOG.md` に項目を足す
- [ ] 4.2 `scripts/test.sh` を全件実行し、exit code と要約を記録する
