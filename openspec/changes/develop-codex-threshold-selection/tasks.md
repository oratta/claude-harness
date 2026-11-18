# Tasks

## 1. 選択の規則と基準の設定

- [x] 1.1 `select_configuration` に基準の引数（既定 10）を足し、`codex-off` の次に「Codex margin が欠測でなく基準以上 → `('codex-standard', 'codex-headroom-meets-threshold')`」を置く。残りの 4 分岐は今のまま。`test_codex_develop.py` に issue #1677 の受け入れ条件の 6 件（6.9/65.3・-5/65.3・6.9/5・-5/5・6.9/-1 と 6.9/None・`codex_enabled=False`）と、基準ちょうど 10 の境界を足し、`python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` が exit 0。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:121-134（`select_configuration`）、plugins/dev-workflow/tests/test_codex_develop.py:390-402（`test_selection_table_and_zero_boundary`）、plugins/dev-workflow/tests/test_codex_develop.py:1099-1105（`test_select_configuration_returns_claude_default_when_codex_is_off`）
- [x] 1.2 基準の設定 `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` を読む関数を足す（未設定・空白だけは 10、`float` に読めない・有限でない・0 未満・100 超は設定名を含む RuntimeError。0・100・小数は通す）。`automatic_selection` の中でだけ呼び（Codex オフでも呼ぶ）、`select_configuration` に渡す。エラーは headroom の設定と同じく `status: blocked`・exit 2 になる。テスト: 基準 30 で 6.9/20 → `claude-write-codex-review`、`abc`・`-1`・`101`・`nan` で `automatic_selection` が RuntimeError、CLI の `request` が exit 2・`blocked`・エラー文に設定名、明示 profile では不正な値でも止まらない。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:62-64（`_setting_error` の隣）、plugins/dev-workflow/scripts/codex-develop.py:336-359（`automatic_selection`）、plugins/dev-workflow/tests/test_codex_develop.py:560-610（`test_invalid_headroom_setting_*`・`test_explicit_profile_never_reads_automatic_snapshots` の隣）
- [x] 1.3 `automatic_selection` の返す selection の `reason` に新しい理由が出ることを、Codex の余裕が基準以上の入力で確かめるテストを足す（dispatch のコメントの reason はこの値）。触る範囲: plugins/dev-workflow/tests/test_codex_develop.py:884-930（`test_acceptance_selection_cases_flow_through_build_request`）

## 2. Codex の余裕が 10 以上で `claude-write-codex-review` を期待していた既存のテストを直す

- [x] 2.1 両 provider に余裕がある入力（Codex 10・20・30 など）で `claude-write-codex-review` を期待していた箇所の Codex の値を基準未満（例 5）に変え、新しい行のケース（Codex 10 以上 → `codex-standard`・`codex-headroom-meets-threshold`）を受け入れの表に足す。`python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py plugins/dev-workflow/tests/test_model_resolution_current.py` が exit 0。触る範囲: plugins/dev-workflow/tests/test_codex_develop.py:390-402、plugins/dev-workflow/tests/test_codex_develop.py:884-905、plugins/dev-workflow/tests/test_codex_develop.py:1083-1130（`automatic_off_case` と Codex オフの検査）、plugins/dev-workflow/tests/test_codex_develop.py:1195-1209、plugins/dev-workflow/tests/test_model_resolution_current.py:55-60、plugins/dev-workflow/tests/test_model_resolution_current.py:126（`MARGINS` の `auto:claude-write-codex-review` は (20, 10)、`auto:codex-standard` は (-5, 30) で理由 `only-codex-has-headroom`、`MARGINS.get` の既定も (20, 10)。どれも Codex を基準未満（5）にして、今の理由のまま表の各行を引く。executor と model の固定値は変えない）

## 3. 文書と変更の記録

- [ ] 3.1 `references/codex-develop.md`「起動と role 解決」の構成の選び方を表の順に書き直し（Codex が基準以上なら Claude を問わず `codex-standard`、基準は `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT`・既定 10・不正値は blocked）、`git grep -n 'DEVELOP_ALL_CODEX_MIN_MARGIN_PCT' plugins/dev-workflow/references/codex-develop.md` が 1 件以上。`skills/develop/SKILL.md` の「Role profile の選択」は正本を指すだけなので、規則の文が無いことを確かめて変えない（構成の列挙に食い違いがあれば合わせる）。触る範囲: plugins/dev-workflow/references/codex-develop.md:11、plugins/dev-workflow/skills/develop/SKILL.md:26
- [ ] 3.2 `plugins/dev-workflow/changes/1677.md` を書く（何が変わったか・設定の名前と既定・置き場を環境変数にした理由・戻し方）。触る範囲: plugins/dev-workflow/changes/1677.md（新規）

## 4. 結合の確認

- [ ] 4.1 `openspec validate develop-codex-threshold-selection --type change --strict` と `scripts/test.sh dev-workflow`（または repo の既存の実行方法）が exit 0。開始済みの工程を切り替えない既存の検査（`plugins/dev-workflow/tests/model-escalation-policy.bats:308` の「a resume calls request again and compares tiers without reselecting」）が変わらず通ること

## Workflow follow-up

- archive で `openspec/specs/codex-role-profiles/spec.md` に反映する
