## 1. hook のスクリプトと登録

- [ ] 1.1 `plugins/dev-workflow/scripts/owner-message-number-check.sh` を作る（spec の要件のうち hooks.json の登録を除く 6 件。本文の読み方・対象の見分け方・止める条件・理由の中身・理由に正本の文言を写さないこと・1 ターン 1 回と fail-soft）。書き方は `unclear-reply-rephrase.sh` に揃える（先頭の注釈に spec 名と design の場所、全解除と `stop_hook_active` と速い道の判定を python3 の前に置く、python3 は `-I`、Python 本体は変数に持って `-c` で渡し payload は標準入力のまま読ませる）。実行権限を付ける。確かめ方: 下の 1.3 の bats が通る。触る範囲: `plugins/dev-workflow/scripts/owner-message-number-check.sh`（新規）、手本として `plugins/dev-workflow/scripts/unclear-reply-rephrase.sh:1-100`
- [ ] 1.2 `plugins/dev-workflow/hooks/hooks.json` の `PreModelSwitch` のあとに `Stop` のキーを足し、1 件のエントリで `"\"${CLAUDE_PLUGIN_ROOT}/scripts/owner-message-number-check.sh\""` を起動する（matcher と timeout を付けない）。確かめ方: `python3 -c 'import json;json.load(open("plugins/dev-workflow/hooks/hooks.json"))'` が通り、`bats tests/hook-python-isolation.bats tests/lint-plugin-validate.bats` が通る。触る範囲: `plugins/dev-workflow/hooks/hooks.json:121-132`
- [ ] 1.3 `plugins/dev-workflow/tests/owner-message-number-check.bats` を作り、spec の各 Scenario を 1 件以上ずつ検査する。受け入れ条件の 4 件（1 行目「PR #1712 のリスクを許容しますか？」でリンク無し → 差し戻して `#1712` を示す／番号が区切りより下と URL の中にだけ → 差し戻さない／`主がすること: なし` で始まり番号を含まない報告 → 差し戻さない／`stop_hook_active: true` の 2 回目 → 差し戻さない）は、それと分かるテスト名にする。正本 `output-styles/readable.md` の節 3 に見出し・「ほかの決まり」の段落・`番号は末尾の URL にだけ置く`・`主がすること: なし` が残っていることも検査する。テスト名は ASCII、否定検査は has / lacks / silent の関数で書く（`openspec/specs/bats-assertion-guard/spec.md`）。確かめ方: `bats plugins/dev-workflow/tests/owner-message-number-check.bats` が全件通る。触る範囲: `plugins/dev-workflow/tests/owner-message-number-check.bats`（新規）、手本として `plugins/dev-workflow/tests/unclear-reply-rephrase.bats:1-120`
- [ ] 1.4 既存のテストが壊れていないことを確かめる。確かめ方: `bats plugins/dev-workflow/tests/` と `bats tests/` が、この変更の前と同じ件数だけ通る（前から落ちているものがあれば、変更前の main でも落ちることを確かめて報告に書く）。触る範囲: なし（実行のみ）

## 2. 実機での差し戻しの確認と変更の記録

- [ ] 2.1 `claude -p --plugin-dir plugins/dev-workflow` で、1 行目を「PR #1712 のリスクを許容しますか？」にしてリンクを付けずに返すよう頼み、hook が 1 回差し戻して書き直した発言が続くことを確かめる。確かめ方: `--output-format stream-json --verbose` の出力（またはトランスクリプト）に差し戻しの理由（`[dev-workflow 主への発言の差し戻し]` と `#1712`）が現れ、2 回目の停止では差し戻していない。実行したコマンドと、出力から抜いた該当行を PR 本文に載せる記録として控える（PR は (3b) で作る）。検証用の作業場所は scratchpad に作る。触る範囲: なし（実行のみ）
- [ ] 2.2 変更の記録 `plugins/dev-workflow/changes/1215.md` を書く（何を足したか・対象と止める条件・1 ターン 1 回と全解除・正本は変えていないこと・守らないもの・戻し方）。版は上げない。確かめ方: ファイルがあり、`bats tests/` の変更の記録に関するテストが通る。触る範囲: `plugins/dev-workflow/changes/1215.md`（新規）、書き方の手本として `plugins/dev-workflow/changes/1184.md`

## Workflow follow-up

- archive（`openspec archive owner-message-number-check-hook`）で `openspec/specs/dev-workflow-owner-message-number-check/spec.md` ができる
- PR 本文に 2.1 の実機の差し戻しの記録を載せる。`Closes #1215` を書く
