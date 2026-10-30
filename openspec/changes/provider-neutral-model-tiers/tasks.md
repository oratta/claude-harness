# Tasks

行番号は仕様づくりの時点の値で、前のタスクの編集でずれうる。編集前に該当範囲を読む。パスの `plugins/dev-workflow/` は `dw/` と略す。

## 1. 対応表と tier-model

- [x] 1.1 `dw/references/model-tier-map.json` を design の形で作り、`load_tier_map(path)` で厳密に読む（欠け・未知のキーは `status: blocked`・exit 2）。`path` の既定は同梱の表。テスト: 壊れた表を一時ファイルに書いて `load_tier_map(path)` に渡すと拒否される。`request` 経由は `patch.object(m, 'TIER_MAP', <一時ファイル>)` で差し替え、blocked で依頼ファイルができないことを確かめる。`git grep -nE 'gpt-[0-9]' dw/references/model-tier-map.json` が 0 件。触る範囲: dw/references/model-tier-map.json（新規）、dw/scripts/codex-develop.py:1-44、dw/tests/test_codex_develop.py（新しいテストクラス）
- [x] 1.2 `tier-model` サブコマンドを足し、`main()` を command で分岐する。`--executor` と `--tier` に argparse の `choices` を使わない。テスト: 全格 exit 0、`--tier 特上` と未定義の executor は blocked・exit 2。触る範囲: dw/scripts/codex-develop.py:628-655（main）、dw/tests/test_codex_develop.py（新しいテストクラス）

## 2. profile の形式版 2

- [ ] 2.1 `codex-role-profiles.json` を version 2 にする。全 entry の `model` を消し、`claude-default` を足し、`codex-economy` の spec-write / implement に `tier_cap: 最安` を付ける。テスト: 全 entry の走査で `model` キーが無いこと、`tier_cap` を持つのがその 2 entry だけであること、`git grep -nE 'gpt-[0-9]' dw/references/codex-role-profiles.json` が 0 件。触る範囲: dw/references/codex-role-profiles.json:1-53、dw/tests/test_codex_develop.py（新しいテストクラス）
- [ ] 2.2 `validate_role_entry`・`load_profile`・`validate_execution_config`・`resolve_execution` を形式版 2 にする。`claude_default()` と `automatic_claude_default` を消し、自動選択の `claude-default` も `load_profile` で読む。`--profile claude-default` が account-home なしで通ることを確かめる。テスト: `test_codex_develop.py` の version 1 の fixture を version 2 に直し、version 1・`model` キー・未定義の `tier_cap` の拒否を足す。`claude_default` と `execution_config` のテストを直す。`python3 -m pytest plugins/dev-workflow/tests/test_codex_develop.py` が通る。触る範囲: dw/scripts/codex-develop.py:330-350（bind_codex_account・claude_default）、dw/scripts/codex-develop.py:405-478（validate_role_entry〜resolve_execution）、dw/scripts/codex-develop.py:586-596（build_request の自動選択）、dw/tests/test_codex_develop.py:70-82、dw/tests/test_codex_develop.py:216-309、dw/tests/test_codex_develop.py:737-751、dw/tests/test_codex_develop.py:934-935、dw/tests/test_codex_develop.py:1143
- [ ] 2.3 外部 profile の形式と移行を文書にする。確認: 文書の例の JSON を `--profile-file` に渡して解決できる。`git grep -n 'version 1' dw/docs/codex-develop.md dw/references/codex-develop-explicit.md` が移行の説明以外に当たらない。触る範囲: dw/references/codex-develop-explicit.md:13、dw/docs/codex-develop.md:49

## 3. 格の規則

- [ ] 3.1 `request` に `--pre-class`・`--design-judgment`・`--failure`・`--unmanned` を足し、phase と入力から要求の格を決める関数を作る。W と G は phase で分ける。テスト: `model-tier-resolution` の「格は役と入力だけから決める」の scenario 全部と、未定義の `--pre-class` で依頼ファイルができないこと。触る範囲: dw/scripts/codex-develop.py:550-626（build_request）、dw/scripts/codex-develop.py:628-655（main）、dw/tests/test_codex_develop.py（新しいテストクラス）
- [ ] 3.2 spec-review / review の merge・contract・billing で decider の entry に切り替える。指示書は phase のものを保つ。結果の role だけを decider にし、依頼ファイルの role は phase の role を保つ。テスト: `claude-write-codex-review` の review + contract が codex・astra・結果の role=decider で、依頼ファイルの role が `impl-review` で、prompt に phase `review` の指示書が入る。`--pre-class sacred` だけなら切り替わらず、`--failure` が効かない。触る範囲: dw/scripts/codex-develop.py:595-596、dw/scripts/codex-develop.py:496-534（prompt）、dw/tests/test_codex_develop.py（新しいテストクラス）

## 4. 残量モード

- [ ] 4.1 `usage_view.py` に残量モードの導出の関数を足す。式は `session-tripwires.sh` 92-122 行目と同じ。未知の明示値は conserve / throttled、データ無しは conserve / ok に読み替える。テスト: 明示 env が勝つ・データ無し・未知の値の scenario、`now` を固定して fable_weekly_pct 95・weekly_all_pct 60・weekly_resets_epoch = now + 6 日で exhausted / throttled になること、`session-tripwires.sh` と同じ入力で同じ値になること。触る範囲: dw/scripts/usage_view.py:195-246（slot_view・active_slot の次）、dw/tests/test_codex_develop.py（新しいテストクラス）
- [ ] 4.2 要求の格に残量モードを適用する関数を作り、`codex-develop.py` から導出を呼ぶ。読めないときは止まらない。明示 profile でも usage probe は走らせない。テスト: `model-tier-resolution` の「残量モードを格に適用する」の scenario 全部。既存のテストは残量 env を固定する（`setUp` で conserve / ok）。触る範囲: dw/scripts/codex-develop.py:65-87（claude_usage_evidence の近く）、dw/scripts/codex-develop.py:550-626、dw/tests/test_codex_develop.py:100-112、dw/tests/test_codex_develop.py:152-153

## 5. 上限と出力

- [ ] 5.1 `tier_cap` から `executed_tier` を作り、対応表で `requested_model` と `model` を引いて結果に 8 欄を足す。`tier_reason` は共有枠モードを優先する。依頼ファイルの欄は増やさない。テスト: `model-tier-resolution` の「構成の上限」「格の出力」の scenario 全部。依頼ファイルが `codex-worker.py run` に受け付けられる。触る範囲: dw/scripts/codex-develop.py:595-626、dw/tests/test_codex_develop.py（新しいテストクラス）
- [ ] 5.2 旧形式は規則・残量モード・対応表を通さず、格の欄を null にする。格の入力の引数は受けて無視する。テスト: `model-tier-resolution` の「旧形式は格の規則を通らない」と `codex-role-profiles` の「旧形式で系統名と完全 ID を指定する」。触る範囲: dw/scripts/codex-develop.py:576-584、dw/tests/test_codex_develop.py（新しいテストクラス）

## 6. 文書

- [ ] 6.1 SKILL.md の「Role profile の選択」と「モデル」節を、規則の説明と `request` への参照にする。本体が渡す入力、`role: decider` の起こし方、dispatch 記録の欄（`tier`・`executed_tier`・`tier_cap` を含む）、32 行目の再開前の確認を「`request` を呼び直し `tier` と thread の格を比べる」形にすること、V と引き継ぎの判定役は `request` を通らないこと（V は 中位（`sonnet`）、判定役は 上位（`opus`））を書く。テスト: `model-escalation-policy.bats` に `dev-workflow-develop` の scenario の確認を足す。`awk '/^## モデル/{f=1;next} /^## /{f=0} f' plugins/dev-workflow/skills/develop/SKILL.md | grep -cE 'claude-write-codex-review|codex-standard'` が 0。触る範囲: dw/skills/develop/SKILL.md:24-32、dw/skills/develop/SKILL.md:165、dw/skills/develop/SKILL.md:281-298、dw/tests/model-escalation-policy.bats:169-171
- [ ] 6.2 `pre-classification.md` を `request` の入力への参照に直し、20 行目を聖域パスだけでは上げない形にする。`decision-criteria.md` の 106 行目を同じ向きに直し、122 行目の depleted を「Sonnet 上限」にして、共有枠モードの節に haiku の扱いを 1 行足す（throttled / depleted とも最安はそのまま）。`worker.md` は索引なので触らない。テスト: `model-escalation-policy.bats` に聖域と haiku の文言の確認を足す。触る範囲: dw/skills/develop/references/pre-classification.md:9-20、dw/skills/develop/references/decision-criteria.md:106、dw/skills/develop/references/decision-criteria.md:121-124、dw/tests/model-escalation-policy.bats:32-60
- [ ] 6.3 `spec-reviewer.md`「R1 の spawn」の箇条を、`request` が返す `model` と `role: decider` への参照に直す。33 行目の depleted の語も「`sonnet` 上限」に合わせる。テスト: `dev-workflow-spec-review` の scenario の文言（既定 `opus`、聖域パスだけでは上げない、`reserve` と `exhausted` の書き分け）が残ることを `model-escalation-policy.bats` で確かめる。触る範囲: dw/skills/develop/references/roles/spec-reviewer.md:29-34、dw/tests/model-escalation-policy.bats
- [ ] 6.4 `model-tiers.md` に格と対応表への参照、「中位（重めは opus）」が今回の上位に当たることを書き、version 1 の記述を直す。テスト: 対応表の claude と `model-tiers.md` の `haiku`・`sonnet`・`fable` の 3 行、`'opus'` の記述が一致する。触る範囲: dw/references/model-tiers.md:13-26、dw/tests/test_model_resolution_current.py
- [ ] 6.5 `codex-develop.md` の Claude role の新規起動と再開を、`request` が返す `requested_model`・`model`・`tier_reason` を使う形に直す。21 行目の「`SHARED_BUDGET_MODE=depleted` は requested にかかわらず applied=sonnet に固定」の文を「sonnet 上限で haiku はそのまま」に直す。23 行目の再開前の確認は `request` の呼び直しと `tier` の比較にする。入力の引数を書く。`docs/codex-develop.md` の呼び方も合わせる。テスト: `test_codex_develop.py` 1229 行目付近の文言の確認を直す。触る範囲: dw/references/codex-develop.md:5-23、dw/docs/codex-develop.md:28-49、dw/tests/test_codex_develop.py:1229-1230

## 7. #613 のテストと表の置き換え

- [ ] 7.1 `test_model_resolution_current.py` を書き換える。役 × 構成 × 12 モード × 入力の `tier` をリテラルの期待値で確かめ、入力なしの conserve / ok は executor と model が #613 の値のままであることも確かめる。遅ければ git の呼び出しを差し替える。テスト: `python3 -m pytest plugins/dev-workflow/tests/test_model_resolution_current.py` が exit 0 で、`claude-write-codex-review` の事前分類の W が上位。触る範囲: dw/tests/test_model_resolution_current.py:1-140
- [ ] 7.2 `model-resolution-current.md` を削除し、参照を消す。確認: `git grep -n 'model-resolution-current' -- plugins/dev-workflow ':!plugins/dev-workflow/changes'` が 0 件。触る範囲: dw/references/model-resolution-current.md:1-769（削除）、dw/references/codex-develop-explicit.md:13、dw/tests/test_model_resolution_current.py:3、dw/tests/test_model_resolution_current.py:66
- [ ] 7.3 変更の記録を書く。BREAKING（外部 profile-file の version 1 の拒否と書き換え方）を含める。確認: ファイルがあり、#614 と書き換え方が書かれている。触る範囲: dw/changes/614.md（新規）

## 8. 受け入れ条件の確認

- [ ] 8.1 全体の確認を通す。`bats plugins/dev-workflow/tests tests/injection-budget.bats` と `python3 -m pytest plugins/dev-workflow/tests` が exit 0。issue の `awk | grep -c` が 0。全 entry の走査テストで `model` キーが無い。`tier-model` が全格で exit 0、未定義の格で exit 2。触る範囲: なし（確認のみ）

## Workflow follow-up

- R1 の APPROVE が記録先に記録されてから実装に入る。
- 実装と verify のあと、change を archive して PR を作る。
