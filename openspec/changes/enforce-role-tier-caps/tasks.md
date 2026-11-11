# Tasks

行番号は仕様づくりの時点の値で、前のタスクの編集でずれうる。編集前に該当範囲を読む。パスの `plugins/dev-workflow/` は `dw/` と略す。実装に入る前と PR を出す前に `git fetch origin && git merge origin/main` で main を取り込む（親エピック #616 の注意書き）。

## 1. 対応表の上限と共有モジュール

- [x] 1.1 `dw/references/model-tier-map.json` に `"role_caps": {"spec-write": "上位", "implement": "上位"}` を足す（`version` は 1 のまま）。`load_tier_map` を、キーが `version`・`tiers`・`executors`・`role_caps` ちょうどで、`role_caps` のキーが `spec-write` と `implement` ちょうどで値が 4 格のどれかのときだけ受ける形にする（ほかの役は上限を持たない。将来足すときは旧形式の対象判定を広げる別 change）。テスト: `TierMap.test_the_bundled_table_has_the_agreed_values` に `role_caps` の値を足し、`test_a_broken_table_is_refused` に「`role_caps` 欠け・`implement` 欠け・`decider` を足した表・未知の役・未定義の格 `特上`・値が文字列でない」を足す。`python3 -m pytest dw/tests/test_codex_develop.py -k TierMap` が通る。触る範囲: dw/references/model-tier-map.json:1-8、dw/scripts/codex-develop.py:383-404（load_tier_map）、dw/tests/test_codex_develop.py:1210-1265（TierMap）
- [x] 1.2 `dw/scripts/tier_caps.py` を新しく作る（標準ライブラリだけ・Python 3.9 で動く書き方。`match` 文と `X | Y` の型注釈を使わない）。中身は、model 名から格を引く関数（design「model 名から格を引く規則と文面を 1 つのモジュールに置く」の規則。いちばん低い格）と、拒否の文面の前半を作る関数。`codex-develop.py` は既存の `sys.path.insert` のあとで import する。テスト: spec の「名前の照合」scenario の 6 例を pytest で確かめ、`/usr/bin/python3 -I -c 'import sys; sys.path.insert(0, "dw/scripts"); import tier_caps'` が通る。触る範囲: dw/scripts/tier_caps.py（新規）、dw/scripts/codex-develop.py:17-22（import）、dw/tests/test_codex_develop.py（新しいテストクラス）

## 2. codex-develop.py request の上限

- [x] 2.1 profile 形式・自動選択で、実際に動く entry の役（切り替え後は decider）が実行役（spec-write か implement）のときだけ、`executed_tier` をその役の上限と比べ、超えたら `RuntimeError`（文面は 1.2 の関数。役・`executed_tier`・上限を含む）にする。依頼ファイルを書く前に判定する。テストは `patch.dict(os.environ, {'FABLE_BUDGET_MODE': 'abundant', 'SHARED_BUDGET_MODE': 'ok'})` で残量モードを固定する（3.2 と同じ）。テスト: 同梱の表で `claude-default` の implement + `--pre-class contract` が `executed_tier` 上位で通り、`patch.object(m, 'TIER_MAP', <implement と spec-write を 中位 にした表>)` では同じ依頼が `RuntimeError` で依頼ファイルが無く、メッセージに `implement`・`上位`・`中位` を含む。同じ下げた表で入力なしの implement は通り、`SHARED_BUDGET_MODE=depleted` に固定すると `--pre-class contract` の implement も中位で通る（守備範囲の③）。触る範囲: dw/scripts/codex-develop.py:442-453（tier_fields）、dw/scripts/codex-develop.py:658-739（build_request）、dw/tests/test_codex_develop.py（新しいテストクラス）
- [x] 2.2 旧形式で、phase の役が実行役（spec-write か implement）のときだけ表を読み、`--model` を codex の列で格に戻して `role_caps` の上限を超えたら拒否する。対象かどうかは役の名前だけで決め（`role_caps` のキーはこの 2 役に固定）、実行役以外の役では表を読まない。ほかの役を対象に広げるのはこの change の範囲外（広げるなら別 change で対象判定ごと変える）。テスト: implement の `gpt-6-astra` と `astra` が拒否され（依頼ファイルなし・メッセージに `implement`・`最上位`・`上位`）、implement の `gpt-6-sol` と表に無い名前は通り、`test_the_legacy_form_ignores_a_broken_table_and_the_modes`（decider の astra）がそのまま通る。`test_family_names_and_exact_ids_pass_unchanged` は `gpt-6-astra` を上限の無い phase（decider など）で確かめる形に直す。implement で表が読めないときは拒否されるテストを足す。`python3 -m pytest dw/tests/test_codex_develop.py dw/tests/test_model_resolution_current.py` が通る。触る範囲: dw/scripts/codex-develop.py:658-712（build_request の legacy 分岐と tier_map の読み込み）、dw/tests/test_codex_develop.py:1603-1632（LegacyForm）

## 3. agent-model-guard.sh の上限

- [x] 3.1 guard に種別と役の対応（`dev-workflow:worker` → spec-write・implement、`dev-workflow:gate-runner` → implement）を定数で置き、対応のある種別で `model` があるとき、guard の場所から `../references/model-tier-map.json` を読み、1.2 のモジュールで格に戻して上限を超えたら拒否する。拒否理由は 1.2 の前半のあとに `dev-workflow:decider`・`sonnet` / `opus`・`rules/subagent-model-selection.md` を足す。表が読めない・壊れているときは上限の判定を飛ばして今の Fable 判定に進む。冒頭の判定の説明コメントも直す。テスト（`agent-model-guard.bats`）: worker + `fable` の理由に `spec-write`・`implement`・`最上位`・`上位`・`dev-workflow:decider` を grep、gate-runner + `claude-fable-5-1` の理由に `implement`・`最上位`・`上位` を grep、worker の `haiku`・`sonnet`・`opus`・`fabel`・省略が通る、guard と表の一時コピーで表を壊すと worker + `fable` は拒否・`opus` は通る。既存の 64-77 行のテストが通る。触る範囲: dw/scripts/agent-model-guard.sh:1-22（説明コメント）、dw/scripts/agent-model-guard.sh:85-98（Fable 判定の前）、dw/scripts/agent-model-guard.sh:118-119（python3 の起動）、dw/tests/agent-model-guard.bats:64-77、dw/tests/agent-model-guard.bats（末尾に追加）
- [x] 3.2 表を 1 か所変えると両方の判定が変わるテストを `agent-model-guard.bats` に 1 件足す。`dw/scripts` と `dw/references` を一時ディレクトリに複製し、複製の表の spec-write・implement を `中位` に下げ、同じテストで「同梱の guard は worker + `opus` を通す／複製の guard は拒否する」「同梱の `codex-develop.py request --profile claude-default --phase implement --pre-class contract` は通る／複製は拒否する」を確かめる。`request` の cwd には一時の git リポジトリを作り、`FABLE_BUDGET_MODE=abundant`・`SHARED_BUDGET_MODE=ok` を明示する。`bats dw/tests/agent-model-guard.bats` が exit 0。触る範囲: dw/tests/agent-model-guard.bats（末尾に追加）

## 4. 文書と記録

- [x] 4.1 `model-tiers.md` の強制層の説明に、実行役の上限は `model-tier-map.json` の `role_caps` にあり、guard と `codex-develop.py request` が同じ表から判定することを足す。`model-tier-map.json` の役割を述べる 22 行目付近の段落にも上限の置き場所を 1 文足す。変更の記録 `dw/changes/615.md` を書く。確認: `git grep -n role_caps dw/references/model-tiers.md` が当たる。触る範囲: dw/references/model-tiers.md:22-26、dw/references/model-tiers.md:76、dw/changes/615.md（新規）

## 5. 全体の確認

- [x] 5.1 `bats plugins/dev-workflow/tests` と `python3 -m pytest plugins/dev-workflow/tests/test_codex_develop.py plugins/dev-workflow/tests/test_model_resolution_current.py` が exit 0。`openspec validate enforce-role-tier-caps --type change --strict` が通る
