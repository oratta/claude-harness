## 1. 帰属の鍵を足す

- [ ] 1.1 `attribution.bats` に、`gh issue reopen 42` を実行した区間が issue 42 に寄るテストと、`gh api -X POST repos/acme/app/issues/42/comments` と `gh api -X PATCH repos/acme/app/issues/42` で寄るテスト、実行していない文字列（`Agent` の指示文や `Edit` の本文の `gh issue reopen 42`）では寄らないテスト、`issues/comments/<id>`・`gh api graphql`・`issues/42abc` では寄らないテスト、`gh api -X POST repos/acme/app/issues/42/comments -f body="gh api repos/acme/app/issues/99"` が 42 に寄り 99 に寄らないテスト、行頭・`&&` の直後・`VAR=x gh api ...` で寄り `xargs gh api ...` では寄らない（読み落とす）テストを先に書き、落ちることを確かめる。触る範囲: `plugins/cost-ledger/tests/attribution.bats:1-120`、`load helper` の `cl_row`・`cl_write_log` の使い方は `plugins/cost-ledger/tests/deleted-cwd.bats:289-300` を参照
- [ ] 1.2 `ISSUE_RE` の定義だけを書き換え、`reopen` と、コマンドの位置（行頭、または `;` `&&` `||` `|` `(` の直後。前の `VAR=値` は可）にある `gh api` の形を非キャプチャ群の選択肢で並べ、`re.M` を付ける（design の決定 2 の形）（番号のキャプチャ群は 1 つのまま。`findall` は今までどおり番号の文字列のリストを返す）。`scan_tool_calls` など `ISSUE_RE` 以外の行は変えない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:46-50`（`ISSUE_RE`。定義の上のコメントは変えない）
- [ ] 1.3 `bats plugins/cost-ledger/tests/` が exit 0 になることを確かめる（既存の帰属のテストが変わらず通る）

## 2. 仕様と記録

- [ ] 2.1 `openspec/specs/cost-ledger-attribution/spec.md` の該当要件に delta を反映する（archive で行う）。触る範囲: `openspec/specs/cost-ledger-attribution/spec.md:138-165`
- [ ] 2.2 変更の記録 `plugins/cost-ledger/changes/698.md` を書く（直したこと・過去分は直さないこと・`gh api` で読まない形・実測）。触る範囲: `plugins/cost-ledger/changes/698.md`（新規）

## 3. 実測（エピック #272 の全体の制約）

- [ ] 3.1 LLM のトークンを使っていないこと（hook とスクリプトだけの変更）を PR 本文に書く
- [ ] 3.2 hook 1 回の同期部分の待ち時間を、変更の前後で 20 回測った中央値で PR 本文に書く
- [ ] 3.3 `gh` の呼び出し回数を、変更の前後で同じ入力に対して数えて PR 本文に書く
